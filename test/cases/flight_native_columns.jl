@testset "Flight services expose native parser scope columns" begin
    julia_summary_service = build_parser_flight_service(JULIA_FILE_SUMMARY_ROUTE)
    julia_summary_request = parser_exchange_request(
        JULIA_FILE_SUMMARY_ROUTE,
        [
            ParserRequest(
                "req-flight-scope-summary",
                "Scoped.jl",
                """
                module Demo
                using DataFrames
                \"\"\"docstring for foo\"\"\"
                foo(x)=x
                module Inner
                using DataFrames
                foo(x)=x + 1
                end
                end
                """,
            ),
        ],
    )
    julia_summary_table = WendaoCodeParser.WendaoArrow.flight_exchange_table(
        julia_summary_service,
        WendaoCodeParser.WendaoArrow.Arrow.Flight.ServerCallContext(),
        julia_summary_request,
    )
    julia_summary_columns = Tables.columntable(julia_summary_table)
    @test hasproperty(julia_summary_columns, :item_owner_kind)
    @test hasproperty(julia_summary_columns, :item_owner_path)
    @test hasproperty(julia_summary_columns, :item_module_name)
    @test hasproperty(julia_summary_columns, :item_module_path)
    @test hasproperty(julia_summary_columns, :item_target_path)
    foo_indices = findall(
        index ->
            julia_summary_columns.item_group[index] == "symbol" &&
                julia_summary_columns.item_name[index] == "foo",
        eachindex(julia_summary_columns.item_group),
    )
    @test sort(
        collect(julia_summary_columns.item_owner_path[index] for index in foo_indices),
    ) == ["Demo", "Demo.Inner"]
    docstring_index = only(
        index for index in eachindex(julia_summary_columns.item_group) if
        julia_summary_columns.item_group[index] == "docstring"
    )
    @test julia_summary_columns.item_module_name[docstring_index] == "Demo"
    @test julia_summary_columns.item_module_path[docstring_index] == "Demo"
    @test julia_summary_columns.item_target_path[docstring_index] == "Demo.foo"

    julia_query_service = build_parser_flight_service(JULIA_AST_QUERY_ROUTE)
    julia_query_request = parser_exchange_request(
        JULIA_AST_QUERY_ROUTE,
        [
            ParserRequest(
                "req-flight-scope-query",
                "Scoped.jl",
                """
                module Demo
                foo(x)=x
                module Inner
                foo(x)=x + 1
                end
                end
                """;
                node_kind = "function",
                name_equals = "foo",
                attribute_key = "owner_path",
                attribute_equals = "Demo.Inner",
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
    @test hasproperty(julia_query_columns, :match_target_kind)
    @test hasproperty(julia_query_columns, :match_owner_kind)
    @test hasproperty(julia_query_columns, :match_owner_path)
    @test hasproperty(julia_query_columns, :match_module_name)
    @test hasproperty(julia_query_columns, :match_module_path)
    @test hasproperty(julia_query_columns, :match_target_path)
    @test julia_query_columns.match_owner_kind == ["module"]
    @test julia_query_columns.match_owner_path == ["Demo.Inner"]
    @test julia_query_columns.match_module_name == ["Inner"]
    @test julia_query_columns.match_module_path == ["Demo.Inner"]

    docstring_query_request = parser_exchange_request(
        JULIA_AST_QUERY_ROUTE,
        [
            ParserRequest(
                "req-flight-scope-doc",
                "Docs.jl",
                """
                module Demo
                \"\"\"docstring for foo\"\"\"
                foo(x)=x
                end
                """;
                node_kind = "docstring",
                text_contains = "docstring for foo",
                limit = 5,
            ),
        ],
    )
    docstring_query_table = WendaoCodeParser.WendaoArrow.flight_exchange_table(
        julia_query_service,
        WendaoCodeParser.WendaoArrow.Arrow.Flight.ServerCallContext(),
        docstring_query_request,
    )
    docstring_query_columns = Tables.columntable(docstring_query_table)
    @test docstring_query_columns.match_target_kind == ["symbol"]
    @test docstring_query_columns.match_target_path == ["Demo.foo"]

    modelica_summary_service = build_parser_flight_service(MODELICA_FILE_SUMMARY_ROUTE)
    modelica_summary_request = parser_exchange_request(
        MODELICA_FILE_SUMMARY_ROUTE,
        [
            ParserRequest(
                "req-flight-modelica-summary",
                "Scoped.mo",
                """
                model Demo
                  parameter Integer n = 1;
                  model Inner
                    parameter Integer n = 2;
                  end Inner;
                end Demo;
                """,
            ),
        ],
    )
    modelica_summary_table = WendaoCodeParser.WendaoArrow.flight_exchange_table(
        modelica_summary_service,
        WendaoCodeParser.WendaoArrow.Arrow.Flight.ServerCallContext(),
        modelica_summary_request,
    )
    modelica_summary_columns = Tables.columntable(modelica_summary_table)
    @test hasproperty(modelica_summary_columns, :item_owner_path)
    @test hasproperty(modelica_summary_columns, :item_class_path)
    modelica_symbol_indices = findall(
        index ->
            modelica_summary_columns.item_group[index] == "symbol" &&
                modelica_summary_columns.item_name[index] == "n",
        eachindex(modelica_summary_columns.item_group),
    )
    @test sort(
        collect(
            modelica_summary_columns.item_owner_path[index] for
            index in modelica_symbol_indices
        ),
    ) == ["Demo", "Demo.Inner"]
    @test sort(
        collect(
            modelica_summary_columns.item_class_path[index] for
            index in modelica_symbol_indices
        ),
    ) == ["Demo", "Demo.Inner"]
end
