using Random: Random

struct Integrated{T,F}
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

################################################
# utility for working with integrated generators
################################################

const iBool = Integrated(Manual(Generator(Bool)))
iWord(hi) = Integrated(mWord(hi))

freeze(i::Integrated{T,F}) where {T,F} = Generator{T}(i.gen)
# TODO: check if this should just produce the root continously instead
dontShrink(i::Integrated{Tree{T},F}) where {T,F} = Generator{Tree{T}}(rng -> root(i.gen(rng)))
dependent(g::Generator{Tree{T},F}) where {T,F} = Integrated{Tree{T},F}(g.gen)

"""
    map(f, i::Integrated)

Maps `f` lazily over all elements in `i`, producing a new tree.
"""
function PropCheck.map(f, gen::Integrated{T,F}, mapType::Type{Tree{_T}}=eltype(gen)) where {T,F,_T}
    function genF(rng)
        map(f, generate(rng, freeze(gen)))
    end
    dependent(Generator{mapType}(genF))
end
PropCheck.map(f, gen::Integrated, mapType::Type{T}) where {T} = map(f,  gen, Tree{T})

# we are Applicative with this
function PropCheck.map(funcs::Integrated{Tree{F}}, gen::Integrated{Tree{T}}) where {T,F}
    genF(rng) = interleave(generate(funcs, rng), generate(gen, rng))
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
function Base.filter(p, genA::Integrated{T,F}, trim=false) where {T,F}
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

function listAux(genLen::Integrated, genA::Integrated{T}) where {T}
    n = dontShrink(genLen)
    genF(rng) = [ generate(rng, freeze(genA)) for _ in 1:generate(rng, n) ]
    Generator{Vector{Tree{T}}}(genF)
end

function vector(genLen, genA::Integrated{T,F}) where {T,F}
    function genF(rng)
        treeVec = generate(rng, listAux(genLen, genA))
        interleave(treeVec)
    end
    gen = Generator{Tree{Vector{eltype(T)}}}(genF)
    dependent(gen)
end

function arrayAux(genLen::I, genA::Integrated{T}) where {T, I}
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

function tupleAux(genLen::Integrated, genA::Integrated{T}) where {T}
    n = dontShrink(genLen)
    genF(rng) = ntuple(_ -> generate(rng, freeze(genA)), generate(rng, n))
    Generator{NTuple{N, Tree{T}} where N}(genF)
end

"""
    tuple(genLen, genA)

Generates a tuple of a generated length, using the elements produced by `genA`.
"""
function tuple(genLen, genA::Integrated{T,F}) where {T,F}
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
function str(genLen, alphabet::Integrated=isample(typemin(Char):"\xf7\xbf\xbf\xbf"[1]))
    map(join, vector(genLen, alphabet))
end
