using Documenter, PropCheck

DocMeta.setdocmeta!(PropCheck, :DocTestSetup, :(using PropCheck); recursive=true)

function builddocs(clear=false)
    clear && rm(joinpath(@__DIR__, "build"), force=true, recursive=true)
    makedocs(
        sitename="PropCheck.jl Documentation",
        format = Documenter.HTML(
            prettyurls = get(ENV, "CI", nothing) == true
        ),
        pages = [
            "Main Page" => "index.md",
            "Introduction to PBT" => "intro.md",
            "Examples" => [
                "Basic Usage" => "Examples/basic.md",
                "Generating Structs" => "Examples/structs.md",
                "Generating Containers" => "Examples/containers.md",
                "Composing Generators" => "Examples/properties.md"
            ],
            "API Reference" => "api.md"
        ]
    )
end

builddocs()

!isinteractive() && deploydocs(
   repo = "github.com/Seelengrab/PropCheck.jl.git",
   devbranch = "main",
   push_preview = true
)