@testset "Julia Flight services expose type header alignment" begin
    source = """
    module Demo
    struct Box{T<:Real,U} <: AbstractBox
        x::T
    end
    abstract type Fancy{A,B} <: Number end
    primitive type Word24 <: Unsigned 24 end
    end
    """

    summary_service = build_parser_flight_service(JULIA_FILE_SUMMARY_ROUTE)
    summary_request = parser_exchange_request(
        JULIA_FILE_SUMMARY_ROUTE,
        [ParserRequest("req-flight-julia-type-headers", "Types.jl", source)],
    )
    summary_table = WendaoCodeParser.WendaoArrow.flight_exchange_table(
        summary_service,
        WendaoCodeParser.WendaoArrow.Arrow.Flight.ServerCallContext(),
        summary_request,
    )
    summary_columns = Tables.columntable(summary_table)
    @test hasproperty(summary_columns, :item_type_parameters)
    @test hasproperty(summary_columns, :item_type_supertype)
    @test hasproperty(summary_columns, :item_primitive_bits)
    box_index = only(
        index for index in eachindex(summary_columns.item_group) if
        summary_columns.item_group[index] == "symbol" &&
        summary_columns.item_name[index] == "Box"
    )
    @test summary_columns.item_type_kind[box_index] == "struct"
    @test summary_columns.item_type_parameters[box_index] == "T<:Real, U"
    @test summary_columns.item_type_supertype[box_index] == "AbstractBox"
    primitive_index = only(
        index for index in eachindex(summary_columns.item_group) if
        summary_columns.item_group[index] == "symbol" &&
        summary_columns.item_name[index] == "Word24"
    )
    @test summary_columns.item_type_kind[primitive_index] == "primitive_type"
    @test summary_columns.item_type_supertype[primitive_index] == "Unsigned"
    @test summary_columns.item_primitive_bits[primitive_index] == "24"

    query_service = build_parser_flight_service(JULIA_AST_QUERY_ROUTE)
    query_request = parser_exchange_request(
        JULIA_AST_QUERY_ROUTE,
        [
            ParserRequest(
                "req-flight-julia-type-supertype",
                "Types.jl",
                source;
                node_kind = "type",
                attribute_key = "type_supertype",
                attribute_equals = "Number",
                limit = 5,
            ),
        ],
    )
    query_table = WendaoCodeParser.WendaoArrow.flight_exchange_table(
        query_service,
        WendaoCodeParser.WendaoArrow.Arrow.Flight.ServerCallContext(),
        query_request,
    )
    query_columns = Tables.columntable(query_table)
    @test hasproperty(query_columns, :match_type_parameters)
    @test hasproperty(query_columns, :match_type_supertype)
    @test hasproperty(query_columns, :match_primitive_bits)
    @test query_columns.match_name == ["Fancy"]
    @test query_columns.match_type_kind == ["abstract_type"]
    @test query_columns.match_type_parameters == ["A, B"]
    @test query_columns.match_type_supertype == ["Number"]
    @test query_columns.match_attribute_key == ["type_supertype"]
    @test query_columns.match_attribute_value == ["Number"]
end
