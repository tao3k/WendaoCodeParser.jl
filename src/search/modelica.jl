function search_modelica_ast(request::ParserRequest)
    try
        query = _parse_ast_query(request)
        state = collect_modelica_state(request.source_text, request.source_id)
        matches = _filter_ast_nodes(state.nodes, query)
        return ParserResponse(
            request.request_id,
            request.source_id,
            "modelica_ast_query",
            "OMParser.jl";
            success = true,
            primary_name = state.primary_class,
            match_count = length(matches),
            matches = matches,
        )
    catch error
        return ParserResponse(
            request.request_id,
            request.source_id,
            "modelica_ast_query",
            "OMParser.jl";
            success = false,
            error_message = sprint(showerror, error),
        )
    end
end
