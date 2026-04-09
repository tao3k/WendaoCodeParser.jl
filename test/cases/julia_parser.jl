@testset "Julia file summary extraction" begin
    response = parse_julia_file_summary(ParserRequest("req-1", "Demo.jl", JULIA_SOURCE))
    @test response.success
    @test response.primary_name == "Demo"
    @test response.summary_scalars["module_name"] == "Demo"
    @test response.summary_scalars["module_kind"] == "module"
    @test [item["name"] for item in response.summary_items if item["group"] == "export"] == ["foo", "Bar"]
    @test [item["path"] for item in response.summary_items if item["group"] == "include"] == ["nested.jl"]
    @test [
        item["module"] for item in response.summary_items if item["group"] == "import"
    ] == ["DataFrames"]
    @test Set(
        String[
            item["name"] for item in response.summary_items if item["group"] == "symbol"
        ],
    ) == Set(["foo", "Bar"])
    docstrings = [item for item in response.summary_items if item["group"] == "docstring"]
    @test length(docstrings) == 1
    @test docstrings[1]["name"] == "foo"
    @test docstrings[1]["target_kind"] == "symbol"
    @test docstrings[1]["line_start"] == 2
    @test docstrings[1]["line_end"] == 2
    @test docstrings[1]["target_line_start"] == 3
    @test docstrings[1]["target_line_end"] == 3
    foo_symbol = only(
        item for item in response.summary_items if
        item["group"] == "symbol" && item["name"] == "foo"
    )
    @test foo_symbol["line_start"] == 3
    @test foo_symbol["line_end"] == 3
end

@testset "Julia baremodule and richer type kind alignment" begin
    source = """
    baremodule Bare
    abstract type AbstractBox end
    primitive type Word 32 end
    end
    """

    response =
        parse_julia_file_summary(ParserRequest("req-julia-module-kind", "Bare.jl", source))
    @test response.success
    @test response.primary_name == "Bare"
    @test response.summary_scalars["module_name"] == "Bare"
    @test response.summary_scalars["module_kind"] == "baremodule"

    symbols = Dict(
        String(item["name"]) => item for
        item in response.summary_items if item["group"] == "symbol"
    )
    @test symbols["AbstractBox"]["kind"] == "type"
    @test symbols["AbstractBox"]["type_kind"] == "abstract_type"
    @test symbols["Word"]["kind"] == "type"
    @test symbols["Word"]["type_kind"] == "primitive_type"

    module_response = search_julia_ast(
        ParserRequest(
            "req-julia-baremodule",
            "Bare.jl",
            source;
            node_kind = "module",
            attribute_key = "module_kind",
            attribute_equals = "baremodule",
            limit = 5,
        ),
    )
    @test module_response.success
    @test module_response.match_count == 1
    @test module_response.matches[1]["name"] == "Bare"
    @test module_response.matches[1]["module_kind"] == "baremodule"

    abstract_response = search_julia_ast(
        ParserRequest(
            "req-julia-abstract-type",
            "Bare.jl",
            source;
            node_kind = "type",
            attribute_key = "type_kind",
            attribute_equals = "abstract_type",
            limit = 5,
        ),
    )
    @test abstract_response.success
    @test abstract_response.match_count == 1
    @test abstract_response.matches[1]["name"] == "AbstractBox"
    @test abstract_response.matches[1]["type_kind"] == "abstract_type"

    primitive_response = search_julia_ast(
        ParserRequest(
            "req-julia-primitive-type",
            "Bare.jl",
            source;
            node_kind = "type",
            attribute_key = "type_kind",
            attribute_equals = "primitive_type",
            limit = 5,
        ),
    )
    @test primitive_response.success
    @test primitive_response.match_count == 1
    @test primitive_response.matches[1]["name"] == "Word"
    @test primitive_response.matches[1]["type_kind"] == "primitive_type"
end

@testset "Julia root summary requires module" begin
    response =
        parse_julia_root_summary(ParserRequest("req-2", "standalone.jl", "foo(x)=x\n"))
    @test !response.success
    @test occursin("root module", response.error_message)
end

@testset "Julia AST query search module" begin
    request = ParserRequest(
        "req-3",
        "Demo.jl",
        JULIA_SOURCE;
        node_kind = "function",
        name_contains = "fo",
        limit = 5,
    )
    response = search_julia_ast(request)
    @test response.success
    @test response.match_count == 1
    @test response.matches[1]["name"] == "foo"
    @test response.matches[1]["node_kind"] == "function"
    @test response.matches[1]["line_start"] == 3
    @test response.matches[1]["line_end"] == 3

    docstring_response = search_julia_ast(
        ParserRequest(
            "req-3-doc",
            "Demo.jl",
            JULIA_SOURCE;
            node_kind = "docstring",
            text_contains = "docstring for foo",
            limit = 5,
        ),
    )
    @test docstring_response.success
    @test docstring_response.match_count == 1
    @test docstring_response.matches[1]["name"] == "foo"
    @test docstring_response.matches[1]["node_kind"] == "docstring"
    @test docstring_response.matches[1]["line_start"] == 2
    @test docstring_response.matches[1]["line_end"] == 2
    @test docstring_response.matches[1]["target_line_start"] == 3
    @test docstring_response.matches[1]["target_line_end"] == 3
    @test docstring_response.matches[1]["target_kind"] == "symbol"
    @test docstring_response.matches[1]["target_path"] == "Demo.foo"

    reexport_response = search_julia_ast(
        ParserRequest(
            "req-3-reexport",
            "Aligned.jl",
            """
            module Demo
            @reexport using DataFrames
            end
            """;
            node_kind = "import",
            attribute_key = "reexported",
            attribute_equals = "true",
            limit = 5,
        ),
    )
    @test reexport_response.success
    @test reexport_response.match_count == 1
    @test reexport_response.matches[1]["name"] == "DataFrames"
    @test reexport_response.matches[1]["attribute_key"] == "reexported"
    @test reexport_response.matches[1]["attribute_value"] == true

    nested_response = search_julia_ast(
        ParserRequest(
            "req-3-scope",
            "Nested.jl",
            """
            module Demo
            foo(x)=x
            module Inner
            foo(x)=x + 1
            end
            end
            """;
            node_kind = "function",
            name_equals = "foo",
            limit = 10,
        ),
    )
    @test nested_response.success
    @test nested_response.match_count == 2

    inner_response = search_julia_ast(
        ParserRequest(
            "req-3-inner",
            "Nested.jl",
            """
            module Demo
            foo(x)=x
            module Inner
            foo(x)=x + 1
            end
            end
            """;
            node_kind = "function",
            name_equals = "foo",
            attribute_key = "owner_path",
            attribute_equals = "Demo.Inner",
            limit = 5,
        ),
    )
    @test inner_response.success
    @test inner_response.match_count == 1
    @test inner_response.matches[1]["name"] == "foo"
    @test inner_response.matches[1]["owner_path"] == "Demo.Inner"
    @test inner_response.matches[1]["module_path"] == "Demo.Inner"
    @test inner_response.matches[1]["attribute_value"] == "Demo.Inner"
end

@testset "Julia native syntax alignment details" begin
    response = parse_julia_file_summary(
        ParserRequest(
            "req-3-align",
            "Aligned.jl",
            """
            \"\"\"module docs\"\"\"
            module Demo
            @reexport using DataFrames

            \"\"\"docstring for foo\"\"\"
            foo(x)=x

            function bar(y)
                y
            end
            end
            """,
        ),
    )
    @test response.success
    imports = [item for item in response.summary_items if item["group"] == "import"]
    @test length(imports) == 1
    @test imports[1]["module"] == "DataFrames"
    @test imports[1]["reexported"] == true
    @test imports[1]["line_start"] == 3
    @test imports[1]["line_end"] == 3

    symbols = Dict(
        String(item["name"]) => item for
        item in response.summary_items if item["group"] == "symbol"
    )
    @test symbols["foo"]["line_start"] == 6
    @test symbols["foo"]["line_end"] == 6
    @test symbols["foo"]["signature"] == "foo(x)=x"
    @test symbols["bar"]["line_start"] == 8
    @test symbols["bar"]["line_end"] == 10
    @test symbols["bar"]["signature"] == "bar(y)"

    docstrings = [item for item in response.summary_items if item["group"] == "docstring"]
    @test length(docstrings) == 2
    module_doc = only(item for item in docstrings if item["target_kind"] == "module")
    symbol_doc = only(item for item in docstrings if item["target_kind"] == "symbol")
    @test module_doc["name"] == "Demo"
    @test module_doc["content"] == "module docs"
    @test module_doc["line_start"] == 1
    @test module_doc["line_end"] == 1
    @test module_doc["target_line_start"] == 2
    @test module_doc["target_line_end"] == 11
    @test symbol_doc["name"] == "foo"
    @test symbol_doc["content"] == "docstring for foo"
    @test symbol_doc["line_start"] == 5
    @test symbol_doc["line_end"] == 5
    @test symbol_doc["target_line_start"] == 6
    @test symbol_doc["target_line_end"] == 6

    scoped_response = parse_julia_file_summary(
        ParserRequest(
            "req-3-scoped",
            "Scoped.jl",
            """
            module Demo
            using DataFrames
            foo(x)=x
            module Inner
            using DataFrames
            foo(x)=x + 1
            end
            end
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
        item["group"] == "symbol" && item["name"] == "foo"
    ]
    @test length(scoped_symbols) == 2
    @test sort(collect(String(item["owner_path"]) for item in scoped_symbols)) ==
          ["Demo", "Demo.Inner"]
end
