mutable struct ModelicaCollectionState
    primary_class::Union{Nothing,String}
    restriction::Union{Nothing,String}
    imports::Vector{Dict{String,Any}}
    import_set::Set{Tuple{String,String}}
    extends::Vector{Dict{String,Any}}
    extend_set::Set{Tuple{String,String}}
    symbols::Vector{Dict{String,Any}}
    symbol_set::Set{Tuple{String,String,String}}
    documentation::Vector{String}
    equations::Vector{Dict{String,Any}}
    nodes::Vector{Dict{String,Any}}
end

function ModelicaCollectionState()
    return ModelicaCollectionState(
        nothing,
        nothing,
        Dict{String,Any}[],
        Set{Tuple{String,String}}(),
        Dict{String,Any}[],
        Set{Tuple{String,String}}(),
        Dict{String,Any}[],
        Set{Tuple{String,String,String}}(),
        String[],
        Dict{String,Any}[],
        Dict{String,Any}[],
    )
end

const _modelica_state_cache_hit_count = Ref(0)
const _modelica_state_cache_miss_count = Ref(0)
const _MODELICA_STATE_CACHE_LIMIT = 16
const _modelica_state_cache = Dict{Tuple{String,String},ModelicaCollectionState}()
const _modelica_state_cache_order = Tuple{String,String}[]

function collect_modelica_state(source_text::AbstractString, source_id::AbstractString)
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
        _collect_modelica_class!(state, class_, source_text; top_level = true)
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
    class_::Absyn.Class,
    source_text::AbstractString;
    top_level::Bool,
    visibility::String = "public",
    owner_name::Union{Nothing,String} = nothing,
    owner_path::Union{Nothing,String} = nothing,
)
    restriction = _modelica_restriction_name(class_.restriction)
    class_name = String(class_.name)
    class_path = isnothing(owner_path) ? class_name : "$(owner_path).$(class_name)"
    if top_level && isnothing(state.primary_class)
        state.primary_class = class_name
        state.restriction = restriction
    end
    class_metadata = Dict{String,Any}(
        "restriction" => restriction,
        "class_path" => class_path,
        "top_level" => top_level,
        "visibility" => visibility,
        "is_partial" => Bool(class_.partialPrefix),
        "is_final" => Bool(class_.finalPrefix),
        "is_encapsulated" => Bool(class_.encapsulatedPrefix),
    )
    isnothing(owner_name) || (class_metadata["owner_name"] = owner_name)
    isnothing(owner_path) || (class_metadata["owner_path"] = owner_path)
    _push_modelica_symbol!(
        state,
        class_name,
        restriction;
        text = "$(restriction) $(class_name)",
        line_start = _line_start(class_.info),
        line_end = _line_end(class_.info),
        metadata = class_metadata,
    )
    _collect_modelica_class_body!(state, class_name, class_path, class_.body, source_text)
    return nothing
end

function _collect_modelica_class_body!(
    state::ModelicaCollectionState,
    class_name::String,
    class_path::String,
    body::Absyn.ClassDef,
    source_text::AbstractString,
)
    if body isa Absyn.PARTS
        for class_part in body.classParts
            _collect_modelica_class_part!(
                state,
                class_name,
                class_path,
                class_part,
                source_text,
            )
        end
    elseif body isa Absyn.CLASS_EXTENDS
        _push_modelica_extend!(
            state,
            String(body.baseClassName);
            metadata = Dict{String,Any}(
                "owner_name" => class_name,
                "owner_path" => class_path,
                "class_path" => class_path,
            ),
        )
        for class_part in body.parts
            _collect_modelica_class_part!(
                state,
                class_name,
                class_path,
                class_part,
                source_text,
            )
        end
    end
    _maybe_push_modelica_documentation!(
        state,
        body;
        owner_name = class_name,
        owner_path = class_path,
        class_path = class_path,
    )
    return nothing
end

function _collect_modelica_class_part!(
    state::ModelicaCollectionState,
    class_name::String,
    class_path::String,
    class_part::Absyn.ClassPart,
    source_text::AbstractString,
)
    if class_part isa Absyn.PUBLIC || class_part isa Absyn.PROTECTED
        visibility = class_part isa Absyn.PROTECTED ? "protected" : "public"
        for element_item in class_part.contents
            _collect_modelica_element_item!(
                state,
                element_item,
                source_text;
                visibility = visibility,
                owner_name = class_name,
                owner_path = class_path,
            )
        end
    elseif class_part isa Absyn.EQUATIONS
        _collect_modelica_equations!(
            state,
            class_name,
            class_path,
            class_part.contents,
            source_text,
        )
    end
    return nothing
end

function _collect_modelica_element_item!(
    state::ModelicaCollectionState,
    element_item::Absyn.ElementItem,
    source_text::AbstractString;
    visibility::String,
    owner_name::String,
    owner_path::String,
)
    if element_item isa Absyn.ELEMENTITEM
        _collect_modelica_element!(
            state,
            element_item.element,
            source_text;
            visibility = visibility,
            owner_name = owner_name,
            owner_path = owner_path,
        )
    elseif element_item isa Absyn.LEXER_COMMENT
        _push_modelica_documentation!(
            state,
            String(element_item.comment);
            metadata = Dict{String,Any}(
                "owner_name" => owner_name,
                "owner_path" => owner_path,
                "class_path" => owner_path,
            ),
        )
    end
    return nothing
end

function _collect_modelica_element!(
    state::ModelicaCollectionState,
    element::Absyn.Element,
    source_text::AbstractString;
    visibility::String,
    owner_name::String,
    owner_path::String,
)
    element isa Absyn.ELEMENT || return nothing
    spec = element.specification
    if spec isa Absyn.COMPONENTS
        _collect_modelica_components!(
            state,
            spec,
            element.info;
            visibility = visibility,
            owner_name = owner_name,
            owner_path = owner_path,
        )
    elseif spec isa Absyn.CLASSDEF
        _collect_modelica_class!(
            state,
            spec.class_,
            source_text;
            top_level = false,
            visibility = visibility,
            owner_name = owner_name,
            owner_path = owner_path,
        )
    elseif spec isa Absyn.IMPORT
        _push_modelica_import!(
            state,
            _modelica_import_name(spec.import_);
            line_start = _line_start(spec.info),
            line_end = _line_end(spec.info),
            metadata = Dict{String,Any}(
                "owner_name" => owner_name,
                "owner_path" => owner_path,
                "class_path" => owner_path,
            ),
        )
    elseif spec isa Absyn.EXTENDS
        _push_modelica_extend!(
            state,
            _modelica_path_string(spec.path);
            line_start = _line_start(element.info),
            line_end = _line_end(element.info),
            metadata = Dict{String,Any}(
                "owner_name" => owner_name,
                "owner_path" => owner_path,
                "class_path" => owner_path,
            ),
        )
    end
    _maybe_push_modelica_comment!(
        state,
        spec;
        owner_name = owner_name,
        owner_path = owner_path,
        class_path = owner_path,
    )
    return nothing
end

function _collect_modelica_components!(
    state::ModelicaCollectionState,
    spec::Absyn.COMPONENTS,
    info,
    ;
    visibility::String,
    owner_name::String,
    owner_path::String,
)
    type_name = _modelica_type_spec_string(spec.typeSpec)
    variability = _modelica_variability_name(spec.attributes.variability)
    direction = _modelica_direction_name(spec.attributes.direction)
    for component_item in spec.components
        component = component_item.component
        component_name = String(component.name)
        component_kind = _modelica_component_kind(variability, direction)
        array_dimensions = _modelica_component_array_dimensions(component, spec)
        default_value = _modelica_component_default_value(component)
        start_value = _modelica_component_start_value(component)
        modifier_names = _modelica_component_modifier_names(component)
        unit = _modelica_component_unit(component)
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
                "type_name" => type_name,
                "variability" => variability,
                "direction" => direction,
                "component_kind" => component_kind,
                "array_dimensions" => array_dimensions,
                "default_value" => default_value,
                "start_value" => start_value,
                "modifier_names" => modifier_names,
                "unit" => unit,
                "visibility" => visibility,
                "owner_name" => owner_name,
                "owner_path" => owner_path,
                "class_path" => owner_path,
            ),
        )
        _maybe_push_modelica_comment!(
            state,
            component_item;
            owner_name = owner_name,
            owner_path = owner_path,
            class_path = owner_path,
        )
    end
    return nothing
end

function _collect_modelica_equations!(
    state::ModelicaCollectionState,
    owner_name::String,
    owner_path::String,
    contents,
    source_text::AbstractString,
)
    for equation_item in contents
        equation_item isa Absyn.EQUATIONITEM || continue
        line_start = _line_start(equation_item.info)
        line_end = _line_end(equation_item.info)
        equation_text =
            String(_modelica_source_span_text(source_text, line_start, line_end))
        isempty(equation_text) && continue
        equation_entry = Dict{String,Any}(
            "owner_name" => owner_name,
            "owner_path" => owner_path,
            "class_path" => owner_path,
            "text" => equation_text,
            "line_start" => line_start,
            "line_end" => line_end,
        )
        push!(state.equations, equation_entry)
        push!(
            state.nodes,
            _modelica_ast_node(
                "equation",
                owner_name;
                text = equation_text,
                line_start = line_start,
                line_end = line_end,
                metadata = Dict{String,Any}(
                    "owner_name" => owner_name,
                    "owner_path" => owner_path,
                    "class_path" => owner_path,
                ),
            ),
        )
    end
    return nothing
end

function _push_modelica_import!(
    state::ModelicaCollectionState,
    import_name::String;
    line_start::Union{Nothing,Int} = nothing,
    line_end::Union{Nothing,Int} = nothing,
    metadata = Dict{String,Any}(),
)
    import_metadata = Dict{String,Any}(metadata)
    owner_key =
        String(get(import_metadata, "owner_path", get(import_metadata, "owner_name", "")))
    import_key = (import_name, owner_key)
    import_key in state.import_set && return nothing
    push!(state.import_set, import_key)
    import_entry = Dict{String,Any}(
        "module" => import_name,
        "line_start" => line_start,
        "line_end" => line_end,
    )
    merge!(import_entry, import_metadata)
    push!(state.imports, import_entry)
    import_metadata["module"] = import_name
    push!(
        state.nodes,
        _modelica_ast_node(
            "import",
            import_name;
            text = import_name,
            line_start = line_start,
            line_end = line_end,
            metadata = import_metadata,
        ),
    )
    return nothing
end

function _push_modelica_extend!(
    state::ModelicaCollectionState,
    extend_name::String;
    line_start::Union{Nothing,Int} = nothing,
    line_end::Union{Nothing,Int} = nothing,
    metadata = Dict{String,Any}(),
)
    extend_metadata = Dict{String,Any}(metadata)
    owner_key =
        String(get(extend_metadata, "owner_path", get(extend_metadata, "owner_name", "")))
    extend_key = (extend_name, owner_key)
    extend_key in state.extend_set && return nothing
    push!(state.extend_set, extend_key)
    extend_entry = Dict{String,Any}(
        "path" => extend_name,
        "line_start" => line_start,
        "line_end" => line_end,
    )
    merge!(extend_entry, extend_metadata)
    push!(state.extends, extend_entry)
    extend_metadata["path"] = extend_name
    push!(
        state.nodes,
        _modelica_ast_node(
            "extends",
            extend_name;
            text = extend_name,
            line_start = line_start,
            line_end = line_end,
            metadata = extend_metadata,
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
    owner_key = get(metadata, "owner_path", get(metadata, "owner_name", ""))
    symbol_key = (symbol_name, node_kind, String(owner_key))
    symbol_key in state.symbol_set && return nothing
    push!(state.symbol_set, symbol_key)
    symbol_metadata = Dict{String,Any}(metadata)
    entry = Dict{String,Any}(
        "name" => symbol_name,
        "kind" => node_kind,
        "signature" => text,
        "line_start" => line_start,
        "line_end" => line_end,
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

function _push_modelica_documentation!(
    state::ModelicaCollectionState,
    value::String;
    metadata = Dict{String,Any}(),
)
    normalized_value = String(_normalize_modelica_documentation(value))
    isempty(normalized_value) && return nothing
    push!(state.documentation, normalized_value)
    node_metadata = Dict{String,Any}(metadata)
    node_metadata["content"] = normalized_value
    push!(
        state.nodes,
        _modelica_ast_node(
            "documentation",
            normalized_value;
            text = normalized_value,
            metadata = node_metadata,
        ),
    )
    return nothing
end

function _maybe_push_modelica_documentation!(
    state::ModelicaCollectionState,
    body::Absyn.ClassDef,
    ;
    owner_name::Union{Nothing,String} = nothing,
    owner_path::Union{Nothing,String} = nothing,
    class_path::Union{Nothing,String} = nothing,
)
    if hasproperty(body, :comment)
        metadata = Dict{String,Any}()
        isnothing(owner_name) || (metadata["owner_name"] = owner_name)
        isnothing(owner_path) || (metadata["owner_path"] = owner_path)
        isnothing(class_path) || (metadata["class_path"] = class_path)
        _push_modelica_documentation!(
            state,
            _modelica_option_string(getproperty(body, :comment));
            metadata = metadata,
        )
    end
    return nothing
end

function _maybe_push_modelica_comment!(
    state::ModelicaCollectionState,
    value;
    owner_name::Union{Nothing,String} = nothing,
    owner_path::Union{Nothing,String} = nothing,
    class_path::Union{Nothing,String} = nothing,
)
    hasproperty(value, :comment) || return nothing
    metadata = Dict{String,Any}()
    isnothing(owner_name) || (metadata["owner_name"] = owner_name)
    isnothing(owner_path) || (metadata["owner_path"] = owner_path)
    isnothing(class_path) || (metadata["class_path"] = class_path)
    _push_modelica_documentation!(
        state,
        _modelica_option_string(getproperty(value, :comment));
        metadata = metadata,
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

function _modelica_component_kind(variability::String, direction::String)
    direction == "input" && return "input_connector"
    direction == "output" && return "output_connector"
    variability == "parameter" && return "parameter"
    variability == "constant" && return "constant"
    return "variable"
end

function _modelica_component_default_value(component)
    classmod = _modelica_component_classmod(component)
    isnothing(classmod) && return nothing
    expression = _modelica_eqmod_expression(getproperty(classmod, :eqMod))
    isnothing(expression) && return nothing
    return _modelica_expression_string(expression)
end

function _modelica_component_start_value(component)
    modifier_entries = _modelica_component_modifier_entries(component)
    return _modelica_component_modifier_value(modifier_entries, "start")
end

function _modelica_component_modifier_names(component)
    modifier_entries = _modelica_component_modifier_entries(component)
    isempty(modifier_entries) && return nothing
    return join(first.(modifier_entries), ",")
end

function _modelica_component_unit(component)
    classmod = _modelica_component_classmod(component)
    isnothing(classmod) && return nothing
    modifier_entries =
        _modelica_component_modifier_entries(component; unquote_strings = true)
    return _modelica_component_modifier_value(modifier_entries, "unit")
end

function _modelica_component_classmod(component)
    hasproperty(component, :modification) || return nothing
    return _modelica_option_data(getproperty(component, :modification))
end

function _modelica_component_array_dimensions(component, spec)
    dimensions = String[]
    append!(
        dimensions,
        _modelica_array_dimension_entries(getproperty(component, :arrayDim)),
    )
    if hasproperty(spec, :attributes) && hasproperty(spec.attributes, :arrayDim)
        append!(
            dimensions,
            _modelica_array_dimension_entries(getproperty(spec.attributes, :arrayDim)),
        )
    end
    isempty(dimensions) && return nothing
    return "[" * join(dimensions, ", ") * "]"
end

function _modelica_array_dimension_entries(array_dim)
    entries = String[]
    for subscript in collect(array_dim)
        value = _modelica_subscript_string(subscript)
        isnothing(value) && continue
        push!(entries, value)
    end
    return entries
end

function _modelica_subscript_string(subscript)
    subscript isa Absyn.NOSUB && return ":"
    subscript isa Absyn.SUBSCRIPT || return nothing
    expression = getproperty(subscript, :subscript)
    isnothing(expression) && return nothing
    return _modelica_expression_string(expression; unquote_strings = true)
end

function _modelica_component_modifier_entries(component; unquote_strings::Bool = false)
    classmod = _modelica_component_classmod(component)
    isnothing(classmod) && return Pair{String,String}[]
    entries = Pair{String,String}[]
    for element_arg in collect(getproperty(classmod, :elementArgLst))
        element_arg isa Absyn.MODIFICATION || continue
        path_name = _modelica_path_string(getproperty(element_arg, :path))
        nested_classmod = _modelica_option_data(getproperty(element_arg, :modification))
        isnothing(nested_classmod) && continue
        expression = _modelica_eqmod_expression(getproperty(nested_classmod, :eqMod))
        isnothing(expression) && continue
        push!(
            entries,
            path_name =>
                _modelica_expression_string(expression; unquote_strings = unquote_strings),
        )
    end
    return entries
end

function _modelica_component_modifier_value(
    modifier_entries::Vector{Pair{String,String}},
    expected_key::String,
)
    for entry in modifier_entries
        first(entry) == expected_key && return last(entry)
    end
    return nothing
end

function _modelica_option_data(value)
    isnothing(value) && return nothing
    hasproperty(value, :data) || return nothing
    return getproperty(value, :data)
end

function _modelica_eqmod_expression(value)
    value isa Absyn.EQMOD || return nothing
    return getproperty(value, :exp)
end

function _modelica_expression_string(expression; unquote_strings::Bool = false)
    if expression isa Absyn.INTEGER || expression isa Absyn.REAL
        return string(getproperty(expression, :value))
    elseif expression isa Absyn.STRING
        value = String(getproperty(expression, :value))
        return unquote_strings ? value : "\"$(value)\""
    elseif expression isa Absyn.BOOL
        return Bool(getproperty(expression, :value)) ? "true" : "false"
    elseif expression isa Absyn.CREF
        return _modelica_component_ref_string(getproperty(expression, :componentRef))
    elseif expression isa Absyn.BINARY
        left = _modelica_expression_string(getproperty(expression, :exp1))
        right = _modelica_expression_string(getproperty(expression, :exp2))
        op = _modelica_operator_string(getproperty(expression, :op))
        return "$(left) $(op) $(right)"
    elseif expression isa Absyn.UNARY
        op = _modelica_operator_string(getproperty(expression, :op))
        inner = _modelica_expression_string(getproperty(expression, :exp))
        return "$(op)$(inner)"
    end
    return string(expression)
end

function _modelica_component_ref_string(component_ref)
    if component_ref isa Absyn.CREF_IDENT
        return String(getproperty(component_ref, :name))
    elseif component_ref isa Absyn.CREF_QUAL
        prefix = String(getproperty(component_ref, :name))
        suffix = _modelica_component_ref_string(getproperty(component_ref, :componentRef))
        return "$(prefix).$(suffix)"
    elseif component_ref isa Absyn.CREF_FULLYQUALIFIED
        return "." *
               _modelica_component_ref_string(getproperty(component_ref, :componentRef))
    end
    return string(component_ref)
end

function _modelica_operator_string(operator)
    operator isa Absyn.ADD && return "+"
    operator isa Absyn.SUB && return "-"
    operator isa Absyn.MUL && return "*"
    operator isa Absyn.DIV && return "/"
    operator isa Absyn.POW && return "^"
    operator isa Absyn.UMINUS && return "-"
    operator isa Absyn.UPLUS && return "+"
    return lowercase(String(nameof(typeof(operator))))
end

function _modelica_option_string(value)
    isnothing(value) && return ""
    hasproperty(value, :value) || return string(value)
    return _modelica_option_string(getproperty(value, :value))
end

function _normalize_modelica_documentation(value::AbstractString)
    text = replace(String(value), "\r\n" => "\n", "\r" => "\n")
    startswith(text, "/*") && (text = replace(text, r"^/\*" => ""))
    endswith(text, "*/") && (text = replace(text, r"\*/$" => ""))
    normalized_lines = String[]
    for line in split(text, '\n'; keepempty = true)
        stripped = lstrip(line)
        if startswith(stripped, "//")
            push!(normalized_lines, strip(stripped[3:end]))
        elseif startswith(stripped, "*")
            push!(normalized_lines, strip(stripped[2:end]))
        else
            push!(normalized_lines, rstrip(line))
        end
    end
    while !isempty(normalized_lines) && isempty(normalized_lines[1])
        popfirst!(normalized_lines)
    end
    while !isempty(normalized_lines) && isempty(normalized_lines[end])
        pop!(normalized_lines)
    end
    return strip(join(normalized_lines, "\n"))
end

function _modelica_source_span_text(
    source_text::AbstractString,
    line_start::Union{Nothing,Int},
    line_end::Union{Nothing,Int},
)
    isnothing(line_start) && return ""
    isnothing(line_end) && return ""
    lines = split(String(source_text), '\n'; keepempty = true)
    isempty(lines) && return ""
    first_line = clamp(Int(line_start), 1, length(lines))
    last_line = clamp(Int(line_end), first_line, length(lines))
    return strip(join(lines[first_line:last_line], "\n"))
end

_line_start(info) = isnothing(info) ? nothing : Int(getproperty(info, :lineNumberStart))
_line_end(info) = isnothing(info) ? nothing : Int(getproperty(info, :lineNumberEnd))

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
