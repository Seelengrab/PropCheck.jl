using Test
using PropCheck
using PropCheck: getSubtypes, numTests

"""
Tests the fallback shrinking for numbers to shrink towards zero.
"""
function numsToZero(T)
    # are there other properties of the shrinkers themselves we can test?
    check(igen(T)) do x
        shrunks = shrink(x)
        if x == zero(T)
            isempty(shrunks)
        else
            !isempty(shrunks) && all( y -> zero(T) <= abs(y) < abs(x), shrunks)
        end
    end
end

function stringsFromTypeToEmpty()
    @test check(igen(String)) do str
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
    s = filter(l->length(l)>=5, PropCheck.str(igen(0xa)), true)
    i = interleave(s,s)
    res = check(i) do ((_,s2))
        length(s2)<5
    end
    @test res == ('\0'^5, '\0'^5)
end

function interleaveMapInvariant()
    s = map(l -> l*'\0', PropCheck.str(igen(0x2)))
    i = interleave(s,s)
    res = check(i) do ((_,s2))
        !isempty(s2) && last(s2)!='\0'
    end
    @test res == ("\0","\0")
end

function vectorLengthIsBoundedByRange()
    i = PropCheck.vector(igen(5:10), igen(Int8))
    res = check(i) do v
        length(v) != 5
    end
    @test res == zeros(Int8, 5)
end

"""
Tests that when a given predicate holds for the parent, it also holds for its subtrees (or at least the first 100).
"""
function predicateHoldsForSubtrees(p, T)
    g = filter(p, igen(T))
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
    g = map(guaranteeEven, igen(T))
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

const numTypes = union(getSubtypes(Integer), getSubtypes(AbstractFloat))

@testset "All Tests" begin
    @testset "numsToZero" begin
        @testset "$T" for T in numTypes
            @test numsToZero(T) broken=(T == BigInt || T <: AbstractFloat)
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
        @test check(issorted, PropCheck.vector(igen(20), igen(UInt8))) == [0x1, 0x0]
    end
    @testset "all even numbers are less than 5" begin
        @test check(<(5), filter(iseven, igen(UInt8))) == 0x6
    end
    @testset "there are only even numbers" begin
        @test check(iseven, igen(UInt8)) == 0x1
    end
    @testset "throwing properties still shrink" begin
        @test check(throwingProperty, igen(UInt8)) == (0x05, ArgumentError("x not smaller than 5"))
    end
    @testset stringsFromTypeToEmpty()
    @testset "interleave preserves invariants" begin
        @testset interleaveFilterInvariant()
        @testset interleaveMapInvariant()
    end
    @testset vectorLengthIsBoundedByRange()
end
