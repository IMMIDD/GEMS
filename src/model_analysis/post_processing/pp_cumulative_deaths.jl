export cumulative_deaths

"""
    cumulative_deaths(postProcessor::PostProcessor)

Returns a `DataFrame` containing the total count of individuals that died.

# Returns

- `DataFrame` with the following columns:

| Name             | Type    | Description                                          |
| :--------------- | :------ | :--------------------------------------------------- |
| `tick`           | `Int16` | Simulation tick (time)                               |
| `deaths_cum`     | `Int64` | Total number of individuals that have died until now |

"""
function cumulative_deaths(postProcessor::PostProcessor)::DataFrame

    return tick_cases(postProcessor) |>
        df -> DataFrame(
            tick = df.tick,
            deaths_cum = cumsum(df.dead_cnt)
        )
end