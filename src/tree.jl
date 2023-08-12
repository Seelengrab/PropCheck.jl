using Base.Iterators: flatten, map as imap, filter as ifilter, product as iproduct
using Random: shuffle!

"""
    Tree{T}

A tree of `T` objects. The tree is inherently lazy; subtrees of subtrees are only
generated on demand.

The `subtrees` field is intentionally untyped, to allow for various kinds of lazy subtree
representations.
"""
struct Tree{T}
    root::T
    subtrees
    Tree(el::T, subtrees=T[]) where T = new{T}(el, subtrees)
end

"""
    root(t::Tree)

Returns the singular root of the given `Tree`.

See also [`subtrees`](@ref).
"""
root(t::Tree) = t.root
root(::Nothing) = nothing

"""
    subtrees(t::Tree)

Returns the (potentially lazy) subtrees of the given `Tree`.

See also [`root`](@ref).
"""
subtrees(t::Tree) = t.subtrees
subtrees(::Nothing) = nothing

Base.show(io::IO, t::Tree) = print(io, "Tree(", t.root, ')')

Base.eltype(::Type{<:Tree{T}}) where {T} = T

Base.:(==)(::Tree, ::Tree) = false
Base.:(==)(a::Tree{T}, b::Tree{T}) where T = a.root == b.root && a.subtrees == b.subtrees
Base.hash(t::Tree, h::UInt) = hash(t.subtrees, hash(t.root, h))

"""
    unfold(f, root)

Unfolds `root` into a `Tree`, by applying `f` to each root to create subtrees.

`root` is the new root of the returned `Tree`. `f` must return an iterable
object with `eltype` egal to `typeof(root)`.
"""
function unfold(f, root::T) where {T}
    Tree(root, imap(unfold(f), f(root)))
end
unfold(f) = Base.Fix1(unfold, f)

function interleave(funcs::Tree, objs::Tree)
    f = root(funcs)
    x = root(objs)
    shrinkFuncs = (interleave(l_, objs) for l_ in subtrees(funcs))
    shrinkObjs  = (interleave(funcs, o_) for o_ in subtrees(objs))
    shrinks = flatten((shrinkFuncs,  shrinkObjs))
    Tree(f(x), shrinks)
end

function interleave(ts::Vector)
    r = map(root, ts)
    ds = (interleave(d) for d in drops(ts))
    sh = (interleave(s) for s in shrinks(subtrees, ts))
    subs = uniqueitr(flatten((ds, sh)))
    Tree(r, subs)
end

function interleave(ts::Tuple)
    r = map(root, ts)
    sh = (interleave(s) for s in shrinks(subtrees, ts))
    Tree(r, sh)
end

"""
    filter(pred, ::Tree, trim=false)

Filters the given `Tree` by applying the predicate `pred` to each root.

Filtering is done lazily for subtrees.

`trim` controls whether subtrees that don't match the predicate should be pruned entirely,
or only their roots should be removed from the resulting `Tree`. If `trim` is `true`,
subtrees of subtrees that don't match the predicate are moved to the parent.
"""
function Base.filter(pred, t::Tree{T}, trim=false) where {T}
    r = root(t)
    _filter(x) = filter(pred, x, trim)
    flat = Flatten{Tree{T}}(imap(_filter, subtrees(t)))

    if pred(r)
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

"""
    map(f, ::Tree)

Maps the function `f` over the nodes of the given `Tree`, returning a new true.

The subtrees of the tree returned by `map` are guaranteed to be unique.
"""
function Base.Iterators.map(f, t::Tree{T}) where {T}
    r = root(t)
    lazySubtrees = uniqueitr(imap(_map(f), subtrees(t)))
    return Tree(f(r), lazySubtrees)
end
