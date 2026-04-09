@testset "Julia Flight services expose function parameter alignment" begin
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
        [ParserRequest("req-flight-julia-function-params", "Params.jl", source)],
    )
    summary_table = WendaoCodeParser.WendaoArrow.flight_exchange_table(
        summary_service,
        WendaoCodeParser.WendaoArrow.Arrow.Flight.ServerCallContext(),
        summary_request,
    )
    summary_columns = Tables.columntable(summary_table)
    @test hasproperty(summary_columns, :item_function_positional_params)
    @test hasproperty(summary_columns, :item_function_keyword_params)
    @test hasproperty(summary_columns, :item_function_defaulted_params)
    @test hasproperty(summary_columns, :item_function_typed_params)
    @test hasproperty(summary_columns, :item_function_positional_vararg_name)
    @test hasproperty(summary_columns, :item_function_keyword_vararg_name)

    qux_index = only(
        index for index in eachindex(summary_columns.item_group) if
        summary_columns.item_group[index] == "symbol" &&
        summary_columns.item_name[index] == "qux"
    )
    @test summary_columns.item_function_positional_params[qux_index] == "a,b,c,args"
    @test summary_columns.item_function_keyword_params[qux_index] == "k,t,kwargs"
    @test summary_columns.item_function_defaulted_params[qux_index] == "b,c,k,t"
    @test summary_columns.item_function_typed_params[qux_index] == "c,t"
    @test summary_columns.item_function_positional_vararg_name[qux_index] == "args"
    @test summary_columns.item_function_keyword_vararg_name[qux_index] == "kwargs"

    query_service = build_parser_flight_service(JULIA_AST_QUERY_ROUTE)
    query_request = parser_exchange_request(
        JULIA_AST_QUERY_ROUTE,
        [
            ParserRequest(
                "req-flight-julia-function-param-query",
                "Params.jl",
                source;
                node_kind = "function",
                attribute_key = "function_keyword_params",
                attribute_contains = "kwargs",
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
    @test hasproperty(query_columns, :match_function_positional_params)
    @test hasproperty(query_columns, :match_function_keyword_params)
    @test hasproperty(query_columns, :match_function_defaulted_params)
    @test hasproperty(query_columns, :match_function_typed_params)
    @test hasproperty(query_columns, :match_function_positional_vararg_name)
    @test hasproperty(query_columns, :match_function_keyword_vararg_name)
    @test query_columns.match_name == ["qux"]
    @test query_columns.match_function_keyword_params == ["k,t,kwargs"]
    @test query_columns.match_function_positional_vararg_name == ["args"]
    @test query_columns.match_function_keyword_vararg_name == ["kwargs"]
end
