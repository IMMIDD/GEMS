export process!

"""
    process!(batch::Batch; representative_by=nothing, keep_rundata=false, rd_style="LightRD")

Run and post-process all simulation configurations in `batch` one at a time, accumulating
results into a `BatchProcessor`. Each simulation is created, run, post-processed, and
discarded before the next one starts, so peak memory is ~1× a single simulation regardless
of batch size.

When the batch contains simulations with multiple distinct labels, per-label statistics
are accumulated separately and exposed via `per_label(bd)`. The top-level `BatchProcessor`
fields always reflect the merged aggregate across all labels.

# Keyword Arguments

- `representative_by`: a function `pp::PostProcessor -> scalar` passed to `BatchProcessor`.
  The single `ResultData` whose criterion is closest to the running median is kept.
  Example: `pp -> nrow(infectionsDF(pp))` for the run with median total infections.
- `keep_rundata`: if `true`, every run's `ResultData` is stored in `bp.rundata`.
  Required for `merge(bds::BatchData...)`. Default: `false`.
- `rd_style`: the `ResultData` style used when creating the representative run or
  storing individual `ResultData` objects. Default: `"LightRD"`.

# Returns

A `BatchProcessor` with accumulated statistics from all runs.
"""
function process!(batch::Batch;
    representative_by::Union{Nothing, Function} = nothing,
    keep_rundata::Bool = false,
    rd_style::String = "LightRD"
)
    configs = simconfigs(batch)
    cfg_labels = [string(get(cfg, :label, "")) for cfg in configs]
    multi_label = length(unique(cfg_labels)) > 1

    bp = BatchProcessor(; representative_by, keep_rundata)
    cnt = 0
    total = length(configs)

    for (cfg, sim_label) in zip(configs, cfg_labels)
        printinfo("Processing Simulation $(cnt += 1)/$total in Batch")
        sim = Simulation(; cfg...)
        run!(sim)
        pp = PostProcessor(sim)
        accumulate!(bp, pp; rd_style)
        if multi_label
            if !haskey(bp.per_label, sim_label)
                bp.per_label[sim_label] = BatchProcessor()
            end
            accumulate!(bp.per_label[sim_label], pp; rd_style)
        end
    end

    return bp
end
