function parser_route_descriptor(route_name::Symbol)
    route = parser_route(route_name)
    return WendaoArrow.flight_route_descriptor(
        route.path;
        subject = "WendaoCodeParser Flight descriptor",
    )
end

function parser_route_request_headers(
    route_name::Symbol;
    request_id = nothing,
    headers::AbstractVector{<:Pair} = Pair{String,String}[],
)
    route = parser_route(route_name)
    result = WendaoArrow.flight_schema_headers(
        schema_version = WENDAOCODEPARSER_SCHEMA_VERSION,
        headers = headers,
        subject = "WendaoCodeParser Flight request",
    )
    push!(result, "x-wendao-code-parser-route-name" => String(route.name))
    push!(result, "x-wendao-code-parser-route-path" => route.path)
    push!(result, "x-wendao-code-parser-summary-kind" => route.summary_kind)
    push!(result, "x-wendao-code-parser-backend" => route.backend)
    !isnothing(request_id) &&
        push!(result, "x-wendao-code-parser-request-id" => String(request_id))
    return result
end

function parser_exchange_request(
    route_name::Symbol,
    requests::AbstractVector{ParserRequest};
    headers::AbstractVector{<:Pair} = Pair{String,String}[],
)
    shared_request_id = length(requests) == 1 ? only(requests).request_id : nothing
    return WendaoArrow.flight_exchange_request(
        parser_request_arrow_table(route_name, requests);
        descriptor = parser_route_descriptor(route_name),
        headers = parser_route_request_headers(
            route_name;
            request_id = shared_request_id,
            headers = headers,
        ),
        subject = "WendaoCodeParser Flight exchange request",
    )
end
