function _parser_responses_for_route(
    route_name::Symbol,
    requests::AbstractVector{ParserRequest},
)
    if route_name == JULIA_FILE_SUMMARY_ROUTE
        return parse_julia_file_summary.(requests)
    elseif route_name == JULIA_ROOT_SUMMARY_ROUTE
        return parse_julia_root_summary.(requests)
    elseif route_name == MODELICA_FILE_SUMMARY_ROUTE
        return parse_modelica_file_summary.(requests)
    elseif route_name == JULIA_AST_QUERY_ROUTE
        return search_julia_ast.(requests)
    elseif route_name == MODELICA_AST_QUERY_ROUTE
        return search_modelica_ast.(requests)
    end
    error("unsupported WendaoCodeParser service route: $(String(route_name))")
end

function build_parser_table_processor(route_name::Symbol)
    return function (table_like)
        requests = _parser_requests_for_route(route_name, Tables.columntable(table_like))
        responses = _parser_responses_for_route(route_name, requests)
        return parser_response_arrow_table(route_name, responses)
    end
end

function build_parser_flight_service(route_name::Symbol)
    processor = build_parser_table_processor(route_name)
    return WendaoArrow.build_flight_service(
        processor;
        descriptor = parser_route_descriptor(route_name),
        expected_schema_version = WENDAOCODEPARSER_SCHEMA_VERSION,
    )
end

_optional_request_text(value) = ismissing(value) ? nothing : String(value)
_optional_request_int(value) = ismissing(value) ? nothing : Int(value)
supported_parser_route_names() = collect(PARSER_ROUTE_NAMES)

function _parser_requests_for_route(route_name::Symbol, columns)
    if route_name == JULIA_AST_QUERY_ROUTE || route_name == MODELICA_AST_QUERY_ROUTE
        _parser_has_ast_query_columns(columns) ||
            error("AST query routes require typed query columns")
        return ParserRequest[
            ParserRequest(
                String(columns.request_id[index]),
                String(columns.source_id[index]),
                String(columns.source_text[index]);
                node_kind = _optional_request_text(columns.node_kind[index]),
                name_equals = _optional_request_text(columns.name_equals[index]),
                name_contains = _optional_request_text(columns.name_contains[index]),
                text_contains = _optional_request_text(columns.text_contains[index]),
                limit = _optional_request_int(columns.limit[index]),
            ) for index = 1:length(columns.request_id)
        ]
    end

    return ParserRequest[
        ParserRequest(
            String(columns.request_id[index]),
            String(columns.source_id[index]),
            String(columns.source_text[index]);
        ) for index = 1:length(columns.request_id)
    ]
end

function _parser_has_ast_query_columns(columns)
    column_names = propertynames(columns)
    return :node_kind in column_names &&
           :name_equals in column_names &&
           :name_contains in column_names &&
           :text_contains in column_names &&
           :limit in column_names
end
