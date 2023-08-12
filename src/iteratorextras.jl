"""
    UniqueIterator(itr, by=identity)

A lazy iterator over unique elements that have not been produced before.

!!! warning "Floating Point"
    This iterator treats distinct bitpatterns of `NaN` as distinct values,
    unlike `Base.hash`.
"""
struct UniqueIterator{T,By}
    itr::T
    by::By
    UniqueIterator(itr::T, by::By=identity) where {T,By} = new{T,By}(itr, by)
end
Base.:(==)(a::UniqueIterator{T}, b::UniqueIterator{T}) where T = a.itr == b.itr && a.by == b.by
Base.hash(t::UniqueIterator, h::UInt) = hash(t.by, hash(t.itr, h))

"""
    nanHash(x[, h=zero(UInt)])

Produces a hash for values, with special consideration for `NaN`s, ensuring
distinct bitpatterns in `NaN` produce different hashes.
"""
nanHash

nanHash(x, h=zero(UInt)) = hash(x, h)
nanHash(x::Base.IEEEFloat, h=zero(UInt)) = hash(reinterpret(uint(typeof(x)), x), h)

function Base.iterate(itr::UniqueIterator)
    t = iterate(itr.itr)
    t === nothing && return nothing
    el, state = t
    # we store the hash instead of the object to allow GC to free it
    (el, (state, Set{UInt}(nanHash(itr.by(el)))))
end

function Base.iterate(itr::UniqueIterator, (state, cache))
    local el, state, h
    while true
        t = iterate(itr.itr, state)
        t === nothing && return nothing
        el, state = t
        h = nanHash(itr.by(el))
        h ∉ cache && break
    end
    push!(cache, h)
    return el, (state, cache)
end
Base.IteratorEltype(::Type{UniqueIterator{T,F}}) where {T,F} = Base.IteratorEltype(T)
Base.IteratorSize(::Type{UniqueIterator{T,F}}) where {T,F} = Base.SizeUnknown()
Base.eltype(::Type{UniqueIterator{T,F}}) where {T,F} = eltype(T)

Base.IteratorEltype(::Type{Base.Generator{T,F}}) where {T <: UniqueIterator, F} = Base.IteratorEltype(T)
Base.eltype(::Type{Base.Generator{T,F}}) where {T <: UniqueIterator, F} = eltype(T)

uniqueitr(itr; by=identity) = UniqueIterator(itr, by)
uniqueitr(itr, itr2, itrs...; by=identity) = UniqueIterator(Flatten{eltype(itr)}(itr, itr2, itrs...), by)

"""
    Flatten{Eltype}

An iterator like `Base.flatten`, except with inferrable `eltype`. Requires the given iterators to have the same `eltype`.

!!! warning "Type mismatches"
    The given `Eltype` is used to assert the return type; a type mismatch there _will_ throw.
"""
struct Flatten{Eltype}
    it
end
Flatten{T}(itrs...) where T = Flatten{T}(itrs)
Base.IteratorEltype(::Type{<:Flatten}) = Base.HasEltype()
Base.IteratorSize(::Type{<:Flatten}) = Base.SizeUnknown()
Base.eltype(::Type{Flatten{T}}) where T = T
function Base.iterate(f::Flatten{T}, state=()) where T
    if state !== ()
        y = iterate(Base.tail(state)...)
        y !== nothing && return (y[1], (state[1], state[2], y[2]))
    end
    x = (state === () ? iterate(f.it) : iterate(f.it, state[1]))
    x === nothing && return nothing
    y = iterate(x[1])
    while y === nothing
         x = iterate(f.it, x[2])
         x === nothing && return nothing
         y = iterate(x[1])
    end
    return convert(T, y[1]), (x[2], x[1], y[2])
end
Base.:(==)(a::Flatten, b::Flatten) = a.it == b.it
Base.hash(t::Flatten, h::UInt) = hash(t.it, h)

struct Shuffle{T}
    itr::T
    cacheSize::Int
    Shuffle(itr::T, cacheSize::Int=min(100, Base.IteratorSize(T) isa Base.HasShape || Base.IteratorSize(T) isa Base.HasLength ? max(length(itr), length(itr)÷5) : 5)) where T = new{T}(itr, cacheSize)
end
Shuffle(v::AbstractArray) = shuffle!(v) # we already have the memory, so shuffle it directly

Base.:(==)(a::Shuffle, b::Shuffle) = a.itr == b.itr && a.cacheSize == b.cacheSize
Base.hash(t::Shuffle, h::UInt) = hash(t.cacheSize, hash(t.itr, h))
Base.IteratorEltype(::Shuffle{T}) where T = Base.IteratorEltype(T)
Base.IteratorSize(::Shuffle{T}) where T = Base.IteratorSize(T)
Base.eltype(::Shuffle{T}) where T = eltype(T)
Base.size(s::Shuffle{T}) where T = size(s.itr)
Base.length(s::Shuffle{T}) where T = length(s.itr)

function Base.iterate(s::Shuffle{T}) where T
    els = eltype(T)[]
    sizehint!(els, s.cacheSize)
    it = iterate(s.itr)
    while it !== nothing && length(els) < s.cacheSize
        el, state = it
        push!(els, el)
        it = iterate(s.itr, state)
    end
    shuffle!(els)
    iterate(s, (els, it))
end

function Base.iterate(s::Shuffle, (els, it))
    iszero(length(els)) && return nothing
    shuffle!(reverse!(els))
    ret = popfirst!(els)
    if it !== nothing
        el, state = it
        push!(els, el)
        it = iterate(s.itr, state)
    end
    return (ret, (els, it))
end

spliterator(t) = ((@view(t[begin:n-1]), t[n], @view(t[n+1:end]),1) for n in eachindex(t))
spliterator(t::Tuple) = ((t[begin:n-1], t[n], t[n+1:end]) for n in eachindex(t))
