using Logging

function check(p, i::Integrated, rng=Random.default_rng(); ntests::Int=numTests[], show_initial=true)
    genAs = [ generate(rng, freeze(i)) for _ in 1:ntests ]
    res = findCounterexample(p, genAs; show_initial)
    res === nothing && return true
    @debug res
    entry = last(res)
    if errored(entry)
        return entry.example, exception(entry)
    else
        return entry.example
    end
end

const ExState = Tuple{<:Exception,Vector{Base.StackTraces.StackFrame}}
struct CheckEntry{T}
    example::T
    exception::Union{Nothing,ExState}
end

errored(ce::CheckEntry) = ce.exception !== nothing
exception(ce::CheckEntry) = errored(ce) && first(ce.exception)

function minimize!(log, f, t::Tree{T}, initEx) where {T}
    ex::Union{Nothing,ExState} = initEx
    while true
        r = root(t)
        @debug "Possible shrink value" r
        push!(log, CheckEntry(r, ex))
        subs = subtrees(t)
        filteredSubtrees = Iterators.filter(first, Iterators.map(f, subs))
        !any(first, filteredSubtrees) && break
        _, t, ex = first(filteredSubtrees)
    end
    infomsg = "$(length(log)) counterexamples found"
    errcount = count(errored, log)
    if !iszero(errcount)
        unique_errors = filter(!isnothing, unique(exception, log))
        distinct_errors = length(unique_errors)
        infomsg *= ", of which $errcount threw $distinct_errors distinct exception types"
        @info infomsg Errors=map(exception, unique_errors)
    else
        @info infomsg
    end
    # TODO: Return a fancy log type here instead of just a vector
    log
end

function findCounterexample(f, trees::Vector{<:Tree}; show_initial=true)
    function _f(tree)
        try
            ((!f ∘ root)(tree), tree, nothing)
        catch ex
            trace = stacktrace(catch_backtrace())
            (true, tree, (ex, trace)) # if we threw, the property failed
        end
    end
    checkedTrees = map(_f, trees)
    filter!(first, checkedTrees)
    isempty(checkedTrees) && return nothing
    initialCE = first(checkedTrees)
    if show_initial
        @info "Found counterexample for '$f', beginning shrinking..."  Counterexample=root(initialCE[2])
    else
        @info "Found counterexample for '$f', beginning shrinking..."
    end
    _, initTree, initEx = initialCE
    log = CheckEntry{eltype(initTree)}[]
    minimize!(log, _f, initTree, initEx)
end
