export tick_cases

"""
    tick_cases(postProcessor::PostProcessor)

Returns a `DataFrame` containing the count of individuals currently entering in the
respective disease states exposed, infectious, recovered, and deceased, per pathogen.

# Returns

- `DataFrame` with the following columns:

| Name             | Type    | Description                                         |
| :--------------- | :------ | :-------------------------------------------------- |
| `tick`           | `Int16` | Simulation tick (time)                              |
| `pathogen_id`    | `Int8`  | Pathogen identifier                                 |
| `exposed_cnt`    | `Int64` | Number of individuals entering the exposed state    |
| `infectious_cnt` | `Int64` | Number of individuals entering the infectious state |
| `recovered_cnt`  | `Int64` | Number of individuals recovering                    |
| `dead_cnt`       | `Int64` | Number of individuals dying                         |
"""
function tick_cases(postProcessor::PostProcessor)::DataFrame

    # load cached DF if available
    if in_cache(postProcessor, "tick_cases")
        return(load_cache(postProcessor, "tick_cases"))
    end

    infs = infectionsDF(postProcessor)
    base = crossjoin(
        DataFrame(tick = collect(Int16, 0:tick(simulation(postProcessor)))),
        DataFrame(pathogen_id = collect(map(id, pathogens(simulation(postProcessor))))))

    exposed = groupby(infs, [:tick, :pathogen_id]) |>
        x -> combine(x, nrow => :exposed_cnt)

    infectious = groupby(infs, [:infectiousness_onset, :pathogen_id]) |>
        x -> combine(x, nrow => :infectious_cnt) |>
        x -> DataFrames.select(x, :infectiousness_onset => :tick, :pathogen_id, :infectious_cnt)

    recovered = groupby(infs, [:recovery, :pathogen_id]) |>
        x -> combine(x, nrow => :recovered_cnt) |>
        x -> DataFrames.select(x, :recovery => :tick, :pathogen_id, :recovered_cnt)

    dead = groupby(infs, [:death, :pathogen_id]) |>
        x -> combine(x, nrow => :dead_cnt) |>
        x -> DataFrames.select(x, :death => :tick, :pathogen_id, :dead_cnt)

    res = leftjoin!(base, exposed, on = [:tick, :pathogen_id])
    leftjoin!(res, infectious, on = [:tick, :pathogen_id])
    leftjoin!(res, recovered, on = [:tick, :pathogen_id])
    leftjoin!(res, dead, on = [:tick, :pathogen_id])
    select!(res, :tick, :pathogen_id,
        :exposed_cnt => ByRow(x -> coalesce(x, 0)) => :exposed_cnt,
        :infectious_cnt => ByRow(x -> coalesce(x, 0)) => :infectious_cnt,
        :recovered_cnt => ByRow(x -> coalesce(x, 0)) => :recovered_cnt,
        :dead_cnt => ByRow(x -> coalesce(x, 0)) => :dead_cnt)
    sort!(res, [:pathogen_id, :tick])

    # cache dataframe
    store_cache(postProcessor, "tick_cases", res)

    return(res)
end
