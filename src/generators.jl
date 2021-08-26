using Random: Random, AbstractRNG, default_rng

abstract type AbstractGenerator{T} end

struct Generator{T,F} <: AbstractGenerator{T}
    gen::F
    Generator{T}(g) where T = new{T,typeof(g)}(g)
end
Generator(el::T) where T = Generator{T}(()->generate(el))
Generator(::Type{T}) where T = Generator{T}(()->generate(T))

generate(g::Generator) = g.gen()

generate(::Type{T}) where {T <: Number} = rand(T) # numbers
generate(::Type{NTuple{N,T}}) where {N,T} = ntuple(_ -> generate(T), N)

Base.iterate(g::Generator, state=nothing) = (generate(g),nothing)
Base.IteratorEltype(::Type{<:Generator}) = Base.HasEltype()
Base.IteratorSize(::Type{<:Generator}) = Base.IsInfinite()
Base.eltype(::Type{Generator{T,F}}) where {T,F} = T

###############
## Integrated
###############

mutable struct Integrated{T,f_,F} <: AbstractGenerator{T}
    gen::Generator{T,f_}
    do_shrink::Bool
    @atomic has_shrunk::Bool
    subtrees::Vector{Integrated{T}}
    
    shrink::F
    root::T

    function Integrated(gen::Generator{T,f_}, do_shrink, subtrees, shrink::F, root) where {T,f_,F}
        return new{T,f_,F}(gen, do_shrink, !isempty(subtrees), subtrees, shrink, root)
    end
    function Integrated(gen::Generator{T,f_}, do_shrink, subtrees, shrink::F) where {T,f_,F}
        return new{T,f_,F}(gen, do_shrink, !isempty(subtrees), subtrees, shrink, generate(gen))
    end
end
function Integrated(t::Generator{T,f_}, shrink=shrink; do_shrink=false) where {T,f_}
    return Integrated(t, do_shrink, Integrated{T}[], shrink)
end
Integrated(el::T, shrink=shrink) where T = Integrated(Generator(el), shrink)

function Base.show(io::IO, t::Integrated{T,R,F}) where {T,R,F}
    print(io, 'I')
    printstyled(io, '{', T, '}'; color=8)
    print(io, '(', root(t), ')')
end

# if root and shrink function are the same, two integrated generators are the same since shrink should be deterministisch
Base.:(==)(i1::Integrated, i2::Integrated) = i1.root == i2.root && i2.shrink == i2.shrink
Base.hash(i::Integrated, x::UInt64) = hash(i.shrink, hash(i.root, x))
Base.copy(i::Integrated{T,f_,F_}) where {T,f_,F_} = Integrated(i.gen, i.do_shrink, Integrated{T}[], i.shrink, i.root)

function Base.getproperty(t::Integrated, sym::Symbol)
    if sym === :subtrees
        unfoldTree!(t)
        getfield(t, sym)
    else
        getfield(t, sym)
    end
end
root(i::Integrated) = i.root
subtrees(i::Integrated) = i.subtrees
function generate(i::Integrated)
    (@atomic i.has_shrunk) && return i.root
    i.root = generate(i.gen)
end

function unfoldTree!(t::Integrated{T,f_,F_}) where {T,f_,F_}
    old, success = @atomicreplace t.has_shrunk false => true
    (old || !success) && return nothing
    subTrees = map(x -> Integrated(Generator{T}(()->x), t.shrink), t.shrink(t.root))
    append!(t.subtrees, subTrees)
    nothing
end

_iterate(i) = i.do_shrink ? (root(i), copy(subtrees(i))) : (generate(i), nothing)
Base.iterate(i::Integrated) = _iterate(i)
Base.iterate(i::Integrated, ::Nothing) = _iterate(i)
function Base.iterate(_::Integrated, state)
    isempty(state) && return nothing
    tree = pop!(state)
    prepend!(state, subtrees(tree))
    return root(tree), state
end
Base.IteratorEltype(::Type{<:Integrated}) = Base.HasEltype()
Base.IteratorSize(::Type{<:Integrated}) = Base.SizeUnknown()
Base.eltype(::Type{Integrated{T,F,R}}) where {T,F,R} = T

function interleave(trees::Integrated...)
    newRoot = map(root, trees)
    shrinks = map(x -> x.shrink, trees)
    allShrinks = ( ntuple(x -> i == x ? f : (x -> (x,)), length(shrinks)) for (i,f) in enumerate(shrinks) )
    newShrink(toShrink) = begin
        ret = typeof(newRoot)[]

        for shrinks in allShrinks
            shrunks = ntuple(i -> shrinks[i](toShrink[i]), length(shrinks))
            any(isempty, shrunks) && continue
            append!(ret, Iterators.product(shrunks...))
        end

        return ret
    end
    newGen = Generator{typeof(newRoot)}(() -> map(generate, trees))

    return Integrated(Generator{typeof(newRoot)}(newGen), newShrink)
end

function interleave(trees::Generator{Vector{G},F}) where {F, T, G <: AbstractGenerator{T}}
    # luckily we should be able to assume that the shrink functions are always the same for all generated generators, else we'd go mad here
    shrink_funcs = map(x -> x.shrink, generate(trees))
    allShrinks = [ [ i == x ? f : (x -> [x]) for (i,f) in enumerate(shrink_funcs)] for x in 1:length(shrink_funcs) ]
    newShrink(toShrink) = begin
        ret = Vector{T}[]

        for i in eachindex(toShrink)
            arr = deleteat!(deepcopy(toShrink), i)
            isempty(arr) && continue
            push!(ret, arr)
        end

        for funcs in allShrinks
            shrunks = [ f(x) for (f,x) in zip(funcs, toShrink) ]
            any(isempty, shrunks) && continue
            all(==(toShrink), shrunks) && continue # no progress through shrinking, one should have changed!
            toAppend = ([p...] for p in Iterators.product(shrunks...))
            append!(ret, Iterators.filter(!=(toShrink), toAppend))
        end

        return ret
    end
    newGen = Generator{Vector{T}}(() -> map(generate, generate(trees)))

    return Integrated(newGen, newShrink)
end

function freeze(i::Integrated{T,R,F}) where {T,R,F}
    Generator{T}(()->Integrated(generate(i)))
end

function dontShrink(i::Integrated{T,R,F}) where {T,R,F}
    Generator{T}(()->i.root)
end

function listAux(genLen, genEl::AbstractGenerator{T}) where T
    n = dontShrink(genLen)
    gen = freeze(genEl)
    Generator{Vector{Integrated{T}}}(()->[ generate(gen) for _ in 1:generate(n) ])
end

genList(n::Integrated, el::Integrated) = interleave(listAux(n, el))