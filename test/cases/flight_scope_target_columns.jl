@testset "Flight services preserve stable scope and target columns" begin
    nested_julia_source = """
    module Demo
    foo() = 1
    module Inner
    bar() = 2
    end
    end
    """

    julia_summary_service = build_parser_flight_service(JULIA_FILE_SUMMARY_ROUTE)
    julia_summary_request = parser_exchange_request(
        JULIA_FILE_SUMMARY_ROUTE,
        [
            ParserRequest("req-flight-scope-summary-julia", "Demo.jl", JULIA_SOURCE),
            ParserRequest(
                "req-flight-scope-summary-julia-nested",
                "NestedDemo.jl",
                nested_julia_source,
            ),
        ],
    )
    julia_summary_table = WendaoCodeParser.WendaoArrow.flight_exchange_table(
        julia_summary_service,
        WendaoCodeParser.WendaoArrow.Arrow.Flight.ServerCallContext(),
        julia_summary_request,
    )
    julia_summary_columns = Tables.columntable(julia_summary_table)
    @test hasproperty(julia_summary_columns, :item_target_name)
    @test hasproperty(julia_summary_columns, :item_root_module_name)
    @test hasproperty(julia_summary_columns, :item_top_level)
    docstring_index = only(
        index for index in eachindex(julia_summary_columns.item_group) if
        julia_summary_columns.request_id[index] == "req-flight-scope-summary-julia" &&
        julia_summary_columns.item_group[index] == "docstring"
    )
    foo_index = only(
        index for index in eachindex(julia_summary_columns.item_group) if
        julia_summary_columns.request_id[index] == "req-flight-scope-summary-julia" &&
        julia_summary_columns.item_group[index] == "symbol" &&
        julia_summary_columns.item_name[index] == "foo"
    )
    nested_foo_index = only(
        index for index in eachindex(julia_summary_columns.item_group) if
        julia_summary_columns.request_id[index] ==
        "req-flight-scope-summary-julia-nested" &&
        julia_summary_columns.item_group[index] == "symbol" &&
        julia_summary_columns.item_name[index] == "foo"
    )
    nested_bar_index = only(
        index for index in eachindex(julia_summary_columns.item_group) if
        julia_summary_columns.request_id[index] ==
        "req-flight-scope-summary-julia-nested" &&
        julia_summary_columns.item_group[index] == "symbol" &&
        julia_summary_columns.item_name[index] == "bar"
    )
    @test julia_summary_columns.item_target_name[docstring_index] == "foo"
    @test julia_summary_columns.item_root_module_name[docstring_index] == "Demo"
    @test julia_summary_columns.item_root_module_name[foo_index] == "Demo"
    @test julia_summary_columns.item_top_level[nested_foo_index] === true
    @test julia_summary_columns.item_top_level[nested_bar_index] === false

    modelica_summary_service = build_parser_flight_service(MODELICA_FILE_SUMMARY_ROUTE)
    modelica_source = """
    model Outer
      model Inner
      end Inner;
    end Outer;
    """
    modelica_summary_request = parser_exchange_request(
        MODELICA_FILE_SUMMARY_ROUTE,
        [ParserRequest("req-flight-scope-summary-modelica", "Nested.mo", modelica_source)],
    )
    modelica_summary_table = WendaoCodeParser.WendaoArrow.flight_exchange_table(
        modelica_summary_service,
        WendaoCodeParser.WendaoArrow.Arrow.Flight.ServerCallContext(),
        modelica_summary_request,
    )
    modelica_summary_columns = Tables.columntable(modelica_summary_table)
    @test hasproperty(modelica_summary_columns, :item_top_level)
    outer_index = only(
        index for index in eachindex(modelica_summary_columns.item_group) if
        modelica_summary_columns.item_group[index] == "symbol" &&
        modelica_summary_columns.item_name[index] == "Outer"
    )
    inner_index = only(
        index for index in eachindex(modelica_summary_columns.item_group) if
        modelica_summary_columns.item_group[index] == "symbol" &&
        modelica_summary_columns.item_name[index] == "Inner"
    )
    @test modelica_summary_columns.item_top_level[outer_index] === true
    @test modelica_summary_columns.item_top_level[inner_index] === false

    julia_query_service = build_parser_flight_service(JULIA_AST_QUERY_ROUTE)
    julia_query_request = parser_exchange_request(
        JULIA_AST_QUERY_ROUTE,
        [
            ParserRequest(
                "req-flight-target-name-julia",
                "Demo.jl",
                JULIA_SOURCE;
                node_kind = "docstring",
                attribute_key = "target_name",
                attribute_equals = "foo",
                limit = 5,
            ),
            ParserRequest(
                "req-flight-root-module-julia",
                "Demo.jl",
                JULIA_SOURCE;
                node_kind = "function",
                attribute_key = "root_module_name",
                attribute_equals = "Demo",
                limit = 5,
            ),
            ParserRequest(
                "req-flight-top-level-julia",
                "NestedDemo.jl",
                nested_julia_source;
                node_kind = "function",
                attribute_key = "top_level",
                attribute_equals = "false",
                limit = 5,
            ),
        ],
    )
    julia_query_table = WendaoCodeParser.WendaoArrow.flight_exchange_table(
        julia_query_service,
        WendaoCodeParser.WendaoArrow.Arrow.Flight.ServerCallContext(),
        julia_query_request,
    )
    julia_query_columns = Tables.columntable(julia_query_table)
    @test hasproperty(julia_query_columns, :match_target_name)
    @test hasproperty(julia_query_columns, :match_root_module_name)
    @test hasproperty(julia_query_columns, :match_top_level)
    @test julia_query_columns.match_name == ["foo", "foo", "bar"]
    @test julia_query_columns.match_target_name[1] == "foo"
    @test ismissing(julia_query_columns.match_target_name[2])
    @test ismissing(julia_query_columns.match_target_name[3])
    @test julia_query_columns.match_root_module_name == ["Demo", "Demo", "Demo"]
    @test julia_query_columns.match_top_level == [true, true, false]
    @test julia_query_columns.match_attribute_value == ["foo", "Demo", "false"]

    modelica_query_service = build_parser_flight_service(MODELICA_AST_QUERY_ROUTE)
    modelica_query_request = parser_exchange_request(
        MODELICA_AST_QUERY_ROUTE,
        [
            ParserRequest(
                "req-flight-top-level-modelica",
                "Nested.mo",
                modelica_source;
                node_kind = "model",
                attribute_key = "top_level",
                attribute_equals = "true",
                limit = 5,
            ),
        ],
    )
    modelica_query_table = WendaoCodeParser.WendaoArrow.flight_exchange_table(
        modelica_query_service,
        WendaoCodeParser.WendaoArrow.Arrow.Flight.ServerCallContext(),
        modelica_query_request,
    )
    modelica_query_columns = Tables.columntable(modelica_query_table)
    @test hasproperty(modelica_query_columns, :match_top_level)
    @test modelica_query_columns.match_name == ["Outer"]
    @test modelica_query_columns.match_top_level == [true]
    @test modelica_query_columns.match_attribute_value == ["true"]
end
