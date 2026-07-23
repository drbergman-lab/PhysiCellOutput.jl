using PhysiCellOutput
using Documenter

DocMeta.setdocmeta!(PhysiCellOutput, :DocTestSetup, :(using PhysiCellOutput); recursive=true)

makedocs(;
    modules=[PhysiCellOutput],
    authors="Daniel Bergman <danielrbergman@gmail.com> and contributors",
    sitename="PhysiCellOutput.jl",
    format=Documenter.HTML(;
        canonical="https://drbergman-lab.github.io/PhysiCellOutput.jl",
        edit_link="main",
        assets=String[],
        collapselevel=1,
    ),
    pages=[
        "Home" => "index.md",
        "Getting Started" => Any[
            "Installation" => "man/installation.md",
            "Loading data" => "man/loading_data.md",
        ],
        "Reference" => Any[
            "Loading API" => "lib/loader.md",
            "XML utilities" => "lib/xml_utilities.md",
            "Alphabetical index" => "lib/index.md",
        ],
    ],
    checkdocs=:exports,
)

deploydocs(;
    repo="github.com/drbergman-lab/PhysiCellOutput.jl",
    devbranch="main",
)
