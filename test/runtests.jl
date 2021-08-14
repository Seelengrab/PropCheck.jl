using Test
using PropCheck

"""
Tests the fallback shrinking for numbers to shrink towards zero.
"""
function numsToZero(T)
    @forall(generate(T), x -> begin
        if x == zero(T)
            shrink(x) == zero(T)
        elseif x < zero(T)
            x < shrink(x) <= zero(T)
        else
            x > shrink(x) >= zero(T)
        end
    end)
end

function numsNotSkipping(T)
    target = generate(T)
    _, res = @forall(generate(T), x -> x != target)
    if target == res
        true, nothing
    else
        false, (target,res)
    end
end

function arraysToEmpty()
    @forall(generate(T), x -> begin
        shrunk = shrink(x)
        if isempty(x)
            length(x) == length(shrunk) == 0
        else
            length(x) > length(shrunk)
        end
    end)
end

@testset "All Tests" begin
    @testset "Macro expansions" begin
        # TODO: write tests for the expansion
    end
    @testset "Shrinking Numbers" begin
        @check for T in union(subtypes(Unsigned), subtypes(AbstractFloat), (Float64, Float32, Float16))
            numsToZero(T)
            numsNotSkipping(T)
        end
    end
end