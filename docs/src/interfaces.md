# Interfaces

PropCheck.jl provides a number of interfaces to hook into with your code. Some of these are more
robust than others, while some are likely to change in the future. Nevertheless, they
are documented here in order to facilitate experimentation, as well as gathering feedback
on how well they work and where they have missing functionality/aren't clear enough, before an
eventual 1.0 version release.

The interfaces mentioned on this page are intended for user-extension, in the manner described.
Overloading the functions in a different way or assuming more of an interface than is guaranteed
is not supported.

For the abstract-type based interfaces `AbstractIntegrated` and `ExtentIntegrated`, you can use
the API provided by [RequiredInterfaces.jl](https://github.com/Seelengrab/RequiredInterfaces.jl)
to check for compliance, if you want to provide a custom integrated shrinker.

## `AbstractIntegrated{T}`

```@docs
PropCheck.AbstractIntegrated
```

`AbstractIntegrated` is the most unassuming integrated shrinker type, requiring little more than
defining `generate`. `generate` on an `AbstractIntegrated` is, in the current design, only going
to return `Tree`s (and others are unlikely to work/not supported by the rest of the package), but
that's not technically necessary. A more sophisticated generation process than the implicit & lazy
unfolding of a tree could share subtrees, which would be more like a lazy graph. While technically
possible, this is not currently planned.

## `ExtentIntegrated{T}`

```@docs
PropCheck.ExtentIntegrated
```

`ExtentIntegrated` extends the `AbstractIntegrated` interface by a single method - [`PropCheck.extent`](@ref).
Its purpose is simple - values produced by an `ExtentIntegrated` are expected to fall within a given
ordered set, with a maximum and a minimum, which is what is returned by `extent`.

## Generation & Shrinking

These two functions are required if you want to customize shrinking & type-based generation.
It's certainly not necessary to implement these to work with most features of this package,
but they are required if you want to customize what kinds of object [`itype`](@ref) returns.

```@docs
PropCheck.shrink
PropCheck.generate
```

### `itype`

```@docs
PropCheck.itype
```

In order to hook into the generation provided by `itype`, define [`generate`](@ref) for your type `T`.

Generally speaking, `generate` should always produce the full set of possible values of a type.

Be sure to also define a shrinking function for your type, by adding a method to [`shrink`](@ref).