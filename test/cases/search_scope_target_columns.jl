@testset "Parser search resolves stable scope and target columns" begin
    julia_source = """
    module Demo
    \"\"\"docstring for foo\"\"\"
    foo(x) = x
    end
    """

    julia_target_response = search_julia_ast(
        ParserRequest(
            "req-search-target-name-julia",
            "TargetName.jl",
            julia_source;
            node_kind = "docstring",
            attribute_key = "target_name",
            attribute_equals = "foo",
            limit = 5,
        ),
    )
    @test julia_target_response.success
    @test julia_target_response.match_count == 1
    @test julia_target_response.matches[1]["name"] == "foo"
    @test julia_target_response.matches[1]["target_name"] == "foo"
    @test julia_target_response.matches[1]["attribute_value"] == "foo"

    julia_scope_response = search_julia_ast(
        ParserRequest(
            "req-search-root-module-julia",
            "TargetName.jl",
            julia_source;
            node_kind = "function",
            attribute_key = "root_module_name",
            attribute_equals = "Demo",
            limit = 5,
        ),
    )
    @test julia_scope_response.success
    @test julia_scope_response.match_count == 1
    @test julia_scope_response.matches[1]["name"] == "foo"
    @test julia_scope_response.matches[1]["root_module_name"] == "Demo"
    @test julia_scope_response.matches[1]["attribute_value"] == "Demo"

    nested_julia_source = """
    module Demo
    foo() = 1
    module Inner
    bar() = 2
    end
    end
    """

    julia_top_level_response = search_julia_ast(
        ParserRequest(
            "req-search-top-level-julia",
            "NestedDemo.jl",
            nested_julia_source;
            node_kind = "function",
            attribute_key = "top_level",
            attribute_equals = "true",
            limit = 5,
        ),
    )
    @test julia_top_level_response.success
    @test julia_top_level_response.match_count == 1
    @test julia_top_level_response.matches[1]["name"] == "foo"
    @test julia_top_level_response.matches[1]["top_level"] === true
    @test julia_top_level_response.matches[1]["attribute_value"] === true

    julia_nested_response = search_julia_ast(
        ParserRequest(
            "req-search-nested-julia",
            "NestedDemo.jl",
            nested_julia_source;
            node_kind = "function",
            attribute_key = "top_level",
            attribute_equals = "false",
            limit = 5,
        ),
    )
    @test julia_nested_response.success
    @test julia_nested_response.match_count == 1
    @test julia_nested_response.matches[1]["name"] == "bar"
    @test julia_nested_response.matches[1]["top_level"] === false
    @test julia_nested_response.matches[1]["attribute_value"] === false

    modelica_source = """
    model Outer
      model Inner
      end Inner;
    end Outer;
    """

    modelica_top_level_response = search_modelica_ast(
        ParserRequest(
            "req-search-top-level-modelica",
            "Nested.mo",
            modelica_source;
            node_kind = "model",
            attribute_key = "top_level",
            attribute_equals = "true",
            limit = 5,
        ),
    )
    @test modelica_top_level_response.success
    @test modelica_top_level_response.match_count == 1
    @test modelica_top_level_response.matches[1]["name"] == "Outer"
    @test modelica_top_level_response.matches[1]["top_level"] === true
    @test modelica_top_level_response.matches[1]["attribute_value"] === true

    modelica_nested_response = search_modelica_ast(
        ParserRequest(
            "req-search-nested-modelica",
            "Nested.mo",
            modelica_source;
            node_kind = "model",
            attribute_key = "top_level",
            attribute_equals = "false",
            limit = 5,
        ),
    )
    @test modelica_nested_response.success
    @test modelica_nested_response.match_count == 1
    @test modelica_nested_response.matches[1]["name"] == "Inner"
    @test modelica_nested_response.matches[1]["top_level"] === false
    @test modelica_nested_response.matches[1]["attribute_value"] === false
end
