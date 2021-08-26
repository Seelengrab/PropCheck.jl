generate(::Bool) = rand(Bool)
generate(::Type{Bool}) = rand(Bool)
const mBool = Generator(Bool)
function shrink(t::Bool)
    if t
        return Bool[false]
    else
        return Bool[]
    end
end

struct Word
    hi::UInt
end
generate(w::Word) = Word(rand(0:w.hi))
generate(::Type{Word}) = Word(rand(UInt))
const mWord(w) = Generator(Word(w))
function shrink(w::Word)
    ret = Word[]
    w.hi > 0x2 && push!(ret, Word(w.hi ÷ 0x2))
    w.hi > 0x0 && push!(ret, Word(w.hi - 0x1))
    return ret
end

# shrinks an unsigned value by half and one less
function shrink(w::T) where T <: Unsigned
    ret = T[]
    w > 0x2 && push!(ret, w ÷ 0x2)
    w > 0x0 && push!(ret, w - 0x1)
    return ret
end

# shrinks a signed value by shrinking its absolute value like an unsigned
function shrink(w::T) where T <: Signed
    ret = T[]
    w >  2 && push!(ret, w ÷ 2, -(w ÷ 2))
    w >  0 && push!(ret, w - 1, -(w - 1))
    w <  0 && push!(ret, w + 1, -(w + 1))
    w < -2 && push!(ret, w ÷ 2, -(w ÷ 2))
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