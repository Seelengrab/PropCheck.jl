# Chaining generation

Sometimes, it is useful to be able to generate a finite set of "special values", before throwing the full brunt of possible values of a type at your function.
At other times, you may want to test a few special distributions of values whose generation isn't finite, before having PropCheck.jl try a generic type-based
fuzzing approach. In these cases, it's helpful to try one of the subtypes of [`PropCheck.FiniteIntegrated`](@ref).

## IntegratedOnce

[`PropCheck.IntegratedOnce`](@ref) is the "Give me a value, but please only one value" version of [`PropCheck.ival`](@ref). It is semantically the same as 
`PropCheck.IntegratedLengthBounded(ival(x), 1)` (which we'll look at in detail later), but with a more efficient implementation.

Here's an example:

```@repl once
using PropCheck
using PropCheck: IntegratedOnce

gen = IntegratedOnce(5)
tree = generate(gen)

subtrees(tree) |> collect # The shrink tree is unfolded as usual
generate(gen) isa Nothing # but subsequent `generate` calls don't produce any value
generate(gen) isa Nothing
```

If you know that you're only going to require the value to be tested exactly once, while still being able to test its shrinks in case the property fails, `IntegratedOnce` can be a very good choice.
An example use case is for regression testing of known previous failures.

Of course, this kind of integrated shrinker can be `map`ped and `filter`ed just the same as regular infinite generators:

```@repl once
gen = filter(iseven, IntegratedOnce(5));
tree = generate(gen)
root(tree)
subtrees(tree) |> collect
gen = map(x -> 2x, IntegratedOnce(5));
tree = generate(gen)
root(tree)
subtrees(tree) |> collect
```

!!! warning "Copying & exhaustion"
    Keep in mind that all finite generators can only be exhausted _once_. So be sure to `deepcopy` the finite generators
    if you want to reuse them in multiple places. This may later be relaxed to only `copy` for some finite generators,
    in order to reuse as many reusable generators as possible.

## IntegratedFiniteIterator

[`PropCheck.IntegratedFiniteIterator`](@ref) can be used to produce the values of a given finite iterator, one after the other, before suspending generation of new values.

This is useful when you have a known set of special values that you want to try, which are likely to lead to issues. `IntegratedOnce` is similar to this integrated shrinker, with the difference being
that `IntegratedFiniteIterator` can take any arbitrary iterable (except other `AbstractIntegrated`) to produce their values in exactly the order they were originally produced in from the iterator.

```@repl finiteiter
using PropCheck
using PropCheck: IntegratedFiniteIterator

iter = 1:2:21
gen = IntegratedFiniteIterator(iter); # all odd values between 1 and 21, inclusive
length(gen) == length(iter)
all(zip(gen, iter)) do (gval, ival)
    root(gval) == ival
end
generate(gen) isa Nothing # and of course, once it's exhausted that's it
```

## IntegratedLengthBounded

[`PropCheck.IntegratedLengthBounded`](@ref) can be used to limit an [`PropCheck.AbstractIntegrated`](@ref) to a an upperbound in the count of generated values, before generation is suspended.

This can be useful for only wanting to generate a finite number of elements from some other infinite generator before switching to another one, as mentioned earlier. The basic usage is
passing an `AbstractIntegrated` as well as the desired maximum length. If a `FiniteIntegrated` is passed, the resulting integrated shrinker has as its length the `min` of the given
`FiniteIntegrated` and the given upper bound.

```@repl bounded
using PropCheck
using PropCheck: IntegratedLengthBounded, IntegratedOnce

gen = IntegratedLengthBounded(itype(Int8), 7);
collect(gen) # 7 `Tree{Int8}`

gen = IntegratedLengthBounded(IntegratedOnce(42), 99);
length(gen) # still only one `Tree{Int}`
collect(gen)
```

## IntegratedChain

While itself not guaranteed to be finite, [`PropCheck.IntegratedChain`](@ref) is the most useful tool when combining finite generators in this fashion. Its
constructor takes any number of `AbstractIntegrated`, though all but the last one are required to subtype `FiniteIntegrated`.
The last integrated shrinker may be truly `AbstractIntegrated`, though being `FiniteIntegrated` is also ok.

This allows `IntegratedChain` to be a building block for grouping special values together, or for preparing a known set of previous failures into a regression test,
while still allowing the values to shrink according to the shrinking function used during the original generation, if available.

```@repl chain
using PropCheck
using PropCheck: IntegratedChain, IntegratedOnce, IntegratedFiniteIterator
using Test

function myAdd(a::Float64, b::Float64)
    # whoops, this isn't `add` at all!
    1.0 <= a && return NaN
    a + b
end

previousFailure = interleave(IntegratedOnce(0.5), IntegratedOnce(0.2));
specialCases = IntegratedFiniteIterator((NaN, -1.0, 1.0, 0.0));
specialInput = interleave(specialCases, deepcopy(specialCases)); # take care to not consume too early

addGen = IntegratedChain(previousFailure, # fail early if this doesn't work
                         specialInput, # some known special cases
                         PropCheck.tuple(ival(2), itype(Float64))); # finally, fuzzing on arbitrary stuff!

function nanProp(a, b)
    res = myAdd(a,b)
    # only `NaN` should produce `NaN`
    (isnan(a) || isnan(b)) == isnan(res)
end

@testset "myAdd" begin # We find a failure past our first chain of special cases
    @test check(splat(nanProp), addGen)
end
```