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
    subs = iunique(flatten((ds, sh)))
    Tree(r, subs)
end

function interleave(ts::Tuple)
    r = map(root, ts)
    sh = (interleave(s) for s in shrinks(subtrees, ts))
    Tree(r, sh)
end

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
