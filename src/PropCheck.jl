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
    shrink(val::T) where T

Function to be used during shrinking of `val`. Must return an iterable of shrunk values, which can be lazy. If the returned iterable is empty,
it's taken as a signal that the given value cannot shrink further.

Must _never_ return a previously input value, i.e. no value `val` used as input should ever be produced by `shrink(val)` or subsequent applications of `shrink` on the produced elements. This _will_ lead to infinite looping during shrinking.
"""
function shrink end

"""
    generate(rng::AbstractRNG, ::T) where T -> T
    generate(rng::AbstractRNG, ::Type{T}) where T -> T

Function to generate a single value of type `T`. Falls back to field inspection, which _will_ generate values for `::Any` typed fields.

A distinction is made between passing in an instance of a type and a type itself. The former is permitted to use the fields of the object
to steer generation, for example for more fine grained generation, while the latter is supposed to return all possible values the type
could express. Customizing the `::Type{T}` version is only recommended if you need to enforce invariants of the constructors of your type.

Types that have `rand` defined for them should forward to it here.
Assumed to return an object of type `T`.
"""
function generate end

include("util.jl")
include("iteratorextras.jl")
include("config.jl")
include("generators.jl")
include("shrinkers.jl")
include("tree.jl")
include("integrated.jl")
include("checking.jl")

"""
    igen(T)

A convenience constructor for creating integrated shrinkers.
"""
igen(x) = (Integrated ∘ Generator)(x)

end # module
