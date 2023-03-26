# PropCheck.jl Documentation

This is the documentation for *PropCheck.jl*, a property based testing framework loosely inspired by QuickCheck & Hedgehog.

It features integrated shrinkers, which can smartly shrink initial failures to smaller examples while preserving
the invariants the original input was generated under.

Check out the Examples to get an introduction to property based testing and to learn how to write your own tests!

```@contents
Pages = ["intro.md", "Examples/basic.md", "Example/properties.md"]
```
