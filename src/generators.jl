using Random: Random, AbstractRNG, default_rng, randstring

abstract type AbstractGenerator{T} end

struct Generator{T,F} <: AbstractGenerator{T}
    gen::F
end
Generator{T}(g) where T = Generator{T,typeof(g)}(g)
Generator(el::T) where T = Generator{T}((rng)->generate(rng, el))
Generator(::Type{T}) where T = Generator{T}((rng)->generate(rng, T))

generate(rng, g::Generator) = g.gen(rng)

Base.iterate(g::Generator, state=nothing) = (generate(default_rng(), g), nothing)
Base.IteratorEltype(::Type{<:Generator}) = Base.HasEltype()
Base.IteratorSize(::Type{<:Generator}) = Base.IsInfinite()
Base.eltype(::Type{Generator{T,F}}) where {T,F} = T

generate(rng, t::T) where {T <: Unsigned} = rand(zero(T):t) # numbers
generate(rng, t::T) where {T <: Signed} = rand(-t:t) # numbers
generate(rng, ::Type{T}) where {T <: Number} = rand(rng, T) # numbers
generate(rng, t::NTuple{N,T}) where {N,T} = ntuple(i -> generate(rng, t[i]), N)
generate(rng, ::Type{NTuple{N,T}}) where {N,T} = ntuple(_ -> generate(rng, T), N)
