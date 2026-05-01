module WendaoCodeParser

import Absyn
using JuliaSyntax
import Libdl
using Logging
using Tables
using WendaoArrow

const WENDAOCODEPARSER_SCHEMA_VERSION = "v3"
const JULIA_FILE_SUMMARY_ROUTE = :julia_file_summary
const JULIA_ROOT_SUMMARY_ROUTE = :julia_root_summary
const MODELICA_FILE_SUMMARY_ROUTE = :modelica_file_summary
const JULIA_AST_QUERY_ROUTE = :julia_ast_query
const MODELICA_AST_QUERY_ROUTE = :modelica_ast_query
const PARSER_ROUTE_NAMES = (
    JULIA_FILE_SUMMARY_ROUTE,
    JULIA_ROOT_SUMMARY_ROUTE,
    MODELICA_FILE_SUMMARY_ROUTE,
    JULIA_AST_QUERY_ROUTE,
    MODELICA_AST_QUERY_ROUTE,
)

include("contracts/mod.jl")
include("parsers/mod.jl")
include("search/mod.jl")
include("service/mod.jl")

export WENDAOCODEPARSER_SCHEMA_VERSION
export JULIA_FILE_SUMMARY_ROUTE
export JULIA_ROOT_SUMMARY_ROUTE
export MODELICA_FILE_SUMMARY_ROUTE
export JULIA_AST_QUERY_ROUTE
export MODELICA_AST_QUERY_ROUTE
export PARSER_ROUTE_NAMES
export AstQuery
export ParserRequest
export ParserResponse
export ensure_omparser_backend!
export prewarm_modelica_backend!
export build_parser_flight_service
export build_parser_table_processor
export parser_exchange_request
export parser_request_arrow_table
export parser_response_arrow_table
export parse_julia_file_summary
export parse_julia_root_summary
export parse_modelica_file_summary
export parser_route_descriptor
export parser_route_request_headers
export parser_service_flight_server_kwargs
export parser_service_interface_args
export parser_service_listener_config
export parser_service_route_names
export ParserServiceListenerConfig
export supported_parser_route_names
export build_parser_live_flight_service
export search_julia_ast
export search_modelica_ast
export warm_parser_live_flight_service

end
