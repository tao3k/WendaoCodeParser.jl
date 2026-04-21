import Pkg
using TOML

const SCRIPT_ROOT = @__DIR__
const WENDAO_ROOT = normpath(joinpath(SCRIPT_ROOT, ".."))
const PROJECT_TOML = joinpath(WENDAO_ROOT, "Project.toml")
const BOOTSTRAP_ENV = "WENDAO_CODE_PARSER_BOOTSTRAP_ENV"
const LOCAL_ARROW_ENV = "WENDAO_CODE_PARSER_LOCAL_ARROW_PATH"
const LOCAL_WENDAOARROW_ENV = "WENDAO_CODE_PARSER_LOCAL_WENDAO_ARROW_PATH"

function valid_arrow_checkout(path::AbstractString)
    return isfile(joinpath(path, "Project.toml")) &&
           isfile(joinpath(path, "src", "ArrowTypes", "Project.toml"))
end

function valid_wendaoarrow_checkout(path::AbstractString)
    return isfile(joinpath(path, "Project.toml")) &&
           isfile(joinpath(path, "src", "WendaoArrow.jl"))
end

function candidate_arrow_checkouts()
    candidates = String[]

    if haskey(ENV, LOCAL_ARROW_ENV)
        push!(candidates, abspath(ENV[LOCAL_ARROW_ENV]))
    end

    push!(candidates, normpath(joinpath(dirname(WENDAO_ROOT), "arrow-julia")))

    if haskey(ENV, "PRJ_ROOT")
        push!(candidates, normpath(joinpath(ENV["PRJ_ROOT"], ".data", "arrow-julia")))
    end

    return unique(candidates)
end

function candidate_wendaoarrow_checkouts()
    candidates = String[]

    if haskey(ENV, LOCAL_WENDAOARROW_ENV)
        push!(candidates, abspath(ENV[LOCAL_WENDAOARROW_ENV]))
    end

    push!(candidates, normpath(joinpath(dirname(WENDAO_ROOT), "WendaoArrow.jl")))

    if haskey(ENV, "PRJ_ROOT")
        push!(candidates, normpath(joinpath(ENV["PRJ_ROOT"], ".data", "WendaoArrow.jl")))
    end

    return unique(candidates)
end

function maybe_local_checkout(candidates::Vector{String}, validator::Function)
    for candidate in candidates
        validator(candidate) && return candidate
    end
    return nothing
end

function remote_source_spec(name::String, entry::Dict{String,Any})
    kwargs = Dict{Symbol,Any}(:name => name)
    haskey(entry, "url") && (kwargs[:url] = entry["url"])
    haskey(entry, "rev") && (kwargs[:rev] = entry["rev"])
    haskey(entry, "subdir") && (kwargs[:subdir] = entry["subdir"])
    haskey(entry, "path") && (kwargs[:path] = abspath(joinpath(WENDAO_ROOT, entry["path"])))
    return Pkg.PackageSpec(; kwargs...)
end

project = TOML.parsefile(PROJECT_TOML)
sources = get(project, "sources", Dict{String,Any}())

env_path = get(ENV, BOOTSTRAP_ENV, mktempdir())
Pkg.activate(env_path)

arrow_checkout = maybe_local_checkout(candidate_arrow_checkouts(), valid_arrow_checkout)
wendaoarrow_checkout =
    maybe_local_checkout(candidate_wendaoarrow_checkouts(), valid_wendaoarrow_checkout)

add_specs = Pkg.PackageSpec[]
develop_specs = Pkg.PackageSpec[]

if isnothing(arrow_checkout)
    push!(add_specs, remote_source_spec("Arrow", sources["Arrow"]))
    push!(add_specs, remote_source_spec("ArrowTypes", sources["ArrowTypes"]))
else
    push!(develop_specs, Pkg.PackageSpec(path = arrow_checkout))
    push!(develop_specs, Pkg.PackageSpec(path = joinpath(arrow_checkout, "src", "ArrowTypes")))
end

if isnothing(wendaoarrow_checkout)
    push!(add_specs, remote_source_spec("WendaoArrow", sources["WendaoArrow"]))
else
    push!(develop_specs, Pkg.PackageSpec(path = wendaoarrow_checkout))
end

for (name, entry) in sources
    entry isa Dict{String,Any} || continue
    name in ("Arrow", "ArrowTypes", "WendaoArrow") && continue
    push!(add_specs, remote_source_spec(name, entry))
end

isempty(add_specs) || Pkg.add(add_specs; preserve = Pkg.PRESERVE_DIRECT)
isempty(develop_specs) || Pkg.develop(develop_specs; preserve = Pkg.PRESERVE_DIRECT)
Pkg.develop([Pkg.PackageSpec(path = WENDAO_ROOT)]; preserve = Pkg.PRESERVE_DIRECT)
Pkg.add([Pkg.PackageSpec(name = "Tables")]; preserve = Pkg.PRESERVE_DIRECT)

Pkg.resolve()
Pkg.instantiate()
Pkg.build("WendaoCodeParser")
