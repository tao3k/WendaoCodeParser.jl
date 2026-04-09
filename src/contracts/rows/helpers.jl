function _parser_match_field(match::AbstractDict{String,Any}, key::AbstractString)
    value = get(match, String(key), nothing)
    !isnothing(value) && return value
    metadata = get(match, "metadata", nothing)
    metadata isa AbstractDict || return nothing
    return get(metadata, String(key), nothing)
end

function _parser_match_value(match::AbstractDict{String,Any}, key::AbstractString)
    value = _parser_match_field(match, key)
    return isnothing(value) ? missing : String(value)
end

function _parser_match_int(match::AbstractDict{String,Any}, key::AbstractString)
    value = _parser_match_field(match, key)
    return isnothing(value) ? missing : Int(value)
end

function _parser_match_bool(match::AbstractDict{String,Any}, key::AbstractString)
    value = _parser_match_field(match, key)
    return isnothing(value) ? missing : Bool(value)
end

function _parser_summary_scalar(
    summary_scalars::AbstractDict{String,Any},
    key::AbstractString,
)
    value = get(summary_scalars, String(key), nothing)
    return isnothing(value) ? missing : String(value)
end

function _parser_summary_item_text(item::AbstractDict{String,Any}, key::AbstractString)
    value = get(item, String(key), nothing)
    return isnothing(value) ? missing : String(value)
end

function _parser_summary_item_bool(item::AbstractDict{String,Any}, key::AbstractString)
    value = get(item, String(key), nothing)
    return isnothing(value) ? missing : Bool(value)
end

function _parser_summary_item_int(item::AbstractDict{String,Any}, key::AbstractString)
    value = get(item, String(key), nothing)
    return isnothing(value) ? missing : Int(value)
end

function _summary_kind_route_name(summary_kind::AbstractString)
    summary_kind == "julia_file_summary" && return JULIA_FILE_SUMMARY_ROUTE
    summary_kind == "julia_root_summary" && return JULIA_ROOT_SUMMARY_ROUTE
    summary_kind == "modelica_file_summary" && return MODELICA_FILE_SUMMARY_ROUTE
    summary_kind == "julia_ast_query" && return JULIA_AST_QUERY_ROUTE
    summary_kind == "modelica_ast_query" && return MODELICA_AST_QUERY_ROUTE
    error("unsupported WendaoCodeParser summary kind: $(String(summary_kind))")
end

_is_ast_query_route(route_name::Symbol) =
    route_name == JULIA_AST_QUERY_ROUTE || route_name == MODELICA_AST_QUERY_ROUTE
