import Pkg
using TOML

const SCRIPT_ROOT = @__DIR__
const WENDAO_ROOT = normpath(joinpath(SCRIPT_ROOT, ".."))
const PROJECT_TOML = joinpath(WENDAO_ROOT, "Project.toml")
const BOOTSTRAP_ENV = "WENDAO_CODE_PARSER_BOOTSTRAP_ENV"
const LOCAL_ARROW_ENV = "WENDAO_CODE_PARSER_LOCAL_ARROW_PATH"
const LOCAL_WENDAOARROW_ENV = "WENDAO_CODE_PARSER_LOCAL_WENDAO_ARROW_PATH"
const WENDAOARROW_REQUIRED_SOURCES = ("gRPCServer",)
const WENDAOARROW_SOURCE_FALLBACKS = Dict{String,Dict{String,Any}}(
    "gRPCServer" => Dict{String,Any}(
        "url" => "https://github.com/tao3k/gRPCServer.jl",
        "rev" => "261cd70ac0b76c060cef0507245c400da0b5def9",
    ),
)

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

function wendaoarrow_source_entry(
    name::String,
    sources::Dict{String,Any},
    wendaoarrow_checkout::Union{Nothing,String},
)
    entry = get(sources, name, nothing)
    entry isa Dict{String,Any} && return (; entry, root = WENDAO_ROOT)

    if !isnothing(wendaoarrow_checkout)
        wendaoarrow_project = TOML.parsefile(joinpath(wendaoarrow_checkout, "Project.toml"))
        wendaoarrow_sources = get(wendaoarrow_project, "sources", Dict{String,Any}())
        entry = get(wendaoarrow_sources, name, nothing)
        entry isa Dict{String,Any} && return (; entry, root = wendaoarrow_checkout)
    end

    entry = get(WENDAOARROW_SOURCE_FALLBACKS, name, nothing)
    entry isa Dict{String,Any} && return (; entry, root = WENDAO_ROOT)
    return nothing
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
seen_sources = Set{String}()

if isnothing(arrow_checkout)
    push_remote_source_spec!(add_specs, seen_sources, "Arrow", sources["Arrow"])
    push_remote_source_spec!(add_specs, seen_sources, "ArrowTypes", sources["ArrowTypes"])
else
    push!(develop_specs, Pkg.PackageSpec(path = arrow_checkout))
    push!(develop_specs, Pkg.PackageSpec(path = joinpath(arrow_checkout, "src", "ArrowTypes")))
end

if isnothing(wendaoarrow_checkout)
    push_remote_source_spec!(add_specs, seen_sources, "WendaoArrow", sources["WendaoArrow"])
else
    push!(develop_specs, Pkg.PackageSpec(path = wendaoarrow_checkout))
end

for name in WENDAOARROW_REQUIRED_SOURCES
    source = wendaoarrow_source_entry(name, sources, wendaoarrow_checkout)
    isnothing(source) && continue
    push_remote_source_spec!(
        add_specs,
        seen_sources,
        name,
        source.entry;
        root = source.root,
    )
end

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
