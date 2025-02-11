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
        x -> groupby(x, :infectious_tick) |>
        x -> combine(x, nrow => :infectious_cnt) |>
        x -> DataFrames.select(x, :infectious_tick => :tick, :infectious_cnt)

    removed = infectionsDF(postProcessor) |>
        x -> groupby(x, :removed_tick) |>
        x -> combine(x, nrow => :removed_cnt) |>
        x -> DataFrames.select(x, :removed_tick => :tick, :removed_cnt)

    res = DataFrame(tick = 0:tick(simulation(postProcessor))) |>
        x -> leftjoin(x, exposed, on = :tick) |>
        x -> leftjoin(x, infectious, on = :tick) |>
        x -> leftjoin(x, removed, on = :tick) |>
        x -> DataFrames.select(x, :tick,
            :exposed_cnt => ByRow(x -> coalesce(x, 0)) => :exposed_cnt,
            :infectious_cnt => ByRow(x -> coalesce(x, 0)) => :infectious_cnt,
            :removed_cnt => ByRow(x -> coalesce(x, 0)) => :removed_cnt) |>
        x -> sort(x, :tick)

    # cache dataframe
    store_cache(postProcessor, "tick_cases", res)

    return(res)
end