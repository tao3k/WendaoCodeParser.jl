@testset "Julia Flight services expose parameter owner signatures" begin
    source = """
    module Demo
    foo(x::Int)=x
    foo(x::String)=x
    end
    """

    summary_service = build_parser_flight_service(JULIA_FILE_SUMMARY_ROUTE)
    summary_request = parser_exchange_request(
        JULIA_FILE_SUMMARY_ROUTE,
        [
            ParserRequest(
                "req-flight-julia-parameter-owner-signatures",
                "Methods.jl",
                source,
            ),
        ],
    )
    summary_table = WendaoCodeParser.WendaoArrow.flight_exchange_table(
        summary_service,
        WendaoCodeParser.WendaoArrow.Arrow.Flight.ServerCallContext(),
        summary_request,
    )
    summary_columns = Tables.columntable(summary_table)
    @test hasproperty(summary_columns, :item_owner_signature)
    x_rows = findall(
        index ->
            summary_columns.item_group[index] == "parameter" &&
            summary_columns.item_name[index] == "x",
        eachindex(summary_columns.item_group),
    )
    @test length(x_rows) == 2
    @test sort(summary_columns.item_owner_signature[x_rows]) ==
          ["foo(x::Int)=x", "foo(x::String)=x"]

    query_service = build_parser_flight_service(JULIA_AST_QUERY_ROUTE)
    query_request = parser_exchange_request(
        JULIA_AST_QUERY_ROUTE,
        [
            ParserRequest(
                "req-flight-julia-parameter-owner-signature-query",
                "Methods.jl",
                source;
                node_kind = "parameter",
                name_equals = "x",
                attribute_key = "owner_signature",
                attribute_contains = "String",
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
    @test hasproperty(query_columns, :match_owner_signature)
    @test query_columns.match_name == ["x"]
    @test query_columns.match_owner_signature == ["foo(x::String)=x"]
    @test query_columns.match_target_path == ["Demo.foo#L3"]
    @test query_columns.match_attribute_key == ["owner_signature"]
    @test query_columns.match_attribute_value == ["foo(x::String)=x"]
end
