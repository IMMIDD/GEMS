export cumulative_deaths

"""
    cumulative_deaths(postProcessor::PostProcessor)

Returns a `DataFrame` containing the total count of individuals that died, per pathogen.

# Returns

- `DataFrame` with the following columns:

| Name             | Type    | Description                                          |
| :--------------- | :------ | :--------------------------------------------------- |
| `tick`           | `Int16` | Simulation tick (time)                               |
| `pathogen_id`    | `Int8`  | Pathogen identifier                                  |
| `deaths_cum`     | `Int64` | Total number of individuals that have died until now |

"""
function cumulative_deaths(postProcessor::PostProcessor)::DataFrame

    return tick_cases(postProcessor) |>
        df -> transform(groupby(df, :pathogen_id),
            :dead_cnt => cumsum => :deaths_cum) |>
        df -> DataFrames.select(df, :tick, :pathogen_id, :deaths_cum)
end
