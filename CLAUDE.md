# CLAUDE.md — PhysiCellOutput.jl

## About the User
Assistant professor working on computational modeling of cancer-immune interactions, mechanistic and agent-based modeling. Author and maintainer of the PhysiCell tooling ecosystem in `~/.julia/dev/` (PhysiCellModelManager, ModelManager, PhysiCellXMLRules, PhysiCellCellCreator, PhysiCellECMCreator, …).

## Key Documents — Read These First

| Document | Purpose |
|----------|---------|
| [README.md](README.md) | Project overview + **Implementation Status** (what is built, what remains) |
| [PRD.md](PRD.md) | Behavioral specification for every feature — acceptance criteria and edge cases |
| [progress.md](progress.md) | Session journal: decisions made, approaches rejected, open questions |

Start any feature session by reading the relevant PRD entry and the Implementation Status section of `README.md`.

## Project Overview
PhysiCellOutput.jl reads the output folder of a **single PhysiCell simulation** and loads its data into Julia — cells, substrates, mesh, and the attachment/spring/neighbor graphs — as `DataFrame`s, dictionaries, and `MetaGraph`s. It is a **lightweight, path-based** package: given a path to an output folder, it loads the data with no database, no project structure, and no simulation registry.

It exists to take over the `loader.jl` functionality currently living in [PhysiCellModelManager.jl](https://github.com/drbergman-lab/PhysiCellModelManager.jl) (PCMM) at `~/.julia/dev/PhysiCellModelManager/src/loader.jl`, so that loading PhysiCell data no longer requires the heavy PCMM dependency (SQLite database, project configuration, ModelManager infrastructure, etc.). PCMM will be updated to depend on PhysiCellOutput and re-add its own database-specific concepts (see below).

**Key directories:**
- `src/` — all package logic
- `test/` — test suite (`test/runtests.jl`)
- `docs/` — Documenter.jl site

## Relationship to PCMM — the Boundary
PhysiCellOutput is the base; PCMM will depend on it. The data model is **path-based**:

- `PhysiCellSnapshot` and `PhysiCellSequence` are keyed on the **output-folder path**, not a PCMM `simulation_id`. The `simulation_id` is a PCMM database concept with no meaning to someone holding a bare output folder, so it does **not** appear in this package's public types.
- PCMM converts `simulation_id → path` at its own boundary and calls into PhysiCellOutput with the path. Where PCMM wants the id shown (e.g. in `show`), it wraps the PhysiCellOutput types in a thin PCMM-side struct that carries the `simulation_id` and adds a custom `show`.

When working in this repo:
- Do **not** add PCMM-specific concepts (simulation IDs, `Simulation`, database queries, `assertInitialized`, `pathToOutputFolder`) to this package.
- Keep the public API expressible in terms of paths (and objects derived from paths).
- Treat the port as a *simplification*: strip the PCMM couplings from the original `loader.jl` rather than reproducing them.

## Scope
All work must remain strictly inside this repository folder (`~/.julia/dev/PhysiCellOutput/`).
Do **not** modify files in sibling packages (PCMM, ModelManager, …). You may **read** them for reference — the original `loader.jl` and ModelManager's `src/xml_utilities.jl` are the primary references for the port.

## Git Workflow
This is a standard Claude Code environment (runs on the user's machine, no sandbox restrictions).
- Never commit directly to `main`; branch first (`feature/<desc>`, based on `main` unless told otherwise).
- Commit or push **only when the user asks**.
- End commit messages with the `Co-Authored-By` trailer for Claude.
- `git log`, `git status`, `git diff`, `git show`, `git branch` freely.

## Naming Conventions
Mirror the PCMM/ModelManager house style:
- **Functions:** `camelCase` (e.g., `cellDataSequence`, `loadCells!`, `pathToOutputXML`)
- **Types / Structs:** `PascalCase` (e.g., `PhysiCellSnapshot`, `PhysiCellSequence`, `AgentID`)
- **Internal helpers:** prefixed with `_` (e.g., `_loadCells!`, `_loadGraph!`, `_safe_matread`)
- **Files:** `snake_case.jl`
- **Exported vs internal:** public API is exported from the relevant `src/*.jl`; internal helpers are `_`-prefixed and not exported.
- Mutating functions end in `!`.

## Local Julia Environment
Always use the project environment:
- `julia --project=.`

Preferred test command:
```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

- Do not edit `Manifest.toml` or add/remove dependencies without explicit approval. The intended runtime dependencies for the port are: `DataFrames`, `MAT`, `Graphs`, `MetaGraphsNext`, `LightXML`, and `Dates` (stdlib).

## Required Workflow for Any Change
1. Generate a **design brief** in the assistant response **before any code changes**.
2. Wait for human approval.
   1. Update `PRD.md` to include the new feature or change.
   2. Open a new entry in `progress.md` and log the design process, decisions, and open questions.
3. Create a feature branch (`git branch feature/<desc>`; the user may switch to it).
4. Implement on the feature branch only.
5. Update the `README.md` Implementation Status when a feature is complete.
6. Trim `PRD.md` and `progress.md` to reflect the final implementation before merging.
7. When the user asks to commit, provide/run the commit with the `Co-Authored-By` trailer.

**Design brief template:**
```
# Design Brief: [Feature/Refactor Name]

## Motivation
[Why is this change needed? What problem does it solve?]

## Scope
- Files affected / new files
- Breaking changes: Yes/No

## Proposed Architecture
- Current vs proposed
- Key decisions (why this over alternatives)

## Testing Strategy
- Unit tests / integration tests

## Estimated Effort
- Lines of code, risk level, dependencies
```

## Definition of Done
A feature is complete when **all** of the following are true:
1. **Tests pass:** `julia --project=. -e 'using Pkg; Pkg.test()'` runs green.
2. **Docstrings written:** every exported function has a docstring with description, argument list, return value, and at least one usage example.
3. **README updated:** Implementation Status marks the feature complete.
4. **PRD reflects reality:** update the PRD entry if implementation deviated.
5. **No regressions:** full suite has no new failures.

## Integration Essentials
- Module entrypoint: `src/PhysiCellOutput.jl` (update `include`s when adding/moving files).
- The port needs a small self-contained set of LightXML helpers (`retrieveElement`, `getSimpleContent`, `getChildByAttribute`, `getChildByChildContent`, `retrieveElementError`, `elementIsTerminal`). These currently live in `~/.julia/dev/ModelManager/src/xml_utilities.jl`; copy the minimal subset here rather than depending on ModelManager.
- Test fixtures: a real PhysiCell output folder (with `output*.xml`, `*_cells.mat`, `*_microenvironment0.mat`, and the `*_graph.txt` files) is needed for meaningful tests. See PRD "Testing" for the fixture plan.

## PhysiCellOutput-Specific Guidance
- This package is **path-centric and stateless**. No global state, no `__init__` registry, no database.
- Reads only — this package never writes PhysiCell output files.
- Keep the public function surface API-compatible (by name and behavior) with the original PCMM `loader.jl` where practical, so PCMM's migration is a mechanical re-wiring plus its thin wrapper.
