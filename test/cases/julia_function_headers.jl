@testset "Julia function header alignment" begin
    source = """
    module Demo
    foo(x::T, y=1; z::Int=2, rest...) where {T<:Real} = string(x)
    function bar(a, b::Int=1; c=2, d::T=3) where {T}
        a + b + c
    end
    function baz(x::T, y)::String where {T<:Real}
        string(x, y)
    end
    end
    """

    response = parse_julia_file_summary(
        ParserRequest("req-julia-function-headers", "Headers.jl", source),
    )
    @test response.success

    symbols = Dict(
        String(item["name"]) => item for
        item in response.summary_items if item["group"] == "symbol"
    )
    @test symbols["foo"]["function_positional_arity"] == 2
    @test symbols["foo"]["function_keyword_arity"] == 2
    @test symbols["foo"]["function_has_varargs"] == true
    @test symbols["foo"]["function_where_params"] == "T<:Real"
    @test get(symbols["foo"], "function_return_type", nothing) === nothing

    @test symbols["bar"]["function_positional_arity"] == 2
    @test symbols["bar"]["function_keyword_arity"] == 2
    @test symbols["bar"]["function_has_varargs"] == false
    @test symbols["bar"]["function_where_params"] == "T"

    @test symbols["baz"]["function_positional_arity"] == 2
    @test symbols["baz"]["function_keyword_arity"] == 0
    @test symbols["baz"]["function_has_varargs"] == false
    @test symbols["baz"]["function_where_params"] == "T<:Real"
    @test symbols["baz"]["function_return_type"] == "String"
end

@testset "Julia function header AST search coverage" begin
    source = """
    module Demo
    foo(x::T, y=1; z::Int=2, rest...) where {T<:Real} = string(x)
    function bar(a, b::Int=1; c=2, d::T=3) where {T}
        a + b + c
    end
    function baz(x::T, y)::String where {T<:Real}
        string(x, y)
    end
    end
    """

    vararg_response = search_julia_ast(
        ParserRequest(
            "req-julia-fn-varargs",
            "Headers.jl",
            source;
            node_kind = "function",
            attribute_key = "function_has_varargs",
            attribute_equals = "true",
            limit = 5,
        ),
    )
    @test vararg_response.success
    @test vararg_response.match_count == 1
    @test vararg_response.matches[1]["name"] == "foo"
    @test vararg_response.matches[1]["function_has_varargs"] == true

    return_type_response = search_julia_ast(
        ParserRequest(
            "req-julia-fn-return-type",
            "Headers.jl",
            source;
            node_kind = "function",
            attribute_key = "function_return_type",
            attribute_equals = "String",
            limit = 5,
        ),
    )
    @test return_type_response.success
    @test return_type_response.match_count == 1
    @test return_type_response.matches[1]["name"] == "baz"
    @test return_type_response.matches[1]["function_return_type"] == "String"

    where_response = search_julia_ast(
        ParserRequest(
            "req-julia-fn-where",
            "Headers.jl",
            source;
            node_kind = "function",
            attribute_key = "function_where_params",
            attribute_equals = "T<:Real",
            limit = 5,
        ),
    )
    @test where_response.success
    @test where_response.match_count == 2
    @test Set(String[match["name"] for match in where_response.matches]) == Set(["foo", "baz"])

    keyword_arity_response = search_julia_ast(
        ParserRequest(
            "req-julia-fn-keyword-arity",
            "Headers.jl",
            source;
            node_kind = "function",
            attribute_key = "function_keyword_arity",
            attribute_equals = "2",
            limit = 5,
        ),
    )
    @test keyword_arity_response.success
    @test keyword_arity_response.match_count == 2
    @test Set(String[match["name"] for match in keyword_arity_response.matches]) == Set(["foo", "bar"])
end
