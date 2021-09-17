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

unfold(f) = Base.Fix1(unfold, f)
function unfold(f, t::T) where {T}
    Tree(t, imap(unfold, f(t)))
end

# recursively shrinks and creates a tree
treeMap(root) = imap(t -> Tree(t, treeMap(t)), shrink(root))

function interleave(trees::Union{<:NTuple{N,Tree{T}},Vector{<:Tree{T}},<:Tuple}) where {T,N}
    # the root of interleaved trees is just all individual roots
    nRoot = map(root, trees)
    return Tree(nRoot, treeMap(nRoot)) # TODO: isn't this just `unfold`?
end

"""
    filter(p, t::Tree[, trim=false])

Filters `t` lazily such that all elements contained fulfill the predicate `p`, i.e. all elements for which `p` is `false` are removed.

The first-level subtrees produced by the returned tree will have unique roots amongst each other.

`trim` controls whether subtrees are removed completely when the root doesn't
fulfill the predicate or whether only that root should be skipped, still trying to
shrink its subtrees. This trades performance (less shrinks to check) for quality
(fewer/less diverse shrink values tried).

`prod_unique` controls whether subtrees are filtered for uniqueness during production.
"""
function Base.filter(f, t::Tree{T,sT}, trim=false, prod_unique=true) where {T,sT}
    r = root(t)
    _filter(x) = filter(f, x, trim)
    flat = flatten(imap(_filter, subtrees(t)))
    lazySubtrees = prod_unique ? iunique(flat; by=root) : flat
    
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
_map(f) = Base.Fix1(imap, f)
function Base.Iterators.map(f, t::Tree{T,sT}) where {T,sT}
    r = root(t)
    lazySubtrees = iunique(imap(_map, subtrees(t)))
    return Tree(f(r), lazySubtrees)
end
