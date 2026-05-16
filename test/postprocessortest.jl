@testset "Post Processing" begin
    # setting up post processor structure
    basef = dirname(dirname(pathof(GEMS)))
    popfile = "test/testdata/TestPop.csv"
    populationpath = joinpath(basef, popfile)

    confile = "test/testdata/TestConf.toml"
    configpath = joinpath(basef, confile)

    sim = Simulation(configfile = configpath, population = populationpath)
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

            @test num_individuals == sum(grouped_by_age[:, :sum])

            # test if error is thrown on illegal ArgumentError
            copied_df = copy(population_df)
            morphed_df = select!(copied_df, :id)

            @test_throws ArgumentError GEMS.group_by_age(morphed_df)

            # test if output contains a column "sum"
            grouped_by_age = GEMS.group_by_age(population_df)

            @test :sum in propertynames(grouped_by_age)

        end

        @testset "serotestsDF" begin
            # Scenario Setup
            seroprevalence_testing = Simulation()
            seroprevalence_test = SeroprevalenceTestType("Seroprevalence Test", pathogen(seroprevalence_testing), seroprevalence_testing)
            testing = IStrategy("Testing", seroprevalence_testing)
            add_measure!(testing, GEMS.Test("Test", seroprevalence_test))
            trigger = ITickTrigger(testing, switch_tick=Int16(1), interval=Int16(1))
            add_tick_trigger!(seroprevalence_testing, trigger)
            run!(seroprevalence_testing)
            pp = PostProcessor(seroprevalence_testing)
            df = serotestsDF(pp)

            @test isa(df, DataFrame)

            # Expected column names
            expected_cols = [
                "test_id", "test_tick", "id", "test_result", "infected",
                "was_infected", "infection_id", "test_type"
            ]
            @test all(col -> col in names(df), expected_cols)


            @test nrow(df) > 0

            @test isa(df.test_id, Vector{Int32})
            @test isa(df.test_tick, Vector{Int16})
            @test isa(df.id, Vector{Int32})
            @test isa(df.test_result, Vector{Bool})
            @test isa(df.infected, Vector{Bool})
            @test isa(df.was_infected, Vector{Bool})
            @test isa(df.infection_id, Vector{Int32})
            @test isa(df.test_type, Vector{String})

            @test all(df.infection_id .>= -1)
            @test all(df.test_tick .>= 0)

            result = tick_serotests(pp)

            # Check that result is a Dict{String, DataFrame}
            @test isa(result, Dict{String,DataFrame})
            @test !isempty(result)

            # Check that each DataFrame has expected structure
            expected_cols = [
                "tick", "true_positives", "false_positives", "true_negatives",
                "false_negatives", "positive_tests", "negative_tests", "total_tests"
            ]

            for (test_type, df) in result
                @test all(col -> col in names(df), expected_cols)

                # Check that total_tests is the sum of positives + negatives for some random row
                nonzero_rows = filter(r -> r.total_tests > 0, df)
                if !isempty(nonzero_rows)
                    first_row = nonzero_rows[1, :]
                    @test first_row.total_tests ==
                          first_row.positive_tests + first_row.negative_tests
                    @test first_row.positive_tests ==
                          first_row.true_positives + first_row.false_positives
                    @test first_row.negative_tests ==
                          first_row.true_negatives + first_row.false_negatives
                end
            end
        end
    end

    @testset "show" begin
        @test !isempty(@capture_out show(pp))
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
        number_of_intervals = ceil(Int, length(simulation_contact_matrix_data[1, :]) / 10)

        population_df = populationDF(pp)
        aggregated_population = GEMS.aggregate_populationDF_by_age(population_df, 10)

        contact_matrix = mean_contacts_per_age_group(pp, Household, 10)

        # test interval length of output matrix
        @test contact_matrix._size == number_of_intervals

        # one row of the aggregated matrix should have the same length as the aggregated population vector
        @test contact_matrix._size == length(aggregated_population)

        # aggregate_populationDF_by_age: error without age column
        @test_throws ArgumentError GEMS.aggregate_populationDF_by_age(DataFrame(x = [1, 2, 3]), 10)
        @test_throws ArgumentError GEMS.aggregate_populationDF_by_age(DataFrame(x = [1, 2, 3]), 10, 80)

        # aggregate_populationDF_by_age with max_age: all individuals are preserved in aggregated bins
        agg_pop_bounded = GEMS.aggregate_populationDF_by_age(population_df, 10, 80)
        @test sum(agg_pop_bounded) == nrow(population_df)

        # individuals_per_age_group without aggregation_bound
        ipag = individuals_per_age_group(pp, 10)
        @test ipag isa DataFrame
        @test :age_groups in propertynames(ipag)
        @test :num_individuals in propertynames(ipag)
        @test sum(ipag.num_individuals) == nrow(population_df)

        # individuals_per_age_group with aggregation_bound: error cases
        @test_throws ArgumentError individuals_per_age_group(pp, 1, 80)  # interval_steps <= 1
        @test_throws ArgumentError individuals_per_age_group(pp, 10, 1)  # aggregation_bound <= 1
        @test_throws ArgumentError individuals_per_age_group(pp, 10, 5)  # aggregation_bound < interval_steps
        @test_throws ArgumentError individuals_per_age_group(pp, 10, 85) # not a multiple

        # individuals_per_age_group with aggregation_bound: all individuals preserved
        ipag_bounded = individuals_per_age_group(pp, 10, 80)
        @test ipag_bounded isa DataFrame
        @test sum(ipag_bounded.num_individuals) == nrow(population_df)

        # mean_contacts_per_age_group with max_age: error case
        @test_throws ArgumentError mean_contacts_per_age_group(pp, Household, 10, 1)

        # mean_contacts_per_age_group with max_age: returns valid non-negative matrix
        cm_bounded = mean_contacts_per_age_group(pp, Household, 10, 80)
        @test cm_bounded isa ContactMatrix{Float64}
        @test all(x -> x >= 0.0, cm_bounded.data)

        # weighted_error_sum with a zero error matrix → 0
        n = cm_bounded._size
        @test weighted_error_sum(pp, ContactMatrix{Float64}(zeros(Float64, n, n), 10, 80)) == 0.0

        # weighted_error_sum with a ones error matrix → positive (population is non-empty)
        @test weighted_error_sum(pp, ContactMatrix{Float64}(ones(Float64, n, n), 10, 80)) > 0.0

        # weighted_error_sum comparing simulation against its own contact matrix → non-negative
        @test weighted_error_sum(pp, Household, cm_bounded; fit_to_reference_matrix=false) >= 0.0
        @test weighted_error_sum(pp, Household, cm_bounded; fit_to_reference_matrix=true) >= 0.0

    end
end
