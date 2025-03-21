@testset "Post Processing" begin
    # setting up post processor structure
    basef = dirname(dirname(pathof(GEMS)))
    popfile = "test/testdata/TestPop.csv"
    populationpath = joinpath(basef, popfile)

    confile = "test/testdata/TestConf.toml"
    configpath = joinpath(basef, confile)

    sim = Simulation(configpath, populationpath)
    run!(sim)
    pp = PostProcessor(sim)

    @testset "Basic Methods" begin
        
        @test pp |> simulation == sim
        @test pp |> populationDF == sim |> population |> dataframe

        #check if processed infections dataframe is of same length as "flat" dataframe
        @test pp |> infectionsDF |> nrow == sim |> infectionlogger |> dataframe |> nrow
    
    end

    @testset "Dataframes" begin
        # check if infection dataframe has at least one entry
        df = sim |> infectionlogger |> dataframe
        @test nrow(df) > 0

        ## TODO: Vaclogger

        # check if population dataframe has same length of individual array 
        df = sim |> population |> dataframe
        popsize = sim |> population |> size
        @test nrow(df) == popsize

        @testset "Dataframe grouping" begin
            population_df = sim |> population |> dataframe

            num_individuals = nrow(population_df)

            # test if grouping by age keeps the number of individuals
            grouped_by_age = GEMS.group_by_age(population_df)

            @test num_individuals == sum(grouped_by_age[:,:sum])

            # test if error is thrown on illegal ArgumentError
            copied_df = copy(population_df)
            morphed_df = select!(copied_df, :id)

            @test_throws ArgumentError GEMS.group_by_age(morphed_df)

            # test if output contains a column "sum"
            grouped_by_age = GEMS.group_by_age(population_df)

            @test :sum in propertynames(grouped_by_age)

        end

    end

    @testset "Data Analysis Functions" begin
        
        @test pp |> sim_infectionsDF |> nrow > 0
        @test pp |> effectiveR |> nrow > 0
        @test age_incidence(pp, 7, 100_00) |> nrow > 0
        @test pp |> compartment_periods |> nrow > 0
        @test pp |> tick_cases |> nrow > 0
        @test pp |> cumulative_cases |> nrow > 0
    end

    @testset "Contact Matrices" begin
       
        simulation_contact_matrix_data = setting_age_contacts(pp, Household)
        number_of_intervals = ceil(Int, length(simulation_contact_matrix_data[1,:]) / 10)
        
        population_df = populationDF(pp)
        aggregated_population = GEMS.aggregate_populationDF_by_age(population_df, 10)

        contact_matrix = mean_contacts_per_age_group(pp, Household, 10)

        # test interval length of output matrix
        @test contact_matrix._size == number_of_intervals

        # one row of the aggregated matrix should have the same length as the aggregated population vector
        @test contact_matrix._size == length(aggregated_population)
        
    end
end
