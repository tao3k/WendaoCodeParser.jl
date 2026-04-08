mutable struct ModelicaCollectionState
    primary_class::Union{Nothing,String}
    restriction::Union{Nothing,String}
    imports::Vector{String}
    import_set::Set{String}
    extends::Vector{String}
    extend_set::Set{String}
    symbols::Vector{Dict{String,Any}}
    symbol_set::Set{Tuple{String,String}}
    documentation::Vector{String}
    nodes::Vector{Dict{String,Any}}
end

function ModelicaCollectionState()
    return ModelicaCollectionState(
        nothing,
        nothing,
        String[],
        Set{String}(),
        String[],
        Set{String}(),
        Dict{String,Any}[],
        Set{Tuple{String,String}}(),
        String[],
        Dict{String,Any}[],
    )
end

const _omparser_backend_library_path = Ref{Union{Nothing,String}}(nothing)
const _omparser_backend_library_handle = Ref{Union{Nothing,Ptr{Cvoid}}}(nothing)
const _omparser_backend_parse_symbol = Ref{Union{Nothing,Ptr{Cvoid}}}(nothing)
const _omparser_backend_error_message = Ref{Union{Nothing,String}}(nothing)
const _omparser_backend_build_attempted = Ref(false)
const _omparser_runtime_modules_loaded = Ref(false)
const _omparser_backend_prewarmed = Ref(false)
const _omparser_parse_call_count = Ref(0)
const _modelica_state_cache_hit_count = Ref(0)
const _modelica_state_cache_miss_count = Ref(0)
const _MODELICA_STATE_CACHE_LIMIT = 16
const _modelica_state_cache = Dict{Tuple{String,String},ModelicaCollectionState}()
const _modelica_state_cache_order = Tuple{String,String}[]

function ensure_omparser_backend!()
    return _ensure_omparser_library_path!()
end

function prewarm_modelica_backend!()
    _omparser_backend_prewarmed[] && return _ensure_omparser_library_path!()
    _collect_modelica_state(
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

function _collect_modelica_state(source_text::AbstractString, source_id::AbstractString)
    cache_key = _modelica_state_cache_key(source_text, source_id)
    cached_state = get(_modelica_state_cache, cache_key, nothing)
    if !isnothing(cached_state)
        _modelica_state_cache_hit_count[] += 1
        _touch_modelica_state_cache_key!(cache_key)
        return cached_state
    end
    _modelica_state_cache_miss_count[] += 1
    program = _parse_modelica_program(source_text, source_id)
    state = ModelicaCollectionState()
    for class_ in program.classes
        _collect_modelica_class!(state, class_; top_level = true)
    end
    isnothing(state.primary_class) &&
        error("Modelica file summary requires at least one top-level class declaration")
    _store_modelica_state_cache!(cache_key, state)
    return state
end

function _modelica_state_cache_key(source_text::AbstractString, source_id::AbstractString)
    return (String(source_id), String(source_text))
end

function _touch_modelica_state_cache_key!(cache_key::Tuple{String,String})
    existing_index = findfirst(==(cache_key), _modelica_state_cache_order)
    isnothing(existing_index) || deleteat!(_modelica_state_cache_order, existing_index)
    push!(_modelica_state_cache_order, cache_key)
    return nothing
end

function _store_modelica_state_cache!(
    cache_key::Tuple{String,String},
    state::ModelicaCollectionState,
)
    _modelica_state_cache[cache_key] = state
    _touch_modelica_state_cache_key!(cache_key)
    while length(_modelica_state_cache_order) > _MODELICA_STATE_CACHE_LIMIT
        evicted_key = popfirst!(_modelica_state_cache_order)
        delete!(_modelica_state_cache, evicted_key)
    end
    return state
end

function _collect_modelica_class!(
    state::ModelicaCollectionState,
    class_::Absyn.Class;
    top_level::Bool,
)
    restriction = _modelica_restriction_name(class_.restriction)
    class_name = String(class_.name)
    if top_level && isnothing(state.primary_class)
        state.primary_class = class_name
        state.restriction = restriction
    end
    _push_modelica_symbol!(
        state,
        class_name,
        restriction;
        text = "$(restriction) $(class_name)",
        line_start = _line_start(class_.info),
        line_end = _line_end(class_.info),
        metadata = Dict("restriction" => restriction, "top_level" => top_level),
    )
    _collect_modelica_class_body!(state, class_.body)
    return nothing
end

function _collect_modelica_class_body!(state::ModelicaCollectionState, body::Absyn.ClassDef)
    if body isa Absyn.PARTS
        for class_part in body.classParts
            _collect_modelica_class_part!(state, class_part)
        end
    elseif body isa Absyn.CLASS_EXTENDS
        _push_modelica_extend!(state, String(body.baseClassName))
        for class_part in body.parts
            _collect_modelica_class_part!(state, class_part)
        end
    end
    _maybe_push_modelica_documentation!(state, body)
    return nothing
end

function _collect_modelica_class_part!(
    state::ModelicaCollectionState,
    class_part::Absyn.ClassPart,
)
    if class_part isa Absyn.PUBLIC || class_part isa Absyn.PROTECTED
        for element_item in class_part.contents
            _collect_modelica_element_item!(state, element_item)
        end
    end
    return nothing
end

function _collect_modelica_element_item!(
    state::ModelicaCollectionState,
    element_item::Absyn.ElementItem,
)
    if element_item isa Absyn.ELEMENTITEM
        _collect_modelica_element!(state, element_item.element)
    elseif element_item isa Absyn.LEXER_COMMENT
        _push_modelica_documentation!(state, String(element_item.comment))
    end
    return nothing
end

function _collect_modelica_element!(state::ModelicaCollectionState, element::Absyn.Element)
    element isa Absyn.ELEMENT || return nothing
    spec = element.specification
    if spec isa Absyn.COMPONENTS
        _collect_modelica_components!(state, spec, element.info)
    elseif spec isa Absyn.CLASSDEF
        _collect_modelica_class!(state, spec.class_; top_level = false)
    elseif spec isa Absyn.IMPORT
        _push_modelica_import!(
            state,
            _modelica_import_name(spec.import_);
            line_start = _line_start(spec.info),
            line_end = _line_end(spec.info),
        )
    elseif spec isa Absyn.EXTENDS
        _push_modelica_extend!(
            state,
            _modelica_path_string(spec.path);
            line_start = _line_start(element.info),
            line_end = _line_end(element.info),
        )
    end
    _maybe_push_modelica_comment!(state, spec)
    return nothing
end

function _collect_modelica_components!(
    state::ModelicaCollectionState,
    spec::Absyn.COMPONENTS,
    info,
)
    type_name = _modelica_type_spec_string(spec.typeSpec)
    variability = _modelica_variability_name(spec.attributes.variability)
    direction = _modelica_direction_name(spec.attributes.direction)
    for component_item in spec.components
        component = component_item.component
        component_name = String(component.name)
        signature =
            _modelica_component_signature(type_name, component_name, variability, direction)
        _push_modelica_symbol!(
            state,
            component_name,
            "component";
            text = signature,
            line_start = _line_start(info),
            line_end = _line_end(info),
            metadata = Dict(
                "type" => type_name,
                "variability" => variability,
                "direction" => direction,
            ),
        )
        _maybe_push_modelica_comment!(state, component_item)
    end
    return nothing
end

function _push_modelica_import!(
    state::ModelicaCollectionState,
    import_name::String;
    line_start::Union{Nothing,Int} = nothing,
    line_end::Union{Nothing,Int} = nothing,
)
    import_name in state.import_set && return nothing
    push!(state.import_set, import_name)
    push!(state.imports, import_name)
    push!(
        state.nodes,
        _modelica_ast_node(
            "import",
            import_name;
            text = import_name,
            line_start = line_start,
            line_end = line_end,
            metadata = Dict("module" => import_name),
        ),
    )
    return nothing
end

function _push_modelica_extend!(
    state::ModelicaCollectionState,
    extend_name::String;
    line_start::Union{Nothing,Int} = nothing,
    line_end::Union{Nothing,Int} = nothing,
)
    extend_name in state.extend_set && return nothing
    push!(state.extend_set, extend_name)
    push!(state.extends, extend_name)
    push!(
        state.nodes,
        _modelica_ast_node(
            "extends",
            extend_name;
            text = extend_name,
            line_start = line_start,
            line_end = line_end,
            metadata = Dict("path" => extend_name),
        ),
    )
    return nothing
end

function _push_modelica_symbol!(
    state::ModelicaCollectionState,
    symbol_name::String,
    node_kind::String;
    text::Union{Nothing,String} = nothing,
    line_start::Union{Nothing,Int} = nothing,
    line_end::Union{Nothing,Int} = nothing,
    metadata = Dict{String,Any}(),
)
    symbol_key = (symbol_name, node_kind)
    symbol_key in state.symbol_set && return nothing
    push!(state.symbol_set, symbol_key)
    symbol_metadata = Dict{String,Any}(metadata)
    entry = Dict{String,Any}(
        "name" => symbol_name,
        "kind" => node_kind,
        "signature" => text,
        "metadata" => symbol_metadata,
    )
    push!(state.symbols, entry)
    push!(
        state.nodes,
        _modelica_ast_node(
            node_kind,
            symbol_name;
            text = text,
            line_start = line_start,
            line_end = line_end,
            metadata = symbol_metadata,
        ),
    )
    return nothing
end

function _push_modelica_documentation!(state::ModelicaCollectionState, value::String)
    isempty(strip(value)) && return nothing
    push!(state.documentation, value)
    return nothing
end

function _maybe_push_modelica_documentation!(
    state::ModelicaCollectionState,
    body::Absyn.ClassDef,
)
    if hasproperty(body, :comment)
        _push_modelica_documentation!(
            state,
            _modelica_option_string(getproperty(body, :comment)),
        )
    end
    return nothing
end

function _maybe_push_modelica_comment!(state::ModelicaCollectionState, value)
    hasproperty(value, :comment) || return nothing
    _push_modelica_documentation!(
        state,
        _modelica_option_string(getproperty(value, :comment)),
    )
    return nothing
end

function _modelica_ast_node(
    node_kind::String,
    name::String;
    text::Union{Nothing,String} = nothing,
    line_start::Union{Nothing,Int} = nothing,
    line_end::Union{Nothing,Int} = nothing,
    metadata = Dict{String,Any}(),
)
    return Dict{String,Any}(
        "node_kind" => node_kind,
        "name" => name,
        "text" => text,
        "line_start" => line_start,
        "line_end" => line_end,
        "signature" => text,
        "metadata" => Dict{String,Any}(metadata),
    )
end

function _parse_modelica_program(source_text::AbstractString, source_id::AbstractString)
    _ensure_omparser_runtime_modules!()
    _maybe_omparser_module() # ensure package side effects are loaded
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
    # OMParser's native bridge resolves these modules from Main during parser
    # initialization, so loading them only inside package modules is insufficient.
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

function _modelica_restriction_name(restriction)
    restriction isa Absyn.R_MODEL && return "model"
    restriction isa Absyn.R_FUNCTION && return "function"
    restriction isa Absyn.R_RECORD && return "record"
    restriction isa Absyn.R_PACKAGE && return "package"
    restriction isa Absyn.R_BLOCK && return "block"
    restriction isa Absyn.R_CONNECTOR && return "connector"
    restriction isa Absyn.R_EXP_CONNECTOR && return "expandable_connector"
    restriction isa Absyn.R_TYPE && return "type"
    restriction isa Absyn.R_ENUMERATION && return "enumeration"
    restriction isa Absyn.R_OPERATOR && return "operator"
    restriction isa Absyn.R_OPERATOR_RECORD && return "operator_record"
    restriction isa Absyn.R_UNIONTYPE && return "uniontype"
    restriction isa Absyn.R_METARECORD && return "metarecord"
    restriction isa Absyn.R_CLASS && return "class"
    return lowercase(String(nameof(typeof(restriction))))
end

function _modelica_variability_name(variability)
    variability isa Absyn.PARAM && return "parameter"
    variability isa Absyn.CONST && return "constant"
    variability isa Absyn.DISCRETE && return "discrete"
    return "variable"
end

function _modelica_direction_name(direction)
    direction isa Absyn.INPUT && return "input"
    direction isa Absyn.OUTPUT && return "output"
    direction isa Absyn.INPUT_OUTPUT && return "input_output"
    return "bidir"
end

function _modelica_import_name(import_)
    if import_ isa Absyn.NAMED_IMPORT
        return "$(String(import_.name))=$( _modelica_path_string(import_.path) )"
    elseif import_ isa Absyn.QUAL_IMPORT || import_ isa Absyn.UNQUAL_IMPORT
        return _modelica_path_string(import_.path)
    elseif import_ isa Absyn.GROUP_IMPORT
        return _modelica_path_string(import_.prefix)
    end
    return string(import_)
end

function _modelica_type_spec_string(type_spec::Absyn.TypeSpec)
    if type_spec isa Absyn.TPATH
        return _modelica_path_string(type_spec.path)
    elseif type_spec isa Absyn.TCOMPLEX
        nested = join(_modelica_type_spec_string.(collect(type_spec.typeSpecs)), ", ")
        return "$(_modelica_path_string(type_spec.path)){$(nested)}"
    end
    return string(type_spec)
end

function _modelica_path_string(path::Absyn.Path)
    if path isa Absyn.IDENT
        return String(path.name)
    elseif path isa Absyn.QUALIFIED
        return string(path.name, ".", _modelica_path_string(path.path))
    elseif path isa Absyn.FULLYQUALIFIED
        return "." * _modelica_path_string(path.path)
    end
    return string(path)
end

function _modelica_component_signature(
    type_name::String,
    component_name::String,
    variability::String,
    direction::String,
)
    prefixes = String[]
    variability == "variable" || push!(prefixes, variability)
    direction == "bidir" || push!(prefixes, direction)
    return isempty(prefixes) ? "$(type_name) $(component_name)" :
           "$(join(prefixes, " ")) $(type_name) $(component_name)"
end

function _modelica_option_string(value)
    isnothing(value) && return ""
    hasproperty(value, :value) || return string(value)
    return _modelica_option_string(getproperty(value, :value))
end

_line_start(info) = isnothing(info) ? nothing : Int(getproperty(info, :lineNumberStart))
_line_end(info) = isnothing(info) ? nothing : Int(getproperty(info, :lineNumberEnd))

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

function _reset_omparser_backend_state!()
    handle = _omparser_backend_library_handle[]
    isnothing(handle) || Libdl.dlclose(handle)
    _omparser_backend_library_path[] = nothing
    _omparser_backend_library_handle[] = nothing
    _omparser_backend_parse_symbol[] = nothing
    _omparser_backend_error_message[] = nothing
    _omparser_backend_build_attempted[] = false
    _omparser_runtime_modules_loaded[] = false
    _omparser_backend_prewarmed[] = false
    _omparser_parse_call_count[] = 0
    _modelica_state_cache_hit_count[] = 0
    _modelica_state_cache_miss_count[] = 0
    empty!(_modelica_state_cache)
    empty!(_modelica_state_cache_order)
    global _omparser_import_error = nothing
    return nothing
end

function _modelica_backend_cache_snapshot()
    return (
        parse_calls = _omparser_parse_call_count[],
        cache_hits = _modelica_state_cache_hit_count[],
        cache_misses = _modelica_state_cache_miss_count[],
        cache_size = length(_modelica_state_cache_order),
    )
end
