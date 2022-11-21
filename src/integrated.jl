using Random: Random

struct Integrated{T,F}
    gen::F
end
function Integrated(m::Generator{T,F}, s=shrink) where {T,F}
    gen(rng) = unfold(Shuffle ∘ s, generate(rng, m))
    Integrated{Tree{T},typeof(gen)}(gen)
end
function Integrated(el::T, s=shrink) where T
    gen(_) = unfold(Shuffle ∘ s, el)
    Integrated{Tree{T},typeof(gen)}(gen)
end
Integrated(::Type{T}) where T = Integrated(Generator(T))
generate(rng, i::Integrated) = i.gen(rng)

function Base.iterate(g::Integrated, rng=default_rng())
    el = generate(rng, g)
    el === nothing && return nothing
    (el, rng)
end
Base.IteratorEltype(::Type{<:Integrated}) = Base.HasEltype()
Base.IteratorSize(::Type{<:Integrated}) = Base.SizeUnknown()
Base.eltype(::Type{Integrated{T,F}}) where {T,F} = T

################################################
# utility for working with integrated generators
################################################

const iBool = Integrated(Generator(Bool))
iWord(hi) = Integrated(mWord(hi))

freeze(i::Integrated{T,F}) where {T,F} = Generator{T}(i.gen)
# TODO: check if this should just produce the root continously instead
dontShrink(i::Integrated{T,F}) where {T,F} = Generator{T}((rng) -> root(i.gen(rng)))
dependent(g::Generator{T,F}) where {T,F} = Integrated{T,F}(g.gen)

function listAux(genLen::Integrated, genA::Generator{T, F}) where {T, F}
    n = dontShrink(genLen)
    genF(rng) = [ generate(rng, genA) for _ in 1:generate(rng, n) ]
    Generator{Vector{T}}(genF)
end
listAux(genLen, genA::Integrated) = listAux(genLen, freeze(genA))
listAux(genLen, genA) = listAux(Integrated(genLen), genA)

# TODO: this should be possible to make more generic
function vector(genLen, genA::Integrated{T,F}) where {T,F}
    genF(rng) = interleave(generate(rng, listAux(genLen, genA)))
    gen = Generator{Vector{eltype(T)}}(genF)
    dependent(gen)
end

"""
    tuple(genLen, genA)

Generates a tuple of a generated length, using the elements produced by `genA`.
"""
function tuple(genLen, genA::Integrated{T,F}) where {T,F}
    genF(rng) = interleave((generate(rng, listAux(genLen, genA))...,))
    gen = Generator{NTuple{N, eltype(T)} where N}(genF)
    dependent(gen)
end

"""
    str(len[, alphabet])

Generates a string using the given `genLen` as a generator for the length.
The default alphabet is `typemin(Char):"\xf7\xbf\xbf\xbf"[1]`, which is all
representable `Char` values. The alphabet is passed directly to `Random.randstring`.
"""
function str(genLen, alphabet::Integrated=igen(typemin(Char):"\xf7\xbf\xbf\xbf"[1]))
    map(join, vector(genLen, alphabet))
end

function interleave(integrated::Integrated...)
    T = typeof(map((root ∘ generate), integrated))
    genF(rng) = interleave(map(i -> generate(rng, i), integrated))
    gen = Generator{Tree{T}}(genF)
    dependent(gen)
end

"""
    map(f, i::Integrated)

Maps `f` lazily over all elements in `i`, producing a new tree.
"""
function PropCheck.map(f, gen::Integrated{T,F}, mapType::Type{_T}=eltype(gen)) where {T,F,_T}
    function genF(rng)
        map(f, generate(rng, freeze(gen)))
    end
    dependent(Generator{Tree{_T}}(genF))
end

"""
    filter(p, i::Integrated[, trim=false])

Filters `i` lazily such that all elements contained fulfill the predicate `p`, i.e. all elements for which `p` is `false` are removed.

`trim` controls whether subtrees are removed completely when the root doesn't
fulfill the predicate or whether only that root should be skipped, still trying to
shrink its subtrees. This trades performance (less shrinks to check) for quality
(fewer/less diverse shrink values tried).
"""
function Base.filter(p, genA::Integrated{T,F}, trim=false) where {T,F}
    function genF(rng)
        element = iterate(filter(p, generate(rng, freeze(genA)), trim))
        element === nothing && return nothing
        return first(element)
    end
    gen = Generator{Union{Nothing, T}}(genF)
    dependent(gen)
end
