using Logging

function check(p, i::Integrated, rng=Random.default_rng())
    genAs = [ generate(rng, freeze(i)) for _ in 1:numTests[] ]
    something(findCounterexample(p, genAs), true)
end

minimize(f) = Base.Fix1(minimize, f)
function minimize(f, t::Tree{T,sT}) where {T,sT}
    r = root(t)
    subs = subtrees(t)
    !any(f, subs) && return (r,)
    el = first(Iterators.filter(f, subs))
    @debug "Possible shrink value" el
    flatten(((r,), flatten(imap(minimize(f), (el,)))))
end

function findCounterexample(f, trees::Vector{<:Tree})
    _f = (!f ∘ root)
    filter!(_f, trees)
    isempty(trees) && return nothing
    t = first(trees)
    @info "Found counterexample for '$f', beginning shrinking..." t
    collect(minimize(_f, t))
end