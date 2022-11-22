# Shrinking functions for default data types


"""
    shrink(::Bool)

`true` shrinks to `false`. `false` produces no shrunk values.
"""
function shrink(t::Bool)
    if t
        return Bool[false]
    else
        return Bool[]
    end
end

"""
    shrink(::T) where T <: Unsigned

Shrinks an unsigned value by masking out various part of its bitpattern.

Shrinks towards `zero(T)`. `zero(T)` produces no shrunk values.
"""
function shrink(w::T) where T <: Unsigned
    ret = T[ w & ~(one(T) << mask) for mask in zero(T):(sizeof(T)*8 - 1) ]
    w > zero(T) && pushfirst!(ret, w - 0x1)
    w > one(T) && pushfirst!(ret, w - 0x2)
    pushfirst!(ret, w >> 0x1)
    lowmask = (one(w) << (sizeof(w)*0x4) - 0x1)
    pushfirst!(ret, w & lowmask)
    push!(ret, w & ~lowmask)
    return sort!(filter!(!=(w), unique!(ret)))
end

"""
    shrink(::T) where T <: Signed

Shrinks a signed value by shrinking its absolute value like an unsigned and then also negating that.
Both the absolute and the negated value are part of the shrinking result.

Shrinks towards `zero(T)`. `zero(T)` produces no shrunk values.
"""
function shrink(w::T) where T <: Signed
    ret = signed.(shrink(unsigned(abs(w))))
    append!(ret, ret)
    retView = @view ret[end÷2+1:end]
    map!(-, retView, retView)
    return filter!(unique!(ret)) do x
        x != w && x != -w
    end
end

"""
    shrink(::Char)

Shrinks a character by shrinking its unicode codepoint.

Shrinks towards `'\\0'`. `'\\0'` produces no shrunk values.
"""
function shrink(w::Char)
    c = codepoint(w)
    ret = Char[]
    c > 2 && push!(ret, c ÷ 2)
    c > 0 && push!(ret, c - 1)
    return ret
end

"""
    shrink(::String)

Shrinks a string by either dropping a character, or shrinking a character.

Shrinks towards the empty string, `""`. The empty string produces no shrunk values.
"""
function shrink(s::String)
    ret = String[]
    io = IOBuffer()
    for i in eachindex(s)
        head = @view s[begin:prevind(s, i)]
        tail = @view s[nextind(s, i):end]
        write(io, head)
        write(io, tail)
        push!(ret, String(take!(io)))

        shrinks = shrink(s[i])
        for sh in shrinks
            write(io, head)
            write(io, sh)
            write(io, tail)
            push!(ret, String(take!(io)))
        end
    end
    return ret
end

###########
# Vectors & Tuples
###########

# drop each index once
drops(root) = (deleteat!(deepcopy(root), i) for i in eachindex(root) if length(root) > 1)

# create all tuples with all identity, except for one place which we shrink
allFuncs(root) = (( i == idx ? shrink : (x -> [x]) for i in eachindex(root) ) for idx in eachindex(root))

# apply the shrinking functions and filter unsuccessful shrinks
shrunkEls(root) = ifilter((x -> !(any(isempty, x) || all(==(root), x))),
                    ((f(x) for (f,x) in zip(funcs, root)) for funcs in allFuncs(root)))

getProd(a, ::Type{<:Tuple}) = a
getProd(a, ::Type{<:Vector}) = [a...]
# we have a number of shrink results, take the product of all for all shrink combinations
prods(root::T) where T = flatten((getProd(p, T) for p in iproduct(shrunks...)) for shrunks in shrunkEls(root))

# finally, filter out productions that resulted back in the original root for efficiency
shrinks(root) = (ifilter(!=(root), prods(root)))

# combine with drops and we got lazy shrinks (～￣▽￣)～
# and we can reuse the methods for tuples as well
"""
    shrink(::Vector{T}) where T

Shrinks a vector by either dropping an element, or shrinking an element. Does not modify its input.

Shrinks towards the empty vector, `T[]`. The empty vector produces no shrunk values.
"""
shrink(rootEl::Vector) = iunique(flatten((drops(rootEl), shrinks(rootEl))))

"""
    shrink(::Tuple)

Shrinks a tuple by shrinking an element. The resulting tuples are alwas of the same length as the input tuple.
"""
shrink(rootEl::Tuple) = iunique(shrinks(rootEl))

#######
# Dict
#######

function copyset(dict, k, val)
    nd = copy(dict)
    nd[k] = val
    nd
end

"""
    shrink(::AbstractDict)

Shrinks a dictionary by shrinking keys, values and by dropping an entry.
The empty dictionary doesn't shrink.
"""
function shrink(d::T) where T <: AbstractDict
    # we have LOTS of ways to shrink a dict
    # - shrink keys
    # - shrink values
    # - drop entries
    ret = T[]

    for k in keys(d)
        # shrinking value
        for s in shrink(d[k])
            nd = copy(d)
            nd[k] = s
            push!(ret, nd)
        end

        # dropping
        nd = copy(d)
        delete!(nd, k)
        pushfirst!(ret, nd) # more likely to be useful

        # shrinking key
        for nk in shrink(k)
            nd = copy(nd)
            nd[nk] = d[k]
            push!(ret, nd)
        end
    end

    return ret
end
