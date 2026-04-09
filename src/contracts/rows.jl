function parser_request_row(request::ParserRequest)
    return (
        request_id = request.request_id,
        source_id = request.source_id,
        source_text = request.source_text,
    )
end

function parser_request_row(route_name::Symbol, request::ParserRequest)
    _is_ast_query_route(route_name) || return parser_request_row(request)
    return (
        request_id = request.request_id,
        source_id = request.source_id,
        source_text = request.source_text,
        node_kind = something(request.node_kind, missing),
        name_equals = something(request.name_equals, missing),
        name_contains = something(request.name_contains, missing),
        text_contains = something(request.text_contains, missing),
        limit = something(request.limit, missing),
    )
end

function parser_request_arrow_table(requests::AbstractVector{ParserRequest})
    rows = parser_request_row.(requests)
    return WendaoArrow.schema_table(
        Tables.rowtable(rows);
        schema_version = WENDAOCODEPARSER_SCHEMA_VERSION,
        metadata = Dict(
            "x-wendao-code-parser-payload-kind" => "request",
            "x-wendao-code-parser-contract-shape" => "source_text",
        ),
    )
end

function parser_request_arrow_table(
    route_name::Symbol,
    requests::AbstractVector{ParserRequest},
)
    rows = parser_request_row.(Ref(route_name), requests)
    contract_shape = _is_ast_query_route(route_name) ? "ast_query" : "source_text"
    return WendaoArrow.schema_table(
        Tables.rowtable(rows);
        schema_version = WENDAOCODEPARSER_SCHEMA_VERSION,
        metadata = Dict(
            "x-wendao-code-parser-payload-kind" => "request",
            "x-wendao-code-parser-contract-shape" => contract_shape,
        ),
    )
end

function parser_response_arrow_table(
    responses::AbstractVector{ParserResponse};
    metadata = nothing,
)
    isempty(responses) &&
        error("WendaoCodeParser response tables require at least one response")
    route_name = _summary_kind_route_name(first(responses).summary_kind)
    return parser_response_arrow_table(route_name, responses; metadata = metadata)
end

function parser_response_arrow_table(
    route_name::Symbol,
    responses::AbstractVector{ParserResponse};
    metadata = nothing,
)
    rows = if _is_ast_query_route(route_name)
        _parser_ast_response_rows(responses)
    else
        _parser_summary_response_rows(responses)
    end
    merged_metadata =
        isnothing(metadata) ? Dict{String,String}() : Dict{String,String}(metadata)
    merged_metadata["x-wendao-code-parser-payload-kind"] = "response"
    merged_metadata["x-wendao-code-parser-contract-shape"] =
        _is_ast_query_route(route_name) ? "ast_match_rows" : "summary_item_rows"
    return WendaoArrow.schema_table(
        Tables.rowtable(rows);
        schema_version = WENDAOCODEPARSER_SCHEMA_VERSION,
        metadata = merged_metadata,
    )
end

function _parser_ast_response_rows(responses::AbstractVector{ParserResponse})
    rows = NamedTuple[]
    for response in responses
        append!(rows, _parser_ast_response_rows(response))
    end
    return rows
end

function _parser_ast_response_rows(response::ParserResponse)
    base_row = (
        request_id = response.request_id,
        source_id = response.source_id,
        summary_kind = response.summary_kind,
        backend = response.backend,
        success = response.success,
        primary_name = something(response.primary_name, missing),
        match_count = something(response.match_count, 0),
        error_message = something(response.error_message, missing),
    )
    if !response.success || isempty(response.matches)
        return [
            merge(
                base_row,
                (
                    match_index = missing,
                    match_node_kind = missing,
                    match_name = missing,
                    match_text = missing,
                    match_signature = missing,
                    match_line_start = missing,
                    match_line_end = missing,
                    match_target_line_start = missing,
                    match_target_line_end = missing,
                ),
            ),
        ]
    end

    rows = NamedTuple[]
    for (index, match) in enumerate(response.matches)
        push!(
            rows,
            merge(
                base_row,
                (
                    match_index = index,
                    match_node_kind = _parser_match_value(match, "node_kind"),
                    match_name = _parser_match_value(match, "name"),
                    match_text = _parser_match_value(match, "text"),
                    match_signature = _parser_match_value(match, "signature"),
                    match_line_start = _parser_match_int(match, "line_start"),
                    match_line_end = _parser_match_int(match, "line_end"),
                    match_target_line_start = _parser_match_int(match, "target_line_start"),
                    match_target_line_end = _parser_match_int(match, "target_line_end"),
                ),
            ),
        )
    end
    return rows
end

function _parser_summary_response_rows(responses::AbstractVector{ParserResponse})
    rows = NamedTuple[]
    for response in responses
        append!(rows, _parser_summary_response_rows(response))
    end
    return rows
end

function _parser_summary_response_rows(response::ParserResponse)
    summary_scalars = response.summary_scalars
    base_row = (
        request_id = response.request_id,
        source_id = response.source_id,
        summary_kind = response.summary_kind,
        backend = response.backend,
        success = response.success,
        primary_name = something(response.primary_name, missing),
        error_message = something(response.error_message, missing),
        module_name = _parser_summary_scalar(summary_scalars, "module_name"),
        class_name = _parser_summary_scalar(summary_scalars, "class_name"),
        restriction = _parser_summary_scalar(summary_scalars, "restriction"),
    )
    if !response.success || isempty(response.summary_items)
        return [merge(base_row, _parser_empty_summary_item_row())]
    end

    rows = NamedTuple[]
    for (index, item) in enumerate(response.summary_items)
        push!(
            rows,
            merge(
                base_row,
                (
                    item_index = index,
                    item_group = _parser_summary_item_text(item, "group"),
                    item_name = _parser_summary_item_text(item, "name"),
                    item_kind = _parser_summary_item_text(item, "kind"),
                    item_text = _parser_summary_item_text(item, "text"),
                    item_signature = _parser_summary_item_text(item, "signature"),
                    item_target_kind = _parser_summary_item_text(item, "target_kind"),
                    item_module = _parser_summary_item_text(item, "module"),
                    item_path = _parser_summary_item_text(item, "path"),
                    item_content = _parser_summary_item_text(item, "content"),
                    item_reexported = _parser_summary_item_bool(item, "reexported"),
                    item_visibility = _parser_summary_item_text(item, "visibility"),
                    item_type_name = _parser_summary_item_text(item, "type_name"),
                    item_variability = _parser_summary_item_text(item, "variability"),
                    item_direction = _parser_summary_item_text(item, "direction"),
                    item_component_kind = _parser_summary_item_text(item, "component_kind"),
                    item_default_value = _parser_summary_item_text(item, "default_value"),
                    item_unit = _parser_summary_item_text(item, "unit"),
                    item_owner_name = _parser_summary_item_text(item, "owner_name"),
                    item_line_start = _parser_summary_item_int(item, "line_start"),
                    item_line_end = _parser_summary_item_int(item, "line_end"),
                    item_target_line_start = _parser_summary_item_int(
                        item,
                        "target_line_start",
                    ),
                    item_target_line_end = _parser_summary_item_int(
                        item,
                        "target_line_end",
                    ),
                    item_is_partial = _parser_summary_item_bool(item, "is_partial"),
                    item_is_final = _parser_summary_item_bool(item, "is_final"),
                    item_is_encapsulated = _parser_summary_item_bool(
                        item,
                        "is_encapsulated",
                    ),
                ),
            ),
        )
    end
    return rows
end

function _parser_empty_summary_item_row()
    return (
        item_index = missing,
        item_group = missing,
        item_name = missing,
        item_kind = missing,
        item_text = missing,
        item_signature = missing,
        item_target_kind = missing,
        item_module = missing,
        item_path = missing,
        item_content = missing,
        item_reexported = missing,
        item_visibility = missing,
        item_type_name = missing,
        item_variability = missing,
        item_direction = missing,
        item_component_kind = missing,
        item_default_value = missing,
        item_unit = missing,
        item_owner_name = missing,
        item_line_start = missing,
        item_line_end = missing,
        item_target_line_start = missing,
        item_target_line_end = missing,
        item_is_partial = missing,
        item_is_final = missing,
        item_is_encapsulated = missing,
    )
end

function _parser_match_value(match::AbstractDict{String,Any}, key::AbstractString)
    value = get(match, String(key), nothing)
    return isnothing(value) ? missing : String(value)
end

function _parser_match_int(match::AbstractDict{String,Any}, key::AbstractString)
    value = get(match, String(key), nothing)
    return isnothing(value) ? missing : Int(value)
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
