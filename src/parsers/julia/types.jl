function _julia_type_kind(node, source::String)
    node_kind = _julia_kind_name(node)
    node_kind == "struct" &&
        startswith(_julia_node_signature(node, source), "mutable struct") &&
        return "mutable_struct"
    node_kind == "struct" && return "struct"
    node_kind == "abstract" && return "abstract_type"
    node_kind == "primitive" && return "primitive_type"
    return nothing
end

function _julia_type_header_metadata(node, source::String)
    metadata = Dict{String,Any}()
    type_kind = _julia_type_kind(node, source)
    isnothing(type_kind) || (metadata["type_kind"] = type_kind)
    type_parameters = _julia_type_parameters(node, source)
    isnothing(type_parameters) || (metadata["type_parameters"] = type_parameters)
    type_supertype = _julia_type_supertype(node, source)
    isnothing(type_supertype) || (metadata["type_supertype"] = type_supertype)
    primitive_bits = _julia_primitive_bits(node, source)
    isnothing(primitive_bits) || (metadata["primitive_bits"] = primitive_bits)
    return metadata
end

function _julia_type_name(node, source::String)
    header_name_node = _julia_type_header_name_node(node)
    isnothing(header_name_node) && return nothing
    if _julia_kind_name(header_name_node) == "curly"
        identifier = _julia_first_nontrivia_child(header_name_node)
        isnothing(identifier) && return nothing
        return _julia_symbol_name(identifier, source)
    end
    return _julia_symbol_name(header_name_node, source)
end

function _julia_type_parameters(node, source::String)
    header_node = _julia_type_header_name_node(node)
    isnothing(header_node) && return nothing
    _julia_kind_name(header_node) == "curly" || return nothing
    parameters = String[]
    for (index, child) in enumerate(_julia_child_nodes(header_node))
        index == 1 && continue
        push!(parameters, strip(_julia_node_text(child, source)))
    end
    isempty(parameters) && return nothing
    return join(parameters, ", ")
end

function _julia_type_supertype(node, source::String)
    header_node = _julia_type_header_node(node)
    isnothing(header_node) && return nothing
    _julia_kind_name(header_node) == "<:" || return nothing
    children = collect(_julia_child_nodes(header_node))
    length(children) >= 2 || return nothing
    return strip(_julia_node_text(children[2], source))
end

function _julia_primitive_bits(node, source::String)
    _julia_kind_name(node) == "primitive" || return nothing
    integer_node = _julia_first_child_of_kind(node, "Integer")
    isnothing(integer_node) && return nothing
    return strip(_julia_node_text(integer_node, source))
end

function _julia_type_header_node(node)
    return _julia_first_nontrivia_child(node)
end

function _julia_type_header_name_node(node)
    header_node = _julia_type_header_node(node)
    isnothing(header_node) && return nothing
    if _julia_kind_name(header_node) == "<:"
        return _julia_first_nontrivia_child(header_node)
    end
    return header_node
end
