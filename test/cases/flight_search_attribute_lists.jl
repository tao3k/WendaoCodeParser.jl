@testset "Flight services preserve identifier-list attribute matches" begin
    query_service = build_parser_flight_service(JULIA_AST_QUERY_ROUTE)
    julia_request = parser_exchange_request(
        JULIA_AST_QUERY_ROUTE,
        [
            ParserRequest(
                "req-flight-search-list-julia",
                "Params.jl",
                """
                module Demo
                function qux(a, b=1, c::Int=2, args...; k=3, t::T=4, kwargs...) where {T}
                    a
                end
                end
                """;
                node_kind = "function",
                attribute_key = "function_keyword_params",
                attribute_equals = "kwargs",
                limit = 5,
            ),
        ],
    )
    julia_table = WendaoCodeParser.WendaoArrow.flight_exchange_table(
        query_service,
        WendaoCodeParser.WendaoArrow.Arrow.Flight.ServerCallContext(),
        julia_request,
    )
    julia_columns = Tables.columntable(julia_table)
    @test julia_columns.success == [true]
    @test julia_columns.match_name == ["qux"]
    @test julia_columns.match_function_keyword_params == ["k,t,kwargs"]
    @test julia_columns.match_attribute_key == ["function_keyword_params"]
    @test julia_columns.match_attribute_value == ["kwargs"]

    modelica_service = build_parser_flight_service(MODELICA_AST_QUERY_ROUTE)
    modelica_request = parser_exchange_request(
        MODELICA_AST_QUERY_ROUTE,
        [
            ParserRequest(
                "req-flight-search-list-modelica",
                "Modifiers.mo",
                """
                model Demo
                  parameter Real x[3](unit="s", start=1) = 2;
                end Demo;
                """;
                node_kind = "component",
                attribute_key = "modifier_names",
                attribute_equals = "start",
                limit = 5,
            ),
        ],
    )
    modelica_table = WendaoCodeParser.WendaoArrow.flight_exchange_table(
        modelica_service,
        WendaoCodeParser.WendaoArrow.Arrow.Flight.ServerCallContext(),
        modelica_request,
    )
    modelica_columns = Tables.columntable(modelica_table)
    @test modelica_columns.success == [true]
    @test modelica_columns.match_name == ["x"]
    @test modelica_columns.match_modifier_names == ["unit,start"]
    @test modelica_columns.match_attribute_key == ["modifier_names"]
    @test modelica_columns.match_attribute_value == ["start"]
end
