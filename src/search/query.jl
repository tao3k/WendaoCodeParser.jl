function _parse_ast_query(request::ParserRequest)
    if _has_typed_ast_query(request)
        return AstQuery(
            node_kind = request.node_kind,
            name_equals = request.name_equals,
            name_contains = request.name_contains,
            text_contains = request.text_contains,
            limit = request.limit,
        )
    end
    isnothing(request.query_json) && error("AST query routes require typed query columns")
    parsed = JSON3.read(request.query_json)
    return AstQuery(
        node_kind = _json_property(parsed, :node_kind),
        name_equals = _json_property(parsed, :name_equals),
        name_contains = _json_property(parsed, :name_contains),
        text_contains = _json_property(parsed, :text_contains),
        limit = _json_property(parsed, :limit),
    )
end

function _has_typed_ast_query(request::ParserRequest)
    return !isnothing(request.node_kind) ||
           !isnothing(request.name_equals) ||
           !isnothing(request.name_contains) ||
           !isnothing(request.text_contains) ||
           !isnothing(request.limit)
end

function _json_property(object, field::Symbol)
    return hasproperty(object, field) ? getproperty(object, field) : nothing
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
