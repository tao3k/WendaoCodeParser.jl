const TEST_ROOT = normpath(joinpath(@__DIR__, ".."))

const JULIA_SOURCE = """
module Demo
\"\"\"docstring for foo\"\"\"
foo(x)=x

struct Bar
    x::Int
end

include("nested.jl")
using DataFrames
export foo, Bar
end
"""

modelica_fixture_path(parts...) = joinpath(TEST_ROOT, "fixtures", "modelica", parts...)
