const _AST_QUERY_IDENTIFIER_LIST_KEYS = Set((
    "function_positional_params",
    "function_keyword_params",
    "function_defaulted_params",
    "function_typed_params",
    "modifier_names",
),)

const _AST_QUERY_BOOL_KEYS = Set((
    "reexported",
    "dependency_is_relative",
    "function_has_varargs",
    "parameter_is_typed",
    "parameter_is_defaulted",
    "parameter_is_vararg",
    "is_partial",
    "is_final",
    "is_encapsulated",
    "top_level",
),)

const _AST_QUERY_INT_KEYS = Set((
    "line_start",
    "line_end",
    "target_line_start",
    "target_line_end",
    "dependency_relative_level",
    "primitive_bits",
    "function_positional_arity",
    "function_keyword_arity",
),)

function _node_attribute_value(node::Dict{String,Any}, key::AbstractString)
    value = get(node, String(key), nothing)
    !isnothing(value) && return value
    metadata = get(node, "metadata", nothing)
    metadata isa AbstractDict || return nothing
    return get(metadata, String(key), nothing)
end

function _attribute_equals(key::AbstractString, value, needle::AbstractString)
    list_values = _query_attribute_identifier_list_values(key, value)
    if !isnothing(list_values)
        return any(==(String(needle)), list_values)
    end
    typed_value = _query_attribute_typed_value(key, value)
    if !isnothing(typed_value)
        typed_needle = _query_attribute_typed_needle(key, needle)
        return !isnothing(typed_needle) && typed_value == typed_needle
    end
    return String(value) == String(needle)
end

_contains_text(value, needle::AbstractString) =
    !isnothing(value) && occursin(lowercase(String(needle)), lowercase(String(value)))

function _contains_text(key::AbstractString, value, needle::AbstractString)
    list_values = _query_attribute_identifier_list_values(key, value)
    if !isnothing(list_values)
        needle_text = lowercase(String(needle))
        return any(value_text -> occursin(needle_text, lowercase(value_text)), list_values)
    end
    !isnothing(_query_attribute_typed_value(key, value)) && return false
    return _contains_text(value, needle)
end

function _project_attribute_value(key::AbstractString, value, query::AstQuery)
    list_values = _query_attribute_identifier_list_values(key, value)
    if !isnothing(list_values)
        matched_value = _matched_identifier_list_value(list_values, query)
        !isnothing(matched_value) && return matched_value
    end
    typed_value = _query_attribute_typed_value(key, value)
    !isnothing(typed_value) && return typed_value
    return value
end

function _query_attribute_identifier_list_values(key::AbstractString, value)
    String(key) in _AST_QUERY_IDENTIFIER_LIST_KEYS || return nothing
    value isa AbstractString || return nothing
    parts = String[]
    for raw_part in split(String(value), ',')
        part = strip(raw_part)
        isempty(part) || push!(parts, part)
    end
    return isempty(parts) ? nothing : parts
end

function _matched_identifier_list_value(list_values::Vector{String}, query::AstQuery)
    if !isnothing(query.attribute_equals)
        needle = String(query.attribute_equals)
        for value in list_values
            value == needle && return value
        end
    end
    if !isnothing(query.attribute_contains)
        needle = lowercase(String(query.attribute_contains))
        for value in list_values
            occursin(needle, lowercase(value)) && return value
        end
    end
    return nothing
end

function _query_attribute_typed_value(key::AbstractString, value)
    string_key = String(key)
    string_key in _AST_QUERY_BOOL_KEYS && return _query_bool_value(value)
    string_key in _AST_QUERY_INT_KEYS && return _query_int_value(value)
    return nothing
end

function _query_attribute_typed_needle(key::AbstractString, needle::AbstractString)
    string_key = String(key)
    string_key in _AST_QUERY_BOOL_KEYS && return _query_bool_value(needle)
    string_key in _AST_QUERY_INT_KEYS && return _query_int_value(needle)
    return nothing
end

function _query_bool_value(value)
    value isa Bool && return value
    value isa AbstractString || return nothing
    normalized = lowercase(strip(String(value)))
    normalized == "true" && return true
    normalized == "false" && return false
    normalized == "1" && return true
    normalized == "0" && return false
    return nothing
end

function _query_int_value(value)
    value isa Integer && return Int(value)
    value isa AbstractString || return nothing
    return tryparse(Int, strip(String(value)))
end
