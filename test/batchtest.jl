@testset "Batch" begin
    
    basefolder = dirname(dirname(pathof(GEMS)))
    pop_file = "test/testdata/TestPop.csv"
    pop_path = joinpath(basefolder, pop_file)

    #initialising batches
    sims1 = Simulation[Simulation(label = "batch_test_" * string(i)) for i in 1:2]
    batch1 = Batch(sims1...)

    sims2 = Simulation[Simulation(label = "batch_test_" * string(i)) for i in 3:7]
    batch2 = Batch(sims2...)

    sims3 = Simulation[Simulation(label = "batch_test_" * string(i)) for i in 7:9]
    batch3 = Batch(sims3...)

    sims4 = Simulation[Simulation(label = "batch_test_" * string(i)) for i in 10:12]
    batch4 = Batch(sims4...)

    @testset "Constructor" begin
        @test sims1 == simulations(batch1)
        @test sims2 == simulations(batch2)
        @test sims3 == simulations(batch3)
        @test sims4 == simulations(batch4)
    end


    @testset "SetOperations" begin
        #test add
        @test length(simulations(batch1)) == 2

        sim3 = Simulation(label = "batch_test_3")
        add!(sim3, batch1)

        @test_throws Any add!(batch3, simulations(batch3)[1])
        @test length(simulations(batch1)) == 3

        #test remove
        remove!(simulations(batch2)[5], batch2)
        remove!(simulations(batch2)[1], batch2)

        @test length(simulations(batch2)) == 3

        #test merge
        batch2 = merge(batch2, batch3, batch4)

        @test length(simulations(batch2)) == 9

        #test append
        append!(batch1, batch2)

        @test length(simulations(batch1)) == 12

        for i in 1:12
            @test label(simulations(batch1)[i]) == "batch_test_" * string(i)
        end

    end

    @testset "Logger" begin
        cl = CustomLogger(infected = sim -> count(infected, sim |> population))
        customlogger!(batch1, cl)

        @test all(x -> (size(dataframe(cl), 2) == 2), simulations(batch1))
        logger_ids = [objectid(customlogger(sim)) for sim in simulations(batch1)]
        @test length(logger_ids) == length(unique(logger_ids))
    end

    sims5 = Simulation[Simulation() for i in 1:3]
    batch5 = Batch(sims5...)
    @testset "Run" begin
        run!(batch5)

        for sim in simulations(batch5)
            @test tick(sim) == 365
        end
    end


    @testset "BatchData" begin
        bP = BatchProcessor(batch5)
        bd = BatchData(bP)
        # Test the default batch data generation, i.e., all fields are generated
        @testset "BatchDataDefault" begin
            @test typeof(bd) == BatchData
            @test haskey(bd.data, "meta_data")
            @test haskey(bd.data, "system_data")
            @test haskey(bd.data, "sim_data")
            @test haskey(bd.data, "dataframes")
            @test !haskey(bd.data, "custom")
        end

        @testset "BatchDataMerge" begin
            bd2 = BatchData(batch5)
            bd2 = merge(bd, bd2)
            @test length(runs(bd2)) == 6
        end

        # Test the creation of custom batchdata using the configfile including a custom field 
        # and custom chunk size
        @testset "BatchDataCustom" begin
            mutable struct TestBatchData <: BatchDataStyle
                data::Dict{String, Any}
                function TestBatchData(bP::BatchProcessor)
                    funcs = Dict(
                        "meta_data" =>
                        Dict(
                            "execution_date" => Dates.format(now(), "U dd, yyyy - HH:MM")
                        ),
                        "sim_data" =>
                        Dict(
                            "number_of_runs" => bP |> run_ids |> length,
                        )
                    )
                    
                    return new(funcs)
                end
            end
            custom_bd = BatchData(batch5, style = "TestBatchData")
            @test typeof(custom_bd) == BatchData
            @test haskey(custom_bd.data, "meta_data")
            @test haskey(custom_bd.data, "sim_data")
            @test !haskey(custom_bd.data, "dataframes")
            @test custom_bd |> execution_date |> length != 0
            @test custom_bd |> number_of_runs |> length != 0
        end

        @testset "File Handeling" begin
            directory = basefolder * "/test_" * string(datetime2unix(now()))
            mkpath(directory)
            batch_dir = joinpath(directory, "test")
            exportJSON(bd, batch_dir)
            @test isfile(joinpath(batch_dir, "batchdata.json"))
            exportJLD(bd, batch_dir)
            @test isfile(joinpath(batch_dir, "batchdata.jld2"))
            bd_file = import_batchdata(joinpath(batch_dir, "batchdata.jld2"))
            @test typeof(bd_file) == BatchData
            @test_throws Any import_batchdata(joinpath(batch_dir, "test.txt"))
            rm(directory, recursive=true)
        end

        @testset "BatchDataFunctions" begin
            @test bd |> meta_data |> length != 0
            @test bd |> execution_date |> length != 0
            @test bd |> GEMS_version |> string |> length != 0

            @test bd |> runs |> length != 0
            @test bd |> number_of_runs |> length != 0

            @test bd |> sim_data |> length != 0

            @test bd |> total_infections |> length != 0
            @test bd |> total_tests |> length >= 0
            @test bd |> attack_rate |> length != 0
            @test bd |> total_quarantines |> length != 0

            @test bd |> system_data |> length != 0
            @test bd |> kernel |> length != 0
            @test bd |> julia_version |> length != 0
            @test bd |> word_size |> length != 0
            @test bd |> threads |> length != 0
            @test bd |> cpu_data |> length != 0
            @test bd |> total_mem_size |> length != 0
            @test bd |> free_mem_size |> length != 0
            @test bd |> git_repo |> length != 0
            @test bd |> git_branch |> length != 0
            @test bd |> git_commit |> length != 0

            @test bd |> dataframes |> length != 0
            @test bd |> tick_cases |> nrow != 0
            @test bd |> effectiveR |> nrow != 0
            @test bd |> tests |> length >= 0
            @test bd |> cumulative_quarantines |> nrow != 0
            @test bd |> cumulative_disease_progressions |> length != 0

            @test bd |> id |> length != 0
        end

        @testset "BatchProcessorFunctions" begin
            # Most function are already being called during testset 'BatchDataFunctions'
            @test bP |> config_files |> length != 0
            @test bP |> population_files |> length != 0
    
            @test bP |> tick_unit |> length != 0
            @test bP |> start_conditions |> length != 0
            @test bP |> stop_criteria |> length != 0
            @test bP |> number_of_individuals |> length != 0
            @test bP |> pathogens |> length != 0
            @test bP |> pathogens_by_name |> length != 0
            @test bP |> settingdata |> length != 0
    
            @test bP |> strategies |> length != 0
            @test bP |> symptom_triggers |> length != 0
            @test bP |> testtypes |> length != 0
            
            @test bP |> x -> setting_age_contacts(x, Household) |> length != 0
            @test bP |> x -> setting_age_contacts(x, GlobalSetting) |> length != 0
            @test bP |> population_pyramid |> length != 0
        end
    end
end
