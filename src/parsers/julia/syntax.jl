function _julia_kind_name(node)
    return string(JuliaSyntax.kind(node))
end

function _julia_child_nodes(node)
    return JuliaSyntax.haschildren(node) ? JuliaSyntax.children(node) : ()
end

function _julia_first_child_of_kind(node, expected_kind::AbstractString)
    for child in _julia_child_nodes(node)
        _julia_kind_name(child) == expected_kind && return child
    end
    return nothing
end

function _julia_first_string_child(node)
    for child in _julia_child_nodes(node)
        startswith(_julia_kind_name(child), "string") && return child
    end
    return nothing
end

function _julia_last_non_string_child(node)
    last_child = nothing
    for child in _julia_child_nodes(node)
        startswith(_julia_kind_name(child), "string") && continue
        last_child = child
    end
    return last_child
end

function _julia_node_text(node, source::String)
    return String(source[JuliaSyntax.byte_range(node)])
end

function _julia_node_signature(node, source::String)
    text = _julia_node_text(node, source)
    first_line = strip(first(split(text, '\n'; keepempty = true)))
    return first_line
end

function _julia_function_signature(node, source::String)
    signature = _julia_node_signature(node, source)
    startswith(signature, "function ") && return strip(signature[length("function ")+1:end])
    return signature
end

function _julia_string_content(node, source::String)
    string_child = _julia_first_child_of_kind(node, "String")
    !isnothing(string_child) && return _julia_node_text(string_child, source)

    raw = _julia_node_text(node, source)
    try
        parsed = Meta.parse(raw)
        parsed isa AbstractString && return String(parsed)
    catch
    end
    return strip(raw, ['"', '\''])
end

function _julia_doc_target(node, source::String)
    if _julia_kind_name(node) == "module"
        name = _julia_first_identifier_text(node, source)
        isnothing(name) || return (name = something(name), target_kind = "module")
        return nothing
    end
    symbol_name = _julia_symbol_name(node, source)
    isnothing(symbol_name) && return nothing
    return (name = something(symbol_name), target_kind = "symbol")
end

function _julia_symbol_name(node, source::String)
    node_kind = _julia_kind_name(node)
    if node_kind == "Identifier"
        return _julia_node_text(node, source)
    elseif node_kind == "function"
        return _julia_function_name(node, source)
    elseif node_kind == "call"
        first_child = _julia_first_nontrivia_child(node)
        isnothing(first_child) && return nothing
        return _julia_symbol_name(first_child, source)
    elseif node_kind == "where" || node_kind == "::"
        first_child = _julia_first_nontrivia_child(node)
        isnothing(first_child) && return nothing
        return _julia_symbol_name(first_child, source)
    elseif node_kind == "."
        return _julia_dotted_name(node, source)
    elseif node_kind == "struct" ||
           node_kind == "abstract" ||
           node_kind == "primitive" ||
           node_kind == "module"
        return _julia_first_identifier_text(node, source)
    end
    return nothing
end

function _julia_function_name(node, source::String)
    first_child = _julia_first_nontrivia_child(node)
    isnothing(first_child) && return nothing
    return _julia_symbol_name(first_child, source)
end

function _julia_first_identifier_text(node, source::String)
    child = _julia_first_child_of_kind(node, "Identifier")
    isnothing(child) && return nothing
    return _julia_node_text(child, source)
end

function _julia_first_nontrivia_child(node)
    for child in _julia_child_nodes(node)
        return child
    end
    return nothing
end

function _julia_dotted_name(node, source::String)
    parts = String[]
    _collect_julia_name_parts!(parts, node, source)
    isempty(parts) && return nothing
    return join(parts, ".")
end

function _collect_julia_name_parts!(parts::Vector{String}, node, source::String)
    node_kind = _julia_kind_name(node)
    if node_kind == "Identifier"
        push!(parts, _julia_node_text(node, source))
        return nothing
    elseif node_kind == "." || node_kind == "importpath"
        for child in _julia_child_nodes(node)
            _collect_julia_name_parts!(parts, child, source)
        end
        return nothing
    end
    JuliaSyntax.haschildren(node) || return nothing
    for child in _julia_child_nodes(node)
        _collect_julia_name_parts!(parts, child, source)
    end
    return nothing
end

function _julia_import_modules(node, source::String)
    paths = String[]
    _collect_julia_import_paths!(paths, node, source)
    isempty(paths) && return String[]
    _julia_contains_kind(node, ":") && return [first(paths)]
    return unique(paths)
end

function _collect_julia_import_paths!(paths::Vector{String}, node, source::String)
    if _julia_kind_name(node) == "importpath"
        push!(paths, strip(_julia_node_text(node, source)))
        return nothing
    end
    for child in _julia_child_nodes(node)
        _collect_julia_import_paths!(paths, child, source)
    end
    return nothing
end

function _julia_contains_kind(node, expected_kind::AbstractString)
    _julia_kind_name(node) == expected_kind && return true
    for child in _julia_child_nodes(node)
        _julia_contains_kind(child, expected_kind) && return true
    end
    return false
end

function _julia_macro_name(node, source::String)
    macro_node = _julia_first_child_of_kind(node, "macro_name")
    isnothing(macro_node) && return nothing
    return strip(_julia_node_text(macro_node, source))
end

function _is_julia_include_call(node, source::String)
    _julia_kind_name(node) == "call" || return false
    first_child = _julia_first_nontrivia_child(node)
    isnothing(first_child) && return false
    return _julia_kind_name(first_child) == "Identifier" &&
           _julia_node_text(first_child, source) == "include"
end

function _julia_include_path(node, source::String)
    for child in _julia_child_nodes(node)
        startswith(_julia_kind_name(child), "string") || continue
        return _julia_string_content(child, source)
    end
    return nothing
end

function _julia_line_starts(source::String)
    starts = Int[firstindex(source)]
    for index in eachindex(source)
        source[index] == '\n' || continue
        next_index = nextind(source, index)
        next_index <= lastindex(source) && push!(starts, next_index)
    end
    return starts
end

function _julia_line_span(node, line_starts::Vector{Int})
    range = JuliaSyntax.byte_range(node)
    return (
        _julia_line_number_for_index(line_starts, first(range)),
        _julia_line_number_for_index(line_starts, last(range)),
    )
end

function _julia_doc_spans(string_node, target_node, line_starts::Vector{Int})
    doc_line_start, doc_line_end = _julia_line_span(string_node, line_starts)
    target_line_start, target_line_end = _julia_line_span(target_node, line_starts)
    return (doc_line_start, doc_line_end, target_line_start, target_line_end)
end

function _julia_line_number_for_index(line_starts::Vector{Int}, index::Int)
    line_number = searchsortedlast(line_starts, index)
    return max(line_number, 1)
end
