using Random: Random, shuffle
using RequiredInterfaces

"""
    AbstractIntegrated{T}

Abstract supertype for all integrated shrinkers.
The `T` type parameter describes the kinds of objects generated by this integrated shrinker.
This is usually going to be a [`Tree`](@ref) of objects.

Required methods:

  * `generate(rng::AbstractRNG, ::A) where A <: AbstractIntegrated`
  * `freeze(::A) where A <: AbstractIntegrated`

Fallback definitions:

  * `Base.IteratorEltype -> Base.HasEltype()`
  * `Base.IteratorSize -> Base.SizeUnknown()`
  * `Base.eltype -> T`
  * `Base.iterate(::AbstractIntegrated, rng=default_rng())`
    * Requires `generate`
"""
abstract type AbstractIntegrated{T} end
@required AbstractIntegrated begin
    generate(::AbstractRNG, ::AbstractIntegrated)
    freeze(::AbstractIntegrated)
end

"""
    freeze(::T) where T <: AbstractIntegrated -> T

"Freezes" an `AbstractIntegrated` by returning a new object that has a `generate` method,
and can be wrapped in a new integrated shrinker.
"""
freeze(::AbstractIntegrated)

function Base.iterate(g::AbstractIntegrated, rng=default_rng())
    el = generate(rng, g)
    el === nothing && return nothing
    (el, rng)
end
Base.IteratorEltype(::Type{<:AbstractIntegrated}) = Base.HasEltype()
Base.IteratorSize(::Type{<:AbstractIntegrated}) = Base.SizeUnknown()
Base.eltype(::Type{<:AbstractIntegrated{T}}) where T = T

#######
# Unassuming Integrated
#######

"""
    InfiniteIntegrated{T} <: AbstractIntegrated{T}

Abstract supertype for all integrated shrinkers that provide infinite generation of elements.

Fallback definitions:
    * `Base.IteratorSize(::Type{<:InfiniteIntegrated}) = Base.IsInfinite()`

Overwriting `Base.IteratorSize` for subtypes of this type is disallowed.
"""
abstract type InfiniteIntegrated{T} <: AbstractIntegrated{T} end
Base.IteratorSize(::Type{<:InfiniteIntegrated}) = Base.IsInfinite()

"""
    Integrated{T} <: InfiniteIntegrated{T}

A naive integrated shrinker, only providing extremely basic functionality for
generating and shrinking [`Tree`](@ref)s. Default fallback if no other, more
specialized type exists.

!!! warning "Pending Redesign"
    This type is likely going to be redesigned in the future. Methods constructing it
    are not stable, and may be removed at any point.
"""
struct Integrated{T,F} <: InfiniteIntegrated{T}
    gen::F
end
function Integrated(m::Manual{T}, s=m.shrink) where {T}
    g = m.gen
    gen(rng) = unfold(Shuffle ∘ s, generate(rng, g))
    treeType = integratorType(T)
    Integrated{treeType,typeof(gen)}(gen)
end
function Integrated(m::Generator{T,F}, s=shrink) where {T,F}
    gen(rng) = unfold(Shuffle ∘ s, generate(rng, m))
    treeType = integratorType(T)
    Integrated{treeType,typeof(gen)}(gen)
end
function Integrated(el::Tree{T}) where T
    gen = Returns(el)
    treeType = integratorType(T)
    Integrated{treeType,typeof(gen)}(gen)
end

function integratorType(u::Union)
    types = getSubtypes(u)
    Union{(Tree{T} for T in types)...}
end
integratorType(::Type{T}) where T = Tree{T}

generate(rng::AbstractRNG, i::Integrated{T}) where T = i.gen(rng)

function Base.show(io::IO, i::Integrated{T}) where T
    print(io, "Integrated{", T, "}(", i.gen, ")")
end

"""
    ExtentIntegrated{T} <: InfiniteIntegrated{T}

An integrated shrinker which has bounds. The bounds can be accessed with the `extent` function
and are assumed to have `first` and `last` method defined for them.

Required methods:

  * `extent(::ExtentIntegrated)`
"""
abstract type ExtentIntegrated{T} <: InfiniteIntegrated{T} end
@required ExtentIntegrated extent(::ExtentIntegrated)

"""
    extent(::ExtentIntegrated) -> Tuple{T,T} where T

Gives a tuple of the upper & lower bound of this `ExtentIntegrated`.
"""
extent(::ExtentIntegrated)

"""
    IntegratedRange{T,R,G,F} <: ExtentIntegrated{T}

An integrated shrinker describing a range of values.

The values created by this shrinker shrink according to the given shrinking function.
The shrinking function must ensure that the produced values are always contained within the bounds
of the given range.
"""
struct IntegratedRange{T,R,G,F} <: ExtentIntegrated{T}
    bounds::R
    gen::G
    function IntegratedRange(bounds::R, gen, shrink::F) where {R <: AbstractRange,F}
        igen = Integrated(gen, shrink)
        new{Tree{eltype(R)}, R, typeof(igen), F}(bounds, igen)
    end
end
generate(rng::AbstractRNG, i::IntegratedRange) = generate(rng, i.gen)
extent(ir::IntegratedRange) = (first(ir.bounds), last(ir.bounds))

function Base.show(io::IO, it::IntegratedRange{T, R}) where {T,R}
    print(io, "IntegratedRange(", it.bounds, ", ", it.gen, ")")
end

"""
    IntegratedConst{T,R,G} <: ExtentIntegrated{T}

An integrated shrinker describing a constant. The shrinker will always produce that value, which
doesn't shrink.
"""
struct IntegratedConst{T,R} <: ExtentIntegrated{T}
    bounds::R
    function IntegratedConst(c::T) where T
        new{Tree{T}, T}(c)
    end
end
freeze(ic::IntegratedConst) = ic
generate(_::AbstractRNG, i::IntegratedConst) = Tree(i.bounds)
extent(ir::IntegratedConst) = (ir.bounds, ir.bounds)

function Base.show(io::IO, ic::IntegratedConst{T}) where T
    print(io, "IntegratedConst(", ic.bounds, ")")
end

"""
    IntegratedUnique(vec::Vector{ElT}[, shrink=shrink::S]) where {ElT,S}
    IntegratedUnique{T,ElT,S} <: InfiniteIntegrated{T}

An integrated shrinker, taking a vector `vec`. The shrinker will produce all unique values of `vec`
in a random order before producing a value it returned before. The values produced by this shrinker
shrink according to `shrink`.
"""
mutable struct IntegratedUnique{T,ElT,S} <: InfiniteIntegrated{T}
    els::Vector{ElT}
    cache::Vector{ElT}
    @constfield shrink::S

    function IntegratedUnique(vec::Vector{T}, shrink::S=shrink) where {T,S}
        treeType = integratorType(T)
        els = shuffle(vec)
        cache = sizehint!(similar(els, 0), length(els))
        new{treeType,T,S}(els, cache, shrink)
    end
end

function Base.show(io::IO, iu::IntegratedUnique{T,E,S}) where {T,E,S}
    print(io, "IntegratedUnique(", union(iu.els, iu.cache), ", ", iu.shrink, ")")
end

function generate(rng::AbstractRNG, i::IntegratedUnique)
    el = popfirst!(i.els)
    push!(i.cache, el)
    if isempty(i.els)
        # swap, so we're not wasteful with memory
        i.els, i.cache = i.cache, i.els
        shuffle!(rng, i.els)
    end
    unfold(Shuffle ∘ i.shrink, el)
end

function freeze(i::IntegratedUnique{T,ElT}) where {T,ElT}
    niu = IntegratedUnique(ElT[], i.shrink)
    niu.els = copy(i.els)
    niu.cache = copy(i.cache)
    niu
end

"""
    IntegratedVal(val::V, shrink::S) where {V,S}
    IntegratedVal{T,V,S} <: InfiniteIntegrated{T}

An integrated shrinker, taking a value `val`. The shrinker will always produce `val`, which
shrinks according to `shrink`.

If `V <: Number`, shrinking functions given to this must produce values in

 * `[typemin(V), v]` if `v > zero(V)`
 * `[v, typemax(V)]` if `v < zero(V)`
 * no values if `iszero(v)`

This shrinker supports `extent` out of the box if `V <: Number`. For other types, you need
to define `extent(::IntegratedVal{Tree{T}})`
"""
struct IntegratedVal{T,V,S} <: ExtentIntegrated{T}
    val::V
    shrink::S
    function IntegratedVal(v::V, s::S=shrink) where {V,S}
        new{Tree{V},V,S}(v, s)
    end
end

generate(_::AbstractRNG, iv::IntegratedVal) = unfold(Shuffle ∘ iv.shrink, iv.val)
freeze(i::IntegratedVal) = i
function extent(iv::IntegratedVal{Tree{T}}) where T<:Number
    iszero(iv.val) && return (zero(T), zero(T))
    if iv.val < zero(T)
        return (iv.val, typemax(T))
    else
        return (typemin(T), iv.val)
    end
end

function Base.show(io::IO, iv::IntegratedVal)
    print(io, "IntegratedVal(", iv.val, ", ", iv.shrink, ")")
end

"""
    FiniteIntegrated{T} <: AbstractIntegrated{T}

An integrated shrinker producing only a finite number of elements.

 * `Base.IteratorSize(::FiniteIntegrated)` must return a `Base.HasLength()` or `Base.HasShape`.
   * `length(::T)` needs to be implemented for your `T <: FiniteIntegrated`; there is no fallback.
   * If your `T <: FiniteIntegrated` has a shape, return that from `IteratorSize` instead & implement `size` as well.

Once the integrated generator is exhausted, `generate(::FiniteIntegrated)` will return `nothing`.
"""
abstract type FiniteIntegrated{T} <: AbstractIntegrated{T} end
Base.IteratorSize(::Type{<:FiniteIntegrated}) = Base.HasLength()
freeze(fi::FiniteIntegrated) = deepcopy(fi)

"""
    IntegratedOnce(el[, shrink=shrink])
    IntegratedOnce{T} <: FiniteIntegrated{T}

An integrated shrinker that produces a shrink tree with the value `el` at its root exactly once.
Afterwards, the integrated shrinker produces `nothing`.
"""
mutable struct IntegratedOnce{T, ElT, S} <: FiniteIntegrated{T}
    @constfield el::ElT
    @constfield shrink::S
    done::Bool
    function IntegratedOnce(el::T, shrink::S=shrink) where {T,S}
        new{integratorType(T), T, S}(el, shrink, false)
    end
end
Base.length(::IntegratedOnce) = 1

function generate(::AbstractRNG, oi::IntegratedOnce)
    oi.done && return nothing
    oi.done = true
    unfold(Shuffle ∘ oi.shrink, oi.el)
end

function Base.show(io::IO, iio::IntegratedOnce)
    print(io, "IntegratedOnce(", iio.el, ", ", iio.shrink, ", ", iio.done, ")")
end

"""
    IntegratedFiniteIterator(itr[, shrink=shrink])
    IntegratedFiniteIterator{T} <: FiniteIntegrated{T}

An integrated shrinker taking arbitrary iterables that have a length or a shape. Once the iterator is
exhausted, the integrated shrinker produces `nothing`.

The values produced by this integrated shrinker shrink according to the given shrinking function.
"""
mutable struct IntegratedFiniteIterator{T,I,S,IS} <: FiniteIntegrated{T}
    @constfield itr::I
    @constfield shrink::S
    state::IS
    function IntegratedFiniteIterator(itr::I, shrink::S=shrink) where {I,S}
        !(Base.IteratorSize(I) isa Base.HasLength ||
            Base.IteratorSize(I) isa Base.HasShape) &&
            throw(ArgumentError("The given iterator does not have a finite length!"))
        itr isa AbstractIntegrated && throw(ArgumentError("`IntegratedFiniteIterator` cannot iterate an `$I`!"))
        state = iterate(itr)
        new{integratorType(eltype(I)), I, S, Union{Nothing, typeof(state)}}(itr, shrink, state)
    end
end
Base.IteratorSize(fii::IntegratedFiniteIterator) = Base.IteratorSize(fii.itr)
Base.size(fii::IntegratedFiniteIterator) = if Base.IteratorSize(fii.itr) isa Base.HasShape
    size(fii.itr)
else
    throw(ArgumentError("The iterator wrapped by this `FiniteIteratorIntegrated` does not have a shape!"))
end
Base.length(fii::IntegratedFiniteIterator) = length(fii.itr)
Base.isdone(fii::IntegratedFiniteIterator) = isnothing(fii.state)

function generate(_::AbstractRNG, fii::IntegratedFiniteIterator{T}) where T
    fii.state isa Nothing && return nothing
    el, nstate = fii.state
    fii.state = iterate(fii.itr, nstate)
    unfold(Shuffle ∘ fii.shrink, el)
end

function Base.show(io::IO, ifi::IntegratedFiniteIterator)
    Base.print(io, "IntegratedFiniteIterator(", ifi.itr, ", ", ifi.shrink, ")")
end

"""
    ChainIntegrated(is::AbstractIntegrated...)
    ChainIntegrated{Eltype, N, Is, Finite} where {Eltype, N,
                                            Is <: NTuple{N, <:AbstractIntegrated}, Finite} <: AbstractIntegrated{Eltype}

An integrated shrinker chaining together a number of given integrated shrinkers, producing the values
they generate one after another.

All except the last argument must have some finite length, meaning the integrated shrinker must subtype [`FiniteIntegrated`](@ref).
Only the last integrated shrinker is allowed to be only `<: InfiniteIntegrated`.

The values produced by this integrated shrinker shrink according to the shrinking function given to the shrinker that originally
produce them.

The `Finite` type parameter is a `Bool`, indicating whether this `IntegratedChain` is finite or not.
"""
mutable struct IntegratedChain{T, N, Is <: NTuple{N, AbstractIntegrated}, Finite} <: AbstractIntegrated{T}
    index::Int
    @constfield chain::Is

    function IntegratedChain(is::AbstractIntegrated...)
        start = is[begin:end-1]
        all(start) do i
            i isa FiniteIntegrated
        end || throw(ArgumentError("Only the last argument to `ChainIntegrated` is allowed to not have a length!"))
        T = Union{eltype.(is)...}
        Is = Tuple{typeof.(is)...}
        new{T, length(is), Is, last(is) isa FiniteIntegrated}(firstindex(is), is)
    end
end
Base.isdone(ci::IntegratedChain) = ci.index > lastindex(ci.chain)
freeze(ci::IntegratedChain) = deepcopy(ci)
Base.IteratorSize(ic::IntegratedChain{T, N, Is, true}) where {T,N,Is}  = Base.HasLength()
Base.IteratorSize(ic::IntegratedChain{T, N, Is, false}) where {T,N,Is} = Base.IsInfinite()
Base.length(ic::IntegratedChain{T, N, Is, true}) where {T,N,Is}        = sum(length, ic.chain)

function generate(rng::AbstractRNG, ci::IntegratedChain)
    while true
        # we exhausted all integrated shrinkers
        Base.isdone(ci) && return nothing
        integrated = ci.chain[ci.index]
        ret = generate(rng, integrated)
        if ret isa Nothing
            # the integrated shrinker was exhausted, so try the next one
            ci.index += 1
            continue
        else
            return ret
        end
    end
end

function Base.show(io::IO, ic::IntegratedChain)
    print(io, "IntegratedChain(")
    for i in ic.chain
        print(io, i)
        i != last(ic.chain) && print(io, ", ")
    end
    print(io, ")")
end

"""
    IntegratedLengthBounded(is::AI, bound::Integer) where {T, AI <: AbstractIntegrated{T}}
    IntegratedLengthBounded{T, AbstractIntegrated{T}} <: FiniteIntegrated{T}

An integrated shrinker bounding the number of values generated by the passed integrated shrinker.
This has the ability to transform any [`AbstractIntegrated`](@ref) into a [`FiniteIntegrated`](@ref).

The given bound must be a positive value. If a `fi::FiniteIntegrated` is given as the integrated shrinker,
the bound is chosen to be `min(length(fi), bound)`.

The values produced by this integrated shrinker shrink according to the shrinking function given to the original
integrated shrinker wrapped by `IntegratedLengthBounded`.
"""
mutable struct IntegratedLengthBounded{T, I} <: FiniteIntegrated{T}
    curcount::Int
    @constfield bound::Int
    @constfield integrated::I
    function IntegratedLengthBounded(int::AbstractIntegrated{T}, bound::Integer) where T
        bound < 0 && throw(ArgumentError("Given bound must be a positive number!"))
        new{T, typeof(int)}(1, convert(Int, bound), int)
    end
    function IntegratedLengthBounded(int::FiniteIntegrated{T}, bound::Integer) where T
        bound = min(bound, length(int))
        bound < 0 && throw(ArgumentError("Given bound must be a positive number!"))
        new{T, typeof(int)}(1, convert(Int, bound), int)
    end
end
Base.length(ilb::IntegratedLengthBounded) = ilb.bound
Base.isdone(ilb::IntegratedLengthBounded) = ilb.curcount > ilb.bound

function generate(rng::AbstractRNG, ilb::IntegratedLengthBounded)
    Base.isdone(ilb) && return nothing
    ilb.curcount += 1
    generate(rng, ilb.integrated)
end

function Base.show(io::IO, ilb::IntegratedLengthBounded)
    print(io, "IntegratedLengthBounded(", ilb.integrated, ", ", ilb.bound, ")")
end

"""
    IntegratedChoice(is::AbstractIntegrated...)
    IntegratedChoice{T} <: AbstractIntegrated{T}

An integrated shrinker for generating a value from one of any number of given `AbstractIntegrated`.
The choice is taking uniformly random. No consideration for repeats is taken.

Is `<: AbstractIntegrated{T}`, but can behave (except for dispatch) like a `FiniteIntegrated`, if all
given `AbstractIntegrated` are `FiniteIntegrated`.
"""
struct IntegratedChoice{T, Is, Finite} <: AbstractIntegrated{T}
    gens::Is
    choicelist::Vector{Int}
    function IntegratedChoice(is::AbstractIntegrated...)
        start = is[begin:end-1]
        Finite = all(start) do i
            i isa FiniteIntegrated
        end
        T = Union{eltype.(is)...}
        Is = Tuple{typeof.(is)...}
        new{T, Is, Finite}(is, collect(eachindex(is)))
    end
end
freeze(ci::IntegratedChoice) = deepcopy(ci)
Base.IteratorSize(ic::IntegratedChoice{T, Is, true}) where {T,Is}  = Base.HasLength()
Base.IteratorSize(ic::IntegratedChoice{T, Is, false}) where {T,Is} = Base.IsInfinite()
Base.length(ic::IntegratedChoice{T, Is, true}) where {T, Is} = minimum(length, ic.gens)
Base.isdone(ic::IntegratedChoice{T, Is, true}) where {T, Is} = all(isdone, ic.gens)
Base.isdone(ic::IntegratedChoice{T, Is, false}) where {T, Is} = false

function generate(rng::AbstractRNG, ic::IntegratedChoice)
    while !Base.isdone(ic)
        idx = rand(rng, eachindex(ic.choicelist))
        gen = ic.gens[ic.choicelist[idx]]
        res = generate(rng, gen)
        if res === nothing
            # this generator has been exhausted, remove it so we don't try it in the future
            deleteat!(ic.choicelist, idx)
            continue
        else
            return res
        end
    end
    return nothing
end

function Base.show(io::IO, ilb::IntegratedChoice)
    print(io, "IntegratedChoice(", ilb.gens, ")")
end

"""
    IntegratedBoundedRec{T}(maxrec)
    IntegratedBoundedRec(maxrec, ai::AbstractIntegrated)
    IntegratedBoundedRec{T} <: AbstractIntegrated{T}

An `AbstractIntegrated` for allowing mutual recursion between two `AbstractIntegrated`.
Used by inserting as a shim into one `AbstractIntegrated`, creating a second `AbstractIntegrated`
and setting the second one as `bind!(::IntegratedBoundedRec, ::AbstractIntegrated)` of the shim afterwards.

!!! note "Mutual recursion"
    This type is for allowing mutual recursion between two (or more) different integrated shrinkers.
    Selfrecursion could also be done through this, but is likely to be more efficient when implemented
    explicitly (or bounded through other means), due to the need for type instability on self recursion
    as a result of how this type is implemented.

!!! warn "Experimental"
    This integrated shrinker is very experimental, and some uses still don't work correctly. If possible,
    try to avoid the kind of mutually recursive generation this would enable.
"""
mutable struct IntegratedBoundedRec{T} <: AbstractIntegrated{T}
    @constfield maxrec::Int
    currec::Int
    ai::AbstractIntegrated{<:T}
    IntegratedBoundedRec{T}(maxrec) where T = new{Tree{<:T}}(maxrec, 0)
    IntegratedBoundedRec(maxrec, ai::G) where {T, G<:AbstractIntegrated{T}} = new{T}(maxrec, 0, ai)
end

"""
    bind!(ibr::IntegratedBoundedRec{T}, ai::AbstractIntegrated{T})

Binds the given `AbstractIntegrated` to `ibr`, such that it will be called for generation when
`generate(ibr)` is called.

This needs to be called to allow mutual recursion during generation.
"""
bind!(ibr::IntegratedBoundedRec{T}, ai::AbstractIntegrated) where T = ibr.ai = ai

function generate(rng::AbstractRNG, ibr::IntegratedBoundedRec)
    ibr.currec >= ibr.maxrec && return nothing
    ibr.currec += 1
    res = generate(rng, ibr.ai)
    ibr.currec -= 1
    res
end
freeze(ibr::IntegratedBoundedRec) = ibr

function Base.show(io::IO, ibr::IntegratedBoundedRec)
    print(io, "IntegratedBoundedRec(", ibr.maxrec, ", ")
    if isdefined(ibr, :ai)
        print(io, ibr.ai)
    else
        print(io, "#undef")
    end
    print(io, ")")
end

################################################
# utility for working with integrated generators
################################################

freeze(i::InfiniteIntegrated{T}) where {T} = Generator{T}(i.gen)
dontShrink(i::AbstractIntegrated{T}) where {T} = Generator{T}(rng -> root(generate(rng, i)))
dependent(g::Generator{T,F}) where {T,F} = Integrated{T,F}(g.gen)

"""
    map(f, i::AbstractIntegrated) -> AbstractIntegrated

Maps `f` lazily over all elements in `i`, producing an `AbstractIntegrated` generating the mapped values.
"""
function PropCheck.map(f::F, gen::AbstractIntegrated{T}) where {T, F}
    rettypes = Base.promote_op(f, unpackTreeUnion(T)...)
    mapType = integratorType(rettypes)
    function genF(rng)
        val = generate(rng, freeze(gen))
        val === nothing && return val
        map(f, val)
    end
    dependent(Generator{mapType}(genF))
end

unpackTreeUnion(::Type{Tree{T}}) where T = (T,)
function unpackTreeUnion(::Type{T}) where T
    !(T isa Union) && return (T,)
    (unpackTreeUnion(T.a)..., unpackTreeUnion(T.b)...)
end

# we are Applicative with this
function PropCheck.map(funcs::AbstractIntegrated{Tree{F}}, gen::AbstractIntegrated{Tree{T}}) where {T,F}
    genF(rng) = interleave(generate(rng, funcs), generate(rng, gen))
    rootF = root(generate(funcs))
    retT = Base.promote_op(rootF, T)
    Integrated{Tree{retT}, typeof(genF)}(genF)
end

"""
    filter(p, i::AbstractIntegrated[, trim=false]) -> AbstractIntegrated

Filters `i` lazily such that all elements contained fulfill the predicate `p`, i.e. all elements for which `p` is `false` are removed.

`trim` controls whether subtrees are removed completely when the root doesn't
fulfill the predicate or whether only that root should be skipped, still trying to
shrink its subtrees. This trades performance (less shrinks to check) for quality
(fewer/less diverse shrink values tried).
"""
function Base.filter(p, genA::AbstractIntegrated{T}, trim=false) where {T}
    function genF(rng)
        while true
            val = generate(rng, freeze(genA))
            val === nothing && return nothing
            local element = iterate(filter(p, val, trim))
            element !== nothing && return first(element)
        end
    end
    gen = Generator{T}(genF)
    dependent(gen)
end

######################
# Creating specific `Integrated`
#####################

function listAux(genLen::ExtentIntegrated{W}, genA::AbstractIntegrated{T}) where {W, T}
    n = dontShrink(genLen)
    function genF(rng)
        f = freeze(genA)
        [ generate(rng, f) for _ in 1:generate(rng, n) ]
    end
    Generator{Vector{Tree{T}}}(genF)
end

"""
    PropCheck.vector(genLen::ExtentIntegrated, genA::AbstractIntegrated{Tree{T}}) where T

A utility function for creating an integrated shrinker producing `Vector{T}`, with its length
controlled by the number generated from `genLen` and its elements created by `genA`.

This is generally the best way to create a shrinkable vector, as it takes shrinking both length &
elements into account, irrespective of shrinking order.

!!! note "FiniteIntegrated"
    Using a `FiniteIntegrated{T}` for the elements will cause the vector to have `Union{Nothing, T}`
    as its `eltype` in the general case, because they may stop generating `T` at any point!
"""
function vector(@nospecialize(genLen::ExtentIntegrated), genA::AbstractIntegrated{T}) where {T}
    vecType = genA isa FiniteIntegrated ? Union{Nothing, eltype(T)} : eltype(T)
    function genF(rng)
        while true
            treeVec = generate(rng, listAux(genLen, genA))
            # TODO: this filtering step is super ugly. It would be better to guarantee not to
            # generate incorrect lengths in the first place.
            intr = interleave(treeVec)
            flat = filter(intr, true) do v
                length(v) >= first(extent(genLen))
            end
            ret = iterate(flat)
            ret !== nothing && return first(ret)
        end
    end
    gen = Generator{Tree{Vector{vecType}}}(genF)
    dependent(gen)
end

function arrayAux(genLen::AbstractIntegrated, genA::AbstractIntegrated{T}) where {T}
    n = dontShrink(genLen)
    function genF(rng)
        arrsize = generate(rng, n)
        frozen = freeze(genA)
        arr = Array{T}(undef, arrsize...)
        for idx in eachindex(arr)
            arr[idx] = generate(rng, frozen)
        end
        arr
    end
    Generator{Array{Tree{T}, N} where N}(genF)
end

"""
    PropCheck.array(genSize::AbstractIntegrated, genA::AbstractIntegrated{Tree{T}}) where T

A utility function for creating an integrated shrinker producing `Array{T, N}`, with its size
controlled by the tuple generated from `genLen` and its elements created by `genA`.
If `genSize` produces an integer instead of a tuple of integers, this function will produce a `Vector` instead.

This is generally the best way to create a shrinkable array, as it takes shrinking both size &
elements into account, irrespective of shrinking order.

!!! note "FiniteIntegrated"
    Using a `FiniteIntegrated{T}` for the elements will cause the array to have `Union{Nothing, T}`
    as its `eltype`, because they may stop generating `T` at any point!
"""
function array(genSize::AbstractIntegrated{Tree{TP}}, genA::AbstractIntegrated{Tree{T}}) where {T, TP <: NTuple}
    function genF(rng)
        treeArr = generate(rng, arrayAux(genSize, genA))
        interleave(treeArr)
    end
    arrType = genA isa FiniteIntegrated ? Union{Nothing, eltype(T)} : eltype(T)
    # what a horrible hack
    gen = Generator{Tree{Array{arrType, length(TP.parameters)}}}(genF)
    dependent(gen)
end
array(genSize::AbstractIntegrated{Tree{T}}, genA) where T <: Integer = vector(genSize, genA)

function tupleAux(genLen::AbstractIntegrated, genA::AbstractIntegrated{T}) where {T}
    n = dontShrink(genLen)
    function genF(rng)
        fA = freeze(genA)
        ntuple(_ -> generate(rng, fA), generate(rng, n))
    end
    Generator{NTuple{N, Tree{T}} where N}(genF)
end

"""
    tuple(genLen::AbstractIntegrated, genA::AbstractIntegrated)

Generates a tuple of a generated length, using the elements produced by `genA`.

!!! note "FiniteIntegrated"
    Using a `FiniteIntegrated{T}` will cause the tuple to have `Union{Nothing, T}`
    as its `eltype`, because they may stop generating `T` at any point!

!!! warning "Type stability"
    Due to the length produced by `genLen` not being known until runtime, this function is by its
    very nature type unstable. Consider using `interleave` and a fixed number of known generators instead.
"""
function tuple(genLen::AbstractIntegrated, genA::AbstractIntegrated{Tree{T}}) where {T}
    genF(rng) = interleave(generate(rng, tupleAux(genLen, genA)))
    tupType = genA isa FiniteIntegrated ? Union{Nothing, T} : T
    gen = Generator{Tree{NTuple{N, tupType} where N}}(genF)
    dependent(gen)
end

"""
    str(len::ExtentIntegrated[, alphabet::AbstractIntegrated])

Generates a string using the given `genLen` as a generator for the length.
The default alphabet is `typemin(Char):"\xf7\xbf\xbf\xbf"[1]`, which is all
representable `Char` values.
"""
function str(genLen::ExtentIntegrated, alphabet::AbstractIntegrated=isample(typemin(Char):"\xf7\xbf\xbf\xbf"[1]))
    map(join, vector(genLen, alphabet))
end

function interleave(intr::AbstractIntegrated...)
    rettuple = Tree{Tuple{eltype.(eltype.(intr))...}}
    function gen(rng)
        trees = generate.(rng, intr)
        any(isnothing, trees) && return nothing
        interleave(trees)
    end
    ret = Integrated{rettuple, typeof(gen)}(gen)

    # The interleaving is done, but can we guarantee something about the interwoven generation?
    # This optimizes away, since it all only deals with things inferable from types :)
    anyFinite = any(intr) do i
        i isa FiniteIntegrated
    end
    if anyFinite
        maxlen = foldl(intr; init=typemax(Int)) do prev, i
            min(prev, i isa FiniteIntegrated ? length(i) : typemax(Int))
        end
        IntegratedLengthBounded(ret, maxlen)
    else
        return ret
    end
end