function collect_julia_state(source_text::AbstractString)
    source = String(source_text)
    tree = JuliaSyntax.parseall(JuliaSyntax.SyntaxNode, source)
    line_starts = _julia_line_starts(source)
    state = JuliaCollectionState()
    _collect_julia_node!(tree, state, source, line_starts, JuliaScopeContext())
    return state
end

function _collect_julia_node!(
    node,
    state::JuliaCollectionState,
    source::String,
    line_starts::Vector{Int},
    context::JuliaScopeContext,
)
    node_kind = _julia_kind_name(node)

    if node_kind == "toplevel" || node_kind == "block"
        for child in _julia_child_nodes(node)
            _collect_julia_node!(child, state, source, line_starts, context)
        end
        return nothing
    elseif node_kind == "module" || node_kind == "module-bare"
        _collect_julia_module!(node, state, source, line_starts, context)
        return nothing
    elseif node_kind == "export"
        _collect_julia_export!(node, state, source, line_starts, context)
        return nothing
    elseif node_kind == "import" || node_kind == "using"
        _collect_julia_import!(node, state, source, line_starts; context = context)
        return nothing
    elseif node_kind == "macrocall"
        _collect_julia_macrocall!(node, state, source, line_starts, context)
        return nothing
    elseif node_kind == "macro"
        _collect_julia_macro_definition!(node, state, source, line_starts, context)
        return nothing
    elseif node_kind == "call"
        _collect_julia_include!(node, state, source, line_starts, context)
        return nothing
    elseif node_kind == "function"
        _collect_julia_function!(node, state, source, line_starts, context)
        return nothing
    elseif node_kind == "const" || node_kind == "global"
        _collect_julia_binding!(node, state, source, line_starts, context)
        return nothing
    elseif node_kind == "struct" ||
           node_kind == "struct-mut" ||
           node_kind == "abstract" ||
           node_kind == "primitive"
        _collect_julia_type!(node, state, source, line_starts, context)
        return nothing
    elseif node_kind == "doc"
        _collect_julia_doc!(node, state, source, line_starts, context)
        return nothing
    end

    return nothing
end

function _collect_julia_module!(
    node,
    state::JuliaCollectionState,
    source::String,
    line_starts::Vector{Int},
    context::JuliaScopeContext,
)
    name_node = _julia_first_child_of_kind(node, "Identifier")
    isnothing(name_node) && return nothing
    module_name = _julia_node_text(name_node, source)
    module_kind = _julia_module_kind(node, source)
    isnothing(state.module_name) && (state.module_name = module_name)
    isnothing(state.module_kind) &&
        !isnothing(module_kind) &&
        (state.module_kind = module_kind)
    root_module_name = something(context.root_module_name, state.module_name, module_name)
    module_path =
        isnothing(context.module_path) ? module_name :
        "$(context.module_path).$(module_name)"
    line_start, line_end = _julia_line_span(node, line_starts)
    metadata = _julia_scope_metadata(context)
    metadata["module_name"] = module_name
    metadata["module_path"] = module_path
    metadata["root_module_name"] = root_module_name
    isnothing(module_kind) || (metadata["module_kind"] = module_kind)
    metadata["top_level"] = isnothing(context.module_path)
    _push_ast_node!(
        state,
        "module",
        module_name;
        text = module_name,
        line_start = line_start,
        line_end = line_end,
        metadata = metadata,
    )
    block_node = _julia_first_child_of_kind(node, "block")
    child_context = JuliaScopeContext(
        root_module_name,
        module_name,
        module_path,
        module_name,
        "module",
        module_path,
    )
    isnothing(block_node) ||
        _collect_julia_node!(block_node, state, source, line_starts, child_context)
    return nothing
end

function _collect_julia_export!(
    node,
    state::JuliaCollectionState,
    source::String,
    line_starts::Vector{Int},
    context::JuliaScopeContext,
)
    line_start, line_end = _julia_line_span(node, line_starts)
    for child in _julia_child_nodes(node)
        export_name = _julia_symbol_name(child, source)
        isnothing(export_name) && continue
        _push_export!(state, something(export_name), line_start, line_end, context)
    end
    return nothing
end

function _collect_julia_macrocall!(
    node,
    state::JuliaCollectionState,
    source::String,
    line_starts::Vector{Int},
    context::JuliaScopeContext,
)
    macro_name = _julia_macro_name(node, source)
    if macro_name == "@reexport"
        for child in _julia_child_nodes(node)
            child_kind = _julia_kind_name(child)
            if child_kind == "using" || child_kind == "import"
                _collect_julia_import!(
                    child,
                    state,
                    source,
                    line_starts;
                    reexported = true,
                    context = context,
                )
            elseif child_kind != "macro_name"
                _collect_julia_node!(child, state, source, line_starts, context)
            end
        end
        return nothing
    end

    for child in _julia_child_nodes(node)
        _julia_kind_name(child) == "macro_name" && continue
        _collect_julia_node!(child, state, source, line_starts, context)
    end
    return nothing
end

function _collect_julia_macro_definition!(
    node,
    state::JuliaCollectionState,
    source::String,
    line_starts::Vector{Int},
    context::JuliaScopeContext,
)
    macro_name = _julia_macro_definition_name(node, source)
    isnothing(macro_name) && return nothing
    line_start, line_end = _julia_line_span(node, line_starts)
    signature = _julia_macro_definition_signature(node, source)
    _push_symbol!(
        state,
        something(macro_name),
        "macro",
        signature,
        line_start,
        line_end,
        context,
    )
    return nothing
end

function _collect_julia_binding!(
    node,
    state::JuliaCollectionState,
    source::String,
    line_starts::Vector{Int},
    context::JuliaScopeContext,
)
    binding_name = _julia_binding_name(node, source)
    binding_kind = _julia_binding_kind(node)
    isnothing(binding_name) && return nothing
    isnothing(binding_kind) && return nothing
    line_start, line_end = _julia_line_span(node, line_starts)
    signature = _julia_binding_signature(node, source)
    _push_symbol!(
        state,
        something(binding_name),
        "binding",
        signature,
        line_start,
        line_end,
        context;
        metadata = Dict{String,Any}("binding_kind" => binding_kind),
    )
    return nothing
end

function _collect_julia_function!(
    node,
    state::JuliaCollectionState,
    source::String,
    line_starts::Vector{Int},
    context::JuliaScopeContext,
)
    symbol_name = _julia_function_name(node, source)
    isnothing(symbol_name) && return nothing
    line_start, line_end = _julia_line_span(node, line_starts)
    signature = _julia_function_signature(node, source)
    metadata = _julia_function_header_metadata(node, source)
    _push_symbol!(
        state,
        something(symbol_name),
        "function",
        signature,
        line_start,
        line_end,
        context,
        metadata = metadata,
    )
    _collect_julia_function_parameters!(
        node,
        state,
        source,
        line_starts,
        context,
        something(symbol_name),
        String(signature),
        line_start,
    )
    return nothing
end

function _collect_julia_type!(
    node,
    state::JuliaCollectionState,
    source::String,
    line_starts::Vector{Int},
    context::JuliaScopeContext,
)
    symbol_name = _julia_first_identifier_text(node, source)
    isnothing(symbol_name) && return nothing
    line_start, line_end = _julia_line_span(node, line_starts)
    signature = _julia_node_signature(node, source)
    type_kind = _julia_type_kind(node, source)
    _push_symbol!(
        state,
        something(symbol_name),
        "type",
        signature,
        line_start,
        line_end,
        context;
        metadata = isnothing(type_kind) ? Dict{String,Any}() :
                   Dict{String,Any}("type_kind" => type_kind),
    )
    return nothing
end

function _collect_julia_doc!(
    node,
    state::JuliaCollectionState,
    source::String,
    line_starts::Vector{Int},
    context::JuliaScopeContext,
)
    string_node = _julia_first_string_child(node)
    target_node = _julia_last_non_string_child(node)
    isnothing(string_node) && return nothing
    isnothing(target_node) && return nothing
    target_info = _julia_doc_target(target_node, source)
    if !isnothing(target_info)
        line_start, line_end, target_line_start, target_line_end =
            _julia_doc_spans(string_node, target_node, line_starts)
        _push_docstring!(
            state,
            target_info.name,
            target_info.target_kind,
            _julia_string_content(string_node, source),
            line_start,
            line_end,
            target_line_start,
            target_line_end,
            context,
        )
    end
    _collect_julia_node!(target_node, state, source, line_starts, context)
    return nothing
end
