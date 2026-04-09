function parse_julia_file_summary(request::ParserRequest)
    try
        state = collect_julia_state(request.source_text)
        return _julia_summary_response(request, "julia_file_summary", state)
    catch error
        return _julia_failure_response(request, "julia_file_summary", error)
    end
end

function parse_julia_root_summary(request::ParserRequest)
    try
        state = collect_julia_state(request.source_text)
        isnothing(state.module_name) &&
            error("Julia root summary requires one root module declaration")
        return _julia_summary_response(request, "julia_root_summary", state)
    catch error
        return _julia_failure_response(request, "julia_root_summary", error)
    end
end

function _julia_summary_response(
    request::ParserRequest,
    summary_kind::AbstractString,
    state::JuliaCollectionState,
)
    return ParserResponse(
        request.request_id,
        request.source_id,
        summary_kind,
        "JuliaSyntax.jl";
        success = true,
        primary_name = state.module_name,
        summary_scalars = Dict("module_name" => state.module_name),
        summary_items = _julia_summary_items(state),
    )
end

function _julia_failure_response(
    request::ParserRequest,
    summary_kind::AbstractString,
    error,
)
    return ParserResponse(
        request.request_id,
        request.source_id,
        summary_kind,
        "JuliaSyntax.jl";
        success = false,
        error_message = sprint(showerror, error),
    )
end

function _julia_summary_items(state::JuliaCollectionState)
    items = Dict{String,Any}[]
    append!(
        items,
        [
            Dict(
                "group" => "export",
                "name" => String(entry["name"]),
                "line_start" => get(entry, "line_start", nothing),
                "line_end" => get(entry, "line_end", nothing),
            ) for entry in state.exports
        ],
    )
    append!(
        items,
        [
            Dict(
                "group" => "import",
                "module" => String(entry["module"]),
                "reexported" => Bool(get(entry, "reexported", false)),
                "line_start" => get(entry, "line_start", nothing),
                "line_end" => get(entry, "line_end", nothing),
            ) for entry in state.imports
        ],
    )
    append!(
        items,
        [
            Dict(
                "group" => "symbol",
                "name" => String(entry["name"]),
                "kind" => String(entry["kind"]),
                "signature" => String(entry["signature"]),
                "line_start" => get(entry, "line_start", nothing),
                "line_end" => get(entry, "line_end", nothing),
            ) for entry in state.symbols
        ],
    )
    append!(
        items,
        [
            Dict(
                "group" => "docstring",
                "name" => String(entry["target_name"]),
                "target_kind" => String(entry["target_kind"]),
                "content" => String(entry["content"]),
                "line_start" => get(entry, "line_start", nothing),
                "line_end" => get(entry, "line_end", nothing),
                "target_line_start" => get(entry, "target_line_start", nothing),
                "target_line_end" => get(entry, "target_line_end", nothing),
            ) for entry in state.docstrings
        ],
    )
    append!(
        items,
        [
            Dict(
                "group" => "include",
                "path" => String(entry["path"]),
                "line_start" => get(entry, "line_start", nothing),
                "line_end" => get(entry, "line_end", nothing),
            ) for entry in state.includes
        ],
    )
    return items
end
