# PropCheck.jl

[![CI Stable](https://github.com/Seelengrab/PropCheck.jl/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/Seelengrab/PropCheck.jl/actions/workflows/ci.yml)
[![CI Nightly](https://github.com/Seelengrab/PropCheck.jl/actions/workflows/nightly.yml/badge.svg?branch=main)](https://github.com/Seelengrab/PropCheck.jl/actions/workflows/nightly.yml)
[![docs-stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://seelengrab.github.io/PropCheck.jl/stable)
[![docs-dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://seelengrab.github.io/PropCheck.jl/dev)
[![codecov](https://codecov.io/github/Seelengrab/PropCheck.jl/branch/main/graph/badge.svg?token=8IJ4R0KB82)](https://codecov.io/github/Seelengrab/PropCheck.jl)

A simple, thin package for property based testing. 

## Maintenance only

PropCheck.jl is in _maintenance mode_ which means that no new features will be added.
Bugs that compromise the intended behavior that pop up will continue to be fixed (if sufficiently feasible).
For future development of property based testing, as well as better performance,
consider using [Supposition.jl](https://github.com/Seelengrab/Supposition.jl) instead.

This package is now intended to serve as an example for how a Haskell project deeply
relying on lazy evaluation and type classes could be ported to Julia (thought it may
not necessarily be a _good_ example for that ;) ).

## Installation

This package is registered with General, so to install do

```julia
pkg> add PropCheck
```

PropCheck.jl currently supports Julia versions 1.6 and up. CI runs on nightly and is expected to pass, but no guarantee about stability on unreleased versions of Julia is given.

Please check out the [documentation](https://seelengrab.github.io/PropCheck.jl/) to learn how you can use PropCheck.jl to fuzz your code.
