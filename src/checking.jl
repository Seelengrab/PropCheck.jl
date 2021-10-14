using Logging

function check(p, i::Integrated, rng=Random.default_rng())
    genAs = [ generate(rng, freeze(i)) for _ in 1:numTests[] ]
    something(findCounterexample(p, genAs), true)
end

minimize(f) = Base.Fix1(minimize, f)
function minimize(f, t::Tree{T}) where {T}
    shrinks = T[]
    while true
        r = root(t)
        @debug "Possible shrink value" r
        push!(shrinks, r)
        subs = subtrees(t)
        !any(f, subs) && break
        t = first(Iterators.filter(f, subs))
    end
    return shrinks
end

function findCounterexample(f, trees::Vector{<:Tree})
    _f = (!f ∘ root)
    filter!(_f, trees)
    isempty(trees) && return nothing
    t = first(trees)
    @info "Found counterexample for '$f', beginning shrinking..." t
    minimize(_f, t)
end
