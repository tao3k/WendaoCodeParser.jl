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
        module_kind = _parser_summary_scalar(summary_scalars, "module_kind"),
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
                    item_array_dimensions = _parser_summary_item_text(
                        item,
                        "array_dimensions",
                    ),
                    item_default_value = _parser_summary_item_text(item, "default_value"),
                    item_start_value = _parser_summary_item_text(item, "start_value"),
                    item_modifier_names = _parser_summary_item_text(item, "modifier_names"),
                    item_unit = _parser_summary_item_text(item, "unit"),
                    item_binding_kind = _parser_summary_item_text(item, "binding_kind"),
                    item_type_kind = _parser_summary_item_text(item, "type_kind"),
                    item_function_positional_arity = _parser_summary_item_int(
                        item,
                        "function_positional_arity",
                    ),
                    item_function_keyword_arity = _parser_summary_item_int(
                        item,
                        "function_keyword_arity",
                    ),
                    item_function_has_varargs = _parser_summary_item_bool(
                        item,
                        "function_has_varargs",
                    ),
                    item_function_where_params = _parser_summary_item_text(
                        item,
                        "function_where_params",
                    ),
                    item_function_return_type = _parser_summary_item_text(
                        item,
                        "function_return_type",
                    ),
                    item_function_positional_params = _parser_summary_item_text(
                        item,
                        "function_positional_params",
                    ),
                    item_function_keyword_params = _parser_summary_item_text(
                        item,
                        "function_keyword_params",
                    ),
                    item_function_defaulted_params = _parser_summary_item_text(
                        item,
                        "function_defaulted_params",
                    ),
                    item_function_typed_params = _parser_summary_item_text(
                        item,
                        "function_typed_params",
                    ),
                    item_function_positional_vararg_name = _parser_summary_item_text(
                        item,
                        "function_positional_vararg_name",
                    ),
                    item_function_keyword_vararg_name = _parser_summary_item_text(
                        item,
                        "function_keyword_vararg_name",
                    ),
                    item_parameter_kind = _parser_summary_item_text(item, "parameter_kind"),
                    item_parameter_type_name = _parser_summary_item_text(
                        item,
                        "parameter_type_name",
                    ),
                    item_parameter_default_value = _parser_summary_item_text(
                        item,
                        "parameter_default_value",
                    ),
                    item_parameter_is_typed = _parser_summary_item_bool(
                        item,
                        "parameter_is_typed",
                    ),
                    item_parameter_is_defaulted = _parser_summary_item_bool(
                        item,
                        "parameter_is_defaulted",
                    ),
                    item_parameter_is_vararg = _parser_summary_item_bool(
                        item,
                        "parameter_is_vararg",
                    ),
                    item_owner_name = _parser_summary_item_text(item, "owner_name"),
                    item_owner_kind = _parser_summary_item_text(item, "owner_kind"),
                    item_owner_path = _parser_summary_item_text(item, "owner_path"),
                    item_module_name = _parser_summary_item_text(item, "module_name"),
                    item_module_path = _parser_summary_item_text(item, "module_path"),
                    item_class_path = _parser_summary_item_text(item, "class_path"),
                    item_target_path = _parser_summary_item_text(item, "target_path"),
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
        item_array_dimensions = missing,
        item_default_value = missing,
        item_start_value = missing,
        item_modifier_names = missing,
        item_unit = missing,
        item_binding_kind = missing,
        item_type_kind = missing,
        item_function_positional_arity = missing,
        item_function_keyword_arity = missing,
        item_function_has_varargs = missing,
        item_function_where_params = missing,
        item_function_return_type = missing,
        item_function_positional_params = missing,
        item_function_keyword_params = missing,
        item_function_defaulted_params = missing,
        item_function_typed_params = missing,
        item_function_positional_vararg_name = missing,
        item_function_keyword_vararg_name = missing,
        item_parameter_kind = missing,
        item_parameter_type_name = missing,
        item_parameter_default_value = missing,
        item_parameter_is_typed = missing,
        item_parameter_is_defaulted = missing,
        item_parameter_is_vararg = missing,
        item_owner_name = missing,
        item_owner_kind = missing,
        item_owner_path = missing,
        item_module_name = missing,
        item_module_path = missing,
        item_class_path = missing,
        item_target_path = missing,
        item_line_start = missing,
        item_line_end = missing,
        item_target_line_start = missing,
        item_target_line_end = missing,
        item_is_partial = missing,
        item_is_final = missing,
        item_is_encapsulated = missing,
    )
end
