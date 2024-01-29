"""
    @constfield foo::Int

A macro providing compatibility for `const` fields in mutable structs.
Gives a `const` `Expr` if supported, otherwise is a noop and just returns the field.
"""
macro constfield(ex::Expr)
    (ex.head == Symbol("::") && length(ex.args) == 2) || throw(ArgumentError("`@constfield` only supports expressions of the form `field::Type`!"))
    ex = esc(ex)
    if VERSION < v"1.8"
        ex
    else
        Expr(:const, ex)
    end
end

function getsubtypes(T=Any)::Vector{DataType}
    T isa Union && return getsubunions!(DataType[], T)
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

function getsubunions!(cache, T)
    if !(T isa Union)
        push!(cache, T)
    else
        push!(cache, T.a)
        getsubunions!(cache, T.b)
    end
end