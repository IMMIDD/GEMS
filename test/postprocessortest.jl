import GEMS: _mean_contacts_per_age_group,
    _individuals_per_age_group,
    _weighted_error_sum,
    _aggregate_populationDF_by_age

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

        # infections is an alias for infectionsDF — both must return the same object
        @test infections(pp) isa DataFrame
        @test infections(pp) === infectionsDF(pp)

        # compartmentsDF returns the state-logger compartment data
        @test compartmentsDF(pp) isa DataFrame
        @test nrow(compartmentsDF(pp)) > 0

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
            grouped_by_age = GEMS._group_by_age(population_df)

            @test num_individuals == sum(grouped_by_age[:, :sum])

            # test if error is thrown on illegal ArgumentError
            copied_df = copy(population_df)
            morphed_df = select!(copied_df, :id)

            @test_throws ArgumentError GEMS._group_by_age(morphed_df)

            # test if output contains a column "sum"
            grouped_by_age = GEMS._group_by_age(population_df)

            @test :sum in propertynames(grouped_by_age)

        end

        @testset "serotestsDF" begin
            # Scenario Setup
            seroprevalence_testing = Simulation()
            seroprevalence_test = SeroprevalenceTestType("Seroprevalence Test", id(first_pathogen(seroprevalence_testing)), seroprevalence_testing)
            testing = IStrategy("Testing", seroprevalence_testing)
            add_measure!(testing, GEMS.Test("Test", seroprevalence_test))
            trigger = ITickTrigger(testing, switch_tick=Int16(1), interval=Int16(120))
            add_tick_trigger!(seroprevalence_testing, trigger)
            run!(seroprevalence_testing)
            pp = PostProcessor(seroprevalence_testing)
            df = serotestsDF(pp)

            @test isa(df, DataFrame)

            # Expected column names
            expected_cols = [
                "test_id", "tick", "id", "test_result", "infected",
                "was_infected", "infection_id", "test_type"
            ]
            @test all(col -> col in names(df), expected_cols)


            @test nrow(df) > 0

            @test isa(df.test_id, Vector{Int32})
            @test isa(df.tick, Vector{Int16})
            @test isa(df.id, Vector{Int32})
            @test isa(df.test_result, Vector{Bool})
            @test isa(df.infected, Vector{Bool})
            @test isa(df.was_infected, Vector{Bool})
            @test isa(df.infection_id, Vector{Int32})
            @test isa(df.test_type, Vector{String})

            @test all(df.infection_id .>= -1)
            @test all(df.tick .>= 0)

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

    @testset "Co-Infection Death Accounting" begin
        # a host death ends every co-active infection and is credited to one pathogen
        dkw = (exposure_to_infectiousness_onset = Poisson(1), infectiousness_onset_to_symptom_onset = Poisson(1),
            symptom_onset_to_severeness_onset = Poisson(1), severeness_onset_to_critical_onset = Poisson(2),
            critical_onset_to_critical_offset = Poisson(5), critical_offset_to_severeness_offset = Poisson(3),
            severeness_offset_to_recovery = Poisson(10))
        crit = Critical(; dkw...)
        hp = DefaultHealthProgression(critical = CriticalHealthProfile(
            hospital_probability = 0.4, critical_onset_to_hospital_admission = Poisson(1),
            hospital_admission_to_hospital_discharge = Poisson(8),
            death_probability = 0.15, critical_onset_to_death = Poisson(6)))
        mkp(i, nm) = Pathogen(id = i, name = nm, progressions = [crit],
            progression_assignment = RandomProgressionAssignment([Critical]),
            transmission_function = ConstantTransmissionRate(transmission_rate = 0.15))
        sim_ci = Simulation(pop_size = 4000, pathogens = (mkp(1, "A"), mkp(2, "B")),
            health_progression = hp, infected_fraction = 0.01, seed = 42, tickunit = 'd')
        run!(sim_ci, with_progressbar = false)
        pp_ci = PostProcessor(sim_ci)

        n_deaths = nrow(deathsDF(pp_ci))
        @test n_deaths > 0
        # the death tick is deliberately not on the infection rows
        @test !(:death in propertynames(infectionsDF(pp_ci)))
        @test !(:killing_pathogen_id in propertynames(infectionsDF(pp_ci)))
        @test sum(tick_deaths(pp_ci).death_cnt) == n_deaths
        @test sum(tick_cases(pp_ci).dead_cnt) == n_deaths
        @test sum(combine(groupby(cumulative_deaths(pp_ci), :pathogen_id),
            :deaths_cum => maximum)[!, 2]) == n_deaths

        # a truncated infection still ended at a real tick
        cp = compartment_periods(pp_ci)
        @test all(>=(0), cp.total)
        @test all(>=(0), cp.infectious)
        @test all(>=(0), cp.symptomatic)

        # the normalized distribution still accounts for every infection
        acp = aggregated_compartment_periods(pp_ci)
        for p in unique(acp.pathogen_id)
            @test isapprox(sum(subset(acp, :pathogen_id => ByRow(==(p))).total), 1.0, atol = 1e-9)
        end
    end

    @testset "Contact Matrices" begin

        simulation_contact_matrix_data = setting_age_contacts(pp, Household)
        number_of_intervals = ceil(Int, length(simulation_contact_matrix_data[1, :]) / 10)

        population_df = populationDF(pp)
        aggregated_population = _aggregate_populationDF_by_age(population_df, 10)

        contact_matrix = _mean_contacts_per_age_group(pp, Household, 10)

        # test interval length of output matrix
        @test contact_matrix._size == number_of_intervals

        # one row of the aggregated matrix should have the same length as the aggregated population vector
        @test contact_matrix._size == length(aggregated_population)

        # aggregate_populationDF_by_age: error without age column
        @test_throws ArgumentError _aggregate_populationDF_by_age(DataFrame(x = [1, 2, 3]), 10)
        @test_throws ArgumentError _aggregate_populationDF_by_age(DataFrame(x = [1, 2, 3]), 10, 80)

        # aggregate_populationDF_by_age with max_age: all individuals are preserved in aggregated bins
        agg_pop_bounded = _aggregate_populationDF_by_age(population_df, 10, 80)
        @test sum(agg_pop_bounded) == nrow(population_df)

        # individuals_per_age_group without aggregation_bound
        ipag = _individuals_per_age_group(pp, 10)
        @test ipag isa DataFrame
        @test :age_groups in propertynames(ipag)
        @test :num_individuals in propertynames(ipag)
        @test sum(ipag.num_individuals) == nrow(population_df)

        # individuals_per_age_group with aggregation_bound: error cases
        @test_throws ArgumentError _individuals_per_age_group(pp, 1, 80)  # interval_steps <= 1
        @test_throws ArgumentError _individuals_per_age_group(pp, 10, 1)  # aggregation_bound <= 1
        @test_throws ArgumentError _individuals_per_age_group(pp, 10, 5)  # aggregation_bound < interval_steps
        @test_throws ArgumentError _individuals_per_age_group(pp, 10, 85) # not a multiple

        # individuals_per_age_group with aggregation_bound: all individuals preserved
        ipag_bounded = _individuals_per_age_group(pp, 10, 80)
        @test ipag_bounded isa DataFrame
        @test sum(ipag_bounded.num_individuals) == nrow(population_df)

        # mean_contacts_per_age_group with max_age: error case
        @test_throws ArgumentError _mean_contacts_per_age_group(pp, Household, 10, 1)

        # mean_contacts_per_age_group with max_age: returns valid non-negative matrix
        cm_bounded = _mean_contacts_per_age_group(pp, Household, 10, 80)
        @test cm_bounded isa ContactMatrix{Float64}
        @test all(x -> x >= 0.0, cm_bounded.data)

        # weighted_error_sum with a zero error matrix → 0
        n = cm_bounded._size
        @test _weighted_error_sum(pp, ContactMatrix{Float64}(zeros(Float64, n, n), 10, 80)) == 0.0

        # weighted_error_sum with a ones error matrix → positive (population is non-empty)
        @test _weighted_error_sum(pp, ContactMatrix{Float64}(ones(Float64, n, n), 10, 80)) > 0.0

        # weighted_error_sum comparing simulation against its own contact matrix → non-negative
        @test _weighted_error_sum(pp, Household, cm_bounded; fit_to_reference_matrix=false) >= 0.0
        @test _weighted_error_sum(pp, Household, cm_bounded; fit_to_reference_matrix=true) >= 0.0

    end

    @testset "Health episodes" begin
        # a pre-decoupling config that reliably produces hospital + ICU stays (and deaths)
        hsim = Simulation(configfile = joinpath(basef, "test/testdata/TestConf_old.toml"))
        run!(hsim)
        hpp = PostProcessor(hsim)

        ep = health_episodes(hpp)
        @test ep isa DataFrame
        @test names(ep) == ["host_id", "care_level", "admission_tick", "discharge_tick"]
        @test nrow(ep) > 0
        @test all(ep.discharge_tick .>= ep.admission_tick)                    # valid intervals
        @test issubset(Set(ep.care_level), Set([:hospital, :icu, :ventilation]))

        hosp_ep = subset(ep, :care_level => ByRow(==(:hospital)))
        icu_ep = subset(ep, :care_level => ByRow(==(:icu)))
        @test nrow(hosp_ep) > 0                                               # Hospitalized + LegacyCritical
        @test nrow(icu_ep) > 0                                                # LegacyCritical escalates to ICU
        @test !(:ventilation in ep.care_level)                               # legacy never ventilates

        # one episode per discharge event reconciles with the per-tick occupancy report
        hdf = GEMS._hospital_df(hpp)
        @test nrow(hosp_ep) == sum(hdf.hospital_discharges)
        @test nrow(icu_ep) == sum(hdf.icu_discharges)

        # ladder: each ICU episode sits inside a hospital episode of the same host
        for g in groupby(ep, :host_id)
            h = subset(g, :care_level => ByRow(==(:hospital)), view = true)
            ic = subset(g, :care_level => ByRow(==(:icu)), view = true)
            for i in 1:nrow(ic)
                @test any((h.admission_tick .<= ic.admission_tick[i]) .&
                          (h.discharge_tick .>= ic.discharge_tick[i]))
            end
        end

        # ResultData: stored in default, omitted from light (raw per-episode data, like `infections`)
        rd = ResultData(hpp)
        @test health_episodes(rd) isa DataFrame
        @test nrow(health_episodes(rd)) == nrow(ep)
        rd_light = ResultData(hpp, style = "LightRD")
        @test isempty(health_episodes(rd_light))
    end
end