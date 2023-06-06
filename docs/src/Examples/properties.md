# Complex generation

I've mentioned in the last section how we need `tuple` and `vector` to generate tuples and vectors of values respectively.
In this chapter, we'll use these to build a slightly more complex example.

Let's take a look at a more complicated object and an associated function, like this one for example:

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
grade = map(Base.splat(Pair), PropCheck.interleave(itype(String), isample(0:100))) # random subject, with points in 0:100
gradegen = map(Base.splat(Dict{String,Int}), PropCheck.tuple(isample(1:10), grade))
```

!!! info "Different ranges"
	`isample(2:10, PropCheck.shrinkTowards(2))` gives us an integrated shrinker producing elements in the range `2:10`. They'll shrink towards `2`.

Now to our student:

```@example student
students = map(Base.splat(Student), PropCheck.interleave(itype(String), itype(Int), gradegen))
check(passes, students)
```

And we can see that just generic shrinking produced the minimal student that doesn't pass. A nameless, ageless student
who received no points on two subjects. Note that due to us using a dictionary (which forces unique keys), the two subjects
have different names!

PropCheck tries to be fast when it can, so this reduction barely took any time:

```@example student
pairs(@timed @time check(passes, students))
```

Let's say now that we expect our students to be between `10-18` years old, have a name consisting of `5-20` lowercase ASCII
letters and having between 5 and 10 subjects of `5-15` lowercase ASCII letters. We could build them like this:

```@example student
subj_name = PropCheck.str(isample(5:15), isample('a':'z'))
grade = map(Base.splat(Pair), PropCheck.interleave(subj_name, isample(0:100))) # random subject, with points in 0:100
gradegen = map(Base.splat(Dict{String,Int}), PropCheck.vector(isample(5:10), grade))
stud_name = PropCheck.str(isample(5:20), isample('a':'z')) # we don't want names shorter than 5 characters
stud_age = isample(10:18) # our youngest student can only be 10 years old
students = map(Base.splat(Student), PropCheck.interleave(stud_name, stud_age, gradegen))
collect(Iterators.take(students, 5))
```

which will preserve the invariants described during generation when shrinking:

```@example student
check(passes, students)
```

The student returned has a name with 5 characters, is 10 years old, has taken two distinct subjects and received 0 points
in both of them. We can do much better if we modify our generators a bit, at the cost of having a smaller pool of possible tests:

```@example student
# sample their classes
subj_name = isample(["Geography", "Mathematics", "English", "Arts & Crafts", "Music", "Science"], PropCheck.noshrink)

# random subject, with points in 0:100
grade = map(Base.splat(Pair), PropCheck.interleave(subj_name, isample(0:100)))

# generate their grades
gradegen = map(Base.splat(Dict{String,Int}), PropCheck.vector(isample(5:10), grade))

# give them a name that doesn't vanish
stud_name = isample(["Alice", "Bob", "Claire", "Devon"], PropCheck.noshrink)

# our youngest student can only be 10 years old
stud_age = isample(10:18)

# create our students
students = map(Base.splat(Student), PropCheck.interleave(stud_name, stud_age, gradegen))

# and check that not all students pass
using Test
try # hide
@testset "All students pass" begin
    @test check(passes, students)
end
catch # hide
end # hide
```

!!! note "Dictionaries"
    While this example directly splats a vector into the `Dict{String,Int}` constructor, this is in general
    not optimal. `Dict` will delete previously set values if a key is duplicated, so it's usually better to
    generate a list of unique keys first, which is then combined with a seperately generated list of values.
    In order to generate that list of unique keys, you can use [`iunique`](@ref).

!!! note "Test stdlib and `@test`"
    Currently, `check` returns the minimized failing testcase, so that `@test` displays that the test has
    evaluated to a non-Boolean. This is suboptimal and misuses the `@test` macro. In the future, this may
    be replaced by a `@check` macro, which creates a custom `TestSet` for recording what kind of failure was
    experienced.
