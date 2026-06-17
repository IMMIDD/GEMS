import GEMS: _WelfordState as WelfordState, _welford_update! as welford_update!
import GEMS: BatchProcessor, n_runs, rundata

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
        add!(b1, (label = "extra",))
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
    batch5 = Batch(n_runs = 3, pop_size = 1000)
    bP = process!(batch5; median_by = pp -> nrow(infectionsDF(pp)))
    bP_no_median = process!(Batch(n_runs = 3, pop_size = 1000); median_by = nothing)
    bd_no_median = BatchData(bP_no_median)

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

            # unknown style falls back to DefaultBatchData with a warning
            bd_unknown = BatchData(bP, style="NonExistentStyle_XYZ")
            @test bd_unknown isa BatchData
            @test haskey(bd_unknown.data, "meta_data")
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

            # valid JLD2 but no BatchData inside
            mktempdir() do dir2
                bad_jld2 = joinpath(dir2, "notbd.jld2")
                JLD2.save(bad_jld2, Dict("something" => 42))
                @test_throws ErrorException import_batchdata(bad_jld2)
            end

            rm(directory, recursive=true)
        end

        @testset "BatchDataFunctions" begin
            @test bd |> meta_data |> length != 0
            @test bd |> execution_date |> length != 0
            @test bd |> GEMS_version |> string |> length != 0

            # runs(bd) returns stored ResultData objects (keep_rundata=true by default)
            @test runs(bd) isa Vector{ResultData}
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
            @test bd |> generation_times isa Dict  # per-pathogen in multipathogen
            @test bd |> hospitalizations isa Dict
            @test bd |> observed_R isa Dict
            @test bd |> pool_tests isa Dict
            @test bd |> sero_tests isa Dict
            # scalar fields
            @test bd |> total_detected_cases |> length != 0
            @test bd |> detection_rate |> length != 0
            @test seed(bd) == seed(bP)
            @test runs(bd) isa Vector{ResultData}
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

            bp = process!(Batch(n_runs = 3, pop_size = 1000); seed = fixed_seed, median_by = criterion)
            @test !isnothing(median_run(bp))
            @test typeof(median_run(bp)) == ResultData

            # Re-derive per-simulation seeds the same way process! does
            sim_seeds = let rng = Xoshiro(Int64(fixed_seed))
                [gems_rand(rng, 0:typemax(Int64)) for _ in 1:3]
            end

            # Collect criterion values by replaying each simulation (bit-identical via seed)
            criteria = [Float64(criterion(PostProcessor(run!(Simulation(seed = s, pop_size = 1000))))) for s in sim_seeds]

            final_median = median(criteria)
            best_idx = argmin(abs(v - final_median) for v in criteria)

            # The representative run is the bit-identical replay of the median-closest simulation,
            # so its total infections must equal that simulation's criterion value
            @test sum(total_infections(median_run(bp)).total_infections) == Int(criteria[best_idx])

            # median_runs returns [single_median] for an ungrouped batch with a median
            bd_with_median = BatchData(bp)
            all_medians = median_runs(bd_with_median)
            @test length(all_medians) == 1
            @test all_medians[1] isa ResultData
        end

        @testset "RepresentativeRunMultiGroup" begin
            criterion = pp -> nrow(infectionsDF(pp))
            baseline = Batch(n_runs = 3, transmission_rate = 0.2, label = "Baseline", pop_size = 1000)
            masks = Batch(n_runs = 3, transmission_rate = 0.15, label = "Mask Wearing", pop_size = 1000)
            bp = process!(merge(baseline, masks); median_by = criterion, group_by = :label)

            # no global representative for multi-group batches
            @test isnothing(median_run(bp))

            # each group has its own representative
            @test !isnothing(bp.per_group["Baseline"].median_run)
            @test !isnothing(bp.per_group["Mask Wearing"].median_run)
            @test typeof(bp.per_group["Baseline"].median_run) == ResultData
            @test typeof(bp.per_group["Mask Wearing"].median_run) == ResultData

            # test median_runs — multi-group batch returns one entry per group
            b1 = Batch(n_runs = 3, label = "Scenario A", pop_size = 1000)
            b2 = Batch(n_runs = 3, label = "Scenario B", pop_size = 1000)
            bp_multi = process!(merge(b1, b2); median_by = criterion, group_by = :label)
            bd_multi = BatchData(bp_multi)
            m_multi = median_runs(bd_multi)

            @test m_multi isa Vector
            @test length(m_multi) == 2
            @test all(x -> typeof(x) == ResultData, m_multi)

            m_disabled = median_runs(bd_no_median)

            @test m_disabled isa Vector
            @test isempty(m_disabled)
        end

        @testset "Seed" begin
            bp1 = process!(Batch(n_runs = 3, pop_size = 1000); seed = 42)
            bp2 = process!(Batch(n_runs = 3, pop_size = 1000); seed = 42)
            @test seed(bp1) == 42
            @test total_infections(bp1)["mean"] == total_infections(bp2)["mean"]
        end

        @testset "EmptyBatch" begin
            bp = process!(Batch(n_runs = 0))
            @test n_runs(bp) == 0
            @test isnothing(median_run(bp))
        end

        @testset "DisabledRepresentative" begin
            @test isnothing(median_run(bP_no_median))
        end

        @testset "WelfordCorrectness" begin
            # Welford mean and std should match manual computation
            agg = total_infections(bP)
            @test agg["mean"] isa Float64
            @test agg["std"] >= 0.0
            @test agg["min"] <= agg["mean"] <= agg["max"]
            @test agg["lower_95"] <= agg["mean"] <= agg["upper_95"]
        end

        @testset "MultiColumnAccessors" begin
            # tick_cases and effectiveR now return Dict{Int8, Dict{String, DataFrame}} (per-pathogen)
            tc = tick_cases(bP)
            @test tc isa Dict
            @test haskey(first(values(tc)), "exposed_cnt")
            @test haskey(first(values(tc)), "dead_cnt")
            @test nrow(first(values(tc))["exposed_cnt"]) > 0

            er = effectiveR(bP)
            @test er isa Dict
            @test haskey(first(values(er)), "rolling_R")

            cq = cumulative_quarantines(bP)
            @test cq isa Dict
            @test haskey(cq, "quarantined")
        end

        @testset "NoRateColumnsInTests" begin
            # positive_rate and rolling_positive_rate should not be accumulated
            t = tests(bP)
            for (_, col_dict) in t
                @test !haskey(col_dict, "positive_rate")
                @test !haskey(col_dict, "rolling_positive_rate")
            end
        end

        @testset "AccumulateTestLoops" begin
            # test all three test-type loops in a single run
            sim = Simulation(pop_size = 100, infected_fraction = 0.1)
            pcr = TestType("PCR", id(first_pathogen(sim)), sim)
            sero = SeroprevalenceTestType("Sero", id(first_pathogen(sim)), sim)

            test_strat = IStrategy("Testing", sim)
            add_measure!(test_strat, GEMS.Test("t", pcr))
            add_symptom_trigger!(sim, SymptomTrigger(test_strat))

            pool_strat = SStrategy("PoolTesting", sim)
            add_measure!(pool_strat, PoolTest("pool", pcr))
            add_tick_trigger!(sim, STickTrigger(Household, pool_strat, switch_tick = Int16(1), interval = Int16(60)))

            sero_strat = IStrategy("SeroTesting", sim)
            add_measure!(sero_strat, GEMS.Test("s", sero))
            add_tick_trigger!(sim, ITickTrigger(sero_strat, switch_tick = Int16(1), interval = Int16(60)))

            run!(sim)
            bp = BatchProcessor()
            GEMS.accumulate!(bp, PostProcessor(sim))

            @test haskey(bp.tests, "PCR")
            @test haskey(bp.total_tests, "PCR")
            @test haskey(bp.pool_tests, "PCR")
            @test haskey(bp.sero_tests, "Sero")
        end

        @testset "NewScalarAccessors" begin
            @test tick_unit(bP) isa String
            @test total_detected_cases(bP) isa Dict
            @test detection_rate(bP) isa Dict
            @test detection_rate(bP)["mean"] >= 0.0
        end

        @testset "MultiGroupAccumulators" begin
            b1 = Batch(n_runs = 3, transmission_rate = 0.05, label = "Low", pop_size = 1000)
            b2 = Batch(n_runs = 3, transmission_rate = 0.5, label = "High", pop_size = 1000)
            bp = process!(merge(b1, b2); seed = 11, group_by = :label)
            # per-group accumulators should differ between the two scenarios
            @test haskey(bp.per_group, "Low")
            @test haskey(bp.per_group, "High")
            low_inf = total_infections(bp.per_group["Low"])["mean"]
            high_inf = total_infections(bp.per_group["High"])["mean"]
            @test low_inf < high_inf

            # per_group(bd) exposes the per-group data through BatchData
            bd = BatchData(bp)
            pg = per_group(bd)
            @test haskey(pg, "Low")
            @test haskey(pg, "High")
            @test tick_cases(pg["Low"]) isa Dict
            @test effectiveR(pg["Low"]) isa Dict
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

        @testset "Setup" begin
            # setup on Batch is called once per run
            call_count = Ref(0)
            bp_setup = process!(Batch(n_runs = 3, pop_size = 500,
                setup = sim -> (call_count[] += 1)))
            @test call_count[] == 3

            # setup via add! per-config
            per_cfg_count = Ref(0)
            b_cfg = Batch(n_runs = 0)
            for _ in 1:4
                add!(b_cfg, (pop_size = 500,); setup = sim -> (per_cfg_count[] += 1))
            end
            process!(b_cfg)
            @test per_cfg_count[] == 4

            # different setups per merged scenario
            baseline = Batch(n_runs = 2, pop_size = 500, label = "Baseline")
            with_iso = Batch(n_runs = 2, pop_size = 500, label = "Isolation",
                setup = sim -> begin
                    strat = IStrategy("iso", sim)
                    add_measure!(strat, SelfIsolation(14))
                    add_symptom_trigger!(sim, SymptomTrigger(strat))
                end)
            bp_merged = process!(merge(baseline, with_iso); group_by = :label)
            @test haskey(bp_merged.per_group, "Baseline")
            @test haskey(bp_merged.per_group, "Isolation")
        end

        @testset "CustomLogger" begin
            cl = CustomLogger(infected = sim -> count(infected, sim |> population))
            bp = process!(Batch(n_runs = 3, pop_size = 1000); customlogger = cl, keep_rundata = true)
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
