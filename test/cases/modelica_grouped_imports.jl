@testset "Modelica grouped imports fail deterministically" begin
    source = """
    model Demo
      import Modelica.Media.{Interfaces,Utilities};
    end Demo;
    """

    summary_response = parse_modelica_file_summary(
        ParserRequest("req-modelica-grouped-import-summary", "Grouped.mo", source),
    )
    @test !summary_response.success
    @test occursin("Grouped.mo", something(summary_response.error_message, ""))
    @test occursin(
        "grouped imports are not yet supported",
        something(summary_response.error_message, ""),
    )
    @test occursin("line 2, column 25", something(summary_response.error_message, ""))

    query_response = search_modelica_ast(
        ParserRequest(
            "req-modelica-grouped-import-query",
            "Grouped.mo",
            source;
            node_kind = "import",
            limit = 5,
        ),
    )
    @test !query_response.success
    @test occursin("Grouped.mo", something(query_response.error_message, ""))
    @test occursin(
        "grouped imports are not yet supported",
        something(query_response.error_message, ""),
    )
    @test query_response.match_count === nothing
    @test isempty(query_response.matches)
end
