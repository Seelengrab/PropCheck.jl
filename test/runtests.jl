using Test
using PropCheck
using PropCheck: getSubtypes, numTests, Tree
using RequiredInterfaces: RequiredInterfaces
const RI = RequiredInterfaces

"""
Tests the fallback shrinking for numbers to shrink towards zero.
"""
function numsToZero(T)
    # are there other properties of the shrinkers themselves we can test?
    # there are a lot of numbers, so crank up the tests
    check(itype(T); ntests=10_000) do x
        shrunks = shrink(x)
        if iszero(x) || isnan(x) || isinf(x)
            isempty(shrunks)
        else
            if !isempty(shrunks)
                # abs(Int8(-128)) === Int8(-128)
                x == typemin(x) || all( y -> zero(T) <= abs(y) < abs(x), shrunks)
            else
                false
            end
        end
    end
end

function stringsFromTypeToEmpty()
    @test check(itype(String)) do str
        shrunks = shrink(str)
        if isempty(str)
            isempty(shrunks)
        else
            !isempty(str) && all(shrunks) do shr
                length(shr) < length(str) ||
                count(Base.splat(!=), zip(str, shr)) == 1
            end
        end
    end
end

function interleaveFilterInvariant()
    s = filter(l->length(l)>=5, PropCheck.vector(isample(0:10), itype(UInt8)), true)
    res = check(s) do s2
        length(s2) < 5
    end
    @test res == zeros(UInt8, 5)
end

function interleaveMapInvariant()
    s = map(l -> push!(l, 0x0), PropCheck.vector(isample(0:2), itype(UInt8)))
    res = check(s) do s2
        !isempty(s2) && last(s2) != 0x0
    end
    @test res == [0x0]
end

function initialVectorLengthIsBoundedByRange()
    i = PropCheck.vector(isample(5:10), itype(Int8))
    @test check(i) do v
        5 <= length(v) <= 10
    end
end

"""
Tests that when a given predicate holds for the parent, it also holds for its subtrees (or at least the first 100).
"""
function predicateHoldsForSubtrees(p, T)
    g = filter(p, itype(T))
    toCheck = Iterators.filter(!isnothing, Iterators.take(g, numTests[]))
    checkedValues = false
    res = all(toCheck) do x
        checkedValues = true
        all(p ∘ root, Iterators.take(subtrees(x), 100))
    end
    checkedValues && res
end

guaranteeEven(x) = div(x,0x2)*0x2

function mappedGeneratorsObserveProperty(T)
    g = map(guaranteeEven, itype(T))
    toCheck = Iterators.filter(!isnothing, Iterators.take(g, numTests[]))
    checkedValues = false
    res = all(toCheck) do x
        checkedValues = true
        all(iseven ∘ root, Iterators.take(subtrees(x), 100))
    end
    checkedValues && res
end

function throwingProperty(x)
    if x < 5
        return true
    else
        throw(ArgumentError("x not smaller than 5"))
    end
end

function floatTear(T, x)
    x === PropCheck.assemble(T, PropCheck.tear(x)...)
end

const numTypes = union(getSubtypes(Integer), getSubtypes(AbstractFloat))

@time @testset "All Tests" begin
    @testset "Interfaces" begin
        RI.check_implementations(PropCheck.AbstractIntegrated)
        extent_types = filter!(!=(PropCheck.IntegratedVal), RI.nonabstract_subtypes(PropCheck.ExtentIntegrated))
        RI.check_implementations(PropCheck.ExtentIntegrated, extent_types)
        # only this type implements extent
        num_ival = PropCheck.IntegratedVal{PropCheck.Tree{Number}}
        @test RI.check_interface_implemented(PropCheck.ExtentIntegrated, num_ival)
    end
    @testset "Tear $T & reassemble" for T in getSubtypes(Base.IEEEFloat)
        @test check(x -> floatTear(T, x), itype(T))
        @testset "Special numbers: $x)" for x in (Inf, -Inf, NaN, -0.0, 0.0)
            @test floatTear(T, T(x))
        end
    end
    @testset "numsToZero" begin
        @testset "$T" for T in numTypes
            @test numsToZero(T) broken=(T == BigInt || T == BigFloat)
        end
    end
    @testset "filter predicates hold for shrunk values" begin
        for p in (iseven, isodd)
            @testset "$p($T)" for T in (UInt8, UInt16, UInt32, UInt64)
                @test predicateHoldsForSubtrees(p, T)
            end
        end
    end
    @testset "shrunk values of mapped generator are also even" begin
        @testset "mappedGeneratorsObserveProperty($T)" for T in (UInt8, UInt16, UInt32, UInt64)
            @test mappedGeneratorsObserveProperty(T)
        end
    end
    @testset "random vectors are sorted" begin
        @test check(issorted, PropCheck.vector(isample(0:10), itype(UInt8))) == [0x1, 0x0]
    end
    @testset "all even numbers are less than 5" begin
        @test check(<(5), filter(iseven, itype(UInt8))) == 0x6
    end
    @testset "there are only even numbers" begin
        @test check(iseven, itype(UInt8)) == 0x1
    end
    @testset "throwing properties still shrink" begin
        @test check(throwingProperty, itype(UInt8)) == (0x05, ArgumentError("x not smaller than 5"))
    end
    @testset stringsFromTypeToEmpty()
    @testset "interleave preserves invariants" begin
        @testset interleaveFilterInvariant()
        @testset interleaveMapInvariant()
    end
    @testset initialVectorLengthIsBoundedByRange()
    @testset "`Integrated` can be `collect`ed" begin
        @test all(x -> x isa Tree{Int}, collect(Iterators.take(itype(Int), 5)))
    end
    @testset "convert Trees: $T" for (f,T) in (((x -> x % 0x3), Int8),
                                               ((x -> x %   3), Int))
        t = map(f, itype(Int8))
        itr = Iterators.take(t, 5)
        @test eltype(itr) == Tree{T}
        @test eltype(collect(itr)) == Tree{T}
    end
    @testset "type unstable constructors" begin
        grade = map(Base.splat(Pair), PropCheck.interleave(itype(String), isample(0:100)))
        # it's type unstable because the empty dispatch returns `Dict{Any,Any}`!
        # I'd love to propagate the lowerbound of `1` to make this type stable, but that is hard.
        # maybe that needs dependent types?
        gradegen = map(Base.splat(Dict), PropCheck.tuple(isample(0:10), grade))
        @test eltype(gradegen) == Union{PropCheck.Tree{Dict{Any, Any}}, PropCheck.Tree{Dict{String, Int64}}}
    end
    @testset "$f preserves invariants" for f in (PropCheck.str, PropCheck.vector)
        # 3 hex characters is plenty - this is already 3^11 == 177147 possible strings
        # of couse, it would be better to generate some variations, but.. CI time is not fixing
        # & writing code time ¯\_(ツ)_/¯ Plus, I like to be able to test my code locally in a reasonable time
        strlen = 3
        strgen = f(iconst(strlen), isample('a':'f'))
        work = [generate(strgen)]
        res = false
        while !isempty(work)
            cur = pop!(work)
            res |= strlen == length(root(cur))
            !res && (@test root(cur); break)
            append!(work, subtrees(cur))
        end
        @test res
    end
end
