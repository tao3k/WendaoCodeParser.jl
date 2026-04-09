@testset "Parser search resolves identifier-list attribute matches" begin
    julia_source = """
    module Demo
    function qux(a, b=1, c::Int=2, args...; k=3, t::T=4, kwargs...) where {T}
        a
    end
    end
    """

    julia_response = search_julia_ast(
        ParserRequest(
            "req-search-list-julia",
            "Params.jl",
            julia_source;
            node_kind = "function",
            attribute_key = "function_keyword_params",
            attribute_equals = "kwargs",
            limit = 5,
        ),
    )
    @test julia_response.success
    @test julia_response.match_count == 1
    @test julia_response.matches[1]["name"] == "qux"
    @test julia_response.matches[1]["function_keyword_params"] == "k,t,kwargs"
    @test julia_response.matches[1]["attribute_value"] == "kwargs"

    modelica_source = """
    model Demo
      parameter Real x[3](unit="s", start=1) = 2;
    end Demo;
    """

    modelica_response = search_modelica_ast(
        ParserRequest(
            "req-search-list-modelica",
            "Modifiers.mo",
            modelica_source;
            node_kind = "component",
            attribute_key = "modifier_names",
            attribute_equals = "start",
            limit = 5,
        ),
    )
    @test modelica_response.success
    @test modelica_response.match_count == 1
    @test modelica_response.matches[1]["name"] == "x"
    @test modelica_response.matches[1]["modifier_names"] == "unit,start"
    @test modelica_response.matches[1]["attribute_value"] == "start"
end
