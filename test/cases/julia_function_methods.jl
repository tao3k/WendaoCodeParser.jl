@testset "Julia function method alignment" begin
    source = """
    module Demo
    foo(x::Int)=x
    foo(x::String)=x
    end
    """

    response = parse_julia_file_summary(
        ParserRequest("req-julia-function-methods", "Methods.jl", source),
    )
    @test response.success

    foo_symbols = [
        item for item in response.summary_items if
        item["group"] == "symbol" && item["name"] == "foo"
    ]
    @test length(foo_symbols) == 2
    @test sort([String(item["signature"]) for item in foo_symbols]) == ["foo(x::Int)=x", "foo(x::String)=x"]
    @test all(get(item, "path", nothing) == "Demo.foo" for item in foo_symbols)
    @test sort([Int(item["line_start"]) for item in foo_symbols]) == [2, 3]
end

@testset "Julia function method AST search coverage" begin
    source = """
    module Demo
    foo(x::Int)=x
    foo(x::String)=x
    end
    """

    all_methods_response = search_julia_ast(
        ParserRequest(
            "req-julia-function-methods-all",
            "Methods.jl",
            source;
            node_kind = "function",
            name_equals = "foo",
            limit = 10,
        ),
    )
    @test all_methods_response.success
    @test all_methods_response.match_count == 2
    @test sort([String(match["signature"]) for match in all_methods_response.matches]) == ["foo(x::Int)=x", "foo(x::String)=x"]
    @test all(
        get(match, "path", nothing) == "Demo.foo" for match in all_methods_response.matches
    )

    string_method_response = search_julia_ast(
        ParserRequest(
            "req-julia-function-methods-string",
            "Methods.jl",
            source;
            node_kind = "function",
            name_equals = "foo",
            signature_contains = "String",
            limit = 10,
        ),
    )
    @test string_method_response.success
    @test string_method_response.match_count == 1
    @test only(string_method_response.matches)["signature"] == "foo(x::String)=x"
end
