using Base.Iterators: flatten, map as imap, filter as ifilter, product as iproduct
using Random: shuffle!

struct Tree{T}
    root::T
    subtrees
    Tree(el::T, subtrees=T[]) where T = new{T}(el, subtrees)
end

root(t::Tree) = t.root
subtrees(t::Tree) = t.subtrees

Base.show(io::IO, t::Tree) = print(io, "Tree(", t.root, ')')

Base.eltype(::Type{<:Tree{T}}) where {T} = T

unfold(f) = Base.Fix1(unfold, f)
function unfold(f, t::T) where {T}
    Tree(t, imap(unfold(f), f(t)))
end

shrinkcat(a::Tuple,c::Tuple) = (a..., c...)
shrinkcat(a::Tuple,b,c::Tuple) = (a..., b, c...)
shrinkcat(a::AbstractVector,c::AbstractVector) = cat(a, c, dims=1)
shrinkcat(a::AbstractVector,b,c::AbstractVector) = cat(a, b, c, dims=1)

function interleave(trees::Vector{Tree{T}}) where {T}
    # the root of interleaved trees is just all individual roots
    splits = spliterator(trees)
    shrinks = flatten((shrinkcat(f, s, t) for s in subtrees(mid)) for (f,mid,t) in splits)
    drops = (shrinkcat(f, t) for (f,_,t) in splits)
    els = flatten((drops, shrinks))
    subs = imap(interleave, els)
    Tree(map(root, trees), subs)
end

# tuples don't drop an element
function interleave(trees::NTuple{N, Tree}) where N
    # the root of interleaved trees is just all individual roots
    splits = spliterator(trees)
    shrinks = flatten((shrinkcat(f, s, t) for s in subtrees(mid)) for (f,mid,t) in splits)
    subs = imap(interleave, shrinks)
    Tree(map(root, trees), subs)
end
interleave(trees::Tree...) = interleave(trees)

function Base.filter(f, t::Tree{T}, trim=false) where {T}
    r = root(t)
    _filter(x) = filter(f, x, trim)
    flat = Flatten{Tree{T}}(imap(_filter, subtrees(t)))

    if f(r)
        Flatten{Tree{T}}(Ref(Ref(Tree(r, flat))))
    else
        if !trim
            flat
        else
            Flatten{Tree{T}}()
        end
    end
end

Base.map(f, t::Tree) = imap(f, t)

# lazy mapping by default
_map(f) = Base.Fix1(imap, f)
function Base.Iterators.map(f, t::Tree{T}) where {T}
    r = root(t)
    lazySubtrees = iunique(imap(_map(f), subtrees(t)))
    return Tree(f(r), lazySubtrees)
end
