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