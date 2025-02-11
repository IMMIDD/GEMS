export tick_deaths

"""
    tick_deaths(postProcessor::PostProcessor)

Returns a `DataFrame` containing the count of individuals that died per tick.

# Returns

- `DataFrame` with the following columns:

| Name            | Type    | Description                            |
| :-------------- | :------ | :------------------------------------- |
| `tick`          | `Int16` | Simulation tick (time)                 |
| `death_cnt`     | `Int64` | Number of individuals that dies        |

"""
function tick_deaths(postProcessor::PostProcessor)::DataFrame

    # load cached DF if available
    if in_cache(postProcessor, "tick_deaths")
        return(load_cache(postProcessor, "tick_deaths"))
    end

    deaths = deathsDF(postProcessor) |>
        x -> groupby(x, :tick) |>
        x -> combine(x, nrow => :death_cnt) |>
        x -> DataFrames.select(x, :tick, :death_cnt)

    res = (DataFrame(tick = 0:tick(simulation(postProcessor))) |> 
        x -> leftjoin(x, deaths, on = :tick) |>
        x -> coalesce.(x,0) |> 
        x -> sort(x, :tick))

    # cache dataframe
    store_cache(postProcessor, "tick_deaths", res)

    return(res)
end