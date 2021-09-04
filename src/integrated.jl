using Random: Random

struct Integrated{T,F}
    gen::F
end
function Integrated(m::Generator{T,F}) where {T,F}
    gen(rng) = unfold(shrink, generate(rng, m))
    Integrated{Tree{T},typeof(gen)}(gen)
end
function Integrated(el::T) where T
    gen(_) = unfold(shrink, el)
    Integrated{Tree{T},typeof(gen)}(gen)
end
Integrated(::Type{T}) where T = Integrated(Generator(T))
generate(rng, i::Integrated) = i.gen(rng)

const iBool = Integrated(Generator(Bool))
iWord(hi) = Integrated(mWord(hi))

freeze(i::Integrated{T,F}) where {T,F} = Generator{T}(i.gen)
# TODO: check if this should just produce the root continously instead
dontShrink(i::Integrated{T,F}) where {T,F} = Generator{T}((rng) -> root(i.gen(rng)))
dependent(g::Generator{T,F}) where {T,F} = Integrated{T,F}(g.gen)

function listAux(genLen::Integrated, genA::Integrated{T, F}) where {T, F}
    n = dontShrink(genLen)
    genF(rng) = [ generate(rng, freeze(genA)) for _ in 1:generate(rng, n) ]
    Generator{Vector{T}}(genF)
end
listAux(genLen, genA) = listAux(Integrated(genLen), genA)

# TODO: this should be possible to make more generic
function vector(genLen, genA::Integrated{T,F}) where {T,F}
    genF(rng) = interleave(generate(rng, listAux(genLen, genA)))
    gen = Generator{Vector{eltype(T)}}(genF)
    dependent(gen)
end

function tuple(genLen, genA::Integrated{T,F}) where {T,F}
    genF(rng) = interleave((generate(rng, listAux(genLen, genA))...,))
    gen = Generator{NTuple{N, eltype(T)} where N}(genF)
    dependent(gen)
end

function interleave(integrated...)
    T = typeof(map((root ∘ generate), integrated))
    genF(rng) = interleave(map(i -> generate(rng, i), integrated))
    gen = Generator{Tree{T}}(genF)
    dependent(gen)
end