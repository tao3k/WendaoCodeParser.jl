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
        summary_scalars = Dict(
            "module_name" => state.module_name,
            "module_kind" => state.module_kind,
        ),
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
                "owner_name" => get(entry, "owner_name", nothing),
                "owner_kind" => get(entry, "owner_kind", nothing),
                "module_name" => get(entry, "module_name", nothing),
                "module_path" => get(entry, "module_path", nothing),
                "owner_path" => get(entry, "owner_path", nothing),
                "line_start" => get(entry, "line_start", nothing),
                "line_end" => get(entry, "line_end", nothing),
            ) for entry in state.exports
        ],
    )
    append!(items, _julia_dependency_summary_items(state))
    append!(
        items,
        [
            Dict(
                "group" => "symbol",
                "name" => String(entry["name"]),
                "kind" => String(entry["kind"]),
                "signature" => String(entry["signature"]),
                "path" => get(entry, "path", nothing),
                "owner_name" => get(entry, "owner_name", nothing),
                "owner_kind" => get(entry, "owner_kind", nothing),
                "module_name" => get(entry, "module_name", nothing),
                "module_path" => get(entry, "module_path", nothing),
                "owner_path" => get(entry, "owner_path", nothing),
                "binding_kind" => get(entry, "binding_kind", nothing),
                "type_kind" => get(entry, "type_kind", nothing),
                "type_parameters" => get(entry, "type_parameters", nothing),
                "type_supertype" => get(entry, "type_supertype", nothing),
                "primitive_bits" => get(entry, "primitive_bits", nothing),
                "function_positional_arity" =>
                    get(entry, "function_positional_arity", nothing),
                "function_keyword_arity" => get(entry, "function_keyword_arity", nothing),
                "function_has_varargs" => get(entry, "function_has_varargs", nothing),
                "function_where_params" => get(entry, "function_where_params", nothing),
                "function_return_type" => get(entry, "function_return_type", nothing),
                "function_positional_params" =>
                    get(entry, "function_positional_params", nothing),
                "function_keyword_params" => get(entry, "function_keyword_params", nothing),
                "function_defaulted_params" =>
                    get(entry, "function_defaulted_params", nothing),
                "function_typed_params" => get(entry, "function_typed_params", nothing),
                "function_positional_vararg_name" =>
                    get(entry, "function_positional_vararg_name", nothing),
                "function_keyword_vararg_name" =>
                    get(entry, "function_keyword_vararg_name", nothing),
                "line_start" => get(entry, "line_start", nothing),
                "line_end" => get(entry, "line_end", nothing),
            ) for entry in state.symbols
        ],
    )
    append!(
        items,
        [
            Dict(
                "group" => "parameter",
                "name" => String(entry["name"]),
                "kind" => String(entry["kind"]),
                "text" => String(entry["text"]),
                "target_kind" => String(entry["target_kind"]),
                "path" => get(entry, "path", nothing),
                "parameter_kind" => get(entry, "parameter_kind", nothing),
                "parameter_type_name" => get(entry, "parameter_type_name", nothing),
                "parameter_default_value" => get(entry, "parameter_default_value", nothing),
                "parameter_is_typed" => get(entry, "parameter_is_typed", nothing),
                "parameter_is_defaulted" => get(entry, "parameter_is_defaulted", nothing),
                "parameter_is_vararg" => get(entry, "parameter_is_vararg", nothing),
                "owner_name" => get(entry, "owner_name", nothing),
                "owner_kind" => get(entry, "owner_kind", nothing),
                "module_name" => get(entry, "module_name", nothing),
                "module_path" => get(entry, "module_path", nothing),
                "owner_path" => get(entry, "owner_path", nothing),
                "target_path" => get(entry, "target_path", nothing),
                "line_start" => get(entry, "line_start", nothing),
                "line_end" => get(entry, "line_end", nothing),
            ) for entry in state.parameters
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
                "owner_name" => get(entry, "owner_name", nothing),
                "owner_kind" => get(entry, "owner_kind", nothing),
                "module_name" => get(entry, "module_name", nothing),
                "module_path" => get(entry, "module_path", nothing),
                "owner_path" => get(entry, "owner_path", nothing),
                "target_path" => get(entry, "target_path", nothing),
                "line_start" => get(entry, "line_start", nothing),
                "line_end" => get(entry, "line_end", nothing),
                "target_line_start" => get(entry, "target_line_start", nothing),
                "target_line_end" => get(entry, "target_line_end", nothing),
            ) for entry in state.docstrings
        ],
    )
    return items
end
