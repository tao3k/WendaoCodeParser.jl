@testset "Julia native declaration coverage" begin
    source = """
    module Demo
    const FOO = 1
    global bar = 2
    \"\"\"macro docs\"\"\"
    macro baz(x)
        x
    end
    mutable struct Box
        x::Int
    end
    end
    """

    response =
        parse_julia_file_summary(ParserRequest("req-julia-decls", "Decls.jl", source))
    @test response.success

    symbols = Dict(
        String(item["name"]) => item for
        item in response.summary_items if item["group"] == "symbol"
    )
    @test Set(keys(symbols)) == Set(["FOO", "bar", "baz", "Box"])
    @test symbols["FOO"]["kind"] == "binding"
    @test symbols["FOO"]["binding_kind"] == "const"
    @test symbols["FOO"]["signature"] == "const FOO = 1"
    @test symbols["FOO"]["line_start"] == 2
    @test symbols["FOO"]["line_end"] == 2
    @test symbols["bar"]["kind"] == "binding"
    @test symbols["bar"]["binding_kind"] == "global"
    @test symbols["bar"]["signature"] == "global bar = 2"
    @test symbols["baz"]["kind"] == "macro"
    @test symbols["baz"]["signature"] == "macro baz(x)"
    @test symbols["baz"]["line_start"] == 5
    @test symbols["baz"]["line_end"] == 7
    @test symbols["Box"]["kind"] == "type"
    @test symbols["Box"]["type_kind"] == "mutable_struct"
    @test symbols["Box"]["signature"] == "mutable struct Box"
    @test symbols["Box"]["line_start"] == 8
    @test symbols["Box"]["line_end"] == 10

    docstrings = [item for item in response.summary_items if item["group"] == "docstring"]
    @test length(docstrings) == 1
    @test docstrings[1]["name"] == "baz"
    @test docstrings[1]["target_kind"] == "symbol"
    @test docstrings[1]["target_path"] == "Demo.baz"
    @test docstrings[1]["target_line_start"] == 5
    @test docstrings[1]["target_line_end"] == 7
end

@testset "Julia declaration AST search coverage" begin
    source = """
    module Demo
    const FOO = 1
    global bar = 2
    macro baz(x)
        x
    end
    mutable struct Box
        x::Int
    end
    end
    """

    binding_response = search_julia_ast(
        ParserRequest(
            "req-julia-binding",
            "Decls.jl",
            source;
            node_kind = "binding",
            attribute_key = "binding_kind",
            attribute_equals = "const",
            limit = 5,
        ),
    )
    @test binding_response.success
    @test binding_response.match_count == 1
    @test binding_response.matches[1]["name"] == "FOO"
    @test binding_response.matches[1]["binding_kind"] == "const"
    @test binding_response.matches[1]["attribute_value"] == "const"

    macro_response = search_julia_ast(
        ParserRequest(
            "req-julia-macro",
            "Decls.jl",
            source;
            node_kind = "macro",
            name_equals = "baz",
            limit = 5,
        ),
    )
    @test macro_response.success
    @test macro_response.match_count == 1
    @test macro_response.matches[1]["name"] == "baz"
    @test macro_response.matches[1]["line_start"] == 4
    @test macro_response.matches[1]["line_end"] == 6

    type_response = search_julia_ast(
        ParserRequest(
            "req-julia-type",
            "Decls.jl",
            source;
            node_kind = "type",
            attribute_key = "type_kind",
            attribute_equals = "mutable_struct",
            limit = 5,
        ),
    )
    @test type_response.success
    @test type_response.match_count == 1
    @test type_response.matches[1]["name"] == "Box"
    @test type_response.matches[1]["type_kind"] == "mutable_struct"
    @test type_response.matches[1]["attribute_value"] == "mutable_struct"

    docstring_source = """
    module Demo
    \"\"\"macro docs\"\"\"
    macro baz(x)
        x
    end
    end
    """
    docstring_response = search_julia_ast(
        ParserRequest(
            "req-julia-macro-doc",
            "MacroDocs.jl",
            docstring_source;
            node_kind = "docstring",
            text_contains = "macro docs",
            limit = 5,
        ),
    )
    @test docstring_response.success
    @test docstring_response.match_count == 1
    @test docstring_response.matches[1]["name"] == "baz"
    @test docstring_response.matches[1]["target_path"] == "Demo.baz"
    @test docstring_response.matches[1]["target_line_start"] == 3
    @test docstring_response.matches[1]["target_line_end"] == 5
end
