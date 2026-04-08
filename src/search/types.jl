struct AstQuery
    node_kind::Union{Nothing,String}
    name_equals::Union{Nothing,String}
    name_contains::Union{Nothing,String}
    text_contains::Union{Nothing,String}
    limit::Union{Nothing,Int}
end

function AstQuery(;
    node_kind = nothing,
    name_equals = nothing,
    name_contains = nothing,
    text_contains = nothing,
    limit = nothing,
)
    normalized_limit = isnothing(limit) ? nothing : Int(limit)
    !isnothing(normalized_limit) &&
        normalized_limit < 0 &&
        error("AstQuery limit must be nonnegative")
    return AstQuery(
        isnothing(node_kind) ? nothing : String(node_kind),
        isnothing(name_equals) ? nothing : String(name_equals),
        isnothing(name_contains) ? nothing : String(name_contains),
        isnothing(text_contains) ? nothing : String(text_contains),
        normalized_limit,
    )
end
