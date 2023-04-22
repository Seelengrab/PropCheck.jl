using Random: Random, AbstractRNG, default_rng, randstring

abstract type AbstractGenerator{T} end

struct Generator{T,F} <: AbstractGenerator{T}
    gen::F
end
Generator{T}(g) where T = Generator{T,typeof(g)}(g)
Generator(el::T) where T = Generator{T}((rng)->generate(rng, el))
Generator(::Type{T}) where T = Generator{T}((rng)->generate(rng, T))

# unsure if this is really a good idea
function Base.iterate(g::Generator, rng=default_rng())
    element = generate(rng, g)
    element === nothing && return nothing
    (element, rng)
end
Base.IteratorEltype(::Type{<:Generator}) = Base.HasEltype()
Base.IteratorSize(::Type{<:Generator}) = Base.IsInfinite()
Base.eltype(::Type{Generator{T,F}}) where {T,F} = T

generate(rng, g::Generator) = g.gen(rng)

# fallback generator if no RNG is passed in
generate(x) = generate(Random.default_rng(), x)

struct Word
    hi::UInt
end
generate(rng, w::Word) = Word(rand(rng, 0:w.hi))
generate(rng, ::Type{Word}) = Word(rand(rng, UInt))
const mWord(w) = Generator(Word(w))
shrink(w::Word) = Word.(shrink(w.hi))

#######################
# type based generation
#######################

generate(rng, ::Type{T}) where {T <: Number} = rand(rng, T) # numbers
generate(rng, ::Type{Float16}) = reinterpret(Float16, generate(rng, UInt16))
generate(rng, ::Type{Float32}) = reinterpret(Float32, generate(rng, UInt32))
generate(rng, ::Type{Float64}) = reinterpret(Float64, generate(rng, UInt64))
generate(rng, ::Type{NTuple{N,T}}) where {N,T} = ntuple(_ -> generate(rng, T), N)
# Ref. https://github.com/JuliaLang/julia/issues/44741#issuecomment-1079083216
generate(rng, ::Type{String}) = randstring(rng, typemin(Char):"\xf7\xbf\xbf\xbf"[1], 10)

########################
# value based generation
########################

generate(rng, t::T) where {T <: Number} = t
