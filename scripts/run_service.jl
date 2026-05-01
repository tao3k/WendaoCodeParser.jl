if "@" ∉ Base.LOAD_PATH
    pushfirst!(Base.LOAD_PATH, "@")
end

if "@stdlib" ∉ Base.LOAD_PATH
    push!(Base.LOAD_PATH, "@stdlib")
end

using Logging
using TOML
using WendaoArrow
using WendaoCodeParser

const SCRIPT_ROOT = @__DIR__
const WENDAOCODEPARSER_ROOT = normpath(joinpath(SCRIPT_ROOT, ".."))
const DEFAULT_CONFIG_PATH =
    joinpath(WENDAOCODEPARSER_ROOT, "config", "live", "parser_summary.toml")

function _usage()
    return """
    usage: julia --project=. scripts/run_service.jl [--config PATH] [--host HOST] [--port PORT] [--code-parser-route-names ROUTES]

    Starts the WendaoCodeParser parser-summary Flight service.
    """
end

function _help_requested(args::Vector{String})
    return any(argument -> argument == "--help" || argument == "-h", args)
end

function _has_config_arg(args::Vector{String})
    return any(
        argument == "--config" || startswith(argument, "--config=") for argument in args
    )
end

function _config_arg_path(args::Vector{String})
    index = 1
    while index <= length(args)
        argument = args[index]
        if startswith(argument, "--config=")
            return abspath(split(argument, "=", limit = 2)[2])
        elseif argument == "--config"
            index += 1
            index > length(args) &&
                error("WendaoCodeParser service requires one value after --config")
            return abspath(args[index])
        end
        index += 1
    end
    return nothing
end

function _has_code_parser_route_arg(args::Vector{String})
    return any(
        startswith(argument, "--code-parser-route-name=") ||
        startswith(argument, "--code-parser-route-names=") ||
        startswith(argument, "--code-parser-routes=") ||
        argument == "--code-parser-route-name" ||
        argument == "--code-parser-route-names" ||
        argument == "--code-parser-routes" for argument in args
    )
end

function _effective_config_path(args::Vector{String})
    config_path = _config_arg_path(args)
    !isnothing(config_path) && return config_path
    if haskey(ENV, "WENDAOCODEPARSER_CONFIG")
        return abspath(ENV["WENDAOCODEPARSER_CONFIG"])
    end
    return DEFAULT_CONFIG_PATH
end

function _code_parser_route_args_from_config(config_path::AbstractString)
    resolved_path = abspath(String(config_path))
    isfile(resolved_path) ||
        error("WendaoCodeParser service config does not exist: $(resolved_path)")
    config = TOML.parsefile(resolved_path)
    route_name = get(config, "code_parser_route_name", nothing)
    route_names = get(config, "code_parser_route_names", nothing)
    (!isnothing(route_name) && !isnothing(route_names)) && error(
        "WendaoCodeParser service config must not set both code_parser_route_name and code_parser_route_names",
    )
    if !isnothing(route_name)
        return String["--code-parser-route-name", String(route_name)]
    end
    if !isnothing(route_names)
        route_names isa AbstractVector || error(
            "WendaoCodeParser service config code_parser_route_names must be an array of strings",
        )
        return String[
            "--code-parser-route-names",
            join(String[String(value) for value in route_names], ","),
        ]
    end
    return String[]
end

function service_entry_args(args::Vector{String})
    entry_args = String[]
    config_path = _effective_config_path(args)
    !_has_config_arg(args) && append!(entry_args, ["--config", config_path])
    if !_has_code_parser_route_arg(args)
        route_args = _code_parser_route_args_from_config(config_path)
        isempty(route_args) && error(
            "WendaoCodeParser service requires code_parser_route_name(s) via --config or explicit CLI args",
        )
        append!(entry_args, route_args)
    end
    append!(entry_args, args)
    return entry_args
end

function main(args::Vector{String})
    if _help_requested(args)
        print(_usage())
        return nothing
    end

    entry_args = service_entry_args(args)
    route_names = WendaoCodeParser.parser_service_route_names(entry_args)
    isempty(route_names) &&
        error("WendaoCodeParser service requires at least one parser route")
    listener = WendaoCodeParser.parser_service_listener_config(entry_args)
    config = WendaoArrow.config_from_args(
        WendaoCodeParser.parser_service_interface_args(entry_args),
    )

    @info(
        "WendaoCodeParser service startup",
        host = String(config.host),
        port = Int(config.port),
        route_names = String[String(route_name) for route_name in route_names],
        listener_max_active_requests = listener.max_active_requests,
        listener_request_capacity = listener.request_capacity,
        listener_response_capacity = listener.response_capacity,
        schema_version = WendaoCodeParser.WENDAOCODEPARSER_SCHEMA_VERSION,
    )
    live_service = WendaoCodeParser.build_parser_live_flight_service(route_names)
    WendaoCodeParser.warm_parser_live_flight_service(live_service, route_names)
    server = WendaoArrow.flight_server(
        live_service;
        host = String(config.host),
        port = Int(config.port),
        WendaoCodeParser.parser_service_flight_server_kwargs(listener)...,
    )
    WendaoArrow._wait_for_flight_server(server; block = true)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main(copy(ARGS))
end
