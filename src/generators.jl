using Random: Random, AbstractRNG, default_rng, randstring

abstract type AbstractGenerator{T} end

struct Generator{T,F} <: AbstractGenerator{T}
    gen::F
end
Generator{T}(g) where T = Generator{T,typeof(g)}(g)
Generator(el::T) where T = Generator{T}((rng)->generate(rng, el))
Generator(::Type{T}) where T = Generator{T}((rng)->generate(rng, T))
function Generator(x::Union)
    types = getSubtypes(x)
    Generator{x}() do rng
        generate(rng, rand(rng, types))::x
    end
end

# unsure if this is really a good idea
function Base.iterate(g::Generator, rng=default_rng())
    element = generate(rng, g)
    element === nothing && return nothing
    (element, rng)
end
Base.IteratorEltype(::Type{<:Generator}) = Base.HasEltype()
Base.IteratorSize(::Type{<:Generator}) = Base.SizeUnknown()
Base.eltype(::Type{Generator{T,F}}) where {T,F} = T

generate(rng, g::Generator) = generate(rng, g.gen)

# fallback generator if no RNG is passed in
generate(x) = generate(Random.default_rng(), x)
generate(rng, f::Function) = f(rng)

#######################
# type based generation
#######################

generate(rng, ::Type{T}) where {T <: Number} = rand(rng, T) # numbers
# we want all possible bit patterns, not just numbers in [0,1)
generate(rng, ::Type{Float16}) = reinterpret(Float16, generate(rng, UInt16))
generate(rng, ::Type{Float32}) = reinterpret(Float32, generate(rng, UInt32))
generate(rng, ::Type{Float64}) = reinterpret(Float64, generate(rng, UInt64))
generate(rng, ::Type{NTuple{N,T}}) where {N,T} = ntuple(_ -> generate(rng, T), N)
# Ref. https://github.com/JuliaLang/julia/issues/44741#issuecomment-1079083216
generate(rng, ::Type{String}) = randstring(rng, typemin(Char):"\xf7\xbf\xbf\xbf"[1], 10)

#######################
# special case generation
#######################

"""
    iposint(::Type{T}) where T <: Union{Int8, Int16, Int32, Int64, Int128}

An integrated shrinker producing positive values of type `T`.
"""
iposint(T::Type{<:Base.BitSigned}) = map(itype(T)) do v
    v & typemax(T)
end

"""
    inegint(::Type{T}) where T <: Union{Int8, Int16, Int32, Int64, Int128}

An integrated shrinker producing negative values of type `T`.
"""
inegint(T::Type{<:Base.BitSigned}) = map(itype(T)) do v
    v | ~typemax(T)
end

"""
    ifloat(::T) where T <: Union{Float16, Float32, Float64}

An integrated shrinker producing floating point values, except `NaN`s and `Inf`s.

!!! info "NaN & Inf"
    There are multiple valid bitpatterns for both `NaN`- and `Inf`-like values.
    This shrinker is guaranteed not to produce any of them of its own volition.
    However, functions running on the values produced by this shrinker may still
    result in `NaN` or `Inf` to be produced. For example, if this shrinker produces
    a `0.0` and that number is passed to `x -> 1.0/x`, you'll still get a `Inf`.
    This can be important for `map`ping over this shrinker.
"""
ifloat(::Type{T}) where T <: Base.IEEEFloat = filter(itype(T), true) do v
    !(isinf(v) | isnan(v))
end

"""
    ifloatinf(::Type{T}) where T <: Union{Float16, Float32, Float64}

An integrated shrinker producing nothing but valid `Inf`s.

See also [`ifloatnan`](@ref), [`ifloatinfnan`](@ref).
"""
ifloatinf(::Type{T}) where T <: Base.IEEEFloat = map(itype(Bool)) do b
    inttype = uint(T)
    sign = inttype(b)
    assemble(T, sign, typemax(inttype), zero(inttype))
end

"""
    ifloatnan(::T) where T <: Union{Float16, Float32, Float64}

An integrated shrinker producing nothing but valid `NaN`s.

See also [`ifloatinf`](@ref), [`ifloatinfnan`](@ref).
"""
function ifloatnan(::Type{T}) where T <: Base.IEEEFloat
    # NaNs are just Infs with some nonzero fractional noise, as it turns out
    vintgen = filter(itype(uint(T))) do val
        _, _, fracmask = masks(T)
        !iszero(val & fracmask)
    end
    map(interleave(vintgen, ifloatinf(T))) do (vrand, v)
        vint = reinterpret(uint(T), v)
        reinterpret(T, vrand | vint)
    end
end

"""
    ifloatinfnan(::Type{T}) where T <: Union{Float16, Float32, Float64}

An integrated shrinker producing nothing but valid `NaN`s and `Inf`s.

Implemented more efficiently than naive combining of [`ifloatnan`](@ref) and [`ifloatinf`](@ref).
"""
function ifloatinfnan(::Type{T}) where T <: Base.IEEEFloat
    map(itype(uint(T))) do val
        _, expomask, _ = masks(T)
        reinterpret(T, val | expomask)
    end
end
