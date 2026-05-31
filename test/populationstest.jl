@testset "Populations" begin

    @testset "Creating and Managing" begin
        p = Population(empty = true)
        @test individuals(p) == Vector{Individual}()
        i1 = Individual(age=42, id=1, sex=0)
        i2 = Individual(age=21, id=2, sex=1)
        i3 = Individual(age=1, id=3, sex=1)

        add!(p, i1)
        @test individuals(p) == Vector{Individual}([i1])
        add!(p, i2)
        @test individuals(p) == Vector{Individual}([i1, i2])
        remove!(p, i1)
        @test individuals(p) == Vector{Individual}([i2])
        add!(p, i3)
        @test individuals(p) == Vector{Individual}([i2, i3])
        remove!(p, i1) # should work but not do anything
        @test individuals(p) == Vector{Individual}([i2, i3])

        # issubset compares by individual id
        @test issubset([i2], [i2, i3])
        @test issubset([i2, i3], [i2, i3])
        @test !issubset([i1, i2], [i2, i3])
        @test issubset(Individual[], [i2, i3])  # empty set is subset of anything

        # Base.show
        pop_show = Population([i1, i2, i3])
        output = @capture_out show(pop_show)
        @test occursin("Population", output)
        @test occursin("3", output)
    end

    @testset "Loading" begin
        @testset "CSV-Loading" begin

            num_indiv_in_file = 100

            testfile = "test/testdata/TestPop.csv"
            base_folder = dirname(dirname(pathof(GEMS)))
            path = joinpath(base_folder, testfile)

            csv_content = CSV.read(path, DataFrame)
            population = individuals(Population(path))

            id_map = Dict([(id(individual), individual) for individual in population])
            @test keys(id_map) == Set(range(0,num_indiv_in_file-1))
            for row in eachrow(csv_content)
                @test age(id_map[row["id"]]) == row["age"]
                @test household_id(id_map[row["id"]]) == row["household"]
            end
        end
        
        @testset "JLD2-Loading" begin
            num_indiv_in_file = 1000
            
            testfile = "test/testdata/test_pop_multi_settings_1000_individuals.jld2"
            base_folder = dirname(dirname(pathof(GEMS)))
            path = joinpath(base_folder, testfile)

            jld2_content = load(path, "data")
            population = individuals(Population(path))

            id_map = Dict([(id(individual), individual) for individual in population])
            @test keys(id_map) == Set(range(1,num_indiv_in_file))
            for row in eachrow(jld2_content)
                @test age(id_map[row["id"]]) == row["age"]
                @test household_id(id_map[row["id"]]) == row["household"]
            end
        end
    end

    @testset "Number of Infected" begin
        sim = Simulation(pop_size = 1000, infected_fraction = 0.0)
        pop = population(sim)

        @test 0 == num_of_infected(pop)
        infect!(individuals(sim)[1], sim)
        @test 1 == num_of_infected(pop)

        run!(sim)
        # in the end, the agent should have recovered
        @test 0 == num_of_infected(pop)
    end
    

    @testset "Individual Extensions" begin

        mutable struct PopTestExt
            score::Float32
            category::Int8
        end

        @testset "Extra columns ignored by default" begin
            df = DataFrame(
                id = Int32.(1:5),
                age = Int8.(20:24),
                sex = Int8.(ones(5)),
                household = Int32.(1:5),
                score = Float32.(0.1:0.1:0.5),
                category = Int8.(1:5)
            )
            # Extra columns are ignored — no extensions without explicit ind_extension
            pop = Population(df)
            @test eltype(individuals(pop)) == Individual{Nothing}
        end

        @testset "Explicit Symbol-vector ind_extension" begin
            df = DataFrame(
                id = Int32.(1:5),
                age = Int8.(20:24),
                sex = Int8.(ones(5)),
                household = Int32.(1:5),
                score = Float32.(0.1:0.1:0.5),
                category = Int8.(1:5)
            )
            # Only requested columns become extensions
            pop = Population(df; ind_extension = [:score, :category])
            @test eltype(individuals(pop)) <: Individual{<:AutoExtension}

            ind = individuals(pop)[1]
            @test ind.score ≈ 0.1f0
            @test ind.category == Int8(1)
            @test age(ind) == Int8(20)

            # Transparent write (via AutoExtension merge)
            ind.score = 0.9f0
            @test ind.score ≈ 0.9f0
            @test ind.category == Int8(1)   # other field unchanged

            # Missing column names warn gracefully
            @test_logs (:warn, r"not found") Population(df; ind_extension = [:nonexistent])
        end

        @testset "Explicit ind_extension factory" begin
            df = DataFrame(
                id = Int32.(1:5),
                age = Int8.(20:24),
                sex = Int8.(ones(5)),
                household = Int32.(1:5)
            )
            pop = Population(df; ind_extension = ind -> PopTestExt(Float32(age(ind)) / 100f0, Int8(1)))

            @test eltype(individuals(pop)) == Individual{PopTestExt}

            ind = individuals(pop)[1]
            @test ind.score ≈ 0.20f0   # age 20 / 100
            @test ind.category == Int8(1)

            # in-place mutation via setfield!
            ind.score = 0.5f0
            @test ind.score ≈ 0.5f0
        end

        @testset "No extra columns → Population{Nothing}" begin
            df = DataFrame(id = Int32.(1:3), age = Int8.(20:22), sex = Int8.(ones(3)), household = Int32.(1:3))
            pop = Population(df)
            @test eltype(individuals(pop)) == Individual{Nothing}
        end

        @testset "Simulation with ind_extension" begin
            sim = Simulation(ind_extension = ind -> PopTestExt(0.5f0, Int8(1)))
            ind = individuals(population(sim))[1]
            @test ind.score == 0.5f0
            @test ind.category == Int8(1)
        end

        @testset "DataFrame ind_extension" begin
            base_df = DataFrame(
                id = Int32.(1:5),
                age = Int8.(20:24),
                sex = Int8.(ones(5)),
                household = Int32.(1:5)
            )
            ext_df = DataFrame(
                id = Int32.(1:5),
                score = Float32.([0.1, 0.2, 0.3, 0.4, 0.5])
            )

            # full match: all IDs present
            pop = Population(base_df; ind_extension = ext_df)
            @test eltype(individuals(pop)) <: Individual{<:AutoExtension}
            @test individuals(pop)[1].score ≈ 0.1f0
            @test individuals(pop)[3].score ≈ 0.3f0

            # transparent mutation
            individuals(pop)[1].score = 0.9f0
            @test individuals(pop)[1].score ≈ 0.9f0

            # missing IDs: warn and fill with zero
            ext_partial = DataFrame(id = Int32.(1:3), score = Float32.([0.1, 0.2, 0.3]))
            pop_partial = @test_logs (:warn, r"individual") Population(base_df; ind_extension = ext_partial)
            @test individuals(pop_partial)[4].score == 0.0f0   # missing → zero
            @test individuals(pop_partial)[1].score ≈ 0.1f0   # present → correct

            # extra rows in ext_df are silently ignored
            ext_extra = DataFrame(id = Int32.(1:10), score = Float32.(0.1:0.1:1.0))
            pop_extra = Population(base_df; ind_extension = ext_extra)
            @test length(individuals(pop_extra)) == 5
            @test individuals(pop_extra)[5].score ≈ 0.5f0
        end
    end

    @testset "get_individual_by_id" begin

        pop = Population([Individual(id=100, age=0, sex=0), Individual(id=101, age=0, sex=0), Individual(id=102, age=0, sex=0)])
        @test get_individual_by_id(pop, Int32(100)) === pop.individuals[1] 
        @test get_individual_by_id(pop, Int32(101)) === pop.individuals[2] 
        @test get_individual_by_id(pop, Int32(102)) === pop.individuals[3]  
        
        # invalid ids
        @test get_individual_by_id(pop, Int32(99)) === nothing
        @test get_individual_by_id(pop, Int32(103)) === nothing 
        
        # empty population
        empty_pop = Population(Individual[])
        @test get_individual_by_id(empty_pop, Int32(100)) === nothing 

    end
end