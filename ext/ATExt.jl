module ATExt

using AbstractTrees: AbstractTrees
using PropCheck: PropCheck

AbstractTrees.nodevalue(t::PropCheck.Tree) = PropCheck.root(t)
AbstractTrees.children(t::PropCheck.Tree) = PropCheck.subtrees(t)
AbstractTrees.childtype(::Type{PropCheck.Tree{T}}) where T = T

AbstractTrees.NodeType(::Type{<:PropCheck.Tree}) = AbstractTrees.HasNodeType()
AbstractTrees.nodetype(::Type{<:PropCheck.Tree{T}}) where T = Tree{T}

Base.IteratorEltype(::Type{<:AbstractTrees.TreeIterator{<:PropCheck.Tree}}) = Base.HasEltype()
Base.eltype(::Type{<:AbstractTrees.TreeIterator{PropCheck.Tree{T}}}) where T = T

end
