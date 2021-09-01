using Test
using PropCheck
using PropCheck: getSubtypes

"""
Tests the fallback shrinking for numbers to shrink towards zero.
"""
function numsToZero(T)
    # are there other properties of the shrinkers themselves we can test?
    check(Integrated(Generator(T))) do x
        shrunks = shrink(x)
        if x == zero(T)
            isempty(shrunks)
        else
            !isempty(shrunks) && all( y -> zero(T) <= abs(y) < abs(x), shrunks)
        end
    end
end

@testset "All Tests" begin
    @testset "numsToZero" begin
        @testset "$T" for T in union(getSubtypes(Integer), getSubtypes(AbstractFloat), (Float64, Float32, Float16))
            @test numsToZero(T) broken=(T == BigInt || T <: AbstractFloat)
        end
    end
end