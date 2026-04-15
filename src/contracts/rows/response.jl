const PARSER_RESPONSE_PARTITION_ROW_LIMIT = 512

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
        _parser_response_row_source(
            rows;
            schema_version = WENDAOCODEPARSER_SCHEMA_VERSION,
            metadata = merged_metadata,
        );
        schema_version = WENDAOCODEPARSER_SCHEMA_VERSION,
        metadata = merged_metadata,
    )
end

function _parser_response_row_source(
    rows::AbstractVector{<:NamedTuple};
    schema_version::AbstractString,
    metadata,
)
    length(rows) <= PARSER_RESPONSE_PARTITION_ROW_LIMIT && return Tables.rowtable(rows)
    partitions = [
        WendaoArrow.schema_table(
            Tables.rowtable(collect(chunk));
            schema_version = schema_version,
            metadata = metadata,
        ) for
        chunk in Iterators.partition(rows, PARSER_RESPONSE_PARTITION_ROW_LIMIT)
    ]
    return Tables.partitioner(partitions)
end
