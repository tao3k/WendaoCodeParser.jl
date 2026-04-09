@testset "Julia dependency alignment details" begin
    source = """
    module Demo
    import CSV: read as rd, write
    using DataFrames: DataFrame
    import BenchmarkTools as BT
    include("nested.jl")
    end
    """

    response = parse_julia_file_summary(ParserRequest("req-julia-deps", "Deps.jl", source))
    @test response.success
    imports = [item for item in response.summary_items if item["group"] == "import"]
    @test length(imports) == 4
    read_import = only(item for item in imports if item["dependency_target"] == "CSV.read")
    @test read_import["dependency_kind"] == "import"
    @test read_import["dependency_parent"] == "CSV"
    @test read_import["dependency_member"] == "read"
    @test read_import["dependency_alias"] == "rd"

    write_import =
        only(item for item in imports if item["dependency_target"] == "CSV.write")
    @test write_import["dependency_kind"] == "import"
    @test write_import["dependency_parent"] == "CSV"
    @test write_import["dependency_member"] == "write"
    @test !haskey(write_import, "dependency_alias") ||
          isnothing(write_import["dependency_alias"])

    using_import = only(
        item for item in imports if item["dependency_target"] == "DataFrames.DataFrame"
    )
    @test using_import["dependency_kind"] == "using"
    @test using_import["dependency_parent"] == "DataFrames"
    @test using_import["dependency_member"] == "DataFrame"

    alias_import =
        only(item for item in imports if item["dependency_target"] == "BenchmarkTools")
    @test alias_import["dependency_kind"] == "import"
    @test alias_import["dependency_alias"] == "BT"

    includes = [item for item in response.summary_items if item["group"] == "include"]
    @test length(includes) == 1
    @test includes[1]["dependency_kind"] == "include"
    @test includes[1]["dependency_target"] == "nested.jl"

    import_response = search_julia_ast(
        ParserRequest(
            "req-julia-import-deps",
            "Deps.jl",
            source;
            node_kind = "import",
            attribute_key = "dependency_alias",
            attribute_equals = "rd",
            limit = 5,
        ),
    )
    @test import_response.success
    @test import_response.match_count == 1
    @test import_response.matches[1]["name"] == "CSV.read"
    @test import_response.matches[1]["dependency_kind"] == "import"
    @test import_response.matches[1]["dependency_alias"] == "rd"
    @test import_response.matches[1]["dependency_member"] == "read"

    using_response = search_julia_ast(
        ParserRequest(
            "req-julia-using-deps",
            "Deps.jl",
            source;
            node_kind = "import",
            attribute_key = "dependency_member",
            attribute_equals = "DataFrame",
            limit = 5,
        ),
    )
    @test using_response.success
    @test using_response.match_count == 1
    @test using_response.matches[1]["name"] == "DataFrames.DataFrame"
    @test using_response.matches[1]["dependency_kind"] == "using"
    @test using_response.matches[1]["dependency_parent"] == "DataFrames"
    @test using_response.matches[1]["dependency_member"] == "DataFrame"

    include_response = search_julia_ast(
        ParserRequest(
            "req-julia-include-deps",
            "Deps.jl",
            source;
            node_kind = "include",
            attribute_key = "dependency_target",
            attribute_equals = "nested.jl",
            limit = 5,
        ),
    )
    @test include_response.success
    @test include_response.match_count == 1
    @test include_response.matches[1]["name"] == "nested.jl"
    @test include_response.matches[1]["dependency_kind"] == "include"
    @test include_response.matches[1]["dependency_target"] == "nested.jl"
end
