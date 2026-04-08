struct ParserRequest
    request_id::String
    source_id::String
    source_text::String
    node_kind::Union{Nothing,String}
    name_equals::Union{Nothing,String}
    name_contains::Union{Nothing,String}
    text_contains::Union{Nothing,String}
    limit::Union{Nothing,Int}
    query_json::Union{Nothing,String}
end

function ParserRequest(
    request_id::AbstractString,
    source_id::AbstractString,
    source_text::AbstractString;
    node_kind = nothing,
    name_equals = nothing,
    name_contains = nothing,
    text_contains = nothing,
    limit = nothing,
    query_json = nothing,
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
        normalized_limit,
        isnothing(query_json) ? nothing : String(query_json),
    )
end

struct ParserResponse
    request_id::String
    source_id::String
    summary_kind::String
    backend::String
    success::Bool
    primary_name::Union{Nothing,String}
    payload_json::Union{Nothing,String}
    error_message::Union{Nothing,String}
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
    payload_json = nothing,
    error_message = nothing,
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
        isnothing(payload_json) ? nothing : String(payload_json),
        isnothing(error_message) ? nothing : String(error_message),
        normalized_match_count,
        normalized_matches,
    )
end
