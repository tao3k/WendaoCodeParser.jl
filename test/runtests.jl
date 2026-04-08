using Test
using JSON3
using Tables
using WendaoCodeParser

const JULIA_SOURCE = """
module Demo
\"\"\"docstring for foo\"\"\"
foo(x)=x

struct Bar
    x::Int
end

include("nested.jl")
using DataFrames
export foo, Bar
end
"""

@testset "Package loads" begin
    @test WendaoCodeParser.WENDAOCODEPARSER_SCHEMA_VERSION == "v2"
end

@testset "Julia file summary extraction" begin
    response = parse_julia_file_summary(ParserRequest("req-1", "Demo.jl", JULIA_SOURCE))
    @test response.success
    @test response.primary_name == "Demo"
    payload = JSON3.read(response.payload_json)

    @test payload.module_name == "Demo"
    @test payload.exports == ["foo", "Bar"]
    @test payload.includes == ["nested.jl"]
    @test length(payload.imports) == 1
    @test payload.imports[1].module == "DataFrames"
    @test length(payload.symbols) == 2
    @test Set(String[symbol.name for symbol in payload.symbols]) == Set(["foo", "Bar"])
    @test length(payload.docstrings) == 1
    @test payload.docstrings[1].target_name == "foo"
end

@testset "Julia root summary requires module" begin
    response =
        parse_julia_root_summary(ParserRequest("req-2", "standalone.jl", "foo(x)=x\n"))
    @test !response.success
    @test occursin("root module", response.error_message)
end

@testset "Julia AST query search module" begin
    request = ParserRequest(
        "req-3",
        "Demo.jl",
        JULIA_SOURCE;
        node_kind = "function",
        name_contains = "fo",
        limit = 5,
    )
    response = search_julia_ast(request)
    @test response.success
    @test response.match_count == 1
    @test response.matches[1]["name"] == "foo"
    @test response.matches[1]["node_kind"] == "function"
end

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
    @test summary_columns.success == [true]
    summary_payload = JSON3.read(summary_columns.payload_json[1])
    @test summary_payload.module_name == "Demo"

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
end

@testset "Modelica summary extraction and backend build" begin
    WendaoCodeParser._reset_omparser_backend_state!()
    response = parse_modelica_file_summary(
        ParserRequest(
            "req-6",
            "Demo.mo",
            """
            model Demo
              import Modelica.Constants.pi;
              parameter Integer n = 1;
              Real x;
              function foo
              algorithm
              end foo;
            end Demo;
            """,
        ),
    )
    @test response.success
    @test response.primary_name == "Demo"
    payload = JSON3.read(response.payload_json)
    @test payload.class_name == "Demo"
    @test payload.restriction == "model"
    @test payload.imports == ["Modelica.Constants.pi"]
    @test Set(String[symbol.name for symbol in payload.symbols]) == Set(["Demo", "n", "x", "foo"])
    signatures =
        Dict(String(symbol.name) => String(symbol.signature) for symbol in payload.symbols)
    @test signatures["n"] == "parameter Integer n"
    @test signatures["x"] == "Real x"
    @test signatures["foo"] == "function foo"
    @test isfile(WendaoCodeParser.ensure_omparser_backend!())
    @test isdefined(Main, :Absyn)
    @test isdefined(Main, :ImmutableList)
    @test isdefined(Main, :MetaModelica)
end

@testset "Modelica AST query search module" begin
    request = ParserRequest(
        "req-7",
        "Demo.mo",
        """
        model Demo
          Real x;
          function foo
          algorithm
          end foo;
        end Demo;
        """;
        node_kind = "function",
        name_contains = "fo",
        limit = 5,
    )
    response = search_modelica_ast(request)
    @test response.success
    @test response.match_count == 1
    @test response.matches[1]["name"] == "foo"
    @test response.matches[1]["node_kind"] == "function"
end

@testset "Modelica AST query cache hits and invalidation" begin
    WendaoCodeParser._reset_omparser_backend_state!()
    warm_request = ParserRequest(
        "req-7-cache-1",
        "Demo.mo",
        """
        model Demo
          Real x;
          function foo
          algorithm
          end foo;
        end Demo;
        """;
        node_kind = "function",
        name_contains = "fo",
        limit = 5,
    )
    warm_response = search_modelica_ast(warm_request)
    @test warm_response.success
    warm_snapshot = WendaoCodeParser._modelica_backend_cache_snapshot()
    @test warm_snapshot.parse_calls == 1
    @test warm_snapshot.cache_hits == 0
    @test warm_snapshot.cache_misses == 1
    @test warm_snapshot.cache_size == 1

    hot_response = search_modelica_ast(warm_request)
    @test hot_response.success
    hot_snapshot = WendaoCodeParser._modelica_backend_cache_snapshot()
    @test hot_snapshot.parse_calls == 1
    @test hot_snapshot.cache_hits == 1
    @test hot_snapshot.cache_misses == 1
    @test hot_snapshot.cache_size == 1

    invalidated_request = ParserRequest(
        "req-7-cache-2",
        "Demo.mo",
        """
        model Demo
          Real x;
          function foo
          algorithm
          end foo;
          function bar
          algorithm
          end bar;
        end Demo;
        """;
        node_kind = "function",
        name_contains = "ba",
        limit = 5,
    )
    invalidated_response = search_modelica_ast(invalidated_request)
    @test invalidated_response.success
    invalidated_snapshot = WendaoCodeParser._modelica_backend_cache_snapshot()
    @test invalidated_snapshot.parse_calls == 2
    @test invalidated_snapshot.cache_hits == 1
    @test invalidated_snapshot.cache_misses == 2
    @test invalidated_snapshot.cache_size == 2
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
    @test summary_columns.success == [true]
    @test summary_columns.backend == ["OMParser.jl"]
    summary_payload = JSON3.read(summary_columns.payload_json[1])
    @test summary_payload.class_name == "Demo"
    @test Set(String[symbol.name for symbol in summary_payload.symbols]) == Set(["Demo", "x"])
end
