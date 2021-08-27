using AbstractTrees
using Base.Iterators: flatten, map as imap, filter as ifilter, product as iproduct

struct Tree{T,sT}
    root::T
    subtrees::sT
    Tree(el::T, subtrees=T[]) where T = new{T,typeof(subtrees)}(el, subtrees)
end

root(t::Tree) = t.root
subtrees(t::Tree) = t.subtrees

Base.show(io::IO, t::Tree) = print(io, "Tree(", t.root, ')')

AbstractTrees.children(t::Tree) = collect(subtrees(t))
Base.eltype(::Type{<:Tree{T}}) where {T} = T

function unfold(f, t::T) where {T}
    _unfold = Base.Fix1(unfold, f)
    Tree(t, imap(_unfold, f(t)))
end

# recursively shrinks and creates a tree
treeMap(root) = imap(t -> Tree(t, treeMap(t)), shrink(root))

function interleave(trees::Union{<:NTuple{N,Tree{T}},Vector{<:Tree{T}}}) where {T,N}
    # the root of interleaved trees is just all individual roots
    nRoot = map(root, trees)
    return Tree(nRoot, treeMap(nRoot)) # TODO: isn't this just `unfold`?
end

"""
    filter(p, t::Tree[, trim=false])

Filters `t` lazily such that all elements contained fulfill the predicate `p`.

The first-level subtrees produced by the returned tree will have unique roots amongst each other.

`trim` controls whether subtrees are removed completely when the root doesn't
fulfill the predicate or whether only that root should be skipped, still trying to
shrink its subtrees. This trades performance (less shrinks to check) for quality
(fewer/less diverse shrink values tried).
"""
function Base.filter(f, t::Tree{T,sT}, trim=false) where {T,sT}
    r = root(t)
    _filter(x) = filter(f, x, trim)
    lazySubtrees = iunique(flatten(imap(_filter, subtrees(t))); by=root)
    
    if f(r)
        Tree{T}[ Tree(r, lazySubtrees) ]
    else
        if !trim
            lazySubtrees
        else
            Tree{T}[]
        end
    end
end

"""
    map(f, t::Tree)

Maps `f` lazily over all elements in `t`, producing a new tree. 

The first-level subtrees produced by the returned tree will have unique roots amongst each other.
"""
Base.map(f, t::Tree) = imap(f, t)

# lazy mapping by default
function Base.Iterators.map(f, t::Tree{T,sT}) where {T,sT}
    r = root(t)
    _map(t) = imap(f, t)
    lazySubtrees = iunique(imap(_map, subtrees(t)))
    return Tree(f(r), lazySubtrees)
end
