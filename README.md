# PropCheck.jl

[![CI Stable](https://github.com/Seelengrab/PropCheck.jl/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/Seelengrab/PropCheck.jl/actions/workflows/ci.yml)
[![CI Nightly](https://github.com/Seelengrab/PropCheck.jl/actions/workflows/nightly.yml/badge.svg?branch=main)](https://github.com/Seelengrab/PropCheck.jl/actions/workflows/nightly.yml)
[![docs-stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://seelengrab.github.io/PropCheck.jl/stable)
[![docs-dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://seelengrab.github.io/PropCheck.jl/dev)
[![codecov](https://codecov.io/github/Seelengrab/PropCheck.jl/branch/main/graph/badge.svg?token=8IJ4R0KB82)](https://codecov.io/github/Seelengrab/PropCheck.jl)

A simple, thin package for property based testing. 
For a look at what's already planned in the future, take a look at the [`feature`](https://github.com/Seelengrab/PropCheck.jl/issues?q=is%3Aissue+is%3Aopen+label%3Afeature) label in the issues.

## Installation

This package is registered with General, so to install do

```julia
pkg> add PropCheck
```

PropCheck.jl currently supports Julia versions 1.6 and up. CI runs on nightly and is expected to pass, but no guarantee about stability on unreleased versions of Julia is given.

Please check out the [documentation](https://seelengrab.github.io/PropCheck.jl/) to learn how you can use PropCheck.jl to fuzz your code.
