const _AST_QUERY_IDENTIFIER_LIST_KEYS = Set((
    "function_positional_params",
    "function_keyword_params",
    "function_defaulted_params",
    "function_typed_params",
    "modifier_names",
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
    return _contains_text(value, needle)
end

function _project_attribute_value(key::AbstractString, value, query::AstQuery)
    list_values = _query_attribute_identifier_list_values(key, value)
    if !isnothing(list_values)
        matched_value = _matched_identifier_list_value(list_values, query)
        !isnothing(matched_value) && return matched_value
    end
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
