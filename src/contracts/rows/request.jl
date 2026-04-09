function parser_request_row(request::ParserRequest)
    return (
        request_id = request.request_id,
        source_id = request.source_id,
        source_text = request.source_text,
    )
end

function parser_request_row(route_name::Symbol, request::ParserRequest)
    _is_ast_query_route(route_name) || return parser_request_row(request)
    return (
        request_id = request.request_id,
        source_id = request.source_id,
        source_text = request.source_text,
        node_kind = something(request.node_kind, missing),
        name_equals = something(request.name_equals, missing),
        name_contains = something(request.name_contains, missing),
        text_contains = something(request.text_contains, missing),
        signature_contains = something(request.signature_contains, missing),
        attribute_key = something(request.attribute_key, missing),
        attribute_equals = something(request.attribute_equals, missing),
        attribute_contains = something(request.attribute_contains, missing),
        limit = something(request.limit, missing),
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
