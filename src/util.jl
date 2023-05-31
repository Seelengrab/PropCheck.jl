function getSubtypes(T=Any)::Vector{DataType}
    T isa Union && return getSubUnions!(DataType[], T)
    subs = subtypes(T)
    ret = filter(isconcretetype, subs)
    filter!(isabstracttype, subs)

    while !isempty(subs)
        ntype = popfirst!(subs)
        ntype == Any && continue
        nsubs = subtypes(ntype)
        append!(ret, Iterators.filter(isconcretetype, nsubs))
        append!(subs, Iterators.filter(isabstracttype, nsubs))
    end

    ret
end

function getSubUnions!(cache, T)
    if !(T isa Union)
        push!(cache, T)
    else
        push!(cache, T.a)
        getSubUnions!(cache, T.b)
    end
end