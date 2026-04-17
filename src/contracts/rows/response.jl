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
            _parser_response_partition_table(collect(chunk));
            schema_version = schema_version,
            metadata = metadata,
        ) for chunk in Iterators.partition(rows, PARSER_RESPONSE_PARTITION_ROW_LIMIT)
    ]
    return Tables.partitioner(partitions)
end

function _parser_response_partition_table(rows::AbstractVector{<:NamedTuple})
    names = fieldnames(typeof(first(rows)))
    columns = map(name -> _parser_response_partition_column(rows, name), names)
    return NamedTuple{names}(Tuple(columns))
end

function _parser_response_partition_column(rows::AbstractVector{<:NamedTuple}, name::Symbol)
    column_type = Union{}
    for row in rows
        column_type = typejoin(column_type, typeof(getproperty(row, name)))
    end
    column = Vector{column_type}(undef, length(rows))
    for (index, row) in pairs(rows)
        column[index] = getproperty(row, name)
    end

    # Rust Arrow panics on some all-null Boolean buffers emitted from row-wise
    # partition inference. Canonicalize all-missing optional columns to Null.
    all(ismissing, column) && return fill(missing, length(column))
    return column
end
