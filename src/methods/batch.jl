export run!

"""
    run!(batch::Batch; representative_by=nothing, keep_rundata=false, rd_style="LightRD")

Run all simulation configurations in `batch` one at a time, accumulating results
into a `BatchProcessor`. Each simulation is created, run, and post-processed before
the next one starts, so peak memory is ~1× a single simulation regardless of batch size.

# Keyword Arguments

- `representative_by`: a function `pp::PostProcessor -> scalar` passed to `BatchProcessor`.
  The single `ResultData` whose criterion is closest to the running mean is kept.
  Example: `pp -> nrow(infectionsDF(pp))` for the run with mean total infections.
- `keep_rundata`: if `true`, every run's `ResultData` is stored in `bp.rundata`.
  Required for `merge(bds::BatchData...)`. Default: `false`.
- `rd_style`: the `ResultData` style used when creating the representative run or
  storing individual `ResultData` objects. Default: `"LightRD"`.

# Returns

A `BatchProcessor` with accumulated statistics from all runs.
"""
function run!(batch::Batch;
              representative_by::Union{Nothing, Function} = nothing,
              keep_rundata::Bool = false,
              rd_style::String = "LightRD")
    bp = BatchProcessor(; representative_by, keep_rundata)
    cnt = 0
    total = length(simconfigs(batch))
    for cfg in simconfigs(batch)
        printinfo("Running Simulation $(cnt += 1)/$total in Batch")
        sim = Simulation(; cfg...)
        run!(sim)
        pp = PostProcessor(sim)
        accumulate!(bp, pp; rd_style)
    end
    return bp
end
