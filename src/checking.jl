function check(p, i::Integrated, rng=Random.default_rng())
    genAs = [ generate(rng, freeze(i)) for _ in 1:numTests[] ]
    something(findCounterexample(p, genAs), true)
end

minimize(f) = t -> minimize(f, t)
function minimize(f, t::Tree{T,sT}) where {T,sT}
    r = root(t)
    subs = subtrees(t)
    s = filter!(f, collect(subs))
    isempty(s) && return (r,)
    flatten(((r,), flatten(imap(minimize(f), (first(s),)))))
end
function findCounterexample(f, trees::Vector{<:Tree})
    _f = (!f ∘ root)
    filter!(_f, trees)
    isempty(trees) && return nothing
    (collect ∘ minimize(_f) ∘ first)(trees)
end