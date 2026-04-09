@testset "Modelica import form preservation" begin
    source = """
    model Demo
      import Modelica.Math;
      import Modelica.Math.*;
    end Demo;
    """

    response = parse_modelica_file_summary(
        ParserRequest("req-modelica-import-forms", "ImportForms.mo", source),
    )
    @test response.success

    imports = [item for item in response.summary_items if item["group"] == "import"]
    @test length(imports) == 2
    forms = sort(getindex.(imports, "dependency_form"))
    @test forms == ["qualified_import", "unqualified_import"]

    qualified_import =
        only(item for item in imports if item["dependency_form"] == "qualified_import")
    @test qualified_import["dependency_target"] == "Modelica.Math"
    @test qualified_import["dependency_local_name"] == "Math"

    unqualified_import =
        only(item for item in imports if item["dependency_form"] == "unqualified_import")
    @test unqualified_import["dependency_target"] == "Modelica.Math"
    @test unqualified_import["dependency_local_name"] == "Math"

    query_response = search_modelica_ast(
        ParserRequest(
            "req-modelica-unqualified-import-query",
            "ImportForms.mo",
            source;
            node_kind = "import",
            attribute_key = "dependency_form",
            attribute_equals = "unqualified_import",
            limit = 5,
        ),
    )
    @test query_response.success
    @test query_response.match_count == 1
    @test query_response.matches[1]["name"] == "Modelica.Math"
    @test query_response.matches[1]["dependency_form"] == "unqualified_import"
    @test query_response.matches[1]["dependency_target"] == "Modelica.Math"
    @test query_response.matches[1]["dependency_local_name"] == "Math"
end
