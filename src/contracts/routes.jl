struct ParserRouteDescriptor
    name::Symbol
    path::String
    summary_kind::String
    backend::String
end

function parser_route(route_name::Symbol)
    if route_name == JULIA_FILE_SUMMARY_ROUTE
        return ParserRouteDescriptor(
            route_name,
            "/wendao/code-parser/julia/file-summary",
            "julia_file_summary",
            "JuliaSyntax.jl",
        )
    elseif route_name == JULIA_ROOT_SUMMARY_ROUTE
        return ParserRouteDescriptor(
            route_name,
            "/wendao/code-parser/julia/root-summary",
            "julia_root_summary",
            "JuliaSyntax.jl",
        )
    elseif route_name == MODELICA_FILE_SUMMARY_ROUTE
        return ParserRouteDescriptor(
            route_name,
            "/wendao/code-parser/modelica/file-summary",
            "modelica_file_summary",
            "OMParser.jl",
        )
    elseif route_name == JULIA_AST_QUERY_ROUTE
        return ParserRouteDescriptor(
            route_name,
            "/wendao/code-parser/julia/ast-query",
            "julia_ast_query",
            "JuliaSyntax.jl",
        )
    elseif route_name == MODELICA_AST_QUERY_ROUTE
        return ParserRouteDescriptor(
            route_name,
            "/wendao/code-parser/modelica/ast-query",
            "modelica_ast_query",
            "OMParser.jl",
        )
    end
    error("unsupported WendaoCodeParser route: $(String(route_name))")
end
