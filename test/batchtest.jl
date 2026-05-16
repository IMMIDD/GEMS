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
            # multi-column accessors return Dict
            @test bd |> tick_cases |> length != 0
            @test bd |> effectiveR |> length != 0
            @test bd |> tests |> length >= 0
            @test bd |> cumulative_quarantines |> length != 0
            @test bd |> cumulative_disease_progressions |> length != 0
            # 6 new dataframe getters (may be empty when model features unused)
            @test bd |> dark_figure isa DataFrame
            @test bd |> generation_times isa DataFrame
            @test bd |> hospitalizations isa Dict
            @test bd |> observed_R isa Dict
            @test bd |> pool_tests isa Dict
            @test bd |> sero_tests isa Dict
            # scalar fields
            @test bd |> total_detected_cases |> length != 0
            @test bd |> detection_rate |> length != 0
            @test seed(bd) == seed(bP)
            @test isnothing(runs(bd))
            @test !isnothing(median_run(bd))
            @test typeof(median_run(bd)) == ResultData

            @test bd |> id |> length != 0
        end

        @testset "BatchProcessorFunctions" begin
            @test n_runs(bP) == 3
            @test bP |> total_infections |> length != 0
            @test bP |> attack_rate |> length != 0
            @test bP |> r0 |> length != 0
            @test bP |> total_quarantines |> length != 0
            @test bP |> tick_cases |> length != 0
            @test bP |> effectiveR |> length != 0
            @test bP |> cumulative_quarantines |> length != 0
            @test bP |> cumulative_disease_progressions |> length != 0
        end

        @testset "RepresentativeRun" begin
            criterion = pp -> nrow(infectionsDF(pp))
            fixed_seed = 1234

            bp = process!(Batch(n_runs = 5); seed = fixed_seed, median_by = criterion)
            @test !isnothing(median_run(bp))
            @test typeof(median_run(bp)) == ResultData

            # Re-derive per-simulation seeds the same way process! does
            sim_seeds = let rng = Xoshiro(Int64(fixed_seed))
                [gems_rand(rng, 0:typemax(Int64)) for _ in 1:5]
            end

            # Collect criterion values by replaying each simulation (bit-identical via seed)
            criteria = [Float64(criterion(PostProcessor(run!(Simulation(seed = s))))) for s in sim_seeds]

            final_median = median(criteria)
            best_idx = argmin(abs(v - final_median) for v in criteria)

            # The representative run is the bit-identical replay of the median-closest simulation,
            # so its total infections must equal that simulation's criterion value
            @test total_infections(median_run(bp)) == Int(criteria[best_idx])
        end

        @testset "RepresentativeRunMultiLabel" begin
            baseline = Batch(n_runs = 5, transmission_rate = 0.2, label = "Baseline")
            masks = Batch(n_runs = 5, transmission_rate = 0.15, label = "Mask Wearing")
            bp = process!(merge(baseline, masks))

            # no global representative for multi-label batches
            @test isnothing(median_run(bp))

            # each label has its own representative
            @test !isnothing(bp.per_label["Baseline"].median_run)
            @test !isnothing(bp.per_label["Mask Wearing"].median_run)
            @test typeof(bp.per_label["Baseline"].median_run) == ResultData
            @test typeof(bp.per_label["Mask Wearing"].median_run) == ResultData

            # test median_runs
            bp_single = process!(Batch(n_runs = 3))
            bd_single = BatchData(bp_single)
            m_single = median_runs(bd_single)
            
            @test m_single isa Vector
            @test length(m_single) == 1
            @test typeof(m_single[1]) == ResultData

            b1 = Batch(n_runs = 3, label = "Scenario A")
            b2 = Batch(n_runs = 3, label = "Scenario B")
            bp_multi = process!(merge(b1, b2))
            bd_multi = BatchData(bp_multi)
            m_multi = median_runs(bd_multi)
            
            @test m_multi isa Vector
            @test length(m_multi) == 2
            @test all(x -> typeof(x) == ResultData, m_multi)

            bp_disabled = process!(Batch(n_runs = 3); median_by = nothing)
            bd_disabled = BatchData(bp_disabled)
            m_disabled = median_runs(bd_disabled)
            
            @test m_disabled isa Vector
            @test isempty(m_disabled)
        end

        @testset "Seed" begin
            bp1 = process!(Batch(n_runs = 3); seed = 42)
            bp2 = process!(Batch(n_runs = 3); seed = 42)
            @test seed(bp1) == 42
            @test total_infections(bp1)["mean"] == total_infections(bp2)["mean"]
        end

        @testset "EmptyBatch" begin
            bp = process!(Batch(n_runs = 0))
            @test n_runs(bp) == 0
            @test isnothing(median_run(bp))
        end

        @testset "DisabledRepresentative" begin
            bp = process!(Batch(n_runs = 3); median_by = nothing)
            @test isnothing(median_run(bp))
        end

        @testset "WelfordCorrectness" begin
            # Welford mean and std should match manual computation
            bp = process!(Batch(n_runs = 5); seed = 7)
            agg = total_infections(bp)
            @test agg["mean"] isa Float64
            @test agg["std"] >= 0.0
            @test agg["min"] <= agg["mean"] <= agg["max"]
            @test agg["lower_95"] <= agg["mean"] <= agg["upper_95"]
        end

        @testset "MultiColumnAccessors" begin
            bp = process!(Batch(n_runs = 3); seed = 8)
            # tick_cases, effectiveR, cumulative_quarantines now return Dict
            tc = tick_cases(bp)
            @test tc isa Dict
            @test haskey(tc, "exposed_cnt")
            @test haskey(tc, "dead_cnt")
            @test nrow(tc["exposed_cnt"]) > 0

            er = effectiveR(bp)
            @test er isa Dict
            @test haskey(er, "rolling_R")

            cq = cumulative_quarantines(bp)
            @test cq isa Dict
            @test haskey(cq, "quarantined")
        end

        @testset "NoRateColumnsInTests" begin
            # positive_rate and rolling_positive_rate should not be accumulated
            bp = process!(Batch(n_runs = 3); seed = 9)
            t = tests(bp)
            for (_, col_dict) in t
                @test !haskey(col_dict, "positive_rate")
                @test !haskey(col_dict, "rolling_positive_rate")
            end
        end

        @testset "NewScalarAccessors" begin
            bp = process!(Batch(n_runs = 3); seed = 10)
            bd = BatchData(bp)
            @test seed(bp) == 10
            @test seed(bd) == 10
            @test tick_unit(bp) isa String
            @test total_detected_cases(bp) isa Dict
            @test detection_rate(bp) isa Dict
            @test detection_rate(bp)["mean"] >= 0.0
        end

        @testset "MultiLabelAccumulators" begin
            b1 = Batch(n_runs = 5, transmission_rate = 0.05, label = "Low")
            b2 = Batch(n_runs = 5, transmission_rate = 0.5, label = "High")
            bp = process!(merge(b1, b2); seed = 11)
            # per-label accumulators should differ between the two scenarios
            @test haskey(bp.per_label, "Low")
            @test haskey(bp.per_label, "High")
            low_inf = total_infections(bp.per_label["Low"])["mean"]
            high_inf = total_infections(bp.per_label["High"])["mean"]
            @test low_inf < high_inf

            # per_label(bd) exposes the per-label data through BatchData
            bd = BatchData(bp)
            pl = per_label(bd)
            @test haskey(pl, "Low")
            @test haskey(pl, "High")
            @test haskey(pl["Low"], "tick_cases")
            @test haskey(pl["Low"], "effectiveR")
            @test haskey(pl["Low"], "median_run")
            @test !isnothing(pl["Low"]["median_run"])
            @test !isnothing(pl["High"]["median_run"])
        end

        @testset "TotalTestsMultiType" begin
            # directly insert fake per-type test data to exercise the multi-type branch of generate(TotalTests(), bd::BatchData)
            bp_tests = BatchProcessor()
            for testtype in ["PCR", "Antigen"]
                bp_tests.tests[testtype] = Dict{String, Dict{Int, WelfordState}}()
                for col in ["total_tests", "positive_tests", "negative_tests"]
                    col_accum = Dict{Int, WelfordState}()
                    for tick in 1:5
                        s = WelfordState()
                        welford_update!(s, Float64(tick))
                        col_accum[tick] = s
                    end
                    bp_tests.tests[testtype][col] = col_accum
                end
            end
            bd_tests = BatchData(bp_tests)
            @test tests(bd_tests) isa Dict
            @test haskey(tests(bd_tests), "PCR")
            @test haskey(tests(bd_tests), "Antigen")
        end

        @testset "CustomLogger" begin
            cl = CustomLogger(infected = sim -> count(infected, sim |> population))
            bp = process!(Batch(n_runs = 3); customlogger = cl, keep_rundata = true)
            # each stored ResultData should have custom logger data
            for rd in rundata(bp)
                cl_data = customlogger(rd)
                @test cl_data isa DataFrame
                @test nrow(cl_data) > 0
            end
            # the logger passed to process! must not be mutated (data isolated per run)
            @test nrow(dataframe(cl)) == 0
        end
    end

    @testset "Printing" begin
        @test !isempty(@capture_out show(batch5))

        bd = BatchData(bP)
        @test !isempty(@capture_out info(bd))
        @test !isempty(@capture_out show(bd))
    end
end
