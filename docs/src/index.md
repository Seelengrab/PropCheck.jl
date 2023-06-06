# PropCheck.jl Documentation

This is the documentation for *PropCheck.jl*, a property based testing framework loosely inspired by QuickCheck & Hedgehog.

It features integrated shrinkers, which can smartly shrink initial failures to smaller examples while preserving
the invariants the original input was generated under.

Check out the Examples to get an introduction to property based testing and to learn how to write your own tests!

```@contents
Pages = ["index.md", "intro.md", "Examples/basic.md", "Examples/structs.md", "Examples/containers.md", "Examples/properties.md"]
Depth = 3
```

## Goals

 * Good performance
   * A test framework should not be the bottleneck of the testsuite.
 * Composability
   * It should not be required to modify an existing codebase to accomodate PropCheck.jl
   * PropCheck.jl should merely be a way of writing some tests for arbitrary functions, not something you need to integrate into your code.
 * Reusability
   * It should be possible to reuse large parts of the existing definitions for Base to build custom integrated shrinkers/generators

## Limitations

 * Due to threading being a hard problem, I have not yet looked into parallelizing the running of PropCheck.jl.
   * I think something like this should be handled by the test runner, not PropCheck.jl.
   * This might also interfere with threading in the code-to-be-tested.
 * PropCheck.jl (currently) cannot test temporal properties (well).
   * It's not impossible to do so, but since PropCheck is not an intrusive testing framework, it has no control over how long tasks take to run, whether they throw spurious errors etc.
   * I would like to be able to test that as well, but this is (currently) out of scope.

## Planned Features

 * Reflection on methods, for creating arbitrary generators from function definitions
 * Reintroducing generation of `Any`
 * Better handling of errors during generation of values
   * Perhaps there's a way to automatically detect error paths and skip generating values that would lead to an error?
 * Better handling of errors during testing
   * It would be great if we could shrink on the specific type & message of an error as well
   * Right now, all failures due to an error assume all errors are the same
 * Better way to define default generators
   * Right now, an `itype(Int)` assumes all `Int`s are equally important - this is not always the case
   * Integers that are branched on that are close to the critical edge when a condition in that branch flips from `true` to `false` are usually more interesting, but that's not knowable just from `itype(Int)` itself.
   * I'd call such a generator "function aware" or "function integrated".
   * This extends to all kinds of properties, like the length of an array, whether a field in some object is set or not etc.
   * This is a very difficult problem, so please don't expect anything of the sort anytime soon. It's just a thought stuck in my head.