# PropCheck.jl

A simple, thin package for property based testing. This package, though functional, is WIP and has some very rough edges. Improvements and suggestions are welcome, but please check the TODO below for what's already planned.

## Installation

This package is not yet registered with General, so to install do

```julia
pkg> add https://github.com/Seelengrab/PropCheck.jl.git
```

## Usage

First define a property you want to test, which for PropCheck.jl means defining a function, checks that property and returns a boolean indicating whether the property holds or not.

For example for addition:

```julia
# The function we want to test for some property:
function add(x::Int, y::Int)
    return x+y
end

# The commutative property for addition:
function commProp()
    @forall((generate(Int),generate(Int)), (x,y) -> begin
      c = add(x,y)
      d = add(y,x)
      return c == d
    end)
end
```

In order to test this property, the `@check` macro is provided:

```julia
julia> using PropCheck

julia> @check commProp
Test Summary: | Pass  Total
commProp: ✓   |    1      1
```

If you have more than one property to test, you can simply nest the `@check` calls into another testset from e.g. `Test`:

```julia
julia> function identProp()
           @forall(generate(Int), x -> x + 0 == 0 + x)
       end

julia> using Test

julia> @testset "Nested Tests" begin
           @check commProp
           @check identProp
       end
Test Summary: | Pass  Total
Nested Tests  |    2      2
```

Failing properties will be displayed as well:

```julia
julia> brokenProp() = @forall(generate(Int), _ -> false)
brokenProp (generic function with 1 method)

julia> @testset "A broken test" begin
           @check commProp
           @check identProp
           @check brokenProp
       end
brokenProp: 152341: Test Failed at [...]
  Expression: res
Stacktrace:
    [...]
Test Summary:        | Pass  Fail  Total
A broken test        |    2     1      3
  commProp: ✓        |    1            1
  identProp: ✓       |    1            1
  brokenProp: 152341 |          1      1
```

Note the `152341`, indicating for which input the property doesn't hold. By default, most basic types have a generic generator defined. Should a type not support generation, PropCheck will fall back to generating via reflection of the fields of the type. If the types doesn't support the default constructor, you will have to define a `PropCheck.generate` method for your type. Generating `Any` is supported, but be warned that this _will_ give you an instance of any known type that can be generated without errors as well as kill any hopes of working inference.

Once a falsifying example has been found, PropCheck tries to shrink it to a minimal example. Arrays shrink towards the empty array, numbers shrink towards zero, tuples only shrink their elements. If you want to customise shrinking for your type, define `PropCheck.shrink` for your type.

Errors occuring during testing are considered a failure and are printed together with the case which produced the error. This does not stop checking of the remaining properties, but does prevent further checks of the same property.

## ToDo

In no particular order:

 * Clean up the printing of test cases (custom testset?)
 * Define more generators for types from Base, e.g. `Char` and `String`
 * Make it possible to `generate(Union{Int,Float64})`