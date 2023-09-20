using Documenter, NAB

makedocs(
    sitename="NAB.jl Documentation",
    format=Documenter.HTML(
        prettyurls = false,
        edit_link="main",
    ),
    modules=[NAB],
    pages = ["index.md"],
)

#deploydocs(repo = "github.com/akamai/NAB.jl.git")
