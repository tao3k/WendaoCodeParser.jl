function _julia_dependency_kind(node)::String
    return _julia_kind_name(node) == "using" ? "using" : "import"
end

function _julia_dependency_entry(
    target::AbstractString;
    parent = nothing,
    member = nothing,
    alias = nothing,
)
    entry = Dict{String,Any}("dependency_target" => String(target))
    isnothing(parent) || (entry["dependency_parent"] = String(parent))
    isnothing(member) || (entry["dependency_member"] = String(member))
    isnothing(alias) || (entry["dependency_alias"] = String(alias))
    return entry
end

function _julia_import_dependencies(node, source::String)
    dependencies = Dict{String,Any}[]
    for child in _julia_child_nodes(node)
        append!(dependencies, _julia_import_dependencies(child, source, nothing))
    end
    return dependencies
end

function _julia_import_dependencies(node, source::String, parent)
    node_kind = _julia_kind_name(node)
    if node_kind == "importpath"
        target = strip(_julia_node_text(node, source))
        if isnothing(parent)
            return [_julia_dependency_entry(target)]
        end
        member = target
        return [
            _julia_dependency_entry(
                "$(parent).$(member)";
                parent = parent,
                member = member,
            ),
        ]
    elseif node_kind == "as"
        children = collect(_julia_child_nodes(node))
        isempty(children) && return Dict{String,Any}[]
        alias = length(children) >= 2 ? _julia_symbol_name(children[2], source) : nothing
        dependencies = _julia_import_dependencies(children[1], source, parent)
        for entry in dependencies
            isnothing(alias) || (entry["dependency_alias"] = String(alias))
        end
        return dependencies
    elseif node_kind == ":"
        children = collect(_julia_child_nodes(node))
        isempty(children) && return Dict{String,Any}[]
        prefix_entries = _julia_import_dependencies(children[1], source, nothing)
        isempty(prefix_entries) && return Dict{String,Any}[]
        prefix = String(prefix_entries[1]["dependency_target"])
        dependencies = Dict{String,Any}[]
        for child in Iterators.drop(children, 1)
            append!(dependencies, _julia_import_dependencies(child, source, prefix))
        end
        return dependencies
    end

    dependencies = Dict{String,Any}[]
    for child in _julia_child_nodes(node)
        append!(dependencies, _julia_import_dependencies(child, source, parent))
    end
    return dependencies
end

function _collect_julia_import!(
    node,
    state::JuliaCollectionState,
    source::String,
    line_starts::Vector{Int};
    reexported::Bool = false,
    context::JuliaScopeContext = JuliaScopeContext(),
)
    line_start, line_end = _julia_line_span(node, line_starts)
    dependency_kind = _julia_dependency_kind(node)
    dependencies = _julia_import_dependencies(node, source)
    for dependency in dependencies
        _push_import!(
            state,
            String(dependency["dependency_target"]),
            line_start,
            line_end;
            dependency_kind = dependency_kind,
            dependency_parent = get(dependency, "dependency_parent", nothing),
            dependency_member = get(dependency, "dependency_member", nothing),
            dependency_alias = get(dependency, "dependency_alias", nothing),
            reexported = reexported,
            context = context,
        )
    end
    return nothing
end

function _collect_julia_include!(
    node,
    state::JuliaCollectionState,
    source::String,
    line_starts::Vector{Int},
    context::JuliaScopeContext,
)
    _is_julia_include_call(node, source) || return nothing
    include_path = _julia_include_path(node, source)
    isnothing(include_path) && return nothing
    line_start, line_end = _julia_line_span(node, line_starts)
    _push_include!(state, something(include_path), line_start, line_end, context)
    return nothing
end

function _push_import!(
    state::JuliaCollectionState,
    import_name::String,
    line_start::Int,
    line_end::Int;
    dependency_kind::String,
    dependency_parent = nothing,
    dependency_member = nothing,
    dependency_alias = nothing,
    reexported::Bool = false,
    context::JuliaScopeContext = JuliaScopeContext(),
)
    scope_key = _julia_scope_key(context)
    existing_index = findfirst(
        entry ->
            String(entry["module"]) == import_name &&
                String(get(entry, "dependency_kind", "import")) == dependency_kind &&
                String(get(entry, "dependency_parent", "")) ==
                String(something(dependency_parent, "")) &&
                String(get(entry, "dependency_member", "")) ==
                String(something(dependency_member, "")) &&
                String(get(entry, "dependency_alias", "")) ==
                String(something(dependency_alias, "")) &&
                String(get(entry, "owner_path", get(entry, "module_path", ""))) == scope_key,
        state.imports,
    )
    if !isnothing(existing_index)
        if reexported && !Bool(get(state.imports[existing_index], "reexported", false))
            state.imports[existing_index]["reexported"] = true
            for node in Iterators.reverse(state.nodes)
                if get(node, "node_kind", nothing) == "import" &&
                   get(node, "name", nothing) == import_name &&
                   String(
                       get(
                           get(node, "metadata", Dict{String,Any}()),
                           "dependency_kind",
                           "import",
                       ),
                   ) == dependency_kind &&
                   String(
                       get(
                           get(node, "metadata", Dict{String,Any}()),
                           "dependency_parent",
                           "",
                       ),
                   ) == String(something(dependency_parent, "")) &&
                   String(
                       get(
                           get(node, "metadata", Dict{String,Any}()),
                           "dependency_member",
                           "",
                       ),
                   ) == String(something(dependency_member, "")) &&
                   String(
                       get(
                           get(node, "metadata", Dict{String,Any}()),
                           "dependency_alias",
                           "",
                       ),
                   ) == String(something(dependency_alias, "")) &&
                   String(
                       get(
                           get(node, "metadata", Dict{String,Any}()),
                           "owner_path",
                           get(
                               get(node, "metadata", Dict{String,Any}()),
                               "module_path",
                               "",
                           ),
                       ),
                   ) == scope_key
                    node_metadata = get(node, "metadata", Dict{String,Any}())
                    node_metadata["reexported"] = true
                    node["metadata"] = node_metadata
                    break
                end
            end
        end
        return nothing
    end

    push!(
        state.import_set,
        (
            import_name,
            dependency_kind,
            String(something(dependency_parent, "")),
            String(something(dependency_member, "")),
            String(something(dependency_alias, "")),
            scope_key,
        ),
    )
    entry = Dict{String,Any}(
        "module" => import_name,
        "dependency_kind" => dependency_kind,
        "dependency_target" => import_name,
        "reexported" => reexported,
        "line_start" => line_start,
        "line_end" => line_end,
    )
    isnothing(dependency_parent) || (entry["dependency_parent"] = String(dependency_parent))
    isnothing(dependency_member) || (entry["dependency_member"] = String(dependency_member))
    isnothing(dependency_alias) || (entry["dependency_alias"] = String(dependency_alias))
    merge!(entry, _julia_scope_metadata(context))
    push!(state.imports, entry)
    metadata = _julia_scope_metadata(context)
    metadata["module"] = import_name
    metadata["dependency_kind"] = dependency_kind
    metadata["dependency_target"] = import_name
    isnothing(dependency_parent) ||
        (metadata["dependency_parent"] = String(dependency_parent))
    isnothing(dependency_member) ||
        (metadata["dependency_member"] = String(dependency_member))
    isnothing(dependency_alias) || (metadata["dependency_alias"] = String(dependency_alias))
    metadata["reexported"] = reexported
    _push_ast_node!(
        state,
        "import",
        import_name;
        text = import_name,
        line_start = line_start,
        line_end = line_end,
        metadata = metadata,
    )
    return nothing
end

function _push_include!(
    state::JuliaCollectionState,
    include_literal::String,
    line_start::Int,
    line_end::Int,
    context::JuliaScopeContext,
)
    include_key = (include_literal, _julia_scope_key(context))
    include_key in state.include_set && return nothing
    push!(state.include_set, include_key)
    include_entry = Dict{String,Any}(
        "path" => include_literal,
        "dependency_kind" => "include",
        "dependency_target" => include_literal,
        "line_start" => line_start,
        "line_end" => line_end,
    )
    merge!(include_entry, _julia_scope_metadata(context))
    push!(state.includes, include_entry)
    metadata = _julia_scope_metadata(context)
    metadata["path"] = include_literal
    metadata["dependency_kind"] = "include"
    metadata["dependency_target"] = include_literal
    _push_ast_node!(
        state,
        "include",
        include_literal;
        text = include_literal,
        line_start = line_start,
        line_end = line_end,
        metadata = metadata,
    )
    return nothing
end

function _julia_dependency_summary_items(state::JuliaCollectionState)
    items = Dict{String,Any}[]
    append!(
        items,
        [
            Dict(
                "group" => "import",
                "module" => String(entry["module"]),
                "dependency_kind" => String(get(entry, "dependency_kind", "import")),
                "dependency_target" =>
                    String(get(entry, "dependency_target", entry["module"])),
                "dependency_parent" => get(entry, "dependency_parent", nothing),
                "dependency_member" => get(entry, "dependency_member", nothing),
                "dependency_alias" => get(entry, "dependency_alias", nothing),
                "reexported" => Bool(get(entry, "reexported", false)),
                "owner_name" => get(entry, "owner_name", nothing),
                "owner_kind" => get(entry, "owner_kind", nothing),
                "module_name" => get(entry, "module_name", nothing),
                "module_path" => get(entry, "module_path", nothing),
                "owner_path" => get(entry, "owner_path", nothing),
                "line_start" => get(entry, "line_start", nothing),
                "line_end" => get(entry, "line_end", nothing),
            ) for entry in state.imports
        ],
    )
    append!(
        items,
        [
            Dict(
                "group" => "include",
                "path" => String(entry["path"]),
                "dependency_kind" => String(get(entry, "dependency_kind", "include")),
                "dependency_target" =>
                    String(get(entry, "dependency_target", entry["path"])),
                "dependency_parent" => get(entry, "dependency_parent", nothing),
                "dependency_member" => get(entry, "dependency_member", nothing),
                "dependency_alias" => get(entry, "dependency_alias", nothing),
                "owner_name" => get(entry, "owner_name", nothing),
                "owner_kind" => get(entry, "owner_kind", nothing),
                "module_name" => get(entry, "module_name", nothing),
                "module_path" => get(entry, "module_path", nothing),
                "owner_path" => get(entry, "owner_path", nothing),
                "line_start" => get(entry, "line_start", nothing),
                "line_end" => get(entry, "line_end", nothing),
            ) for entry in state.includes
        ],
    )
    return items
end
