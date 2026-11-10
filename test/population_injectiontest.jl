###
### POPULATION INJECTION (STAGED POPULATION CHANGES)
###
### Part 1: unit suite ported from DynamicPopulationLog.jl (renamed to the GEMS injection vocabulary)
### Part 2: GEMS integration (Simulation hooks, snapshot rebasing, deaths, reset!)
###

using GEMS
using DataFrames
using Test
using Random
using JLD2
using Statistics
using Logging

const PI = GEMS.PopulationInjection

# Log-record collector for asserting on warning output (warn-once behaviour)
mutable struct WarnCollector <: Logging.AbstractLogger
    messages::Vector{String}
end
Logging.min_enabled_level(col::WarnCollector) = Logging.Debug
Logging.shouldlog(col::WarnCollector, level, _module, group, id) = level >= Logging.Debug
function Logging.handle_message(col::WarnCollector, level, msg, _module, group, id, file, line; _private...)
    push!(col.messages, string(msg))
    return nothing
end


###
### PART 1 — INJECTOR UNIT SUITE (ported)
###

# Test data generation function
function generate_test_population()
    Random.seed!(1234)
    # Create a test DataFrame with various data types
    df = DataFrame(
        id=Int32.(1:100),
        name=string.("Person_", 1:100),
        age=Int8.(rand(18:80, 100)),
        salary=rand(30000.0:150000.0, 100),
        department=rand(["IT", "HR", "Finance", "Marketing", "Operations"], 100),
        active=rand([true, false], 100),
        score=rand(0.0:100.0, 100),
        sex=Int8.(rand(1:2, 100))
    )
    return df
end

# Test 1: Basic injector creation and schema creation
@testset "Basic Injector Functionality" begin
    # Generate test population
    base_pop = generate_test_population()

    # Create schema
    schema = PI.create_column_schema(base_pop)

    # Create injector
    inj = PI.Injector(schema)

    @test inj isa PI.Injector
    @test inj.schema isa PI.InjectorSchema
    @test length(inj.events) == 0

    # Test schema metadata
    @test haskey(inj.schema.meta, :ind_id_type)
    @test haskey(inj.schema.meta, :num_individuals)
    @test inj.schema.meta[:num_individuals] == 100
end

# Test 2: Event staging and encoding
@testset "Event Staging and Encoding" begin
    base_pop = generate_test_population()
    inj = PI.Injector(PI.create_column_schema(base_pop))

    # Test staging events
    event1 = PI.stage_event!(inj, 1, :age, 25, Int16(100))
    event2 = PI.stage_event!(inj, 3, :department, "IT", Int16(200))

    @test length(inj.events) == 2
    # Event types will depend on the specific column encoding
    @test event1 isa PI.Event
    @test event2 isa PI.Event


    # Test event properties
    @test event1.ind_id == 1
    @test event1.timestamp == 100
    @test event1.field == inj.schema.field_to_index[:age]  # age field index
    @test event2.ind_id == 3
    @test event2.timestamp == 200
end

# Test 2b: setting-id staging rules (new households / offices / school classes, ...)
@testset "Setting ID Staging Rules" begin
    # Base population: 40 individuals in 10 households (ids 1:10)
    base_pop = DataFrame(
        id = Int32.(1:40),
        age = Int8.(repeat(18:21, inner = 10)[1:40]),
        sex = Int8.(repeat([1, 2], inner = 20)[1:40]),
        household = Int32.(repeat(1:10, inner = 4))
    )
    schema = PI.create_column_schema(base_pop)
    inj = PI.Injector(schema)

    # extend the schema so the new household ids (and the values of the negative tests
    # below, which must be encodable for the setting-id rule to be reached) can be encoded
    PI.update_schema!(inj.schema, :household, vcat(Int32.([-1, 0]), Int32.(11:15)))

    # the first new household id (max base id + 1) is valid
    PI.stage_event!(inj, 1, :household, Int32(11), Int16(1))
    # the same new household id may be referenced again by later events
    # (a second individual joins the newly formed household)
    PI.stage_event!(inj, 2, :household, Int32(11), Int16(2))
    # the next new household id is valid as well
    PI.stage_event!(inj, 3, :household, Int32(12), Int16(3))

    @test length(inj.events) == 3
    @test PI.get_original_value(inj, inj.events[2]) == 11

    # skipping a new id would leave a gap → staging error
    @test_throws ArgumentError PI.stage_event!(inj, 4, :household, Int32(14), Int16(4))
    # an id that is neither a base id nor the default "no setting" id → staging error
    @test_throws ArgumentError PI.stage_event!(inj, 4, :household, Int32(0), Int16(4))
    # the default id ("no household") is always allowed
    PI.stage_event!(inj, 4, :household, Int32(GEMS.DEFAULT_SETTING_ID), Int16(4))
    # existing base household ids remain valid
    PI.stage_event!(inj, 5, :household, Int32(3), Int16(5))

    # the running max of the staged new ids is cached in the schema meta (O(1) checks)
    @test inj.schema.meta[:setting_max_new][:household] == Int32(12)
    # with the cache in place the rule is unchanged: staged new ids and the next new id pass
    PI.stage_event!(inj, 6, :household, Int32(11), Int16(6))
    PI.stage_event!(inj, 7, :household, Int32(13), Int16(7))
    @test inj.schema.meta[:setting_max_new][:household] == Int32(13)
    @test_throws ArgumentError PI.stage_event!(inj, 8, :household, Int32(15), Int16(8))
end

# Test 2c: pre-cache saved injectors fall back to the event scan, then re-cache
@testset "Setting ID check without the meta cache (legacy saved injector)" begin
    base_pop = DataFrame(
        id = Int32.(1:20),
        age = Int8.(repeat(18:21, inner = 5)[1:20]),
        sex = Int8.(repeat([1, 2], inner = 10)[1:20]),
        household = Int32.(repeat(1:5, inner = 4))
    )
    schema = PI.create_column_schema(base_pop)
    inj = PI.Injector(schema)
    PI.update_schema!(inj.schema, :household, vcat(Int32.([-1, 0]), Int32.(6:8)))
    PI.stage_event!(inj, 1, :household, Int32(6), Int16(1))
    PI.stage_event!(inj, 2, :household, Int32(7), Int16(2))

    # simulate an injector saved before the setting_max_new cache existed
    delete!(inj.schema.meta, :setting_max_new)
    # the fallback event scan reconstructs the max: staged new ids and the next new id pass
    PI.stage_event!(inj, 3, :household, Int32(7), Int16(3))
    PI.stage_event!(inj, 4, :household, Int32(8), Int16(4))
    # ...and the cache is populated again for subsequent checks
    @test inj.schema.meta[:setting_max_new][:household] == Int32(8)
    @test_throws ArgumentError PI.stage_event!(inj, 5, :household, Int32(10), Int16(5))
end

# Test 3: Encoding and decoding functionality
@testset "Encoding and Decoding" begin
    base_pop = generate_test_population()
    inj = PI.Injector(PI.create_column_schema(base_pop))

    # Test encode/decode cycle
    original_value = 30
    encoded = PI.encode_value(inj, :age, original_value)
    decoded = PI.decode_value(inj, :age, encoded)
    @test decoded == original_value

    original_value = 30.5
    encoded = PI.encode_value(inj, :salary, original_value)
    decoded = PI.decode_value(inj, :salary, encoded)

    @test decoded == original_value


    # Test with string values
    dept_value = "Finance"
    encoded_dept = PI.encode_value(inj, :department, dept_value)
    decoded_dept = PI.decode_value(inj, :department, encoded_dept)

    @test decoded_dept == dept_value
end

# Test 4: Error handling
@testset "Error Handling" begin
    base_pop = generate_test_population()
    inj = PI.Injector(PI.create_column_schema(base_pop))

    # Test error when trying to encode a value not in schema
    @test_throws ErrorException PI.encode_value(inj, :age, 9999)  # Value not in original data

    # Test error when trying to encode a value not in schema for string field
    @test_throws ErrorException PI.encode_value(inj, :department, "UnknownDept")
end

# Test 5: Snapshot functionality
@testset "Snapshot Functionality" begin
    base_pop = generate_test_population()
    inj = PI.Injector(PI.create_column_schema(base_pop))

    # Stage some events
    PI.stage_event!(inj, 1, :age, 25, Int16(100))
    PI.stage_event!(inj, 2, :department, "IT", Int16(200))
    PI.stage_event!(inj, 3, :salary, Float64(123.456), Int16(299))

    # Create snapshot at different timestamps
    snapshot1 = PI.snapshot(inj, base_pop, Int16(120))
    snapshot2 = PI.snapshot(inj, base_pop, Int16(250))
    snapshot3 = PI.snapshot(inj, base_pop, Int16(300))

    @test snapshot1 isa DataFrame
    @test snapshot2 isa DataFrame
    @test size(snapshot1) == size(base_pop)
    @test size(snapshot2) == size(base_pop)

    # Verify that the snapshot reflects the staged events
    @test snapshot1[1, :age] == 25
    @test snapshot2[1, :age] == 25
    @test snapshot2[2, :department] == "IT"
    @test isapprox(snapshot3[3, :salary], Float64(123.456))
end

# Test 6: File save/load functionality
@testset "Save/Load (saved injector)" begin
    base_pop = generate_test_population()
    inj = PI.Injector(PI.create_column_schema(base_pop))

    # Stage some events
    PI.stage_event!(inj, 1, :age, 25, Int16(100))

    # Save to file
    filename = "test_injector.jld2"
    PI.save(inj, filename)

    # Load from file
    loaded_inj = PI.Injector(filename)

    @test loaded_inj isa PI.Injector
    @test length(loaded_inj.events) == 1

    # Clean up
    rm(filename)
end

# Test 7: Edge cases and boundary conditions
@testset "Edge Cases" begin
    # Test with empty DataFrame
    empty_df = DataFrame(id=Int32[], name=String[], age=Int8[], sex=Int8[])
    schema = PI.create_column_schema(empty_df)
    inj = PI.Injector(schema)

    @test schema isa PI.InjectorSchema
    @test inj isa PI.Injector

    # Test with single row
    single_row_df = DataFrame(id=Int32[1], name=["Test"], age=Int8[25], sex=Int8[1])
    single_schema = PI.create_column_schema(single_row_df)
    single_inj = PI.Injector(single_schema)

    @test single_schema.meta[:num_individuals] == 1
    @test single_inj isa PI.Injector

    # Test with boolean values
    bool_df = DataFrame(id=Int32[1, 2, 3], age=Int8[30, 40, 50], sex=Int8[1, 2, 1],
                        active=[true, false, true])
    bool_schema = PI.create_column_schema(bool_df)
    bool_inj = PI.Injector(bool_schema)

    @test bool_schema isa PI.InjectorSchema
    @test bool_inj isa PI.Injector

    # Test staging boolean values
    PI.stage_event!(bool_inj, 1, :active, true, Int16(100))
    @test length(bool_inj.events) == 1
end

# Test 9: Field mapping functionality
@testset "Field Mapping" begin
    base_pop = generate_test_population()
    inj = PI.Injector(PI.create_column_schema(base_pop))

    # Test field to index mapping
    @test haskey(inj.schema.field_to_index, :id)
    @test haskey(inj.schema.field_to_index, :name)
    @test haskey(inj.schema.field_to_index, :age)

    # Test index to field mapping
    @test length(inj.schema.index_to_field) == 8
    @test inj.schema.index_to_field[1] == :id
    @test inj.schema.index_to_field[2] == :name
    @test inj.schema.index_to_field[3] == :age
end

@testset "create_column_schema enforces the required and setting columns" begin
    # missing required columns - the error names the columns, their required types, and the fix
    ex = try
        PI.create_column_schema(DataFrame(id = Int32.(1:5), name = ["a", "b", "c", "d", "e"]))
        nothing
    catch e
        e
    end
    @test ex isa ArgumentError
    @test occursin(":age", ex.msg) && occursin(":sex", ex.msg)
    @test occursin("Int8", ex.msg) && occursin("dataframe(population)", ex.msg)
    # wrong element type - id must be Int32 (the hash is dtype-sensitive)
    ex = try
        PI.create_column_schema(DataFrame(id = 1:5, age = Int8.(20:24), sex = Int8.(1:5)))
        nothing
    catch e
        e
    end
    @test ex isa ArgumentError
    @test occursin(":id is Int64 but must be Int32", ex.msg)
    # a present setting column must keep the Individual field type (Int32)
    ex = try
        PI.create_column_schema(DataFrame(id = Int32.(1:5), age = Int8.(20:24), sex = Int8.(1:5),
                                         household = 1:5))
        nothing
    catch e
        e
    end
    @test ex isa ArgumentError
    @test occursin(":household is Int64 but must be Int32", ex.msg)
    # setting columns are optional: no :household/office/schoolclass column is fine
    schema = PI.create_column_schema(DataFrame(id = Int32.(1:5), age = Int8.(20:24), sex = Int8.(1:5)))
    @test length(schema.index_to_field) == 3
    # …and a present setting column with the correct type is accepted
    schema = PI.create_column_schema(DataFrame(id = Int32.(1:5), age = Int8.(20:24), sex = Int8.(1:5),
                                               household = Int32.(1:5)))
    @test length(schema.index_to_field) == 4
end

# Test 10: Complete workflow test
@testset "Complete Workflow" begin
    # Generate base population
    base_pop = generate_test_population()

    # Create injector
    schema = PI.create_column_schema(base_pop)
    PI.update_schema!(schema, :age, Int8.(collect(0:1:115)))

    inj = PI.Injector(schema)
    # Stage multiple events
    for i in 1:10
        PI.stage_event!(inj, i, :age, 20 + i, Int16(i * 10))
    end

    # Create snapshots
    snapshot1 = PI.snapshot(inj, base_pop, Int16(50))
    snapshot2 = PI.snapshot(inj, base_pop, Int16(150))

    # Verify snapshots
    @test length(inj.events) == 10
    @test snapshot1 isa DataFrame
    @test snapshot2 isa DataFrame

    # Test that the injector can be saved and loaded
    filename = "workflow_test.jld2"
    PI.save(inj, filename)
    loaded_inj = PI.Injector(filename)

    @test length(loaded_inj.events) == 10
    rm(filename)
end

# Test 10a: Hash Consistency and Stability Tests
@testset "Hash Consistency Tests" begin
    base_pop = generate_test_population()

    # Test 10a.1: Same data produces same hash across multiple computations
    @testset "Stable hashing - same data, same hash" begin
        # Create multiple DataFrames with identical content
        df1 = copy(base_pop)
        df2 = copy(base_pop)

        # Compute hashes for each column in all three DataFrames
        for col_name in names(base_pop)
            hash1 = PI.stable_hash(df1[:, col_name])
            hash2 = PI.stable_hash(df2[:, col_name])

            @test hash1 == hash2
        end
    end

    # Test 10a.2: Different type produces different hash (e.g., Int8 vs Int16)
    @testset "Type mismatch - Int8 vs Int16 should produce different hashes" begin
        # Create a DataFrame with Int8 column
        int8_df = DataFrame(id=Int8[1, 2, 3, 4, 5])

        # Create a DataFrame with Int16 column with same values
        int16_df = DataFrame(id=Int16[1, 2, 3, 4, 5])

        # Hashes should be different because the underlying byte representation differs
        int8_hash = PI.stable_hash(int8_df[:, :id])
        int16_hash = PI.stable_hash(int16_df[:, :id])

        @test int8_hash != int16_hash
    end

    # Test 10a.3: Different values produce different hashes
    @testset "Value mismatch - different values should produce different hashes" begin
        df_same = DataFrame(id=Int8[1, 2, 3, 4, 5])
        df_different = DataFrame(id=Int8[1, 2, 3, 4, 6])  # Last value differs

        hash_same = PI.stable_hash(df_same[:, :id])
        hash_different = PI.stable_hash(df_different[:, :id])

        @test hash_same != hash_different
    end

    # Test 10a.4: Empty DataFrame handling
    @testset "Empty column hashing" begin
        df1 = DataFrame(id=Int8[])
        df2 = DataFrame(id=Int8[])

        hash1 = PI.stable_hash(df1[:, :id])
        hash2 = PI.stable_hash(df2[:, :id])

        @test hash1 == hash2
    end

    # Test 10a.5: Mixed type column hashing (strings)
    @testset "String column hashing stability" begin
        df1 = DataFrame(name=["Alice", "Bob", "Charlie"])
        df2 = DataFrame(name=["Alice", "Bob", "Charlie"])

        hash1 = PI.stable_hash(df1[:, :name])
        hash2 = PI.stable_hash(df2[:, :name])

        @test hash1 == hash2
    end

    # Test 10a.6: Boolean column hashing stability
    @testset "Boolean column hashing stability" begin
        df1 = DataFrame(active=[true, false, true, false])
        df2 = DataFrame(active=[true, false, true, false])

        hash1 = PI.stable_hash(df1[:, :active])
        hash2 = PI.stable_hash(df2[:, :active])

        @test hash1 == hash2
    end

    # Test 10a.7: Float column hashing stability
    @testset "Float column hashing stability" begin
        df1 = DataFrame(salary=[35000.0, 45000.0, 55000.0])
        df2 = DataFrame(salary=[35000.0, 45000.0, 55000.0])

        hash1 = PI.stable_hash(df1[:, :salary])
        hash2 = PI.stable_hash(df2[:, :salary])

        @test hash1 == hash2
    end
end

# Test 11: stage_new_individuals! Comprehensive Tests
# Note: All string values must exist in the base population encoding maps,
# and individual ids must be within Int8 range (-127 to 127) for this test setup.
@testset "stage_new_individuals! Functionality" begin
    # Setup: Create a base population for testing
    Random.seed!(42)
    base_pop = generate_test_population()

    # Test 11.1: Basic functionality - adding a new individual with subset of fields
    @testset "Basic Individual Addition" begin
        schema = PI.create_column_schema(base_pop)
        PI.update_schema!(schema, :age, Int8.(0:115))  # Expand age range to support all test values
        inj = PI.Injector(schema)

        # Add a new individual using only existing values from base population
        new_individuals = DataFrame(
            name=["Person_1"],  # Use existing name from base population
            age=[Int8.(25)[1]],
            sex=[Int8(1)],      # :sex and :age are required for new individuals
            salary=[Float64(50000.0)],
            department=["IT"],  # Use existing department
            active=[true],
            score=[Float64(85.5)]
        )

        new_id = PI.stage_new_individuals!(inj, new_individuals, Int16(300))

        @test isa(collect(new_id), Vector{Int})
        @test length(inj.events) == 7  # One event per field (excluding id)
    end

    # Test 11.12: Snapshot functionality with stage_new_individuals!
    @testset "Snapshot with stage_new_individuals!" begin
        schema = PI.create_column_schema(base_pop)
        PI.update_schema!(schema, :age, Int8.(0:115))  # Expand age range to support all test values
        inj = PI.Injector(schema)

        # Stage some events on existing individuals first
        PI.stage_event!(inj, 1, :age, Int8.(25)[1], Int16(100))
        PI.stage_event!(inj, 2, :department, "HR", Int16(200))

        # Add a new individual via stage_new_individuals! at timestamp 300
        new_individuals = DataFrame(
            name=["Person_5"],
            age=[Int8.(35)[1]],
            sex=[Int8(1)],
            salary=[Float64(90000.0)],
            department=["Finance"],
            active=[true],
            score=[Float64(72.0)]
        )
        new_id = PI.stage_new_individuals!(inj, new_individuals, Int16(300))

        # Test snapshot at timestamp before stage_new_individuals! (Int16(250))
        # New individual should not appear in the snapshot since it wasn't created yet
        snapshot_before = PI.snapshot(inj, base_pop, Int16(250))
        @test size(snapshot_before) == (100, 8)  # Original size

        # Test snapshot at timestamp after stage_new_individuals! (Int16(350))
        # New individual should appear in the snapshot with all its field values
        snapshot_after = PI.snapshot(inj, base_pop, Int16(350))
        @test size(snapshot_after) == (101, 8)  # Size increased by 1

        # Verify the new individual's values are correctly reflected in the snapshot
        # The newly added individual should have all the values we set via stage_new_individuals!
        @test snapshot_after[new_id[1], :name] == "Person_5"
        @test snapshot_after[new_id[1], :age] == Int8.(35)[1]
        @test snapshot_after[new_id[1], :salary] == Float64(90000.0)
        @test snapshot_after[new_id[1], :department] == "Finance"
        @test snapshot_after[new_id[1], :active] == true
        @test isapprox(snapshot_after[new_id[1], :score], Float64(72.0); atol=1e-6)

        # Verify existing individual updates are still reflected in the later snapshot
        @test snapshot_after[1, :age] == Int8.(25)[1]
        @test snapshot_after[2, :department] == "HR"

        # Test intermediate snapshot at timestamp Int16(300) - exactly when the individual was added
        snapshot_at_addition = PI.snapshot(inj, base_pop, Int16(300))
        @test size(snapshot_at_addition) == (101, 8)
        @test snapshot_at_addition[new_id[1], :name] == "Person_5"
    end

    # Test 11.13: Multiple snapshots with sequential stage_new_individuals! operations
    @testset "Sequential Snapshots After stage_new_individuals!" begin
        schema = PI.create_column_schema(base_pop)
        PI.update_schema!(schema, :age, Int8.(0:115))
        inj = PI.Injector(schema)

        # Add first individual at timestamp 400
        new_individuals_1 = DataFrame(
            name=["Person_6"],
            age=[Int8.(40)[1]],
            sex=[Int8(1)],
            salary=[Float64(55000.0)],
            department=["IT"],
            active=[false],
            score=[Float64(75.0)]
        )
        id_1 = PI.stage_new_individuals!(inj, new_individuals_1, Int16(400))

        # Add second individual at timestamp 500
        new_individuals_2 = DataFrame(
            name=["Person_7"],
            age=[Int8.(45)[1]],
            sex=[Int8(2)],
            salary=[Float64(65000.0)],
            department=["HR"],
            active=[true],
            score=[Float64(80.0)]
        )
        id_2 = PI.stage_new_individuals!(inj, new_individuals_2, Int16(500))

        # Snapshot before first new individual (Int16(350)) - should have original size
        snap_early = PI.snapshot(inj, base_pop, Int16(350))
        @test size(snap_early) == (100, 8)

        # Snapshot between the two new individuals (Int16(450)) - should have first individual only
        snap_middle = PI.snapshot(inj, base_pop, Int16(450))
        @test size(snap_middle) == (id_1[1], 8)
        @test snap_middle[id_1[1], :name] == "Person_6"

        # Snapshot after both individuals added (Int16(550)) - should have both new individuals
        snap_late = PI.snapshot(inj, base_pop, Int16(550))
        @test size(snap_late) == (id_2[1], 8)
        @test snap_late[id_1[1], :name] == "Person_6"
        @test snap_late[id_2[1], :name] == "Person_7"
        @test snap_late[id_1[1], :age] == Int8.(40)[1]
        @test snap_late[id_2[1], :age] == Int8.(45)[1]
    end

    # Test 11.14: Snapshot with partial stage_new_individuals! - missing fields appear as missing
    @testset "Snapshot with Partial Individual Data" begin
        schema = PI.create_column_schema(base_pop)
        PI.update_schema!(schema, :age, Int8.(0:115))
        inj = PI.Injector(schema)

        # Add an individual with only some fields specified (:sex/:age required, the rest optional)
        partial_individual = DataFrame(
            name=["Person_8"],
            age=[Int8.(50)[1]],
            sex=[Int8(1)]
        )
        id_3 = PI.stage_new_individuals!(inj, partial_individual, Int16(600))

        # Snapshot after individual addition - verify only specified fields are set
        snap = PI.snapshot(inj, base_pop, Int16(700))
        @test size(snap) == (id_3[1], 8)
        @test snap[id_3[1], :name] == "Person_8"
        @test snap[id_3[1], :age] == Int8.(50)[1]

        # Unspecified fields should retain original values from base population or be missing
        # For newly added individuals, unspecified columns may show as missing or have NA values
        # This depends on how snapshot handles incomplete individual data
    end

    # Test 11.6: Partial individual addition (not all fields)
    @testset "Partial Individual Addition" begin
        schema = PI.create_column_schema(base_pop)
        inj = PI.Injector(schema)

        partial_individual = DataFrame(
            name=["Person_1"],
            age=[Int8.(40)[1]],
            sex=[Int8(1)]
        )

        new_id = PI.stage_new_individuals!(inj, partial_individual, Int16(700))

        @test length(inj.events) == 3  # Only three events created
    end

    # Test 11.7: Type-specific value handling
    @testset "Type-Specific Values" begin
        schema = PI.create_column_schema(base_pop)
        PI.update_schema!(schema, :age, Int8.(0:115))  # Expand age range to support all test values
        inj = PI.Injector(schema)

        individual = DataFrame(
            name=["Person_6"],  # Use existing name
            age=[Int8.(18)[1]],  # Minimum valid age
            sex=[Int8(2)],
            salary=[Float64(30000.0)],  # Minimum salary
            department=["Operations"],  # String value from base population
            active=[false],  # Boolean false
            score=[Float64(100.0)]  # Maximum score
        )

        new_id = PI.stage_new_individuals!(inj, individual, Int16(800))

        @test isa(new_id, Vector{Int})

        # Verify the events can be decoded correctly
        for event in inj.events[end-6:end]
            original_value = PI.get_original_value(inj, event)
            field = inj.schema.index_to_field[event.field+1]
            expected_value = individual[!, field][1]

            if typeof(expected_value) <: AbstractFloat
                @test isapprox(original_value, expected_value; atol=1e-6)
            else
                @test original_value == expected_value
            end
        end
    end

    # Test 11.8: Multiple individual additions in sequence
    @testset "Sequential Individual Addition" begin
        schema = PI.create_column_schema(base_pop)
        PI.update_schema!(schema, :age, Int8.(0:115))  # Expand age range to support all test values
        inj = PI.Injector(schema)

        for i in 1:5
            new_individuals = DataFrame(
                name=["Person_$(i + 6)"],  # Use existing names from base population
                age=[Int8.(20 + i)[1]],
                sex=[Int8(1)],
                salary=[Float64(40000.0 * (i + 1))],
                department=["HR"],  # Use existing department
                active=[true],
                score=[Float64(70.0 + i * 5)]
            )

            result = PI.stage_new_individuals!(inj, new_individuals, Int16(900 + i))
        end

        # Verify total events created
        @test length(inj.events) == 35  # 5 individuals * 7 fields
    end

    # Test 11.9: Return value consistency
    @testset "Return Value Consistency" begin
        schema = PI.create_column_schema(base_pop)
        PI.update_schema!(schema, :age, Int8.(0:115))  # Expand age range to support all test values
        inj = PI.Injector(schema)

        individuals = DataFrame(
            name=["Person_7", "Person_7"],  # Use existing name - two rows
            age=[Int8.(25)[1], Int8.(25)[1]],
            sex=[Int8(1), Int8(2)],
            salary=[Float64(50000.0), Float64(50000.0)],
            department=["Finance", "Finance"],
            active=[true, true],
            score=[Float64(90.0), Float64(90.0)]
        )

        # Call stage_new_individuals! with the same parameters twice
        result1 = PI.stage_new_individuals!(inj, individuals[1:1, :], Int16(1000))
        result2 = PI.stage_new_individuals!(inj, individuals[2:2, :], Int16(1001))

        # Both should return ids for newly added individuals (consecutive)
        @test isa(result1[1], Integer)
        @test result2[1] == 102
    end

    # Test 11.10: Integration with existing injector state
    @testset "Integration with Existing Events" begin
        base_pop = generate_test_population()
        schema = PI.create_column_schema(base_pop)
        PI.update_schema!(schema, :age, Int8.(0:115))  # Expand age range to support all test values
        inj = PI.Injector(schema)

        # First stage some regular events
        PI.stage_event!(inj, 1, :age, 25, Int16(50))
        PI.stage_event!(inj, 2, :salary, Float64(60000.0), Int16(100))

        # Now add a new individual with existing values
        individual = DataFrame(
            name=["Person_8"],  # Use existing name from base population
            age=[Int8.(28)[1]],
            sex=[Int8(1)],
            salary=[Float64(70000.0)],
            department=["Marketing"],
            active=[false],
            score=[Float64(88.5)]
        )

        PI.stage_new_individuals!(inj, individual, Int16(150))

        # Verify events were created for the new individual
        @test length(inj.events) >= 2  # At least 2 fields updated
    end

    @testset "stage_new_individuals! edge cases with special values" begin
        schema = PI.create_column_schema(base_pop)
        PI.update_schema!(schema, :age, Int8.(0:115))  # Expand age range to support all test values
        inj = PI.Injector(schema)

        # Test with NaN and Inf values for score field if applicable
        try
            individual_special = DataFrame(
                name=["Person_9"],  # Use existing name from base population
                age=[Int8.(25)[1]],
                sex=[Int8(1)],
                salary=[Float64(50000.0)],
                department=["Operations"],
                active=[true],
                score=[Float64(NaN)]
            )

            result = PI.stage_new_individuals!(inj, individual_special, Int16(2000))
            @test isa(result, Vector{Int})
        catch e
            # If NaN is not handled, this test can skip with a warning
            @warn "Special value handling test encountered an issue: $(e)"
        end
    end
end


###
### UNIT COVERAGE — type helpers, internal staging paths, change history, stable_hash
###

@testset "determine_minimal_type boundaries" begin
    @test PI.determine_minimal_type(0) == Int8
    @test PI.determine_minimal_type(1) == Int8
    @test PI.determine_minimal_type(255) == Int8                 # Int8 boundary
    @test PI.determine_minimal_type(256) == Int16
    @test PI.determine_minimal_type(65535) == Int16              # Int16 boundary
    @test PI.determine_minimal_type(65536) == Int32
    @test PI.determine_minimal_type(4_294_967_295) == Int32      # Int32 boundary
    @test PI.determine_minimal_type(4_294_967_296) == Int64
    @test PI.determine_minimal_type(typemax(Int)) == Int64
end

@testset "determine_ind_id_type (10% buffer)" begin
    @test PI.determine_ind_id_type(1) == Int8                    # ceil(1.1) = 2
    @test PI.determine_ind_id_type(100) == Int8                  # 110
    @test PI.determine_ind_id_type(231) == Int8                  # ceil(254.1) = 255 — fits
    @test PI.determine_ind_id_type(232) == Int16                 # ceil(255.2) = 256 — overflows
    @test PI.determine_ind_id_type(59_000) == Int16              # ~64_900
    @test PI.determine_ind_id_type(60_000) == Int32              # ~66_000
    @test PI.determine_ind_id_type(3_000_000_000) == Int32       # 3.3e9
    @test PI.determine_ind_id_type(5_000_000_000) == Int64       # 5.5e9
end

@testset "_check_staged_death_reason!" begin
    # non-infection codes (<= 0) are accepted and return nothing
    @test PI._check_staged_death_reason!(GEMS.DEFAULT_DEATH_REASON) === nothing
    @test PI._check_staged_death_reason!(GEMS.DEATH_REASON_NATURAL) === nothing
    @test PI._check_staged_death_reason!(Int8(0)) === nothing
    @test PI._check_staged_death_reason!(Int16(-10)) === nothing
    @test PI._check_staged_death_reason!(Int32(-2)) === nothing

    # positive codes are reserved for pathogen deaths → ArgumentError with a helpful message
    for bad in (Int8(1), Int16(5), Int32(1234), Int(42))
        ex = try
            PI._check_staged_death_reason!(bad)
            nothing
        catch e
            e
        end
        @test ex isa ArgumentError
        @test occursin("staged death_reason $bad", ex.msg)
        @test occursin("positive codes are reserved", ex.msg)
        @test occursin("GEMS.DEATH_REASON_NATURAL", ex.msg)
    end
end

@testset "_stage_event! paths, warnings and errors" begin
    # base WITH the death columns so the :death / :death_reason paths can be exercised
    base = generate_test_population()
    base[!, :death] = Int8.(fill(-1, 100))
    base[!, :death_reason] = Int8.(fill(GEMS.DEFAULT_DEATH_REASON, 100))
    schema = PI.create_column_schema(base)
    PI.update_schema!(schema, :death_reason, [Int8(GEMS.DEATH_REASON_NATURAL)])
    inj = PI.Injector(schema)

    @testset "return value: the staged event, stored in injector.events" begin
        ev = PI._stage_event!(inj, 1, :age, Int8(99), Int16(10))
        @test ev isa PI.Event
        @test ev.ind_id == 1
        @test ev.field == inj.schema.field_to_index[:age]
        @test ev.timestamp == Int16(10)
        @test ev.new_value == Int8(99)                          # identity field: stored as-is
        @test length(inj.events) == 1
        @test inj.events[1] === ev                              # the returned event is the stored one

        # the public wrapper delegates and returns the same event object
        ev2 = PI.stage_event!(inj, 2, :age, Int8(88), Int16(11))
        @test inj.events[2] === ev2
        @test ev2.new_value == Int8(88)
    end

    @testset "encoding branches" begin
        # closed value set: decode round-trips the staged value
        ev = PI.stage_event!(inj, 1, :department, "HR", Int16(12))
        @test ev.field == inj.schema.field_to_index[:department]
        @test PI.get_original_value(inj, ev) == "HR"

        # float column: no encoding, stored as-is
        ev = PI.stage_event!(inj, 1, :salary, Float64(60000.0), Int16(13))
        @test ev.new_value == Float64(60000.0)

        # float conversion warning: NaN != NaN, so the "converted" warning fires
        col = WarnCollector(String[])
        with_logger(col) do
            ev = PI.stage_event!(inj, 1, :score, Float64(NaN), Int16(14))
        end
        @test isnan(ev.new_value)
        @test count(m -> occursin("was converted to NaN for encoding", m), col.messages) == 1
    end

    @testset "death and death_reason via the internal path" begin
        # :death: non-alive values are stored as the dead flag (the timestamp is the day of death)
        ev = PI._stage_event!(inj, 1, :death, "ignored-value", Int16(5))
        @test ev isa PI.Event{Int8}
        @test ev.new_value == PI.INJECTION_DEATH_FLAG
        @test ev.ind_id == 1
        @test ev.field == inj.schema.field_to_index[:death]
        @test ev.timestamp == Int16(5)

        # alive values are RECORDED as the alive marker (never skipped, never a death) ...
        for alive_val in (Int16(-1), Int8(-1), -1, missing, false)
            n0 = length(inj.events)
            ev_alive = PI._stage_event!(inj, 1, :death, alive_val, Int16(6))
            @test ev_alive isa PI.Event{Int8}
            @test ev_alive.new_value == PI.INJECTION_ALIVE_DEATH_TICK
            @test length(inj.events) == n0 + 1
        end
        # ... while real death days (>= 0) record the dead flag
        @test PI._stage_event!(inj, 1, :death, Int16(0), Int16(6)).new_value == PI.INJECTION_DEATH_FLAG

        # the public stage_event! guards the death fields and leaves no state behind
        n = length(inj.events)
        ex = try
            PI.stage_event!(inj, 1, :death, 5, Int16(3))
            nothing
        catch e
            e
        end
        @test ex isa ArgumentError
        @test occursin("cannot be staged via stage_event!", ex.msg)
        @test occursin("stage_death!", ex.msg)
        @test occursin("1", ex.msg) && occursin("3", ex.msg)    # ind_id / timestamp echoed in the hint
        ex = try
            PI.stage_event!(inj, 1, :death_reason, Int8(-2), Int16(3))
            nothing
        catch e
            e
        end
        @test ex isa ArgumentError
        @test occursin("death_reason cannot be staged via stage_event!", ex.msg)
        @test length(inj.events) == n                            # the guards throw before staging

        # :death_reason: positive codes rejected, non-infection codes staged, unknown codes unencodable
        ex = try
            PI._stage_event!(inj, 1, :death_reason, Int8(5), Int16(6))
            nothing
        catch e
            e
        end
        @test ex isa ArgumentError
        @test occursin("death_reason", ex.msg)
        ev = PI._stage_event!(inj, 1, :death_reason, Int8(GEMS.DEATH_REASON_NATURAL), Int16(6))
        @test PI.get_original_value(inj, ev) == GEMS.DEATH_REASON_NATURAL
        ex = try
            PI._stage_event!(inj, 1, :death_reason, Int8(-7), Int16(6))
            nothing
        catch e
            e
        end
        @test ex isa ErrorException
        @test occursin("could not be encoded", ex.msg)
    end

    @testset "field, value and range errors" begin
        # unknown field
        ex = try
            PI._stage_event!(inj, 1, :nonexistent, 1, Int16(5))
            nothing
        catch e
            e
        end
        @test ex isa ErrorException
        @test occursin("Field nonexistent not found in injector schema", ex.msg)

        # a value that cannot be converted to the column's type at all
        ex = try
            PI._stage_event!(inj, 1, :department, 5, Int16(5))
            nothing
        catch e
            e
        end
        @test ex isa ErrorException
        @test occursin("could not be converted to a valid type", ex.msg)

        # an identity-field value out of range for the column's element type (Int8 age)
        ex = try
            PI._stage_event!(inj, 1, :age, 300, Int16(5))
            nothing
        catch e
            e
        end
        @test ex isa ErrorException
        @test occursin("out of range for the identity-mapped age column", ex.msg)

        # ind_id outside the schema type: convert() throws before the defensive conversion
        # warning is ever reachable (the public wrapper shares this path via _stage_event!)
        @test_throws InexactError PI._stage_event!(inj, 300, :age, Int8(30), Int16(5))   # ind_id_type Int8
        # timestamps that are not exact Int16 days: descriptive staging errors
        for bad_ts in (40000, -40000, 1.5, missing, "day5")
            ex = try
                PI._stage_event!(inj, 1, :age, Int8(30), bad_ts)
                nothing
            catch e
                e
            end
            @test ex isa ArgumentError
            @test occursin("Int16", ex.msg)
        end
        @test PI._stage_event!(inj, 1, :age, Int8(30), Int16(7)).timestamp == Int16(7)   # exact value: fine
    end
end

@testset "get_change_history" begin
    base = generate_test_population()
    schema = PI.create_column_schema(base)
    inj = PI.Injector(schema)

    @testset "no events: single base row at day 0" begin
        h = PI.get_change_history(inj, 5, base)
        @test h isa DataFrame
        @test size(h) == (1, 9)                     # 8 base columns + :timestamp
        @test h[1, :timestamp] == 0
        @test h[1, :age] == base[5, :age]
        @test h[1, :name] == base[5, :name]
    end

    @testset "one row per changepoint, values accumulate" begin
        PI.stage_event!(inj, 1, :age, Int8(42), Int16(10))
        PI.stage_event!(inj, 1, :department, "HR", Int16(20))
        PI.stage_event!(inj, 7, :age, Int8(43), Int16(15))   # other individual: excluded

        h = PI.get_change_history(inj, 1, base)
        @test size(h) == (3, 9)                     # base row + 2 changepoints
        @test h[:, :timestamp] == [0, 10, 20]
        @test h[1, :age] == base[1, :age] && h[1, :department] == base[1, :department]
        @test h[2, :age] == Int8(42) && h[2, :department] == base[1, :department]         # first change only
        @test h[3, :age] == Int8(42) && h[3, :department] == "HR"                         # both changes

        h7 = PI.get_change_history(inj, 7, base)
        @test size(h7) == (2, 9)
        @test h7[2, :age] == Int8(43)
    end

    @testset "death changepoint: flag row followed by the reason row" begin
        base_d = generate_test_population()
        base_d[!, :death] = Int8.(fill(-1, 100))
        base_d[!, :death_reason] = Int8.(fill(GEMS.DEFAULT_DEATH_REASON, 100))
        schema_d = PI.create_column_schema(base_d)
        PI.update_schema!(schema_d, :death_reason, [Int8(GEMS.DEATH_REASON_NATURAL)])
        inj_d = PI.Injector(schema_d)
        PI.stage_event!(inj_d, 1, :age, Int8(44), Int16(5))
        PI.stage_death!(inj_d, 1, GEMS.DEATH_REASON_NATURAL, Int16(10))

        h = PI.get_change_history(inj_d, 1, base_d)
        @test size(h) == (4, 11)                    # base + age + death + death_reason
        @test h[:, :timestamp] == [0, 5, 10, 10]
        @test h[1, :death] == Int8(-1)              # base row: alive
        @test h[3, :death] == 1                     # death row: the flag
        @test h[3, :death_reason] == Int8(GEMS.DEFAULT_DEATH_REASON)   # reason not yet staged
        @test h[4, :death] == 1                     # the flag carries into the reason row
        @test h[4, :death_reason] == Int8(GEMS.DEATH_REASON_NATURAL)
    end

    @testset "hash verification" begin
        bad = copy(base)
        bad[5, :age] = Int8(12)
        ex = try
            PI.get_change_history(inj, 1, bad)
            nothing
        catch e
            e
        end
        @test ex isa ErrorException
        @test occursin("Hash mismatch", ex.msg)
    end
end

@testset "stage_new_individuals! ids, bookkeeping and error paths" begin
    base = generate_test_population()

    @testset "assigned ids continue the counter; schema meta is updated" begin
        inj = PI.Injector(PI.create_column_schema(base))
        @test inj.schema.meta[:current_individuals] == 100

        ids1 = PI.stage_new_individuals!(inj,
            DataFrame(name = ["Person_1", "Person_2"], age = [Int8(25), Int8(26)],
                      sex = [Int8(1), Int8(2)]), Int16(10))
        @test ids1 == [101, 102]
        @test inj.schema.meta[:current_individuals] == 102

        ids2 = PI.stage_new_individuals!(inj,
            DataFrame(name = ["Person_3"], age = [Int8(27)], sex = [Int8(1)]), Int16(20))
        @test ids2 == [103]
        @test inj.schema.meta[:current_individuals] == 103

        @test length(inj.events) == 9                           # 3 individuals * 3 fields
        @test all(ev.ind_id ∈ (101, 102, 103) for ev in inj.events)
    end

    @testset "an id column in the input is ignored" begin
        inj = PI.Injector(PI.create_column_schema(base))
        ids = PI.stage_new_individuals!(inj,
            DataFrame(id = Int32[999], name = ["Person_1"], age = [Int8(25)], sex = [Int8(1)]), Int16(5))
        @test ids == [101]
        @test length(inj.events) == 3                           # only name, age and sex staged
        @test all(ev.field != inj.schema.field_to_index[:id] for ev in inj.events)
    end

    @testset "error paths" begin
        inj = PI.Injector(PI.create_column_schema(base))

        # assigned ids overflow the schema's id type (base of 100 → Int8): convert() throws
        # before the defensive conversion warning is ever reachable
        @test_throws InexactError PI.stage_new_individuals!(inj,
            DataFrame(name = repeat(["Person_1"], inner = 200),
                      age = repeat(Int8[25], inner = 200),
                      sex = repeat(Int8[1], inner = 200)), Int16(5))

        # timestamp outside Int16: descriptive staging error, nothing recorded
        ex_ts = try
            PI.stage_new_individuals!(inj,
                DataFrame(name = ["Person_1"], age = [Int8(25)], sex = [Int8(1)]), 40000)
            nothing
        catch e
            e
        end
        @test ex_ts isa ArgumentError
        @test occursin("Int16", ex_ts.msg)

        # a value that cannot be encoded for a closed value set
        ex = try
            PI.stage_new_individuals!(inj,
                DataFrame(name = ["Person_1"], age = [Int8(25)], sex = [Int8(1)],
                          department = ["UnknownDept"]), Int16(5))
            nothing
        catch e
            e
        end
        @test ex isa ErrorException
        @test occursin("could not be encoded", ex.msg)
    end
end

@testset "stable_hash branches" begin
    @testset "isbits fast path" begin
        for v in (Int8[1, 2, 3], Int16[5, 6], Int32[-1, 0, 7], Int64[9],
                  UInt64[0, 1], Float32[0.5, 1.5], Float64[NaN], Bool[true, false],
                  Int8[7], Int16[5])                       # incl. 1- and 2-byte tail remainders
            h = PI.stable_hash(v)
            @test h isa UInt64
            @test h == PI.stable_hash(copy(v))             # deterministic across instances
        end
        @test PI.stable_hash(Int8[1, 2, 3]) != PI.stable_hash(Int8[3, 2, 1])   # order matters
        @test PI.stable_hash(Int8[1, 2, 3]) != PI.stable_hash(Int8[1, 2])      # length matters
    end

    @testset "column branch (vector of vectors)" begin
        cols1 = [Int8[1, 2, 3], Int16[4, 5]]
        cols2 = [Int16[4, 5], Int8[1, 2, 3]]              # same columns, swapped
        h = PI.stable_hash(cols1)
        @test h isa UInt64
        @test h == PI.stable_hash(copy(cols1))
        @test PI.stable_hash(cols1) != PI.stable_hash(cols2)                 # order matters
        @test PI.stable_hash(cols1) != PI.stable_hash([Int8[1, 2, 3], Int16[4]])  # content matters

        # an empty outer vector is deterministic as well (no columns to combine)
        empty_h = PI.stable_hash(Vector{AbstractVector{Int}}[])
        @test empty_h isa UInt64
        @test empty_h == PI.stable_hash(Vector{AbstractVector{Int}}[])
    end

    @testset "fallback branch (element-wise)" begin
        mixed1 = Vector{Any}([1, "a", [1.5]])
        mixed2 = Vector{Any}(["a", 1, [1.5]])
        @test PI.stable_hash(mixed1) isa UInt64
        @test PI.stable_hash(mixed1) == PI.stable_hash(Vector{Any}([1, "a", [1.5]]))
        @test PI.stable_hash(mixed1) != PI.stable_hash(mixed2)              # order matters

        strings = String["ab", "cd"]
        @test PI.stable_hash(strings) == PI.stable_hash(String["ab", "cd"])
        @test PI.stable_hash(strings) != PI.stable_hash(String["cd", "ab"])
    end

    @testset "scalars and strings" begin
        @test PI.stable_hash(5) isa UInt64
        @test PI.stable_hash(5) == PI.stable_hash(5)
        @test PI.stable_hash(5) != PI.stable_hash(6)
        @test PI.stable_hash(3.14) == PI.stable_hash(3.14)
        @test PI.stable_hash(3.14) != PI.stable_hash(3.15)
        # strings are hashed as code units: identical to hashing the byte vector
        @test PI.stable_hash("ab") == PI.stable_hash(codeunits("ab"))
        @test PI.stable_hash("a") != PI.stable_hash("b")
        @test PI.stable_hash("") isa UInt64
    end
end

@testset "determine_minimal_float_type" begin
    @test PI.determine_minimal_float_type([Float64(1.5)], 1e-6) == Float16   # exactly representable
    @test PI.determine_minimal_float_type([Float64(0.1)], 1e-6) == Float32   # not exact in Float16
    # NaN can never pass isapprox, so even Float64 is "insufficient" → error
    ex = try
        PI.determine_minimal_float_type([Float64(NaN)], 1e-6)
        nothing
    catch e
        e
    end
    @test ex isa ErrorException
    @test occursin("Required precision higher than Float64", ex.msg)
end

@testset "_encode_identity! rethrows non-Inexact conversion errors" begin
    @test_throws MethodError PI._encode_identity!(Int8, "abc", :age)
end

@testset "update_schema! on an unknown field" begin
    schema = PI.create_column_schema(generate_test_population())
    ex = try
        PI.update_schema!(schema, :nonexistent, [1, 2])
        nothing
    catch e
        e
    end
    @test ex isa ErrorException
    @test occursin("Field nonexistent not found in schema", ex.msg)
end

@testset "_stage_event!: value in neither the value set nor a convertible type" begin
    base = generate_test_population()
    inj = PI.Injector(PI.create_column_schema(base))
    ex = try
        PI.stage_event!(inj, 1, :department, :HR, Int16(7))   # Symbol for a String column
        nothing
    catch e
        e
    end
    @test ex isa ErrorException
    @test occursin("could not be converted to a valid type", ex.msg)
    @test isempty(inj.events)                                  # the failed staging leaves no state
end

@testset "verify_base_population_hashes: column without a stored hash" begin
    base = generate_test_population()
    inj = PI.Injector(PI.create_column_schema(base))
    PI.stage_event!(inj, 1, :age, Int8(42), Int16(5))
    extra = copy(base)
    extra[!, :ghost] = Int8.(1:100)
    ex = try
        PI.snapshot(inj, extra, Int16(5))
        nothing
    catch e
        e
    end
    @test ex isa ErrorException
    @test occursin("No hash stored for column ghost", ex.msg)
end


###
### PART 2 — GEMS INTEGRATION
###

@testset "Population Injection" begin
    # canonical base population (dtypes matter for the schema hash!)
    function make_base()
        DataFrame(
            id          = Int32.(1:100),
            sex         = Int8.(rand(1:2, 100)),
            age         = Int8.(rand(18:80, 100)),
            education   = Int8.(rand(0:4, 100)),
            occupation  = Int16.(rand(1:5, 100)),
            household   = Int32.(repeat(1:50, inner = 2)),
            office      = Int32.(repeat(1:20, inner = 5)),
            schoolclass = Int32.(fill(-1, 100))
        )
    end

    @testset "attribute update + births during run (no snapshot)" begin
        base = make_base()
        pop = Population(base)
        schema = PI.create_column_schema(dataframe(pop))
        PI.update_schema!(schema, :occupation, [Int16(20)])   # new values must be in the schema
        PI.update_schema!(schema, :age, [Int8(0), Int8(1)])   # newborn ages must be in the schema
        inj = PI.Injector(schema)
        PI.stage_event!(inj, 1, :occupation, Int16(20), Int16(5))
        PI.stage_new_individuals!(inj, DataFrame(id = Int32[101], sex = Int8[1], age = Int8[0],
                                                 occupation = Int16[20], household = Int32[1]), Int16(10))
        # singular convenience (Dict input, mirrors Individual(properties)); injector assigns the id
        @test PI.stage_new_individual!(inj, Dict(:sex => Int8(2), :age => Int8(1),
                                                 :occupation => Int16(20), :household => Int32(2)), Int16(11)) == 102

        sim = Simulation(population = pop, population_injection = inj,
                         stop_criterion = TimesUp(limit = 14))
        @test length(individuals(sim)) == 100
        for _ in 1:5; step!(sim); end
        @test occupation(get_individual_by_id(population(sim), Int32(1))) != 20   # not yet due
        step!(sim)                                                       # tick 5: event applied
        @test occupation(get_individual_by_id(population(sim), Int32(1))) == 20
        @test length(individuals(sim)) == 100
        for _ in 1:8; step!(sim); end                                    # births due at ticks 10 and 11
        @test length(individuals(sim)) == 102
        @test get_individual_by_id(population(sim), Int32(101)) !== nothing
        @test get_individual_by_id(population(sim), Int32(102)) !== nothing
        @test age(get_individual_by_id(population(sim), Int32(102))) == 1
    end

    @testset "snapshot: baked-in state + rebasing (sim tick 0 == day t0)" begin
        base = make_base()
        pop = Population(base)
        inj = GEMS.new_injector(pop)                                # convenience ctor
        PI.update_schema!(inj.schema, :occupation, [Int16(20)])
        PI.update_schema!(inj.schema, :age, [Int8(3)])
        PI.stage_event!(inj, 1, :occupation, Int16(20), Int16(490))      # before snapshot -> baked in
        PI.stage_event!(inj, 2, :occupation, Int16(20), Int16(510))      # after  -> fires at sim tick 10
        PI.stage_new_individuals!(inj, DataFrame(id = Int32[101], sex = Int8[1], age = Int8[3],
                                                 occupation = Int16[20], household = Int32[1]), Int16(500))

        sim = Simulation(population = pop, population_injection = inj,
                         population_snapshot = 500, stop_criterion = TimesUp(limit = 14))
        @test tick(sim) == 0                                           # clock starts at 0
        @test occupation(get_individual_by_id(population(sim), Int32(1))) == 20          # baked in
        @test get_individual_by_id(population(sim), Int32(101)) !== nothing             # baked-in birth
        @test occupation(get_individual_by_id(population(sim), Int32(2))) != 20         # not yet due
        for _ in 1:10; step!(sim); end
        @test occupation(get_individual_by_id(population(sim), Int32(2))) != 20
        step!(sim)                                                     # tick 10: event applied
        @test occupation(get_individual_by_id(population(sim), Int32(2))) == 20
        @test length(individuals(sim)) == 101                                    # birth not duplicated
    end

    @testset "snapshot cross-check against PI.snapshot" begin
        base = make_base()
        df_base = copy(base)
        pop = Population(base)
        inj = GEMS.new_injector(pop)
        PI.update_schema!(inj.schema, :occupation, [Int16(20)])
        PI.update_schema!(inj.schema, :age, [Int8(3)])
        PI.stage_event!(inj, 1, :occupation, Int16(20), Int16(490))
        PI.stage_event!(inj, 2, :occupation, Int16(20), Int16(510))
        PI.stage_new_individuals!(inj, DataFrame(id = Int32[101], sex = Int8[1], age = Int8[3],
                                                 occupation = Int16[20], household = Int32[1]), Int16(500))
        df_ref = PI.snapshot(inj, df_base, Int16(500))

        sim = Simulation(population = pop, population_injection = inj,
                         population_snapshot = 500, stop_criterion = TimesUp(limit = 3))

        @test df_ref[1, :occupation] == occupation(get_individual_by_id(population(sim), Int32(1)))
        @test df_ref[101, :age] == age(get_individual_by_id(population(sim), Int32(101)))
        @test df_ref[101, :occupation] == occupation(get_individual_by_id(population(sim), Int32(101)))
    end

    @testset "snapshot overloads: full, single, and vector" begin
        base = make_base()
        schema = PI.create_column_schema(base)
        PI.update_schema!(schema, :occupation, [Int16(20)])
        inj = PI.Injector(schema)
        PI.stage_event!(inj, 1, :occupation, Int16(20), Int16(490))
        PI.stage_event!(inj, 1, :age, Int8(99), Int16(495))
        PI.stage_event!(inj, 2, :occupation, Int16(20), Int16(510))   # day 510: must not apply at day 500
        PI.stage_new_individuals!(inj, DataFrame(id = Int32[101], sex = Int8[1], age = Int8[0],
                                                 occupation = Int16[20], household = Int32[1]), Int16(500))

        # full population: events before day 500 applied, new individual appended
        s = PI.snapshot(inj, base, Int16(500))
        @test size(s) == (101, 8)
        @test s[1, :occupation] == Int16(20)
        @test s[1, :age] == Int8(99)
        @test s[2, :occupation] != Int16(20)                            # event at day 510 not yet due
        @test s[3, :occupation] == base[3, :occupation]                 # untouched row kept
        @test s[101, :age] == Int8(0)                                   # new individual appended

        # single individual: one-row frame with the same updates
        s1 = PI.snapshot(inj, 1, base, Int16(500))
        @test ncol(s1) == 8
        @test s1[1, :occupation] == Int16(20)
        @test s1[1, :age] == Int8(99)
        @test s1[1, :sex] == base[1, :sex]

        # vector: row order follows ind_id, values match the full-population snapshot
        sv = PI.snapshot(inj, [1, 2], base, Int16(500))
        @test size(sv) == (2, 8)
        @test sv == s[1:2, :]

        # vector overload with no events for the selected individuals: early-return copy
        @test PI.snapshot(inj, [3, 4], base, Int16(500)) == base[3:4, :]

        # single individual with no events: base row
        s3 = PI.snapshot(inj, 3, base, Int16(500))
        @test s3[1, :occupation] == base[3, :occupation]

        # hash verification fires in all overloads when the base table was modified
        bad = copy(base)
        bad[5, :age] = Int8(12)
        @test_throws ErrorException PI.snapshot(inj, bad, Int16(500))
        @test_throws ErrorException PI.snapshot(inj, 1, bad, Int16(500))
        @test_throws ErrorException PI.snapshot(inj, [1, 2], bad, Int16(500))
        @test_throws ErrorException PI.get_change_history(inj, 1, bad)
    end

    @testset "death injection" begin
        # NOTE: the death column must exist in the schema's base DataFrame.
        base = make_base()
        base[!, :death] = Int8.(fill(-1, 100))          # alive = DEFAULT_TICK (-1); schema built from THIS df
        pop = Population(base)
        schema = PI.create_column_schema(base)
        inj = PI.Injector(schema)
        PI.stage_death!(inj, 3, nothing, Int16(7))      # the TIMESTAMP is the death day; no reason

        sim = Simulation(population = pop, population_injection = inj,
                         stop_criterion = TimesUp(limit = 9))
        ind3 = get_individual_by_id(population(sim), Int32(3))
        @test !dead(ind3)
        for _ in 1:7; step!(sim); end
        @test !dead(ind3)
        step!(sim)                                        # tick 7: death applied
        @test dead(ind3)
        @test ind3.death == Int16(7)
        # recorded exactly once in the DeathLogger, attributed to no pathogen
        dl = dataframe(deathlogger(sim))
        @test sum(dl.id .== Int32(3)) == 1
        @test dl.tick[dl.id .== Int32(3)] == [Int16(7)]
        @test dl.pathogen_id[dl.id .== Int32(3)] == [GEMS.DEFAULT_PATHOGEN_ID]
    end

    @testset "death injection with death reason" begin
        # the death-reason column must exist in the schema's base DataFrame (like :death)
        base = make_base()
        base[!, :death] = Int8.(fill(-1, 100))
        base[!, :death_reason] = Int8.(fill(GEMS.DEFAULT_DEATH_REASON, 100))
        pop = Population(base)
        schema = PI.create_column_schema(base)
        PI.update_schema!(schema, :death_reason, [Int8(GEMS.DEATH_REASON_NATURAL)])  # new codes must be in the schema
        inj = PI.Injector(schema)
        # positive codes are reserved for simulation-caused (pathogen) deaths -> rejected at staging
        @test_throws ArgumentError PI.stage_death!(inj, 3, Int8(1), Int16(7))
        # ind 3: natural death; ind 7: death with the default (unspecified) reason
        PI.stage_death!(inj, 3, GEMS.DEATH_REASON_NATURAL, Int16(7))
        PI.stage_death!(inj, 7, nothing, Int16(7))

        sim = Simulation(population = pop, population_injection = inj,
                         stop_criterion = TimesUp(limit = 9))
        for _ in 1:7; step!(sim); end
        @test !dead(get_individual_by_id(population(sim), Int32(3)))
        step!(sim)                                        # tick 7: deaths applied
        ind3 = get_individual_by_id(population(sim), Int32(3))
        ind7 = get_individual_by_id(population(sim), Int32(7))
        @test dead(ind3) && dead(ind7)
        # the staged reason is part of the death state; without one it stays at the default
        @test ind3.death_reason == Int8(GEMS.DEATH_REASON_NATURAL)
        @test ind7.death_reason == Int8(GEMS.DEFAULT_DEATH_REASON)
        # the injector never attributes a death to a pathogen
        @test killing_pathogen_id(ind3) === nothing
        @test killing_pathogen_id(ind7) === nothing
        # the DeathLogger records the reason (its `pathogen_id` column)
        dl = dataframe(deathlogger(sim))
        @test dl.pathogen_id[dl.id .== Int32(3)] == [Int8(GEMS.DEATH_REASON_NATURAL)]
        @test dl.pathogen_id[dl.id .== Int32(7)] == [Int8(GEMS.DEFAULT_DEATH_REASON)]
    end

    @testset "stage_death! convenience" begin
        base = make_base()
        base[!, :death] = Int8.(fill(-1, 100))
        base[!, :death_reason] = Int8.(fill(GEMS.DEFAULT_DEATH_REASON, 100))
        pop = Population(base)
        schema = PI.create_column_schema(base)
        PI.update_schema!(schema, :death_reason, [Int8(GEMS.DEATH_REASON_NATURAL)])
        inj = PI.Injector(schema)

        # without a reason: only the :death event is staged (no :death schema entry needed)
        ev = PI.stage_death!(inj, 3, nothing, Int16(7))
        @test length(inj.events) == 1
        @test ev.timestamp == Int16(7)
        # with a reason: both events, same timestamp
        PI.stage_death!(inj, 7, GEMS.DEATH_REASON_NATURAL, Int16(7))
        @test length(inj.events) == 3
        # positive codes are still rejected (and leave no partial state)
        @test_throws ArgumentError PI.stage_death!(inj, 9, Int8(1), Int16(7))
        # the manual stage_event! paths for deaths are closed, hinting at stage_death!
        @test_throws ArgumentError PI.stage_event!(inj, 3, :death, Int8(1), Int16(7))
        @test_throws ArgumentError PI.stage_event!(inj, 3, :death_reason, Int8(GEMS.DEATH_REASON_NATURAL), Int16(7))

        sim = Simulation(population = pop, population_injection = inj,
                         stop_criterion = TimesUp(limit = 9))
        for _ in 1:7; step!(sim); end
        step!(sim)                                        # tick 7: deaths applied
        ind3 = get_individual_by_id(population(sim), Int32(3))
        ind7 = get_individual_by_id(population(sim), Int32(7))
        ind9 = get_individual_by_id(population(sim), Int32(9))
        @test dead(ind3) && dead(ind7) && !dead(ind9)
        @test ind3.death_reason == Int8(GEMS.DEFAULT_DEATH_REASON)
        @test ind7.death_reason == Int8(GEMS.DEATH_REASON_NATURAL)
        dl = dataframe(deathlogger(sim))
        @test dl.pathogen_id[dl.id .== Int32(7)] == [Int8(GEMS.DEATH_REASON_NATURAL)]
    end

    @testset "stage_death! requires the declared death columns" begin
        # no :death column in the base population -> rejected, hinting at the column, its default value, and the schema step
        base = make_base()
        schema = PI.create_column_schema(base)
        inj = PI.Injector(schema)
        ex = try
            PI.stage_death!(inj, 3, nothing, Int16(7))
            nothing
        catch e
            e
        end
        @test ex isa ArgumentError
        @test occursin("has no :death column", ex.msg)
        @test occursin("GEMS.DEFAULT_TICK", ex.msg) && occursin("create_column_schema", ex.msg)
        ex = try
            PI.stage_death!(inj, 3, GEMS.DEATH_REASON_NATURAL, Int16(7))
            nothing
        catch e
            e
        end
        @test ex isa ArgumentError
        @test isempty(inj.events)                                    # nothing staged on failure
        # :death declared, but no :death_reason: a death without reason is fine, with a reason rejected
        base = make_base()
        base[!, :death] = Int8.(fill(-1, 100))
        schema = PI.create_column_schema(base)
        inj = PI.Injector(schema)
        PI.stage_death!(inj, 3, nothing, Int16(7))
        @test length(inj.events) == 1
        ex = try
            PI.stage_death!(inj, 7, GEMS.DEATH_REASON_NATURAL, Int16(7))
            nothing
        catch e
            e
        end
        @test ex isa ArgumentError
        @test occursin("has no :death_reason column", ex.msg)
        @test occursin("GEMS.DEFAULT_DEATH_REASON", ex.msg) && occursin("create_column_schema", ex.msg)
        @test length(inj.events) == 1                                # the failed staging left no partial state
    end

    @testset "snapshot of staged deaths" begin
        # the base declares the death columns (the usual case); staged deaths are written
        # into the snapshot as the constant flag, alive individuals keep the base value
        base = make_base()
        base[!, :death] = Int8.(fill(-1, 100))
        base[!, :death_reason] = Int8.(fill(GEMS.DEFAULT_DEATH_REASON, 100))
        schema = PI.create_column_schema(base)
        PI.update_schema!(schema, :death_reason, [Int8(GEMS.DEATH_REASON_NATURAL)])
        inj = PI.Injector(schema)
        PI.stage_death!(inj, 3, GEMS.DEATH_REASON_NATURAL, Int16(5))
        PI.stage_death!(inj, 9, nothing, Int16(8))

        s = PI.snapshot(inj, base, Int16(8))
        @test s[3, :death] == 1
        @test s[3, :death_reason] == Int8(GEMS.DEATH_REASON_NATURAL)
        @test s[9, :death] == 1
        @test s[9, :death_reason] == Int8(GEMS.DEFAULT_DEATH_REASON)
        @test s[5, :death] == Int8(-1)                               # not dead: base value kept

        s1 = PI.snapshot(inj, 3, base, Int16(8))
        @test s1[1, :death] == 1

        sv = PI.snapshot(inj, [3, 9], base, Int16(8))                  # vector overload, both dead
        @test size(sv) == (2, 10)
        @test sv[1, :death] == 1
        @test sv[2, :death] == 1
        @test sv[1, :death_reason] == Int8(GEMS.DEATH_REASON_NATURAL)
        @test sv[2, :death_reason] == Int8(GEMS.DEFAULT_DEATH_REASON)

        h = PI.get_change_history(inj, 3, base)
        @test h[1, :death] == Int8(-1)                               # base row (day 0): alive
        @test h[end, :death] == 1                                    # death event row: the flag
        @test h[end, :death_reason] == Int8(GEMS.DEATH_REASON_NATURAL)
    end

    @testset "snapshot creates the :death column when the passed table lacks it" begin
        base = make_base()
        base[!, :death] = Int8.(fill(-1, 100))
        death_reasons = fill(Int8(GEMS.DEFAULT_DEATH_REASON), 100)
        death_reasons[97:100] .= GEMS.DEATH_REASON_NATURAL   # widen the closed value set
        base[!, :death_reason] = death_reasons
        schema = PI.create_column_schema(base)
        inj = PI.Injector(schema)
        PI.stage_death!(inj, 3, nothing, Int16(5))
        PI.stage_death!(inj, 9, nothing, Int16(8))
        PI.stage_death!(inj, 7, GEMS.DEATH_REASON_NATURAL, Int16(8))

        # the hash check only validates the columns that ARE present, so a table without the
        # death columns passes; the death branch must then create the column on the fly
        # NOTE: this build's setdiff mishandles symbol/string mixed inputs, filter manually
        base_nondeath = base[:, [x for x in names(base) if x != "death" && x != "death_reason"]]
        @test !hasproperty(base_nondeath, :death)

        s = PI.snapshot(inj, base_nondeath, Int16(8))
        @test hasproperty(s, :death)
        @test hasproperty(s, :death_reason)                          # created next to :death
        @test s[3, :death] == 1
        @test s[9, :death] == 1
        @test s[5, :death] == Int8(-1)                               # alive: the created default
        @test s[7, :death] == 1
        @test s[7, :death_reason] == Int8(GEMS.DEATH_REASON_NATURAL) # staged reason survives
        @test s[5, :death_reason] == Int8(GEMS.DEFAULT_DEATH_REASON) # alive: the created default

        s1 = PI.snapshot(inj, 3, base_nondeath, Int16(8))
        @test s1[1, :death] == 1

        sv = PI.snapshot(inj, [3, 9], base_nondeath, Int16(8))
        @test sv[1, :death] == 1 && sv[2, :death] == 1

        h = PI.get_change_history(inj, 3, base_nondeath)
        @test h[1, :death] == Int8(-1)
        @test h[end, :death] == 1
    end

    @testset "staged :id change on an existing individual is skipped" begin
        base = make_base()
        pop = Population(base)
        inj = GEMS.new_injector(pop)
        PI.stage_event!(inj, 1, :id, Int32(500), Int16(5))          # identity is immutable at application

        sim = Simulation(population = pop, population_injection = inj, stop_criterion = TimesUp(limit = 9))
        for _ in 1:6; step!(sim); end
        ind1 = get_individual_by_id(population(sim), Int32(1))
        @test ind1 !== nothing && id(ind1) == Int32(1)              # id untouched
        @test get_individual_by_id(population(sim), Int32(500)) === nothing   # no renumbering side effects
        @test length(individuals(sim)) == 100                       # no birth/death side effects
    end

    @testset "born-dead newborn: realized at birth and in the death logger" begin
        base = make_base()
        base[!, :death] = Int8.(fill(-1, 100))
        base[!, :death_reason] = Int8.(fill(GEMS.DEFAULT_DEATH_REASON, 100))
        schema = PI.create_column_schema(base)
        PI.update_schema!(schema, :death_reason, [Int8(GEMS.DEATH_REASON_NATURAL)])
        inj = PI.Injector(schema)
        PI.stage_new_individuals!(inj, DataFrame(
            id = Int32[101], sex = Int8[1], age = Int8[0],
            occupation = Int16[2], household = Int32[1],
            death = Int8[1], death_reason = Int8[GEMS.DEATH_REASON_NATURAL]), Int16(5))

        sim = Simulation(population = Population(base), population_injection = inj,
                         stop_criterion = TimesUp(limit = 9))
        for _ in 1:6; step!(sim); end                               # the day-5 birth fires at tick 5
        ind101 = get_individual_by_id(population(sim), Int32(101))
        @test ind101 !== nothing && dead(ind101)
        @test ind101.death == Int16(5)
        @test ind101.death_reason == Int8(GEMS.DEATH_REASON_NATURAL)
        dl = dataframe(deathlogger(sim))
        @test any(dl.id .== Int32(101))                             # born-dead: still a run-time death
    end

    @testset "new individual with alive death values: alive by default" begin
        # a row carrying the death columns' alive defaults verbatim (DEFAULT_TICK / -1) is
        # recorded as an alive marker and must NOT realize a death: new individuals are
        # alive with the alive death reason
        base = make_base()
        base[!, :death] = Int8.(fill(-1, 100))
        base[!, :death_reason] = Int8.(fill(GEMS.DEFAULT_DEATH_REASON, 100))
        schema = PI.create_column_schema(base)
        inj = PI.Injector(schema)
        PI.stage_new_individuals!(inj, DataFrame(
            id = Int32[101], sex = Int8[1], age = Int8[0],
            occupation = Int16[2], household = Int32[1],
            death = Int8[-1], death_reason = Int8[GEMS.DEFAULT_DEATH_REASON]), Int16(5))

        # the alive death value IS recorded — as an alive-marker event that realizes no death
        death_events = [e for e in inj.events if inj.schema.index_to_field[Int(e.field) + 1] === :death]
        @test length(death_events) == 1
        @test only(death_events).new_value == PI.INJECTION_ALIVE_DEATH_TICK

        sim = Simulation(population = Population(base), population_injection = inj,
                         stop_criterion = TimesUp(limit = 9))
        for _ in 1:6; step!(sim); end                               # the day-5 birth fires at tick 5
        ind101 = get_individual_by_id(population(sim), Int32(101))
        @test ind101 !== nothing && !dead(ind101)
        @test ind101.death == GEMS.DEFAULT_TICK
        @test ind101.death_reason == GEMS.DEFAULT_DEATH_REASON
        dl = dataframe(deathlogger(sim))
        @test !any(dl.id .== Int32(101))                            # alive: not in the death logger

        # the snapshot pads the newborn row with the death columns' alive defaults, not missing
        sn = PI.snapshot(inj, base, Int16(5))
        @test sn[101, :death] == GEMS.DEFAULT_TICK
        @test sn[101, :death_reason] == GEMS.DEFAULT_DEATH_REASON
    end

    @testset "stage_new_individuals! requires :sex and :age at staging" begin
        base = make_base()
        schema = PI.create_column_schema(base)
        inj = PI.Injector(schema)
        for (df, req) in ((DataFrame(id = Int32[101], sex = Int8[1], occupation = Int16[1]), ":age"),
                          (DataFrame(id = Int32[101], age = Int8[0], occupation = Int16[1]), ":sex"),
                          (DataFrame(id = Int32[101], sex = Int8[1], age = [missing]), ":age"))
            ex = try
                PI.stage_new_individuals!(inj, df, Int16(5))
                nothing
            catch e
                e
            end
            @test ex isa ArgumentError
            @test occursin(req, ex.msg)
        end
        @test isempty(inj.events)                                 # validated before staging anything
        @test inj.schema.meta[:current_individuals] == 100        # id counter untouched
    end

    @testset "alive marker on an existing individual: no-op, later death still fires" begin
        base = make_base()
        base[!, :death] = Int8.(fill(-1, 100))
        schema = PI.create_column_schema(base)
        inj = PI.Injector(schema)
        PI._stage_event!(inj, 3, :death, Int8(-1), Int16(3))        # recorded alive marker
        PI.stage_death!(inj, 3, nothing, Int16(7))                  # a real death after it

        sim = Simulation(population = Population(base), population_injection = inj,
                         stop_criterion = TimesUp(limit = 9))
        for _ in 1:7; step!(sim); end                               # day-3 marker long applied
        ind3 = get_individual_by_id(population(sim), Int32(3))
        @test ind3 !== nothing && !dead(ind3)                       # the marker marks nobody dead
        step!(sim)                                                  # tick 7: the death applies
        @test dead(ind3)
        @test ind3.death == Int16(7)
        dl = dataframe(deathlogger(sim))
        @test sum(dl.id .== Int32(3)) == 1                          # logged exactly once
    end

    @testset "birth with extension field on a struct extension type" begin
        struct InjectionExt
            income::Float64
        end
        base = make_base()
        base[!, :income] = Float64.(1000.0 .* (1:100))
        # values beyond Float16 precision, so the schema keeps Float32 (the staged 3100.5 must survive)
        pop = Population(base, ind_extension = ind -> InjectionExt(10000.0 .* (ind.id % 3 + 1) + 0.5))
        @test individuals(pop)[1].extensions isa InjectionExt

        inj = GEMS.new_injector(pop)
        PI.stage_new_individuals!(inj, DataFrame(
            sex = Int8[1], age = Int8[0], household = Int32[1],
            income = Float64[3100.5]), Int16(2))

        sim = Simulation(population = pop, population_injection = inj, stop_criterion = TimesUp(limit = 5))
        for _ in 1:6; step!(sim); end                               # the day-2 birth fires at tick 2
        ind101 = get_individual_by_id(population(sim), Int32(101))
        @test ind101 !== nothing
        @test ind101.extensions isa InjectionExt                    # default-constructed at birth
        @test ind101.extensions.income == 3100.5                    # staged value injected
    end

    @testset "death with snapshot bake-in" begin
        # death at day 490, snapshot 500 -> dead from simulation tick 0, NOT in DeathLogger
        base = make_base()
        base[!, :death] = Int8.(fill(-1, 100))
        pop = Population(base)
        schema = PI.create_column_schema(base)
        inj = PI.Injector(schema)
        PI.stage_death!(inj, 3, nothing, Int16(490))

        sim = Simulation(population = pop, population_injection = inj,
                         population_snapshot = 500, stop_criterion = TimesUp(limit = 3))
        ind3 = get_individual_by_id(population(sim), Int32(3))
        @test dead(ind3)
        @test ind3.death == Int16(0)
        run!(sim)
        dl = dataframe(deathlogger(sim))
        @test !any(dl.id .== Int32(3))                   # initial-state death: not a run-time death
    end

    @testset "reset! replays without duplicating births, re-realizes baked-in deaths" begin
        base = make_base()
        base[!, :death] = Int8.(fill(-1, 100))
        pop = Population(base)
        schema = PI.create_column_schema(base)
        PI.update_schema!(schema, :occupation, [Int16(20)])
        PI.update_schema!(schema, :age, [Int8(2)])
        inj = PI.Injector(schema)
        PI.stage_event!(inj, 1, :occupation, Int16(20), Int16(490))   # baked in
        PI.stage_death!(inj, 3, nothing, Int16(495))                  # baked in (dead from tick 0)
        PI.stage_new_individuals!(inj, DataFrame(id = Int32[101], sex = Int8[1], age = Int8[2],
                                                 occupation = Int16[20], household = Int32[1]), Int16(500))  # baked-in birth
        PI.stage_event!(inj, 2, :occupation, Int16(20), Int16(510))   # post-snapshot -> fires at sim tick 10

        sim = Simulation(population = pop, population_injection = inj,
                         population_snapshot = 500, stop_criterion = TimesUp(limit = 25))
        @test length(individuals(sim)) == 101
        @test dead(get_individual_by_id(population(sim), Int32(3)))
        run!(sim)
        n = length(individuals(sim))
        @test n == 101
        @test occupation(get_individual_by_id(population(sim), Int32(2))) == 20   # applied once at tick 10

        reset!(sim)
        @test length(individuals(sim)) == 101          # no duplicate births
        @test dead(get_individual_by_id(population(sim), Int32(3)))   # baked-in death re-realized
        @test occupation(get_individual_by_id(population(sim), Int32(1))) == 20  # baked-in attribute re-set
        @test occupation(get_individual_by_id(population(sim), Int32(2))) == 20  # attribute changes persist across reset! (reset! clears disease state only)

        run!(sim)
        @test length(individuals(sim)) == 101          # still no duplicate births on the re-run
        @test dead(get_individual_by_id(population(sim), Int32(3)))
        @test occupation(get_individual_by_id(population(sim), Int32(2))) == 20  # replayed exactly once on the re-run
    end

    @testset "save/load (saved injector)" begin
        base = make_base()
        schema = PI.create_column_schema(base)
        PI.update_schema!(schema, :age, [Int8(55)])    # the staged age must be in the schema
        inj = PI.Injector(schema)
        PI.stage_event!(inj, 1, :age, Int8(55), Int16(3))
        f = joinpath(mktempdir(), "test_injector.jld2")
        PI.save(inj, f)
        inj2 = PI.Injector(f)
        @test length(inj2.events) == length(inj.events)
        sim = Simulation(population = Population(base), population_injection = f,
                         stop_criterion = TimesUp(limit = 5))
        for _ in 1:3; step!(sim); end
        step!(sim)                                                       # tick 3: event applied
        @test age(get_individual_by_id(population(sim), Int32(1))) == 55
    end

    @testset "errors" begin
        pop = Population(make_base())
        @test_throws ArgumentError Simulation(population = pop, population_snapshot = 10)
        @test_throws ArgumentError Simulation(population = pop, population_snapshot = -1)
        @test_throws ArgumentError Simulation(population = pop, population_snapshot = 70_000)
        # mismatched base:
        inj = PI.Injector(PI.create_column_schema(
            DataFrame(id = Int32.(1:5), sex = Int8.(1:5), age = Int8.(20:24),
                      education = Int8.(1:5), occupation = Int16.(1:5),
                      household = Int32.(1:5), office = Int32.(1:5),
                      schoolclass = Int32.(fill(-1, 5)))))
        @test_throws ArgumentError Simulation(population = pop, population_injection = inj)
        # birth without :sex/:age is rejected at staging, recording nothing
        inj2 = PI.Injector(PI.create_column_schema(dataframe(pop)))
        ex = try
            PI.stage_new_individuals!(inj2, DataFrame(id = Int32[200], occupation = Int16[1]), Int16(1))
            nothing
        catch e
            e
        end
        @test ex isa ArgumentError
        @test occursin(":sex", ex.msg)
        @test isempty(inj2.events)
        # application still guards directly staged events (bake-in surfaces at construction)
        PI._stage_event!(inj2, 101, :occupation, Int16(1), Int16(1))
        @test_throws ArgumentError Simulation(population = pop, population_injection = inj2,
                                              population_snapshot = 1)
    end

    @testset "no injector attached: unchanged behavior (fast path)" begin
        sim = Simulation(pop_size = 10_000)
        step!(sim)
        @test tick(sim) == 1
    end
end


@testset "Extension Columns and Warn-once" begin
    function make_ext_base()
        DataFrame(
            id         = Int32.(1:100),
            sex        = Int8.(1 .+ (1:100) .% 2),
            age        = Int8.(18 .+ (1:100) .% 60),
            occupation = Int16.(1 .+ (1:100) .% 6),
            household  = Int32.(repeat(1:50, inner = 2)),
            income     = Float32.(1000.25 .* (1:100)),
        )
    end

    @testset "extension column (ind_extension) is injected" begin
        base = make_ext_base()
        pop = Population(base, ind_extension = [:income])
        @test getproperty(individuals(pop)[1], :income) == Float32(1000.25)

        inj = GEMS.new_injector(pop)     # dataframe(pop) includes :income (the extension column)
        @test :income in keys(inj.schema.columns)
        PI.update_schema!(inj.schema, :age, Int8[0])   # the newborn's age must be in the schema
        PI.stage_event!(inj, 1, :income, Float32(4200.0), Int16(2))
        PI.stage_new_individuals!(inj, DataFrame(
            sex = Int8[1], age = Int8[0], household = Int32[1],
            income = Float32[3100.5]), Int16(4))

        sim = Simulation(population = pop, population_injection = inj, stop_criterion = TimesUp(limit = 8))
        for _ in 1:3; step!(sim); end                    # day-2 change in effect after 2 + 1 steps
        @test getproperty(get_individual_by_id(population(sim), Int32(1)), :income) == Float32(4200.0)

        for _ in 1:3; step!(sim); end                    # day-4 birth in effect after 4 + 1 steps
        @test length(individuals(sim)) == 101
        ind101 = get_individual_by_id(population(sim), Int32(101))
        @test getproperty(ind101, :income) == Float32(3100.5)
        @test sex(ind101) == 1
        @test household_id(ind101) == 1
    end

    @testset "unstored field: warn once per (injector, field)" begin
        base = make_ext_base()
        pop = Population(DataFrame(    # the population WITHOUT the income extension
            id = base.id, sex = base.sex, age = base.age,
            occupation = base.occupation, household = base.household))
        schema = PI.create_column_schema(base)   # :income is in the schema but not stored in the population
        inj = PI.Injector(schema)
        PI.stage_event!(inj, 1, :income, Float32(4200.0), Int16(2))
        PI.stage_event!(inj, 7, :income, Float32(1500.75), Int16(4))

        col = WarnCollector(String[])
        with_logger(col) do
            sim = Simulation(population = pop, population_injection = inj, stop_criterion = TimesUp(limit = 14))
            for _ in 1:14; step!(sim); end
            # a second simulation on the same injector: no repeated warning
            sim2 = Simulation(population = Population(DataFrame(
                id = base.id, sex = base.sex, age = base.age,
                occupation = base.occupation, household = base.household)),
                population_injection = inj, stop_criterion = TimesUp(limit = 14))
            for _ in 1:14; step!(sim2); end
        end
        @test count(m -> occursin("field :income is not stored on this population", m), col.messages) == 1
    end

    @testset "unstored field on a NEW individual: warns at birth" begin
        base = make_ext_base()
        pop = Population(DataFrame(    # the population WITHOUT the income extension
            id = base.id, sex = base.sex, age = base.age,
            occupation = base.occupation, household = base.household))
        schema = PI.create_column_schema(base)
        inj = PI.Injector(schema)
        PI.stage_new_individuals!(inj, DataFrame(
            sex = Int8[1], age = Int8[0], household = Int32[1],
            income = Float32[3100.5]), Int16(2))

        col = WarnCollector(String[])
        with_logger(col) do
            # the internal apply is called directly: no construction-time warning precedes
            # it (the Simulation ctor would warn once already), so the birth path is what
            # surfaces the unstored field
            GEMS.apply_injection_events!(pop, inj, inj.events, Int16(2), nothing)
        end
        @test count(m -> occursin("field :income is not stored on this population", m)
                   && occursin("individual 101", m), col.messages) == 1
        @test get_individual_by_id(pop, Int32(101)) !== nothing       # the birth itself still happens
    end
end


@testset "Setting Moves" begin
    function make_set_base()
        DataFrame(
            id        = Int32.(1:4),
            sex       = Int8[1, 0, 1, 0],
            age       = Int8[20, 30, 40, 50],
            household = Int32[1, 1, 2, 2],
            office    = Int32[1, 1, 2, 2],
        )
    end

    @testset "move to an existing setting: roster and id field stay in sync" begin
        pop = Population(make_set_base())
        inj = new_injector(pop)
        PI.stage_event!(inj, 1, :household, Int32(2), Int16(1))
        sim = Simulation(population = pop, population_injection = inj, stop_criterion = TimesUp(limit = 2))
        ind1 = get_individual_by_id(population(sim), Int32(1))
        @test ind1 in individuals(settings(sim, Household)[1])
        for _ in 1:2; step!(sim); end                     # day-1 change is applied at tick 1 (during step 2)
        ind1 = get_individual_by_id(population(sim), Int32(1))
        @test ind1 in individuals(settings(sim, Household)[2])
        @test !(ind1 in individuals(settings(sim, Household)[1]))
        @test ind1.household == Int32(2)
    end

    @testset "move to a new setting: created as the next free id, CSM inherited" begin
        pop = Population(make_set_base())
        inj = new_injector(pop)
        PI.update_schema!(inj.schema, :household, Int32[3])
        PI.stage_event!(inj, 2, :household, Int32(3), Int16(1))
        sim = Simulation(population = pop, population_injection = inj, stop_criterion = TimesUp(limit = 3))
        for _ in 1:2; step!(sim); end
        hhvec = settings(sim, Household)
        @test length(hhvec) == 3
        ind2 = get_individual_by_id(population(sim), Int32(2))
        @test ind2 in individuals(hhvec[3])
        @test !(ind2 in individuals(hhvec[1]))
        @test ind2.household == Int32(3)
        @test typeof(GEMS.contact_sampling_method(hhvec[3])) == typeof(GEMS.contact_sampling_method(hhvec[1]))
        @test household(ind2, sim) === hhvec[3]
    end

    @testset "staging a non-contiguous new id is a staging error" begin
        pop = Population(make_set_base())
        inj = new_injector(pop)                                   # base households: 1, 2 → next new id is 3
        PI.update_schema!(inj.schema, :household, Int32[9])
        @test_throws ArgumentError PI.stage_event!(inj, 1, :household, Int32(9), Int16(1))
        PI.update_schema!(inj.schema, :household, Int32[3, 4])
        PI.stage_event!(inj, 1, :household, Int32(3), Int16(1))
        PI.stage_event!(inj, 2, :household, Int32(4), Int16(1))   # 4 = 3 + 1 — allowed after 3 is staged
    end

    @testset "move to the default id: membership removed" begin
        pop = Population(make_set_base())
        inj = new_injector(pop)
        PI.update_schema!(inj.schema, :household, Int32[-1])
        PI.stage_event!(inj, 1, :household, Int32(-1), Int16(1))
        sim = Simulation(population = pop, population_injection = inj, stop_criterion = TimesUp(limit = 3))
        for _ in 1:2; step!(sim); end
        ind1 = get_individual_by_id(population(sim), Int32(1))
        @test ind1.household == Int32(-1)
        @test !(ind1 in individuals(settings(sim, Household)[1]))
        @test !(ind1 in individuals(settings(sim, Household)[2]))
    end

    @testset "births join their staged household (existing and new)" begin
        pop = Population(make_set_base())
        inj = new_injector(pop)
        PI.update_schema!(inj.schema, :age, Int8[0])
        PI.update_schema!(inj.schema, :household, Int32[3])
        ids = PI.stage_new_individuals!(inj, DataFrame(
            sex = Int8[1, 0], age = Int8[0, 0], household = Int32[2, 3]), Int16(1))
        sim = Simulation(population = pop, population_injection = inj, stop_criterion = TimesUp(limit = 3))
        for _ in 1:2; step!(sim); end
        hhvec = settings(sim, Household)
        @test length(hhvec) == 3
        @test get_individual_by_id(population(sim), Int32(ids[1])) in individuals(hhvec[2])
        @test get_individual_by_id(population(sim), Int32(ids[2])) in individuals(hhvec[3])
        @test household_id(get_individual_by_id(population(sim), Int32(ids[2]))) == Int32(3)
    end

    @testset "injection-time violation: a non-next id cannot be created" begin
        pop = Population(make_set_base())
        sim = Simulation(population = pop, stop_criterion = TimesUp(limit = 1))
        cntnr = GEMS.settingscontainer(sim)
        @test_throws ArgumentError GEMS._apply_setting_move!(cntnr, Household, get_individual_by_id(pop, Int32(1)), Int32(7))
    end

    @testset "reset! re-applies the move without duplicating membership" begin
        pop = Population(make_set_base())
        inj = new_injector(pop)
        PI.stage_event!(inj, 1, :household, Int32(2), Int16(1))
        sim = Simulation(population = pop, population_injection = inj, stop_criterion = TimesUp(limit = 3))
        for _ in 1:2; step!(sim); end
        reset!(sim)
        for _ in 1:2; step!(sim); end
        ind1 = get_individual_by_id(population(sim), Int32(1))
        @test count(x -> x === ind1, individuals(settings(sim, Household)[2])) == 1
        @test !(ind1 in individuals(settings(sim, Household)[1]))
        @test ind1.household == Int32(2)
    end

    @testset "bake-in moves membership at construction" begin
        pop = Population(make_set_base())
        inj = new_injector(pop)
        PI.update_schema!(inj.schema, :household, Int32[3])
        PI.stage_event!(inj, 1, :household, Int32(2), Int16(0))     # day 0 → baked in
        PI.stage_event!(inj, 2, :household, Int32(3), Int16(0))     # day 0 → baked in, household created
        sim = Simulation(population = pop, population_injection = inj, population_snapshot = 0,
                         stop_criterion = TimesUp(limit = 1))
        hhvec = settings(sim, Household)
        @test length(hhvec) == 3
        @test get_individual_by_id(population(sim), Int32(1)) in individuals(hhvec[2])
        @test get_individual_by_id(population(sim), Int32(2)) in individuals(hhvec[3])
    end

    @testset "other setting types (office) move the same way" begin
        pop = Population(make_set_base())
        inj = new_injector(pop)
        PI.update_schema!(inj.schema, :office, Int32[3])
        PI.stage_event!(inj, 1, :office, Int32(3), Int16(1))
        sim = Simulation(population = pop, population_injection = inj, stop_criterion = TimesUp(limit = 3))
        for _ in 1:2; step!(sim); end
        ovec = settings(sim, Office)
        @test length(ovec) == 3
        @test get_individual_by_id(population(sim), Int32(1)) in individuals(ovec[3])
        @test !(get_individual_by_id(population(sim), Int32(1)) in individuals(ovec[1]))
    end
end
