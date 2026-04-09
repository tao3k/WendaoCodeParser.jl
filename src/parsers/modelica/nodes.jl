function _modelica_ast_node(
    node_kind::String,
    name::String;
    text::Union{Nothing,String} = nothing,
    line_start::Union{Nothing,Int} = nothing,
    line_end::Union{Nothing,Int} = nothing,
    metadata = Dict{String,Any}(),
)
    return Dict{String,Any}(
        "node_kind" => node_kind,
        "name" => name,
        "text" => text,
        "line_start" => line_start,
        "line_end" => line_end,
        "signature" => text,
        "metadata" => Dict{String,Any}(metadata),
    )
end
