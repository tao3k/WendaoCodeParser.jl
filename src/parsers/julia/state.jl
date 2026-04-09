struct JuliaScopeContext
    root_module_name::Union{Nothing,String}
    module_name::Union{Nothing,String}
    module_path::Union{Nothing,String}
    owner_name::Union{Nothing,String}
    owner_kind::Union{Nothing,String}
    owner_path::Union{Nothing,String}
end

JuliaScopeContext() =
    JuliaScopeContext(nothing, nothing, nothing, nothing, nothing, nothing)

mutable struct JuliaCollectionState
    module_name::Union{Nothing,String}
    module_kind::Union{Nothing,String}
    exports::Vector{Dict{String,Any}}
    export_set::Set{Tuple{String,String}}
    imports::Vector{Dict{String,Any}}
    import_set::Set{NTuple{7,String}}
    symbols::Vector{Dict{String,Any}}
    symbol_set::Set{Tuple{String,String,String,Int,Int}}
    parameters::Vector{Dict{String,Any}}
    docstrings::Vector{Dict{String,Any}}
    includes::Vector{Dict{String,Any}}
    include_set::Set{Tuple{String,String}}
    nodes::Vector{Dict{String,Any}}
end

function JuliaCollectionState()
    return JuliaCollectionState(
        nothing,
        nothing,
        Dict{String,Any}[],
        Set{Tuple{String,String}}(),
        Dict{String,Any}[],
        Set{NTuple{7,String}}(),
        Dict{String,Any}[],
        Set{Tuple{String,String,String,Int,Int}}(),
        Dict{String,Any}[],
        Dict{String,Any}[],
        Dict{String,Any}[],
        Set{Tuple{String,String}}(),
        Dict{String,Any}[],
    )
end
