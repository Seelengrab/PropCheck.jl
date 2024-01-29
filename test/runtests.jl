using Test

using PropCheck
using PropCheck: getsubtypes, numTests, Tree
const PC = PropCheck

using RequiredInterfaces: RequiredInterfaces
const RI = RequiredInterfaces

using Random: default_rng, randperm

@info "RNG state is:" RNG=copy(default_rng())

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
    s = filter(l->length(l)>=5, PC.vector(isample(0:10), itype(UInt8)), true)
    res = check(s) do s2
        length(s2) < 5
    end
    @test res == zeros(UInt8, 5)
end

function interleaveMapInvariant()
    s = map(l -> push!(l, 0x0), PC.vector(isample(0:2), itype(UInt8)))
    res = check(s) do s2
        !isempty(s2) && last(s2) != 0x0
    end
    @test res == [0x0]
end

function initialVectorLengthIsBoundedByRange()
    i = PC.vector(isample(5:10), itype(Int8))
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
    x === PC.assemble(T, PC.tear(x)...)
end

function assembleInf(T)
    check(itype(Bool)) do b
        inttype = PC.uint(T)
        f = PC.assemble(T, inttype(b), typemax(inttype), zero(inttype))
        b == signbit(f)
    end
end

const numTypes = union(getsubtypes(Integer), getsubtypes(AbstractFloat))

@time @testset "All Tests" begin
    @testset "Interfaces" begin
        RI.check_implementations(PC.AbstractIntegrated)
        extent_types = filter!(!=(PC.IntegratedVal), RI.nonabstract_subtypes(PC.ExtentIntegrated))
        RI.check_implementations(PC.ExtentIntegrated, extent_types)
        # only this type implements extent
        num_ival = PC.IntegratedVal{PC.Tree{Number}}
        @test RI.check_interface_implemented(PC.ExtentIntegrated, num_ival)
    end
    @testset "Tear $T & reassemble, floating point generators" for T in getsubtypes(Base.IEEEFloat)
        @testset "assembleInf" begin
            assembleInf(T)
        end
        @test check(x -> floatTear(T, x), itype(T))
        @test check(isinf, PC.ifloatinf(T); transform=bitstring)
        @test check(isnan, PC.ifloatnan(T); transform=bitstring)
        @test check(PC.ifloatinfnan(T); transform=bitstring) do v
            isnan(v) | isinf(v)
        end
        @test check(PC.ifloat(T)) do v
            !(isnan(v) | isinf(v))
        end
        @testset "Special numbers: $x)" for x in (Inf, -Inf, NaN, -0.0, 0.0)
            @test floatTear(T, T(x))
        end
    end
    @testset "Integer generators" begin
        @testset for T in (getsubtypes(Base.BitSigned))
            @test check(>=(zero(T)), PC.iposint(T))
            @test check(<(zero(T)), PC.inegint(T))
        end
    end
    @testset "numsToZero" begin
        @testset "$T" for T in numTypes
            if VERSION >= v"1.7"
                @test numsToZero(T) broken=(T == BigInt || T == BigFloat)
            else
                if T != BigInt && T != BigFloat
                    @test numsToZero(T)
                end
            end
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
        @test check(issorted, PC.vector(isample(0:10), itype(UInt8))) == [0x1, 0x0]
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
    @testset "stringsFromTypeToEmpty" begin
        stringsFromTypeToEmpty()
    end
    @testset "interleave preserves invariants" begin
        @testset "interleaveFilterInvariant" begin
            interleaveFilterInvariant()
        end
        @testset "interleaveMapInvariant" begin
            interleaveMapInvariant()
        end
    end
    @testset "initialVectorLengthIsboundedByRange" begin
        initialVectorLengthIsBoundedByRange()
    end
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
    if VERSION >= v"1.9"
        # this sadly doesn't infer before then, so we can't really test it :/
        @testset "type unstable constructors" begin
            grade = map(Base.splat(Pair), PC.interleave(itype(String), isample(0:100)))
            # it's type unstable because the empty dispatch returns `Dict{Any,Any}`!
            # I'd love to propagate the lowerbound of `1` to make this type stable, but that is hard.
            # maybe that needs dependent types?
            gradegen = map(Base.splat(Dict), PC.tuple(isample(0:10), grade))
            @test eltype(gradegen) == Union{PC.Tree{Dict{Any, Any}}, PC.Tree{Dict{String, Int64}}}
        end
    end
    @testset "$f preserves invariants" for f in (PC.str, PC.vector)
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
    @testset "IntegratedUnique" begin
        colgen = PC.vector(isample(0:10), itype(Int8))
        # Taking as many elements as the source collection has
        # produces the source collection again
        @test check(colgen) do col
            iu = PC.IntegratedUnique(copy(col), shrink)
            sort!(col)
            iucol = sort!(map(root, Iterators.take(iu, length(col))))
            firstiteration =  all(Base.splat(==), zip(col, iucol))
            iucol = sort!(map(root, Iterators.take(iu, length(col))))
            seconditeration =  all(Base.splat(==), zip(col, iucol))
            iucol = sort!(map(root, Iterators.take(iu, length(col))))
            thirditeration =  all(Base.splat(==), zip(col, iucol))
            firstiteration && seconditeration && thirditeration
        end
    end
    @testset "IntegratedConst" begin
        valgen = itype(Int8)
        # Only & exactly the root is produced, without shrunk values
        @test check(valgen) do v
            genv = generate(iconst(v))
            v == root(genv) && isempty(subtrees(genv))
        end
    end
    @testset "IntegratedVal" begin
        valgen = itype(Int8)
        shrinkgen = iunique([shrink, PC.noshrink], PC.noshrink)
        constgen = interleave(valgen, shrinkgen)
        # The root is always the given element
        @test check(constgen) do (v, s)
            genv = generate(PC.ival(v, s))
            v == root(genv)
        end
        # The shrunk values of the root are consistent with the given shrinking function
        @test check(constgen) do (v, s)
            genv = generate(PC.ival(v, s))
            shrunks = sort!(s(v))
            gensubs = sort!(map(root, subtrees(genv)))
            length(shrunks) == length(gensubs) && all(Base.splat(==), zip(shrunks, gensubs))
        end
    end
    @testset "FiniteIntegrated" begin
    @testset "IntegratedOnce" begin
        valgen = itype(Int8)
        # The value will only be generated exactly once
        @test check(valgen) do v
            gen = PC.IntegratedOnce(v)
            v == root(generate(gen)) && isnothing(generate(gen))
        end
    end
    @testset "IntegratedFiniteIterator" begin
        function integratedFinitePreservesLength(itr)
            # generation preserves the length
            ifi = PC.IntegratedFiniteIterator(itr)
            length(itr) == length(ifi)
        end

        function integratedFinitePreservesOrder(itr)
            # generation preserves the original iteration order
            ifi = PC.IntegratedFiniteIterator(itr)
            # `iterate` calls `generate`
            all(zip(itr, ifi)) do (a,b)
                a == root(b)
            end
        end

        function integratedFiniteGetsExhausted(itr)
            # After `length(itr)` calls to `generate`, the shrinker is exhausted
            ifi = PC.IntegratedFiniteIterator(itr)
            for _ in 1:length(itr)
                generate(ifi)
            end
            Base.isdone(ifi) && generate(ifi) === nothing
        end

        lengen = isample(0:10)
        elgen = itype(Int8)
        vecgen = PC.vector(lengen, elgen)
        tupgen = PC.tuple(lengen, elgen)

        @testset for prop in (integratedFinitePreservesLength,
                              integratedFinitePreservesOrder,
                              integratedFiniteGetsExhausted)
            @testset for gen in (vecgen, tupgen)
                @test check(prop, gen)
            end
        end
    end
    @testset "IntegratedLengthBounded" begin
        function givenLengthCorrectForInfinite(len)
            gen = PC.IntegratedLengthBounded(itype(Int8), len)
            all(zip(gen, 1:(len+1))) do (genval, counter)
                if counter > len
                    genval isa Nothing
                else
                    genval isa Tree{Int8}
                end
            end
        end

        function givenLengthUpperboundForFinite(len)
            targetLen = div(len, 2) + 1
            sourceels = rand(Int8, targetLen)
            elgen = PC.IntegratedFiniteIterator(sourceels)
            gen = PC.IntegratedLengthBounded(elgen, len)
            all(zip(gen, 1:max(targetLen, len))) do (genval, counter)
                if counter > min(targetLen, len)
                    genval isa Nothing
                else
                    genval isa Tree{Int8} && sourceels[counter] == root(genval)
                end
            end
        end

        @test check(givenLengthCorrectForInfinite, isample(0:20))
        @test check(givenLengthUpperboundForFinite, isample(0:20))
    end
    gens = [
        PC.IntegratedOnce(6),
        PC.IntegratedFiniteIterator(1:11),
        PC.IntegratedLengthBounded(PC.iposint(Int8), 5)
    ]
    @testset for gen in gens
        @testset "`filter` FiniteIntegrated" begin
            @test check(isodd, filter(isodd, gen))
        end
        @testset "`map` FiniteIntegrated" begin
            mgen = map(gen) do v
                v, sqrt(v)
            end
            @test check(mgen) do (a,b)
                sqrt(a) ≈ b
            end
        end
    end
    @testset "`interleave` FiniteIntegrated" begin
        @testset "IntegratedOnce" begin
            gen = PC.IntegratedOnce(6)
            woven = interleave(gen, deepcopy(gen))
            @test begin
                res = generate(woven)
                res isa Tree{Tuple{Int, Int}} && root(res) == (6,6)
            end
            @test generate(woven) isa Nothing
        end
        @testset "IntegratedFiniteIterator" begin
            src = 1:11
            gen = PC.IntegratedFiniteIterator(src)
            woven = interleave(gen, deepcopy(gen))
            for i in src
                res = generate(woven)
                @test res isa Tree{Tuple{Int, Int}} && root(res) == (i,i)
            end
            @test generate(woven) isa Nothing
        end
        @testset "IntegratedLengthBounded" begin
            bound = PC.iposint(Int8)
            @test check(bound) do v
                gen = PC.IntegratedLengthBounded(itype(Int8), v)
                woven = interleave(gen, deepcopy(gen))
                count(woven) do t
                    t isa Tree{Tuple{Int8, Int8}}
                end == v && generate(woven) isa Nothing
            end
        end
    end
    @testset "`check` on finite integrated reaches second generated value" begin
        gen = PC.IntegratedFiniteIterator(1:2)
        @test check(gen) do v
            v != 2
        end == 2
    end
    end
    @testset "IntegratedBoundedRec" begin
        @testset "Regular repeated generation" begin
            irb = PC.IntegratedBoundedRec(10, itype(Int8))
            irbvec = PC.vector(isample(10:20), irb)
            @test check(irbvec) do v
                length(v) >= 10 && all(v) do e
                    e isa Int8
                end
            end
        end
        @testset "Mutually recursive generation" begin
            # This is _incredibly_ awkward to test!
            foocount_correct(s) = 2*count(==('f'), s) == count(==('o'), s)
            @testset "with Choice" begin
                irb = PC.IntegratedBoundedRec{String}(10);
                a = map(join, interleave(ival("foo", PC.noshrink), irb))
                b = PC.IntegratedChoice(a, a, a, a, a, ival("bar", PC.noshrink))
                PC.bind!(irb, b)
                @test check(foocount_correct, b)
            end
            @testset "map" begin
                irc = PC.IntegratedBoundedRec{String}(10);
                rec = map(join, interleave(iconst("foo"), irc))
                c = map(interleave(rec, iconst("bar"))) do t
                    t = join(t)
                    t[randperm(length(t))]::String
                end
                PC.bind!(irc, c)
                @test_broken check(foocount_correct, c)
            end
            @testset "interleave" begin
                ird = PC.IntegratedBoundedRec{Any}(5);
                red = PC.IntegratedChoice(ird, iconst("foo"))
                d = interleave(red, iconst("bar"))
                PC.bind!(ird, d)
                @test check(foocount_correct, d)
            end
        end
    end
    @testset "Inference" begin
        @testset for gen in (
                itype(Int8), PC.iposint(Int8), PC.inegint(Int8),
                PC.ifloat(Float16), PC.ifloatinf(Float16), PC.ifloatnan(Float16),
                )
            @test @inferred(generate(gen)) isa PC.Tree
        end
    end
end
