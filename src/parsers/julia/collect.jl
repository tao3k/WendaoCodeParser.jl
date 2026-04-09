function collect_julia_state(source_text::AbstractString)
    source = String(source_text)
    tree = JuliaSyntax.parseall(JuliaSyntax.SyntaxNode, source)
    line_starts = _julia_line_starts(source)
    state = JuliaCollectionState()
    _collect_julia_node!(tree, state, source, line_starts)
    return state
end

function _collect_julia_node!(
    node,
    state::JuliaCollectionState,
    source::String,
    line_starts::Vector{Int},
)
    node_kind = _julia_kind_name(node)

    if node_kind == "toplevel" || node_kind == "block"
        for child in _julia_child_nodes(node)
            _collect_julia_node!(child, state, source, line_starts)
        end
        return nothing
    elseif node_kind == "module"
        _collect_julia_module!(node, state, source, line_starts)
        return nothing
    elseif node_kind == "export"
        _collect_julia_export!(node, state, source, line_starts)
        return nothing
    elseif node_kind == "import" || node_kind == "using"
        _collect_julia_import!(node, state, source, line_starts)
        return nothing
    elseif node_kind == "macrocall"
        _collect_julia_macrocall!(node, state, source, line_starts)
        return nothing
    elseif node_kind == "call"
        _collect_julia_include!(node, state, source, line_starts)
        return nothing
    elseif node_kind == "function"
        _collect_julia_function!(node, state, source, line_starts)
        return nothing
    elseif node_kind == "struct" || node_kind == "abstract" || node_kind == "primitive"
        _collect_julia_type!(node, state, source, line_starts)
        return nothing
    elseif node_kind == "doc"
        _collect_julia_doc!(node, state, source, line_starts)
        return nothing
    end

    return nothing
end

function _collect_julia_module!(
    node,
    state::JuliaCollectionState,
    source::String,
    line_starts::Vector{Int},
)
    name_node = _julia_first_child_of_kind(node, "Identifier")
    isnothing(name_node) && return nothing
    module_name = _julia_node_text(name_node, source)
    isnothing(state.module_name) && (state.module_name = module_name)
    line_start, line_end = _julia_line_span(node, line_starts)
    _push_ast_node!(
        state,
        "module",
        module_name;
        text = module_name,
        line_start = line_start,
        line_end = line_end,
        metadata = Dict("module_name" => module_name),
    )
    block_node = _julia_first_child_of_kind(node, "block")
    isnothing(block_node) || _collect_julia_node!(block_node, state, source, line_starts)
    return nothing
end

function _collect_julia_export!(
    node,
    state::JuliaCollectionState,
    source::String,
    line_starts::Vector{Int},
)
    line_start, line_end = _julia_line_span(node, line_starts)
    for child in _julia_child_nodes(node)
        export_name = _julia_symbol_name(child, source)
        isnothing(export_name) && continue
        _push_export!(state, something(export_name), line_start, line_end)
    end
    return nothing
end

function _collect_julia_import!(
    node,
    state::JuliaCollectionState,
    source::String,
    line_starts::Vector{Int};
    reexported::Bool = false,
)
    line_start, line_end = _julia_line_span(node, line_starts)
    import_modules = _julia_import_modules(node, source)
    for import_name in import_modules
        _push_import!(state, import_name, line_start, line_end; reexported = reexported)
    end
    return nothing
end

function _collect_julia_macrocall!(
    node,
    state::JuliaCollectionState,
    source::String,
    line_starts::Vector{Int},
)
    macro_name = _julia_macro_name(node, source)
    if macro_name == "@reexport"
        for child in _julia_child_nodes(node)
            child_kind = _julia_kind_name(child)
            if child_kind == "using" || child_kind == "import"
                _collect_julia_import!(child, state, source, line_starts; reexported = true)
            elseif child_kind != "macro_name"
                _collect_julia_node!(child, state, source, line_starts)
            end
        end
        return nothing
    end

    for child in _julia_child_nodes(node)
        _julia_kind_name(child) == "macro_name" && continue
        _collect_julia_node!(child, state, source, line_starts)
    end
    return nothing
end

function _collect_julia_include!(
    node,
    state::JuliaCollectionState,
    source::String,
    line_starts::Vector{Int},
)
    _is_julia_include_call(node, source) || return nothing
    include_path = _julia_include_path(node, source)
    isnothing(include_path) && return nothing
    line_start, line_end = _julia_line_span(node, line_starts)
    _push_include!(state, something(include_path), line_start, line_end)
    return nothing
end

function _collect_julia_function!(
    node,
    state::JuliaCollectionState,
    source::String,
    line_starts::Vector{Int},
)
    symbol_name = _julia_function_name(node, source)
    isnothing(symbol_name) && return nothing
    line_start, line_end = _julia_line_span(node, line_starts)
    signature = _julia_function_signature(node, source)
    _push_symbol!(
        state,
        something(symbol_name),
        "function",
        signature,
        line_start,
        line_end,
    )
    return nothing
end

function _collect_julia_type!(
    node,
    state::JuliaCollectionState,
    source::String,
    line_starts::Vector{Int},
)
    symbol_name = _julia_first_identifier_text(node, source)
    isnothing(symbol_name) && return nothing
    line_start, line_end = _julia_line_span(node, line_starts)
    signature = _julia_node_signature(node, source)
    _push_symbol!(state, something(symbol_name), "type", signature, line_start, line_end)
    return nothing
end

function _collect_julia_doc!(
    node,
    state::JuliaCollectionState,
    source::String,
    line_starts::Vector{Int},
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
        )
    end
    _collect_julia_node!(target_node, state, source, line_starts)
    return nothing
end
