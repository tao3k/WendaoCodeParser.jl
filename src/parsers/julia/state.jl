mutable struct JuliaCollectionState
    module_name::Union{Nothing,String}
    exports::Vector{Dict{String,Any}}
    export_set::Set{String}
    imports::Vector{Dict{String,Any}}
    import_set::Set{String}
    symbols::Vector{Dict{String,Any}}
    symbol_set::Set{Tuple{String,String}}
    docstrings::Vector{Dict{String,Any}}
    includes::Vector{Dict{String,Any}}
    include_set::Set{String}
    nodes::Vector{Dict{String,Any}}
end

function JuliaCollectionState()
    return JuliaCollectionState(
        nothing,
        Dict{String,Any}[],
        Set{String}(),
        Dict{String,Any}[],
        Set{String}(),
        Dict{String,Any}[],
        Set{Tuple{String,String}}(),
        Dict{String,Any}[],
        Dict{String,Any}[],
        Set{String}(),
        Dict{String,Any}[],
    )
end
