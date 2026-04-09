@testset "Flight services preserve Modelica import forms" begin
    summary_service = build_parser_flight_service(MODELICA_FILE_SUMMARY_ROUTE)
    summary_request = parser_exchange_request(
        MODELICA_FILE_SUMMARY_ROUTE,
        [
            ParserRequest(
                "req-flight-modelica-import-forms",
                "ImportForms.mo",
                """
                model Demo
                  import Modelica.Math;
                  import Modelica.Math.*;
                end Demo;
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
    import_rows = findall(
        index -> summary_columns.item_group[index] == "import",
        eachindex(summary_columns.item_group),
    )
    @test length(import_rows) == 2
    @test sort(summary_columns.item_dependency_form[import_rows]) ==
          ["qualified_import", "unqualified_import"]
    @test all(summary_columns.item_dependency_target[import_rows] .== "Modelica.Math")

    query_service = build_parser_flight_service(MODELICA_AST_QUERY_ROUTE)
    query_request = parser_exchange_request(
        MODELICA_AST_QUERY_ROUTE,
        [
            ParserRequest(
                "req-flight-modelica-unqualified-import",
                "ImportForms.mo",
                """
                model Demo
                  import Modelica.Math;
                  import Modelica.Math.*;
                end Demo;
                """;
                node_kind = "import",
                attribute_key = "dependency_form",
                attribute_equals = "unqualified_import",
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
    @test query_columns.success == [true]
    @test query_columns.match_count == [1]
    @test query_columns.match_name == ["Modelica.Math"]
    @test query_columns.match_dependency_form == ["unqualified_import"]
    @test query_columns.match_dependency_target == ["Modelica.Math"]
    @test query_columns.match_dependency_local_name == ["Math"]
end
