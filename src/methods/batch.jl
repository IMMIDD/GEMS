export process!

"""
    process!(batch::Batch; keep_rundata=true, rd_style="LightRD", median_by=nothing, group_by=nothing, seed=nothing, customlogger=nothing)

Processes all simulation configurations in `batch` sequentially, accumulating
results into a `BatchProcessor`.

# Keyword Arguments

- `keep_rundata`: if `true`, every run's `ResultData` is stored in `bp.rundata`.
  Default: `true`.
- `rd_style`: the `ResultData` style for individual and median runs. Default: `"LightRD"`.
- `median_by`: a function `pp::PostProcessor -> scalar` for selecting the median run.
  The simulation with criterion closest to the median across all runs is re-run and
  stored. For multi-group batches one median run per group is computed.
  Default: `nothing`
- `group_by`: a `Symbol` naming a field in each simulation config `NamedTuple` to use
  as the grouping key. When `nothing` (default), no per-group tracking is performed.
  Pass e.g. `group_by = :label` to group by the `:label` field.
- `seed`: seed for reproducibility. Passing the same value produces the same results.
  If `nothing`, a random seed is generated. Retrieve the used seed via `seed(bp)`.
- `customlogger`: a `CustomLogger` to attach to each simulation. An independent copy
  is created per run so data is not mixed across runs. Default: `nothing`.
"""
function process!(batch::Batch;
    keep_rundata::Bool = true,
    rd_style::String = "LightRD",
    median_by::Union{Nothing, Function} = nothing,
    group_by::Union{Nothing, Symbol} = nothing,
    seed::Union{Nothing, Integer} = nothing,
    customlogger::Union{Nothing, CustomLogger} = nothing
)
    configs = simconfigs(batch)
    setups = simsetups(batch)
    n = length(configs)

    master_seed = seed !== nothing ? Int64(seed) : gems_rand(Xoshiro(), 0:typemax(Int64))
    sim_seeds = let rng = Xoshiro(master_seed)
        [gems_rand(rng, 0:typemax(Int64)) for _ in 1:n]
    end

    bp = BatchProcessor(; keep_rundata, master_seed)
    cfg_groups = group_by !== nothing ? [string(get(cfg, group_by, "")) for cfg in configs] : fill("", n)
    multi_group = group_by !== nothing && length(unique(cfg_groups)) > 1

    collect_median = median_by !== nothing
    criterion_values = !multi_group && collect_median ? Float64[] : nothing
    group_criteria = multi_group && collect_median ? Dict{String, Vector{Float64}}() : nothing
    group_indices = multi_group && collect_median ? Dict{String, Vector{Int}}() : nothing

    for (i, (cfg, sim_setup, sim_group)) in enumerate(zip(configs, setups, cfg_groups))
        printinfo("Processing Simulation $i/$n in Batch")

        sim = Simulation(; cfg..., seed = sim_seeds[i])

        sim_setup !== nothing && sim_setup(sim)

        customlogger !== nothing && customlogger!(sim, duplicate(customlogger))
        run!(sim)
        pp = PostProcessor(sim)
        accumulate!(bp, pp; rd_style)
        if multi_group
            if !haskey(bp.per_group, sim_group)
                bp.per_group[sim_group] = BatchProcessor()
            end
            accumulate!(bp.per_group[sim_group], pp; rd_style)
        end
        if collect_median
            val = Float64(median_by(pp))
            criterion_values !== nothing && push!(criterion_values, val)
            if group_criteria !== nothing
                push!(get!(group_criteria, sim_group, Float64[]), val)
                push!(get!(group_indices, sim_group, Int[]), i)
            end
        end
    end

    if multi_group
        _run_group_median_runs!(bp, configs, setups, sim_seeds, group_criteria, group_indices, rd_style)
    else
        _run_median_run!(bp, configs, setups, sim_seeds, criterion_values, rd_style)
    end

    return bp
end

function _run_median_run!(bp, configs, setups, sim_seeds, criterion_values, rd_style)
    (isnothing(criterion_values) || isempty(criterion_values)) && return
    final_median = median(criterion_values)
    best_idx = argmin(abs(v - final_median) for v in criterion_values)
    printinfo("Re-running median simulation (config $best_idx)")
    cfg = configs[best_idx]
    rep_sim = Simulation(; cfg..., seed = sim_seeds[best_idx])
    setups[best_idx] !== nothing && setups[best_idx](rep_sim)
    run!(rep_sim)
    bp.median_run = ResultData(PostProcessor(rep_sim), style = rd_style)
end

function _run_group_median_runs!(bp, configs, setups, sim_seeds, group_criteria, group_indices, rd_style)
    isnothing(group_criteria) && return
    for (grp, criteria) in group_criteria
        indices = group_indices[grp]
        final_median = median(criteria)
        best_local = argmin(abs(v - final_median) for v in criteria)
        best_idx = indices[best_local]
        printinfo("Re-running median simulation for group \"$grp\" (config $best_idx)")
        cfg = configs[best_idx]
        rep_sim = Simulation(; cfg..., seed = sim_seeds[best_idx])
        setups[best_idx] !== nothing && setups[best_idx](rep_sim)
        run!(rep_sim)
        bp.per_group[grp].median_run = ResultData(PostProcessor(rep_sim), style = rd_style)
    end
end
