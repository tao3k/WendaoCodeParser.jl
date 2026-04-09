function _julia_scope_key(context::JuliaScopeContext)
    return String(something(context.owner_path, context.module_path, ""))
end

function _julia_scope_metadata(context::JuliaScopeContext)
    metadata = Dict{String,Any}()
    isnothing(context.root_module_name) ||
        (metadata["root_module_name"] = context.root_module_name)
    isnothing(context.module_name) || (metadata["module_name"] = context.module_name)
    isnothing(context.module_path) || (metadata["module_path"] = context.module_path)
    isnothing(context.owner_name) || (metadata["owner_name"] = context.owner_name)
    isnothing(context.owner_kind) || (metadata["owner_kind"] = context.owner_kind)
    isnothing(context.owner_path) || (metadata["owner_path"] = context.owner_path)
    return metadata
end

function _julia_symbol_path(symbol_name::String, context::JuliaScopeContext)
    isnothing(context.owner_path) && return symbol_name
    return "$(context.owner_path).$(symbol_name)"
end

function _julia_method_target_path(
    function_name::String,
    line_start::Int,
    context::JuliaScopeContext,
)
    return "$(_julia_symbol_path(function_name, context))#L$(line_start)"
end

function _push_export!(
    state::JuliaCollectionState,
    export_name::String,
    line_start::Int,
    line_end::Int,
    context::JuliaScopeContext,
)
    export_key = (export_name, _julia_scope_key(context))
    export_key in state.export_set && return nothing
    push!(state.export_set, export_key)
    export_entry = Dict{String,Any}(
        "name" => export_name,
        "line_start" => line_start,
        "line_end" => line_end,
    )
    merge!(export_entry, _julia_scope_metadata(context))
    push!(state.exports, export_entry)
    metadata = _julia_scope_metadata(context)
    metadata["name"] = export_name
    _push_ast_node!(
        state,
        "export",
        export_name;
        text = export_name,
        line_start = line_start,
        line_end = line_end,
        metadata = metadata,
    )
    return nothing
end

function _push_import!(
    state::JuliaCollectionState,
    import_name::String,
    line_start::Int,
    line_end::Int;
    reexported::Bool = false,
    context::JuliaScopeContext = JuliaScopeContext(),
)
    scope_key = _julia_scope_key(context)
    existing_index = findfirst(
        entry ->
            String(entry["module"]) == import_name &&
                String(get(entry, "owner_path", get(entry, "module_path", ""))) ==
                scope_key,
        state.imports,
    )
    if !isnothing(existing_index)
        if reexported && !Bool(get(state.imports[existing_index], "reexported", false))
            state.imports[existing_index]["reexported"] = true
            for node in Iterators.reverse(state.nodes)
                if get(node, "node_kind", nothing) == "import" &&
                   get(node, "name", nothing) == import_name &&
                   String(
                       get(
                           get(node, "metadata", Dict{String,Any}()),
                           "owner_path",
                           get(
                               get(node, "metadata", Dict{String,Any}()),
                               "module_path",
                               "",
                           ),
                       ),
                   ) == scope_key
                    node_metadata = get(node, "metadata", Dict{String,Any}())
                    node_metadata["reexported"] = true
                    node["metadata"] = node_metadata
                    break
                end
            end
        end
        return nothing
    end

    push!(state.import_set, (import_name, scope_key))
    entry = Dict{String,Any}(
        "module" => import_name,
        "reexported" => reexported,
        "line_start" => line_start,
        "line_end" => line_end,
    )
    merge!(entry, _julia_scope_metadata(context))
    push!(state.imports, entry)
    metadata = _julia_scope_metadata(context)
    metadata["module"] = import_name
    metadata["reexported"] = reexported
    _push_ast_node!(
        state,
        "import",
        import_name;
        text = import_name,
        line_start = line_start,
        line_end = line_end,
        metadata = metadata,
    )
    return nothing
end

function _push_symbol!(
    state::JuliaCollectionState,
    symbol_name::String,
    symbol_kind::String,
    signature::AbstractString,
    line_start::Int,
    line_end::Int,
    context::JuliaScopeContext;
    metadata = Dict{String,Any}(),
)
    symbol_key = (symbol_name, symbol_kind, _julia_scope_key(context), line_start, line_end)
    symbol_key in state.symbol_set && return nothing
    push!(state.symbol_set, symbol_key)
    symbol_metadata = _julia_scope_metadata(context)
    merge!(symbol_metadata, Dict{String,Any}(metadata))
    symbol_path = _julia_symbol_path(symbol_name, context)
    symbol_metadata["path"] = symbol_path
    entry = Dict{String,Any}(
        "name" => symbol_name,
        "kind" => symbol_kind,
        "signature" => String(signature),
        "path" => symbol_path,
        "line_start" => line_start,
        "line_end" => line_end,
    )
    merge!(entry, symbol_metadata)
    push!(state.symbols, entry)
    node_metadata = Dict{String,Any}(symbol_metadata)
    node_metadata["name"] = symbol_name
    node_metadata["kind"] = symbol_kind
    _push_ast_node!(
        state,
        symbol_kind,
        symbol_name;
        text = String(signature),
        line_start = line_start,
        line_end = line_end,
        signature = String(signature),
        metadata = node_metadata,
    )
    return nothing
end

function _push_parameter!(
    state::JuliaCollectionState,
    parameter_name::String,
    parameter_kind::String,
    parameter_text::String,
    line_start::Int,
    line_end::Int,
    context::JuliaScopeContext;
    function_name::String,
    function_signature::String,
    function_line_start::Int,
    type_name = nothing,
    default_value = nothing,
    typed::Bool = false,
    defaulted::Bool = false,
    vararg::Bool = false,
)
    function_path = _julia_symbol_path(function_name, context)
    function_target_path =
        _julia_method_target_path(function_name, function_line_start, context)
    parameter_path = "$(function_target_path).$(parameter_name)"
    parameter_metadata = _julia_scope_metadata(context)
    merge!(
        parameter_metadata,
        Dict{String,Any}(
            "target_kind" => "function",
            "owner_name" => function_name,
            "owner_kind" => "function",
            "owner_path" => function_path,
            "owner_signature" => function_signature,
            "target_path" => function_target_path,
            "path" => parameter_path,
            "parameter_kind" => parameter_kind,
            "parameter_is_typed" => typed,
            "parameter_is_defaulted" => defaulted,
            "parameter_is_vararg" => vararg,
        ),
    )
    isnothing(type_name) || (parameter_metadata["parameter_type_name"] = type_name)
    isnothing(default_value) ||
        (parameter_metadata["parameter_default_value"] = default_value)

    entry = Dict{String,Any}(
        "name" => parameter_name,
        "kind" => "parameter",
        "text" => parameter_text,
        "target_kind" => "function",
        "path" => parameter_path,
        "target_path" => function_target_path,
        "parameter_kind" => parameter_kind,
        "parameter_is_typed" => typed,
        "parameter_is_defaulted" => defaulted,
        "parameter_is_vararg" => vararg,
        "line_start" => line_start,
        "line_end" => line_end,
    )
    isnothing(type_name) || (entry["parameter_type_name"] = type_name)
    isnothing(default_value) || (entry["parameter_default_value"] = default_value)
    merge!(entry, parameter_metadata)
    push!(state.parameters, entry)

    node_metadata = Dict{String,Any}(parameter_metadata)
    node_metadata["name"] = parameter_name
    node_metadata["kind"] = "parameter"
    _push_ast_node!(
        state,
        "parameter",
        parameter_name;
        text = parameter_text,
        line_start = line_start,
        line_end = line_end,
        metadata = node_metadata,
    )
    return nothing
end

function _push_docstring!(
    state::JuliaCollectionState,
    target_name::String,
    target_kind::String,
    content::String,
    line_start::Int,
    line_end::Int,
    target_line_start::Int,
    target_line_end::Int,
    context::JuliaScopeContext,
)
    entry = Dict{String,Any}(
        "target_name" => target_name,
        "target_kind" => target_kind,
        "content" => content,
        "line_start" => line_start,
        "line_end" => line_end,
        "target_line_start" => target_line_start,
        "target_line_end" => target_line_end,
    )
    merge!(entry, _julia_scope_metadata(context))
    push!(state.docstrings, entry)
    metadata = _julia_scope_metadata(context)
    metadata["target_name"] = target_name
    metadata["target_kind"] = target_kind
    if target_kind == "module"
        target_path =
            isnothing(context.module_path) ? target_name :
            "$(context.module_path).$(target_name)"
        entry["module_name"] = target_name
        entry["module_path"] = target_path
        entry["target_path"] = target_path
        metadata["module_name"] = target_name
        metadata["module_path"] = target_path
        metadata["target_path"] = target_path
    elseif !isnothing(context.owner_path)
        entry["target_path"] = "$(context.owner_path).$(target_name)"
        metadata["target_path"] = "$(context.owner_path).$(target_name)"
    else
        entry["target_path"] = target_name
        metadata["target_path"] = target_name
    end
    _push_ast_node!(
        state,
        "docstring",
        target_name;
        text = content,
        line_start = line_start,
        line_end = line_end,
        target_line_start = target_line_start,
        target_line_end = target_line_end,
        metadata = metadata,
    )
    return nothing
end

function _push_include!(
    state::JuliaCollectionState,
    include_literal::String,
    line_start::Int,
    line_end::Int,
    context::JuliaScopeContext,
)
    include_key = (include_literal, _julia_scope_key(context))
    include_key in state.include_set && return nothing
    push!(state.include_set, include_key)
    include_entry = Dict{String,Any}(
        "path" => include_literal,
        "line_start" => line_start,
        "line_end" => line_end,
    )
    merge!(include_entry, _julia_scope_metadata(context))
    push!(state.includes, include_entry)
    metadata = _julia_scope_metadata(context)
    metadata["path"] = include_literal
    _push_ast_node!(
        state,
        "include",
        include_literal;
        text = include_literal,
        line_start = line_start,
        line_end = line_end,
        metadata = metadata,
    )
    return nothing
end

function _push_ast_node!(
    state::JuliaCollectionState,
    node_kind::String,
    name::String;
    text::Union{Nothing,String} = nothing,
    line_start::Union{Nothing,Int} = nothing,
    line_end::Union{Nothing,Int} = nothing,
    target_line_start::Union{Nothing,Int} = nothing,
    target_line_end::Union{Nothing,Int} = nothing,
    signature::Union{Nothing,String} = nothing,
    metadata = nothing,
)
    node = Dict{String,Any}(
        "node_kind" => node_kind,
        "name" => name,
        "text" => text,
        "line_start" => line_start,
        "line_end" => line_end,
        "target_line_start" => target_line_start,
        "target_line_end" => target_line_end,
        "signature" => signature,
        "metadata" =>
            isnothing(metadata) ? Dict{String,Any}() : Dict{String,Any}(metadata),
    )
    push!(state.nodes, node)
    return nothing
end
