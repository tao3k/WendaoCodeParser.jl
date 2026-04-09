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
                    match_target_kind = missing,
                    match_module = missing,
                    match_module_kind = missing,
                    match_path = missing,
                    match_dependency_kind = missing,
                    match_dependency_target = missing,
                    match_dependency_parent = missing,
                    match_dependency_member = missing,
                    match_dependency_alias = missing,
                    match_line_start = missing,
                    match_line_end = missing,
                    match_target_line_start = missing,
                    match_target_line_end = missing,
                    match_owner_name = missing,
                    match_owner_kind = missing,
                    match_owner_path = missing,
                    match_module_name = missing,
                    match_module_path = missing,
                    match_class_path = missing,
                    match_target_path = missing,
                    match_binding_kind = missing,
                    match_type_kind = missing,
                    match_function_positional_arity = missing,
                    match_function_keyword_arity = missing,
                    match_function_has_varargs = missing,
                    match_function_where_params = missing,
                    match_function_return_type = missing,
                    match_function_positional_params = missing,
                    match_function_keyword_params = missing,
                    match_function_defaulted_params = missing,
                    match_function_typed_params = missing,
                    match_function_positional_vararg_name = missing,
                    match_function_keyword_vararg_name = missing,
                    match_parameter_kind = missing,
                    match_parameter_type_name = missing,
                    match_parameter_default_value = missing,
                    match_parameter_is_typed = missing,
                    match_parameter_is_defaulted = missing,
                    match_parameter_is_vararg = missing,
                    match_array_dimensions = missing,
                    match_start_value = missing,
                    match_modifier_names = missing,
                    match_attribute_key = missing,
                    match_attribute_value = missing,
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
                    match_target_kind = _parser_match_value(match, "target_kind"),
                    match_module = _parser_match_value(match, "module"),
                    match_module_kind = _parser_match_value(match, "module_kind"),
                    match_path = _parser_match_value(match, "path"),
                    match_dependency_kind = _parser_match_value(match, "dependency_kind"),
                    match_dependency_target = _parser_match_value(
                        match,
                        "dependency_target",
                    ),
                    match_dependency_parent = _parser_match_value(
                        match,
                        "dependency_parent",
                    ),
                    match_dependency_member = _parser_match_value(
                        match,
                        "dependency_member",
                    ),
                    match_dependency_alias = _parser_match_value(match, "dependency_alias"),
                    match_line_start = _parser_match_int(match, "line_start"),
                    match_line_end = _parser_match_int(match, "line_end"),
                    match_target_line_start = _parser_match_int(match, "target_line_start"),
                    match_target_line_end = _parser_match_int(match, "target_line_end"),
                    match_owner_name = _parser_match_value(match, "owner_name"),
                    match_owner_kind = _parser_match_value(match, "owner_kind"),
                    match_owner_path = _parser_match_value(match, "owner_path"),
                    match_module_name = _parser_match_value(match, "module_name"),
                    match_module_path = _parser_match_value(match, "module_path"),
                    match_class_path = _parser_match_value(match, "class_path"),
                    match_target_path = _parser_match_value(match, "target_path"),
                    match_binding_kind = _parser_match_value(match, "binding_kind"),
                    match_type_kind = _parser_match_value(match, "type_kind"),
                    match_function_positional_arity = _parser_match_int(
                        match,
                        "function_positional_arity",
                    ),
                    match_function_keyword_arity = _parser_match_int(
                        match,
                        "function_keyword_arity",
                    ),
                    match_function_has_varargs = _parser_match_bool(
                        match,
                        "function_has_varargs",
                    ),
                    match_function_where_params = _parser_match_value(
                        match,
                        "function_where_params",
                    ),
                    match_function_return_type = _parser_match_value(
                        match,
                        "function_return_type",
                    ),
                    match_function_positional_params = _parser_match_value(
                        match,
                        "function_positional_params",
                    ),
                    match_function_keyword_params = _parser_match_value(
                        match,
                        "function_keyword_params",
                    ),
                    match_function_defaulted_params = _parser_match_value(
                        match,
                        "function_defaulted_params",
                    ),
                    match_function_typed_params = _parser_match_value(
                        match,
                        "function_typed_params",
                    ),
                    match_function_positional_vararg_name = _parser_match_value(
                        match,
                        "function_positional_vararg_name",
                    ),
                    match_function_keyword_vararg_name = _parser_match_value(
                        match,
                        "function_keyword_vararg_name",
                    ),
                    match_parameter_kind = _parser_match_value(match, "parameter_kind"),
                    match_parameter_type_name = _parser_match_value(
                        match,
                        "parameter_type_name",
                    ),
                    match_parameter_default_value = _parser_match_value(
                        match,
                        "parameter_default_value",
                    ),
                    match_parameter_is_typed = _parser_match_bool(
                        match,
                        "parameter_is_typed",
                    ),
                    match_parameter_is_defaulted = _parser_match_bool(
                        match,
                        "parameter_is_defaulted",
                    ),
                    match_parameter_is_vararg = _parser_match_bool(
                        match,
                        "parameter_is_vararg",
                    ),
                    match_array_dimensions = _parser_match_value(match, "array_dimensions"),
                    match_start_value = _parser_match_value(match, "start_value"),
                    match_modifier_names = _parser_match_value(match, "modifier_names"),
                    match_attribute_key = _parser_match_value(match, "attribute_key"),
                    match_attribute_value = _parser_match_value(match, "attribute_value"),
                ),
            ),
        )
    end
    return rows
end
