## Function Index

!!! warning "Stability"
    The entries written on this page are automatically generated and DO NOT represent
    the currently supported API surface. PropCheck.jl is currently in a 0.x release;
    feel free to use anything you can find here, but know that (for now) only
    symbols that are exported are expected to stick around (they too may change, but I
    don't expect the underlying functionality to vanish entirely).

    Nevertheless, I don't really expect things to change too much - the package is already
    complicated as is.

```@index
```

### Function reference

```@autodocs
Modules = [PropCheck]
Order = [:function, :type]
Filter = t -> begin
    !(isabstracttype(t) && t <: PropCheck.AbstractIntegrated) && !(t in (PropCheck.shrink, PropCheck.generate, PropCheck.itype))
end
```
