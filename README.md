# PropCheck.jl

[![CI Stable](https://github.com/Seelengrab/PropCheck.jl/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/Seelengrab/PropCheck.jl/actions/workflows/ci.yml)
[![CI Nightly](https://github.com/Seelengrab/PropCheck.jl/actions/workflows/nightly.yml/badge.svg?branch=main)](https://github.com/Seelengrab/PropCheck.jl/actions/workflows/nightly.yml)
[![docs-stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://seelengrab.github.io/PropCheck.jl/stable)
[![docs-dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://seelengrab.github.io/PropCheck.jl/dev)
[![codecov](https://codecov.io/github/Seelengrab/PropCheck.jl/branch/main/graph/badge.svg?token=PBH8NJCHKS)](https://codecov.io/github/Seelengrab/PropCheck.jl)

A simple, thin package for property based testing. This package, though functional, is WIP and has some very rough edges. Improvements and suggestions are welcome, but please check the TODO below for what's already planned.

## Installation

This package is not yet registered with General, so to install do

```julia
pkg> add https://github.com/Seelengrab/PropCheck.jl.git
```

## Usage

This package is undergoing a major rewrite, but for now you can use it like this:

```julia
using PropCheck

# define a custom property, in this case returning a closure
# that checks whether its argument is less than 5
# properties have to return a Bool
lessThan5 = <(5)

# define a generator, using e.g. the convenient `itype`
# this here defines an integrated generator for types, like UInt8
gen = itype(UInt8)

# optionally enable debug printing for output during the shrinking process
# ENV["JULIA_DEBUG"] = PropCheck

# check the property
check(lessThan5, gen)
```

Output:

```julia
# this will of course be different for each run, as a random one is drawn
┌ Info: Found counterexample for 'Base.Fix2{typeof(<), Int64}(<, 5)', beginning shrinking...
└   t = Tree(80)
10-element Vector{UInt8}: # this vector contains a list of all shrunk values
 0x50
 0x4f
 0x27
 0x13
 0x12
 0x11
 0x0f
 0x0b
 0x0a
 0x05
```

As you can see, the last value is the smallest value that's _not_ less than (i.e., greater or equal to) `5` - which is `5`.

## ToDo

These are written down here instead of in issues because they're very generic goals and usually don't directly have an actionable task associated with them.

In no particular order:

 * Clean up the printing of test cases (custom testset?)
 * ~~Define more generators for types from Base, e.g. `Char` and `String`~~
 * ~Improve shrinking for types which already have a generator defined~
 * ~Make it possible to `generate(Union{Int,Float64})`~
