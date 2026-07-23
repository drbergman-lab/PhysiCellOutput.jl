```@meta
CurrentModule = PhysiCellOutput
```

# PhysiCellOutput.jl

[PhysiCellOutput.jl](https://github.com/drbergman-lab/PhysiCellOutput.jl) reads the output
folder of a **single PhysiCell simulation** into Julia — cells, substrates, mesh, and the
cell attachment/spring/neighbor graphs — with no database, no project structure, and no
simulation registry. Point it at a folder and load.

It is a lightweight, path-based loader. Everything is keyed on the path to a PhysiCell output
folder (the folder containing `output00000000.xml`, `output00000000_cells.mat`, and friends).
The package exists so that loading PhysiCell data does not require the full
[PhysiCellModelManager.jl](https://github.com/drbergman-lab/PhysiCellModelManager.jl) (PCMM)
stack; PCMM in turn depends on PhysiCellOutput for its output loading and layers its database
concepts (such as simulation IDs) on top. See [Relationship to PhysiCellModelManager](@ref)
for where the boundary sits.

New here? Read [Installation](@ref), then [Loading data](@ref loading_data).

## Quick start

```julia
using PhysiCellOutput

folder = "/path/to/PhysiCell/output"

# Load the whole time series, with the data you want:
sequence = PhysiCellSequence(folder; include_cells=true, include_substrates=true)

# Or a single snapshot by index (or :initial / :final):
snapshot = PhysiCellSnapshot(folder, 0; include_cells=true)
snapshot = PhysiCellSnapshot(folder, :final; include_mesh=true)

# Per-cell time series across the whole simulation:
data = cellDataSequence(folder, ["position", "total_volume"]; include_cell_type_name=true)
data[1].position   # N×3 array of cell 1's position over time
data[1].time       # times of the snapshots cell 1 appears in
```

## Where do I look?

| I want to… | Go to |
| --- | --- |
| Add the package as a dependency | [Installation](@ref) |
| Load cells, substrates, mesh, or graphs from a folder | [Loading data](@ref loading_data) |
| Understand snapshots vs. sequences and lazy loading | [Snapshots and sequences](@ref) |
| Build per-cell time series | [Per-cell time series](@ref) |
| Understand how this relates to PCMM | [Relationship to PhysiCellModelManager](@ref) |
| Look up a function's signature | the [Alphabetical index](@ref) |

## Issues

Found a bug or have a question? Please open an issue on the
[PhysiCellOutput.jl GitHub page](https://github.com/drbergman-lab/PhysiCellOutput.jl/issues).
