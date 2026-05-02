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

const CODE_PARSER_WARMUP_JULIA_SOURCE = """
module WarmupCodeParser
foo(x)=x
export foo
end
"""

const CODE_PARSER_WARMUP_MODELICA_SOURCE = """
model WarmupCodeParser
end WarmupCodeParser;
"""

const CODE_PARSER_WARMUP_MODELICA_AST_SOURCE = """
within Modelica;
package WarmupCodeParser
  import SI = Modelica.Units.SI;
  extends Icons.Package;

  block Controller
    parameter Real k = 1;
    input Real u;
    output Real y;
  equation
    y = k * u;
  end Controller;

  model Plant
    SI.Time t(start = 0);
    Controller c;
  end Plant;

  package Types
    type Gain = Real(unit = "1");
  end Types;
end WarmupCodeParser;
"""

struct ParserServiceListenerConfig
    max_active_requests::Int
    request_capacity::Int
    response_capacity::Int
end

function ParserServiceListenerConfig(;
    max_active_requests::Integer = max(Threads.nthreads() * 8, 32),
    request_capacity::Integer = 16,
    response_capacity::Integer = 16,
)
    max_active_requests > 0 ||
        error("WendaoCodeParser listener max_active_requests must be greater than zero")
    request_capacity > 0 ||
        error("WendaoCodeParser listener request_capacity must be greater than zero")
    response_capacity > 0 ||
        error("WendaoCodeParser listener response_capacity must be greater than zero")
    return ParserServiceListenerConfig(
        Int(max_active_requests),
        Int(request_capacity),
        Int(response_capacity),
    )
end

function parser_service_route_names(args::Vector{String})
    route_name = nothing
    route_names = nothing
    index = 1

    while index <= length(args)
        argument = args[index]
        if startswith(argument, "--code-parser-route-name=")
            route_name = split(argument, "=", limit = 2)[2]
        elseif argument == "--code-parser-route-name"
            index += 1
            index > length(args) && error(
                "WendaoCodeParser service requires one value after --code-parser-route-name",
            )
            route_name = args[index]
        elseif startswith(argument, "--code-parser-route-names=") ||
               startswith(argument, "--code-parser-routes=")
            route_names = split(argument, "=", limit = 2)[2]
        elseif argument == "--code-parser-route-names" || argument == "--code-parser-routes"
            index += 1
            index > length(args) && error(
                "WendaoCodeParser service requires one value after --code-parser-route-names",
            )
            route_names = args[index]
        end
        index += 1
    end

    (!isnothing(route_name) && !isnothing(route_names)) && error(
        "WendaoCodeParser service must not set both code_parser route_name and route_names",
    )
    isnothing(route_name) && isnothing(route_names) && return Symbol[]
    return _resolved_parser_service_route_names(something(route_name, route_names))
end

function parser_service_listener_config(args::Vector{String})
    defaults = ParserServiceListenerConfig()
    max_active_requests = defaults.max_active_requests
    request_capacity = defaults.request_capacity
    response_capacity = defaults.response_capacity
    index = 1

    while index <= length(args)
        argument = args[index]
        if startswith(argument, "--max-active-requests=")
            max_active_requests = Base.parse(Int, split(argument, "=", limit = 2)[2])
        elseif argument == "--max-active-requests"
            index += 1
            index > length(args) && error(
                "WendaoCodeParser service requires one value after --max-active-requests",
            )
            max_active_requests = Base.parse(Int, args[index])
        elseif startswith(argument, "--request-capacity=")
            request_capacity = Base.parse(Int, split(argument, "=", limit = 2)[2])
        elseif argument == "--request-capacity"
            index += 1
            index > length(args) && error(
                "WendaoCodeParser service requires one value after --request-capacity",
            )
            request_capacity = Base.parse(Int, args[index])
        elseif startswith(argument, "--response-capacity=")
            response_capacity = Base.parse(Int, split(argument, "=", limit = 2)[2])
        elseif argument == "--response-capacity"
            index += 1
            index > length(args) && error(
                "WendaoCodeParser service requires one value after --response-capacity",
            )
            response_capacity = Base.parse(Int, args[index])
        end
        index += 1
    end

    return ParserServiceListenerConfig(
        max_active_requests = max_active_requests,
        request_capacity = request_capacity,
        response_capacity = response_capacity,
    )
end

function parser_service_flight_server_kwargs(listener::ParserServiceListenerConfig)
    return (
        max_active_requests = listener.max_active_requests,
        request_capacity = listener.request_capacity,
        response_capacity = listener.response_capacity,
    )
end

function parser_service_interface_args(args::Vector{String})
    filtered = String[]
    index = 1
    while index <= length(args)
        argument = args[index]
        if startswith(argument, "--code-parser-route-name=") ||
           startswith(argument, "--code-parser-route-names=") ||
           startswith(argument, "--code-parser-routes=")
            nothing
        elseif argument == "--code-parser-route-name" ||
               argument == "--code-parser-route-names" ||
               argument == "--code-parser-routes" ||
               argument == "--max-active-requests" ||
               argument == "--request-capacity" ||
               argument == "--response-capacity"
            index += 1
            index > length(args) &&
                error("WendaoCodeParser service requires one value after $(argument)")
        elseif startswith(argument, "--max-active-requests=") ||
               startswith(argument, "--request-capacity=") ||
               startswith(argument, "--response-capacity=")
            nothing
        else
            push!(filtered, argument)
        end
        index += 1
    end
    return filtered
end

function build_parser_live_flight_service(route_names = Symbol[])
    parser_routes = _resolved_parser_service_route_names(route_names)
    isempty(parser_routes) &&
        error("WendaoCodeParser live service requires at least one parser route")
    _prewarm_modelica_backend_if_needed(parser_routes)
    length(parser_routes) == 1 && return build_parser_flight_service(only(parser_routes))

    route_entries = Dict{Tuple,NamedTuple}()
    for route_name in parser_routes
        route_entries[_descriptor_path_key(parser_route_descriptor(route_name))] = (
            processor = build_parser_table_processor(route_name),
            expected_schema_version = WENDAOCODEPARSER_SCHEMA_VERSION,
            subject = "WendaoCodeParser parser-summary exchange request",
        )
    end

    return _build_routed_parser_live_flight_service(
        route_entries;
        missing_descriptor_message = "WendaoCodeParser live service requires one Flight descriptor",
        unsupported_descriptor_prefix = "unsupported WendaoCodeParser descriptor path",
    )
end

function warm_parser_live_flight_service(
    service::WendaoArrow.Arrow.Flight.Service,
    route_names = Symbol[],
)
    parser_routes = _resolved_parser_service_route_names(route_names)
    isempty(parser_routes) &&
        error("WendaoCodeParser live warmup requires at least one parser route")
    for route_name in parser_routes
        _warm_parser_flight_service(service, route_name)
    end
    return nothing
end

function _build_routed_parser_live_flight_service(
    route_entries;
    missing_descriptor_message::AbstractString,
    unsupported_descriptor_prefix::AbstractString,
)
    return WendaoArrow.Arrow.Flight.exchangeservice(
        function (incoming_messages, request_descriptor, _)
            descriptor_path =
                isnothing(request_descriptor) ? nothing : request_descriptor.path
            table_like = try
                WendaoArrow.Arrow.Flight.table(incoming_messages; convert = true)
            catch error
                @error "WendaoCodeParser routed Flight service failed to decode request" exception =
                    (error, catch_backtrace()) descriptor_path = descriptor_path
                rethrow()
            end

            isnothing(request_descriptor) && error(missing_descriptor_message)
            requested_path = _descriptor_path_key(request_descriptor)
            route_entry = get(route_entries, requested_path, nothing)
            isnothing(route_entry) &&
                error("$(unsupported_descriptor_prefix): $(join(requested_path, "/"))")

            try
                WendaoArrow.require_schema_version(
                    table_like;
                    subject = route_entry.subject,
                    expected = route_entry.expected_schema_version,
                )
                return (
                    output_table = route_entry.processor(table_like),
                    schema_version = route_entry.expected_schema_version,
                    subject = route_entry.subject,
                )
            catch error
                @error "WendaoCodeParser routed Flight processor failed" exception =
                    (error, catch_backtrace()) descriptor_path = request_descriptor.path subject =
                    route_entry.subject
                rethrow()
            end
        end;
        writer = function (response, routed_output, request_descriptor, _)
            descriptor_path =
                isnothing(request_descriptor) ? nothing : request_descriptor.path
            try
                return WendaoArrow.Arrow.Flight.putflightdata!(
                    response,
                    routed_output.output_table;
                    metadata = WendaoArrow.merge_schema_metadata(
                        WendaoArrow.schema_metadata(routed_output.output_table);
                        schema_version = routed_output.schema_version,
                    ),
                )
            catch error
                @error "WendaoCodeParser routed Flight service failed to encode response" exception =
                    (error, catch_backtrace()) descriptor_path = descriptor_path subject =
                    routed_output.subject
                rethrow()
            end
        end,
    )
end

function _resolved_parser_service_route_names(route_names)
    isnothing(route_names) && return Symbol[]
    raw_values =
        route_names isa AbstractVector ? collect(route_names) :
        split(String(route_names), ',')
    isempty(raw_values) && return Symbol[]

    normalized = Symbol[]
    for raw_value in raw_values
        route_text = lowercase(strip(String(raw_value)))
        isempty(route_text) &&
            error("WendaoCodeParser route_names must not contain blanks")
        if route_text in ("all", "multi", "full")
            append!(normalized, supported_parser_route_names())
        else
            push!(normalized, _normalized_parser_service_route_name(route_text))
        end
    end
    return unique(normalized)
end

function _normalized_parser_service_route_name(route_name)
    route_text = lowercase(strip(String(route_name)))
    isempty(route_text) && error("WendaoCodeParser route_name must not be blank")
    if route_text in
       ("julia_file_summary", "julia-file-summary", "julia-file", "julia_summary")
        return JULIA_FILE_SUMMARY_ROUTE
    elseif route_text in ("julia_root_summary", "julia-root-summary", "julia-root")
        return JULIA_ROOT_SUMMARY_ROUTE
    elseif route_text in (
        "modelica_file_summary",
        "modelica-file-summary",
        "modelica-file",
        "modelica_summary",
    )
        return MODELICA_FILE_SUMMARY_ROUTE
    elseif route_text in ("julia_ast_query", "julia-ast-query", "julia-query")
        return JULIA_AST_QUERY_ROUTE
    elseif route_text in ("modelica_ast_query", "modelica-ast-query", "modelica-query")
        return MODELICA_AST_QUERY_ROUTE
    end
    error("unsupported WendaoCodeParser route_name: $(route_name)")
end

function _warm_parser_flight_service(
    service::WendaoArrow.Arrow.Flight.Service,
    route_name::Symbol,
)
    request = _warm_parser_exchange_request(route_name)
    WendaoArrow.flight_exchange_table(
        service,
        WendaoArrow.Arrow.Flight.ServerCallContext(),
        request,
    )
    return nothing
end

function _prewarm_modelica_backend_if_needed(route_names::AbstractVector{Symbol})
    any(_is_modelica_parser_route, route_names) || return nothing
    prewarm_modelica_backend!()
    return nothing
end

_is_modelica_parser_route(route_name::Symbol) =
    route_name == MODELICA_FILE_SUMMARY_ROUTE || route_name == MODELICA_AST_QUERY_ROUTE

function _warm_parser_exchange_request(route_name::Symbol)
    if route_name == JULIA_FILE_SUMMARY_ROUTE
        requests = [
            ParserRequest(
                "warmup-julia-file-summary",
                "WarmupCodeParser.jl",
                CODE_PARSER_WARMUP_JULIA_SOURCE,
            ),
        ]
    elseif route_name == JULIA_ROOT_SUMMARY_ROUTE
        requests = [
            ParserRequest(
                "warmup-julia-root-summary",
                "WarmupCodeParser.jl",
                CODE_PARSER_WARMUP_JULIA_SOURCE,
            ),
        ]
    elseif route_name == MODELICA_FILE_SUMMARY_ROUTE
        requests = [
            ParserRequest(
                "warmup-modelica-file-summary",
                "WarmupCodeParser.mo",
                CODE_PARSER_WARMUP_MODELICA_SOURCE,
            ),
        ]
    elseif route_name == JULIA_AST_QUERY_ROUTE
        requests = [
            ParserRequest(
                "warmup-julia-ast-query",
                "WarmupCodeParser.jl",
                CODE_PARSER_WARMUP_JULIA_SOURCE;
                node_kind = "function",
                limit = 1,
            ),
        ]
    elseif route_name == MODELICA_AST_QUERY_ROUTE
        requests = [
            ParserRequest(
                "warmup-modelica-ast-query",
                "WarmupCodeParser/package.mo",
                CODE_PARSER_WARMUP_MODELICA_AST_SOURCE;
                limit = 64,
            ),
        ]
    else
        error("unsupported WendaoCodeParser route_name: $(route_name)")
    end
    return parser_exchange_request(route_name, requests)
end

function _descriptor_path_key(descriptor)
    return Tuple(String(segment) for segment in descriptor.path)
end

function _optional_request_text(columns, column_name::Symbol, index::Int)
    column_name in propertynames(columns) || return nothing
    return _optional_request_text(getproperty(columns, column_name)[index])
end

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
                signature_contains = _optional_request_text(
                    columns,
                    :signature_contains,
                    index,
                ),
                attribute_key = _optional_request_text(columns, :attribute_key, index),
                attribute_equals = _optional_request_text(
                    columns,
                    :attribute_equals,
                    index,
                ),
                attribute_contains = _optional_request_text(
                    columns,
                    :attribute_contains,
                    index,
                ),
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
