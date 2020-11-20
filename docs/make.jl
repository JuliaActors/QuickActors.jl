using Documenter, QuickActors

makedocs(
    modules = [QuickActors],
    format = Documenter.HTML(; prettyurls = get(ENV, "CI", nothing) == "true"),
    authors = "Schäffer Krisztián",
    sitename = "QuickActors.jl",
    pages = Any["index.md"]
    # strict = true,
    # clean = true,
    # checkdocs = :exports,
)

deploydocs(
    repo = "github.com/tisztamo/QuickActors.jl.git",
    push_preview = true
)
