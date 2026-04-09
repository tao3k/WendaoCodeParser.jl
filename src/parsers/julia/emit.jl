function _push_export!(
    state::JuliaCollectionState,
    export_name::String,
    line_start::Int,
    line_end::Int,
)
    export_name in state.export_set && return nothing
    push!(state.export_set, export_name)
    push!(
        state.exports,
        Dict{String,Any}(
            "name" => export_name,
            "line_start" => line_start,
            "line_end" => line_end,
        ),
    )
    _push_ast_node!(
        state,
        "export",
        export_name;
        text = export_name,
        line_start = line_start,
        line_end = line_end,
        metadata = Dict("name" => export_name),
    )
    return nothing
end

function _push_import!(
    state::JuliaCollectionState,
    import_name::String,
    line_start::Int,
    line_end::Int;
    reexported::Bool = false,
)
    existing_index =
        findfirst(entry -> String(entry["module"]) == import_name, state.imports)
    if !isnothing(existing_index)
        if reexported && !Bool(get(state.imports[existing_index], "reexported", false))
            state.imports[existing_index]["reexported"] = true
            for node in Iterators.reverse(state.nodes)
                if get(node, "node_kind", nothing) == "import" &&
                   get(node, "name", nothing) == import_name
                    node_metadata = get(node, "metadata", Dict{String,Any}())
                    node_metadata["reexported"] = true
                    node["metadata"] = node_metadata
                    break
                end
            end
        end
        return nothing
    end

    push!(state.import_set, import_name)
    entry = Dict{String,Any}(
        "module" => import_name,
        "reexported" => reexported,
        "line_start" => line_start,
        "line_end" => line_end,
    )
    push!(state.imports, entry)
    _push_ast_node!(
        state,
        "import",
        import_name;
        text = import_name,
        line_start = line_start,
        line_end = line_end,
        metadata = Dict("module" => import_name, "reexported" => reexported),
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
)
    symbol_key = (symbol_name, symbol_kind)
    symbol_key in state.symbol_set && return nothing
    push!(state.symbol_set, symbol_key)
    entry = Dict{String,Any}(
        "name" => symbol_name,
        "kind" => symbol_kind,
        "signature" => String(signature),
        "line_start" => line_start,
        "line_end" => line_end,
    )
    push!(state.symbols, entry)
    _push_ast_node!(
        state,
        symbol_kind,
        symbol_name;
        text = String(signature),
        line_start = line_start,
        line_end = line_end,
        signature = String(signature),
        metadata = Dict("name" => symbol_name, "kind" => symbol_kind),
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
    push!(state.docstrings, entry)
    _push_ast_node!(
        state,
        "docstring",
        target_name;
        text = content,
        line_start = line_start,
        line_end = line_end,
        target_line_start = target_line_start,
        target_line_end = target_line_end,
        metadata = Dict("target_name" => target_name, "target_kind" => target_kind),
    )
    return nothing
end

function _push_include!(
    state::JuliaCollectionState,
    include_literal::String,
    line_start::Int,
    line_end::Int,
)
    include_literal in state.include_set && return nothing
    push!(state.include_set, include_literal)
    push!(
        state.includes,
        Dict{String,Any}(
            "path" => include_literal,
            "line_start" => line_start,
            "line_end" => line_end,
        ),
    )
    _push_ast_node!(
        state,
        "include",
        include_literal;
        text = include_literal,
        line_start = line_start,
        line_end = line_end,
        metadata = Dict("path" => include_literal),
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
