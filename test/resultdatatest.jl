@testset "Result Data" begin
    basefolder = dirname(dirname(pathof(GEMS)))

    popfile = "test/testdata/TestPop.csv"
    populationpath = joinpath(basefolder, popfile)

    confile = "test/testdata/TestConf.toml"
    configpath = joinpath(basefolder, confile)

    sim = test_sim(populationpath, configpath)
    run!(sim, with_progressbar=false)

    pp = sim |> PostProcessor

    @testset "ResultData Generation" begin
        # Case 1 empty config
        @testset "Full ResultData" begin
            full_rd = ResultData(pp)
            @test isa(full_rd, ResultData)
        end
        # Use style
        @testset "ResultDataStyle" begin
            key_rd = ResultData(pp, style="DefaultResultData")
            @test key_rd |> dataframes != Dict()
            @test key_rd |> infections != Dict()
            @test key_rd |> deaths != Dict()
            @test key_rd |> tick_deaths != Dict()
            @test key_rd |> final_tick != Dict()
            @test key_rd |> config_file != Dict()
            @test key_rd |> population_file != Dict()
            key_rd = ResultData(pp, style="OptimisedResultData")
            mutable struct TestResultData <: ResultDataStyle
                data::Dict{Any,Any}
                function TestResultData(pP)
                    data = Dict("infections" => pP |> infectionsDF)
                    return new(data)
                end
            end
            key_rd = ResultData(pp, style="TestResultData")
            @test key_rd |> model_size == "Not available!"
            @test key_rd.data["infections"] != Dict()
            @test GEMS.get_style("") == DefaultResultData

            key_rd = ResultData(pp, style="EssentialResultData")
            @test key_rd |> dataframes != Dict()
            @test key_rd |> infections != Dict()
            @test key_rd |> deaths != Dict()
            @test key_rd |> final_tick != Dict()
            @test key_rd |> config_file != Dict()
            @test key_rd |> population_file != Dict()
        end

    end
    @testset "ResultData Import" begin
        rd = ResultData(pp, style="OptimisedResultData")
        exportJLD(rd, "tempdir")
        # Test import without modifications
        rd_imp = import_resultdata(joinpath("tempdir", "resultdata.jld2"))
        @test rd_imp |> id == rd |> id

        # finally, remove all test files
        rm("tempdir", recursive=true)
    end

    rd = ResultData(pp)
    @testset "Dictionaries" begin

        # simulation data

        # checking if date string can be parsed
        @test rd |> execution_date |> length > 0
        @test rd |> GEMS_version |> string |> length > 0
        @test rd |> config_file |> isfile
        @test rd |> population_file |> isfile
        @test rd |> final_tick == sim |> tick
        @test rd |> number_of_individuals == sim |> population |> size
        @test rd |> total_infections > 0
        # check if settting type names match
        @test (rd|>setting_data)[!, "setting_type"] |> sort == string.(sim |> settingscontainer |> settingtypes |> collect) |> sort
        @test rd |> pathogens == [sim |> pathogen]
        @test rd |> tick_unit == sim |> tickunit
        @test rd |> start_condition == sim |> start_condition
        @test rd |> stop_criterion == sim |> stop_criterion

        # system data

        @test rd |> kernel == String(Base.Sys.KERNEL) * String(Base.Sys.MACHINE)
        @test rd |> julia_version == string(Base.VERSION)
        @test rd |> word_size == Base.Sys.WORD_SIZE
        @test rd |> threads == Threads.nthreads()
        @test rd |> cpu_data |> length > 0
        @test rd |> total_mem_size > 0
        @test rd |> free_mem_size > 0

        # contact data

        matrix_data = aggregated_setting_age_contacts(rd, Household).data
        # test if matrix data contains numbers
        @test (matrix_data |> sum) > 0
    end

    @testset "DataFrames" begin

        @test rd |> infections |> nrow > 0
        @test rd |> infections |> x -> 'g' in x.setting_type
        @test rd |> effectiveR |> nrow > 0
        @test rd |> compartment_periods |> nrow > 0
        @test rd |> tick_cases |> nrow > 0
        @test rd |> tick_deaths |> nrow > 0
        @test rd |> cumulative_cases |> nrow > 0
        @test rd |> cumulative_deaths |> nrow > 0
        @test rd |> age_incidence |> nrow > 0
        @test rd |> population_pyramid |> nrow > 0

    end

    @testset "Utils & Exporting" begin

        to = TimerOutput()
        timer_output!(rd, to)

        @test rd |> timer_output == to

        #temporary testing directory (timestamp for uniqueness)
        BASE_FOLDER = dirname(dirname(pathof(GEMS)))
        directory = BASE_FOLDER * "/test_" * string(datetime2unix(now()))

        exportJLD(rd, directory)
        exportJSON(rd, directory)

        # check file existence
        @test isfile(directory * "/resultdata.jld2")
        @test isfile(directory * "/runinfo.json")

        # finally, remove all test files
        rm(directory, recursive=true)

    end

    @testset "Constructors tests " begin
        rd = ResultData([pp], style="", print_infos=true)
        @test isa(rd, Vector{ResultData})
        rd = ResultData([sim], style="", print_infos=true)
        @test isa(rd, Vector{ResultData})
        batch = Batch()
        rd = ResultData(batch, style="", print_infos=true)
        @test isa(rd, Vector{ResultData})
    end

    @testset "config_file_val Test" begin
        rd = ResultData(pp)
        config_data = Dict{String,Any}(
            "Settings" => Dict(
                "SchoolClass" => Dict("contact_sampling_method" => Dict("parameters" => Dict("contactparameter" => 1.0), "type" => "ContactparameterSampling")),
                "Office" => Dict("contact_sampling_method" => Dict("parameters" => Dict("contactparameter" => 1.0), "type" => "ContactparameterSampling")),
                "School" => Dict("contact_sampling_method" => Dict("parameters" => Dict("contactparameter" => 1.0), "type" => "ContactparameterSampling")),
                "Household" => Dict("contact_sampling_method" => Dict("parameters" => Dict("contactparameter" => 1.0), "type" => "ContactparameterSampling")),
                "GlobalSetting" => Dict("contact_sampling_method" => Dict("parameters" => Dict("contactparameter" => 1.0), "type" => "ContactparameterSampling"))
            ),
            "Simulation" => Dict(
                "StartCondition" => Dict(
                    "pathogen" => "Test",
                    "type" => "InfectedFraction",
                    "fraction" => 0.05
                ),
                "enddate" => "2024.12.31",
                "tickunit" => "d",
                "StopCriterion" => Dict("type" => "TimesUp", "limit" => 240),
                "seed" => 1234,
                "startdate" => "2024.1.1",
                "GlobalSetting" => true
            ), "Pathogens" => Dict(
                "Test" => Dict(
                    "mild_death_rate" => Dict(
                        "parameters" => [0.1, 0.2],
                        "distribution" => "Uniform"
                    ),
                    "transmission_function" => Dict(
                        "parameters" => Dict("transmission_rate" => 0.04),
                        "type" => "ConstantTransmissionRate"
                    ),
                    "critical_death_rate" => Dict(
                        "parameters" => [0.98, 0.99],
                        "distribution" => "Uniform"
                    ),
                    "time_to_recovery" => Dict(
                        "parameters" => [24],
                        "distribution" => "Poisson"
                    ),
                    "dpr" => Dict(
                        "age_groups" => ["0-40", "40-80", "80+"],
                        "disease_compartments" => ["Asymptomatic", "Mild", "Severe", "Critical"],
                        "stratification_matrix" => [[1.0, 0.0, 0.0, 0.0], [0.0, 1.0, 0.0, 0.0], [0.0, 0.0, 0.0, 1.0]]
                    )
                )
            ),
            "Population" => Dict(
                "avg_office_size" => 5,
                "avg_school_size" => 100,
                "avg_household_size" => 3,
                "empty" => false,
                "n" => 100000
            )
        )
        @test config_file_val(rd) == config_data
    end

    @testset "population_params Test" begin
        rd = ResultData(pp)
        @test population_params(rd)["populationfile"] == rd.data["meta_data"]["population_file"]
    end

    @testset "tick_serial_intervals and tick_hosptitalizations" begin
        sim = Simulation(label="test")
        rd = sim |> PostProcessor |> ResultData
        @test label(rd) == "test"

        df = tick_serial_intervals(rd)
        @test df isa DataFrame

        # Test tick_serial_intervals
        expected_cols = ["max_SI", "tick", "upper_95_SI", "lower_95_SI", "std_SI", "min_SI", "mean_SI"]

        # Test all expected columns are in the DataFrame
        @test all(col -> col in names(df), expected_cols)

        # Test first row has tick == 0
        @test df[1, :tick] == 0

        # Test tick_hosptitalizations
        df = tick_hosptitalizations(rd)
        @test df isa DataFrame

        expected_cols = [
            "tick", "hospital_cnt", "hospital_releases",
            "icu_cnt", "icu_releases", "ventilation_cnt", "ventilation_releases",
            "current_hospitalized", "current_icu", "current_ventilation"
        ]

        @test all(col -> col in names(df), expected_cols)
        @test df[1, :tick] == 0

    end

    @testset "Custom Logger" begin
        sim = Simulation()

        function logging_func(sim)
            cnt = 0 # counting variable
            inds = individuals(sim)
            for i in inds
                h = household(i, sim)
                if infected(i) && size(h) >= 3
                    cnt += 1
                end
            end
            return cnt
        end

        cl = CustomLogger(infected_in_large_households=logging_func)
        customlogger!(sim, cl)

        run!(sim)
        rd = ResultData(sim)

        df = customlogger(rd)

        # Basic checks
        @test isa(df, DataFrame)
        @test all(col -> col in names(df), ["infected_in_large_households", "tick"])
        @test nrow(df) > 0

        # The count column should be integers ≥ 0
        @test all(x -> isa(x, Integer) && x ≥ 0, df.infected_in_large_households)

        # The tick column should be non-negative and sorted ascending
        @test all(x -> isa(x, Integer) && x ≥ 0, df.tick)
        @test issorted(df.tick)

    end

    @testset "region_info" begin
        sim = Simulation(population="HB")
        run!(sim)
        rd = sim |> PostProcessor |> ResultData

        #test region_info
        df = region_info(rd)

        @test df[1, :ags] == AGS("04011000")
        @test df[1, :pop_size] == 563150
        @test isapprox(df[1, :area], 318.2; atol=1e-2)

        @test df[2, :ags] == AGS("04012000")
        @test df[2, :pop_size] == 113105
        @test isapprox(df[2, :area], 101.41; atol=1e-2)

    end

    @testset "tests(rd) and time_to_detection" begin
        sim = Simulation()
        test = TestType("Test", pathogen(sim), sim)
        add_testtype!(sim, test)
        i_strategy = IStrategy("i_strategy", sim)
        test_measure = GEMS.Test("test", test)
        add_measure!(i_strategy, test_measure)
        i_tick_trigger = ITickTrigger(i_strategy, switch_tick=Int16(1))
        add_tick_trigger!(sim, i_tick_trigger)

        run!(sim)
        rd = sim |> PostProcessor |> ResultData
        df = tests(rd)
        @test all(row -> row.test_tick == 1, eachrow(df))

        @test isa(df, DataFrame)
        @test nrow(df) > 0

        expected_cols = [
            "test_id", "test_tick", "id", "test_result", "infected", "infection_id",
            "test_type", "reportable", "sex", "age", "number_of_vaccinations",
            "vaccination_tick", "education", "occupation", "household", "office", "schoolclass"
        ]
        @test all(col -> col in names(df), expected_cols)

        @test Set(names(df)) == Set(expected_cols)

        @test all(row -> row.test_result in (true, false), eachrow(df))
        @test all(row -> row.infected in (true, false), eachrow(df))
        @test all(row -> row.infected == false ? row.infection_id == -1 : true, eachrow(df))

        #test time_to_detection
        df = time_to_detection(rd)

        # Basic checks
        @test isa(df, DataFrame)
        @test nrow(df) > 0

        expected_cols = [
            "std_time_to_detection", "tick", "upper_95_time_to_detection",
            "lower_95_time_to_detection", "min_time_to_detection",
            "mean_time_to_detection", "max_time_to_detection"
        ]
        @test all(col -> col in names(df), expected_cols)

        # Check tick column is sorted and starts at 1
        @test issorted(df.tick)
        @test df.tick[1] == 1

        # Focus on first tick row only (assuming it's always row 1)
        first_row = df[1, :]

        # Check no missing values in first row columns of interest
        for col in expected_cols
            @test !ismissing(first_row[col])
        end

        # Logical consistency on first row
        @test first_row.min_time_to_detection <= first_row.mean_time_to_detection <= first_row.max_time_to_detection
        @test first_row.lower_95_time_to_detection <= first_row.mean_time_to_detection <= first_row.upper_95_time_to_detection

        #TODO
        @test vaccinations(rd) == Dict()

    end

    @testset "tick_pooltests" begin
        sim = Simulation()
        test = TestType("Test", pathogen(sim), sim)
        s_strategy = SStrategy("s_strategy", sim)
        pool_test = PoolTest("Pool Test", test)
        add_measure!(s_strategy, pool_test)
        s_tick_trigger = STickTrigger(Household, s_strategy, switch_tick=Int16(1))
        add_tick_trigger!(sim, s_tick_trigger)
        run!(sim)
        rd = sim |> PostProcessor |> ResultData
        pt = tick_pooltests(rd)
        df = pt["Test"]
        tick1 = filter(row -> row.tick == 1, df)
        pos = tick1[1, :positive_tests]
        neg = tick1[1, :negative_tests]
        tot = tick1[1, :total_tests]

        @test tot == pos + neg
        @test tot > 0
        @test 0 ≤ pos ≤ tot
        @test 0 ≤ neg ≤ tot
    end

    @testset "tick_serotests" begin
        # Scenario Setup
        seroprevalence_testing = Simulation()
        seroprevalence_test = SeroprevalenceTestType("Seroprevalence Test", pathogen(seroprevalence_testing), seroprevalence_testing)
        testing = IStrategy("Testing", seroprevalence_testing)
        add_measure!(testing, GEMS.Test("Test", seroprevalence_test))
        trigger = ITickTrigger(testing, switch_tick=Int16(1), interval=Int16(1))
        add_tick_trigger!(seroprevalence_testing, trigger)
        run!(seroprevalence_testing)
        rd = ResultData(seroprevalence_testing)
        st = tick_serotests(rd)
        # Tests
        @test isa(st, Dict)
        @test haskey(st, "Seroprevalence Test")

        df = st["Seroprevalence Test"]
        @test isa(df, DataFrame)
        expected_cols = ["tick", "true_positives", "false_positives", "true_negatives",
            "false_negatives", "positive_tests", "negative_tests", "total_tests"]
        @test all(col -> col in names(df), expected_cols)
        @test nrow(df) == 365
        @test all(df.total_tests .== df.positive_tests .+ df.negative_tests)
        @test all(df.false_positives .== 0)
        @test all(df.false_negatives .== 0)
    end

    @testset "Hashes" begin
        @test infections_hash(rd) isa Base.SHA1
        #@test data_hash(rd) isa Base.SHA1 # this somehow fails. Bug in ContentHashes?
        @test hashes(rd) == Dict()
    end

    @testset "Testing allempty and someempty with ResultData" begin
        f(rd) = get(rd.data, "test_key", [])
        rd = ResultData(pp)
        @test allempty(f, [rd])
        @test someempty(f, [rd])
    end


    @testset "Test obtain_fields" begin
        rd = ResultData(pp)
        @test_throws "Reconstruction failed. Essential dataframes missing!" GEMS.obtain_fields(rd, "DefaultResultData")
    end
end
