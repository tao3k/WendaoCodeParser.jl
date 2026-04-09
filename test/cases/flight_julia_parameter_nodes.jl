@testset "Julia Flight services expose parameter nodes" begin
    source = """
    module Demo
    function qux(a, b=1, c::Int=2, args...; k=3, t::T=4, kwargs...) where {T}
        a
    end
    end
    """

    summary_service = build_parser_flight_service(JULIA_FILE_SUMMARY_ROUTE)
    summary_request = parser_exchange_request(
        JULIA_FILE_SUMMARY_ROUTE,
        [ParserRequest("req-flight-julia-parameter-nodes", "Params.jl", source)],
    )
    summary_table = WendaoCodeParser.WendaoArrow.flight_exchange_table(
        summary_service,
        WendaoCodeParser.WendaoArrow.Arrow.Flight.ServerCallContext(),
        summary_request,
    )
    summary_columns = Tables.columntable(summary_table)
    @test hasproperty(summary_columns, :item_parameter_kind)
    @test hasproperty(summary_columns, :item_parameter_type_name)
    @test hasproperty(summary_columns, :item_parameter_default_value)
    @test hasproperty(summary_columns, :item_parameter_is_typed)
    @test hasproperty(summary_columns, :item_parameter_is_defaulted)
    @test hasproperty(summary_columns, :item_parameter_is_vararg)

    c_index = only(
        index for index in eachindex(summary_columns.item_group) if
        summary_columns.item_group[index] == "parameter" &&
        summary_columns.item_name[index] == "c"
    )
    @test summary_columns.item_parameter_kind[c_index] == "positional"
    @test summary_columns.item_parameter_type_name[c_index] == "Int"
    @test summary_columns.item_parameter_default_value[c_index] == "2"
    @test summary_columns.item_parameter_is_typed[c_index] == true
    @test summary_columns.item_parameter_is_defaulted[c_index] == true
    @test summary_columns.item_target_path[c_index] == "Demo.qux#L2"

    query_service = build_parser_flight_service(JULIA_AST_QUERY_ROUTE)
    query_request = parser_exchange_request(
        JULIA_AST_QUERY_ROUTE,
        [
            ParserRequest(
                "req-flight-julia-parameter-query",
                "Params.jl",
                source;
                node_kind = "parameter",
                attribute_key = "parameter_type_name",
                attribute_equals = "Int",
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
    @test hasproperty(query_columns, :match_parameter_kind)
    @test hasproperty(query_columns, :match_parameter_type_name)
    @test hasproperty(query_columns, :match_parameter_default_value)
    @test hasproperty(query_columns, :match_parameter_is_typed)
    @test hasproperty(query_columns, :match_parameter_is_defaulted)
    @test hasproperty(query_columns, :match_parameter_is_vararg)
    @test query_columns.match_name == ["c"]
    @test query_columns.match_parameter_kind == ["positional"]
    @test query_columns.match_parameter_type_name == ["Int"]
    @test query_columns.match_parameter_default_value == ["2"]
    @test query_columns.match_parameter_is_typed == [true]
    @test query_columns.match_parameter_is_defaulted == [true]
    @test query_columns.match_target_path == ["Demo.qux#L2"]
end
