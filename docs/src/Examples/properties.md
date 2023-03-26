# Complex generation

I've mentioned in the last section how we need `tuple` and `vector` to generate tuples and vectors of values respectively. In this chapter
we'll see why that is and how we can build our own custom integrated shrinkers.

Let's say we have a function that expects to only be passed even numbers, else we error:

```@example even_numbers
using PropCheck # hide

function myfunc(x)
    # x should be odd
    isodd(x) || error("even!")
    return "odd!"
end
```

Now suppose we want to test these possibilities seperately - how do we get a generator that only produces even and odd values respectively?

PropCheck.jl provides a few facilities for this, simplest of all are `filter` and `map`:

```@example even_numbers
even_nums_filt = filter(iseven, igen(Int8))
[ t for t in Iterators.take(even_nums_filt, 5) ]
```
```@example even_numbers
triple_nums = map(x -> x % 3, igen(Int8))
# due to the nature of random generation, there may not be a Tree(2) here
[ t for t in Iterators.take(triple_nums, 5) ]
```

Both `map` and `filter` on an integrated generator return another integrated generator - everything is handled lazily.

Keen eyes notice that we can iterate over integrated generators, which gives us a [`PropCheck.Tree`](@ref). Instead of
expanding a full tree of possible subsequent shrink values, we get a lazily computed representation of all possible values.
This is crucial for performance, as well as to keep the invariants of which objects we want to generate and what initial
properties we want to have for them.

One important difference between `filter` and `map` is the amount of valid test cases we generate. If we're unlucky, `filter`
may filter out too many potential inputs, leaving us with nothing to test. In contrast, `map` will always give us a valid
object by transforming a (potentially invalid) input into a valid one. In general, `filter` should be preferred if there's no
known transform from an invalid input to a valid one and the majority of inputs is valid in the first place. `filter` also
has the additional downside of introducing a potential type instability, since it's possible that no input was valid, thus
returning `nothing`.

For the function above, both approaches can work:

```@example even_numbers
function myfunc_prop(x)
    myfunc(x) == "odd!"
end

even_nums_map = map(x -> div(2*x, 2), igen(Int8))
check(myfunc_prop, even_nums_filt)
```
```@example even_numbers
check(myfunc_prop, even_nums_map)
```

Both checks sucessfully shrunk their failing testcases to the smallest even number that throws the exception - `0`!
If we input odd numbers instead, the test passes:

```@example even_numbers
odd_numbers_filt = filter(isodd, igen(Int8))
check(myfunc_prop, odd_numbers_filt)
```
```@example even_numbers
odd_numbers_map = map(x -> x + iseven(x), igen(Int8))
check(myfunc_prop, odd_numbers_map)
```

Now let's take a look at a more complicated object and an associated function, like this one for example:

```@example student
using PropCheck # hide

struct Student
   name::String
   age::Int
   grades::Dict{String,Int} # subject => points
end

"""
    passes(s::Student)

Checks whether a student passes this grade. At most one subject may have a failing grade with less than 51 points.
"""
function passes(s::Student)
    count(<(51), values(s.grades)) <= 1
end
```

First, we're going to need a custom generator for our grades:

```@example student
grade = map(Base.splat(Pair), PropCheck.interleave(igen(String), igen(0:100))) # random subject, with points in 0:100
gradegen = map(Base.splat(Dict), PropCheck.tuple(igen(1:10), grade))
```

!!! info "Different ranges"
	`igen(2:10)` gives us an integrated shrinker producing elements in the range `2:10`. They'll shrink towards `2`.

Now to our student:

```@example student
students = map(Base.splat(Student), PropCheck.interleave(igen(String), igen(Int), gradegen))
check(passes, students)
```

And we can see that just generic shrinking produced the minimal student that doesn't pass. A nameless, ageless student
who got no points on two subjects. Note that due to us using a dictionary (which forces unique keys), the two subjects
have different names!

PropCheck tries to be fast when it can, so this reduction barely took any time:

```@example student
pairs(@timed check(passes, students))
```

Let's say now that we expect our students to be between `10-18` years old, have a name consisting of `5-20` lowercase ASCII
letters and having between 5 and 10 subjects of `5-15` lowercase ASCII letters. We could build them like this:

```@example student
subj_name = PropCheck.str(igen(5:15), igen('a':'z'))
grade = map(Base.splat(Pair), PropCheck.interleave(subj_name, igen(0:100))) # random subject, with points in 0:100
gradegen = map(Base.splat(Dict), PropCheck.tuple(igen(5:10), grade))
stud_name = PropCheck.str(igen(5:20), igen('a':'z')) # we don't want names shorter than 5 characters
stud_age = igen(10:18) # our youngest student can only be 10 years old
students = map(Base.splat(Student), PropCheck.interleave(stud_name, stud_age, gradegen))
[ s for s in Iterators.take(students, 5) ]
```

which will preserve the invariants described during generation when shrinking:

```@example student
check(passes, students)
```
