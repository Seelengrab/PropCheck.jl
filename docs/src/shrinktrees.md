# Shrinking with `Tree`s

In the examples we've learnt about various integrated shrinkers. So how does this work
under the hood?

When we `generate` a value from an integrated shrinker, we get some `Tree` out, not the value directly:

```@repl  generateTree
using PropCheck
nums = PropCheck.isample(1:3);
t = generate(nums)
```

`Tree` is the main object doing the heavy lifting behind the scenes - all [`PropCheck.AbstractIntegrated`](@ref)
create these objects. A `Tree` is nothing more than a lazy representation of a root and its shrunk values.
You can think of a `Tree` as a tree with one element at the root, and zero to $$n$$ values as its children.
As the name suggests, we can take a look at these shrink trees with `AbstractTrees`:

```@repl generateTree
using AbstractTrees
print_tree(t)
```

On the left hand side up top we can see our generated root - the initial value `3`. One layer to the
right, we can see the first level of shrinks of `3`. These values have been produced by the default
shrinking function `shrink` that is passed to `isample` - they observe the property that their absolute
value is strictly less than the value of our root, in order to guarantee that their shrunk values
in turn don't ever generate the original value (in this case, `3`) again. In addition, the default shrinking
function also guarantees that the shrunk values are larger than the minimum of the given range; hence,
the smallest number that can be generated is `1`.

The magic behind PropCheck.jl is in this `Tree` object, which is heavily inspired by the [Hedgehog 
Haskell library](https://hedgehog.qa) for property based testing.

Under the hood, this is what PropCheck.jl manipulates. When you `filter` an integrated shrinker,
you implicitly `filter` the `Tree` produced by the shrinker:

```@repl generateTree
t = generate(filter(iseven, PropCheck.ival(3)))
print_tree(t)
```

and when you `map` over an integrated shrinker, you `map` over the `Tree` it produces:

```@repl generateTree
t = generate(map(sqrt∘Complex, nums))
print_tree(t)
```

When searching for a counterexample, PropCheck.jl first generates a number of possible roots, and when
one of those roots makes your property fail, it tries to find a smaller (i.e., a shrunk) value that still
reproduces the same failure. Those shrunk values all originate from the `Tree` spun out by repeatedly expanding
the root of the `Tree`, according to the `map`, `filter`, generating constraints of the integrated shrinkers
and the shrinking functions associated with them.

It's important to keep this shrink `Tree` in mind when generating - the larger the tree is you span out
with evermore complex generation, the harder it can be for PropCheck.jl to find the smaller counterexamples
you're looking for.
