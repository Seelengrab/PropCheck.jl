module PropCheck

using Compat: Returns

using Base: Signed
using Test
using InteractiveUtils: subtypes

export generate, shrink
export check
export Integrated, Generator

# Trees
export root, subtrees, unfold, interleave
export itype, ival, iconst, isample, iunique

"""
    shrink(val::T) where T

Function to be used during shrinking of `val`. Must return an iterable of shrunk values, which can be lazy. If the returned iterable is empty,
it's taken as a signal that the given value cannot shrink further.

Must _never_ return a previously input value, i.e. no value `val` used as input should ever be produced by `shrink(val)` or subsequent applications of `shrink` on the produced elements.
This _will_ lead to infinite looping during shrinking.
"""
function shrink end

"""
    generate(rng::AbstractRNG, ::Type{T}) where T -> T

Function to generate a single value of type `T`. Falls back to constructor inspection, which _will_ generate values for `::Any` typed arguments.

Types that have `rand` defined for them should forward to it here, assuming `rand` returns the full spectrum of possible instances.
Assumed to return an object of type `T`.

!!! note "Float64"
    A good example for when not to forward to `rand` is `Float64` - by default, Julia only generates values in the half-open interval `[0,1)`,
    meaning `Inf`, `NaN` and similar special values aren't generated at all. As you might imagine, this is not desirable for a framework that
    ought to find bugs in code that _doesn't_ handle these kinds of values correctly.
"""
function generate end

include("util.jl")
include("iteratorextras.jl")
include("config.jl")
include("generators.jl")
include("manual.jl")
include("shrinkers.jl")
include("tree.jl")
include("integrated.jl")
include("checking.jl")

"""
    itype(T::Type[, shrink=shrink]) -> AbstractIntegrated

A convenience constructor for creating integrated shrinkers, generating their values from a type.

Trees created by this function will have their elements shrink according to `shrink`.
"""
itype(::Type{T}, shrink=shrink) where T = Integrated(Generator(T), shrink)

"""
    ival(x::T[, shrink=shrink]) -> AbstractIntegrated

A convenience constructor for creating integrated shrinkers, generating their values from a starting value.

Trees created by this function will always initially have `x` at their root, as well as shrink
according to `shrink`.
"""
ival(x::T, shrink=shrink) where T = IntegratedVal(x, shrink)

"""
    iconst(x) -> AbstractIntegrated

A convenience constructor for creating an integrated shrinker.

Trees created by this do not shrink, and `generate` on the returned `AbstractIntegrated` will always
produce `x`.
"""
iconst(x) = IntegratedConst(x)

"""
    isample(x[, shrink=shrink]) -> AbstractIntegrated

A convenience constructor for creating an integrated shrinker.

Trees created by this shrink according to `shrink`, and `generate` on the returned
`Integrated` will always produce an element of the collection `x`.

`x` needs to be indexable.
"""
function isample(x, shrink=shrink)
    gen = Generator{eltype(x)}(rng -> rand(rng, x))
    Integrated(gen, shrink)
end

"""
    isample(x::AbstractRange[, shrink=shrinkTowards(first(x))]) -> AbstractIntegrated

A convenience constructor for creating an integrated shrinker.

Trees created by this shrink towards the first element of the range by default.
"""
function isample(x::AbstractRange, shrink=shrinkTowards(first(x)))
    gen = Generator{eltype(x)}(rng -> rand(rng, x))
    IntegratedRange(x, gen, shrink)
end

"""
    iunique(x::Vector, shrink=shrink) -> AbstractIntegrated

A convenience constructor for creating an integrated shrinker.

This shrinker produces all unique values of `x` before producing a value it has produced before.
The produced trees shrink according to `shrink`.
"""
iunique(x::Vector{T}, shrink=shrink) where T = IntegratedUnique(x, shrink)

end # module
