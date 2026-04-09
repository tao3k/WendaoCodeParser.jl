function _julia_function_header_metadata(node, source::String)
    call_node = _julia_function_call_node(node)
    isnothing(call_node) && return Dict{String,Any}()

    metadata = Dict{String,Any}(
        "function_positional_arity" => _julia_function_positional_arity(call_node),
        "function_keyword_arity" => _julia_function_keyword_arity(call_node),
        "function_has_varargs" => _julia_function_has_varargs(call_node),
    )

    where_params = _julia_function_where_params(node, source)
    isnothing(where_params) || (metadata["function_where_params"] = where_params)

    return_type = _julia_function_return_type(node, source)
    isnothing(return_type) || (metadata["function_return_type"] = return_type)

    merge!(metadata, _julia_function_parameter_metadata(call_node, source))

    return metadata
end

function _julia_function_call_node(node)
    current =
        _julia_kind_name(node) == "function" ? _julia_first_nontrivia_child(node) : node
    while !isnothing(current)
        node_kind = _julia_kind_name(current)
        node_kind == "call" && return current
        if node_kind == "where" || node_kind == "::"
            current = _julia_first_nontrivia_child(current)
        else
            return nothing
        end
    end
    return nothing
end

function _julia_function_positional_arity(call_node)
    count = 0
    skipped_head = false
    for child in _julia_child_nodes(call_node)
        if !skipped_head
            skipped_head = true
            continue
        end
        _julia_kind_name(child) == "parameters" && continue
        count += 1
    end
    return count
end

function _julia_function_keyword_arity(call_node)
    parameters_node = _julia_first_child_of_kind(call_node, "parameters")
    isnothing(parameters_node) && return 0
    count = 0
    for _ in _julia_child_nodes(parameters_node)
        count += 1
    end
    return count
end

function _julia_function_has_varargs(call_node)
    skipped_head = false
    for child in _julia_child_nodes(call_node)
        if !skipped_head
            skipped_head = true
            continue
        end
        if _julia_kind_name(child) == "parameters"
            for parameter_child in _julia_child_nodes(child)
                _julia_kind_name(parameter_child) == "..." && return true
            end
        elseif _julia_kind_name(child) == "..."
            return true
        end
    end
    return false
end

function _julia_function_where_params(node, source::String)
    head_node =
        _julia_kind_name(node) == "function" ? _julia_first_nontrivia_child(node) : node
    return _julia_function_where_params(head_node, source, nothing)
end

function _julia_function_where_params(node, source::String, _)
    isnothing(node) && return nothing
    node_kind = _julia_kind_name(node)
    if node_kind == "where"
        braces_node = _julia_first_child_of_kind(node, "braces")
        isnothing(braces_node) && return nothing
        return _julia_brace_contents(braces_node, source)
    elseif node_kind == "::"
        return _julia_function_where_params(
            _julia_first_nontrivia_child(node),
            source,
            nothing,
        )
    end
    return nothing
end

function _julia_function_return_type(node, source::String)
    head_node =
        _julia_kind_name(node) == "function" ? _julia_first_nontrivia_child(node) : node
    return _julia_function_return_type_from_head(head_node, source)
end

function _julia_function_return_type_from_head(node, source::String)
    isnothing(node) && return nothing
    node_kind = _julia_kind_name(node)
    if node_kind == "::"
        type_node = _julia_last_nontrivia_child(node)
        isnothing(type_node) && return nothing
        return strip(_julia_node_text(type_node, source))
    elseif node_kind == "where"
        return _julia_function_return_type_from_head(
            _julia_first_nontrivia_child(node),
            source,
        )
    end
    return nothing
end

function _julia_last_nontrivia_child(node)
    last_child = nothing
    for child in _julia_child_nodes(node)
        last_child = child
    end
    return last_child
end

function _julia_brace_contents(node, source::String)
    text = strip(_julia_node_text(node, source))
    startswith(text, "{") && endswith(text, "}") || return text
    start_index = nextind(text, firstindex(text))
    end_index = prevind(text, lastindex(text))
    start_index > end_index && return ""
    return strip(text[start_index:end_index])
end
