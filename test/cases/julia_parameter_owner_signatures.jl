@testset "Julia parameter owner signature alignment" begin
    source = """
    module Demo
    foo(x::Int)=x
    foo(x::String)=x
    end
    """

    response = parse_julia_file_summary(
        ParserRequest("req-julia-parameter-owner-signatures", "Methods.jl", source),
    )
    @test response.success

    parameter_items =
        [item for item in response.summary_items if item["group"] == "parameter"]
    @test length(parameter_items) == 2
    @test sort([String(item["owner_signature"]) for item in parameter_items]) == ["foo(x::Int)=x", "foo(x::String)=x"]
    @test all(
        item["target_path"] in ("Demo.foo#L2", "Demo.foo#L3") for item in parameter_items
    )
end

@testset "Julia parameter owner signature AST search coverage" begin
    source = """
    module Demo
    foo(x::Int)=x
    foo(x::String)=x
    end
    """

    string_method_parameter_response = search_julia_ast(
        ParserRequest(
            "req-julia-parameter-owner-signature-string",
            "Methods.jl",
            source;
            node_kind = "parameter",
            name_equals = "x",
            attribute_key = "owner_signature",
            attribute_contains = "String",
            limit = 5,
        ),
    )
    @test string_method_parameter_response.success
    @test string_method_parameter_response.match_count == 1
    @test only(string_method_parameter_response.matches)["owner_signature"] ==
          "foo(x::String)=x"
    @test only(string_method_parameter_response.matches)["target_path"] == "Demo.foo#L3"
    @test only(string_method_parameter_response.matches)["attribute_value"] ==
          "foo(x::String)=x"
end
