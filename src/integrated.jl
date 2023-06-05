using Random: Random

abstract type AbstractIntegrated{T} end

struct Integrated{T,F} <: AbstractIntegrated{T}
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

function Base.iterate(g::Integrated, rng=default_rng())
    el = generate(rng, g)
    el === nothing && return nothing
    (el, rng)
end
Base.IteratorEltype(::Type{<:Integrated}) = Base.HasEltype()
Base.IteratorSize(::Type{<:Integrated}) = Base.SizeUnknown()
Base.eltype(::Type{Integrated{T,F}}) where {T,F} = T

generate(rng, i::Integrated{T}) where T = i.gen(rng)

"""
    ExtentIntegrated{T} <: AbstractIntegrated{T}

An integrated shrinker which has a bounds. The bounds can be accessed with the `extent` function.
"""
abstract type ExtentIntegrated{T} <: AbstractIntegrated{T} end

"""
    IntegratedRange{T,R,G,F} <: ExtentIntegrated{T}

An integrated shrinker describing a range of values.

The values created by this shrinker shrink according to the given shrinking function.
The shrinking function must ensure that the produce values are always contained within the bounds
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
generate(rng, i::IntegratedRange) = generate(rng, i.gen)
Base.iterate(g::IntegratedRange, rng=default_rng()) = iterate(g.gen, rng)
Base.IteratorEltype(::Type{<:IntegratedRange}) = Base.HasEltype()
Base.IteratorSize(::Type{<:IntegratedRange}) = Base.SizeUnknown()
Base.eltype(::Type{<:IntegratedRange{T}}) where T = T
extent(ir::IntegratedRange) = (first(ir.bounds), last(ir.bounds))

"""
    IntegratedConst{T,R,G} <: ExtentIntegrated{T}

An integrated shrinker describing a constant. The shrinker will always produce that value, which
doesn't shrink.
"""
struct IntegratedConst{T,R,G} <: ExtentIntegrated{T}
    bounds::R
    gen::G
    function IntegratedConst(c::T) where T
        gen = Integrated(Tree(c))
        new{Tree{T}, T, typeof(gen)}(c, gen)
    end
end
generate(rng, i::IntegratedConst) = generate(rng, i.gen)
Base.iterate(g::IntegratedConst, rng=default_rng()) = iterate(g.gen, rng)
Base.IteratorEltype(::Type{<:IntegratedConst}) = Base.HasEltype()
Base.IteratorSize(::Type{<:IntegratedConst}) = Base.SizeUnknown()
Base.eltype(::Type{<:IntegratedConst{T}}) where T = T
extent(ir::IntegratedConst) = (ir.bounds, ir.bounds)

################################################
# utility for working with integrated generators
################################################

freeze(i::AbstractIntegrated{T}) where {T} = Generator{T}(i.gen)
dontShrink(i::AbstractIntegrated{T}) where {T} = Generator{T}(rng -> root(generate(rng, i.gen)))
dependent(g::Generator{T,F}) where {T,F} = Integrated{T,F}(g.gen)

"""
    map(f, i::Integrated)

Maps `f` lazily over all elements in `i`, producing a new tree.
"""
function PropCheck.map(f, gen::AbstractIntegrated{Tree{T}}) where {T}
    mapType = integratorType(Union{Base.return_types(f, (T,))...})
    function genF(rng)
        map(f, generate(rng, freeze(gen)))
    end
    dependent(Generator{mapType}(genF))
end

# we are Applicative with this
function PropCheck.map(funcs::AbstractIntegrated{Tree{F}}, gen::AbstractIntegrated{Tree{T}}) where {T,F}
    genF(rng) = interleave(generate(rng, funcs), generate(rng, gen))
    rootF = root(generate(funcs))
    retT = reduce(typejoin, Base.return_types(rootF, (T,)))
    Integrated{Tree{retT}, typeof(genF)}(genF)
end

"""
    filter(p, i::Integrated[, trim=false])

Filters `i` lazily such that all elements contained fulfill the predicate `p`, i.e. all elements for which `p` is `false` are removed.

`trim` controls whether subtrees are removed completely when the root doesn't
fulfill the predicate or whether only that root should be skipped, still trying to
shrink its subtrees. This trades performance (less shrinks to check) for quality
(fewer/less diverse shrink values tried).
"""
function Base.filter(p, genA::AbstractIntegrated{T}, trim=false) where {T}
    function genF(rng)
        while true
            local element = iterate(filter(p, generate(rng, freeze(genA)), trim))
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

function vector(genLen::ExtentIntegrated, genA::AbstractIntegrated{T}) where {T}
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
            ret !== nothing && return first(ret)::Tree{Vector{eltype(T)}}
        end
    end
    gen = Generator{Tree{Vector{eltype(T)}}}(genF)
    dependent(gen)
end

function arrayAux(genLen::ExtentIntegrated, genA::Integrated{T}) where {T}
    n = dontShrink(genLen)
    function genF(rng)
        s = generate(rng, n)
        arr = Array{T}(undef, s...)
        for idx in eachindex(arr)
            arr[idx] = generate(rng, freeze(genA))
        end
        arr
    end
    Generator{Array{Tree{T}, N} where N}(genF)
end

array(genSize::Integrated{Tree{T}}, genA) where T <: Integer = array(PropCheck.tuple(iconst(0x1), genSize), genA)
function array(genSize::Integrated{Tree{TP}}, genA::Integrated{T,F}) where {T,F, TP <: NTuple}
    function genF(rng)
        treeArr = generate(rng, arrayAux(genSize, genA))
        interleave(treeArr)
    end
    # what a horrible hack
    gen = Generator{Tree{Array{eltype(T), length(TP.parameters)}}}(genF)
    dependent(gen)
end

function tupleAux(genLen::AbstractIntegrated, genA::AbstractIntegrated{T}) where {T}
    n = dontShrink(genLen)
    genF(rng) = ntuple(_ -> generate(rng, freeze(genA)), generate(rng, n))
    Generator{NTuple{N, Tree{T}} where N}(genF)
end

"""
    tuple(genLen, genA)

Generates a tuple of a generated length, using the elements produced by `genA`.
"""
function tuple(genLen::AbstractIntegrated, genA::AbstractIntegrated{T}) where {T}
    genF(rng) = interleave(generate(rng, tupleAux(genLen, genA)))
    gen = Generator{Tree{NTuple{N, eltype(T)} where N}}(genF)
    dependent(gen)
end

"""
    str(len[, alphabet])

Generates a string using the given `genLen` as a generator for the length.
The default alphabet is `typemin(Char):"\xf7\xbf\xbf\xbf"[1]`, which is all
representable `Char` values. 
"""
function str(genLen::ExtentIntegrated, alphabet::AbstractIntegrated=isample(typemin(Char):"\xf7\xbf\xbf\xbf"[1]))
    map(join, vector(genLen, alphabet))
end

function interleave(intr::AbstractIntegrated...)
    rettuple = Tree{Tuple{eltype.(eltype.(intr))...}}
    gen(rng) = interleave(generate.(rng, intr))
    Integrated{rettuple, typeof(gen)}(gen)
end