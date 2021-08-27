using Test
using PropCheck
using PropCheck: getSubtypes

"""
Tests the fallback shrinking for numbers to shrink towards zero.
"""
function numsToZero(T)
    check(Integrated(Generator(T)), x -> begin
        shrunks = shrink(x)
        if x == zero(T)
            isempty(shrunks)
        else
            !isempty(shrunks) && all( y -> zero(T) <= abs(y) < abs(x), shrunks)
        end
    end)
end

function noSkipping(T)
    gen = Generator(T)
    target = generate(gen)
    check(Integrated(gen), !=(target))
end

@testset "All Tests" begin
    @testset "$f" for f in (numsToZero, noSkipping)
        @testset "$T" for T in union(getSubtypes(Integer), getSubtypes(AbstractFloat), (Float64, Float32, Float16))
            @test f(T)
        end
    end
end