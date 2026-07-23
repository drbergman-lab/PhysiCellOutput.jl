# PhysiCellOutput.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://drbergman-lab.github.io/PhysiCellOutput.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://drbergman-lab.github.io/PhysiCellOutput.jl/dev/)
[![Build Status](https://github.com/drbergman-lab/PhysiCellOutput.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/drbergman-lab/PhysiCellOutput.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/drbergman-lab/PhysiCellOutput.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/drbergman-lab/PhysiCellOutput.jl)

Read the output folder of a **single PhysiCell simulation** into Julia — cells, substrates, mesh, and the cell attachment/spring/neighbor graphs — with no database, no project structure, and no simulation registry. Point it at a folder and load.

PhysiCellOutput is a lightweight, path-based loader. It exists so that loading PhysiCell data does not require the full [PhysiCellModelManager.jl](https://github.com/drbergman-lab/PhysiCellModelManager.jl) (PCMM) stack. PCMM depends on PhysiCellOutput for its output loading and layers its database concepts (e.g. simulation IDs) on top.

> **Status:** The loader is ported from PCMM's `loader.jl` and tested against a real output fixture. Remaining work is the downstream PCMM migration and a fuller docs site. See **Implementation Status** below.

## Installation

The package is registered in the [BergmanLabRegistry](https://github.com/drbergman-lab/BergmanLabRegistry):

```julia-repl
pkg> registry add https://github.com/drbergman-lab/BergmanLabRegistry
pkg> add PhysiCellOutput
```

## Quick start

Everything is keyed on the path to a PhysiCell output folder (the folder containing `output00000000.xml`, `output00000000_cells.mat`, etc.).

```julia
using PhysiCellOutput

folder = "/path/to/PhysiCell/output"

# Load the whole time series, with the data you want:
sequence = PhysiCellSequence(folder; include_cells=true, include_substrates=true)

# Or a single snapshot by index (or :initial / :final):
snapshot = PhysiCellSnapshot(folder, 0; include_cells=true)
snapshot = PhysiCellSnapshot(folder, :final; include_mesh=true)

# Load data lazily after construction:
loadCells!(sequence)
loadSubstrates!(snapshot)
loadMesh!(snapshot)
loadGraph!(snapshot, :neighbors)   # :attachments, :spring_attachments, :neighbors

# Per-cell time series across the whole simulation:
data = cellDataSequence(folder, ["position", "elapsed_time_in_phase"];
                        include_dead=true, include_cell_type_name=true)
data[1].position   # N×3 array of cell 1's position over time
data[1].time       # times of the snapshots cell 1 appears in
```

Cell and substrate data come back as `DataFrame`s; the mesh as a `Dict`; the graphs as `MetaGraphs` labeled by `AgentID`.

## Relationship to PhysiCellModelManager.jl

PhysiCellOutput is the base loading layer. PCMM identifies simulations by an integer `simulation_id` stored in its database; PhysiCellOutput does not — it works purely from folder paths. PCMM converts `simulation_id → output folder` and calls PhysiCellOutput, wrapping the result in a thin PCMM-side type when it wants the ID displayed. If you are managing many simulations with a database and parameter sweeps, use PCMM; if you just have an output folder to read, use this package directly.

---

## Implementation Status

> For Claude Code sessions: this section is the authoritative record of what has been built. Update it as features land. See [PRD.md](PRD.md) for behavioral specs, [progress.md](progress.md) for decision rationale, and [CLAUDE.md](CLAUDE.md) for working conventions and the PCMM boundary.

### Completed
- [x] Project scaffolding — docs (`CLAUDE.md`, `PRD.md`, `progress.md`, this README), CI/TagBot/CompatHelper wired to the BergmanLabRegistry, codecov config.
- [x] Core design decision locked — **path-based identity** (types key on `folder::String`, not `simulation_id`); PCMM re-adds the ID via a thin wrapper. See PRD "Core Design Decision".
- [x] Internal LightXML helpers (`retrieveElement`, `getSimpleContent`, `getChildByAttribute`, `getChildByChildContent`, `retrieveElementError`, `elementIsTerminal`) — minimal read-side subset copied from ModelManager (`src/xml_utilities.jl`).
- [x] `AbstractPhysiCellSequence`, `PhysiCellSnapshot`, `PhysiCellSequence` (path-based) with lazy `include_*` loading and `show` methods.
- [x] Path/filename utilities — `indexToFilename`, `pathToOutputFileBase`, `pathToOutputXML`.
- [x] Metadata readers — `cellLabels`, `cellTypeToNameDict`, `substrateNames` (path / `XMLDocument` / snapshot / sequence).
- [x] Loaders — `loadCells!`, `loadSubstrates!`, `loadMesh!`, `loadGraph!` (+ `_load*` internals, `_safe_matread` zero-cell `EOFError` workaround).
- [x] Graph support — `AgentID`, `AgentDict`, `physicellEmptyGraph`, `readPhysiCellGraph!`.
- [x] `cellDataSequence` (+ deprecated `getCellDataSequence` alias).
- [x] `Project.toml` dependencies — `DataFrames`, `MAT`, `Graphs`, `MetaGraphsNext`, `LightXML`, `Dates`.
- [x] Test suite (75 tests) against a committed PhysiCell output fixture (`test/fixtures/output`, sim with 3 snapshots + initial/final).

### Remaining
- [ ] Fuller Documenter site — the `docs/` site is still the PkgTemplates single-page stub; a man/lib split (like ModelManager/PCMM) can follow.
- [ ] PCMM migration — PCMM depends on PhysiCellOutput and adds its `simulation_id` wrapper (tracked in PCMM, not here).
