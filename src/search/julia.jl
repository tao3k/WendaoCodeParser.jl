function search_julia_ast(request::ParserRequest)
    try
        query = _parse_ast_query(request)
        state = collect_julia_state(request.source_text)
        matches = _filter_ast_nodes(state.nodes, query)
        return ParserResponse(
            request.request_id,
            request.source_id,
            "julia_ast_query",
            "JuliaSyntax.jl";
            success = true,
            primary_name = state.module_name,
            match_count = length(matches),
            matches = matches,
        )
    catch error
        return ParserResponse(
            request.request_id,
            request.source_id,
            "julia_ast_query",
            "JuliaSyntax.jl";
            success = false,
            error_message = sprint(showerror, error),
        )
    end
end
