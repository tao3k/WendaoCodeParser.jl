function parse_modelica_file_summary(request::ParserRequest)
    try
        state = _collect_modelica_state(request.source_text, request.source_id)
        payload = Dict(
            "class_name" => state.primary_class,
            "restriction" => state.restriction,
            "imports" => state.imports,
            "extends" => state.extends,
            "symbols" => state.symbols,
            "documentation" => state.documentation,
        )
        return ParserResponse(
            request.request_id,
            request.source_id,
            "modelica_file_summary",
            "OMParser.jl";
            success = true,
            primary_name = state.primary_class,
            payload_json = JSON3.write(payload),
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
