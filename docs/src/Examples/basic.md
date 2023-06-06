# Basic Usage

Property based testing is all about having a _function_ to test and a set of _properties_ that should hold on the outputs of that
function, given its inputs. It is, in part, a philosophy of test driven design.

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
    a, b = minmax(a,b)
    sumres = a
    for _ in one(b):b
        sumres = add(sumres, one(b))
    end

    sumres == add(a,b)
end

# output

successor (generic function with 1 method)
```

To check that the properties hold, we first need to define a generator for our input. In this case, we are interested in integers, so
let's define a simple generator that just draws some random numbers. The most basic generator PropCheck provides is [`itype`](@ref), which
generates values of a given type:

```jldoctest example_add; output = false, filter = r"Integrated\{.+\}\(.+\)"
using PropCheck

gen = PropCheck.itype(Int)

# output

Integrated{PropCheck.Tree{Int64}, PropCheck.var"#gen#36"{Generator{Int64, PropCheck.var"#5#6"{Int64}}}}(PropCheck.var"#gen#36"{Generator{Int64, PropCheck.var"#5#6"{Int64}}}(Generator{Int64, PropCheck.var"#5#6"{Int64}}(PropCheck.var"#5#6"{Int64}())))
```

which we can then use to check that our `identity_add` property holds:

```jldoctest example_add
julia> check(identity_add, gen)
true
```

Perhaps unsurprisingly (we're only forwarding to `+` after all), the property holds - PropCheck was unable to find a counterexample.

Here's an example for a property that doesn't hold, showing how PropCheck handles generated cases that fail:

```jldoctest example_add; filter = [r"\[ Info: \d+ counterexamples", r"└   Counterexample = -?\d+"]
julia> failprop(x) = add(x, one(x)) < x;

julia> check(failprop, gen)
┌ Info: Found counterexample for 'failprop', beginning shrinking...
└   Counterexample = 909071986488726633
[ Info: 10 counterexamples found
0
```

PropCheck, once it finds a counterexample to our property (i.e., an input to the property that makes the property error or return `false`),
tries to shrink the counterexample to a smaller one, pinpointing the failure to one that is more manageable
when debugging. In this case, the integrated shrinker `itype(Int)` tries to minimize the absolute value
of the generated number that still fails the property, which is `0` - `0+1` is, after all, not smaller than `0`.

!!! note "Overflow"
    There is a subtle bug here - if `x+1` overflows when `x == typemax(Int)`, the resulting comparison is
    `true`: `typemin(Int) < typemax(Int)` after all. It's important to keep these kinds of subtleties, as
    well as the invariants the datatype guarantees, in mind when choosing a generator and writing properties
    to check the datatype and its functions for.

We've still got three more properties to test, taking two or three arguments each, but `itype` only ever generates one value.
Since we know the number of arguments to each function, we can pair a integrated shrinker for the appropriate
arguments with splatting those arguments into the property with `Base.splat` to test them:

```jldoctest example_add; filter = r"(Test.DefaultTestSet.+)|(Addition\s+\|\s+4\s+4\s+\d\.\ds)|#"
using Test
@testset "Addition" begin
    @test check(identity_add,       itype(UInt))
    @test check(splat(commutative), itype(Tuple{UInt, UInt}))
    @test check(splat(successor),   itype(Tuple{UInt, UInt}))
    @test check(splat(associative), itype(Tuple{UInt, UInt, UInt}))
end
# output
Test Summary: | Pass  Total  Time
Addition      |    4      4  0.3s
Test.DefaultTestSet("Addition", Any[], 4, false, false, true, 1.652808363118544e9, 1.652808363384581e9, false, "")
```

Be aware that while all checks pass, we _do not have a guarantee that our code is correct for all cases_.
Sampling elements to test is a statistical process and as such we can only gain _confidence_ that our code
is correct. You may view this in the light of Bayesian statistics, where we update our prior that the code
is correct as we run our testsuite more often. This is also true were we not using property based testing
or PropCheck at all - with traditional testing approaches, only the values we've actually run the code with
can be said to be tested.
