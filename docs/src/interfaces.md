# Interfaces

PropCheck.jl provides a number of interfaces to hook into with your code. Some of these are more
robust than others, while some are likely to change in the future. Nevertheless, they
are documented here in order to facilitate experimentation, as well as gathering feedback
on how well they work and where they have missing functionality/aren't clear enough, before an
eventual 1.0 version release.

## `AbstractIntegrated{T}`

```@docs
PropCheck.AbstractIntegrated
```

## `ExtentIntegrated{T}`

```@docs
PropCheck.ExtentIntegrated
```

## Generation & Shrinking

```@docs
PropCheck.shrink
PropCheck.generate
```

## `itype`

```@docs
PropCheck.itype
```

In order to hook into the generation provided by `itype`, define [`generate`](@ref) for your type `T`.

Generally speaking, `generate` should always produce the full set of possible values of a type.

Be sure to also define a shrinking function for your type, by adding a method to [`shrink`](@ref).