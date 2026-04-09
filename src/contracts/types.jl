struct ParserRequest
    request_id::String
    source_id::String
    source_text::String
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

function ParserRequest(
    request_id::AbstractString,
    source_id::AbstractString,
    source_text::AbstractString;
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
    return ParserRequest(
        String(request_id),
        String(source_id),
        String(source_text),
        isnothing(node_kind) ? nothing : String(node_kind),
        isnothing(name_equals) ? nothing : String(name_equals),
        isnothing(name_contains) ? nothing : String(name_contains),
        isnothing(text_contains) ? nothing : String(text_contains),
        isnothing(signature_contains) ? nothing : String(signature_contains),
        isnothing(attribute_key) ? nothing : String(attribute_key),
        isnothing(attribute_equals) ? nothing : String(attribute_equals),
        isnothing(attribute_contains) ? nothing : String(attribute_contains),
        normalized_limit,
    )
end

struct ParserResponse
    request_id::String
    source_id::String
    summary_kind::String
    backend::String
    success::Bool
    primary_name::Union{Nothing,String}
    error_message::Union{Nothing,String}
    summary_scalars::Dict{String,Any}
    summary_items::Vector{Dict{String,Any}}
    match_count::Union{Nothing,Int}
    matches::Vector{Dict{String,Any}}
end

function ParserResponse(
    request_id::AbstractString,
    source_id::AbstractString,
    summary_kind::AbstractString,
    backend::AbstractString;
    success::Bool,
    primary_name = nothing,
    error_message = nothing,
    summary_scalars = Dict{String,Any}(),
    summary_items = Dict{String,Any}[],
    match_count = nothing,
    matches = Dict{String,Any}[],
)
    normalized_matches = Dict{String,Any}[Dict{String,Any}(match) for match in matches]
    normalized_match_count = isnothing(match_count) ? nothing : Int(match_count)
    return ParserResponse(
        String(request_id),
        String(source_id),
        String(summary_kind),
        String(backend),
        success,
        isnothing(primary_name) ? nothing : String(primary_name),
        isnothing(error_message) ? nothing : String(error_message),
        _parser_normalize_dict(summary_scalars),
        _parser_normalize_items(summary_items),
        normalized_match_count,
        normalized_matches,
    )
end

function _parser_normalize_dict(values)
    normalized = Dict{String,Any}()
    for (key, value) in pairs(values)
        normalized[String(key)] = value
    end
    return normalized
end

function _parser_normalize_items(items)
    return Dict{String,Any}[_parser_normalize_dict(item) for item in items]
end
