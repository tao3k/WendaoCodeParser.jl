function _parse_ast_query(request::ParserRequest)
    return AstQuery(
        node_kind = request.node_kind,
        name_equals = request.name_equals,
        name_contains = request.name_contains,
        text_contains = request.text_contains,
        limit = request.limit,
    )
end

function _filter_ast_nodes(nodes::Vector{Dict{String,Any}}, query::AstQuery)
    matches = Dict{String,Any}[]
    for node in nodes
        _node_matches_query(node, query) || continue
        push!(matches, node)
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
    return true
end

_contains_text(value, needle::AbstractString) =
    !isnothing(value) && occursin(lowercase(String(needle)), lowercase(String(value)))
