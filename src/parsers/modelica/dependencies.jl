function _modelica_dependency_leaf_name(target::AbstractString)
    segments = split(String(target), '.')
    isempty(segments) && return nothing
    leaf = last(segments)
    return isempty(leaf) ? nothing : leaf
end

function _modelica_import_dependency(import_)
    if import_ isa Absyn.NAMED_IMPORT
        target = _modelica_path_string(import_.path)
        return Dict{String,Any}(
            "dependency_target" => target,
            "dependency_form" => "named_import",
            "dependency_alias" => String(import_.name),
            "dependency_local_name" => String(import_.name),
        )
    elseif import_ isa Absyn.QUAL_IMPORT
        target = _modelica_path_string(import_.path)
        return Dict{String,Any}(
            "dependency_target" => target,
            "dependency_form" => "qualified_import",
            "dependency_local_name" => _modelica_dependency_leaf_name(target),
        )
    elseif import_ isa Absyn.UNQUAL_IMPORT
        target = _modelica_path_string(import_.path)
        return Dict{String,Any}(
            "dependency_target" => target,
            "dependency_form" => "unqualified_import",
            "dependency_local_name" => _modelica_dependency_leaf_name(target),
        )
    elseif import_ isa Absyn.GROUP_IMPORT
        prefix = _modelica_path_string(import_.prefix)
        return Dict{String,Any}(
            "dependency_target" => prefix,
            "dependency_form" => "group_import",
            "dependency_parent" => prefix,
        )
    end
    return Dict{String,Any}("dependency_target" => string(import_))
end

function _push_modelica_import!(
    state::ModelicaCollectionState,
    import_name::String;
    line_start::Union{Nothing,Int} = nothing,
    line_end::Union{Nothing,Int} = nothing,
    metadata = Dict{String,Any}(),
)
    import_metadata = Dict{String,Any}(metadata)
    owner_key =
        String(get(import_metadata, "owner_path", get(import_metadata, "owner_name", "")))
    dependency_form = String(get(import_metadata, "dependency_form", "import"))
    import_key = (
        import_name,
        dependency_form,
        String(get(import_metadata, "dependency_alias", "")),
        owner_key,
    )
    import_key in state.import_set && return nothing
    push!(state.import_set, import_key)
    import_entry = Dict{String,Any}(
        "module" => import_name,
        "dependency_kind" => "import",
        "dependency_target" => import_name,
        "dependency_form" => dependency_form,
        "line_start" => line_start,
        "line_end" => line_end,
    )
    merge!(import_entry, import_metadata)
    push!(state.imports, import_entry)
    import_metadata["module"] = import_name
    import_metadata["dependency_kind"] = "import"
    import_metadata["dependency_target"] = import_name
    import_metadata["dependency_form"] = dependency_form
    push!(
        state.nodes,
        _modelica_ast_node(
            "import",
            import_name;
            text = import_name,
            line_start = line_start,
            line_end = line_end,
            metadata = import_metadata,
        ),
    )
    return nothing
end

function _push_modelica_extend!(
    state::ModelicaCollectionState,
    extend_name::String;
    line_start::Union{Nothing,Int} = nothing,
    line_end::Union{Nothing,Int} = nothing,
    metadata = Dict{String,Any}(),
)
    extend_metadata = Dict{String,Any}(metadata)
    owner_key =
        String(get(extend_metadata, "owner_path", get(extend_metadata, "owner_name", "")))
    extend_key = (extend_name, owner_key)
    extend_key in state.extend_set && return nothing
    push!(state.extend_set, extend_key)
    extend_entry = Dict{String,Any}(
        "path" => extend_name,
        "dependency_kind" => "extends",
        "dependency_target" => extend_name,
        "dependency_form" => "extends",
        "line_start" => line_start,
        "line_end" => line_end,
    )
    merge!(extend_entry, extend_metadata)
    push!(state.extends, extend_entry)
    extend_metadata["path"] = extend_name
    extend_metadata["dependency_kind"] = "extends"
    extend_metadata["dependency_target"] = extend_name
    extend_metadata["dependency_form"] = "extends"
    push!(
        state.nodes,
        _modelica_ast_node(
            "extends",
            extend_name;
            text = extend_name,
            line_start = line_start,
            line_end = line_end,
            metadata = extend_metadata,
        ),
    )
    return nothing
end

function _modelica_dependency_summary_items(state::ModelicaCollectionState)
    items = Dict{String,Any}[]
    append!(
        items,
        [
            Dict(
                "group" => "import",
                "name" => String(entry["module"]),
                "module" => String(entry["module"]),
                "dependency_kind" => String(get(entry, "dependency_kind", "import")),
                "dependency_target" =>
                    String(get(entry, "dependency_target", entry["module"])),
                "dependency_form" => String(get(entry, "dependency_form", "import")),
                "dependency_local_name" => get(entry, "dependency_local_name", nothing),
                "dependency_parent" => get(entry, "dependency_parent", nothing),
                "dependency_member" => get(entry, "dependency_member", nothing),
                "dependency_alias" => get(entry, "dependency_alias", nothing),
                "owner_name" => get(entry, "owner_name", nothing),
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
                "group" => "extend",
                "path" => String(entry["path"]),
                "dependency_kind" => String(get(entry, "dependency_kind", "extends")),
                "dependency_target" =>
                    String(get(entry, "dependency_target", entry["path"])),
                "dependency_form" => String(get(entry, "dependency_form", "extends")),
                "dependency_local_name" => get(entry, "dependency_local_name", nothing),
                "dependency_parent" => get(entry, "dependency_parent", nothing),
                "dependency_member" => get(entry, "dependency_member", nothing),
                "dependency_alias" => get(entry, "dependency_alias", nothing),
                "owner_name" => get(entry, "owner_name", nothing),
                "owner_path" => get(entry, "owner_path", nothing),
                "line_start" => get(entry, "line_start", nothing),
                "line_end" => get(entry, "line_end", nothing),
            ) for entry in state.extends
        ],
    )
    return items
end
