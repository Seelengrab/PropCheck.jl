using Random: Random, AbstractRNG, default_rng, randstring

abstract type AbstractGenerator{T} end

struct Generator{T,F} <: AbstractGenerator{T}
    gen::F
end
Generator{T}(g) where T = Generator{T,typeof(g)}(g)
Generator(el::T) where T = Generator{T}((rng)->generate(rng, el))
Generator(::Type{T}) where T = Generator{T}((rng)->generate(rng, T))

# unsure if this is really a good idea
function Base.iterate(g::Generator, state=nothing)
    element = generate(default_rng(), g)
    element === nothing && return nothing
    (element, nothing)
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
shrink(w::Word) = map(Word, shrink(w.hi))

#######################
# type based generation
#######################

generate(rng, ::Type{T}) where {T <: Number} = rand(rng, T) # numbers
generate(rng, ::Type{Bool}) = rand(rng, Bool)
generate(rng, ::Type{NTuple{N,T}}) where {N,T} = ntuple(_ -> generate(rng, T), N)

########################
# value based generation
########################

generate(rng, t::T) where {T <: Unsigned} = rand(zero(T):t) # numbers
generate(rng, t::T) where {T <: Signed} = rand(-t:t) # numbers
generate(rng, t::NTuple{N,T}) where {N,T} = ntuple(i -> generate(rng, t[i]), N)


