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
generate(rng, i::Integrated) = i.gen(rng)

const iBool = Integrated(Generator(Bool))
iWord(hi) = Integrated(mWord(hi))

freeze(i::Integrated{T,F}) where {T,F} = Generator{T}(i.gen)
dontShrink(i::Integrated{T,F}) where {T,F} = Generator{T}((rng) -> root(i.gen(rng))) # TODO: check if this should just produce the root continously instead
dependent(g::Generator{T,F}) where {T,F} = Integrated{T,F}(g.gen)

function listAux(genLen::Integrated, genA::Integrated{T, F}) where {T, F}
    n = dontShrink(genLen)
    Generator{Vector{T}}(rng -> [ generate(rng, freeze(genA)) for _ in 1:generate(rng, n) ])
end
listAux(genLen, genA) = listAux(Integrated(genLen), genA)

vector(genLen, genA::Integrated{T,F}) where {T,F} = dependent(Generator{Vector{eltype(T)}}((rng) -> interleave(generate(rng, listAux(genLen, genA)))))
tuple(genLen, genA::Integrated{T,F}) where {T,F} = dependent(Generator{NTuple{N, eltype(T)} where N}((rng) -> interleave((generate(rng, listAux(genLen, genA))...,))))