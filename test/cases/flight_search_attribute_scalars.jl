@testset "Flight services preserve typed scalar attribute matches" begin
    julia_service = build_parser_flight_service(JULIA_AST_QUERY_ROUTE)
    julia_request = parser_exchange_request(
        JULIA_AST_QUERY_ROUTE,
        [
            ParserRequest(
                "req-flight-search-bool-julia",
                "Params.jl",
                """
                module Demo
                function qux(a, b=1, c::Int=2, args...; k=3, t::T=4, kwargs...) where {T}
                    a
                end
                end
                """;
                node_kind = "function",
                attribute_key = "function_has_varargs",
                attribute_equals = "true",
                limit = 5,
            ),
            ParserRequest(
                "req-flight-search-int-julia",
                "Params.jl",
                """
                module Demo
                function qux(a, b=1, c::Int=2, args...; k=3, t::T=4, kwargs...) where {T}
                    a
                end
                end
                """;
                node_kind = "function",
                attribute_key = "function_positional_arity",
                attribute_equals = "4",
                limit = 5,
            ),
        ],
    )
    julia_table = WendaoCodeParser.WendaoArrow.flight_exchange_table(
        julia_service,
        WendaoCodeParser.WendaoArrow.Arrow.Flight.ServerCallContext(),
        julia_request,
    )
    julia_columns = Tables.columntable(julia_table)
    @test julia_columns.success == [true, true]
    @test julia_columns.match_name == ["qux", "qux"]
    @test julia_columns.match_function_has_varargs == [true, true]
    @test julia_columns.match_attribute_key ==
          ["function_has_varargs", "function_positional_arity"]
    @test julia_columns.match_attribute_value == ["true", "4"]

    modelica_service = build_parser_flight_service(MODELICA_AST_QUERY_ROUTE)
    modelica_request = parser_exchange_request(
        MODELICA_AST_QUERY_ROUTE,
        [
            ParserRequest(
                "req-flight-search-bool-modelica",
                "Typed.mo",
                """
                partial model Demo
                  parameter Real x = 1;
                end Demo;
                """;
                node_kind = "model",
                attribute_key = "is_partial",
                attribute_equals = "true",
                limit = 5,
            ),
            ParserRequest(
                "req-flight-search-int-modelica",
                "Typed.mo",
                """
                partial model Demo
                  parameter Real x = 1;
                end Demo;
                """;
                node_kind = "component",
                attribute_key = "line_start",
                attribute_equals = "2",
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
    @test modelica_columns.success == [true, true]
    @test modelica_columns.match_name == ["Demo", "x"]
    @test modelica_columns.match_is_partial[1] === true
    @test ismissing(modelica_columns.match_is_partial[2])
    @test modelica_columns.match_line_start == [1, 2]
    @test modelica_columns.match_attribute_key == ["is_partial", "line_start"]
    @test modelica_columns.match_attribute_value == ["true", "2"]
end
