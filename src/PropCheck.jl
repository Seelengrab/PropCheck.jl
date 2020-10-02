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
    @suchthat(N, generate(Int), x -> ...)
    @suchthat(N, () -> generate(Int), ==(N))
    @suchthat((N,M), (generate(Int),generate(Int)), !=)

Tries to generate elements via the given generator(s) until the condition is satisfied. The condition has to return a boolean.
"""
macro suchthat(bin, gen, cond, tries=nGenTries[])
    condArgs = cond.args[1] isa Symbol ? bin : :($bin...)
    generator = gen isa Symbol || (gen isa Expr && gen.head == :->) ? :($gen()) :
                (gen isa Expr && (gen.head == :call || gen.head == :tuple)) ? gen : :(() -> error("The given generator does not look like a callable or a function call."))

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
    generator = gen isa Symbol || (gen isa Expr && gen.head == :->) ? :($gen()) : gen isa Expr && gen.head == :call ? gen : :(() -> error("The given generator does not look like a callable or a function call."))

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

Generates testcases from the given generator `gen` and checks whether the property `prop` holds. Tries a maximum of `nTests` different testcases. If a failing testcase is found, i.e. `prop(case...)` returns `false` for some `case`, the case is shrunk to a minimal reproducible example. The number of arguments is tried to be inferred from the given property. 

Returns either `(true, nothing)` or `(false, <case>)`.
"""
macro forall(gen, prop, nTests=nTests[])
    condGen = gen isa Symbol || (gen isa Expr && gen.head == :->) ? :($gen()) :
             (gen isa Expr && (gen.head == :call || gen.head == :tuple) ? gen : error("The given generator does not look like a generator."))

    if !(prop isa Expr && (prop.head == :-> || prop.head == :call))
        error("Can't infer number of arguments for function.")
    end

    if prop.head == :call
        singleArg = length(prop.args) == 2
        prop = prop.head == :call ? prop.args[1] : prop
    elseif prop.head == :->
        singleArg = prop.args[1] isa Symbol
    end
    condCase = singleArg ? :case : :(case...)
    
    return esc(quote
        for i in 1:$nTests
            case = $condGen
            try 
                if !$prop($condCase)
                    println("\n\tFailed after $i test", i != 1 ? "s." : ".")
                    print("\tShrinking... ")
                    s = shrink($prop, case, $singleArg)
                    case = s.case
                    shrinks = s.generation
                    println("(", shrinks, " time", shrinks != 1 ? "s)" : ")")
                    println('\t', case, '\n')
                    return false, case
                end
            catch ex
                println("\tGot exception:")
                println('\t', ex)
                return false, case                
            end
        end
        println("✓")
        return true, nothing
    end)
end

"""
    @check customProperty
    @check customProperty()

Evaluates the given property and tests whether or not it holds. The given function should not take any arguments. Expects the function to return (boolean, _).
"""
macro check(func)
    f = func isa Expr && func.head == :call ? func : :($func())
    
    esc(quote
    local f_name = "$($func)"
    @testset "$($func)" begin
            print(f_name, ": ")
            local res, _ = $f
            @test res
        end
    end)
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
generate(::Type{T}) where {V, N, T <: AbstractArray{V,N}} = begin
    res = T(undef, rand(UInt8, N)...)
    for i in eachindex(res)
        res[i] = generate(V)
    end
    res
end

generate(::Type{NTuple{N,T}}) where {N, T} = begin
    data = collect(generate(T) for _ in 1:N)
    ntuple(x -> data[x], N)
end

struct Shrinker{T}
    case::T
    generation::UInt
end
Shrinker(case) = Shrinker{typeof(case)}(case, UInt(0))

Base.isless(a::T, b::T) where {S, T <: Shrinker{S}} = shrinkless(a.case,b.case)
shrinkless(a::T, b::T) where T <: Number = a < b
shrinkless(a::T, b::T) where T <: Tuple = length(a) == length(b) ? reduce(&, map(shrinkless, a, b)) : length(a) < length(b)
shrinkless(a::T, b::T) where T = begin
    try
        return a < b
    catch ex
        if ex isa MethodError
            less = true
            for f in 1:fieldcount(T)
                less &= shrinkless(getfield(a,f), getfield(b,f))
            end
            return less
        else
            rethrow(ex)
        end
    end
end
shrinkless(a::T, b::T) where {S, N, T <: AbstractArray{S,N}} = begin
    return length(a) == length(b) ? reduce(&, map(shrinkless, a, b)) : length(a) < length(b)
end

shrink(f, case, singleArg, nShrinks=nShrinks[]) = begin
    tests = 0
    popSize = 100
    bestCounterexample = Shrinker(case)
    
    population   = [ bestCounterexample for _ in 1:3*popSize ]
    
    while tests < nShrinks
        population .= shrink.(population)
        
        survivors = if singleArg 
            filter(x -> !f(x.case), population)
        else
            filter(x -> !f(x.case...), population)
        end
        
        if isempty(survivors)
            fill!(population, bestCounterexample)
        else
            bestN = partialsort!(survivors, 1:min(10, length(survivors)))
            bestCounterexample = first(bestN)
            population .= rand(bestN, 3*popSize)
        end
        tests += 1
    end
    bestCounterexample
end

shrink(s::T) where {S, T <: Shrinker{S}} = T(shrink(s.case), s.generation+1)
shrink(s::T) where {S <: Tuple, T <: Shrinker{S}} = begin
    ncase = shrink(s.case)
    Shrinker{typeof(ncase)}(ncase, s.generation+1)
end

"""
    shrink(a::T) where T

Fallback shrinking function for structs. Tries to shrink each field of the given type and calls the default constructor. If you wrote a custom [`generate`](@ref), you probably also have to customize this.
"""
shrink(a::T) where T = T([ shrink(getfield(a,f)) for f in 1:fieldcount(T) ]...) # fallback for structs

"""
    shrink(n::T) where { T <: Integer }

Shrinks positive integers toward zero and negative integers towards -1.
"""
shrink(up::T) where {T <: Integer} = begin
    iszero(up) && return up
    # this assumes isbits!

    targetSize = sizeof(T)*8
    if targetSize == 64         workType = UInt64
    elseif targetSize == 32     workType = UInt32
    elseif targetSize == 16     workType = UInt16
    elseif targetSize == 8      workType = UInt8
    end

    ret = reinterpret(workType, up)
    pow2s = workType[]
    for i in workType(0):targetSize-1
        n = workType(1) << i
        if (up & n) != workType(0)
            push!(pow2s, n)
        end
    end

    if up < 0
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
shrink(arr::T) where {V, N, T <: AbstractArray{V,N}} = begin
    length(arr) == 0 && return ret
    
    # shrink array by shrinking elements and maybe dropping a random element
    ret = copy(arr)
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
