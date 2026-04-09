@testset "Julia type header alignment" begin
    source = """
    module Demo
    struct Box{T<:Real,U} <: AbstractBox
        x::T
    end
    abstract type Fancy{A,B} <: Number end
    primitive type Word24 <: Unsigned 24 end
    end
    """

    response = parse_julia_file_summary(
        ParserRequest("req-julia-type-headers", "Types.jl", source),
    )
    @test response.success

    symbols = Dict(
        String(item["name"]) => item for
        item in response.summary_items if item["group"] == "symbol"
    )

    @test symbols["Box"]["kind"] == "type"
    @test symbols["Box"]["type_kind"] == "struct"
    @test symbols["Box"]["type_parameters"] == "T<:Real, U"
    @test symbols["Box"]["type_supertype"] == "AbstractBox"

    @test symbols["Fancy"]["kind"] == "type"
    @test symbols["Fancy"]["type_kind"] == "abstract_type"
    @test symbols["Fancy"]["type_parameters"] == "A, B"
    @test symbols["Fancy"]["type_supertype"] == "Number"

    @test symbols["Word24"]["kind"] == "type"
    @test symbols["Word24"]["type_kind"] == "primitive_type"
    @test symbols["Word24"]["type_supertype"] == "Unsigned"
    @test symbols["Word24"]["primitive_bits"] == "24"

    supertype_response = search_julia_ast(
        ParserRequest(
            "req-julia-type-supertype",
            "Types.jl",
            source;
            node_kind = "type",
            attribute_key = "type_supertype",
            attribute_equals = "Number",
            limit = 5,
        ),
    )
    @test supertype_response.success
    @test supertype_response.match_count == 1
    @test supertype_response.matches[1]["name"] == "Fancy"
    @test supertype_response.matches[1]["type_supertype"] == "Number"
    @test supertype_response.matches[1]["attribute_value"] == "Number"

    parameter_response = search_julia_ast(
        ParserRequest(
            "req-julia-type-parameters",
            "Types.jl",
            source;
            node_kind = "type",
            attribute_key = "type_parameters",
            attribute_equals = "T<:Real, U",
            limit = 5,
        ),
    )
    @test parameter_response.success
    @test parameter_response.match_count == 1
    @test parameter_response.matches[1]["name"] == "Box"
    @test parameter_response.matches[1]["type_parameters"] == "T<:Real, U"

    primitive_response = search_julia_ast(
        ParserRequest(
            "req-julia-primitive-bits",
            "Types.jl",
            source;
            node_kind = "type",
            attribute_key = "primitive_bits",
            attribute_equals = "24",
            limit = 5,
        ),
    )
    @test primitive_response.success
    @test primitive_response.match_count == 1
    @test primitive_response.matches[1]["name"] == "Word24"
    @test primitive_response.matches[1]["primitive_bits"] == "24"
end
