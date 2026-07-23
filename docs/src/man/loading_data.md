```@meta
CurrentModule = PhysiCellOutput
```

# [Loading data](@id loading_data)

PhysiCellOutput is built around one idea: a **path to a PhysiCell output folder** is all you
need. From that path you build a [`PhysiCellSnapshot`](@ref) (one time point) or a
[`PhysiCellSequence`](@ref) (the whole run), and load whichever kinds of data you want.

Throughout this page, `folder` is the path to a PhysiCell output directory:

```julia
using PhysiCellOutput
folder = "/path/to/PhysiCell/output"
```

## Snapshots and sequences

A [`PhysiCellSnapshot`](@ref) is a single output index. The index is an integer, or one of
the symbols `:initial` / `:final`:

```julia
snapshot = PhysiCellSnapshot(folder, 0)         # output00000000.*
snapshot = PhysiCellSnapshot(folder, :final)    # final.*
```

A [`PhysiCellSequence`](@ref) is every `output*.xml` in the folder, in index order:

```julia
sequence = PhysiCellSequence(folder)
length(sequence.snapshots)
```

Both are always constructed with their `time` and `runtime` populated, but the heavier data
— cells, substrates, mesh, and the three graphs — is **loaded lazily**. Each data kind stays
empty until you either ask for it at construction with an `include_*` keyword, or load it
afterward with a `load*!` function.

If a requested file is missing, construction prints a message and returns `missing` rather
than throwing, so you can probe a folder without wrapping every call in a `try`.

### Loading at construction

```julia
snapshot = PhysiCellSnapshot(folder, :final;
                             include_cells=true,
                             include_substrates=true,
                             include_mesh=true,
                             include_attachments=true,
                             include_spring_attachments=true,
                             include_neighbors=true)

sequence = PhysiCellSequence(folder; include_cells=true, include_substrates=true)
```

The sequence constructor reads the cell-type map, cell labels, and (when substrates are
requested) substrate names **once** from the initial XML and threads them into every
snapshot, so the per-snapshot XML is not re-parsed for metadata.

### Loading afterward

The `load*!` functions fill in a snapshot or an entire sequence in place. They are
idempotent — calling one on already-loaded data does nothing:

```julia
sequence = PhysiCellSequence(folder)
loadCells!(sequence)        # every snapshot
loadSubstrates!(sequence)
loadMesh!(sequence)
loadGraph!(sequence, :neighbors)
```

## Loading cells

Cell data comes back as a `DataFrame`, one column per PhysiCell label plus a derived
`cell_type_name` column. `ID`, `dead`, and `cell_type` are converted to `Int`, `Bool`, and
`Int` respectively.

```julia
snapshot = PhysiCellSnapshot(folder, :final; include_cells=true)
snapshot.cells               # DataFrame of cells × features
snapshot.cells.cell_type_name
```

The available column labels for a folder can be read directly with [`cellLabels`](@ref), the
cell-type map with [`cellTypeToNameDict`](@ref):

```julia
cellLabels(folder * "/initial.xml")
cellTypeToNameDict(folder * "/initial.xml")   # Dict(id => name)
```

These readers accept a path to an XML file, an `XMLDocument`, a snapshot, or a sequence.

## Loading substrates

Substrate (microenvironment) data comes back as a `DataFrame` with columns
`x, y, z, volume` followed by one column per substrate:

```julia
snapshot = PhysiCellSnapshot(folder, 0; include_substrates=true)
snapshot.substrates
substrateNames(folder * "/initial.xml")       # the substrate column names, in ID order
```

## Loading the mesh

Mesh data is a `Dict{String,Vector{Float64}}` with keys `"bounding_box"`, `"x"`, `"y"`,
and `"z"`, read from the snapshot XML:

```julia
snapshot = PhysiCellSnapshot(folder, 0; include_mesh=true)
snapshot.mesh["bounding_box"]
snapshot.mesh["x"]
```

## Loading graphs

PhysiCell writes three cell graphs per snapshot: attachments, spring attachments, and
neighbors. Each loads into a directed `MetaGraph` whose vertices are labeled by
[`AgentID`](@ref) — a thin wrapper around the integer agent ID so that graph vertex indices
and agent IDs are not confused.

Load a graph with [`loadGraph!`](@ref), passing one of `:attachments`,
`:spring_attachments`, or `:neighbors` (a `String` works too):

```julia
using Graphs, MetaGraphsNext

snapshot = PhysiCellSnapshot(folder, :final; include_neighbors=true)
g = snapshot.neighbors
nv(g), ne(g)                 # vertex and edge counts

loadGraph!(snapshot, :attachments)   # load another graph after the fact
```

## Per-cell time series

[`cellDataSequence`](@ref) reorganizes a whole run into per-cell time series. It returns an
[`AgentDict`](@ref) keyed by cell ID; each value is a `NamedTuple` with a `time` vector plus
one entry per requested label. Scalar labels come back as length-`N` vectors; multi-column
labels (such as `position`) are concatenated into an `N × k` array.

```julia
data = cellDataSequence(folder, ["position", "total_volume"];
                        include_dead=true, include_cell_type_name=true)

data[1].time            # times at which cell 1 was present
data[1].position        # N×3
data[1].total_volume    # length-N
data[1].cell_type_name  # length-N
```

`AgentDict` accepts either an integer or an [`AgentID`](@ref) as a key, so `data[1]` and
`data[AgentID(1)]` are equivalent.

If you will query many labels from the same run, build a [`PhysiCellSequence`](@ref) once and
pass it to `cellDataSequence` so the data is loaded a single time:

```julia
sequence = PhysiCellSequence(folder)
positions = cellDataSequence(sequence, "position")
volumes   = cellDataSequence(sequence, "total_volume")
```

## Relationship to PhysiCellModelManager

PhysiCellOutput is the base loading layer. It identifies data purely by **folder path** — it
has no notion of a simulation ID, a database, or a project.

[PhysiCellModelManager.jl](https://github.com/drbergman-lab/PhysiCellModelManager.jl) (PCMM)
identifies simulations by an integer `simulation_id` stored in its database. When PCMM needs
to load output, it converts `simulation_id → output folder` and calls PhysiCellOutput,
wrapping the result in a thin PCMM-side type when it wants the ID shown. So:

- If you have a folder to read, use PhysiCellOutput directly (this package).
- If you are managing many simulations with a database and parameter sweeps, use PCMM; it
  uses PhysiCellOutput underneath.

Because the two packages share function names, code written against PhysiCellOutput's
folder-based API reads the same as the PCMM equivalent — only the identifier (a path here, a
`simulation_id` there) differs.
