module PropCheck

using Test
using InteractiveUtils: subtypes

export generate, @check, @forall, @suchthat, @set, shrink

"""
Total number of tries to generate an element using [`@suchthat`](@ref).
"""
const nGenTries = Ref(100)

"""
Total number of times a given usage of [`@forall`](@ref) tries to find a falsifying case.
"""
const nTests = Ref(100)

"""
Total number of shrinks attempted during the shrinking.
"""
const nShrinks = Ref(1000)

"""
Probability of dropping an element of an arraylike during shrinking.
"""
const dropChance = Ref(0.5)

"""
    @suchthat(bin, generator, condition[, tries])
    @suchthat(N, generate(Int), x -> ...)
    @suchthat(N, () -> generate(Int), ==(N))
    @suchthat((N,M), (generate(Int),generate(Int)), !=, 500)

Tries to generate elements via the given generator(s) until the condition is satisfied. The condition has to return a boolean.
Returns the element that's satisfying the condition or throws an error if after `tries` no satisfying element could be generated.
"""
macro suchthat(bin, gen, cond, tries=nGenTries[])
    condArgs = cond.args[1] isa Symbol ? bin : :($bin...)
    generator = gen isa Symbol || (gen isa Expr && gen.head == :->) ? :($gen()) :
                (gen isa Expr && (gen.head == :call || gen.head == :tuple)) ? gen :
                :(() -> error("The given generator does not look like a callable or a function call."))

    return esc(quote
        $bin = $generator
        for i in 1:$tries
            i == $tries && error("Couldn't find a workable case in $i tries.")
            
            $cond($condArgs) && break
            $bin = $generator
        end
        $bin
    end)
end

"""
    @set(N, generate(Int), N*2)

Generates values from the given generators and applies the expression `expr` on them. Leaks definitions into the containing scope!
"""
macro set(bin, gen, expr)
    # TODO: Find out if this macro is really necessary, seems like a trivial transform?
    generator = gen isa Symbol || (gen isa Expr && gen.head == :->) ? :($gen()) :
                gen isa Expr && gen.head == :call ? gen :
                :(() -> error("The given generator does not look like a callable or a function call."))

    esc(quote
        $bin = $generator
        $bin = $expr
    end)
end

"""
    @forall(generate(Int), x -> (x == x), nTests=PropCheck.nTests[])
    @forall((generate(Int), generate(Int)), x -> (x == x), nTests=PropCheck.nTests[])
    @forall((generate(Int), generate(Int)), (x,y) -> (x != y), nTests=PropCheck.nTests[])
    @forall((generate(Int), generate(Int)), !=(x,y), nTests=PropCheck.nTests[])
    @forall(gen, prop[, nTests])

Generates testcases from the given generator `gen` and checks whether the property `prop` holds. Tries a maximum of `nTests` different testcases. If a failing testcase is found, i.e. `prop(case...)` returns `false` for some `case`, the case is shrunk to a minimal reproducible example. The number of arguments is tried to be inferred from the given property. 

Returns either `(true, nothing)` or `(false, <case>)`.
"""
macro forall(gen, prop, nTests=nTests[])
    local condGen = gen isa Symbol || (gen isa Expr && gen.head == :->) ? :($gen()) :
             (gen isa Expr && (gen.head == :call || gen.head == :tuple) ? gen :
             :(() -> error("The given generator does not look like a generator.")))

    if !(prop isa Expr && (prop.head == :-> || prop.head == :call))
        throw(ArgumentError("Can't infer number of arguments for function."))
    end

    if prop.head == :call
        local singleArg = length(prop.args) == 2
        prop = prop.head == :call ? prop.args[1] : prop
    elseif prop.head == :->
        singleArg = prop.args[1] isa Symbol
    end
    local condCase = singleArg ? :case : :(case...)
    
    return esc(quote
        ret = (true, nothing)
        for i in 1:$nTests
            case = $condGen
            res = try 
                $prop($condCase)
            catch ex
                println("\n\tGot exception, not shrinking:")
                Base.display_error(ex)
                ret = (false, case)
                break
            end
            if !res
                println("\tFailed after ", i, " test", i != 1 ? "s." : ".")
                print("\tShrinking... (", case, ')')
                s = shrink($prop, case, $singleArg)
                case = s.case
                shrinks = s.generation
                println("(", shrinks, " time", shrinks != 1 ? "s)" : ")")
                println('\t', case, '\n')
                ret = (false, case)
                flush(stdout)
                break
            end
        end
        ret
    end)
end

"""
    @check customProperty 
    @check customProperty([A...])
    @check prop pretty=true

Evaluates the given property and tests whether or not it holds. Expects the function to return `(boolean, _)`.

Make sure the arguments to the property are either constants or you don't mind resolving/evaluating them before calling the property. This behaviour can be turned off by setting `pretty=false`, at the cost of no longer seeing the values of arguments in the resulting names of the testset.
"""
macro check(ex, pretty=true, broken=false)
    if ex isa Expr
        if ex.head == :call
            f = ex
        elseif ex.head != :for
            f = :($ex())
        else # for loop expanded to a testset of multiple testsets, each running over their own loop
            f = ex.args[2]
            body = Expr(:block)
            for inner_ex in f.args
                nLoop = copy(ex)
                if !(inner_ex isa Expr) || inner_ex.head != :call
                    push!(body.args, inner_ex)
                    continue
                end
                # we have to escape the function call, but _not_ its arguments
                new_ex = Expr(:call, Expr(:escape, inner_ex.args[1]), inner_ex.args[2:end]...)
                nLoop.args[2] = :(begin
                    res, _ = $new_ex
                    @test res
                end)
                set_name = Expr(:string, Expr(:escape, inner_ex.args[1]), '(')
                for e in inner_ex.args[2:end]
                    push!(set_name.args, e)
                    e !== last(inner_ex.args) && push!(set_name.args, ", ")
                end
                push!(set_name.args, ')')

                func_name = Expr(:string, Expr(:escape, inner_ex.args[1]))
                push!(body.args, :(@testset $func_name begin @testset $set_name $nLoop end))
            end
            name = "LoopCheck"
        end
    end

    if ex isa Symbol
        f = :($ex())
    end
    
    if ex isa Symbol || ex.head != :for # build body and name of outer testset if its not a loop
        body = :(begin
            res, _ = $(esc(f))
            @test res broken=$broken
        end)
        name = Expr(:string, Expr(:escape, f.args[1]), '(', map(x -> Expr(:escape, x), f.args[2:end])..., ')')
    end

    quote
        @testset $name $body
    end
end

getSubtypes() = begin
    subs = subtypes(Any)
    ret = filter(isconcretetype, subs)
    filter!(isabstracttype, subs)

    while !isempty(subs)
        ntype = popfirst!(subs)
        ntype == Any && continue
        nsubs = subtypes(ntype)
        append!(ret, Iterators.filter(isconcretetype, nsubs))
        append!(subs, Iterators.filter(isabstracttype, nsubs))
    end

    ret
end

struct empty end
# This kills inference and might result in endless recursion, so be careful with ::Any field type
generate(::Type{Any}) = begin
    x = empty()
    while x === empty()
        x = try
            generate(rand(getSubtypes()))
        catch ex
            # ignore
            empty()
        end
    end
    x
end
# FIXME: currently only dispatched on if no other method is more special, e.g. Union{Int,Float64} would be dispatched to the generator for <:Number...
generate(x::Union) = generate(rand(filter(isconcretetype, Base.uniontypes(x))))

"""
    generate(::T)

Fallback generator for any given struct. Iterates over all field types and generates an instance recursively. Fails horribly on errors occuring during construction, write a special generator if that's the case.

If a given type doesn't have a special generator defined, this will break implicit invariants not enforced in the constructor! (but that's the point of all of this anyway)
"""
generate(::Type{T}) where T = T([ generate(f) for f in fieldtypes(T) ]...) # default fallback for structs

"""
    generate(::Type{T}) where { T <: Number}

Generates a number by calling `rand(T)`.
"""
generate(::Type{T}) where {T <: Number} = rand(T) # numbers

"""
    generate(::Type{T}) where {V, N, T <: AbstractArray{V,N}}

Generates arrays by choosing a random number of dimensions and filling the resulting array by repeatedly calling `generate(V)`.
"""
generate(::Type{T}) where {V,N,T <: AbstractArray{V,N}} = begin
    res = T(undef, rand(UInt8, N)...)
    for i in eachindex(res)
        res[i] = generate(V)
    end
    res
end

generate(::Type{NTuple{N,T}}) where {N,T} = begin
    data = collect(generate(T) for _ in 1:N)
    ntuple(x -> data[x], N)
end

abstract type Shrinker end

struct SimpleShrinker{T} <: Shrinker
    generation::UInt
    exhausted::Bool
    case::T
end

struct BinaryShrinker{T} <: Shrinker
    generation::UInt
    exhausted::Bool
    case::T

    # new additions compared to the base implementation
    original_case::T
    saved_bound::T
    top::T
    bottom::T
end

Shrinker(case) = SimpleShrinker{typeof(case)}(UInt(0), false, case)

# this method is very casey
Shrinker(case::T) where T <: Integer = BinaryShrinker{T}(UInt(0), false, case, case, case, case, case+one(T)) # this assumes wraparound/modular arithmetic

exhaust(a) = exhaust(a...)
exhaust(falsifies, s::T) where {T <: SimpleShrinker} = SimpleShrinker{typeof(s.case)}(s.generation, falsifies, s.case)
exhaust(falsifies, s::T) where {S <: Integer, T <: BinaryShrinker{S}} = begin
    return T(
        s.generation,
        s.top == s.bottom,
        s.case,
        s.original_case,
        (
            if falsifies 
                (s.top,
                s.case,
                s.bottom)
            else
                (s.bottom,
                s.saved_bound,
                s.case)
            end
        )...
    )
end

Base.isless(a::T, b::T) where {S, T <: BinaryShrinker{S}} = (a.case, a.top-a.bottom, a.original_case, b.generation) < (b.case, b.top-b.bottom, b.original_case, b.generation)
Base.isless(a::T, b::T) where {T <: Shrinker} = shrinkless(a.case, b.case)
shrinkless(a::T, b::T) where T <: Number = a < b
shrinkless(a::T, b::T) where T <: Tuple = length(a) == length(b) ? reduce(&, map(shrinkless, a, b)) : length(a) < length(b)
shrinkless(a::T, b::T) where T = begin
    try
        return a < b
    catch ex
        if ex isa MethodError
            less = true
            for f in 1:fieldcount(T)
                less &= shrinkless(getfield(a, f), getfield(b, f))
            end
            return less
        else
            rethrow(ex)
        end
    end
end
shrinkless(a::T, b::T) where {S,N,T <: AbstractArray{S,N}} = begin
    return length(a) == length(b) ? reduce(&, map(shrinkless, a, b)) : length(a) < length(b)
end

shrink(f, case, singleArg, nShrinks=nShrinks[]) = begin
    tests = 0
    popSize = 100
    
    # TODO: write better initialization depending on the case type
    bestCounterexample = Shrinker(case)
    population   = [ bestCounterexample for _ in 1:popSize ]

    # TODO: outsource this into a recursive function
    # possible things: branch and bound, minimax...
    # should be possible to define a domination criterion
    while tests < nShrinks
        population .= shrink.(population)
        
        survivors = if singleArg 
            map(x -> !f(x.case), population)
        else
            map(x -> !f(x.case...), population)
        end
        
        if any(survivors)
            remainingShrinkers = filter(x -> x.exhausted, Iterators.map(exhaust, Iterators.zip(survivors, population)))
            bestN = partialsort!(remainingShrinkers, 1:min(10, length(remainingShrinkers)))
            bestCounterexample = first(bestN)
            population .= rand(bestN, popSize)
        else # no survivors :(
            fill!(population, bestCounterexample)
        end
        tests += 1
    end
    bestCounterexample
end

shrink(s::T) where {S, T <: SimpleShrinker{S}} = T(s.generation + 1, false, shrink(s.case))
shrink(s::T) where {S, T <: BinaryShrinker{S}} = begin
    return T(s.generation,
             s.exhausted,
             (s.bottom-s.top)÷2,
             s.original_case,
             s.saved_bound,
             s.top,
             s.bottom)
end
shrink(s::T) where {S <: Tuple,T <: SimpleShrinker{S}} = begin
    ncase = shrink(s.case)
    SimpleShrinker{typeof(ncase)}(s.generation + 1, false, ncase)
end

"""
    shrink(a::T) where T

Fallback shrinking function for structs. Tries to shrink each field of the given type and calls the default constructor. If you wrote a custom [`generate`](@ref), you probably also have to customize this.
"""
shrink(a::T) where T = T([ shrink(getfield(a, f)) for f in 1:fieldcount(T) ]...) # fallback for structs

"""
    shrink(n::T) where { T <: Integer }

Shrinks positive integers toward zero and negative integers towards -1.
"""
shrink(up::T) where {T <: Integer} = begin
    iszero(up) && return up
    
    # this assumes isbits and is too smart by half 
    # Ref. https://www.epsilontheory.com/too-clever-by-half/

    targetSize = sizeof(T) * 8
    if targetSize == 128        workType = UInt128
    elseif targetSize == 64     workType = UInt64
    elseif targetSize == 32     workType = UInt32
    elseif targetSize == 16     workType = UInt16
    elseif targetSize == 8      workType = UInt8
    end

    ret = reinterpret(workType, up)
    pow2s = workType[]
    for i in zero(workType):workType(targetSize)-one(workType)
        n = one(workType) << i
        if (up & n) != zero(workType)
            push!(pow2s, n)
        end
    end

    if up < zero(T)
        ret | rand(pow2s)
    else
        ret & ~rand(pow2s)
    end
    reinterpret(T, ret)
end

"""
    shrink(n::T) where { T <: AbstractFloat }

Shrinks positive floats toward zero and negative floats towards -1.
"""
shrink(up::T) where {T <: AbstractFloat} = up / 2

"""
    shrink(arr::T) where {V, N, T <: AbstractArray{V,N}}

Shrinks arrays by shrinking their elements as well as dropping random elements with probability [`PropCheck.dropChance`](@ref).
"""
shrink(arr::T) where {V,N,T <: AbstractArray{V,N}} = begin
    # shrink array by shrinking elements and maybe dropping a random element
    ret = copy(arr)
    
    length(arr) == 0 && return ret
    if rand() < dropChance[]
        deleteat!(ret, rand(eachindex(ret)))
    end
    shrink.(ret)
end

"""
    shrink(a::T) where T <: Tuple

Shrinks tuples by shrinking their elements.
"""
shrink(a::T) where T <: Tuple = shrink.(a)

end # module
