using Documenter, AnomalyBenchmark

makedocs(
    sitename="AnomalyBenchmark.jl Documentation",
    format=Documenter.HTML(
        prettyurls = false,
        edit_link="main",
    ),
    modules=[AnomalyBenchmark],
    pages = ["index.md"],
)

deploydocs(repo = "github.com/akamai/AnomalyBenchmark.jl.git")
