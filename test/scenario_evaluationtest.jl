@testset "Evaluation" begin

    # pluggable criteria: one numeric, one non-numeric
    infections = rd -> sum(total_infections(rd).total_infections)
    scenario_label = rd -> label(rd)
    criteria = (infections = infections, scenario_label = scenario_label)

    make_scenarios() = [
        Batch(n_runs = 3, pop_size = 1000, label = "baseline"),
        Batch(n_runs = 3, pop_size = 1000, label = "masks", setup = sim -> nothing)
    ]

    @testset "SummaryAndRuns" begin
        result = evaluate(make_scenarios(), criteria; seed = 1)

        @test result isa EvaluationResult

        # one row per scenario
        @test nrow(result.summary) == 2
        @test Set(result.summary.scenario) == Set(["baseline", "masks"])

        # numeric criterion aggregated with default mean + std
        @test "infections_mean" in names(result.summary)
        @test "infections_std" in names(result.summary)

        # per-run table: one row per run, scenario + run columns present
        @test result.runs isa DataFrame
        @test nrow(result.runs) == 6
        @test "scenario" in names(result.runs)
        @test "run" in names(result.runs)
        @test "infections" in names(result.runs)
        # run index resets per scenario
        @test sort(result.runs[result.runs.scenario .== "baseline", :run]) == [1, 2, 3]

        @test result.criteria == [:infections, :scenario_label]
    end

    @testset "PluggableAggregators" begin
        result = evaluate(make_scenarios(), (infections = infections,);
            aggregators = (mean = mean, median = median), seed = 1)
        @test "infections_mean" in names(result.summary)
        @test "infections_median" in names(result.summary)
        @test !("infections_std" in names(result.summary))
    end

    @testset "NonNumericCriterion" begin
        result = evaluate(make_scenarios(), criteria; seed = 1)
        # non-numeric criterion collapses to a single column (no _mean / _std)
        @test "scenario_label" in names(result.summary)
        @test !("scenario_label_mean" in names(result.summary))
        base_row = result.summary[result.summary.scenario .== "baseline", :]
        @test base_row.scenario_label[1] == "baseline"
    end

    @testset "KeepRuns" begin
        result = evaluate(make_scenarios(), criteria; keep_runs = false, seed = 1)
        @test result.runs === nothing
        # summary is still produced
        @test nrow(result.summary) == 2
    end

    @testset "KeepRundata" begin
        # default: no ResultData retained
        r_default = evaluate(make_scenarios(), criteria; seed = 1)
        @test r_default.rundata === nothing

        # opt-in: all runs retained
        r_kept = evaluate(make_scenarios(), criteria; keep_rundata = true, seed = 1)
        @test r_kept.rundata isa Vector{ResultData}
        @test length(r_kept.rundata) == 6
    end

    @testset "Reproducibility" begin
        r1 = evaluate(make_scenarios(), criteria; seed = 123)
        r2 = evaluate(make_scenarios(), criteria; seed = 123)
        @test isequal(r1.summary, r2.summary)
        @test isequal(r1.runs, r2.runs)
    end

    @testset "SingleBatch" begin
        # a lone Batch (not wrapped in a vector) is accepted
        result = evaluate(Batch(n_runs = 2, pop_size = 1000, label = "solo"), criteria; seed = 1)
        @test nrow(result.summary) == 1
        @test result.summary.scenario[1] == "solo"
    end

    @testset "Printing" begin
        result = evaluate(make_scenarios(), criteria; seed = 1)
        @test !isempty(@capture_out show(result))
    end
end
