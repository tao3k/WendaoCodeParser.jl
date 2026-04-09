@testset "Parser search resolves typed scalar attribute matches" begin
    julia_source = """
    module Demo
    function qux(a, b=1, c::Int=2, args...; k=3, t::T=4, kwargs...) where {T}
        a
    end
    end
    """

    julia_bool_response = search_julia_ast(
        ParserRequest(
            "req-search-bool-julia",
            "Params.jl",
            julia_source;
            node_kind = "function",
            attribute_key = "function_has_varargs",
            attribute_equals = "true",
            limit = 5,
        ),
    )
    @test julia_bool_response.success
    @test julia_bool_response.match_count == 1
    @test julia_bool_response.matches[1]["name"] == "qux"
    @test julia_bool_response.matches[1]["function_has_varargs"] === true
    @test julia_bool_response.matches[1]["attribute_value"] === true

    julia_int_response = search_julia_ast(
        ParserRequest(
            "req-search-int-julia",
            "Params.jl",
            julia_source;
            node_kind = "function",
            attribute_key = "function_positional_arity",
            attribute_equals = "4",
            limit = 5,
        ),
    )
    @test julia_int_response.success
    @test julia_int_response.match_count == 1
    @test julia_int_response.matches[1]["name"] == "qux"
    @test julia_int_response.matches[1]["function_positional_arity"] == 4
    @test julia_int_response.matches[1]["attribute_value"] == 4

    julia_contains_response = search_julia_ast(
        ParserRequest(
            "req-search-bool-contains-julia",
            "Params.jl",
            julia_source;
            node_kind = "function",
            attribute_key = "function_has_varargs",
            attribute_contains = "tru",
            limit = 5,
        ),
    )
    @test julia_contains_response.success
    @test julia_contains_response.match_count == 0

    modelica_source = """
    partial model Demo
      parameter Real x = 1;
    end Demo;
    """

    modelica_bool_response = search_modelica_ast(
        ParserRequest(
            "req-search-bool-modelica",
            "Typed.mo",
            modelica_source;
            node_kind = "model",
            attribute_key = "is_partial",
            attribute_equals = "true",
            limit = 5,
        ),
    )
    @test modelica_bool_response.success
    @test modelica_bool_response.match_count == 1
    @test modelica_bool_response.matches[1]["name"] == "Demo"
    @test modelica_bool_response.matches[1]["is_partial"] === true
    @test modelica_bool_response.matches[1]["attribute_value"] === true

    modelica_int_response = search_modelica_ast(
        ParserRequest(
            "req-search-int-modelica",
            "Typed.mo",
            modelica_source;
            node_kind = "component",
            attribute_key = "line_start",
            attribute_equals = "2",
            limit = 5,
        ),
    )
    @test modelica_int_response.success
    @test modelica_int_response.match_count == 1
    @test modelica_int_response.matches[1]["name"] == "x"
    @test modelica_int_response.matches[1]["line_start"] == 2
    @test modelica_int_response.matches[1]["attribute_value"] == 2
end
