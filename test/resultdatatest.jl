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

    @testset "more Tests" begin
        sim = Simulation(label="test")
        pp = sim |> PostProcessor
        rd = ResultData(pp)
        @test label(rd) == "test"

        @test region_info(rd) isa DataFrame && size(region_info(rd)) == (0, 3)

        sim = Simulation(pop_size=100)
        pp = sim |> PostProcessor
        rd = ResultData(pp)
        #@test population_size(rd) == 100 not available TODO ?
        @test vaccinations(rd) == Dict()
        @test tick_pooltests(rd) == Dict()
        @test time_to_detection(rd) isa DataFrame && size(time_to_detection(rd)) == (0, 0)
        @test tick_serial_intervals(rd) isa DataFrame && size(tick_serial_intervals(rd)) == (0, 0)
        @test hospital_df(rd) == Dict()
        @test tests(rd) isa DataFrame && size(tests(rd)) == (0, 17)
        @test customlogger(rd) isa DataFrame && size(customlogger(rd)) == (0, 1)
        @test hashes(rd) == Dict()
        #infections_hash(rd) TODO?
        #data_hash(rd) TODO?

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
