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
        i1 = Individual(age=42, id=1, sex=0)
        i2 = Individual(age=21, id=2, sex=1)
        i3 = Individual(age=1, id=3, sex=1)
        pop = Population([i1, i2, i3])
        p = Pathogen(id = 1, name = "COVID")

        infect!(i1, Int16(0), p)
        @test 1 == num_of_infected(pop)
        infect!(i3, Int16(0), p)
        @test 2 == num_of_infected(pop)
        recover!(i1)
        @test 1 == num_of_infected(pop)
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