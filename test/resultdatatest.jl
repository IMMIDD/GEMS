@testset "Result Data" begin
    basefolder = dirname(dirname(pathof(GEMS)))

    popfile = "test/testdata/TestPop.csv"
    populationpath = joinpath(basefolder, popfile)

    confile = "test/testdata/TestConf.toml"
    configpath = joinpath(basefolder, confile)

    sim = test_sim(populationpath, configpath)
    run!(sim, with_progressbar = false)

    pp = sim |> PostProcessor

    @testset "ResultData Generation" begin 
        # Case 1 empty config
        @testset "Full ResultData" begin
            full_rd = ResultData(pp)
            @test isa(full_rd, ResultData)
        end
        # Use style
        @testset "ResultDataStyle" begin
            key_rd = ResultData(pp, style = "DefaultResultData")
            @test key_rd |> dataframes != Dict()
            @test key_rd |> infections != Dict()
            @test key_rd |> deaths != Dict()
            @test key_rd |> tick_deaths != Dict()
            @test key_rd |> final_tick != Dict()
            @test key_rd |> config_file != Dict()
            @test key_rd |> population_file != Dict()
            key_rd = ResultData(pp, style = "OptimisedResultData")
            mutable struct TestResultData <: ResultDataStyle
                data::Dict{Any, Any}
                function TestResultData(pP)
                    data = Dict("infections" => pP |> infectionsDF)
                    return new(data)
                end
            end
            key_rd = ResultData(pp, style = "TestResultData")
            @test key_rd |> model_size == "Not available!"
            @test key_rd.data["infections"] != Dict()
        end

    end
    @testset "ResultData Import" begin
        rd = ResultData(pp, style = "OptimisedResultData")
        exportJLD(rd,"tempdir")
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
        @test rd |> start_date |> Date == sim |> startdate
        @test rd |> final_tick == sim |> tick
        @test rd |> number_of_individuals == sim |> population |> size
        @test rd |> total_infections > 0
        # check if settting type names match
        @test (rd |> setting_data)[!, "setting_type"] |> sort == string.(sim |> settingscontainer |> settingtypes |> collect) |> sort
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
    
end
