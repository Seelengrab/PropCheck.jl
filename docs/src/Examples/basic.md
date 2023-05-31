# Basic Usage

Property based testing is all about having a _function_ to test and a set of _properties_ that should hold on the outputs of that
function, given its inputs. It is, in part, a philosophy of test driven design.

```@meta
DocTestSetup = quote
    using PropCheck
end
```

## A simple example

Consider this `add` function:

```jldoctest example_add; output=false
function add(a,b)
    a + b
end
# output
add (generic function with 1 method)
```

How would we test this? First we have to define the properties we expect to hold. In this case, it's just the laws of addition:

```jldoctest example_add; output = false
commutative(a,b)   =  add(a,b) == add(b,a)
associative(a,b,c) =  add(add(a,b), c) == add(a, add(b,c))
identity_add(a)    =  add(a,zero(a)) == a
function successor(a::T, b::T) where T
    # this function assumes a < b
    s = a
    for _ in one(a):b
        s = add(s, one(a))
    end

    s == add(a,b)
end
# output
successor (generic function with 1 method)
```

To check that the properties hold, we first need to define a generator for our input. In this case, we are interested in integers, so
let's define a simple generator that just draws some random numbers:

```jldoctest example_add; output = false, filter = r"Integrated\{.+\}\(.+\)"
using PropCheck

gen = PropCheck.itype(Int)
# output
Integrated{PropCheck.Tree{Int64}, PropCheck.var"#gen#36"{Generator{Int64, PropCheck.var"#5#6"{Int64}}}}(PropCheck.var"#gen#36"{Generator{Int64, PropCheck.var"#5#6"{Int64}}}(Generator{Int64, PropCheck.var"#5#6"{Int64}}(PropCheck.var"#5#6"{Int64}())))
```

which we can then use to check our properties:

```jldoctest example_add
julia> check(identity_add, gen)
true
```

Perhaps unsurprisingly (we're only forwarding to `+` after all), the property holds. Under the hood, PropCheck.jl generates a bunch of initial
test cases from the generator we created, runs the property against them and, if any failed, generates new testcases from the failing cases.
We can see how this works by checking out how we can generate collections of things.

## Generating tuples

We're going to start by generating homogenous tuples of things. PropCheck.jl provides a convenience function for this:
[`PropCheck.tuple(n, gen)`](@ref).

Consider this property:

```@example tuple
using PropCheck

prop(x) = all(<(5), x)
```

This property tests whether all elements of the argument are smaller than `5`. When running `check` on a property, `PropCheck` tries to find
the smallest counterexample. See how `PropCheck` shrinks a counterexample using a tuple of `3` distinct `Int8` as input:

```@example tuple
ENV["JULIA_DEBUG"] = PropCheck # to enable the debug printing of intermediate shrinking values

check(prop, PropCheck.tuple(iconst(0x3), itype(Int8)))
nothing # hide
```

And its return value:

```@example tuple
check(prop, PropCheck.tuple(iconst(0x3), itype(Int8))) # hide
```

PropCheck.jl successfully reduced the first failing test case to one where no elements can be shrunk further without making the test pass,
giving us our smallest possible counterexample - a tuple with all zeros, except for one place which has `5` instead.

!!! note "CI inconsistencies"
	Due to this having to run twice for both the debug output and the return value to print in the docs, the value returned may not
	be the exact same as printed in the debug printing of the last shrunk value. The property will still fail for both outputs though -
	and in this case, will be one of `(0,0,5)`, `(0,5,0)` or `(5,0,0)`, depending on the initial found counterexample and how it shrunk.

	This is also a very important point - failures are often not unique, which is why we're shrinking them in the first place!

You may notice that the tuple is always of size 3, never smaller - the reasoning for this behavior is twofold:

 1. Tuples generally don't change their size - they are immutable containers, and as such manipulating them will create a new tuple altogether.
 2. Tuples are created during generation when you require a constant number of things, but want to still shrink the things themselves.

While it is possible to generate tuples with a generated size as well (notice that we're passing in a range now instead of a raw number):

```julia-repl
julia> t = PropCheck.tuple(isample(0x0:0x5), itype(Int8));

julia> generate(t)
Tree(())

julia> generate(t)
Tree((9, 98, -88, -45))

julia> generate(t)
Tree((7,))
```

shrinking the resulting cases will _not_ shrink the length of the tuple, since they are an immutable container with fixed length.

### Splatting

Since `PropCheck.check` returns either `true` or a failing case, it easily integrates into existing test infrastructure that makes use of `@testset` and `@test`:

```jldoctest example_add; filter = r"(Test.DefaultTestSet.+)|(Addition\s+\|\s+3\s+3\s+\d\.\ds)"
ENV["JULIA_DEBUG"] = "" # to prevent spamming in docs

using Test
@testset "Addition" begin
    @test check(Base.splat(commutative), PropCheck.tuple(iconst(0x2), itype(Int8)))
    @test check(Base.splat(associative), PropCheck.tuple(iconst(0x3), itype(Int8)))
    @test check(identity_add, itype(Int8))
end
# output
Test Summary: | Pass  Total  Time
Addition      |    3      3  0.3s
Test.DefaultTestSet("Addition", Any[], 3, false, false, true, 1.652808363118544e9, 1.652808363384581e9) # this is just the value returned by @testset - you can ignore this
```

Note the use of `Base.splat` to splat the tuple into the arguments of both `commutative` as well as `associative`. This makes it possible to
create all arguments to a function in one generator, while not having to adjust the function signature just for testing.

!!! note "Splat"
	From Julia 1.9 onwards, you can use the exported `Splat` object instead of `Base.splat`, which has newly added pretty printing to
	aid in debugging. The pretty printing preserves the captured function name, to make it easy to find out which properties fail.

Be aware that while all tests pass, we _do not have a guarantee that our code is correct for all cases_. Sampling elements to test is a
statistical process and as such we can only gain _confidence_ that our code is correct. You may view this in the light of Bayesian statistics, where we update our prior that our code is correct as we run our testsuite more often.

## Generating vectors

Similar to tuples, there is also `PropCheck.vector(n, gen)` to get a generator which generates `Vector`s of `3` elements:

```jldoctest examplevec; output = false, filter = r"Integrated\{.+\}\(.+\)"
vec = PropCheck.vector(iconst(3), itype(Int8))
# output
Integrated{Vector{Int8}, PropCheck.var"#genF#43"{Int64, Integrated{PropCheck.Tree{Int8}, PropCheck.var"#gen#36"{Generator{Int8, PropCheck.var"#5#6"{Int8}}}}}}(PropCheck.var"#genF#43"{Int64, Integrated{PropCheck.Tree{Int8}, PropCheck.var"#gen#36"{Generator{Int8, PropCheck.var"#5#6"{Int8}}}}}(3, Integrated{PropCheck.Tree{Int8}, PropCheck.var"#gen#36"{Generator{Int8, PropCheck.var"#5#6"{Int8}}}}(PropCheck.var"#gen#36"{Generator{Int8, PropCheck.var"#5#6"{Int8}}}(Generator{Int8, PropCheck.var"#5#6"{Int8}}(PropCheck.var"#5#6"{Int8}())))))
```

Which we can then run against the `prop` from earlier:

```jldoctest examplevec; filter = r"((│|┌|└)\s+.+\n)|(\[ Info: (\d+))"
julia> ENV["JULIA_DEBUG"] = PropCheck # to enable the debug printing of intermediate shrinking values
PropCheck

julia> prop(x) = all(<(5), x)
prop (generic function with 1 method)

julia> check(prop, vec)
[ Info: Found counterexample for 'prop', beginning shrinking...
┌ Debug: Possible shrink value
│   r =
│    3-element Vector{Int8}:
│     -47
│      50
│     111
└ @ PropCheck ~/Documents/projects/PropCheck.jl/src/checking.jl:29
┌ Debug: Possible shrink value
│   r =
│    2-element Vector{Int8}:
│      50
│     111
└ @ PropCheck ~/Documents/projects/PropCheck.jl/src/checking.jl:29
┌ Debug: Possible shrink value
│   r =
│    1-element Vector{Int8}:
│     111
└ @ PropCheck ~/Documents/projects/PropCheck.jl/src/checking.jl:29
┌ Debug: Possible shrink value
│   r =
│    1-element Vector{Int8}:
│     15
└ @ PropCheck ~/Documents/projects/PropCheck.jl/src/checking.jl:29
┌ Debug: Possible shrink value
│   r =
│    1-element Vector{Int8}:
│     7
└ @ PropCheck ~/Documents/projects/PropCheck.jl/src/checking.jl:29
┌ Debug: Possible shrink value
│   r =
│    1-element Vector{Int8}:
│     5
└ @ PropCheck ~/Documents/projects/PropCheck.jl/src/checking.jl:29
[ Info: 7 counterexamples found
┌ Debug: PropCheck.CheckEntry{Vector{Int8}}[PropCheck.CheckEntry{Vector{Int8}}(Int8[-119, -47, 50, 111], nothing), PropCheck.CheckEntry{Vector{Int8}}(Int8[-47, 50, 111], nothing), PropCheck.CheckEntry{Vector{Int8}}(Int8[50, 111], nothing), PropCheck.CheckEntry{Vector{Int8}}(Int8[111], nothing), PropCheck.CheckEntry{Vector{Int8}}(Int8[15], nothing), PropCheck.CheckEntry{Vector{Int8}}(Int8[7], nothing), PropCheck.CheckEntry{Vector{Int8}}(Int8[5], nothing)]
└ @ PropCheck ~/Documents/projects/PropCheck.jl/src/checking.jl:7
1-element Vector{Int8}:
 5
```

PropCheck tries to find the smallest counterexample when it finds one - in this case, that is `[5]`, a single element vector containing only the
element `5`. This requires a complication though - both the length of the vector and each element of the vector itself needs to shrink. Purely
from the type, we don't have information about the length of the `Vector`, so we have to make `PropCheck` aware of that information by creating a
custom, chained generator (also called dependent, because the endresult depends on more than one generated input).

You might wonder why `Propcheck.vector` and `PropCheck.tuple` are required in the first place. Can't we just do `itype(Vector{Int8})`?
Well, yes we could, but we have to both generate a length, as well as each element. Trouble is, only generating the length would only
allow us to shrink the length, while only generating elements would prevent us from shrinking the length. So the generation of elements also
depends on the _generated_ length. During shrinking, we have to make a choice: Do we start shrinking the length of the array first,
or do we start shrinking the elements of the array? No matter what we start with, if we just generate one and let the other follow and
naively try to shrink it, _we can can only shrink one thing in one step_. If we switch to shrinking the other, we can't go back to generating or
shrinking the first one anymore. If we generate both, integrated shrinking retains knowledge of how initial failing cases were generated and
can take advantage of that for subsequent shrinks.

However, for regular use this shouldn't matter too much, and we'll get into the details of how to construct more complex types later on.
