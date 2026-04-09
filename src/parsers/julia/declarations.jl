function _julia_module_kind(node, source::String)
    node_kind = _julia_kind_name(node)
    node_kind == "module" &&
        startswith(_julia_node_signature(node, source), "baremodule ") &&
        return "baremodule"
    node_kind == "module" && return "module"
    node_kind == "module-bare" && return "baremodule"
    return nothing
end

function _julia_binding_kind(node)
    node_kind = _julia_kind_name(node)
    node_kind == "const" && return "const"
    node_kind == "global" && return "global"
    return nothing
end

function _julia_binding_name(node, source::String)
    binding_kind = _julia_binding_kind(node)
    isnothing(binding_kind) && return nothing
    assignment = _julia_first_child_of_kind(node, "=")
    if !isnothing(assignment)
        first_child = _julia_first_nontrivia_child(assignment)
        isnothing(first_child) && return nothing
        return _julia_symbol_name(first_child, source)
    end
    first_child = _julia_first_nontrivia_child(node)
    isnothing(first_child) && return nothing
    return _julia_symbol_name(first_child, source)
end

function _julia_binding_signature(node, source::String)
    return _julia_node_signature(node, source)
end

function _julia_macro_definition_name(node, source::String)
    _julia_kind_name(node) == "macro" || return nothing
    head = _julia_first_nontrivia_child(node)
    isnothing(head) && return nothing
    return _julia_symbol_name(head, source)
end

function _julia_macro_definition_signature(node, source::String)
    signature = _julia_node_signature(node, source)
    startswith(signature, "macro ") && return signature
    macro_name = _julia_macro_definition_name(node, source)
    isnothing(macro_name) && return signature
    return "macro $(something(macro_name))"
end
