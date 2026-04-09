@testset "Julia parameter node alignment" begin
    source = """
    module Demo
    function qux(a, b=1, c::Int=2, args...; k=3, t::T=4, kwargs...) where {T}
        a
    end
    end
    """

    response = parse_julia_file_summary(
        ParserRequest("req-julia-parameter-nodes", "Params.jl", source),
    )
    @test response.success

    parameter_items =
        [item for item in response.summary_items if item["group"] == "parameter"]
    @test length(parameter_items) == 7

    typed_defaulted = only(item for item in parameter_items if item["name"] == "c")
    @test typed_defaulted["parameter_kind"] == "positional"
    @test typed_defaulted["parameter_type_name"] == "Int"
    @test typed_defaulted["parameter_default_value"] == "2"
    @test typed_defaulted["parameter_is_typed"] == true
    @test typed_defaulted["parameter_is_defaulted"] == true
    @test typed_defaulted["parameter_is_vararg"] == false
    @test typed_defaulted["target_kind"] == "function"
    @test typed_defaulted["target_path"] == "Demo.qux#L2"
    @test typed_defaulted["owner_path"] == "Demo.qux"

    keyword_vararg = only(item for item in parameter_items if item["name"] == "kwargs")
    @test keyword_vararg["parameter_kind"] == "keyword"
    @test keyword_vararg["parameter_is_vararg"] == true
    @test keyword_vararg["path"] == "Demo.qux#L2.kwargs"
end

@testset "Julia parameter node AST search coverage" begin
    source = """
    module Demo
    function qux(a, b=1, c::Int=2, args...; k=3, t::T=4, kwargs...) where {T}
        a
    end
    end
    """

    typed_response = search_julia_ast(
        ParserRequest(
            "req-julia-parameter-type",
            "Params.jl",
            source;
            node_kind = "parameter",
            attribute_key = "parameter_type_name",
            attribute_equals = "Int",
            limit = 5,
        ),
    )
    @test typed_response.success
    @test typed_response.match_count == 1
    @test only(typed_response.matches)["name"] == "c"

    keyword_default_response = search_julia_ast(
        ParserRequest(
            "req-julia-parameter-default",
            "Params.jl",
            source;
            node_kind = "parameter",
            attribute_key = "parameter_default_value",
            attribute_equals = "4",
            limit = 5,
        ),
    )
    @test keyword_default_response.success
    @test keyword_default_response.match_count == 1
    @test only(keyword_default_response.matches)["name"] == "t"

    keyword_vararg_response = search_julia_ast(
        ParserRequest(
            "req-julia-parameter-vararg",
            "Params.jl",
            source;
            node_kind = "parameter",
            name_equals = "kwargs",
            attribute_key = "parameter_is_vararg",
            attribute_equals = "true",
            limit = 5,
        ),
    )
    @test keyword_vararg_response.success
    @test keyword_vararg_response.match_count == 1
    @test only(keyword_vararg_response.matches)["target_path"] == "Demo.qux#L2"
end
