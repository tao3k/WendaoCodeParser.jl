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
