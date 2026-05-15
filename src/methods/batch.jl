export process!

"""
    process!(batch::Batch; seed=nothing, median_by=pp->nrow(infectionsDF(pp)), keep_rundata=false, rd_style="LightRD")

Processes all simulation configurations in `batch` sequentially, accumulating
results into a `BatchProcessor`.

# Keyword Arguments

- `seed`: seed for reproducibility. Passing the same value produces the same results.
  If `nothing`, a random seed is generated. Retrieve the used seed via `seed(bp)`.
- `median_by`: a function `pp::PostProcessor -> scalar` for selecting the median run.
  The simulation with criterion closest to the median across all runs is re-run and
  stored. For multi-label batches one median run per label is computed.
  Default: total infections. Pass `nothing` to disable.
- `keep_rundata`: if `true`, every run's `ResultData` is stored in `bp.rundata`.
  Default: `false`.
- `rd_style`: the `ResultData` style for individual and median runs. Default: `"LightRD"`.
"""
function process!(batch::Batch;
    seed::Union{Nothing, Integer} = nothing,
    median_by::Union{Nothing, Function} = pp -> nrow(infectionsDF(pp)),
    keep_rundata::Bool = false,
    rd_style::String = "LightRD"
)
    configs = simconfigs(batch)
    n = length(configs)

    master_seed = seed !== nothing ? Int64(seed) : gems_rand(Xoshiro(), 0:typemax(Int64))
    sim_seeds = let rng = Xoshiro(master_seed)
        [gems_rand(rng, 0:typemax(Int64)) for _ in 1:n]
    end

    bp = BatchProcessor(; keep_rundata, master_seed)
    cfg_labels = [string(get(cfg, :label, "")) for cfg in configs]
    multi_label = length(unique(cfg_labels)) > 1

    collect_median = median_by !== nothing
    criterion_values = !multi_label && collect_median ? Float64[] : nothing
    label_criteria = multi_label && collect_median ? Dict{String, Vector{Float64}}() : nothing
    label_indices = multi_label && collect_median ? Dict{String, Vector{Int}}() : nothing

    for (i, (cfg, sim_label)) in enumerate(zip(configs, cfg_labels))
        printinfo("Processing Simulation $i/$n in Batch")
        sim = Simulation(; cfg..., seed = sim_seeds[i])
        run!(sim)
        pp = PostProcessor(sim)
        accumulate!(bp, pp; rd_style)
        if multi_label
            if !haskey(bp.per_label, sim_label)
                bp.per_label[sim_label] = BatchProcessor()
            end
            accumulate!(bp.per_label[sim_label], pp; rd_style)
        end
        if collect_median
            val = Float64(median_by(pp))
            criterion_values !== nothing && push!(criterion_values, val)
            if label_criteria !== nothing
                push!(get!(label_criteria, sim_label, Float64[]), val)
                push!(get!(label_indices, sim_label, Int[]), i)
            end
        end
    end

    if multi_label
        _run_label_median_runs!(bp, configs, sim_seeds, label_criteria, label_indices, rd_style)
    else
        _run_median_run!(bp, configs, sim_seeds, criterion_values, rd_style)
    end

    return bp
end

function _run_median_run!(bp, configs, sim_seeds, criterion_values, rd_style)
    (isnothing(criterion_values) || isempty(criterion_values)) && return
    final_median = median(criterion_values)
    best_idx = argmin(abs(v - final_median) for v in criterion_values)
    printinfo("Re-running median simulation (config $best_idx)")
    rep_sim = Simulation(; configs[best_idx]..., seed = sim_seeds[best_idx])
    run!(rep_sim)
    bp.median_run = ResultData(PostProcessor(rep_sim), style = rd_style)
end

function _run_label_median_runs!(bp, configs, sim_seeds, label_criteria, label_indices, rd_style)
    isnothing(label_criteria) && return
    for (lab, criteria) in label_criteria
        indices = label_indices[lab]
        final_median = median(criteria)
        best_local = argmin(abs(v - final_median) for v in criteria)
        best_idx = indices[best_local]
        printinfo("Re-running median simulation for label \"$lab\" (config $best_idx)")
        rep_sim = Simulation(; configs[best_idx]..., seed = sim_seeds[best_idx])
        run!(rep_sim)
        bp.per_label[lab].median_run = ResultData(PostProcessor(rep_sim), style = rd_style)
    end
end
