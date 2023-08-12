# FAQ

## What exactly is "shrinking"?

And the related questions, "What is being minimized when shrinking? What is the figure of merit?", originally asked [here](https://discourse.julialang.org/t/ann-propcheck-jl/101481/21?u=sukera).

Measuring shrinking values is a bit difficult - after all, the goal is to create a smaller (to human eyes) instance of the given type. It's very subjective what that means, but there are
some generalities you can apply. For example, a `0.0` is less "complex" of a value than `1234651.3465`, so it's usually considered smaller for shrinking purposes. Similarly, an array with
just 2 values is generally considered simpler/smaller than an array with 4123 values, even if both arrays otherwise exhibit the same properties.

Expanding on that - consider checking whether all arrays of positive integers are sorted. Surely, there are lots of counterexamples to that, like `[164, 45, 128, 202, 87]`, `[5,3,2,1]`,
`[1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]`, but there's only one example that's minimal: `[1, 0]`, the array with minimal values and minimal length.

This is of course not correct for all properties and all value domains; the "minimal counterexample" can  look quite different depending on what kind of values you're mostly
interested in. For example, if you're interested in finding the smallest possible counterexample for arrays of `Int8`, it'll be `[-127, -128]`, because the smallest possible
counterexample numerically is a negative number with larger absolute value. By default, PropCheck won't give you that, because a smaller absolute value is usually more desirable
for humans to think about; the bitpattern underlying the number is simpler (or shorter, if you remove leading zeros). To have PropCheck give you those smaller numerical shrinks,
you simply give e.g. `itype` a shrinking function producing those values:

```julia
julia> using PropCheck

julia> vect = PropCheck.vector(ival(4), itype(Int8, PropCheck.shrinkTowards(typemin(Int8))));

julia> check(issorted, vect)
┌ Info: Found counterexample for 'issorted', beginning shrinking...
│   Counterexample =
│    4-element Vector{Int8}:
│      -2
│      58
│      21
└     -85
[ Info: 32 counterexamples found
2-element Vector{Int8}:
 -127
 -128
```

`shrinkTowards` currently only has definitions for numeric types (`<: Integer`, `<: AbstractFloat`, `Bool`) because shrinking towards a general object is quite a bit harder - e.g.
shrinking towards a given string could be an option by working through inserts, deletions & character changes, but I'll have to think about how to best do that to make sure the
full possible space between a given source & target string is generateable.

> What is being minimized when shrinking? What is the figure of merit?

Circling back around to your question - anything you want, really! With a custom shrinking function (which you can supply to everything that generates a value),
YOU get to decide how you want to shrink/minimize things. PropCheck.jl just tries to give you some sane defaults for types from Base (or at least, those I've
gotten around to implementing `generate` and `shrink` for). E.g. in [Composing Generators](@ref),
I use `PropCheck.noshrink` to make sure some strings _don't_ shrink when shrinking the object the generator is used in, because looking at a student with a name
is nicer than looking at a student with the empty string as a name. This is generally applicable with any custom shrinking function; whichever values you
consider to be smaller for the purpose of that shrinking function are what PropCheck.jl considers "smaller" (which is also why it's important that shrinking
functions can't produce shrinking loops - i.e. a shrinking function must never produce a value that, when shrunk with the same shrinking function again, could lead to the initial value).

## What about formal specifications?

While efforts regarding formal specifications & machine checkable proofs are comendable, I think we can get quite far with property based testing & fuzzing
before we need to tackle the dragon that is formal methods & verification. PropCheck.jl is decidedly not in the formal verification camp - it's not an interface
to SAT or SMT solvers, but a fuzzer. Said differently, property based testing + fuzzing are a fuzzy, statistical subset of full formal verification. You can think of
running fuzzing tests as increasing confidence in the correctness of your code each time you run your testsuite, due to different inputs being chosen.

That being said, if this package becomes obsolete due to tremendous advances in formal methods & verification in Julia, I'll happily retire this package to the annals of history :)

## What about package XYZ?

There are a number of other codebases related to property based testing (for example, [JCheck.jl](https://github.com/ps-pat/JCheck.jl), [QuickCheck.jl](https://github.com/pao/QuickCheck.jl)
or [RandomizedPropertyTest.jl](https://git.sr.ht/~quf/RandomizedPropertyTest.jl)) but to my eyes, they are either very old (10+ years!) and don't support modern Julia, don't support
shrinking or don't really compose their generators well, due to being based on QuickCheck. PropCheck.jl, while certainly taking inspiration from QuickCheck, is using a mixed approach,
focusing on integrated shrinking. This has advantages and disadvantages, but from my experience with the package so far, the current architecture is pretty extensible and works much
better than a plain implementation of QuickCheck (Julia is much less focused on types than Haskell is, after all; much of the information we have about a type is implicit & not guaranteed,
and even with that, some type based shrinks are just plain bad, due to even their types not capturing the full semantics of the produced values). Most of the features currently in
PropCheck.jl came about because I ran into an issue that I wanted to solve when testing a different codebase - a workflow I don't expect to change too much in the future.
