@testset "Modelica summary extraction and backend build" begin
    WendaoCodeParser._reset_omparser_backend_state!()
    response = parse_modelica_file_summary(
        ParserRequest(
            "req-6",
            "Demo.mo",
            """
            model Demo
              import Modelica.Constants.pi;
              // Demo documentation
              parameter Integer n = 1;
              Real x;
              function foo
              algorithm
              end foo;
            end Demo;
            """,
        ),
    )
    @test response.success
    @test response.primary_name == "Demo"
    @test response.summary_scalars["class_name"] == "Demo"
    @test response.summary_scalars["restriction"] == "model"
    @test [
        item["module"] for item in response.summary_items if item["group"] == "import"
    ] == ["Modelica.Constants.pi"]
    symbols = [item for item in response.summary_items if item["group"] == "symbol"]
    @test Set(String[item["name"] for item in symbols]) == Set(["Demo", "n", "x", "foo"])
    signatures = Dict(String(item["name"]) => String(item["signature"]) for item in symbols)
    @test signatures["n"] == "parameter Integer n"
    @test signatures["x"] == "Real x"
    @test signatures["foo"] == "function foo"
    @test [
        item["content"] for
        item in response.summary_items if item["group"] == "documentation"
    ] == ["Demo documentation"]
    @test isfile(WendaoCodeParser.ensure_omparser_backend!())
    @test isdefined(Main, :Absyn)
    @test isdefined(Main, :ImmutableList)
    @test isdefined(Main, :MetaModelica)
end

@testset "Modelica AST query search module" begin
    request = ParserRequest(
        "req-7",
        "Demo.mo",
        """
        model Demo
          // foo docs
          Real x;
          function foo
          algorithm
          end foo;
        end Demo;
        """;
        node_kind = "function",
        name_contains = "fo",
        limit = 5,
    )
    response = search_modelica_ast(request)
    @test response.success
    @test response.match_count == 1
    @test response.matches[1]["name"] == "foo"
    @test response.matches[1]["node_kind"] == "function"

    documentation_response = search_modelica_ast(
        ParserRequest(
            "req-7-doc",
            "Demo.mo",
            """
            model Demo
              // foo docs
              Real x;
            end Demo;
            """;
            node_kind = "documentation",
            text_contains = "foo docs",
            limit = 5,
        ),
    )
    @test documentation_response.success
    @test documentation_response.match_count == 1
    @test documentation_response.matches[1]["node_kind"] == "documentation"
    @test documentation_response.matches[1]["owner_path"] == "Demo"

    equation_response = search_modelica_ast(
        ParserRequest(
            "req-7-eq",
            "Demo.mo",
            """
            model Demo
              Real y;
            equation
              y = 10 * 2;
            end Demo;
            """;
            node_kind = "equation",
            text_contains = "10 * 2",
            limit = 5,
        ),
    )
    @test equation_response.success
    @test equation_response.match_count == 1
    @test equation_response.matches[1]["node_kind"] == "equation"
    @test occursin("y = 10 * 2", equation_response.matches[1]["text"])

    attribute_response = search_modelica_ast(
        ParserRequest(
            "req-7-attr",
            "Aligned.mo",
            """
            model Demo
              input Real u;
            protected
              parameter Integer n(unit="s") = 1 + 2;
            end Demo;
            """;
            node_kind = "component",
            attribute_key = "component_kind",
            attribute_equals = "parameter",
            limit = 5,
        ),
    )
    @test attribute_response.success
    @test attribute_response.match_count == 1
    @test attribute_response.matches[1]["name"] == "n"
    @test attribute_response.matches[1]["attribute_key"] == "component_kind"
    @test attribute_response.matches[1]["attribute_value"] == "parameter"

    unit_response = search_modelica_ast(
        ParserRequest(
            "req-7-unit",
            "Aligned.mo",
            """
            model Demo
            protected
              parameter Integer n(unit="s") = 1 + 2;
            end Demo;
            """;
            node_kind = "component",
            attribute_key = "unit",
            attribute_equals = "s",
            limit = 5,
        ),
    )
    @test unit_response.success
    @test unit_response.match_count == 1
    @test unit_response.matches[1]["name"] == "n"
    @test unit_response.matches[1]["attribute_value"] == "s"

    scoped_response = search_modelica_ast(
        ParserRequest(
            "req-7-scope",
            "Nested.mo",
            """
            model Demo
              parameter Integer n = 1;
              model Inner
                parameter Integer n = 2;
              end Inner;
            end Demo;
            """;
            node_kind = "component",
            name_equals = "n",
            attribute_key = "owner_path",
            attribute_equals = "Demo.Inner",
            limit = 5,
        ),
    )
    @test scoped_response.success
    @test scoped_response.match_count == 1
    @test scoped_response.matches[1]["name"] == "n"
    @test scoped_response.matches[1]["owner_path"] == "Demo.Inner"
    @test scoped_response.matches[1]["class_path"] == "Demo.Inner"
    @test scoped_response.matches[1]["attribute_value"] == "Demo.Inner"
end

@testset "Modelica native summary alignment details" begin
    response = parse_modelica_file_summary(
        ParserRequest(
            "req-7-align",
            "Aligned.mo",
            """
            encapsulated partial model Demo
              input Real u;
              output Real z;
              Real y;
            protected
              parameter Integer n(unit="s") = 1 + 2;
            equation
              y = 10 * 2;
            end Demo;
            """,
        ),
    )
    @test response.success
    symbols = Dict(
        String(item["name"]) => item for
        item in response.summary_items if item["group"] == "symbol"
    )
    @test haskey(symbols, "Demo")
    @test haskey(symbols, "u")
    @test haskey(symbols, "z")
    @test haskey(symbols, "y")
    @test haskey(symbols, "n")
    @test symbols["Demo"]["visibility"] == "public"
    @test symbols["Demo"]["is_partial"] == true
    @test symbols["Demo"]["is_encapsulated"] == true
    @test symbols["u"]["component_kind"] == "input_connector"
    @test symbols["u"]["direction"] == "input"
    @test symbols["z"]["component_kind"] == "output_connector"
    @test symbols["z"]["direction"] == "output"
    @test symbols["y"]["visibility"] == "public"
    @test symbols["y"]["type_name"] == "Real"
    @test symbols["y"]["component_kind"] == "variable"
    @test symbols["y"]["variability"] == "variable"
    @test symbols["n"]["visibility"] == "protected"
    @test symbols["n"]["type_name"] == "Integer"
    @test symbols["n"]["component_kind"] == "parameter"
    @test symbols["n"]["variability"] == "parameter"
    @test symbols["n"]["default_value"] == "1 + 2"
    @test symbols["n"]["unit"] == "s"
    @test symbols["n"]["owner_name"] == "Demo"
    equations = [item for item in response.summary_items if item["group"] == "equation"]
    @test length(equations) == 1
    @test equations[1]["name"] == "Demo"
    @test equations[1]["owner_name"] == "Demo"
    @test occursin("y = 10 * 2", equations[1]["text"])
    @test equations[1]["line_start"] == 8
    @test equations[1]["line_end"] == 8

    scoped_response = parse_modelica_file_summary(
        ParserRequest(
            "req-7-scoped",
            "Scoped.mo",
            """
            model Demo
              import Modelica.Constants.pi;
              parameter Integer n = 1;
              model Inner
                import Modelica.Constants.pi;
                parameter Integer n = 2;
              end Inner;
            end Demo;
            """,
        ),
    )
    @test scoped_response.success
    scoped_imports =
        [item for item in scoped_response.summary_items if item["group"] == "import"]
    @test length(scoped_imports) == 2
    @test sort(collect(String(item["owner_path"]) for item in scoped_imports)) ==
          ["Demo", "Demo.Inner"]
    scoped_symbols = [
        item for item in scoped_response.summary_items if
        item["group"] == "symbol" && item["name"] == "n"
    ]
    @test length(scoped_symbols) == 2
    @test sort(collect(String(item["owner_path"]) for item in scoped_symbols)) ==
          ["Demo", "Demo.Inner"]
end

@testset "Modelica native component modifier alignment details" begin
    source = """
    model Demo
      parameter Real x[3](unit="s", start=1) = 2;
    end Demo;
    """

    response = parse_modelica_file_summary(
        ParserRequest("req-7-modifiers", "Modifiers.mo", source),
    )
    @test response.success
    symbols = Dict(
        String(item["name"]) => item for
        item in response.summary_items if item["group"] == "symbol"
    )
    @test haskey(symbols, "x")
    @test symbols["x"]["array_dimensions"] == "[3]"
    @test symbols["x"]["start_value"] == "1"
    @test symbols["x"]["modifier_names"] == "unit,start"
    @test symbols["x"]["default_value"] == "2"
    @test symbols["x"]["unit"] == "s"

    dimension_response = search_modelica_ast(
        ParserRequest(
            "req-7-dim",
            "Modifiers.mo",
            source;
            node_kind = "component",
            attribute_key = "array_dimensions",
            attribute_equals = "[3]",
            limit = 5,
        ),
    )
    @test dimension_response.success
    @test dimension_response.match_count == 1
    @test dimension_response.matches[1]["name"] == "x"
    @test dimension_response.matches[1]["array_dimensions"] == "[3]"

    start_response = search_modelica_ast(
        ParserRequest(
            "req-7-start",
            "Modifiers.mo",
            source;
            node_kind = "component",
            attribute_key = "start_value",
            attribute_equals = "1",
            limit = 5,
        ),
    )
    @test start_response.success
    @test start_response.match_count == 1
    @test start_response.matches[1]["name"] == "x"
    @test start_response.matches[1]["start_value"] == "1"
    @test start_response.matches[1]["modifier_names"] == "unit,start"
end

@testset "Modelica AST query cache hits and invalidation" begin
    WendaoCodeParser._reset_omparser_backend_state!()
    warm_request = ParserRequest(
        "req-7-cache-1",
        "Demo.mo",
        """
        model Demo
          Real x;
          function foo
          algorithm
          end foo;
        end Demo;
        """;
        node_kind = "function",
        name_contains = "fo",
        limit = 5,
    )
    warm_response = search_modelica_ast(warm_request)
    @test warm_response.success
    warm_snapshot = WendaoCodeParser._modelica_backend_cache_snapshot()
    @test warm_snapshot.parse_calls == 1
    @test warm_snapshot.cache_hits == 0
    @test warm_snapshot.cache_misses == 1
    @test warm_snapshot.cache_size == 1

    hot_response = search_modelica_ast(warm_request)
    @test hot_response.success
    hot_snapshot = WendaoCodeParser._modelica_backend_cache_snapshot()
    @test hot_snapshot.parse_calls == 1
    @test hot_snapshot.cache_hits == 1
    @test hot_snapshot.cache_misses == 1
    @test hot_snapshot.cache_size == 1

    invalidated_request = ParserRequest(
        "req-7-cache-2",
        "Demo.mo",
        """
        model Demo
          Real x;
          function foo
          algorithm
          end foo;
          function bar
          algorithm
          end bar;
        end Demo;
        """;
        node_kind = "function",
        name_contains = "ba",
        limit = 5,
    )
    invalidated_response = search_modelica_ast(invalidated_request)
    @test invalidated_response.success
    invalidated_snapshot = WendaoCodeParser._modelica_backend_cache_snapshot()
    @test invalidated_snapshot.parse_calls == 2
    @test invalidated_snapshot.cache_hits == 1
    @test invalidated_snapshot.cache_misses == 2
    @test invalidated_snapshot.cache_size == 2
end
