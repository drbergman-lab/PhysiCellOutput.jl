```@meta
CurrentModule = PhysiCellOutput
```

# Installation

PhysiCellOutput.jl is published in the BergmanLabRegistry. Add the registry once, then add
the package:

```julia-repl
pkg> registry add https://github.com/drbergman-lab/BergmanLabRegistry
pkg> add PhysiCellOutput
```

Then load it:

```julia
using PhysiCellOutput
```

## What you need

You need a PhysiCell **output folder** — the directory a PhysiCell run writes its
`output*.xml`, `*_cells.mat`, `*_microenvironment0.mat`, and `*_graph.txt` files into.
PhysiCellOutput reads that folder; it never writes to it and never runs a simulation.

You do **not** need PhysiCellModelManager.jl, a database, or a project structure. If you are
already using PCMM to manage a campaign of simulations, you generally will not call
PhysiCellOutput directly — PCMM uses it under the hood (see
[Relationship to PhysiCellModelManager](@ref)).

## Julia version and environment

PhysiCellOutput targets a recent stable Julia release; see the `[compat]` section of
`Project.toml` for the supported range. As always, work inside a project environment rather
than the global one:

```sh
julia --project=.
```

## Contributing to PhysiCellOutput itself

Clone and develop it in a fresh environment:

```julia-repl
pkg> dev https://github.com/drbergman-lab/PhysiCellOutput.jl
```

Run the test suite with:

```sh
julia --project=. -e 'using Pkg; Pkg.test()'
```
