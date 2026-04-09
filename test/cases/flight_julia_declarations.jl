@testset "Julia Flight services expose declaration coverage" begin
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

    summary_service = build_parser_flight_service(JULIA_FILE_SUMMARY_ROUTE)
    summary_request = parser_exchange_request(
        JULIA_FILE_SUMMARY_ROUTE,
        [ParserRequest("req-flight-julia-decls", "Decls.jl", source)],
    )
    summary_table = WendaoCodeParser.WendaoArrow.flight_exchange_table(
        summary_service,
        WendaoCodeParser.WendaoArrow.Arrow.Flight.ServerCallContext(),
        summary_request,
    )
    summary_columns = Tables.columntable(summary_table)
    @test hasproperty(summary_columns, :item_binding_kind)
    @test hasproperty(summary_columns, :item_type_kind)
    foo_index = only(
        index for index in eachindex(summary_columns.item_group) if
        summary_columns.item_group[index] == "symbol" &&
        summary_columns.item_name[index] == "FOO"
    )
    @test summary_columns.item_kind[foo_index] == "binding"
    @test summary_columns.item_binding_kind[foo_index] == "const"
    box_index = only(
        index for index in eachindex(summary_columns.item_group) if
        summary_columns.item_group[index] == "symbol" &&
        summary_columns.item_name[index] == "Box"
    )
    @test summary_columns.item_kind[box_index] == "type"
    @test summary_columns.item_type_kind[box_index] == "mutable_struct"
    baz_index = only(
        index for index in eachindex(summary_columns.item_group) if
        summary_columns.item_group[index] == "symbol" &&
        summary_columns.item_name[index] == "baz"
    )
    @test summary_columns.item_kind[baz_index] == "macro"

    query_service = build_parser_flight_service(JULIA_AST_QUERY_ROUTE)
    binding_request = parser_exchange_request(
        JULIA_AST_QUERY_ROUTE,
        [
            ParserRequest(
                "req-flight-julia-binding",
                "Decls.jl",
                source;
                node_kind = "binding",
                attribute_key = "binding_kind",
                attribute_equals = "const",
                limit = 5,
            ),
        ],
    )
    binding_table = WendaoCodeParser.WendaoArrow.flight_exchange_table(
        query_service,
        WendaoCodeParser.WendaoArrow.Arrow.Flight.ServerCallContext(),
        binding_request,
    )
    binding_columns = Tables.columntable(binding_table)
    @test hasproperty(binding_columns, :match_binding_kind)
    @test binding_columns.match_name == ["FOO"]
    @test binding_columns.match_binding_kind == ["const"]

    type_request = parser_exchange_request(
        JULIA_AST_QUERY_ROUTE,
        [
            ParserRequest(
                "req-flight-julia-type",
                "Decls.jl",
                source;
                node_kind = "type",
                attribute_key = "type_kind",
                attribute_equals = "mutable_struct",
                limit = 5,
            ),
        ],
    )
    type_table = WendaoCodeParser.WendaoArrow.flight_exchange_table(
        query_service,
        WendaoCodeParser.WendaoArrow.Arrow.Flight.ServerCallContext(),
        type_request,
    )
    type_columns = Tables.columntable(type_table)
    @test hasproperty(type_columns, :match_type_kind)
    @test type_columns.match_name == ["Box"]
    @test type_columns.match_type_kind == ["mutable_struct"]
end

@testset "Julia Flight services expose module kind and richer type kinds" begin
    source = """
    baremodule Bare
    abstract type AbstractBox end
    primitive type Word 32 end
    end
    """

    summary_service = build_parser_flight_service(JULIA_FILE_SUMMARY_ROUTE)
    summary_request = parser_exchange_request(
        JULIA_FILE_SUMMARY_ROUTE,
        [ParserRequest("req-flight-julia-module-kind", "Bare.jl", source)],
    )
    summary_table = WendaoCodeParser.WendaoArrow.flight_exchange_table(
        summary_service,
        WendaoCodeParser.WendaoArrow.Arrow.Flight.ServerCallContext(),
        summary_request,
    )
    summary_columns = Tables.columntable(summary_table)
    @test hasproperty(summary_columns, :module_kind)
    @test unique(summary_columns.module_kind) == ["baremodule"]
    @test hasproperty(summary_columns, :item_type_kind)
    abstract_index = only(
        index for index in eachindex(summary_columns.item_group) if
        summary_columns.item_group[index] == "symbol" &&
        summary_columns.item_name[index] == "AbstractBox"
    )
    @test summary_columns.item_type_kind[abstract_index] == "abstract_type"
    primitive_index = only(
        index for index in eachindex(summary_columns.item_group) if
        summary_columns.item_group[index] == "symbol" &&
        summary_columns.item_name[index] == "Word"
    )
    @test summary_columns.item_type_kind[primitive_index] == "primitive_type"

    query_service = build_parser_flight_service(JULIA_AST_QUERY_ROUTE)
    module_request = parser_exchange_request(
        JULIA_AST_QUERY_ROUTE,
        [
            ParserRequest(
                "req-flight-julia-baremodule",
                "Bare.jl",
                source;
                node_kind = "module",
                attribute_key = "module_kind",
                attribute_equals = "baremodule",
                limit = 5,
            ),
        ],
    )
    module_table = WendaoCodeParser.WendaoArrow.flight_exchange_table(
        query_service,
        WendaoCodeParser.WendaoArrow.Arrow.Flight.ServerCallContext(),
        module_request,
    )
    module_columns = Tables.columntable(module_table)
    @test hasproperty(module_columns, :match_module_kind)
    @test module_columns.match_name == ["Bare"]
    @test module_columns.match_module_kind == ["baremodule"]

    abstract_request = parser_exchange_request(
        JULIA_AST_QUERY_ROUTE,
        [
            ParserRequest(
                "req-flight-julia-abstract-type",
                "Bare.jl",
                source;
                node_kind = "type",
                attribute_key = "type_kind",
                attribute_equals = "abstract_type",
                limit = 5,
            ),
        ],
    )
    abstract_table = WendaoCodeParser.WendaoArrow.flight_exchange_table(
        query_service,
        WendaoCodeParser.WendaoArrow.Arrow.Flight.ServerCallContext(),
        abstract_request,
    )
    abstract_columns = Tables.columntable(abstract_table)
    @test abstract_columns.match_name == ["AbstractBox"]
    @test abstract_columns.match_type_kind == ["abstract_type"]
end
