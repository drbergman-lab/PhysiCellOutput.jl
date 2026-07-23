using PhysiCellOutput
using Test
using DataFrames, Graphs, MetaGraphsNext, Dates, LightXML

const FIXTURE = joinpath(@__DIR__, "fixtures", "output")

@testset "PhysiCellOutput.jl" begin

    @testset "path & filename utilities" begin
        @test PhysiCellOutput.indexToFilename(0) == "output00000000"
        @test PhysiCellOutput.indexToFilename(12) == "output00000012"
        @test PhysiCellOutput.indexToFilename(:initial) == "initial"
        @test PhysiCellOutput.indexToFilename(:final) == "final"
        @test_throws AssertionError PhysiCellOutput.indexToFilename(:middle)

        @test pathToOutputFileBase(FIXTURE, 0) == joinpath(FIXTURE, "output00000000")
        @test pathToOutputXML(FIXTURE, 0) == joinpath(FIXTURE, "output00000000.xml")
        @test pathToOutputXML(FIXTURE) == joinpath(FIXTURE, "initial.xml") # default :initial
    end

    @testset "metadata readers" begin
        xml = joinpath(FIXTURE, "initial.xml")
        @test cellTypeToNameDict(xml) == Dict(0 => "default")
        @test substrateNames(xml) == ["substrate"]
        labels = cellLabels(xml)
        @test "ID" in labels
        @test "position_1" in labels && "position_3" in labels
        @test "total_volume" in labels
        @test length(labels) == 88

        # Missing file → empty containers (never throws)
        missing_xml = joinpath(FIXTURE, "does_not_exist.xml")
        @test cellLabels(missing_xml) == String[]
        @test cellTypeToNameDict(missing_xml) == Dict{Int,String}()
        @test substrateNames(missing_xml) == String[]
    end

    @testset "PhysiCellSnapshot" begin
        snap = PhysiCellSnapshot(FIXTURE, 0)
        @test snap isa PhysiCellSnapshot
        @test snap isa PhysiCellOutput.AbstractPhysiCellSequence
        @test snap.folder == FIXTURE
        @test snap.index == 0
        @test snap.time == 0.0
        @test snap.runtime isa Nanosecond
        # lazy: nothing loaded yet
        @test isempty(snap.cells)
        @test isempty(snap.substrates)
        @test isempty(snap.mesh)
        @test nv(snap.attachments) == 0

        # missing snapshot → missing (with message), not an exception
        @test PhysiCellSnapshot(FIXTURE, 99) === missing

        # symbol indices
        @test PhysiCellSnapshot(FIXTURE, :initial) isa PhysiCellSnapshot
        @test PhysiCellSnapshot(FIXTURE, :final) isa PhysiCellSnapshot

        # include_cells populates cells with the derived cell_type_name column and typed columns
        snapc = PhysiCellSnapshot(FIXTURE, :final; include_cells=true)
        @test !isempty(snapc.cells)
        @test "cell_type_name" in names(snapc.cells)
        @test eltype(snapc.cells.ID) == Int
        @test eltype(snapc.cells.dead) == Bool
        @test eltype(snapc.cells.cell_type) == Int
        @test all(==("default"), snapc.cells.cell_type_name)

        # include_substrates
        snaps = PhysiCellSnapshot(FIXTURE, 0; include_substrates=true)
        @test names(snaps.substrates) == ["x", "y", "z", "volume", "substrate"]
        @test nrow(snaps.substrates) > 0

        # include_mesh
        snapm = PhysiCellSnapshot(FIXTURE, 0; include_mesh=true)
        @test sort(collect(keys(snapm.mesh))) == ["bounding_box", "x", "y", "z"]
        @test length(snapm.mesh["bounding_box"]) == 6

        # include graphs
        snapg = PhysiCellSnapshot(FIXTURE, :final;
                                  include_attachments=true,
                                  include_spring_attachments=true,
                                  include_neighbors=true)
        @test nv(snapg.neighbors) > 0
        @test is_directed(snapg.neighbors)
    end

    @testset "PhysiCellSequence" begin
        seq = PhysiCellSequence(FIXTURE)
        @test seq isa PhysiCellSequence
        @test seq.folder == FIXTURE
        @test length(seq.snapshots) == 3   # output0000000{0,1,2}
        @test seq.cell_type_to_name_dict == Dict(0 => "default")
        @test length(seq.labels) == 88
        @test seq.substrate_names == String[]   # not requested

        # substrate names populated when requested
        seq_sub = PhysiCellSequence(FIXTURE; include_substrates=true)
        @test seq_sub.substrate_names == ["substrate"]

        # snapshots are in index order
        @test [s.index for s in seq.snapshots] == [0, 1, 2]
    end

    @testset "lazy loaders + idempotency" begin
        seq = PhysiCellSequence(FIXTURE)
        loadCells!(seq)
        @test all(!isempty(s.cells) for s in seq.snapshots)
        rows_before = nrow(seq.snapshots[1].cells)
        loadCells!(seq)                     # idempotent: no duplication
        @test nrow(seq.snapshots[1].cells) == rows_before

        snap = PhysiCellSnapshot(FIXTURE, 0)
        loadSubstrates!(snap)
        @test !isempty(snap.substrates)
        loadMesh!(snap)
        @test !isempty(snap.mesh)
        loadGraph!(snap, :neighbors)
        loadGraph!(snap, "attachments")     # string form
        @test nv(snap.neighbors) ≥ 0

        @test_throws AssertionError loadGraph!(snap, :not_a_graph)
    end

    @testset "cellDataSequence" begin
        # scalar label → Vector; multi-column label → N×k matrix
        data = cellDataSequence(FIXTURE, ["position", "total_volume"]; include_dead=true)
        @test data isa PhysiCellOutput.AgentDict
        id = first(keys(data.dict)).id
        rec = data[id]
        n = length(rec.time)
        @test size(rec.position) == (n, 3)
        @test length(rec.total_volume) == n
        @test !haskey(rec, :cell_type_name)

        # single scalar label as a plain String, with cell type name
        data2 = cellDataSequence(FIXTURE, "total_volume"; include_cell_type_name=true)
        id2 = first(keys(data2.dict)).id
        @test haskey(data2[id2], :cell_type_name)
        @test all(==("default"), data2[id2].cell_type_name)

        # unknown label errors
        @test_throws AssertionError cellDataSequence(FIXTURE, "not_a_label")
    end

    @testset "AgentID / AgentDict" begin
        @test PhysiCellOutput.AgentID(5).id == 5
        @test parse(PhysiCellOutput.AgentID, "7") == PhysiCellOutput.AgentID(7)

        d = PhysiCellOutput.AgentDict(Dict(1 => "a", 2 => "b"))
        @test d isa AbstractDict
        @test length(d) == 2
        @test d[1] == "a"                          # integer key
        @test d[PhysiCellOutput.AgentID(2)] == "b" # AgentID key
        @test haskey(d, 1) && haskey(d, PhysiCellOutput.AgentID(2))
        d[3] = "c"
        @test d[3] == "c"
        delete!(d, 3)
        @test !haskey(d, 3)
        @test Set(v for (_, v) in d) == Set(["a", "b"])
    end

    @testset "getCellDataSequence deprecation" begin
        @test (@test_deprecated getCellDataSequence(FIXTURE, "total_volume")) isa PhysiCellOutput.AgentDict
    end

    @testset "getSimpleContent required=false" begin
        xml_doc = parse_file(joinpath(FIXTURE, "initial.xml"))
        try
            # present terminal element → content
            @test PhysiCellOutput.getSimpleContent(xml_doc, ["metadata", "current_time"]) isa String
            # missing path with required=false → nothing (not an error)
            @test PhysiCellOutput.getSimpleContent(xml_doc, ["metadata", "not_a_field"]; required=false) === nothing
            # missing path with required=true → error
            @test_throws ArgumentError PhysiCellOutput.getSimpleContent(xml_doc, ["metadata", "not_a_field"])
        finally
            free(xml_doc)
        end
    end

    @testset "show is side-effect free" begin
        seq = PhysiCellSequence(FIXTURE)   # mesh not loaded
        @test isempty(seq.snapshots[1].mesh)
        str = sprint(show, seq)
        @test isempty(seq.snapshots[1].mesh)          # show did not mutate/load
        @test occursin("Mesh: NOT LOADED", str)
        loadMesh!(seq)
        @test occursin("grid on", sprint(show, seq))  # mesh info shown once loaded
    end
end
