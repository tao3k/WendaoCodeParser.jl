const _AST_MATCH_CORE_METADATA_KEYS = ("target_kind", "module", "path")

const _AST_MATCH_DEPENDENCY_METADATA_KEYS = (
    "dependency_kind",
    "dependency_form",
    "dependency_target",
    "dependency_is_relative",
    "dependency_relative_level",
    "dependency_local_name",
    "dependency_parent",
    "dependency_member",
    "dependency_alias",
)

const _AST_MATCH_SCOPE_METADATA_KEYS = (
    "module_kind",
    "owner_name",
    "owner_kind",
    "owner_path",
    "module_name",
    "module_path",
    "class_path",
    "target_path",
    "reexported",
    "visibility",
)

const _AST_MATCH_TYPE_METADATA_KEYS = (
    "type_name",
    "type_parameters",
    "type_supertype",
    "primitive_bits",
    "binding_kind",
    "type_kind",
)

const _AST_MATCH_MODELICA_SYMBOL_METADATA_KEYS = (
    "variability",
    "direction",
    "component_kind",
    "array_dimensions",
    "default_value",
    "start_value",
    "modifier_names",
    "unit",
    "is_partial",
    "is_final",
    "is_encapsulated",
)

const _AST_MATCH_FUNCTION_METADATA_KEYS = (
    "function_positional_arity",
    "function_keyword_arity",
    "function_has_varargs",
    "function_where_params",
    "function_return_type",
    "function_positional_params",
    "function_keyword_params",
    "function_defaulted_params",
    "function_typed_params",
    "function_positional_vararg_name",
    "function_keyword_vararg_name",
)

const _AST_MATCH_PARAMETER_METADATA_KEYS = (
    "parameter_kind",
    "parameter_type_name",
    "parameter_default_value",
    "parameter_is_typed",
    "parameter_is_defaulted",
    "parameter_is_vararg",
)

const _AST_MATCH_PROMOTED_METADATA_KEYS = (
    _AST_MATCH_CORE_METADATA_KEYS...,
    _AST_MATCH_DEPENDENCY_METADATA_KEYS...,
    _AST_MATCH_SCOPE_METADATA_KEYS...,
    _AST_MATCH_TYPE_METADATA_KEYS...,
    _AST_MATCH_MODELICA_SYMBOL_METADATA_KEYS...,
    _AST_MATCH_FUNCTION_METADATA_KEYS...,
    _AST_MATCH_PARAMETER_METADATA_KEYS...,
)

function _project_ast_match(node::Dict{String,Any}, query::AstQuery)
    match = Dict{String,Any}(node)
    _promote_ast_match_metadata!(match)
    if !isnothing(query.attribute_key)
        attribute_value = _node_attribute_value(node, query.attribute_key)
        match["attribute_key"] = query.attribute_key
        match["attribute_value"] =
            _project_attribute_value(query.attribute_key, attribute_value, query)
    end
    return match
end

function _promote_ast_match_metadata!(match::Dict{String,Any})
    metadata = get(match, "metadata", nothing)
    metadata isa AbstractDict || return match
    for key in _AST_MATCH_PROMOTED_METADATA_KEYS
        value = get(metadata, key, nothing)
        isnothing(value) && continue
        match[key] = value
    end
    return match
end
