using Documenter, PropCheck

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
                "Generating objects with specific properties" => "Examples/properties.md"
            ],
            "API Reference" => "api.md"
        ]
    )
end

builddocs()
