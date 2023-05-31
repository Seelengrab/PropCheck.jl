# Shrinking functions for default data types

####
# shrink
#####

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

uint(::Type{Float16}) =      UInt16
uint(::     Float16)  = zero(UInt16)
uint(::Type{Float32}) =      UInt32
uint(::     Float32)  = zero(UInt32)
uint(::Type{Float64}) =      UInt64
uint(::     Float64)  = zero(UInt64)
fracsize(::Type{Float16}) = 10
fracsize(::Type{Float32}) = 23
fracsize(::Type{Float64}) = 52
exposize(::Type{Float16}) = 5
exposize(::Type{Float32}) = 8
exposize(::Type{Float64}) = 11

function masks(T::DataType)
    ui = uint(T)
    signbitmask = one(ui) << (8*sizeof(ui)-1)
    fracbitmask =  (-1 % ui) >> (8*sizeof(ui)-fracsize(T))
    expobitmask = ((-1 % ui) >> (8*sizeof(ui)-exposize(T))) << fracsize(T)
    signbitmask, fracbitmask, expobitmask
end

function assemble(T, sign, expo, frac)
    ret = (sign << (exposize(T) + fracsize(T))) | (expo << fracsize(T)) | frac
    return reinterpret(T, ret)
end

function tear(x::T) where T <: AbstractFloat
    signbitmask, fracbitmask, expobitmask = masks(T)
    ur = reinterpret(uint(T), x)
    s = (ur & signbitmask) >> (exposize(T) + fracsize(T))
    e = (ur & expobitmask) >>                fracsize(T)
    f = (ur & fracbitmask) >>                        0x0
    return (s, e, f)
end

"""
    shrink(::T) where T <: AbstractFloat

Shrinks an `AbstractFloat`.

Shrinks towards `iszero(T)`. `Inf`, `NaN` and `zero(T)` produce no shrunk values.
Positive numbers produce their negative counterparts.
"""
function shrink(r::T) where T <: AbstractFloat
    (isinf(r) || isnan(r) || iszero(r)) && return T[]
    os,oe,of = tear(r)
    signbits = shrink(os)
    expobits = shrink(oe)
    fracbits = shrink(of)
    push!(signbits, os)
    push!(expobits, oe)
    push!(fracbits, of)
    # return all shrunks, only the sign changed
    # otherwise we get a shrinking loop
    return [ assemble(T, s, e, f) for s in signbits for e in expobits for f in fracbits
                if !(f == of && e == oe) ]
end

###########
# Vectors & Tuples
###########

# combine with drops and we got lazy shrinks (～￣▽￣)～
# and we can reuse the methods for tuples as well
"""
    shrink(::Vector{T}) where T

Shrinks a vector by either dropping an element, or shrinking an element. Does not modify its input.

Shrinks towards the empty vector, `T[]`. The empty vector produces no shrunk values.
"""
shrink(rootEl::Vector) = iunique(flatten((drops(rootEl), shrinks(shrink, rootEl))))

"""
    shrink(::Tuple)

Shrinks a tuple by shrinking an element. The resulting tuples are always of the same length as the input tuple.
"""
shrink(rootEl::Tuple) = iunique(shrinks(shrink, rootEl))

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
            nd = copyset(d, k, s)
            push!(ret, nd)
        end

        # dropping
        nd = copy(d)
        delete!(nd, k)
        pushfirst!(ret, nd) # more likely to be useful

        # shrinking key
        val = d[k]
        for nk in shrink(k)
            nd = copyset(nd, nk, val)
            push!(ret, nd)
        end
    end

    return ret
end

######
# Ranges
######

"""
    shrink(::AbstractRange)

Shrinks a range by splitting it in two in the middle. Ranges containing only one element
or less don't shrink.
"""
function shrink(r::T) where T <: AbstractRange
    ret = T[]
    length(r) <= 1 && return ret
    middle = Base.midpoint(firstindex(r), lastindex(r))
    push!(ret, r[begin:middle])
    push!(ret, r[middle+1:end])
    ret
end

#######
# shrinkTowards
######

"""
    shrinkTowards(to::T) -> (x::T -> T[...])

Constructs a shrinker function that shrinks given values towards `to`.
"""
function shrinkTowards end

function shrinkTowards(to::T) where T <: Union{Char, Real}
    function (x::T)
        ret = T[]
        to == x && return ret
        diff = div(x, 2) - div(to, 2)
        while diff != 0
            pval = x - diff
            push!(ret, x - diff)
            diff = div(diff, 2)
        end
        (isempty(ret) || first(ret) != to) && pushfirst!(ret, to)
        return ret
    end
end

function shrinkTowards(to::T) where T <: AbstractFloat
    function (x::T)
        ret = T[]
        to == x && return ret
        diff = x - to
        while !iszero(diff)
            diff /= 2.0
            y = (x - diff)
            (isnan(y/x) || isinf(y/x)) && break
            !isempty(ret) && y == last(ret) && break
            push!(ret, y)
        end
        (isempty(ret) || first(ret) != to) && pushfirst!(ret, to)
        return ret
    end
end

shrinkTowards(to::Bool) = function (x::Bool)
    to == x && return Bool[]
    !to && x && return [false]
    to && !x && return Bool[]
end

"""
    noshrink(_::T) -> T[]

A shrinker that doesn't shrink its arguments.
"""
noshrink(::T) where T = T[]