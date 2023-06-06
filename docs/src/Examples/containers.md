# Generating Containers

So far we've only looked at generating objects from their types or simple structs, but this can become difficult when we're
trying to generate more complicated objects like tuples or arrays with a generated size. After all, there
is not a unique vector with a fixed length that has the type `Vector{Int}`, for example - all vectors containing
`Int`, regardless of their length, have the same type. A similar thing is true for tuples if we don't know
their length ahead of time and we want to generate that length as well.

## Generating tuples

We're going to start by generating homogenous tuples of things. PropCheck.jl provides a convenience function for this:
[`PropCheck.tuple(n, gen)`](@ref).

Consider this property:

```@example tuple
using PropCheck

prop(x) = all(<(5), x)
```

This property tests whether all elements of the argument are smaller than `5`.

In order to test that all tuples we can conceivably think of obey this property (or produce a counterexample!),
we use `tuple`. Its first argument is a generator for a number to use as the length, and the second argument
a generator for the objects contained within the tuple. The simplest generator for a length is a generator
that just returns its given argument, called [`iconst`](@ref):

```@repl tuple
const_sized_tuple = PropCheck.tuple(iconst(3), itype(Int8));
tree = generate(const_sized_tuple)
```

And indeed, the generated size of the tuple is `3`. Checking the values this tree shrinks to, we can see that they too are of size `3`:

```@repl tuple
all(t -> length(root(t)) == 3, subtrees(tree))
using Random: shuffle!
shuffle!(collect(subtrees(tree)))[1:5]
```

I'm only showing a subset of all generated subtrees because the full list is quite long. Nevertheless, if we put our generator into
`check` to test our property:

```@example tuple
check(prop, const_sized_tuple)
```

PropCheck.jl successfully reduces the first failing test case to one where no elements can be shrunk further without making the test pass,
giving us our smallest possible counterexample - a tuple with all zeros, except for one place which has `5` instead. There are
three of these minimal cases for `prop`: `(5,0,0)`, `(0,5,0)` and `(0,0,5)`. In general, there may be much more than these three minimal cases,
and yet again more cases that are not minimal at all.

### Variable size tuples

You may notice that the tuple is always of size 3, never smaller - the reasoning for this behavior is twofold:

 1. Tuples generally don't change their size - they are immutable containers, and as such manipulating them will create a new tuple altogether.
 2. Tuples are created during generation when you require a constant number of things, but want to still shrink the things themselves.

But what if we truly do want to generate tuples of various sizes, for example because we want to test some recursive reduction over them?

This too is simple - we only have to change the generator passed into `tuple` to one that can produce multiple distinct values, like [`isample`](@ref):

```@repl vartup
using PropCheck # hide
variable_size_tuple = PropCheck.tuple(isample(0:10), itype(Int8));
[ generate(variable_size_tuple) for _ in 1:5 ]
```

## Generating vectors

Similar to tuples, there is also `PropCheck.vector(n, gen)` to get a generator which generates `Vector`s of `n` elements:

```@repl examplevec
using PropCheck
vec = PropCheck.vector(iconst(3), itype(Int8));
```

Which we can then run against the `prop` from earlier:

```jldoctest examplevec; filter = [r"\[ Info: \d+", r" \d", r"[└│]\s+-?\d+"], setup=:(using PropCheck; vec = PropCheck.vector(iconst(3), itype(Int8)))
julia> prop(x) = all(<(5), x)
prop (generic function with 1 method)

julia> check(prop, vec)
┌ Info: Found counterexample for 'prop', beginning shrinking...
│   Counterexample =
│    3-element Vector{Int8}:
│     -62
│      57
└      81
[ Info: 7 counterexamples found
3-element Vector{Int8}:
 0
 0
 5
```

though for a `Vector`, a constant size of `3` is of course not minimal. We can do better here, by allowing the vector to shrink its length. There are multiple options for achieving this:

 * [`isample`](@ref), which samples from a collection `v`
 * [`ival`](@ref), which always produces the same value (like `iconst`), but allows it to shrink

The former is mostly useful when we don't care about the exact element we generate, but would like it to be from some defined collection of values, while the latter is useful when we want
to start out with some value, but are fine with shrinks of that value as well. `isample` has the additional ability to limit values generated from a range to stay limited to that range.

For example, if we use `ival(3)` for the length of our vector:

```@repl examplevec
valvec = PropCheck.vector(ival(3), itype(Int8));
[ generate(valvec) for _ in 1:5 ]
```

We can see that they all start out as vectors of length `3`, but their subtrees can be smaller too:

```@repl examplevec
subs = collect(subtrees(generate(valvec)));
filter(v -> length(root(v)) < 3, subs)
```

If we use `isample` instead of `ival`, we can see that, just as with tuples, the initial value has a size depending on what we sampled from:

```@repl examplevec
samplevec = PropCheck.vector(isample(0:5), itype(Int8));
[ generate(samplevec) for _ in 1:5 ]
```

and subsequently, the minimal counterexample also changes, to the vector containing nothing but `5`:

```jldoctest examplevec; filter=[r"(\[ Info: \d+)",r"[┌│└]\s+-?\d+"], setup=:(using PropCheck; valvec = PropCheck.vector(ival(3), itype(Int8)); samplevec=PropCheck.vector(isample(0:5), itype(Int8)))
julia> check(prop, valvec; show_initial=false)
[ Info: Found counterexample for 'prop', beginning shrinking...
[ Info: 7 counterexamples found
1-element Vector{Int8}:
 5

julia> check(prop, samplevec; show_initial=false)
[ Info: Found counterexample for 'prop', beginning shrinking...
[ Info: 9 counterexamples found
1-element Vector{Int8}:
 5
```
