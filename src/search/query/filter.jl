function _filter_ast_nodes(nodes::Vector{Dict{String,Any}}, query::AstQuery)
    matches = Dict{String,Any}[]
    for node in nodes
        _node_matches_query(node, query) || continue
        push!(matches, _project_ast_match(node, query))
        !isnothing(query.limit) && length(matches) >= query.limit && break
    end
    return matches
end

function _node_matches_query(node::Dict{String,Any}, query::AstQuery)
    !isnothing(query.node_kind) &&
        get(node, "node_kind", nothing) != query.node_kind &&
        return false
    !isnothing(query.name_equals) &&
        get(node, "name", nothing) != query.name_equals &&
        return false
    !isnothing(query.name_contains) &&
        !_contains_text(get(node, "name", nothing), query.name_contains) &&
        return false
    !isnothing(query.text_contains) &&
        !_contains_text(get(node, "text", nothing), query.text_contains) &&
        return false
    !isnothing(query.signature_contains) &&
        !_contains_text(get(node, "signature", nothing), query.signature_contains) &&
        return false
    if !isnothing(query.attribute_key)
        attribute_value = _node_attribute_value(node, query.attribute_key)
        isnothing(attribute_value) && return false
        !isnothing(query.attribute_equals) &&
            !_attribute_equals(
                query.attribute_key,
                attribute_value,
                query.attribute_equals,
            ) &&
            return false
        !isnothing(query.attribute_contains) &&
            !_contains_text(
                query.attribute_key,
                attribute_value,
                query.attribute_contains,
            ) &&
            return false
    end
    return true
end
