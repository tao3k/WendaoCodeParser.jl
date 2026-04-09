@testset "Julia relative dependency alignment details" begin
    source = """
    module Demo
    using ..Parent: foo
    import .Utils
    import ..Core: bar as baz
    end
    """

    response =
        parse_julia_file_summary(ParserRequest("req-julia-relative-deps", "Rel.jl", source))
    @test response.success
    imports = [item for item in response.summary_items if item["group"] == "import"]
    @test length(imports) == 3

    parent_import =
        only(item for item in imports if item["dependency_target"] == "..Parent.foo")
    @test parent_import["dependency_kind"] == "using"
    @test parent_import["dependency_form"] == "member"
    @test parent_import["dependency_is_relative"] == true
    @test parent_import["dependency_relative_level"] == 2
    @test parent_import["dependency_parent"] == "..Parent"
    @test parent_import["dependency_member"] == "foo"
    @test parent_import["dependency_local_name"] == "foo"

    utils_import = only(item for item in imports if item["dependency_target"] == ".Utils")
    @test utils_import["dependency_kind"] == "import"
    @test utils_import["dependency_form"] == "path"
    @test utils_import["dependency_is_relative"] == true
    @test utils_import["dependency_relative_level"] == 1
    @test utils_import["dependency_local_name"] == "Utils"

    alias_import =
        only(item for item in imports if item["dependency_target"] == "..Core.bar")
    @test alias_import["dependency_kind"] == "import"
    @test alias_import["dependency_form"] == "aliased_member"
    @test alias_import["dependency_is_relative"] == true
    @test alias_import["dependency_relative_level"] == 2
    @test alias_import["dependency_alias"] == "baz"
    @test alias_import["dependency_local_name"] == "baz"

    relative_response = search_julia_ast(
        ParserRequest(
            "req-julia-relative-deps-query",
            "Rel.jl",
            source;
            node_kind = "import",
            attribute_key = "dependency_relative_level",
            attribute_equals = "2",
            limit = 5,
        ),
    )
    @test relative_response.success
    @test relative_response.match_count == 2
    @test getindex.(relative_response.matches, "name") == ["..Parent.foo", "..Core.bar"]
    @test getindex.(relative_response.matches, "dependency_form") ==
          ["member", "aliased_member"]

    direct_response = search_julia_ast(
        ParserRequest(
            "req-julia-direct-relative-deps-query",
            "Rel.jl",
            source;
            node_kind = "import",
            attribute_key = "dependency_is_relative",
            attribute_equals = "true",
            limit = 5,
        ),
    )
    @test direct_response.success
    @test direct_response.match_count == 3
    @test getindex.(direct_response.matches, "dependency_form") ==
          ["member", "path", "aliased_member"]
end
