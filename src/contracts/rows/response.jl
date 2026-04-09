function parser_response_arrow_table(
    responses::AbstractVector{ParserResponse};
    metadata = nothing,
)
    isempty(responses) &&
        error("WendaoCodeParser response tables require at least one response")
    route_name = _summary_kind_route_name(first(responses).summary_kind)
    return parser_response_arrow_table(route_name, responses; metadata = metadata)
end

function parser_response_arrow_table(
    route_name::Symbol,
    responses::AbstractVector{ParserResponse};
    metadata = nothing,
)
    rows = if _is_ast_query_route(route_name)
        _parser_ast_response_rows(responses)
    else
        _parser_summary_response_rows(responses)
    end
    merged_metadata =
        isnothing(metadata) ? Dict{String,String}() : Dict{String,String}(metadata)
    merged_metadata["x-wendao-code-parser-payload-kind"] = "response"
    merged_metadata["x-wendao-code-parser-contract-shape"] =
        _is_ast_query_route(route_name) ? "ast_match_rows" : "summary_item_rows"
    return WendaoArrow.schema_table(
        Tables.rowtable(rows);
        schema_version = WENDAOCODEPARSER_SCHEMA_VERSION,
        metadata = merged_metadata,
    )
end
