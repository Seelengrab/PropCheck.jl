# FAQ

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
