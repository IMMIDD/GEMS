# DATA PROCESSING FOR BATCHRUNS
export BatchProcessor

export rundata, n_runs, median_run, tick_unit, seed
export total_infections, total_tests, attack_rate, r0
export tick_cases, effectiveR, tests, cumulative_quarantines, cumulative_disease_progressions
export total_quarantines, dark_figure, cumulative_cases, generation_times
export hospitalizations, observed_R, pool_tests, sero_tests, total_detected_cases, detection_rate

"""
    BatchProcessor

A type to provide data processing features for batches of simulation runs,
supplying reports, plots, or other data analyses.
"""
mutable struct BatchProcessor
    n_runs::Int
    tick_unit::String

    # Per-tick Welford accumulators (tick -> WelfordState)
    tick_cases::Dict{String, Dict{Int, WelfordState}}
    effectiveR::Dict{String, Dict{Int, WelfordState}}
    compartments::Dict{String, Dict{Int, WelfordState}}
    quarantines::Dict{String, Dict{Int, WelfordState}}
    tests::Dict{String, Dict{String, Dict{Int, WelfordState}}}
    pool_tests::Dict{String, Dict{String, Dict{Int, WelfordState}}}
    sero_tests::Dict{String, Dict{String, Dict{Int, WelfordState}}}
    dark_figure::Dict{Int, WelfordState}
    cumulative_cases::Dict{String, Dict{Int, WelfordState}}
    generation_times::Dict{Int, WelfordState}
    hospitalizations::Dict{String, Dict{Int, WelfordState}}
    observed_R::Dict{String, Dict{Int, WelfordState}}

    # Scalar Welford accumulators
    total_infections::WelfordState
    attack_rate::WelfordState
    r0::WelfordState
    total_quarantines::WelfordState
    total_tests::Dict{String, WelfordState}
    total_detected_cases::WelfordState
    detection_rate::WelfordState

    # Median run — set by process! when median_by is provided
    median_run::Union{Nothing, ResultData}

    # Seed used for this batch run
    master_seed::Int64

    # Individual ResultData objects — only stored when keep_rundata=true
    rundata::Union{Nothing, Vector{ResultData}}

    # Per-label sub-accumulators, only populated for multi-label batches
    per_label::Dict{String, BatchProcessor}

    @doc """
        BatchProcessor(; keep_rundata=false, master_seed=0)

    Creates a `BatchProcessor` object.

    # Keyword Arguments

    - `keep_rundata`: if `true`, store every run's `ResultData` in `rundata`.
      Required for `merge(bds::BatchData...)`. Default: `false`.
    - `master_seed`: seed for this batch run. Default: `0`.
    """
    function BatchProcessor(; keep_rundata::Bool = false, master_seed::Int64 = 0)
        new(
            0,
            "tick",
            Dict{String, Dict{Int, WelfordState}}(),
            Dict{String, Dict{Int, WelfordState}}(),
            Dict{String, Dict{Int, WelfordState}}(),
            Dict{String, Dict{Int, WelfordState}}(),
            Dict{String, Dict{String, Dict{Int, WelfordState}}}(),
            Dict{String, Dict{String, Dict{Int, WelfordState}}}(),
            Dict{String, Dict{String, Dict{Int, WelfordState}}}(),
            Dict{Int, WelfordState}(),
            Dict{String, Dict{Int, WelfordState}}(),
            Dict{Int, WelfordState}(),
            Dict{String, Dict{Int, WelfordState}}(),
            Dict{String, Dict{Int, WelfordState}}(),
            WelfordState(), WelfordState(), WelfordState(), WelfordState(),
            Dict{String, WelfordState}(),
            WelfordState(), WelfordState(),
            nothing,
            master_seed,
            keep_rundata ? ResultData[] : nothing,
            Dict{String, BatchProcessor}()
        )
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

Adds the results of a completed `PostProcessor` to a `BatchProcessor`.
"""
function accumulate!(bp::BatchProcessor, pp::PostProcessor; rd_style::String = "LightRD")
    bp.n_runs += 1

    # Capture tick unit from first run
    if bp.n_runs == 1
        bp.tick_unit = string(tickunit(simulation(pp)))
    end

    # Per-tick accumulators
    _update_multicol!(bp.tick_cases, tick_cases(pp), :tick)
    _update_multicol!(bp.effectiveR, effectiveR(pp), :tick)
    _update_multicol!(bp.compartments, cumulative_disease_progressions(pp), :tick)
    _update_multicol!(bp.quarantines, cumulative_quarantines(pp), :tick)
    for (testtype, df) in tick_tests(pp)
        _update_multicol!(
            get!(bp.tests, testtype, Dict{String, Dict{Int, WelfordState}}()),
            df, :tick
        )
    end

    # Dark figure fraction per tick (non-linear — accumulate the fraction, not raw columns)
    cf = compartment_fill(pp)
    if !isempty(cf) && hasproperty(cf, :exposed_cnt) && hasproperty(cf, :infectious_cnt) && hasproperty(cf, :detected_cnt)
        for row in eachrow(cf)
            active = row[:exposed_cnt] + row[:infectious_cnt]
            frac = active > 0 ? 1.0 - row[:detected_cnt] / active : 0.0
            welford_update!(get!(bp.dark_figure, Int(row[:tick]), WelfordState()), frac)
        end
    end

    # Cumulative cases (multi-column per tick)
    _update_multicol!(bp.cumulative_cases, cumulative_cases(pp), :tick)

    # Mean generation time per tick
    gt = tick_generation_times(pp)
    if !isempty(gt) && hasproperty(gt, :mean_generation_time)
        _update_singlecol!(
            bp.generation_times,
            dropmissing(gt, :mean_generation_time),
            :tick, :mean_generation_time
        )
    end

    # Hospitalizations and observed R per tick
    _update_multicol!(bp.hospitalizations, hospital_df(pp), :tick)
    _update_multicol!(bp.observed_R, observed_R(pp), :tick)

    # Pool and serology tests per tick
    for (testtype, df) in tick_pooltests(pp)
        _update_multicol!(
            get!(bp.pool_tests, testtype, Dict{String, Dict{Int, WelfordState}}()),
            df, :tick
        )
    end
    for (testtype, df) in tick_serotests(pp)
        _update_multicol!(
            get!(bp.sero_tests, testtype, Dict{String, Dict{Int, WelfordState}}()),
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
    welford_update!(bp.total_detected_cases, total_detected_cases(pp))
    welford_update!(bp.detection_rate, detection_rate(pp))

    # Optional: all ResultData
    if bp.rundata !== nothing
        push!(bp.rundata, ResultData(pp, style = rd_style))
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
    tick_unit(bp::BatchProcessor)

Returns the tick unit of the simulation runs in this batch (e.g. `"d"` for days).
"""
function tick_unit(bp::BatchProcessor)
    return bp.tick_unit
end

"""
    rundata(bp::BatchProcessor)

Returns the stored `ResultData` objects, or `nothing` if `keep_rundata` was `false`.
"""
function rundata(bp::BatchProcessor)
    return bp.rundata
end

"""
    median_run(bp::BatchProcessor)

Returns the `ResultData` of the simulation whose criterion is closest to the
median across all runs, or `nothing` if `median_by` was not set.
"""
function median_run(bp::BatchProcessor)
    return bp.median_run
end

"""
    seed(bp::BatchProcessor)

Returns the seed used for this batch run, or `0` if no seed was set.
"""
function seed(bp::BatchProcessor)
    return bp.master_seed
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

Returns aggregated case counts per tick across all runs.
Returns a `Dict{String, DataFrame}` keyed by column name
(`exposed_cnt`, `infectious_cnt`, `recovered_cnt`, `dead_cnt`).
"""
function tick_cases(bp::BatchProcessor)
    return welford_df_to_stats_df_multicol(bp.tick_cases, :tick)
end

"""
    effectiveR(bp::BatchProcessor)

Returns aggregated effective R values per tick across all runs.
Returns a `Dict{String, DataFrame}` keyed by column name
(`effective_R`, `rolling_R`, `in_hh_effective_R`, `rolling_in_hh_R`, `rolling_out_hh_R`).
"""
function effectiveR(bp::BatchProcessor)
    return welford_df_to_stats_df_multicol(bp.effectiveR, :tick)
end

"""
    cumulative_quarantines(bp::BatchProcessor)

Returns aggregated cumulative quarantine counts per tick across all runs.
Returns a `Dict{String, DataFrame}` keyed by column name
(`quarantined`, `students`, `workers`, `other`).
"""
function cumulative_quarantines(bp::BatchProcessor)
    return welford_df_to_stats_df_multicol(bp.quarantines, :tick)
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

"""
    pool_tests(bp::BatchProcessor)

Returns aggregated pool test statistics per tick for each test type.
Returns a `Dict{String, Dict{String, DataFrame}}` keyed by test type then column name.
"""
function pool_tests(bp::BatchProcessor)
    return Dict(k => welford_df_to_stats_df_multicol(v, :tick) for (k, v) in bp.pool_tests)
end

"""
    sero_tests(bp::BatchProcessor)

Returns aggregated serology test statistics per tick for each test type.
Returns a `Dict{String, Dict{String, DataFrame}}` keyed by test type then column name.
"""
function sero_tests(bp::BatchProcessor)
    return Dict(k => welford_df_to_stats_df_multicol(v, :tick) for (k, v) in bp.sero_tests)
end

"""
    hospitalizations(bp::BatchProcessor)

Returns aggregated hospitalization metrics per tick across all runs.
Returns a `Dict{String, DataFrame}` keyed by column name
(e.g. `current_hospitalized`, `current_icu`, `hospital_admissions`).
"""
function hospitalizations(bp::BatchProcessor)
    return welford_df_to_stats_df_multicol(bp.hospitalizations, :tick)
end

"""
    observed_R(bp::BatchProcessor)

Returns aggregated observed reproduction number estimates per tick across all runs.
Returns a `Dict{String, DataFrame}` keyed by column name
(`mean_est_R`, `lower_est_R`, `upper_est_R`).
"""
function observed_R(bp::BatchProcessor)
    return welford_df_to_stats_df_multicol(bp.observed_R, :tick)
end

"""
    total_detected_cases(bp::BatchProcessor)

Returns aggregated statistics for total detected cases across all runs.
"""
function total_detected_cases(bp::BatchProcessor)
    return welford_to_aggregate(bp.total_detected_cases)
end

"""
    detection_rate(bp::BatchProcessor)

Returns aggregated statistics for the detection rate across all runs.
"""
function detection_rate(bp::BatchProcessor)
    return welford_to_aggregate(bp.detection_rate)
end

"""
    dark_figure(bp::BatchProcessor)

Returns aggregated dark figure fractions per tick across all runs as a `DataFrame`.
Columns: `tick`, `minimum`, `maximum`, `mean`, `std`, `lower_95`, `upper_95`.
"""
function dark_figure(bp::BatchProcessor)
    return welford_df_to_stats_df(bp.dark_figure, :tick)
end

"""
    cumulative_cases(bp::BatchProcessor)

Returns aggregated cumulative case counts per tick across all runs.
Returns a `Dict{String, DataFrame}` keyed by column name (e.g. `exposed_cum`, `recovered_cum`, `deaths_cum`).
"""
function cumulative_cases(bp::BatchProcessor)
    return welford_df_to_stats_df_multicol(bp.cumulative_cases, :tick)
end

"""
    generation_times(bp::BatchProcessor)

Returns aggregated mean generation times per tick across all runs as a `DataFrame`.
Columns: `tick`, `minimum`, `maximum`, `mean`, `std`, `lower_95`, `upper_95`.
"""
function generation_times(bp::BatchProcessor)
    return welford_df_to_stats_df(bp.generation_times, :tick)
end


###
### PRINTING
###

function Base.show(io::IO, bp::BatchProcessor)
    write(io, "BatchProcessor ($(bp.n_runs) runs)")
end
