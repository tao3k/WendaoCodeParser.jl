const _omparser_backend_library_path = Ref{Union{Nothing,String}}(nothing)
const _omparser_backend_library_handle = Ref{Union{Nothing,Ptr{Cvoid}}}(nothing)
const _omparser_backend_parse_symbol = Ref{Union{Nothing,Ptr{Cvoid}}}(nothing)
const _omparser_backend_error_message = Ref{Union{Nothing,String}}(nothing)
const _omparser_backend_build_attempted = Ref(false)
const _omparser_runtime_modules_loaded = Ref(false)
const _omparser_backend_prewarmed = Ref(false)
const _omparser_parse_call_count = Ref(0)

function ensure_omparser_backend!()
    return _ensure_omparser_library_path!()
end

function prewarm_modelica_backend!()
    _omparser_backend_prewarmed[] && return _ensure_omparser_library_path!()
    collect_modelica_state(
        """
        model WarmupCodeParser
        end WarmupCodeParser;
        """,
        "WarmupCodeParser.mo",
    )
    _omparser_backend_prewarmed[] = true
    return _ensure_omparser_library_path!()
end

function omparser_backend_available()
    try
        _ensure_omparser_library_path!()
        return true
    catch error
        _record_omparser_error!(error)
        return false
    end
end

function omparser_backend_unavailable_reason()
    try
        library_path = _ensure_omparser_library_path!()
        return "OMParser.jl backend available at $(library_path)"
    catch error
        _record_omparser_error!(error)
        error_message =
            something(_omparser_import_error_message(), sprint(showerror, error))
        return "OMParser.jl backend unavailable: $(error_message)"
    end
end

function _parse_modelica_program(source_text::AbstractString, source_id::AbstractString)
    _ensure_omparser_runtime_modules!()
    _maybe_omparser_module()
    symbol = _ensure_omparser_parse_symbol!()
    _omparser_parse_call_count[] += 1
    return ccall(
        symbol,
        Any,
        (String, String, Int64, Int64),
        String(source_text),
        String(source_id),
        Int64(1),
        Int64(9999),
    )
end

function _ensure_omparser_parse_symbol!()
    symbol = _omparser_backend_parse_symbol[]
    isnothing(symbol) || return symbol
    handle = _ensure_omparser_library_handle!()
    symbol = Libdl.dlsym(handle, :parseString)
    _omparser_backend_parse_symbol[] = symbol
    return symbol
end

function _ensure_omparser_runtime_modules!()
    _omparser_runtime_modules_loaded[] && return nothing
    omparser = _maybe_omparser_module()
    isnothing(omparser) &&
        error("OMParser.jl is not installed in the current project environment")
    _ensure_main_module_binding!(:Absyn, GlobalRef(@__MODULE__, :Absyn))
    _ensure_main_module_binding!(:ImmutableList, GlobalRef(omparser, :ImmutableList))
    _ensure_main_module_binding!(:MetaModelica, GlobalRef(omparser, :MetaModelica))
    _omparser_runtime_modules_loaded[] = true
    return nothing
end

function _ensure_main_module_binding!(name::Symbol, global_ref::GlobalRef)
    isdefined(Main, name) && return nothing
    Core.eval(Main, Expr(:(=), name, global_ref))
    return nothing
end

function _ensure_omparser_library_path!()
    cached_path = _omparser_backend_library_path[]
    if !isnothing(cached_path) && isfile(cached_path)
        return cached_path
    end
    root = _omparser_root()
    local library_path = _find_omparser_library(root)
    if isnothing(library_path)
        _download_omparser_release_if_possible!(root)
        library_path = _find_omparser_library(root)
    end
    if isnothing(library_path)
        _build_omparser_from_source!(root)
        library_path = _find_omparser_library(root)
    end
    isnothing(library_path) && error(
        "OMParser.jl source build completed, but no parser shared library was found under $(joinpath(root, "lib"))",
    )
    _omparser_backend_library_path[] = library_path
    _omparser_backend_library_handle[] = nothing
    _omparser_backend_error_message[] = nothing
    return library_path
end

function _ensure_omparser_library_handle!()
    library_path = _ensure_omparser_library_path!()
    handle = _omparser_backend_library_handle[]
    isnothing(handle) || return handle
    handle = Libdl.dlopen(library_path)
    _omparser_backend_library_handle[] = handle
    _omparser_backend_parse_symbol[] = nothing
    return handle
end

function _download_omparser_release_if_possible!(root::AbstractString)
    os_name = _omparser_release_os_name()
    isnothing(os_name) && return nothing
    ext_dir = joinpath(root, "lib", "ext")
    mkpath(ext_dir)
    julia_version = "$(VERSION.major).$(VERSION.minor)"
    release_tag = "Latest-$(os_name)-julia-$(julia_version)"
    archive_name = "parser-library-$(os_name)-julia-$(julia_version).zip"
    tarball_name = "$(os_name)-julia-$(julia_version)-library.tar.gz"
    archive_url = "https://github.com/OpenModelica/OMParser.jl/releases/download/$(release_tag)/$(archive_name)"
    shell = something(Sys.which("bash"), Sys.which("sh"))
    isnothing(shell) && return nothing
    shared_dir = joinpath(ext_dir, "shared")
    archive_path = joinpath(ext_dir, archive_name)
    tarball_path = joinpath(ext_dir, tarball_name)
    script = """
    set -euo pipefail
    cd '$(replace(ext_dir, "'" => "'\"'\"'"))'
    rm -rf '$(replace(shared_dir, "'" => "'\"'\"'"))'
    mkdir -p '$(replace(shared_dir, "'" => "'\"'\"'"))'
    curl -fsSL '$(archive_url)' -o '$(replace(archive_path, "'" => "'\"'\"'"))'
    unzip -o '$(replace(archive_path, "'" => "'\"'\"'"))' '$(tarball_name)'
    tar -xzf '$(replace(tarball_path, "'" => "'\"'\"'"))' -C '$(replace(shared_dir, "'" => "'\"'\"'"))'
    """
    @info "Attempting OMParser.jl release artifact download" archive_url
    try
        run(Cmd([shell, "-lc", script]))
    catch error
        @warn "OMParser.jl release artifact download failed; falling back to source build" error =
            sprint(showerror, error)
    end
    return nothing
end

function _build_omparser_from_source!(root::AbstractString)
    parser_dir = joinpath(root, "lib", "parser")
    isdir(parser_dir) ||
        error("OMParser.jl parser source directory is missing at $(parser_dir)")
    if _omparser_backend_build_attempted[] && !isnothing(_omparser_backend_error_message[])
        error(_omparser_backend_error_message[])
    end
    _omparser_backend_build_attempted[] = true
    build_dir = joinpath(root, "lib", "build")
    isdir(build_dir) && rm(build_dir; recursive = true, force = true)
    semver_script = joinpath(parser_dir, "common", "semver.sh")
    isfile(semver_script) && chmod(semver_script, 0o755)
    @info "OMParser.jl shared library missing; building from source" parser_dir
    shell = something(Sys.which("bash"), Sys.which("sh"))
    isnothing(shell) && error("OMParser.jl source build requires bash or sh on PATH")
    script = """
    set -euo pipefail
    cd '$(replace(parser_dir, "'" => "'\"'\"'"))'
    autoconf
    ./configure
    make
    """
    try
        run(Cmd([shell, "-lc", script]))
    catch error
        message = "official source build failed under $(parser_dir): $(sprint(showerror, error))"
        _omparser_backend_error_message[] = message
        rethrow(ErrorException(message))
    end
    @info "OMParser.jl source build finished" parser_dir
    return nothing
end

function _find_omparser_library(root::AbstractString)
    for search_root in
        (joinpath(root, "lib", "build", "lib"), joinpath(root, "lib", "ext", "shared"))
        isdir(search_root) || continue
        for (dirpath, _, files) in walkdir(search_root)
            for file in files
                file == _omparser_library_name() && return joinpath(dirpath, file)
            end
        end
    end
    return nothing
end

function _omparser_root()
    omparser = _maybe_omparser_module()
    if !isnothing(omparser)
        package_path = pathof(omparser)
        isnothing(package_path) || return normpath(joinpath(dirname(package_path), ".."))
    end
    package_path = Base.find_package("OMParser")
    isnothing(package_path) &&
        error("OMParser.jl is not installed in the current project environment")
    return normpath(joinpath(dirname(package_path), ".."))
end

_omparser_library_name() =
    Sys.iswindows() ? "libomparse-julia.dll" :
    Sys.islinux() ? "libomparse-julia.so" : "libomparse-julia.dylib"

function _omparser_release_os_name()
    Sys.isapple() && return "macos-latest"
    Sys.islinux() && return "ubuntu-latest"
    Sys.iswindows() && return "windows-latest"
    return nothing
end

function _record_omparser_error!(error)
    global _omparser_import_error = sprint(showerror, error)
    _omparser_backend_error_message[] = _omparser_import_error
    return nothing
end

function _maybe_omparser_module()
    isdefined(@__MODULE__, :OMParser) &&
        return Base.invokelatest(getfield, @__MODULE__, :OMParser)
    try
        @eval import OMParser
        return Base.invokelatest(getfield, @__MODULE__, :OMParser)
    catch error
        _record_omparser_error!(error)
        return nothing
    end
end

function _omparser_import_error_message()
    return @isdefined(_omparser_import_error) ? _omparser_import_error : nothing
end
