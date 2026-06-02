# DATA PROCESSING FOR BATCHRUNS
export BatchProcessor

export rundata, n_runs, median_run, tick_unit, seed, pathogen_names
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

    # Per-tick Welford accumulators (pathogen_id -> col -> tick -> WelfordState)
    tick_cases::Dict{Int8, Dict{String, Dict{Int, WelfordState}}}
    effectiveR::Dict{Int8, Dict{String, Dict{Int, WelfordState}}}
    compartments::Dict{Int8, Dict{String, Dict{Int, WelfordState}}}
    quarantines::Dict{String, Dict{Int, WelfordState}}
    tests::Dict{String, Dict{String, Dict{Int, WelfordState}}}
    pool_tests::Dict{String, Dict{String, Dict{Int, WelfordState}}}
    sero_tests::Dict{String, Dict{String, Dict{Int, WelfordState}}}
    dark_figure::Dict{Int, WelfordState}
    cumulative_cases::Dict{Int8, Dict{String, Dict{Int, WelfordState}}}
    generation_times::Dict{Int8, Dict{Int, WelfordState}}
    hospitalizations::Dict{Int8, Dict{String, Dict{Int, WelfordState}}}
    observed_R::Dict{Int8, Dict{String, Dict{Int, WelfordState}}}

    # Scalar Welford accumulators
    total_infections::WelfordState
    attack_rate::Dict{Int8, WelfordState}
    r0::Dict{Int8, WelfordState}
    total_quarantines::WelfordState
    total_tests::Dict{String, WelfordState}
    total_detected_cases::WelfordState
    detection_rate::WelfordState

    # Pathogen id → name mapping (captured from the first accumulated run)
    pathogen_names::Dict{Int8, String}

    # Median run — set by process! when median_by is provided
    median_run::Union{Nothing, ResultData}

    # Seed used for this batch run
    master_seed::Int64

    # Individual ResultData objects — only stored when keep_rundata=true
    rundata::Union{Nothing, Vector{ResultData}}

    # Per-group sub-accumulators, only populated when group_by is set
    per_group::Dict{String, BatchProcessor}

    @doc """
        BatchProcessor(; keep_rundata=true, master_seed=0)

    Creates a `BatchProcessor` object.

    # Keyword Arguments

    - `keep_rundata`: if `true`, store every run's `ResultData` in `rundata`. Default: `true`.
    - `master_seed`: seed for this batch run. Default: `0`.
    """
    function BatchProcessor(; keep_rundata::Bool = true, master_seed::Int64 = 0)
        new(
            0,
            "tick",
            Dict{Int8, Dict{String, Dict{Int, WelfordState}}}(),
            Dict{Int8, Dict{String, Dict{Int, WelfordState}}}(),
            Dict{Int8, Dict{String, Dict{Int, WelfordState}}}(),
            Dict{String, Dict{Int, WelfordState}}(),
            Dict{String, Dict{String, Dict{Int, WelfordState}}}(),
            Dict{String, Dict{String, Dict{Int, WelfordState}}}(),
            Dict{String, Dict{String, Dict{Int, WelfordState}}}(),
            Dict{Int, WelfordState}(),
            Dict{Int8, Dict{String, Dict{Int, WelfordState}}}(),
            Dict{Int8, Dict{Int, WelfordState}}(),
            Dict{Int8, Dict{String, Dict{Int, WelfordState}}}(),
            Dict{Int8, Dict{String, Dict{Int, WelfordState}}}(),
            WelfordState(), Dict{Int8, WelfordState}(), Dict{Int8, WelfordState}(), WelfordState(),
            Dict{String, WelfordState}(),
            WelfordState(), WelfordState(),
            Dict{Int8, String}(),
            nothing,
            master_seed,
            keep_rundata ? ResultData[] : nothing,
            Dict{String, BatchProcessor}()  # per_group
        )
    end

end


###
### INTERNAL HELPERS
###

function _update_singlecol!(accum::Dict{Int, WelfordState}, df::DataFrame, key_col::Symbol, val_col::Symbol)
    for row in eachrow(df)
        val = row[val_col]
        ismissing(val) && continue
        welford_update!(get!(accum, Int(row[key_col]), WelfordState()), val)
    end
end

function _update_multicol!(accum::Dict{String, Dict{Int, WelfordState}}, df::DataFrame, key_col::Symbol)
    val_cols = [name for name in names(df) if name != string(key_col)]
    for col in val_cols
        col_accum = get!(accum, col, Dict{Int, WelfordState}())
        for row in eachrow(df)
            val = row[col]
            ismissing(val) && continue
            welford_update!(get!(col_accum, Int(row[key_col]), WelfordState()), val)
        end
    end
end

function _update_multicol_grouped!(accum::Dict{Int8, Dict{String, Dict{Int, WelfordState}}},
    df::DataFrame, key_col::Symbol, group_col::Symbol)
    for (k, subdf) in pairs(groupby(df, group_col))
        gid = Int8(k[group_col])
        group_accum = get!(accum, gid, Dict{String, Dict{Int, WelfordState}}())
        _update_multicol!(group_accum, select(subdf, Not(string(group_col))), key_col)
    end
end

function _update_singlecol_grouped!(accum::Dict{Int8, Dict{Int, WelfordState}},
    df::DataFrame, key_col::Symbol, val_col::Symbol, group_col::Symbol)
    for (k, subdf) in pairs(groupby(df, group_col))
        gid = Int8(k[group_col])
        group_accum = get!(accum, gid, Dict{Int, WelfordState}())
        _update_singlecol!(group_accum, DataFrame(subdf), key_col, val_col)
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

    # Capture tick unit and pathogen names from first run
    if bp.n_runs == 1
        bp.tick_unit = string(tickunit(simulation(pp)))
        bp.pathogen_names = Dict(id(p) => name(p) for p in pathogens(simulation(pp)))
    end

    # Per-tick accumulators (pathogen-keyed)
    _update_multicol_grouped!(bp.tick_cases, tick_cases(pp), :tick, :pathogen_id)
    _update_multicol_grouped!(bp.effectiveR, effectiveR(pp), :tick, :pathogen_id)
    _update_multicol_grouped!(bp.compartments, cumulative_disease_progressions(pp), :tick, :pathogen_id)
    _update_multicol!(bp.quarantines, cumulative_quarantines(pp), :tick)
    for (testtype, df) in tick_tests(pp)
        # exclude derived rate columns — they are 0 for no-test ticks (not undefined),
        # which would bias the Welford mean; counts are accumulated instead
        _update_multicol!(
            get!(bp.tests, testtype, Dict{String, Dict{Int, WelfordState}}()),
            select(df, Not(intersect(["positive_rate", "rolling_positive_rate"], names(df)))),
            :tick
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

    # Cumulative cases (multi-column per tick, pathogen-keyed)
    _update_multicol_grouped!(bp.cumulative_cases, cumulative_cases(pp), :tick, :pathogen_id)

    # Mean generation time per tick (pathogen-keyed)
    gt = tick_generation_times(pp)
    if !isempty(gt) && hasproperty(gt, :mean_generation_time)
        _update_singlecol_grouped!(
            bp.generation_times,
            dropmissing(gt, :mean_generation_time),
            :tick, :mean_generation_time, :pathogen_id
        )
    end

    # Hospitalizations and observed R per tick (pathogen-keyed)
    _update_multicol_grouped!(bp.hospitalizations, hospital_df(pp), :tick, :pathogen_id)
    _update_multicol_grouped!(bp.observed_R, observed_R(pp), :tick, :pathogen_id)

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
    for row in eachrow(attack_rate(pp))
        welford_update!(get!(bp.attack_rate, row.pathogen_id, WelfordState()), row.attack_rate)
    end
    for row in eachrow(r0(pp))
        welford_update!(get!(bp.r0, row.pathogen_id, WelfordState()), row.r0)
    end
    welford_update!(bp.total_quarantines, total_quarantines(pp))
    for row in eachrow(total_tests(pp))
        welford_update!(get!(bp.total_tests, row.test_type, WelfordState()), row.count)
    end
    tdc = total_detected_cases(pp)
    welford_update!(bp.total_detected_cases, isempty(tdc) ? 0 : sum(tdc.detected_cases))
    dr = detection_rate(pp)
    welford_update!(bp.detection_rate, isempty(dr) ? 0.0 : sum(dr.detection_rate) / nrow(dr))

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
    pathogen_names(bp::BatchProcessor)

Returns a `Dict{Int8, String}` mapping pathogen id to pathogen name.
"""
function pathogen_names(bp::BatchProcessor)
    return bp.pathogen_names
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

Returns per-pathogen aggregated statistics for the attack rate across all runs.
Returns a `Dict{Int8, Dict{String, Real}}` keyed by pathogen id.
"""
function attack_rate(bp::BatchProcessor)
    return Dict(pid => welford_to_aggregate(ws) for (pid, ws) in bp.attack_rate)
end

"""
    r0(bp::BatchProcessor)

Returns per-pathogen aggregated statistics for the basic reproduction number across all runs.
Returns a `Dict{Int8, Dict{String, Real}}` keyed by pathogen id.
"""
function r0(bp::BatchProcessor)
    return Dict(pid => welford_to_aggregate(ws) for (pid, ws) in bp.r0)
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

Returns aggregated case counts per tick across all runs, per pathogen.
Returns a `Dict{Int8, Dict{String, DataFrame}}` keyed by pathogen id then column name
(`exposed_cnt`, `infectious_cnt`, `recovered_cnt`, `dead_cnt`).
"""
function tick_cases(bp::BatchProcessor)
    return Dict(pid => welford_df_to_stats_df_multicol(inner, :tick) for (pid, inner) in bp.tick_cases)
end

"""
    effectiveR(bp::BatchProcessor)

Returns aggregated effective R values per tick across all runs, per pathogen.
Returns a `Dict{Int8, Dict{String, DataFrame}}` keyed by pathogen id then column name
(`effective_R`, `rolling_R`, `in_hh_effective_R`, `rolling_in_hh_R`, `rolling_out_hh_R`).
"""
function effectiveR(bp::BatchProcessor)
    return Dict(pid => welford_df_to_stats_df_multicol(inner, :tick) for (pid, inner) in bp.effectiveR)
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

Returns aggregated disease progression counts per ticks-since-infection across all runs, per pathogen.
Returns a `Dict{Int8, Dict{String, DataFrame}}` keyed by pathogen id then compartment name
(`latent`, `pre_symptomatic`, `symptomatic`, `asymptomatic`).
"""
function cumulative_disease_progressions(bp::BatchProcessor)
    return Dict(pid => welford_df_to_stats_df_multicol(inner, :tick) for (pid, inner) in bp.compartments)
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

Returns aggregated hospitalization metrics per tick across all runs, per pathogen.
Returns a `Dict{Int8, Dict{String, DataFrame}}` keyed by pathogen id then column name
(e.g. `current_hospitalized`, `current_icu`, `hospital_admissions`).
"""
function hospitalizations(bp::BatchProcessor)
    return Dict(pid => welford_df_to_stats_df_multicol(inner, :tick) for (pid, inner) in bp.hospitalizations)
end

"""
    observed_R(bp::BatchProcessor)

Returns aggregated observed reproduction number estimates per tick across all runs, per pathogen.
Returns a `Dict{Int8, Dict{String, DataFrame}}` keyed by pathogen id then column name
(`mean_est_R`, `lower_est_R`, `upper_est_R`).
"""
function observed_R(bp::BatchProcessor)
    return Dict(pid => welford_df_to_stats_df_multicol(inner, :tick) for (pid, inner) in bp.observed_R)
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

Returns aggregated cumulative case counts per tick across all runs, per pathogen.
Returns a `Dict{Int8, Dict{String, DataFrame}}` keyed by pathogen id then column name
(e.g. `exposed_cum`, `recovered_cum`, `deaths_cum`).
"""
function cumulative_cases(bp::BatchProcessor)
    return Dict(pid => welford_df_to_stats_df_multicol(inner, :tick) for (pid, inner) in bp.cumulative_cases)
end

"""
    generation_times(bp::BatchProcessor)

Returns aggregated mean generation times per tick across all runs, per pathogen.
Returns a `Dict{Int8, DataFrame}` keyed by pathogen id.
Each `DataFrame` has columns: `tick`, `minimum`, `maximum`, `mean`, `std`, `lower_95`, `upper_95`.
"""
function generation_times(bp::BatchProcessor)
    return Dict(pid => welford_df_to_stats_df(inner, :tick) for (pid, inner) in bp.generation_times)
end


###
### PRINTING
###

function Base.show(io::IO, bp::BatchProcessor)
    write(io, "BatchProcessor ($(bp.n_runs) runs)")
end
