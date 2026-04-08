function parser_request_row(request::ParserRequest)
    return (
        request_id = request.request_id,
        source_id = request.source_id,
        source_text = request.source_text,
        query_json = something(request.query_json, missing),
    )
end

function parser_request_row(route_name::Symbol, request::ParserRequest)
    _is_ast_query_route(route_name) || return parser_request_row(request)
    return (
        request_id = request.request_id,
        source_id = request.source_id,
        source_text = request.source_text,
        node_kind = something(_parser_request_query_value(request, :node_kind), missing),
        name_equals = something(
            _parser_request_query_value(request, :name_equals),
            missing,
        ),
        name_contains = something(
            _parser_request_query_value(request, :name_contains),
            missing,
        ),
        text_contains = something(
            _parser_request_query_value(request, :text_contains),
            missing,
        ),
        limit = something(_parser_request_query_limit(request), missing),
    )
end

function parser_request_arrow_table(requests::AbstractVector{ParserRequest})
    rows = parser_request_row.(requests)
    return WendaoArrow.schema_table(
        Tables.rowtable(rows);
        schema_version = WENDAOCODEPARSER_SCHEMA_VERSION,
        metadata = Dict(
            "x-wendao-code-parser-payload-kind" => "request",
            "x-wendao-code-parser-contract-shape" => "source_text",
        ),
    )
end

function parser_request_arrow_table(
    route_name::Symbol,
    requests::AbstractVector{ParserRequest},
)
    rows = parser_request_row.(Ref(route_name), requests)
    contract_shape = _is_ast_query_route(route_name) ? "ast_query" : "source_text"
    return WendaoArrow.schema_table(
        Tables.rowtable(rows);
        schema_version = WENDAOCODEPARSER_SCHEMA_VERSION,
        metadata = Dict(
            "x-wendao-code-parser-payload-kind" => "request",
            "x-wendao-code-parser-contract-shape" => contract_shape,
        ),
    )
end

function parser_response_row(response::ParserResponse)
    return (
        request_id = response.request_id,
        source_id = response.source_id,
        summary_kind = response.summary_kind,
        backend = response.backend,
        success = response.success,
        primary_name = something(response.primary_name, missing),
        payload_json = something(response.payload_json, missing),
        error_message = something(response.error_message, missing),
    )
end

function parser_response_arrow_table(
    responses::AbstractVector{ParserResponse};
    metadata = nothing,
)
    rows = parser_response_row.(responses)
    merged_metadata =
        isnothing(metadata) ? Dict{String,String}() : Dict{String,String}(metadata)
    merged_metadata["x-wendao-code-parser-payload-kind"] = "response"
    return WendaoArrow.schema_table(
        Tables.rowtable(rows);
        schema_version = WENDAOCODEPARSER_SCHEMA_VERSION,
        metadata = merged_metadata,
    )
end

function parser_response_arrow_table(
    route_name::Symbol,
    responses::AbstractVector{ParserResponse};
    metadata = nothing,
)
    _is_ast_query_route(route_name) ||
        return parser_response_arrow_table(responses; metadata = metadata)

    rows = NamedTuple[]
    for response in responses
        append!(rows, _parser_ast_response_rows(response))
    end
    merged_metadata =
        isnothing(metadata) ? Dict{String,String}() : Dict{String,String}(metadata)
    merged_metadata["x-wendao-code-parser-payload-kind"] = "response"
    merged_metadata["x-wendao-code-parser-contract-shape"] = "ast_match_rows"
    return WendaoArrow.schema_table(
        Tables.rowtable(rows);
        schema_version = WENDAOCODEPARSER_SCHEMA_VERSION,
        metadata = merged_metadata,
    )
end

function _parser_ast_response_rows(response::ParserResponse)
    base_row = (
        request_id = response.request_id,
        source_id = response.source_id,
        summary_kind = response.summary_kind,
        backend = response.backend,
        success = response.success,
        primary_name = something(response.primary_name, missing),
        match_count = something(response.match_count, 0),
        error_message = something(response.error_message, missing),
    )
    if !response.success || isempty(response.matches)
        return [
            merge(
                base_row,
                (
                    match_index = missing,
                    match_node_kind = missing,
                    match_name = missing,
                    match_text = missing,
                    match_signature = missing,
                    match_line_start = missing,
                    match_line_end = missing,
                ),
            ),
        ]
    end

    rows = NamedTuple[]
    for (index, match) in enumerate(response.matches)
        push!(
            rows,
            merge(
                base_row,
                (
                    match_index = index,
                    match_node_kind = _parser_match_value(match, "node_kind"),
                    match_name = _parser_match_value(match, "name"),
                    match_text = _parser_match_value(match, "text"),
                    match_signature = _parser_match_value(match, "signature"),
                    match_line_start = _parser_match_int(match, "line_start"),
                    match_line_end = _parser_match_int(match, "line_end"),
                ),
            ),
        )
    end
    return rows
end

function _parser_match_value(match::AbstractDict{String,Any}, key::AbstractString)
    value = get(match, String(key), nothing)
    return isnothing(value) ? missing : String(value)
end

function _parser_match_int(match::AbstractDict{String,Any}, key::AbstractString)
    value = get(match, String(key), nothing)
    return isnothing(value) ? missing : Int(value)
end

function _parser_request_query_value(request::ParserRequest, field::Symbol)
    if _parser_request_has_typed_query(request)
        return getproperty(request, field)
    end
    isnothing(request.query_json) && return nothing
    parsed = JSON3.read(request.query_json)
    return hasproperty(parsed, field) ? getproperty(parsed, field) : nothing
end

function _parser_request_query_limit(request::ParserRequest)
    value = _parser_request_query_value(request, :limit)
    return isnothing(value) ? nothing : Int(value)
end

function _parser_request_has_typed_query(request::ParserRequest)
    return !isnothing(request.node_kind) ||
           !isnothing(request.name_equals) ||
           !isnothing(request.name_contains) ||
           !isnothing(request.text_contains) ||
           !isnothing(request.limit)
end

_is_ast_query_route(route_name::Symbol) =
    route_name == JULIA_AST_QUERY_ROUTE || route_name == MODELICA_AST_QUERY_ROUTE
