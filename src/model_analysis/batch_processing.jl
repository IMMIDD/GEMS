# DATA PROCESSING FOR BATCHRUNS
export BatchProcessor

export rundata, n_runs, representative_run
export total_infections, total_tests, attack_rate, r0
export tick_cases, effectiveR, tests, cumulative_quarantines, cumulative_disease_progressions
export total_quarantines

"""
    BatchProcessor

Streaming accumulator for multi-run batch analysis. Analogous to `PostProcessor`
for single runs: it is the raw accumulation layer from which `BatchData` styles
compute their output.

Accumulate one run at a time by calling `accumulate!(bp, pp)` with a completed
`PostProcessor`. Statistics are maintained online using Welford's algorithm —
memory usage is O(1) in the number of runs regardless of batch size.

# Optional fields

- `representative_by`: pass `pp -> scalar` to keep the single `ResultData` whose
  criterion value is closest to the running mean. Useful for "run with mean infections"
  style analyses without storing all N `ResultData` objects.
- `keep_rundata`: pass `true` to store all individual `ResultData` objects (O(n) memory).
"""
mutable struct BatchProcessor
    n_runs::Int

    # Per-tick Welford accumulators (tick -> WelfordState)
    tick_cases::Dict{Int, WelfordState}
    effectiveR::Dict{Int, WelfordState}
    compartments::Dict{String, Dict{Int, WelfordState}}
    quarantines::Dict{Int, WelfordState}
    tests::Dict{String, Dict{String, Dict{Int, WelfordState}}}

    # Scalar Welford accumulators
    total_infections::WelfordState
    attack_rate::WelfordState
    r0::WelfordState
    total_quarantines::WelfordState
    total_tests::Dict{String, WelfordState}

    # Representative run — O(1) ResultData in memory.
    # Streaming approximation: stores the run whose criterion was closest to the
    # running mean *at the time it was processed*. Accuracy improves with more runs.
    # For exact post-hoc selection use keep_rundata=true.
    representative_by::Union{Nothing, Function}
    representative_run::Union{Nothing, ResultData}
    representative_value::Union{Nothing, Float64}
    running_mean_criterion::Float64

    # Optional: keep all ResultData — O(n) memory, not the default
    rundata::Union{Nothing, Vector{ResultData}}

    @doc """
        BatchProcessor(; representative_by=nothing, keep_rundata=false)

    Create an empty `BatchProcessor` ready to receive runs via `accumulate!`.

    # Keyword Arguments

    - `representative_by`: a function `pp::PostProcessor -> scalar` that selects
      which run is "representative" (e.g. `pp -> nrow(infectionsDF(pp))`). The
      processor keeps the single `ResultData` closest to the running mean of this
      scalar. Default: `nothing` (no representative run stored).
    - `keep_rundata`: if `true`, store every run's `ResultData` in `rundata`.
      Required for `merge(bds::BatchData...)`. Default: `false`.
    """
    function BatchProcessor(; representative_by = nothing, keep_rundata::Bool = false)
        new(
            0,
            Dict{Int, WelfordState}(),
            Dict{Int, WelfordState}(),
            Dict{String, Dict{Int, WelfordState}}(),
            Dict{Int, WelfordState}(),
            Dict{String, Dict{String, Dict{Int, WelfordState}}}(),
            WelfordState(), WelfordState(), WelfordState(), WelfordState(),
            Dict{String, WelfordState}(),
            representative_by, nothing, nothing, 0.0,
            keep_rundata ? ResultData[] : nothing
        )
    end

    @doc """
        BatchProcessor(rds::Vector{ResultData})

    Backward-compatible constructor: accumulate a pre-existing vector of `ResultData`
    objects into a new `BatchProcessor`. The individual `ResultData` objects are stored
    in `rundata` so that `merge(bds::BatchData...)` continues to work.
    """
    function BatchProcessor(rds::Vector{ResultData})
        bp = new(
            0,
            Dict{Int, WelfordState}(),
            Dict{Int, WelfordState}(),
            Dict{String, Dict{Int, WelfordState}}(),
            Dict{Int, WelfordState}(),
            Dict{String, Dict{String, Dict{Int, WelfordState}}}(),
            WelfordState(), WelfordState(), WelfordState(), WelfordState(),
            Dict{String, WelfordState}(),
            nothing, nothing, nothing, 0.0,
            ResultData[]
        )
        for rd in rds
            accumulate!(bp, rd)
        end
        return bp
    end
end


###
### INTERNAL HELPERS
###

function _update_singlecol!(accum::Dict{Int, WelfordState}, df::DataFrame, key_col::Symbol, val_col::Symbol)
    for row in eachrow(df)
        welford_update!(get!(accum, Int(row[key_col]), WelfordState()), row[val_col])
    end
end

function _update_multicol!(accum::Dict{String, Dict{Int, WelfordState}}, df::DataFrame, key_col::Symbol)
    val_cols = [name for name in names(df) if name != string(key_col)]
    for col in val_cols
        col_accum = get!(accum, col, Dict{Int, WelfordState}())
        for row in eachrow(df)
            welford_update!(get!(col_accum, Int(row[key_col]), WelfordState()), row[col])
        end
    end
end


###
### ACCUMULATE FROM POSTPROCESSOR
###

"""
    accumulate!(bp::BatchProcessor, pp::PostProcessor; rd_style="LightRD")

Update all accumulators in `bp` with data from a completed `PostProcessor`.
Call this once per simulation run immediately after `PostProcessor(sim)` is
constructed, before discarding the simulation and post-processor.
"""
function accumulate!(bp::BatchProcessor, pp::PostProcessor; rd_style::String = "LightRD")
    bp.n_runs += 1

    # Per-tick accumulators
    _update_singlecol!(bp.tick_cases, tick_cases(pp), :tick, :exposed_cnt)
    _update_singlecol!(bp.effectiveR, effectiveR(pp), :tick, :effective_R)
    _update_multicol!(bp.compartments, cumulative_disease_progressions(pp), :tick)
    _update_singlecol!(bp.quarantines, cumulative_quarantines(pp), :tick, :quarantined)
    for (testtype, df) in tick_tests(pp)
        _update_multicol!(
            get!(bp.tests, testtype, Dict{String, Dict{Int, WelfordState}}()),
            df, :tick
        )
    end

    # Scalar accumulators
    welford_update!(bp.total_infections, nrow(infectionsDF(pp)))
    welford_update!(bp.attack_rate, attack_rate(pp))
    welford_update!(bp.r0, r0(pp))
    welford_update!(bp.total_quarantines, total_quarantines(pp))
    for (testtype, cnt) in total_tests(pp)
        welford_update!(get!(bp.total_tests, testtype, WelfordState()), cnt)
    end

    # Representative run
    if bp.representative_by !== nothing
        val = Float64(bp.representative_by(pp))
        bp.running_mean_criterion = ((bp.n_runs - 1) * bp.running_mean_criterion + val) / bp.n_runs
        if bp.representative_run === nothing ||
           abs(val - bp.running_mean_criterion) < abs(bp.representative_value - bp.running_mean_criterion)
            bp.representative_run = ResultData(pp, style = rd_style)
            bp.representative_value = val
        end
    end

    # Optional: all ResultData
    if bp.rundata !== nothing
        push!(bp.rundata, ResultData(pp, style = rd_style))
    end
end


###
### ACCUMULATE FROM RESULTDATA (backward compat)
###

"""
    accumulate!(bp::BatchProcessor, rd::ResultData)

Update accumulators from a pre-computed `ResultData` object.
Used by the backward-compatible `BatchProcessor(rds::Vector{ResultData})` constructor.
"""
function accumulate!(bp::BatchProcessor, rd::ResultData)
    bp.n_runs += 1

    # Per-tick accumulators — read from ResultData dataframes dict
    tc = tick_cases(rd)
    if isa(tc, DataFrame) && !isempty(tc) && hasproperty(tc, :tick) && hasproperty(tc, :exposed_cnt)
        _update_singlecol!(bp.tick_cases, tc, :tick, :exposed_cnt)
    end

    er = effectiveR(rd)
    if isa(er, DataFrame) && !isempty(er) && hasproperty(er, :tick) && hasproperty(er, :effective_R)
        _update_singlecol!(bp.effectiveR, er, :tick, :effective_R)
    end

    cdp = cumulative_disease_progressions(rd)
    if isa(cdp, DataFrame) && !isempty(cdp) && hasproperty(cdp, :tick)
        _update_multicol!(bp.compartments, cdp, :tick)
    end

    cq = cumulative_quarantines(rd)
    if isa(cq, DataFrame) && !isempty(cq) && hasproperty(cq, :tick) && hasproperty(cq, :quarantined)
        _update_singlecol!(bp.quarantines, cq, :tick, :quarantined)
    end

    tt = tick_tests(rd)
    if isa(tt, Dict)
        for (testtype, df) in tt
            if isa(df, DataFrame) && !isempty(df) && hasproperty(df, :tick)
                _update_multicol!(
                    get!(bp.tests, testtype, Dict{String, Dict{Int, WelfordState}}()),
                    df, :tick
                )
            end
        end
    end

    # Scalar accumulators
    ti = total_infections(rd)
    isa(ti, Number) && welford_update!(bp.total_infections, ti)

    ar = attack_rate(rd)
    isa(ar, Number) && welford_update!(bp.attack_rate, ar)

    r0val = r0(rd)
    isa(r0val, Number) && welford_update!(bp.r0, r0val)

    tq = total_quarantines(rd)
    isa(tq, Number) && welford_update!(bp.total_quarantines, tq)

    tt_scalar = total_tests(rd)
    if isa(tt_scalar, Dict)
        for (testtype, cnt) in tt_scalar
            isa(cnt, Number) && welford_update!(get!(bp.total_tests, testtype, WelfordState()), cnt)
        end
    end

    # Optional: store ResultData
    if bp.rundata !== nothing
        push!(bp.rundata, rd)
    end
end


###
### ACCESSORS
###

"""
    n_runs(bp::BatchProcessor)

Returns the number of simulation runs accumulated so far.
"""
function n_runs(bp::BatchProcessor)
    return bp.n_runs
end

"""
    rundata(bp::BatchProcessor)

Returns the stored `ResultData` objects, or `nothing` if `keep_rundata` was `false`.
"""
function rundata(bp::BatchProcessor)
    return bp.rundata
end

"""
    representative_run(bp::BatchProcessor)

Returns the representative `ResultData` (the run whose `representative_by` criterion
was closest to the running mean), or `nothing` if `representative_by` was not set.
"""
function representative_run(bp::BatchProcessor)
    return bp.representative_run
end

"""
    total_infections(bp::BatchProcessor)

Returns aggregated statistics for total infections across all runs.
Keys: `"min"`, `"max"`, `"mean"`, `"std"`, `"lower_95"`, `"upper_95"`.
"""
function total_infections(bp::BatchProcessor)
    return welford_to_aggregate(bp.total_infections)
end

"""
    attack_rate(bp::BatchProcessor)

Returns aggregated statistics for the attack rate across all runs.
"""
function attack_rate(bp::BatchProcessor)
    return welford_to_aggregate(bp.attack_rate)
end

"""
    r0(bp::BatchProcessor)

Returns aggregated statistics for the basic reproduction number across all runs.
"""
function r0(bp::BatchProcessor)
    return welford_to_aggregate(bp.r0)
end

"""
    total_quarantines(bp::BatchProcessor)

Returns aggregated statistics for total quarantines across all runs.
"""
function total_quarantines(bp::BatchProcessor)
    return welford_to_aggregate(bp.total_quarantines)
end

"""
    total_tests(bp::BatchProcessor)

Returns a dict mapping test type name to aggregated statistics across all runs.
"""
function total_tests(bp::BatchProcessor)
    return Dict(k => welford_to_aggregate(v) for (k, v) in bp.total_tests)
end

"""
    tick_cases(bp::BatchProcessor)

Returns aggregated new exposures per tick across all runs as a `DataFrame`.
Columns: `tick`, `minimum`, `maximum`, `mean`, `std`, `lower_95`, `upper_95`.
"""
function tick_cases(bp::BatchProcessor)
    return welford_df_to_stats_df(bp.tick_cases, :tick)
end

"""
    effectiveR(bp::BatchProcessor)

Returns aggregated effective R per tick across all runs as a `DataFrame`.
Columns: `tick`, `minimum`, `maximum`, `mean`, `std`, `lower_95`, `upper_95`.
"""
function effectiveR(bp::BatchProcessor)
    return welford_df_to_stats_df(bp.effectiveR, :tick)
end

"""
    cumulative_quarantines(bp::BatchProcessor)

Returns aggregated cumulative quarantines per tick across all runs as a `DataFrame`.
Columns: `tick`, `minimum`, `maximum`, `mean`, `std`, `lower_95`, `upper_95`.
"""
function cumulative_quarantines(bp::BatchProcessor)
    return welford_df_to_stats_df(bp.quarantines, :tick)
end

"""
    cumulative_disease_progressions(bp::BatchProcessor)

Returns aggregated disease progression counts per tick across all runs.
Returns a `Dict{String, DataFrame}` keyed by compartment name
(`latent`, `pre_symptomatic`, `symptomatic`, `asymptomatic`).
"""
function cumulative_disease_progressions(bp::BatchProcessor)
    return welford_df_to_stats_df_multicol(bp.compartments, :tick)
end

"""
    tests(bp::BatchProcessor)

Returns aggregated test statistics per tick for each test type.
Returns a `Dict{String, Dict{String, DataFrame}}` keyed by test type then column name.
"""
function tests(bp::BatchProcessor)
    return Dict(k => welford_df_to_stats_df_multicol(v, :tick) for (k, v) in bp.tests)
end


###
### PRINTING
###

function Base.show(io::IO, bp::BatchProcessor)
    write(io, "BatchProcessor ($(bp.n_runs) runs accumulated)")
end
