@testset "Flight services expose relative dependency columns" begin
    summary_service = build_parser_flight_service(JULIA_FILE_SUMMARY_ROUTE)
    summary_request = parser_exchange_request(
        JULIA_FILE_SUMMARY_ROUTE,
        [
            ParserRequest(
                "req-flight-julia-relative-deps",
                "Rel.jl",
                """
                module Demo
                using ..Parent: foo
                import .Utils
                import ..Core: bar as baz
                end
                """,
            ),
        ],
    )
    summary_table = WendaoCodeParser.WendaoArrow.flight_exchange_table(
        summary_service,
        WendaoCodeParser.WendaoArrow.Arrow.Flight.ServerCallContext(),
        summary_request,
    )
    summary_columns = Tables.columntable(summary_table)
    @test hasproperty(summary_columns, :item_dependency_is_relative)
    @test hasproperty(summary_columns, :item_dependency_relative_level)
    relative_row = only(
        index for index in eachindex(summary_columns.item_group) if
        summary_columns.item_group[index] == "import" &&
        summary_columns.item_dependency_target[index] == "..Core.bar"
    )
    @test summary_columns.item_dependency_is_relative[relative_row] == true
    @test summary_columns.item_dependency_relative_level[relative_row] == 2

    query_service = build_parser_flight_service(JULIA_AST_QUERY_ROUTE)
    query_request = parser_exchange_request(
        JULIA_AST_QUERY_ROUTE,
        [
            ParserRequest(
                "req-flight-julia-relative-query",
                "Rel.jl",
                """
                module Demo
                using ..Parent: foo
                import .Utils
                end
                """;
                node_kind = "import",
                attribute_key = "dependency_relative_level",
                attribute_equals = "1",
                limit = 5,
            ),
        ],
    )
    query_table = WendaoCodeParser.WendaoArrow.flight_exchange_table(
        query_service,
        WendaoCodeParser.WendaoArrow.Arrow.Flight.ServerCallContext(),
        query_request,
    )
    query_columns = Tables.columntable(query_table)
    @test hasproperty(query_columns, :match_dependency_is_relative)
    @test hasproperty(query_columns, :match_dependency_relative_level)
    @test query_columns.match_name == [".Utils"]
    @test query_columns.match_dependency_is_relative == [true]
    @test query_columns.match_dependency_relative_level == [1]
end
