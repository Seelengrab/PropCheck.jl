module PropCheck

using Base: Signed
using Test
using InteractiveUtils: subtypes

export generate, shrink
export check
export Integrated, Generator

# Trees
export root, subtrees, unfold, interleave
export igen

"""
    shrink(x)

Function to be used during shrinking of `x`. Returns an iterable of shrunk values.

Must _never_ return a previously input value, i.e. no value `x` used as input should ever be produced by `shrink(x)` or subsequent applications of `shrink` on the produced elements. This _will_ lead to infinite looping during shrinking.
"""
function shrink end

include("util.jl")
include("iteratorextras.jl")
include("config.jl")
include("generators.jl")
include("shrinkers.jl")
include("tree.jl")
include("integrated.jl")
include("checking.jl")

const igen = (Integrated ∘ Generator)

end # module
