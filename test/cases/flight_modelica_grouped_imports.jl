@testset "Flight services return structured failure for grouped Modelica imports" begin
    source = """
    model Demo
      import Modelica.Media.{Interfaces,Utilities};
    end Demo;
    """

    summary_service = build_parser_flight_service(MODELICA_FILE_SUMMARY_ROUTE)
    summary_request = parser_exchange_request(
        MODELICA_FILE_SUMMARY_ROUTE,
        [ParserRequest("req-flight-modelica-grouped-import-summary", "Grouped.mo", source)],
    )
    summary_table = WendaoCodeParser.WendaoArrow.flight_exchange_table(
        summary_service,
        WendaoCodeParser.WendaoArrow.Arrow.Flight.ServerCallContext(),
        summary_request,
    )
    summary_columns = Tables.columntable(summary_table)
    @test summary_columns.success == [false]
    @test occursin(
        "grouped imports are not yet supported",
        String(summary_columns.error_message[1]),
    )
    @test occursin("Grouped.mo", String(summary_columns.error_message[1]))

    query_service = build_parser_flight_service(MODELICA_AST_QUERY_ROUTE)
    query_request = parser_exchange_request(
        MODELICA_AST_QUERY_ROUTE,
        [
            ParserRequest(
                "req-flight-modelica-grouped-import-query",
                "Grouped.mo",
                source;
                node_kind = "import",
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
    @test query_columns.success == [false]
    @test query_columns.match_count == [0]
    @test occursin(
        "grouped imports are not yet supported",
        String(query_columns.error_message[1]),
    )
    @test occursin("Grouped.mo", String(query_columns.error_message[1]))
end
