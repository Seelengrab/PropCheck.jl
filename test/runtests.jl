using Test
using PropCheck
using PropCheck: getSubtypes, numTests, Tree

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

@testset "All Tests" begin
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
        @test check(issorted, PropCheck.vector(iconst(20), itype(UInt8))) == [0x1, 0x0]
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
    @testset "convert Trees" begin
        t = map(x -> x % 3, itype(Int8))
        itr = Iterators.take(t, 5)
        @test eltype(itr) == Tree{Int8}
        @test eltype(collect(itr)) == Tree{Int8}
        t = map(x -> x % 3, itype(Int8), Int)
        itr = Iterators.take(t, 5)
        @test eltype(itr) == Tree{Int}
        @test eltype(collect(itr)) == Tree{Int}
    end
end
