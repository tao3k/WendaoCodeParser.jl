module ServiceEntrypointHarness
include(joinpath(@__DIR__, "..", "..", "scripts", "run_service.jl"))
end

@testset "Service entrypoint uses package project" begin
    @test ServiceEntrypointHarness.activate_code_parser_project() ==
          ServiceEntrypointHarness.WENDAOCODEPARSER_ROOT
    @test isfile(Base.active_project())
    @test Base.active_project() !=
          joinpath(ServiceEntrypointHarness.WENDAOCODEPARSER_ROOT, "Project.toml")
end

@testset "Service entrypoint default config args" begin
    entry_args = ServiceEntrypointHarness.service_entry_args(String[])
    @test entry_args[1:2] == [
        "--config",
        ServiceEntrypointHarness.DEFAULT_CONFIG_PATH,
    ]
    @test "--code-parser-route-name" in entry_args ||
          "--code-parser-route-names" in entry_args
end
