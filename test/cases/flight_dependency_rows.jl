@testset "Flight services expose shared dependency columns" begin
    julia_summary_service = build_parser_flight_service(JULIA_FILE_SUMMARY_ROUTE)
    julia_summary_request = parser_exchange_request(
        JULIA_FILE_SUMMARY_ROUTE,
        [ParserRequest(
                "req-flight-julia-deps",
                "Deps.jl",
                """
                module Demo
                import CSV: read as rd, write
                using DataFrames: DataFrame
                include("nested.jl")
                end
                """,
            )],
    )
    julia_summary_table = WendaoCodeParser.WendaoArrow.flight_exchange_table(
        julia_summary_service,
        WendaoCodeParser.WendaoArrow.Arrow.Flight.ServerCallContext(),
        julia_summary_request,
    )
    julia_summary_columns = Tables.columntable(julia_summary_table)
    @test hasproperty(julia_summary_columns, :item_dependency_kind)
    @test hasproperty(julia_summary_columns, :item_dependency_form)
    @test hasproperty(julia_summary_columns, :item_dependency_target)
    @test hasproperty(julia_summary_columns, :item_dependency_local_name)
    @test hasproperty(julia_summary_columns, :item_dependency_parent)
    @test hasproperty(julia_summary_columns, :item_dependency_member)
    @test hasproperty(julia_summary_columns, :item_dependency_alias)
    import_indices = findall(
        index -> julia_summary_columns.item_group[index] == "import",
        eachindex(julia_summary_columns.item_group),
    )
    alias_index = only(
        index for index in import_indices if
        isequal(julia_summary_columns.item_dependency_alias[index], "rd")
    )
    @test julia_summary_columns.item_dependency_form[alias_index] == "aliased_member"
    @test julia_summary_columns.item_dependency_target[alias_index] == "CSV.read"
    @test julia_summary_columns.item_dependency_local_name[alias_index] == "rd"
    @test julia_summary_columns.item_dependency_parent[alias_index] == "CSV"
    @test julia_summary_columns.item_dependency_member[alias_index] == "read"

    julia_query_service = build_parser_flight_service(JULIA_AST_QUERY_ROUTE)
    julia_query_request = parser_exchange_request(
        JULIA_AST_QUERY_ROUTE,
        [
            ParserRequest(
                "req-flight-julia-alias",
                "Deps.jl",
                """
                module Demo
                import CSV: read as rd, write
                end
                """;
                node_kind = "import",
                attribute_key = "dependency_alias",
                attribute_equals = "rd",
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
    @test hasproperty(julia_query_columns, :match_dependency_kind)
    @test hasproperty(julia_query_columns, :match_dependency_form)
    @test hasproperty(julia_query_columns, :match_dependency_target)
    @test hasproperty(julia_query_columns, :match_dependency_local_name)
    @test hasproperty(julia_query_columns, :match_dependency_parent)
    @test hasproperty(julia_query_columns, :match_dependency_member)
    @test hasproperty(julia_query_columns, :match_dependency_alias)
    @test julia_query_columns.match_dependency_kind == ["import"]
    @test julia_query_columns.match_dependency_form == ["aliased_member"]
    @test julia_query_columns.match_dependency_target == ["CSV.read"]
    @test julia_query_columns.match_dependency_local_name == ["rd"]
    @test julia_query_columns.match_dependency_parent == ["CSV"]
    @test julia_query_columns.match_dependency_member == ["read"]
    @test julia_query_columns.match_dependency_alias == ["rd"]

    modelica_summary_service = build_parser_flight_service(MODELICA_FILE_SUMMARY_ROUTE)
    modelica_summary_request = parser_exchange_request(
        MODELICA_FILE_SUMMARY_ROUTE,
        [
            ParserRequest(
                "req-flight-modelica-deps",
                "Deps.mo",
                """
                model Demo
                  import SI = Modelica.Units.SI;
                  extends Base;
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
    @test hasproperty(modelica_summary_columns, :item_dependency_kind)
    @test hasproperty(modelica_summary_columns, :item_dependency_form)
    @test hasproperty(modelica_summary_columns, :item_dependency_target)
    @test hasproperty(modelica_summary_columns, :item_dependency_local_name)
    @test hasproperty(modelica_summary_columns, :item_dependency_alias)
    import_index = only(
        index for index in eachindex(modelica_summary_columns.item_group) if
        modelica_summary_columns.item_group[index] == "import"
    )
    @test modelica_summary_columns.item_dependency_form[import_index] == "named_import"
    @test modelica_summary_columns.item_dependency_target[import_index] ==
          "Modelica.Units.SI"
    @test modelica_summary_columns.item_dependency_local_name[import_index] == "SI"
    @test modelica_summary_columns.item_dependency_alias[import_index] == "SI"
    extend_index = only(
        index for index in eachindex(modelica_summary_columns.item_group) if
        modelica_summary_columns.item_group[index] == "extend"
    )
    @test modelica_summary_columns.item_dependency_kind[extend_index] == "extends"
    @test modelica_summary_columns.item_dependency_form[extend_index] == "extends"
    @test modelica_summary_columns.item_dependency_target[extend_index] == "Base"
end
