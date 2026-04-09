@testset "Julia Flight services expose function header alignment" begin
    source = """
    module Demo
    foo(x::T, y=1; z::Int=2, rest...) where {T<:Real} = string(x)
    function baz(x::T, y)::String where {T<:Real}
        string(x, y)
    end
    end
    """

    summary_service = build_parser_flight_service(JULIA_FILE_SUMMARY_ROUTE)
    summary_request = parser_exchange_request(
        JULIA_FILE_SUMMARY_ROUTE,
        [ParserRequest("req-flight-julia-function-headers", "Headers.jl", source)],
    )
    summary_table = WendaoCodeParser.WendaoArrow.flight_exchange_table(
        summary_service,
        WendaoCodeParser.WendaoArrow.Arrow.Flight.ServerCallContext(),
        summary_request,
    )
    summary_columns = Tables.columntable(summary_table)
    @test hasproperty(summary_columns, :item_function_positional_arity)
    @test hasproperty(summary_columns, :item_function_keyword_arity)
    @test hasproperty(summary_columns, :item_function_has_varargs)
    @test hasproperty(summary_columns, :item_function_where_params)
    @test hasproperty(summary_columns, :item_function_return_type)

    foo_index = only(
        index for index in eachindex(summary_columns.item_group) if
        summary_columns.item_group[index] == "symbol" &&
        summary_columns.item_name[index] == "foo"
    )
    @test summary_columns.item_function_positional_arity[foo_index] == 2
    @test summary_columns.item_function_keyword_arity[foo_index] == 2
    @test summary_columns.item_function_has_varargs[foo_index] == true
    @test summary_columns.item_function_where_params[foo_index] == "T<:Real"

    baz_index = only(
        index for index in eachindex(summary_columns.item_group) if
        summary_columns.item_group[index] == "symbol" &&
        summary_columns.item_name[index] == "baz"
    )
    @test summary_columns.item_function_return_type[baz_index] == "String"

    query_service = build_parser_flight_service(JULIA_AST_QUERY_ROUTE)
    query_request = parser_exchange_request(
        JULIA_AST_QUERY_ROUTE,
        [
            ParserRequest(
                "req-flight-julia-function-return",
                "Headers.jl",
                source;
                node_kind = "function",
                attribute_key = "function_return_type",
                attribute_equals = "String",
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
    @test hasproperty(query_columns, :match_function_positional_arity)
    @test hasproperty(query_columns, :match_function_keyword_arity)
    @test hasproperty(query_columns, :match_function_has_varargs)
    @test hasproperty(query_columns, :match_function_where_params)
    @test hasproperty(query_columns, :match_function_return_type)
    @test query_columns.match_name == ["baz"]
    @test query_columns.match_function_return_type == ["String"]
    @test query_columns.match_function_positional_arity == [2]
    @test query_columns.match_function_keyword_arity == [0]
    @test query_columns.match_function_has_varargs == [false]
    @test query_columns.match_function_where_params == ["T<:Real"]
end
