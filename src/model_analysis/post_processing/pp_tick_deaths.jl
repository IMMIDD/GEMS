export tick_deaths

"""
    tick_deaths(postProcessor::PostProcessor)

Returns a `DataFrame` containing the count of individuals that died per tick and pathogen.

# Returns

- `DataFrame` with the following columns:

| Name          | Type    | Description                            |
| :------------ | :------ | :------------------------------------- |
| `tick`        | `Int16` | Simulation tick (time)                 |
| `pathogen_id` | `Int8`  | Pathogen identifier                    |
| `death_cnt`   | `Int64` | Number of individuals that died        |

"""
function tick_deaths(postProcessor::PostProcessor)::DataFrame

    # load cached DF if available
    if in_cache(postProcessor, "tick_deaths")
        return(load_cache(postProcessor, "tick_deaths"))
    end

    deaths = deathsDF(postProcessor) |>
        x -> groupby(x, [:tick, :pathogen_id]) |>
        x -> combine(x, nrow => :death_cnt) |>
        x -> DataFrames.select(x, :tick, :pathogen_id, :death_cnt)

    base = crossjoin(
        DataFrame(tick = collect(Int16, 0:tick(simulation(postProcessor)))),
        DataFrame(pathogen_id = map(id, pathogens(simulation(postProcessor)))))

    res = leftjoin!(base, deaths, on = [:tick, :pathogen_id]) |>
        x -> transform!(x, :death_cnt => ByRow(x -> coalesce(x, 0)) => :death_cnt) |>
        x -> sort!(x, [:pathogen_id, :tick])

    # cache dataframe
    store_cache(postProcessor, "tick_deaths", res)

    return(res)
end
