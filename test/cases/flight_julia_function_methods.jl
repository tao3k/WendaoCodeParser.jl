@testset "Julia Flight services preserve function methods" begin
    source = """
    module Demo
    foo(x::Int)=x
    foo(x::String)=x
    end
    """

    summary_service = build_parser_flight_service(JULIA_FILE_SUMMARY_ROUTE)
    summary_request = parser_exchange_request(
        JULIA_FILE_SUMMARY_ROUTE,
        [ParserRequest("req-flight-julia-function-methods", "Methods.jl", source)],
    )
    summary_table = WendaoCodeParser.WendaoArrow.flight_exchange_table(
        summary_service,
        WendaoCodeParser.WendaoArrow.Arrow.Flight.ServerCallContext(),
        summary_request,
    )
    summary_columns = Tables.columntable(summary_table)
    foo_indexes = [
        index for index in eachindex(summary_columns.item_group) if
        summary_columns.item_group[index] == "symbol" &&
        summary_columns.item_name[index] == "foo"
    ]
    @test length(foo_indexes) == 2
    @test sort(summary_columns.item_signature[foo_indexes]) ==
          ["foo(x::Int)=x", "foo(x::String)=x"]
    @test summary_columns.item_path[foo_indexes] == ["Demo.foo", "Demo.foo"]

    query_service = build_parser_flight_service(JULIA_AST_QUERY_ROUTE)
    query_request = parser_exchange_request(
        JULIA_AST_QUERY_ROUTE,
        [
            ParserRequest(
                "req-flight-julia-function-methods-query",
                "Methods.jl",
                source;
                node_kind = "function",
                name_equals = "foo",
                limit = 10,
            ),
        ],
    )
    query_table = WendaoCodeParser.WendaoArrow.flight_exchange_table(
        query_service,
        WendaoCodeParser.WendaoArrow.Arrow.Flight.ServerCallContext(),
        query_request,
    )
    query_columns = Tables.columntable(query_table)
    @test query_columns.match_name == ["foo", "foo"]
    @test query_columns.match_count == [2, 2]
    @test sort(query_columns.match_signature) == ["foo(x::Int)=x", "foo(x::String)=x"]
    @test query_columns.match_path == ["Demo.foo", "Demo.foo"]
end
