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
