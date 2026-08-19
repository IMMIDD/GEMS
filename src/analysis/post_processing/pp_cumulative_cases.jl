export cumulative_cases

"""
    cumulative_cases(postProcessor::PostProcessor)

Calculates the cumulative counts of simulated infections (exposures), recoveries, and deaths over time
and returns a `DataFrame` containing these cumulative counts for each tick, per pathogen.

If individuals can get reinfected, the cumulative counts will reflect the total number of events,
including multiple infections, recoveries, and deaths for the same individual.

# Returns

- `DataFrame` with the following columns:

| Name             | Type    | Description                                                |
| :--------------- | :------ | :--------------------------------------------------------- |
| `tick`           | `Int16` | Simulation tick (time)                                     |
| `pathogen_id`    | `Int8`  | Pathogen identifier                                        |
| `exposed_cum`    | `Int64` | Cumulative number of individuals infected up to this tick  |
| `recovered_cum`  | `Int64` | Cumulative number of individuals recovered up to this tick |
| `deaths_cum`     | `Int64` | Cumulative number of individuals deceased up to this tick  |
"""
function cumulative_cases(postProcessor::PostProcessor)::DataFrame

    # load cached DF if available
    if in_cache(postProcessor, "cumulative_cases")
        return(load_cache(postProcessor, "cumulative_cases"))
    end

    res = tick_cases(postProcessor) |>
        df -> transform(groupby(df, :pathogen_id),
            :exposed_cnt => cumsum => :exposed_cum,
            :recovered_cnt => cumsum => :recovered_cum,
            :dead_cnt => cumsum => :deaths_cum) |>
        df -> DataFrames.select(df, :tick, :pathogen_id, :exposed_cum, :recovered_cum, :deaths_cum)

    # cache dataframe
    store_cache(postProcessor, "cumulative_cases", res)

    return res
end
