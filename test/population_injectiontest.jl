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
        id=1:100,
        name=string.("Person_", 1:100),
        age=Int8.(rand(18:80, 100)),
        salary=rand(30000.0:150000.0, 100),
        department=rand(["IT", "HR", "Finance", "Marketing", "Operations"], 100),
        active=rand([true, false], 100),
        score=rand(0.0:100.0, 100)
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
    empty_df = DataFrame(id=Int[], name=String[], age=Int[])
    schema = PI.create_column_schema(empty_df)
    inj = PI.Injector(schema)

    @test schema isa PI.InjectorSchema
    @test inj isa PI.Injector

    # Test with single row
    single_row_df = DataFrame(id=[1], name=["Test"], age=[25])
    single_schema = PI.create_column_schema(single_row_df)
    single_inj = PI.Injector(single_schema)

    @test single_schema.meta[:num_individuals] == 1
    @test single_inj isa PI.Injector

    # Test with boolean values
    bool_df = DataFrame(active=[true, false, true])
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
    @test length(inj.schema.index_to_field) == 7
    @test inj.schema.index_to_field[1] == :id
    @test inj.schema.index_to_field[2] == :name
    @test inj.schema.index_to_field[3] == :age
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
            salary=[Float64(50000.0)],
            department=["IT"],  # Use existing department
            active=[true],
            score=[Float64(85.5)]
        )

        new_id = PI.stage_new_individuals!(inj, new_individuals, Int16(300))

        @test isa(collect(new_id), Vector{Int})
        @test length(inj.events) == 6  # One event per field (excluding id)
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
            salary=[Float64(90000.0)],
            department=["Finance"],
            active=[true],
            score=[Float64(72.0)]
        )
        new_id = PI.stage_new_individuals!(inj, new_individuals, Int16(300))

        # Test snapshot at timestamp before stage_new_individuals! (Int16(250))
        # New individual should not appear in the snapshot since it wasn't created yet
        snapshot_before = PI.snapshot(inj, base_pop, Int16(250))
        @test size(snapshot_before) == (100, 7)  # Original size

        # Test snapshot at timestamp after stage_new_individuals! (Int16(350))
        # New individual should appear in the snapshot with all its field values
        snapshot_after = PI.snapshot(inj, base_pop, Int16(350))
        @test size(snapshot_after) == (101, 7)  # Size increased by 1

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
        @test size(snapshot_at_addition) == (101, 7)
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
            salary=[Float64(65000.0)],
            department=["HR"],
            active=[true],
            score=[Float64(80.0)]
        )
        id_2 = PI.stage_new_individuals!(inj, new_individuals_2, Int16(500))

        # Snapshot before first new individual (Int16(350)) - should have original size
        snap_early = PI.snapshot(inj, base_pop, Int16(350))
        @test size(snap_early) == (100, 7)

        # Snapshot between the two new individuals (Int16(450)) - should have first individual only
        snap_middle = PI.snapshot(inj, base_pop, Int16(450))
        @test size(snap_middle) == (id_1[1], 7)
        @test snap_middle[id_1[1], :name] == "Person_6"

        # Snapshot after both individuals added (Int16(550)) - should have both new individuals
        snap_late = PI.snapshot(inj, base_pop, Int16(550))
        @test size(snap_late) == (id_2[1], 7)
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

        # Add an individual with only some fields specified
        partial_individual = DataFrame(
            name=["Person_8"],
            age=[Int8.(50)[1]]
        )
        id_3 = PI.stage_new_individuals!(inj, partial_individual, Int16(600))

        # Snapshot after individual addition - verify only specified fields are set
        snap = PI.snapshot(inj, base_pop, Int16(700))
        @test size(snap) == (id_3[1], 7)
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
            age=[Int8.(40)[1]]
        )

        new_id = PI.stage_new_individuals!(inj, partial_individual, Int16(700))

        @test length(inj.events) == 2  # Only two events created
    end

    # Test 11.7: Type-specific value handling
    @testset "Type-Specific Values" begin
        schema = PI.create_column_schema(base_pop)
        PI.update_schema!(schema, :age, Int8.(0:115))  # Expand age range to support all test values
        inj = PI.Injector(schema)

        individual = DataFrame(
            name=["Person_6"],  # Use existing name
            age=[Int8.(18)[1]],  # Minimum valid age
            salary=[Float64(30000.0)],  # Minimum salary
            department=["Operations"],  # String value from base population
            active=[false],  # Boolean false
            score=[Float64(100.0)]  # Maximum score
        )

        new_id = PI.stage_new_individuals!(inj, individual, Int16(800))

        @test isa(new_id, Vector{Int})

        # Verify the events can be decoded correctly
        for event in inj.events[end-5:end]
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
                salary=[Float64(40000.0 * (i + 1))],
                department=["HR"],  # Use existing department
                active=[true],
                score=[Float64(70.0 + i * 5)]
            )

            result = PI.stage_new_individuals!(inj, new_individuals, Int16(900 + i))
        end

        # Verify total events created
        @test length(inj.events) == 30  # 5 individuals * 6 fields
    end

    # Test 11.9: Return value consistency
    @testset "Return Value Consistency" begin
        schema = PI.create_column_schema(base_pop)
        PI.update_schema!(schema, :age, Int8.(0:115))  # Expand age range to support all test values
        inj = PI.Injector(schema)

        individuals = DataFrame(
            name=["Person_7", "Person_7"],  # Use existing name - two rows
            age=[Int8.(25)[1], Int8.(25)[1]],
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

    @testset "death injection" begin
        # NOTE: the death column must exist in the schema's base DataFrame.
        base = make_base()
        base[!, :death] = Int8.(fill(-1, 100))          # alive = DEFAULT_TICK (-1); schema built from THIS df
        pop = Population(base)
        schema = PI.create_column_schema(base)
        PI.update_schema!(schema, :death, [Int8(1)])    # the staged flag value must be in the schema
        inj = PI.Injector(schema)
        PI.stage_event!(inj, 3, :death, Int8(1), Int16(7)) # value may be a flag; the TIMESTAMP is the death day

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

    @testset "death with snapshot bake-in" begin
        # death at day 490, snapshot 500 -> dead from simulation tick 0, NOT in DeathLogger
        base = make_base()
        base[!, :death] = Int8.(fill(-1, 100))
        pop = Population(base)
        schema = PI.create_column_schema(base)
        PI.update_schema!(schema, :death, [Int8(1)])
        inj = PI.Injector(schema)
        PI.stage_event!(inj, 3, :death, Int8(1), Int16(490))

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
        PI.update_schema!(schema, :death, [Int8(1)])
        inj = PI.Injector(schema)
        PI.stage_event!(inj, 1, :occupation, Int16(20), Int16(490))   # baked in
        PI.stage_event!(inj, 3, :death, Int8(1), Int16(495))          # baked in (dead from tick 0)
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
        # birth without :sex/:age (force bake-in so the error surfaces at construction)
        inj2 = PI.Injector(PI.create_column_schema(dataframe(pop)))
        PI.stage_new_individuals!(inj2, DataFrame(id = Int32[200], occupation = Int16[1]), Int16(1))
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
