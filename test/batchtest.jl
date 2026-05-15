@testset "Batch" begin

    basefolder = dirname(dirname(pathof(GEMS)))

    @testset "Constructor" begin
        # keyword constructor creates correct number of configs
        kw_batch = Batch(n_runs = 3)
        @test length(simconfigs(kw_batch)) == 3

        # simargs are stored in configs
        kw_batch2 = Batch(n_runs = 2, label = "kw_test")
        @test all(cfg -> cfg.label == "kw_test", simconfigs(kw_batch2))

        # empty batch
        empty_batch = Batch(n_runs = 0)
        @test length(simconfigs(empty_batch)) == 0
    end

    @testset "SetOperations" begin
        b1 = Batch(n_runs = 2)
        b2 = Batch(n_runs = 3)
        b3 = Batch(n_runs = 4)

        # add! appends a config
        @test length(simconfigs(b1)) == 2
        add!((label = "extra",), b1)
        @test length(simconfigs(b1)) == 3

        # merge combines configs from multiple batches
        merged = merge(b2, b3)
        @test length(simconfigs(merged)) == 7

        # append! appends in-place
        b4 = Batch(n_runs = 2)
        b5 = Batch(n_runs = 3)
        append!(b4, b5)
        @test length(simconfigs(b4)) == 5
    end

    # small batch used for run and data tests
    batch5 = Batch(n_runs = 3)
    bP = process!(batch5)

    @testset "Run" begin
        @test n_runs(bP) == 3
        # confirm accumulators received 3 observations
        @test bP.total_infections.n == 3
    end

    @testset "BatchData" begin
        bd = BatchData(bP)

        @testset "BatchDataDefault" begin
            @test typeof(bd) == BatchData
            @test haskey(bd.data, "meta_data")
            @test haskey(bd.data, "system_data")
            @test haskey(bd.data, "sim_data")
            @test haskey(bd.data, "dataframes")
            @test !haskey(bd.data, "custom")
        end

        @testset "BatchDataMerge" begin
            # merge requires keep_rundata=true on both BatchData objects
            bd_a = BatchData(run!(Batch(n_runs = 3); keep_rundata = true); style = "DefaultBatchData")
            bd_b = BatchData(run!(Batch(n_runs = 3); keep_rundata = true); style = "DefaultBatchData")
            bd_merged = merge(bd_a, bd_b)
            @test length(runs(bd_merged)) == 6
        end

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
                            "number_of_runs" => n_runs(bP),
                        )
                    )
                    return new(funcs)
                end
            end
            custom_bd = BatchData(bP, style = "TestBatchData")
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

            # runs is nothing by default (keep_rundata=false)
            @test isnothing(runs(bd))
            @test bd |> number_of_runs != 0

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
            @test n_runs(bP) == 3
            @test bP |> total_infections |> length != 0
            @test bP |> attack_rate |> length != 0
            @test bP |> r0 |> length != 0
            @test bP |> total_quarantines |> length != 0
            @test bP |> tick_cases |> nrow != 0
            @test bP |> effectiveR |> nrow != 0
            @test bP |> cumulative_quarantines |> nrow != 0
            @test bP |> cumulative_disease_progressions |> length != 0
        end

        @testset "RepresentativeRun" begin
            bp_rep = run!(Batch(n_runs = 5); representative_by = pp -> nrow(infectionsDF(pp)))
            @test !isnothing(representative_run(bp_rep))
            @test typeof(representative_run(bp_rep)) == ResultData
        end
    end
end
