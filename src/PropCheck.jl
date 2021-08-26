module PropCheck

using Base: Signed
using Test
using InteractiveUtils: subtypes

export generate, @check, @forall, @suchthat, @set, shrink
export Integrated, Generator

"""
    shrink(x)

    Function to be used during shrinking of `x`. Returns a `Vector` of shrinked values.
    
    Must _never_ return a previously input value, i.e. no value `x` used as input should ever be produced by `shrink(x)` or subsequent applications of `shrink` on the produced elements.
"""
function shrink end

include("config.jl")
include("macros.jl")
include("util.jl")
include("generators.jl")
include("shrinkers.jl")

end # module
