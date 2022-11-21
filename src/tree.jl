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

# recursively shrinks and creates a tree
shrinkMap(root) = imap(t -> Tree(t, shrinkMap(t)), shrink(root))

function interleave(trees::Union{<:NTuple{N,Tree{T}},Vector{Tree{T}},<:Tuple}) where {T,N}
    # the root of interleaved trees is just all individual roots
    nRoot = map(root, trees)
    return Tree(nRoot, shrinkMap(nRoot)) # TODO: isn't this just `unfold`?
end

"""
    filter(p, t::Tree[, trim=false])

Filters `t` lazily such that all elements contained fulfill the predicate `p`, i.e. all elements for which `p` is `false` are removed.

The first-level subtrees produced by the returned tree will have unique roots amongst each other.

`trim` controls whether subtrees are removed completely when the root doesn't
fulfill the predicate or whether only that root should be skipped, still trying to
shrink its subtrees. This trades performance (less shrinks to check) for quality
(fewer/less diverse shrink values tried).
"""
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
