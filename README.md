# PropCheck.jl

A simple, thin package for property based testing. This package, though functional, is WIP and has some very rough edges. Improvements and suggestions are welcome, but please check the TODO below for what's already planned.

## Installation

This package is not yet registered with METADATA, so to install do

```julia
pkg> add https://github.com/Seelengrab/PropCheck.jl.git
```

## Usage

First define a property you want to test, which for PropCheck.jl means defining a function which takes some arguments, checks that property against the arguments and returns a boolean indicating whether the property holds or not.

For example for addition:

```julia
# The function we want to test for some property:
function add(x::Int, y::Int)
    return x+y
end

# The commutative property for addition:
function commProp(x::Int, y::Int)
    c = add(x,y)
    d = add(y,x)
    return c == d
end
```

In order to test this property, the `@check` macro is provided:

```julia
julia> using PropCheck

julia> @check commProp (Int, Int)
Test Summary: | Pass  Total
commProp: ✓   |    1      1
```

Note the tuple provided after the name of the property - it defines the argument types of the generated values to test the given function with.

If you have more than one property to test, you can simply nest the `@check` calls into another testset from e.g. `Test`:

```julia
julia> function identProp(x::Int)
           x + 0 == 0 + x
       end

julia> using Test

julia> @testset "Nested Tests" begin
           @check commProp (Int, Int)
           @check identProp (Int,)
       end
Test Summary: | Pass  Total
Nested Tests  |    2      2
```

For the `identProp` property, note the single argument. In order to convey this to PropCheck, pass a single value tuple.

Failing properties will be displayed as well:

```julia
julia> brokenProp(::Int, ::Int) = false
brokenProp (generic function with 1 method)

julia> @testset "A broken test" begin
           @check commProp (Int, Int)
           @check identProp (Int,)
           @check brokenProp (Int, Int)
       end
brokenProp: [0, 0]: Test Failed at [...]
  Expression: res
Stacktrace:
    [...]
Test Summary:        | Pass  Fail  Total
A broken test        |    2     1      3
  commProp: ✓        |    1            1
  identProp: ✓       |    1            1
  brokenProp: [0, 0] |          1      1
```

Note the `[0,0]` indicating for which input the property doesn't hold. By default, some special values are generated for numeric types. Should a type not support generation, an error will be thrown indicating so. After the special types are tested, 100 random instances will be generated and tested. there is no "shrinking" of failed cases. Errors occuring during testing are considered a failure and are printed together with the case which produced the error. This does not stop checking of the remaining properties, but does prevent further checks of the same property.

## ToDo

In no particular order:

 * Clean up the printing of test cases (custom testset?)
 * Finish reflection of argument types on properties
   * Make it type stable
 * Make special case generation type-stable
 * Define more generators for types from Base, e.g. `Char` and `String`
 * Better value generation
   * Provide a way to exclude certain values and/or ranges of values
   * Provide a way to pass "must-check" values or ranges of values
   * Provide a way to set a custom number of randomly generated values