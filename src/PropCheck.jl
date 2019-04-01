module PropCheck

using Test, Logging

export generate, specials, checkProp, argTypes, @check

getsig(f::Function) = map(b -> b.sig, methods(f).ms)
function argTypes(f::Function)
    filtered = filter(x -> !(x isa UnionAll) && !(Any in x.parameters), getsig(f))
    return map(x -> x.parameters[2:end], filtered)
end

function lenReduce(x, y)
    return x * length(y)
end

function genSpecialCases(types::NTuple{N, DataType}) where {N}
    specialCases = specials.(types)
    ncases = foldl(lenReduce, specialCases, init=1)
    cases = Matrix{Union{types...}}(undef, ncases, N)
    for i in axes(cases, 2)
        lenEach = (i == N) ? 1 : foldl(lenReduce, specialCases[i+1:end], init=1)
        cases[:,i] .= repeat(specialCases[i], inner = lenEach, outer = div(ncases, lenEach*length(specialCases[i])))
    end
    cases
end

function checkProp(prop::Function, types::NTuple{N, DataType}, ntests = 100) where {N}
    ret, caseSpec = checkSpecials(prop, types)
    !ret && return false, caseSpec
    ret, caseGen = checkGen(prop, types, ntests)
    !ret && return false, caseGen
    return true, nothing
end

function checkSpecials(prop::Function, types::NTuple{N, DataType}) where {N}
    specials = genSpecialCases(types)
    for case in axes(specials, 1)
        try
            !prop(specials[case,:]...) && return false, specials[case,:]
        catch ex
            return false, (ex, specials[case,:])
        end
    end
    return true, nothing
end

function checkGen(prop::Function, types::NTuple{N, DataType}, ntests) where {N}
    for _ in 1:ntests
        case = generate.(types)
        try
            !prop(case...) && return false, case
        catch ex
            return false, (ex, case)
        end
    end
    return true, nothing
end

macro check(func::Symbol, types, x...)
    quote
        local escf = $(esc(func))
        local res, case = checkProp($(esc(func)), $(esc(types)))
        case = case === nothing ? "✓" : case
        @testset "$(nameof(escf)): $case" begin
            @test res
        end
    end
end

generate(::Type{T}) where {T <: Number} = rand(T)
generate(::Type{T}) where {T} = error("No `generate` defined for $T")
generate(::Type{T}, n) where {T} = T[ generate(T) for _ in 1:n ]

specials(::Type{T}) where {T <: Signed} = T[zero(T), one(T), -one(T), typemax(T), typemin(T)]
specials(::Type{BigInt}) = BigInt[zero(BigInt),one(BigInt),-one(BigInt)]
specials(::Type{T}) where {T <: Unsigned} = T[zero(T), one(T), typemax(T)]
specials(::Type{T}) where {T <: AbstractFloat} = T[zero(T), one(T), typemax(T), typemin(T), zero(T) / zero(T)]
specials(::Type{T}) where {T} = T[generate(T)]

end # module
