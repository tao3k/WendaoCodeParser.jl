@testset "Julia function parameter alignment" begin
    source = """
    module Demo
    function qux(a, b=1, c::Int=2, args...; k=3, t::T=4, kwargs...) where {T}
        a
    end
    end
    """

    response = parse_julia_file_summary(
        ParserRequest("req-julia-function-params", "Params.jl", source),
    )
    @test response.success

    symbols = Dict(
        String(item["name"]) => item for
        item in response.summary_items if item["group"] == "symbol"
    )
    @test symbols["qux"]["function_positional_params"] == "a,b,c,args"
    @test symbols["qux"]["function_keyword_params"] == "k,t,kwargs"
    @test symbols["qux"]["function_defaulted_params"] == "b,c,k,t"
    @test symbols["qux"]["function_typed_params"] == "c,t"
    @test symbols["qux"]["function_positional_vararg_name"] == "args"
    @test symbols["qux"]["function_keyword_vararg_name"] == "kwargs"
end

@testset "Julia function parameter AST search coverage" begin
    source = """
    module Demo
    function qux(a, b=1, c::Int=2, args...; k=3, t::T=4, kwargs...) where {T}
        a
    end
    function only_keywords(; alpha=1, beta::Int=2)
        alpha + beta
    end
    end
    """

    keyword_param_response = search_julia_ast(
        ParserRequest(
            "req-julia-fn-keyword-param",
            "Params.jl",
            source;
            node_kind = "function",
            attribute_key = "function_keyword_params",
            attribute_contains = "kwargs",
            limit = 5,
        ),
    )
    @test keyword_param_response.success
    @test keyword_param_response.match_count == 1
    @test keyword_param_response.matches[1]["name"] == "qux"
    @test keyword_param_response.matches[1]["function_keyword_params"] == "k,t,kwargs"

    defaulted_param_response = search_julia_ast(
        ParserRequest(
            "req-julia-fn-defaulted-param",
            "Params.jl",
            source;
            node_kind = "function",
            attribute_key = "function_defaulted_params",
            attribute_contains = "beta",
            limit = 5,
        ),
    )
    @test defaulted_param_response.success
    @test defaulted_param_response.match_count == 1
    @test defaulted_param_response.matches[1]["name"] == "only_keywords"

    typed_param_response = search_julia_ast(
        ParserRequest(
            "req-julia-fn-typed-param",
            "Params.jl",
            source;
            node_kind = "function",
            attribute_key = "function_typed_params",
            attribute_contains = "c",
            limit = 5,
        ),
    )
    @test typed_param_response.success
    @test typed_param_response.match_count == 1
    @test typed_param_response.matches[1]["name"] == "qux"
    @test typed_param_response.matches[1]["function_typed_params"] == "c,t"

    vararg_name_response = search_julia_ast(
        ParserRequest(
            "req-julia-fn-vararg-name",
            "Params.jl",
            source;
            node_kind = "function",
            attribute_key = "function_positional_vararg_name",
            attribute_equals = "args",
            limit = 5,
        ),
    )
    @test vararg_name_response.success
    @test vararg_name_response.match_count == 1
    @test vararg_name_response.matches[1]["name"] == "qux"
    @test vararg_name_response.matches[1]["function_keyword_vararg_name"] == "kwargs"
end
