# Product Requirements Document — PhysiCellOutput.jl

> **Purpose:** This document defines the feature set of PhysiCellOutput in behavioral terms. It is the authoritative answer to "what should this system do?" Read it at the start of any feature session to align intent with implementation.

---

## Product Overview

**Vision:** A lightweight, dependency-light Julia package that loads the output of a single PhysiCell simulation from its output folder — cells, substrates, mesh, and cell graphs — with **no** database, project structure, or simulation registry required.

**Target Users:**
1. Julia users who have a PhysiCell output folder and want the data as `DataFrame`s / `MetaGraph`s without installing the full PhysiCellModelManager.jl (PCMM) stack.
2. PCMM itself, which will depend on this package for all output loading and re-add its database-specific concepts through a thin wrapper.

**Business Objectives:**
1. Remove the heavy PCMM dependency from the "just load PhysiCell data" use case.
2. Give PCMM a single, well-tested loading layer to depend on, eliminating duplicated loader logic.
3. Keep the loading layer simulator-output-focused and stateless.

**Non-goals:**
- No writing of PhysiCell output.
- No simulation running, parameter variation, database, or project management (those stay in ModelManager/PCMM).
- No plotting (downstream packages handle visualization).

---

## Core Design Decision — Path-Based Identity

The original PCMM `loader.jl` keyed `PhysiCellSnapshot`/`PhysiCellSequence` on a `simulation_id::Int` and resolved it to a folder via `pathToOutputFolder(simulation_id)`, which requires an initialized PCMM project/database.

**Decision (locked):** PhysiCellOutput types are keyed on the **output-folder path**. `simulation_id` does not appear anywhere in this package.

- `PhysiCellSnapshot` and `PhysiCellSequence` store a `folder::String` (path to a PhysiCell output folder).
- Construction takes a folder path (+ an `index` for snapshots).
- **PCMM re-adds its concept:** PCMM converts `simulation_id → output-folder path` at its own boundary and calls PhysiCellOutput. Where PCMM wants the id displayed (its `show` currently prints `SimID=…`), PCMM defines a thin wrapper struct carrying the `simulation_id` plus the PhysiCellOutput object, and gives it a custom `show`. PhysiCellOutput provides the loading; PCMM provides the id semantics.

Rationale and alternatives considered are recorded in [progress.md](progress.md) (Session: initial scaffolding).

---

## Data Model

### Feature: `AbstractPhysiCellSequence`
**One-line:** Common supertype for a single snapshot and a sequence of snapshots.
**Priority:** Must-have
- `abstract type AbstractPhysiCellSequence end`.
- Both `PhysiCellSnapshot` and `PhysiCellSequence` subtype it.

### Feature: `PhysiCellSnapshot`
**One-line:** A single time point of a PhysiCell simulation, loaded lazily.
**Priority:** Must-have

**Fields:**
- `folder::String` — path to the output folder.
- `index::Union{Int,Symbol}` — snapshot index; integer, or `:initial` / `:final`.
- `time::Float64` — simulation time (minutes), read from the snapshot XML `metadata/current_time`.
- `runtime::Nanosecond` — wall-clock runtime to reach this snapshot, from `metadata/current_runtime` (seconds → `Nanosecond`).
- `cells::DataFrame` — cell data (empty until loaded).
- `substrates::DataFrame` — substrate data (empty until loaded).
- `mesh::Dict{String,Vector{Float64}}` — mesh data (empty until loaded).
- `attachments::MetaGraph`, `spring_attachments::MetaGraph`, `neighbors::MetaGraph` — cell graphs (empty graph until loaded).

**Constructor:** `PhysiCellSnapshot(folder::AbstractString, index::Union{Integer,Symbol}, labels::Vector{String}=String[], substrate_names::Vector{String}=String[]; kwargs...)`

**Keyword arguments** (all `false`/empty by default — data is loaded lazily):
- `include_cells::Bool`
- `cell_type_to_name_dict::Dict{Int,String}`
- `include_substrates::Bool`
- `include_mesh::Bool`
- `include_attachments::Bool`
- `include_spring_attachments::Bool`
- `include_neighbors::Bool`

**Behavioral spec:**
- The snapshot's file base is `joinpath(folder, indexToFilename(index))`.
- If the snapshot XML file is missing, print a message and return `missing`.
- `time` and `runtime` are always read from XML at construction.
- Each `include_*` flag, if `true`, loads the corresponding data; if that data's file is missing, print a message and return `missing`.
- `show` prints folder + index, time, runtime, and a per-field "NOT LOADED"/summary line for cells, substrates, mesh, and the three graphs. (Contrast with PCMM's wrapper, which shows the `simulation_id`.)

**Acceptance criteria:**
- Constructing against a valid folder/index with no `include_*` flags yields a snapshot with populated `time`/`runtime` and empty data containers.
- Missing XML → `missing` (with message), never an exception.
- `include_cells=true` populates `cells` with one column per label plus a `cell_type_name` column.

### Feature: `PhysiCellSequence`
**One-line:** The ordered set of all snapshots in an output folder.
**Priority:** Must-have

**Fields:**
- `folder::String`
- `snapshots::Vector{PhysiCellSnapshot}`
- `cell_type_to_name_dict::Dict{Int,String}`
- `labels::Vector{String}`
- `substrate_names::Vector{String}`

**Constructor:** `PhysiCellSequence(folder::AbstractString; include_cells, include_substrates, include_mesh, include_attachments, include_spring_attachments, include_neighbors)` (all `false` by default).

**Behavioral spec:**
- Reads `cell_type_to_name_dict`, `labels` (and `substrate_names` when substrates requested) once from the `:initial` XML and threads them into every snapshot (avoids re-parsing XML per snapshot).
- If the initial XML has no cell-type info (e.g. pruned output), print a message and return `missing`.
- Iterates `index = 0, 1, 2, …` building a snapshot for each while `output{index}.xml` exists.
- `show` prints folder, number of snapshots, cell types, substrates, and mesh info.

**Acceptance criteria:**
- A folder with N `output*.xml` files yields a sequence of N snapshots in index order.
- Metadata (labels, cell types, substrate names) is parsed once, not per snapshot.

---

## Path & Filename Utilities

### Feature: `indexToFilename`
- `indexToFilename(index::Int)` → `"output" * lpad(index, 8, "0")`.
- `indexToFilename(index::Symbol)` → `"initial"` or `"final"` (asserts the symbol is one of those two).
- Doctestable, e.g. `indexToFilename(0) == "output00000000"`.

### Feature: path helpers (path-based)
- `pathToOutputFileBase(folder, index)` → `joinpath(folder, indexToFilename(index))` (everything but the extension).
- `pathToOutputFileBase(snapshot)` → uses `snapshot.folder`, `snapshot.index`.
- `pathToOutputXML(folder, index=:initial)` → `"$(pathToOutputFileBase(folder, index)).xml"`.
- `pathToOutputXML(snapshot)`.
- **Removed vs `loader.jl`:** the `simulation_id`/`Simulation` overloads of these helpers. PCMM supplies the folder.

---

## Metadata Readers

Each of these accepts a **path to an XML file** (`String`), an `XMLDocument`, a `PhysiCellSnapshot`, or a `PhysiCellSequence`. (The `simulation_id`/`Simulation` overloads from `loader.jl` are dropped.)

### Feature: `cellLabels`
- Returns the cell-data column labels from the simplified_data `labels` element.
- Multi-column labels (`size > 1`) expand to `name_1 … name_k`.
- Preserves the `elapsed_time_in_phase` MultiCellDS duplicate hack (`elapsed_time_in_phase_2`).
- Missing file → `String[]`.

### Feature: `cellTypeToNameDict`
- Returns `Dict{Int,String}` mapping cell-type ID → name from `simplified_data/cell_types`.
- Missing file → empty dict.

### Feature: `substrateNames`
- Returns substrate names ordered by variable ID from `microenvironment/domain/variables`.
- Missing file → `String[]`.

---

## Loaders (lazy, in-place)

All loaders are idempotent: if the target container is already populated, they return immediately.

### Feature: `loadCells!`
- `loadCells!(snapshot[, cell_type_to_name_dict, labels])` and `loadCells!(sequence)`.
- Reads `<base>_cells.mat` (variable `cells`), assigns one column per label, converts `ID`→`Int`, `dead`→`Bool`, `cell_type`→`Int`, and appends `cell_type_name`.
- Handles the MAT.jl zero-cell `EOFError` bug via a safe read that returns a `length(labels) × 0` matrix.
- Missing `.mat` → message + `missing`.

### Feature: `loadSubstrates!`
- `loadSubstrates!(snapshot[, substrate_names])` and `loadSubstrates!(sequence)`.
- Reads `<base>_microenvironment0.mat` (variable `multiscale_microenvironment`) into columns `x, y, z, volume, <substrates…>`.
- Missing `.mat` → message + `missing`.

### Feature: `loadMesh!`
- `loadMesh!(snapshot)` and `loadMesh!(sequence)`.
- Fills `mesh` with `bounding_box` and `x`/`y`/`z` coordinate vectors from `microenvironment/domain/mesh`.

### Feature: graph loading
- `physicellEmptyGraph()` → directed `MetaGraph` labeled by `AgentID`, no vertex/edge data.
- `readPhysiCellGraph!(g, path_to_txt)` — parse the `id: id,id,…` adjacency text format.
- `loadGraph!(S, graph::Union{Symbol,String})` where `graph ∈ {:attachments, :spring_attachments, :neighbors}`, mapping to `_attached_cells_graph.txt`, `_spring_attached_cells_graph.txt`, `_cell_neighbor_graph.txt`.
- Missing file → message + `missing`.

### Feature: `AgentID` / `AgentDict`
- `AgentID(id::Int)` wrapper (so `MetaGraph` `Int` vertex indices aren't confused with agent IDs); `parse(AgentID, s)`.
- `AgentDict{T} <: AbstractDict{AgentID,T}` — accepts `Integer` keys and converts to `AgentID`; full `AbstractDict` interface.

---

## Derived Data

### Feature: `cellDataSequence`
**One-line:** Per-cell time series of chosen labels across a whole sequence.
**Priority:** Must-have
- `cellDataSequence(folder, labels; include_dead=false, include_cell_type_name=false)` and overloads for a single `label::String`, and for a `PhysiCellSequence`.
- Returns an `AgentDict` keyed by cell ID; each value is a `NamedTuple` with a `time` vector plus one entry per requested label. Multi-column labels (e.g. `position`) are concatenated into an `N × k` array.
- **Removed vs `loader.jl`:** `simulation_id`/`Simulation` overloads (the folder or a `PhysiCellSequence` is passed instead). PCMM adds the id-based overloads in its wrapper layer.

### Feature: `getCellDataSequence` (deprecated alias)
- Deprecated alias for `cellDataSequence`, emitting `Base.depwarn`. Retained for source compatibility with existing PCMM/user code.

---

## XML Utilities (internal)

**One-line:** Minimal, self-contained LightXML navigation helpers.
**Priority:** Must-have
- Copy the minimal subset the loader needs from ModelManager's `src/xml_utilities.jl`: `retrieveElement`, `retrieveElementError`, `elementIsTerminal`, `getSimpleContent`, `getChildByAttribute`, `getChildByChildContent`.
- These are internal (not exported); PhysiCellOutput must **not** depend on ModelManager for them.
- Do **not** copy the PCMM/ModelManager variation-file machinery (`createXMLFile`, `prepareBaseFile`, `setSimpleContent`, `columnNameToXMLPath`, `postVariationXMLProcessing`, …) — none of it is needed for reading output.

---

## Removed / Excluded PCMM Couplings

The port must **drop** these from the original `loader.jl`:
- `assertInitialized()` — no global project state exists here.
- `pathToOutputFolder(simulation_id)` — the folder is provided directly.
- The `Simulation` type and all `Simulation`/`simulation_id` method overloads.
- The `simulation_id` struct field (replaced by `folder`).

---

## Dependencies

Intended runtime dependencies (to be added to `Project.toml` at implementation time, with approval):
`DataFrames`, `MAT`, `Graphs`, `MetaGraphsNext`, `LightXML`, and `Dates` (stdlib).

All are in the General registry; the package itself will be registered in the **BergmanLabRegistry**.

---

## Testing

**Priority:** Must-have
- Requires a real (small) PhysiCell output folder committed as a test fixture, including at least: two or more `output*.xml`, `*_cells.mat`, `*_microenvironment0.mat`, and the three `*_graph.txt` files, plus an `initial.xml`/`final.xml`.
- Test coverage targets:
  - Snapshot construction (present vs missing files → `missing`), `time`/`runtime` parsing.
  - Sequence construction and count; metadata parsed once.
  - Each loader populates the expected shape; idempotency on re-load.
  - Zero-cell `.mat` `EOFError` path returns an empty (correct-width) frame.
  - `cellDataSequence` scalar vs multi-column concatenation; `include_dead` / `include_cell_type_name`.
  - `indexToFilename` doctests.
  - `AgentDict` behaves as an `AbstractDict` with integer and `AgentID` keys.
- CI adds the BergmanLabRegistry (see `.github/workflows/CI.yml`) so the package resolves as it will once registered.

---

## Acceptance Criteria for the Package as a Whole

1. Given only a path to a PhysiCell output folder, a user can load cells, substrates, mesh, and graphs into Julia with no PCMM/ModelManager install.
2. No public symbol references `simulation_id`, `Simulation`, or any database/project concept.
3. Public function names/behaviors match the original `loader.jl` closely enough that PCMM's migration is a mechanical re-wiring plus a thin id-carrying wrapper.
4. Full test suite passes on `lts`, `1`, and `pre` Julia in CI.
