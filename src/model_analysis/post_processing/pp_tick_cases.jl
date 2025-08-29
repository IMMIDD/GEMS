export tick_cases

"""
    tick_cases(postProcessor::PostProcessor)

Returns a `DataFrame` containing the count of individuals currently entering in the
respective disease states exposed, infectious, and removed.

# Returns

- `DataFrame` with the following columns:

| Name             | Type    | Description                                         |
| :--------------- | :------ | :-------------------------------------------------- |
| `tick`           | `Int16` | Simulation tick (time)                              |
| `exposed_cnt`    | `Int64` | Number of individuals entering the exposed state    |
| `infectious_cnt` | `Int64` | Number of individuals entering the infectious state |
| `removed_cnt`    | `Int64` | Number of individuals entering the removed state    |

"""
function tick_cases(postProcessor::PostProcessor)::DataFrame

    # load cached DF if available
    if in_cache(postProcessor, "tick_cases")
        return(load_cache(postProcessor, "tick_cases"))
    end

    exposed = infectionsDF(postProcessor) |>
        x -> groupby(x, :tick) |>
        x -> combine(x, nrow => :exposed_cnt) |>
        x -> DataFrames.select(x, :tick, :exposed_cnt)
    
    infectious = infectionsDF(postProcessor) |>
        x -> groupby(x, :infectiousness_onset) |>
        x -> combine(x, nrow => :infectious_cnt) |>
        x -> DataFrames.select(x, :infectiousness_onset => :tick, :infectious_cnt)

    recovered = infectionsDF(postProcessor) |>
        x -> groupby(x, :recovery) |>
        x -> combine(x, nrow => :recovered_cnt) |>
        x -> DataFrames.select(x, :recovery => :tick, :recovered_cnt)

    dead = infectionsDF(postProcessor) |>
        x -> groupby(x, :death) |>
        x -> combine(x, nrow => :dead_cnt) |>
        x -> DataFrames.select(x, :death => :tick, :dead_cnt)

    res = DataFrame(tick = 0:tick(simulation(postProcessor))) |>
        x -> leftjoin(x, exposed, on = :tick) |>
        x -> leftjoin(x, infectious, on = :tick) |>
        x -> leftjoin(x, recovered, on = :tick) |>
        x -> leftjoin(x, dead, on = :tick) |>
        x -> DataFrames.select(x, :tick,
            :exposed_cnt => ByRow(x -> coalesce(x, 0)) => :exposed_cnt,
            :infectious_cnt => ByRow(x -> coalesce(x, 0)) => :infectious_cnt,
            :recovered_cnt => ByRow(x -> coalesce(x, 0)) => :recovered_cnt,
            :dead_cnt => ByRow(x -> coalesce(x, 0)) => :dead_cnt) |>
        x -> sort(x, :tick)

    # cache dataframe
    store_cache(postProcessor, "tick_cases", res)

    return(res)
end