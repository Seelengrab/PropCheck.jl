struct Manual{T, G <: AbstractGenerator{T}, F}
    gen::G
    shrink::F
end
Manual(gen::AbstractGenerator) = Manual(gen, shrink)
generate(rng, m::Manual) = generate(rng, m.gen)

# drop each index once
drops(root::Vector) = (deleteat!(deepcopy(root), i) for i in eachindex(root))

# create all tuples with all identity, except for one place which we shrink
allfuncs(elShrink, root) = (( i == idx ? elShrink : (x -> [x]) for i in eachindex(root) ) for idx in eachindex(root))

# apply the shrinking functions and filter unsuccessful shrinks
shrunkels(elShrink, root) = ifilter((x -> !(any(isempty, x) || all(==(root), x))),
                    ((f(x) for (f,x) in zip(funcs, root)) for funcs in allfuncs(elShrink, root)))

getprod(a, ::Type{<:Tuple}) = a
getprod(a, ::Type{<:Vector}) = [a...]
# we have a number of shrink results, take the product of all for all shrink combinations
prods(elShrink, root::T) where T = flatten((getprod(p, T) for p in iproduct(shrunks...)) for shrunks in shrunkels(elShrink, root))

# finally, filter out productions that resulted back in the original root for efficiency
shrinks(elShrink, root) = (ifilter(!=(root), prods(elShrink, root)))

function mlist(genLen::Manual{I}, genA::Manual{T}) where {T, I <: Union{Base.BitInteger,Bool}}
    gen(rng) = T[ generate(rng, genA)::T for _ in 1:generate(rng, genLen)::I ]
    shrink(a) = uniqueitr(flatten((drops(a), shrinks(genA.shrink, a))))
    Manual(Generator{Vector{T}}(gen), shrink)
end

function repeatuntil(pred, ma)
    while true
        el = ma()
        pred(el) && return el
    end
end

function Base.filter(pred, genA::Manual{T}) where T
    gen(rng) = repeatuntil(pred, () -> generate(rng, genA))
    shrink_(a) = flatten(pred(x) ? (x,) : shrink_(x) for x in genA.shrink(a))
    Manual(Generator{T}(gen), shrink_)
end