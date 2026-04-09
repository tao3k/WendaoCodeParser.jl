function parse_modelica_file_summary(request::ParserRequest)
    try
        state = collect_modelica_state(request.source_text, request.source_id)
        return ParserResponse(
            request.request_id,
            request.source_id,
            "modelica_file_summary",
            "OMParser.jl";
            success = true,
            primary_name = state.primary_class,
            summary_scalars = Dict(
                "class_name" => state.primary_class,
                "restriction" => state.restriction,
            ),
            summary_items = _modelica_summary_items(state),
        )
    catch error
        return ParserResponse(
            request.request_id,
            request.source_id,
            "modelica_file_summary",
            "OMParser.jl";
            success = false,
            error_message = sprint(showerror, error),
        )
    end
end

function _modelica_summary_items(state::ModelicaCollectionState)
    items = Dict{String,Any}[]
    append!(items, _modelica_dependency_summary_items(state))
    append!(
        items,
        [
            let metadata = get(entry, "metadata", Dict{String,Any}())
                Dict(
                    "group" => "symbol",
                    "name" => String(entry["name"]),
                    "kind" => String(entry["kind"]),
                    "signature" => String(entry["signature"]),
                    "visibility" => get(metadata, "visibility", nothing),
                    "type_name" => get(metadata, "type_name", nothing),
                    "variability" => get(metadata, "variability", nothing),
                    "direction" => get(metadata, "direction", nothing),
                    "component_kind" => get(metadata, "component_kind", nothing),
                    "array_dimensions" => get(metadata, "array_dimensions", nothing),
                    "default_value" => get(metadata, "default_value", nothing),
                    "start_value" => get(metadata, "start_value", nothing),
                    "modifier_names" => get(metadata, "modifier_names", nothing),
                    "unit" => get(metadata, "unit", nothing),
                    "owner_name" => get(metadata, "owner_name", nothing),
                    "owner_path" => get(metadata, "owner_path", nothing),
                    "class_path" => get(metadata, "class_path", nothing),
                    "top_level" => get(metadata, "top_level", nothing),
                    "line_start" => get(entry, "line_start", nothing),
                    "line_end" => get(entry, "line_end", nothing),
                    "is_partial" => get(metadata, "is_partial", nothing),
                    "is_final" => get(metadata, "is_final", nothing),
                    "is_encapsulated" => get(metadata, "is_encapsulated", nothing),
                )
            end for entry in state.symbols
        ],
    )
    append!(
        items,
        [
            Dict(
                "group" => "equation",
                "name" => String(get(entry, "owner_name", "")),
                "kind" => "equation",
                "text" => String(entry["text"]),
                "owner_name" => String(get(entry, "owner_name", "")),
                "owner_path" => get(entry, "owner_path", nothing),
                "line_start" => get(entry, "line_start", nothing),
                "line_end" => get(entry, "line_end", nothing),
            ) for entry in state.equations
        ],
    )
    append!(
        items,
        [
            Dict("group" => "documentation", "content" => content) for
            content in state.documentation
        ],
    )
    return items
end
