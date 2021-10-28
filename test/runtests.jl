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

"""
Tests that when a given predicate holds for the parent, it also holds for its subtrees (or at least the first 100).
"""
function predicateHoldsForSubtrees(p, T)
    g = filter(p, igen(T))
    toCheck = (first(g) for _ in 1:numTests[])
    all(toCheck) do x
        all(p ∘ root, Iterators.take(subtrees(x), 100))
    end
end

function throwingProperty(x)
    if x < 5
        return true
    else
        throw(ArgumentError("x not smaller than 5"))
    end
end

const numTypes = union(getSubtypes(Integer), getSubtypes(AbstractFloat), (Float64, Float32, Float16))

@testset "All Tests" begin
    @testset "numsToZero" begin
        @testset "$T" for T in numTypes
            @test numsToZero(T) broken=(T == BigInt || T <: AbstractFloat)
        end
    end
    @testset "filter predicates hold for shrunk values" begin
        for p in (iseven, isodd)
            @testset "$p($T)" for T in (UInt8, UInt16, UInt32, UInt64)
                @test predicateHoldsForSubtrees(p, T) broken=(T == BigInt || T <: AbstractFloat)
            end
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
end
