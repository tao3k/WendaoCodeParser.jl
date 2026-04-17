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

@testset "Flight summary rows bound heavy parser text fields for transport" begin
    long_documentation = repeat("Modelica package documentation line. ", 800)
    response = parse_modelica_file_summary(
        ParserRequest(
            "req-flight-modelica-heavy-summary",
            "Heavy.mo",
            """
            model Heavy
              Real y;
              // $(long_documentation)
            equation
              y = y + 1;
            end Heavy;
            """,
        ),
    )
    @test response.success

    documentation_item =
        first(item for item in response.summary_items if item["group"] == "documentation")
    @test length(String(documentation_item["content"])) >
          WendaoCodeParser.PARSER_SUMMARY_HEAVY_TEXT_MAX_CHARS

    summary_table = parser_response_arrow_table(MODELICA_FILE_SUMMARY_ROUTE, [response])
    summary_columns = Tables.columntable(summary_table)

    documentation_index = findfirst(==("documentation"), summary_columns.item_group)
    @test !isnothing(documentation_index)

    documentation_payload = String(summary_columns.item_content[documentation_index])
    @test endswith(
        documentation_payload,
        WendaoCodeParser.PARSER_SUMMARY_HEAVY_TEXT_TRUNCATION_SUFFIX,
    )
    @test length(documentation_payload) <=
          WendaoCodeParser.PARSER_SUMMARY_HEAVY_TEXT_MAX_CHARS +
          length(WendaoCodeParser.PARSER_SUMMARY_HEAVY_TEXT_TRUNCATION_SUFFIX)
end

@testset "Flight summary rows roundtrip large transport payloads through a single batch" begin
    response = ParserResponse(
        "req-flight-modelica-partitioned-summary",
        "Partitioned.mo",
        "modelica_file_summary",
        "omparser";
        success = true,
        summary_items = [
            Dict(
                "group" => "documentation",
                "name" => "Partitioned",
                "kind" => "package",
                "content" => repeat("Modelica summary payload. ", 80),
                "module" => "Partitioned",
                "path" => "Partitioned",
            ) for _ = 1:80
        ],
    )

    summary_table = parser_response_arrow_table(MODELICA_FILE_SUMMARY_ROUTE, [response])
    partitions = collect(Tables.partitions(summary_table))
    summary_columns = Tables.columntable(summary_table)
    roundtrip_table = WendaoCodeParser.WendaoArrow.Arrow.Table(
        WendaoCodeParser.WendaoArrow.Arrow.tobuffer(summary_table),
    )
    roundtrip_columns = Tables.columntable(roundtrip_table)

    @test length(partitions) == 1
    @test length(summary_columns.item_group) == 80
    @test count(==("documentation"), summary_columns.item_group) == 80
    @test length(roundtrip_columns.item_group) == 80
    @test count(==("documentation"), roundtrip_columns.item_group) == 80
end

@testset "Flight summary rows partition dense parser-summary responses" begin
    response = ParserResponse(
        "req-flight-modelica-dense-summary",
        "Dense.mo",
        "modelica_file_summary",
        "omparser";
        success = true,
        summary_items = [
            Dict(
                "group" => "documentation",
                "name" => "Dense$(index)",
                "kind" => "package",
                "content" => "dense summary row $(index)",
                "module" => "Dense",
                "path" => "Dense.$(index)",
            ) for index = 1:1025
        ],
    )

    summary_table = parser_response_arrow_table(MODELICA_FILE_SUMMARY_ROUTE, [response])
    partitions = collect(Tables.partitions(summary_table))
    summary_columns = Tables.columntable(summary_table)
    summary_schema = Tables.schema(summary_table)
    roundtrip_table = WendaoCodeParser.WendaoArrow.Arrow.Table(
        WendaoCodeParser.WendaoArrow.Arrow.tobuffer(summary_table),
    )
    roundtrip_columns = Tables.columntable(roundtrip_table)
    roundtrip_schema = Tables.schema(roundtrip_table)

    @test !isempty(partitions)
    @test !isnothing(Tables.schema(first(partitions)))
    @test summary_schema.types[findfirst(==(:item_reexported), summary_schema.names)] ==
          Missing
    @test summary_schema.types[findfirst(==(:item_top_level), summary_schema.names)] ==
          Missing
    @test summary_schema.types[findfirst(==(:item_is_partial), summary_schema.names)] ==
          Missing
    @test summary_schema.types[findfirst(==(:item_is_final), summary_schema.names)] ==
          Missing
    @test summary_schema.types[findfirst(
        ==(:item_is_encapsulated),
        summary_schema.names,
    )] == Missing
    @test roundtrip_schema.types[findfirst(==(:item_reexported), roundtrip_schema.names)] ==
          Missing
    @test roundtrip_schema.types[findfirst(==(:item_top_level), roundtrip_schema.names)] ==
          Missing
    @test roundtrip_schema.types[findfirst(==(:item_is_partial), roundtrip_schema.names)] ==
          Missing
    @test roundtrip_schema.types[findfirst(==(:item_is_final), roundtrip_schema.names)] ==
          Missing
    @test roundtrip_schema.types[findfirst(
        ==(:item_is_encapsulated),
        roundtrip_schema.names,
    )] == Missing
    @test length(summary_columns.item_group) == 1025
    @test count(==("documentation"), summary_columns.item_group) == 1025
    @test all(ismissing, summary_columns.item_reexported)
    @test all(ismissing, summary_columns.item_top_level)
    @test all(ismissing, summary_columns.item_is_partial)
    @test all(ismissing, summary_columns.item_is_final)
    @test all(ismissing, summary_columns.item_is_encapsulated)
    @test length(roundtrip_columns.item_group) == 1025
    @test count(==("documentation"), roundtrip_columns.item_group) == 1025
end

@testset "Flight summary rows parse committed Modelica demo fixtures" begin
    fixture_cases = (
        (
            request_id = "req-flight-modelica-fixture-package",
            path = modelica_fixture_path("Modelica", "Blocks", "package.mo"),
            min_items = 500,
        ),
        (
            request_id = "req-flight-modelica-fixture-interfaces",
            path = modelica_fixture_path("Modelica", "Blocks", "Interfaces.mo"),
            min_items = 150,
        ),
        (
            request_id = "req-flight-modelica-fixture-types",
            path = modelica_fixture_path("Modelica", "Blocks", "Types.mo"),
            min_items = 20,
        ),
    )

    for fixture_case in fixture_cases
        @test isfile(fixture_case.path)
        response = parse_modelica_file_summary(
            ParserRequest(
                fixture_case.request_id,
                fixture_case.path,
                read(fixture_case.path, String),
            ),
        )
        @test response.success
        @test length(response.summary_items) > fixture_case.min_items

        summary_table = parser_response_arrow_table(MODELICA_FILE_SUMMARY_ROUTE, [response])
        summary_columns = Tables.columntable(summary_table)
        partitions = collect(Tables.partitions(summary_table))
        partition_row_counts =
            [length(Tables.columntable(partition).item_group) for partition in partitions]
        roundtrip_table = WendaoCodeParser.WendaoArrow.Arrow.Table(
            WendaoCodeParser.WendaoArrow.Arrow.tobuffer(summary_table),
        )
        roundtrip_columns = Tables.columntable(roundtrip_table)

        @test length(summary_columns.item_group) == length(response.summary_items)
        @test !isempty(partitions)
        @test all(
            <=(WendaoCodeParser.PARSER_RESPONSE_PARTITION_ROW_LIMIT),
            partition_row_counts,
        )
        @test sum(partition_row_counts) == length(response.summary_items)
        @test length(roundtrip_columns.item_group) == length(response.summary_items)
    end
end
