@testset "Modelica dependency alignment details" begin
    source = """
    model Demo
      import SI = Modelica.Units.SI;
      import Modelica.Math;
      extends Base;
    end Demo;
    """

    response =
        parse_modelica_file_summary(ParserRequest("req-modelica-deps", "Deps.mo", source))
    @test response.success

    imports = [item for item in response.summary_items if item["group"] == "import"]
    @test length(imports) == 2
    named_import =
        only(item for item in imports if item["dependency_target"] == "Modelica.Units.SI")
    @test named_import["dependency_kind"] == "import"
    @test named_import["dependency_form"] == "named_import"
    @test named_import["dependency_alias"] == "SI"
    @test named_import["dependency_local_name"] == "SI"
    plain_import =
        only(item for item in imports if item["dependency_target"] == "Modelica.Math")
    @test plain_import["dependency_kind"] == "import"
    @test plain_import["dependency_form"] == "qualified_import"
    @test plain_import["dependency_local_name"] == "Math"

    extends_items = [item for item in response.summary_items if item["group"] == "extend"]
    @test length(extends_items) == 1
    @test extends_items[1]["dependency_kind"] == "extends"
    @test extends_items[1]["dependency_form"] == "extends"
    @test extends_items[1]["dependency_target"] == "Base"

    import_response = search_modelica_ast(
        ParserRequest(
            "req-modelica-import-deps",
            "Deps.mo",
            source;
            node_kind = "import",
            attribute_key = "dependency_alias",
            attribute_equals = "SI",
            limit = 5,
        ),
    )
    @test import_response.success
    @test import_response.match_count == 1
    @test import_response.matches[1]["dependency_kind"] == "import"
    @test import_response.matches[1]["dependency_form"] == "named_import"
    @test import_response.matches[1]["dependency_target"] == "Modelica.Units.SI"
    @test import_response.matches[1]["dependency_alias"] == "SI"
    @test import_response.matches[1]["dependency_local_name"] == "SI"

    plain_import_response = search_modelica_ast(
        ParserRequest(
            "req-modelica-plain-import-local-name",
            "Deps.mo",
            source;
            node_kind = "import",
            attribute_key = "dependency_local_name",
            attribute_equals = "Math",
            limit = 5,
        ),
    )
    @test plain_import_response.success
    @test plain_import_response.match_count == 1
    @test plain_import_response.matches[1]["dependency_form"] == "qualified_import"
    @test plain_import_response.matches[1]["dependency_target"] == "Modelica.Math"
    @test plain_import_response.matches[1]["dependency_local_name"] == "Math"

    extends_response = search_modelica_ast(
        ParserRequest(
            "req-modelica-extends-deps",
            "Deps.mo",
            source;
            node_kind = "extends",
            attribute_key = "dependency_kind",
            attribute_equals = "extends",
            limit = 5,
        ),
    )
    @test extends_response.success
    @test extends_response.match_count == 1
    @test extends_response.matches[1]["name"] == "Base"
    @test extends_response.matches[1]["dependency_kind"] == "extends"
    @test extends_response.matches[1]["dependency_form"] == "extends"
    @test extends_response.matches[1]["dependency_target"] == "Base"
end
