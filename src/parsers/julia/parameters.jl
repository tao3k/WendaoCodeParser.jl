function _julia_function_parameter_metadata(call_node, source::String)
    parameter_entries = _julia_function_parameter_entries(call_node, source)
    positional_names = String[]
    keyword_names = String[]
    defaulted_names = String[]
    typed_names = String[]
    positional_vararg_name = nothing
    keyword_vararg_name = nothing

    for parameter_entry in parameter_entries
        if parameter_entry.parameter_kind == "keyword"
            push!(keyword_names, parameter_entry.name)
            parameter_entry.vararg && (keyword_vararg_name = parameter_entry.name)
        else
            push!(positional_names, parameter_entry.name)
            parameter_entry.vararg && (positional_vararg_name = parameter_entry.name)
        end
        parameter_entry.defaulted && push!(defaulted_names, parameter_entry.name)
        parameter_entry.typed && push!(typed_names, parameter_entry.name)
    end

    metadata = Dict{String,Any}()
    isempty(positional_names) ||
        (metadata["function_positional_params"] = join(positional_names, ","))
    isempty(keyword_names) ||
        (metadata["function_keyword_params"] = join(keyword_names, ","))
    isempty(defaulted_names) ||
        (metadata["function_defaulted_params"] = join(defaulted_names, ","))
    isempty(typed_names) || (metadata["function_typed_params"] = join(typed_names, ","))
    isnothing(positional_vararg_name) ||
        (metadata["function_positional_vararg_name"] = positional_vararg_name)
    isnothing(keyword_vararg_name) ||
        (metadata["function_keyword_vararg_name"] = keyword_vararg_name)
    return metadata
end

function _collect_julia_function_parameters!(
    node,
    state::JuliaCollectionState,
    source::String,
    line_starts::Vector{Int},
    context::JuliaScopeContext,
    function_name::String,
    function_signature::String,
    function_line_start::Int,
)
    call_node = _julia_function_call_node(node)
    isnothing(call_node) && return nothing
    for parameter_entry in _julia_function_parameter_entries(call_node, source)
        line_start, line_end = _julia_line_span(parameter_entry.node, line_starts)
        _push_parameter!(
            state,
            parameter_entry.name,
            parameter_entry.parameter_kind,
            parameter_entry.text,
            line_start,
            line_end,
            context;
            function_name = function_name,
            function_signature = function_signature,
            function_line_start = function_line_start,
            type_name = parameter_entry.type_name,
            default_value = parameter_entry.default_value,
            typed = parameter_entry.typed,
            defaulted = parameter_entry.defaulted,
            vararg = parameter_entry.vararg,
        )
    end
    return nothing
end

function _julia_function_parameter_entries(call_node, source::String)
    entries = NamedTuple[]
    skipped_head = false
    for child in _julia_child_nodes(call_node)
        if !skipped_head
            skipped_head = true
            continue
        end
        if _julia_kind_name(child) == "parameters"
            for parameter_child in _julia_child_nodes(child)
                _push_julia_parameter_entry!(entries, parameter_child, "keyword", source)
            end
        else
            _push_julia_parameter_entry!(entries, child, "positional", source)
        end
    end
    return entries
end

function _push_julia_parameter_entry!(
    entries::Vector{NamedTuple},
    node,
    parameter_kind::String,
    source::String,
)
    parameter_info = _julia_parameter_info(node, source)
    isnothing(parameter_info.name) && return nothing
    push!(
        entries,
        (
            node = node,
            parameter_kind = parameter_kind,
            name = something(parameter_info.name),
            text = String(strip(_julia_node_text(node, source))),
            typed = parameter_info.typed,
            defaulted = parameter_info.defaulted,
            vararg = parameter_info.vararg,
            type_name = parameter_info.type_name,
            default_value = parameter_info.default_value,
        ),
    )
    return nothing
end

function _julia_parameter_info(node, source::String)
    name = _julia_parameter_name(node, source)
    return (
        name = name,
        typed = _julia_parameter_is_typed(node),
        defaulted = _julia_parameter_has_default(node),
        vararg = _julia_parameter_is_vararg(node),
        type_name = _julia_parameter_type_name(node, source),
        default_value = _julia_parameter_default_value(node, source),
    )
end

function _julia_parameter_name(node, source::String)
    node_kind = _julia_kind_name(node)
    if node_kind == "Identifier"
        return _julia_node_text(node, source)
    elseif node_kind == "::" || node_kind == "=" || node_kind == "..."
        first_child = _julia_first_nontrivia_child(node)
        isnothing(first_child) && return nothing
        return _julia_parameter_name(first_child, source)
    end
    return nothing
end

function _julia_parameter_is_typed(node)
    node_kind = _julia_kind_name(node)
    node_kind == "::" && return true
    if node_kind == "=" || node_kind == "..."
        first_child = _julia_first_nontrivia_child(node)
        isnothing(first_child) && return false
        return _julia_parameter_is_typed(first_child)
    end
    return false
end

function _julia_parameter_has_default(node)
    node_kind = _julia_kind_name(node)
    node_kind == "=" && return true
    if node_kind == "..."
        first_child = _julia_first_nontrivia_child(node)
        isnothing(first_child) && return false
        return _julia_parameter_has_default(first_child)
    end
    return false
end

function _julia_parameter_is_vararg(node)
    node_kind = _julia_kind_name(node)
    node_kind == "..." && return true
    if node_kind == "=" || node_kind == "::"
        first_child = _julia_first_nontrivia_child(node)
        isnothing(first_child) && return false
        return _julia_parameter_is_vararg(first_child)
    end
    return false
end

function _julia_parameter_type_name(node, source::String)
    node_kind = _julia_kind_name(node)
    if node_kind == "::"
        type_node = _julia_last_nontrivia_child(node)
        isnothing(type_node) && return nothing
        return String(strip(_julia_node_text(type_node, source)))
    elseif node_kind == "=" || node_kind == "..."
        first_child = _julia_first_nontrivia_child(node)
        isnothing(first_child) && return nothing
        return _julia_parameter_type_name(first_child, source)
    end
    return nothing
end

function _julia_parameter_default_value(node, source::String)
    node_kind = _julia_kind_name(node)
    if node_kind == "="
        default_node = _julia_last_nontrivia_child(node)
        isnothing(default_node) && return nothing
        return String(strip(_julia_node_text(default_node, source)))
    elseif node_kind == "..."
        first_child = _julia_first_nontrivia_child(node)
        isnothing(first_child) && return nothing
        return _julia_parameter_default_value(first_child, source)
    end
    return nothing
end
