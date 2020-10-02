using Test
using PropCheck

function numsToZero(T)
    @forall(generate(T), x -> begin
        x < 0 ? shrink(x) < 0 : shrink(x) >= 0
    end)
end

function numsNotSkipping(T)
    target = generate(T)
    failed, res = @forall(generate(T), x -> x != target)
    if !failed
        target == res, nothing
    else
        false, res
    end
end

@testset "All Tests" begin
    @testset "Shrinking" for T in (UInt64, UInt32, UInt16, UInt8, Float64, Float32, Float16)
        @check numsToZero(T)
        @check numsNotSkipping(T)
    end
end