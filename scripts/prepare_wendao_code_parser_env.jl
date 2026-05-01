import Downloads
import Pkg
using TOML

const SCRIPT_ROOT = @__DIR__
const WENDAO_ROOT = normpath(joinpath(SCRIPT_ROOT, ".."))
const PROJECT_TOML = joinpath(WENDAO_ROOT, "Project.toml")
const TEST_ENV = "WENDAO_CODE_PARSER_TEST_ENV"
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

function remote_source_spec(name::String, entry::Dict{String,Any}; root::AbstractString = WENDAO_ROOT)
    kwargs = Dict{Symbol,Any}(:name => name)
    haskey(entry, "url") && (kwargs[:url] = entry["url"])
    haskey(entry, "rev") && (kwargs[:rev] = entry["rev"])
    haskey(entry, "subdir") && (kwargs[:subdir] = entry["subdir"])
    haskey(entry, "path") && (kwargs[:path] = abspath(joinpath(root, entry["path"])))
    return Pkg.PackageSpec(; kwargs...)
end

function push_remote_source_spec!(
    specs::Vector{Pkg.PackageSpec},
    seen_sources::Set{String},
    name::String,
    entry,
    ;
    root::AbstractString = WENDAO_ROOT,
)
    entry isa Dict{String,Any} || return
    name in seen_sources && return
    push!(specs, remote_source_spec(name, entry; root = root))
    push!(seen_sources, name)
    return
end

function github_project_toml_url(entry::Dict{String,Any})
    url = get(entry, "url", nothing)
    rev = get(entry, "rev", nothing)
    url isa AbstractString || return nothing
    rev isa AbstractString || return nothing

    match_result = match(r"^https://github\.com/([^/]+)/([^/]+?)(?:\.git)?/?$", url)
    isnothing(match_result) && return nothing

    owner, repo = match_result.captures
    subdir = get(entry, "subdir", "")
    project_path = isempty(subdir) ? "Project.toml" : "$(subdir)/Project.toml"
    return "https://raw.githubusercontent.com/$(owner)/$(repo)/$(rev)/$(project_path)"
end

function source_project_from_entry(
    name::String,
    entry::Dict{String,Any};
    root::AbstractString = WENDAO_ROOT,
)
    if haskey(entry, "path")
        return TOML.parsefile(joinpath(root, entry["path"], "Project.toml"))
    end

    project_url = github_project_toml_url(entry)
    isnothing(project_url) && return nothing

    project_toml = Downloads.download(project_url)
    try
        return TOML.parsefile(project_toml)
    catch err
        error("Could not read source Project.toml for $(name) from $(project_url): $(err)")
    finally
        rm(project_toml; force = true)
    end
end

function push_dependency_source_specs!(
    specs::Vector{Pkg.PackageSpec},
    seen_sources::Set{String},
    source_project::Union{Nothing,Dict{String,Any}},
    ;
    root::AbstractString = WENDAO_ROOT,
)
    isnothing(source_project) && return

    dependencies = get(source_project, "deps", Dict{String,Any}())
    dependency_sources = get(source_project, "sources", Dict{String,Any}())

    for name in sort(collect(keys(dependencies)))
        entry = get(dependency_sources, name, nothing)
        push_remote_source_spec!(specs, seen_sources, name, entry; root = root)
    end
    return nothing
end

project = TOML.parsefile(PROJECT_TOML)
sources = get(project, "sources", Dict{String,Any}())

env_path = get(ENV, TEST_ENV, mktempdir())
Pkg.activate(env_path)

arrow_checkout = maybe_local_checkout(candidate_arrow_checkouts(), valid_arrow_checkout)
wendaoarrow_checkout =
    maybe_local_checkout(candidate_wendaoarrow_checkouts(), valid_wendaoarrow_checkout)

add_specs = Pkg.PackageSpec[]
develop_specs = Pkg.PackageSpec[]
seen_sources = Set{String}()

if isnothing(arrow_checkout)
    push_remote_source_spec!(add_specs, seen_sources, "Arrow", sources["Arrow"])
    push_remote_source_spec!(add_specs, seen_sources, "ArrowTypes", sources["ArrowTypes"])
else
    push!(develop_specs, Pkg.PackageSpec(path = arrow_checkout))
    push!(develop_specs, Pkg.PackageSpec(path = joinpath(arrow_checkout, "src", "ArrowTypes")))
    push!(seen_sources, "Arrow")
    push!(seen_sources, "ArrowTypes")
end

wendaoarrow_project = nothing
wendaoarrow_project_root = WENDAO_ROOT
if isnothing(wendaoarrow_checkout)
    wendaoarrow_source = sources["WendaoArrow"]
    push_remote_source_spec!(add_specs, seen_sources, "WendaoArrow", wendaoarrow_source)
    wendaoarrow_project = source_project_from_entry("WendaoArrow", wendaoarrow_source)
else
    push!(develop_specs, Pkg.PackageSpec(path = wendaoarrow_checkout))
    push!(seen_sources, "WendaoArrow")
    wendaoarrow_project = TOML.parsefile(joinpath(wendaoarrow_checkout, "Project.toml"))
    wendaoarrow_project_root = wendaoarrow_checkout
end

push_dependency_source_specs!(
    add_specs,
    seen_sources,
    wendaoarrow_project;
    root = wendaoarrow_project_root,
)

for (name, entry) in sources
    entry isa Dict{String,Any} || continue
    name in ("Arrow", "ArrowTypes", "WendaoArrow") && continue
    push_remote_source_spec!(add_specs, seen_sources, name, entry)
end

isempty(add_specs) || Pkg.add(add_specs; preserve = Pkg.PRESERVE_DIRECT)
isempty(develop_specs) || Pkg.develop(develop_specs; preserve = Pkg.PRESERVE_DIRECT)
Pkg.develop([Pkg.PackageSpec(path = WENDAO_ROOT)]; preserve = Pkg.PRESERVE_DIRECT)
Pkg.add([Pkg.PackageSpec(name = "Tables")]; preserve = Pkg.PRESERVE_DIRECT)

Pkg.resolve()
Pkg.instantiate()
Pkg.build("WendaoCodeParser")
