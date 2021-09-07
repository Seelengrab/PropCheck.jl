struct UniqueIterator{T,F}
    itr::T
    by::F
    UniqueIterator(itr::T, f::F) where {T,F} = new{T,F}(itr, f)
end

function Base.iterate(itr::UniqueIterator)
    t = iterate(itr.itr)
    t === nothing && return nothing
    el, state = t
    (el, (state, [hash(itr.by(el))]))
end

function Base.iterate(itr::UniqueIterator, (state, cache))
    local el, state, h
    while true
        t = iterate(itr.itr, state)
        t === nothing && return nothing
        el, state = t
        h = hash(itr.by(el))
        h ∉ cache && break
    end
    push!(cache, h)
    return el, (state, cache)
end
Base.IteratorEltype(::Type{UniqueIterator{T,F}}) where {T,F} = Base.IteratorEltype(T)
Base.eltype(::Type{UniqueIterator{T,F}}) where {T,F} = eltype(T)
Base.IteratorSize(::Type{UniqueIterator{T,F}}) where {T,F} = Base.SizeUnknown()
iunique(itr; by=identity) = UniqueIterator(itr, by)
iunique(itr...; by=identity) = UniqueIterator(Iterators.flatten(itr), by)