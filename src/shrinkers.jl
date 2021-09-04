# Shrinking functions for default data types


# shrinks `true` to `Bool[false]`` and `false` to `Bool[]`
function shrink(t::Bool)
    if t
        return Bool[false]
    else
        return Bool[]
    end
end

# shrinks an unsigned value by half and one/two less, since we don't want to miss 0 when only generating even numbers
function shrink(w::T) where T <: Unsigned
    ret = T[]
    w > 0x2 && push!(ret, w ÷ 0x2, w - 0x2)
    w > 0x0 && push!(ret, w - 0x1)
    return ret
end

# shrinks a signed value by shrinking its absolute value like an unsigned
function shrink(w::T) where T <: Signed
    ret = T[]
    w ==  2 && push!(ret, zero(T))
    w >   2 && push!(ret, w ÷ 2, -(w ÷ 2))
    w >   0 && push!(ret, w - 1, -(w - 1), w - 2, -(w - 2))
    w <   0 && push!(ret, w + 1, -(w + 1), w + 2, -(w + 2))
    w <  -2 && push!(ret, w ÷ 2, -(w ÷ 2))
    w == -2 && push!(ret, zero(T))
    return unique!(ret)
end

# shrinks a character by shrinking its codepoint 
function shrink(w::Char)
    c = codepoint(w)
    ret = Char[]
    c > 2 && push!(ret, c ÷ 2)
    c > 0 && push!(ret, c - 1)
    return ret
end

# drops a character and shrinks a character to form new strings
function shrink(s::String)
    ret = String[]
    io = IOBuffer()
    pio(s) = print(io, s)
    for i in eachindex(s)
        head = @view s[begin:i-1]
        tail = @view s[i+1:end]
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
allFuncs(root) = (( i == idx ? shrink : (x -> [x]) for i in 1:length(root) ) for idx in eachindex(root))

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
shrink(rootEl::Vector) = iunique(flatten((drops(rootEl), shrinks(rootEl))))
# and we can reuse the methods for tuples as well
shrink(rootEl::Tuple) = iunique(shrinks(rootEl))