@testset "Julia Flight services round-trip summary and query responses" begin
    summary_service = build_parser_flight_service(JULIA_FILE_SUMMARY_ROUTE)
    summary_request = parser_exchange_request(
        JULIA_FILE_SUMMARY_ROUTE,
        [ParserRequest("req-4", "Demo.jl", JULIA_SOURCE)],
    )
    summary_table = WendaoCodeParser.WendaoArrow.flight_exchange_table(
        summary_service,
        WendaoCodeParser.WendaoArrow.Arrow.Flight.ServerCallContext(),
        summary_request,
    )
    summary_columns = Tables.columntable(summary_table)
    @test all(summary_columns.success)
    @test unique(summary_columns.module_name) == ["Demo"]
    @test unique(summary_columns.module_kind) == ["module"]
    @test Set(
        String[
            summary_columns.item_group[index] for
            index in eachindex(summary_columns.item_group)
        ],
    ) == Set(["export", "import", "symbol", "parameter", "docstring", "include"])
    @test Set(
        String[
            summary_columns.item_name[index] for
            index in eachindex(summary_columns.item_group) if
            summary_columns.item_group[index] == "symbol"
        ],
    ) == Set(["foo", "Bar"])
    @test hasproperty(summary_columns, :item_target_line_start)
    @test hasproperty(summary_columns, :item_target_line_end)
    docstring_index = only(
        index for index in eachindex(summary_columns.item_group) if
        summary_columns.item_group[index] == "docstring"
    )
    @test summary_columns.item_line_start[docstring_index] == 2
    @test summary_columns.item_line_end[docstring_index] == 2
    @test summary_columns.item_target_line_start[docstring_index] == 3
    @test summary_columns.item_target_line_end[docstring_index] == 3
    summary_metadata = WendaoCodeParser.WendaoArrow.schema_metadata(summary_table)
    @test summary_metadata["x-wendao-code-parser-contract-shape"] == "summary_item_rows"

    query_service = build_parser_flight_service(JULIA_AST_QUERY_ROUTE)
    query_request = parser_exchange_request(
        JULIA_AST_QUERY_ROUTE,
        [ParserRequest("req-5", "Demo.jl", JULIA_SOURCE; node_kind = "include")],
    )
    query_table = WendaoCodeParser.WendaoArrow.flight_exchange_table(
        query_service,
        WendaoCodeParser.WendaoArrow.Arrow.Flight.ServerCallContext(),
        query_request,
    )
    query_columns = Tables.columntable(query_table)
    @test query_columns.success == [true]
    @test query_columns.match_count == [1]
    @test query_columns.match_name == ["nested.jl"]
    @test query_columns.match_node_kind == ["include"]
    @test hasproperty(query_columns, :match_module_kind)
    @test hasproperty(query_columns, :match_target_line_start)
    @test hasproperty(query_columns, :match_target_line_end)

    docstring_query_request = parser_exchange_request(
        JULIA_AST_QUERY_ROUTE,
        [
            ParserRequest(
                "req-5-doc",
                "Demo.jl",
                JULIA_SOURCE;
                node_kind = "docstring",
                text_contains = "docstring for foo",
            ),
        ],
    )
    docstring_query_table = WendaoCodeParser.WendaoArrow.flight_exchange_table(
        query_service,
        WendaoCodeParser.WendaoArrow.Arrow.Flight.ServerCallContext(),
        docstring_query_request,
    )
    docstring_query_columns = Tables.columntable(docstring_query_table)
    @test docstring_query_columns.success == [true]
    @test docstring_query_columns.match_count == [1]
    @test docstring_query_columns.match_name == ["foo"]
    @test docstring_query_columns.match_node_kind == ["docstring"]
    @test docstring_query_columns.match_line_start == [2]
    @test docstring_query_columns.match_line_end == [2]
    @test docstring_query_columns.match_target_line_start == [3]
    @test docstring_query_columns.match_target_line_end == [3]
    @test hasproperty(docstring_query_columns, :match_attribute_key)
    @test hasproperty(docstring_query_columns, :match_attribute_value)
end

@testset "Parser service route parsing and routed live service" begin
    @test parser_service_route_names([
        "--code-parser-route-names",
        "julia_file_summary,julia-ast-query",
    ]) == [JULIA_FILE_SUMMARY_ROUTE, JULIA_AST_QUERY_ROUTE]
    @test parser_service_route_names(["--code-parser-routes", "all"]) ==
          supported_parser_route_names()

    listener = parser_service_listener_config([
        "--max-active-requests",
        "4",
        "--request-capacity=3",
        "--response-capacity",
        "2",
    ])
    @test listener.max_active_requests == 4
    @test listener.request_capacity == 3
    @test listener.response_capacity == 2
    @test parser_service_interface_args([
        "--config",
        "config/live/parser_summary.toml",
        "--code-parser-route-names",
        "julia_ast_query",
        "--max-active-requests",
        "4",
        "--host",
        "127.0.0.1",
        "--port=41081",
    ]) == [
        "--config",
        "config/live/parser_summary.toml",
        "--host",
        "127.0.0.1",
        "--port=41081",
    ]

    live_service =
        build_parser_live_flight_service([JULIA_FILE_SUMMARY_ROUTE, JULIA_AST_QUERY_ROUTE])
    request = parser_exchange_request(
        JULIA_AST_QUERY_ROUTE,
        [ParserRequest("live-query", "Demo.jl", JULIA_SOURCE; node_kind = "function")],
    )
    table = WendaoCodeParser.WendaoArrow.flight_exchange_table(
        live_service,
        WendaoCodeParser.WendaoArrow.Arrow.Flight.ServerCallContext(),
        request,
    )
    columns = Tables.columntable(table)
    @test columns.request_id == ["live-query"]
    @test columns.success == [true]
    @test columns.match_name == ["foo"]
end

@testset "Modelica Flight services round-trip summary response" begin
    summary_service = build_parser_flight_service(MODELICA_FILE_SUMMARY_ROUTE)
    summary_request = parser_exchange_request(
        MODELICA_FILE_SUMMARY_ROUTE,
        [ParserRequest(
            "req-8",
            "Demo.mo",
            """
            model Demo
              Real x;
            end Demo;
            """,
        )],
    )
    summary_table = WendaoCodeParser.WendaoArrow.flight_exchange_table(
        summary_service,
        WendaoCodeParser.WendaoArrow.Arrow.Flight.ServerCallContext(),
        summary_request,
    )
    summary_columns = Tables.columntable(summary_table)
    @test all(summary_columns.success)
    @test unique(summary_columns.backend) == ["OMParser.jl"]
    @test unique(summary_columns.class_name) == ["Demo"]
    @test unique(summary_columns.restriction) == ["model"]
    @test hasproperty(summary_columns, :item_visibility)
    @test hasproperty(summary_columns, :item_line_start)
    @test hasproperty(summary_columns, :item_array_dimensions)
    @test hasproperty(summary_columns, :item_start_value)
    @test hasproperty(summary_columns, :item_modifier_names)
    @test Set(
        String[
            summary_columns.item_name[index] for
            index in eachindex(summary_columns.item_group) if
            summary_columns.item_group[index] == "symbol"
        ],
    ) == Set(["Demo", "x"])
end

@testset "Modelica Flight services expose component modifier details" begin
    summary_service = build_parser_flight_service(MODELICA_FILE_SUMMARY_ROUTE)
    summary_request = parser_exchange_request(
        MODELICA_FILE_SUMMARY_ROUTE,
        [
            ParserRequest(
                "req-8-modifiers",
                "Modifiers.mo",
                """
                model Demo
                  parameter Real x[3](unit="s", start=1) = 2;
                end Demo;
                """,
            ),
        ],
    )
    summary_table = WendaoCodeParser.WendaoArrow.flight_exchange_table(
        summary_service,
        WendaoCodeParser.WendaoArrow.Arrow.Flight.ServerCallContext(),
        summary_request,
    )
    summary_columns = Tables.columntable(summary_table)
    x_index = only(
        index for index in eachindex(summary_columns.item_group) if
        summary_columns.item_group[index] == "symbol" &&
        summary_columns.item_name[index] == "x"
    )
    @test summary_columns.item_array_dimensions[x_index] == "[3]"
    @test summary_columns.item_start_value[x_index] == "1"
    @test summary_columns.item_modifier_names[x_index] == "unit,start"

    query_service = build_parser_flight_service(MODELICA_AST_QUERY_ROUTE)
    query_request = parser_exchange_request(
        MODELICA_AST_QUERY_ROUTE,
        [
            ParserRequest(
                "req-8-start-query",
                "Modifiers.mo",
                """
                model Demo
                  parameter Real x[3](unit="s", start=1) = 2;
                end Demo;
                """;
                node_kind = "component",
                attribute_key = "start_value",
                attribute_equals = "1",
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
    @test hasproperty(query_columns, :match_array_dimensions)
    @test hasproperty(query_columns, :match_start_value)
    @test hasproperty(query_columns, :match_modifier_names)
    @test query_columns.match_name == ["x"]
    @test query_columns.match_start_value == ["1"]
    @test query_columns.match_modifier_names == ["unit,start"]
end
