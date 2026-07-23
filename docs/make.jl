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
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/drbergman-lab/PhysiCellOutput.jl",
    devbranch="main",
)
