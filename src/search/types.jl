struct AstQuery
    node_kind::Union{Nothing,String}
    name_equals::Union{Nothing,String}
    name_contains::Union{Nothing,String}
    text_contains::Union{Nothing,String}
    signature_contains::Union{Nothing,String}
    attribute_key::Union{Nothing,String}
    attribute_equals::Union{Nothing,String}
    attribute_contains::Union{Nothing,String}
    limit::Union{Nothing,Int}
end

function AstQuery(;
    node_kind = nothing,
    name_equals = nothing,
    name_contains = nothing,
    text_contains = nothing,
    signature_contains = nothing,
    attribute_key = nothing,
    attribute_equals = nothing,
    attribute_contains = nothing,
    limit = nothing,
)
    normalized_limit = isnothing(limit) ? nothing : Int(limit)
    normalized_attribute_key = isnothing(attribute_key) ? nothing : String(attribute_key)
    normalized_attribute_equals =
        isnothing(attribute_equals) ? nothing : String(attribute_equals)
    normalized_attribute_contains =
        isnothing(attribute_contains) ? nothing : String(attribute_contains)
    !isnothing(normalized_limit) &&
        normalized_limit < 0 &&
        error("AstQuery limit must be nonnegative")
    isnothing(normalized_attribute_key) &&
        (
            !isnothing(normalized_attribute_equals) ||
            !isnothing(normalized_attribute_contains)
        ) &&
        error("AstQuery attribute filters require attribute_key")
    return AstQuery(
        isnothing(node_kind) ? nothing : String(node_kind),
        isnothing(name_equals) ? nothing : String(name_equals),
        isnothing(name_contains) ? nothing : String(name_contains),
        isnothing(text_contains) ? nothing : String(text_contains),
        isnothing(signature_contains) ? nothing : String(signature_contains),
        normalized_attribute_key,
        normalized_attribute_equals,
        normalized_attribute_contains,
        normalized_limit,
    )
end
