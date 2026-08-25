@testset "Evaluation" begin

    infections = rd -> sum(total_infections(rd).total_infections)
    scenario_label = rd -> label(rd)
    nr = rd -> number_of_individuals(rd)
    criteria = (infections = infections, scenario_label = scenario_label, nr = nr, const_val = rd -> 42)

    # tiny, short sims: these tests exercise the evaluate harness, not epidemic dynamics.
    # infected_fraction explicit — the default config seeds 0.001, ≈ 0 infections at this pop.
    fast(; kw...) = Batch(; pop_size = 100, infected_fraction = 0.1, stop_criterion = TimesUp(limit = 20), kw...)
    make_scenarios() = [fast(n_runs = 2, label = "baseline"),
                        fast(n_runs = 2, label = "masks", setup = sim -> nothing)]

    strata_fn = rd -> (inf = infections(rd); DataFrame(age = [1, 2], sex = [1, 1], inf = [inf ÷ 2, inf - inf ÷ 2]))

    # ONE scalar+stratified evaluation shared by every read-only testset below (4 sims)
    base = evaluate(make_scenarios(), criteria;
        stratified = strata_fn, stratified_by = [:age, :sex], keep_rundata = true, seed = 1)

    @testset "SummaryAndRuns" begin
        @test base isa EvaluationResult
        @test nrow(base.summary) == 2
        @test Set(base.summary.scenario) == Set(["baseline", "masks"])
        @test issubset(["infections_mean", "infections_std"], names(base.summary))
        @test base.runs isa DataFrame
        @test nrow(base.runs) == 4
        @test issubset(["scenario", "run", "infections"], names(base.runs))
        @test sort(base.runs[base.runs.scenario .== "baseline", :run]) == [1, 2]
        @test base.criteria == [:infections, :scenario_label, :nr, :const_val]
    end

    @testset "NonNumericCriterion" begin
        # scenario_label is constant per scenario -> kept as a single column (no _mean / _std)
        @test "scenario_label" in names(base.summary)
        @test !("scenario_label_mean" in names(base.summary))
        @test base.summary[base.summary.scenario .== "baseline", :scenario_label][1] == "baseline"
    end

    @testset "ConstantNumericAggregatesByDefault" begin
        # numeric criteria always aggregate, even when constant across runs (fixed population,
        # `const_val` = 42) — the summary schema is data-independent
        @test "nr_mean" in names(base.summary)
        @test !("nr" in names(base.summary))
        @test "const_val_mean" in names(base.summary)
    end

    @testset "KeepRundata" begin
        @test base.rundata isa Vector{ResultData}
        @test length(base.rundata) == 4
    end

    @testset "Printing" begin
        @test !isempty(@capture_out show(base))
    end

    @testset "StratifiedSummary" begin
        @test nrow(base.stratified) == 4     # 2 scenarios × 2 strata
        @test issubset(["scenario", "age", "sex", "inf_mean", "inf_std"], names(base.stratified))
        @test nrow(base.strata_runs) == 8    # 2 scenarios × 2 runs × 2 strata
        @test issubset(["scenario", "run", "age", "sex", "inf"], names(base.strata_runs))
    end

    @testset "CanonicalStrataOrder" begin
        @test isequal(base.stratified, sort(base.stratified, [:scenario, :age, :sex]))
    end

    @testset "KeepRunsRundataSingleBatch" begin
        # lone Batch accepted; keep_runs = false drops runs; keep_rundata defaults off
        r = evaluate(fast(n_runs = 1, label = "solo"), criteria; keep_runs = false, seed = 1)
        @test nrow(r.summary) == 1
        @test r.summary.scenario[1] == "solo"
        @test r.runs === nothing
        @test r.rundata === nothing
    end

    @testset "Reproducibility" begin
        r1 = evaluate(fast(n_runs = 2, label = "s"), (infections = infections,); seed = 7)
        r2 = evaluate(fast(n_runs = 2, label = "s"), (infections = infections,); seed = 7)
        @test isequal(r1.summary, r2.summary)
        @test isequal(r1.runs, r2.runs)
    end

    @testset "PluggableAggregators" begin
        r = evaluate(fast(n_runs = 1, label = "s"), (infections = infections,);
            aggregators = (mean = mean, median = median), seed = 1)
        @test issubset(["infections_mean", "infections_median"], names(r.summary))
        @test !("infections_std" in names(r.summary))
    end

    @testset "PerCriterionAggregators" begin
        # per-criterion map: `nr` gets median only, everything else the :default set
        r = evaluate(fast(n_runs = 1, label = "s"), (infections = infections, nr = nr);
            aggregators = (default = (mean = mean, std = std), nr = (median = median,)), seed = 1)
        @test issubset(["infections_mean", "nr_median"], names(r.summary))
        @test !("nr_mean" in names(r.summary))
    end

    @testset "ConstantsKwargKeepsVerbatim" begin
        r = evaluate(fast(n_runs = 1, label = "s"), (infections = infections, nr = nr);
            constants = (:nr,), seed = 1)
        @test "nr" in names(r.summary)
        @test !("nr_mean" in names(r.summary))
        @test eltype(r.summary.nr) <: Integer
        @test "infections_mean" in names(r.summary)
    end

    @testset "UnsummarizableCriterionOmitted" begin
        # a non-scalar criterion can't be reduced: omitted (with a warning), kept in runs
        crit = (frame = rd -> total_infections(rd), infections = infections)
        r = @test_logs (:warn,) match_mode = :any evaluate(fast(n_runs = 1, label = "s"), crit; seed = 1)
        @test !("frame" in names(r.summary))
        @test "frame" in names(r.runs)
        @test "infections_mean" in names(r.summary)
    end

    @testset "SingleRunNonNumericDropped" begin
        # at n_runs = 1 constancy can't be confirmed, so an undeclared non-numeric is dropped;
        # declaring keeps it
        b = fast(n_runs = 1, label = "s")
        r = @test_logs (:warn,) match_mode = :any evaluate(b, criteria; seed = 1)
        @test "infections_mean" in names(r.summary)
        @test !("scenario_label" in names(r.summary))
        @test "scenario_label" in names(r.runs)
        @test "scenario_label" in names(evaluate(b, criteria; constants = (:scenario_label,), seed = 1).summary)
    end

    @testset "SummaryUnaffectedByStrata" begin
        b = fast(n_runs = 1, label = "s")
        a = evaluate(b, (infections = infections,); seed = 1)
        c = evaluate(b, (infections = infections,);
            stratified = rd -> DataFrame(g = [1], inf = [1]), stratified_by = [:g], seed = 1)
        @test isequal(a.summary, c.summary)
    end

    @testset "AggregatorValidationThrows" begin
        # all fail before running the batch
        @test_throws ArgumentError evaluate(make_scenarios(), (infections = infections,);
            aggregators = (infections = mean,), seed = 1)                                    # ambiguous
        @test_throws ArgumentError evaluate(make_scenarios(), (infections = infections,);
            aggregators = (infectons = (median = median,), default = (mean = mean,)), seed = 1)  # unknown name
        @test_throws ArgumentError evaluate(make_scenarios(), (infections = infections, nr = nr);
            aggregators = (infections = (median = median,), nr = mean), seed = 1)            # malformed
    end

    @testset "ConstantsThrows" begin
        @test_throws ArgumentError evaluate(make_scenarios(), (infections = infections,);
            constants = (:typo,), seed = 1)                                    # unknown name, pre-batch
        # a criterion that varies across runs, declared constant -> throws (deterministic counter)
        varying = let c = Ref(0); _ -> (c[] += 1) end
        @test_throws ArgumentError evaluate(fast(n_runs = 2, label = "s"), (v = varying,);
            constants = (:v,), seed = 1)
    end

    @testset "StrataOnlyConstant" begin
        # `nr` is a strata-only column (not a scalar criterion), declared constant + kept verbatim
        fn = rd -> DataFrame(age = [1, 2], sex = [1, 1], inf = [infections(rd), 0], nr = [100, 100])
        r = evaluate(fast(n_runs = 1, label = "s"), (infections = infections,);
            stratified = fn, stratified_by = [:age, :sex], constants = (:nr,), seed = 1)
        @test "nr" in names(r.stratified)
        @test !("nr_mean" in names(r.stratified))
    end

    @testset "RaggedStrataWarn" begin
        # first run omits age 2; that stratum then appears in only 1 of 2 runs -> warn
        call = Ref(0)
        ragged = rd -> (call[] += 1; inf = infections(rd);
            call[] == 1 ? DataFrame(age = [1], sex = [1], inf = [inf]) :
                          DataFrame(age = [1, 2], sex = [1, 1], inf = [inf ÷ 2, inf - inf ÷ 2]))
        r = @test_logs (:warn,) match_mode = :any evaluate(fast(n_runs = 2, label = "s"),
            (infections = infections,); stratified = ragged, stratified_by = [:age, :sex], seed = 1)
        @test 2 in r.stratified.age   # still present despite being ragged
    end

    @testset "StrataRawRefPinned" begin
        # a non-scalar strata column is dropped; the warning must point at strata_runs
        fn = rd -> DataFrame(age = [1, 2], sex = [1, 1], frame = [DataFrame(v = [1]), DataFrame(v = [1])])
        @test_logs (:warn, r"strata_runs") match_mode = :any evaluate(fast(n_runs = 1, label = "s"),
            (infections = infections,); stratified = fn, stratified_by = [:age, :sex], seed = 1)
    end

    @testset "StrataValidationThrows" begin
        crit = (infections = infections,)
        small() = fast(n_runs = 1, label = "s")
        # pre-batch: stratified / stratified_by must be paired
        @test_throws ArgumentError evaluate(make_scenarios(), crit; stratified_by = [:age], seed = 1)
        @test_throws ArgumentError evaluate(make_scenarios(), crit; stratified = strata_fn, seed = 1)
        # after run 1: missing key column, reserved column, duplicate key
        @test_throws ArgumentError evaluate(small(), crit;
            stratified = rd -> DataFrame(age = [1], inf = [1]), stratified_by = [:age, :sex], seed = 1)
        @test_throws ArgumentError evaluate(small(), crit;
            stratified = rd -> DataFrame(scenario = ["x"], age = [1], inf = [1]), stratified_by = [:age], seed = 1)
        @test_throws ArgumentError evaluate(small(), crit;
            stratified = rd -> DataFrame(age = [1, 1], sex = [1, 1], inf = [1, 2]), stratified_by = [:age, :sex], seed = 1)
        # schema divergence across runs
        c = Ref(0)
        divergent = rd -> (c[] += 1; c[] == 1 ? DataFrame(age = [1], sex = [1], inf = [1]) :
                                                DataFrame(age = [1], sex = [1], other = [1]))
        @test_throws ArgumentError evaluate(fast(n_runs = 2, label = "s"), crit;
            stratified = divergent, stratified_by = [:age, :sex], seed = 1)
    end
end
