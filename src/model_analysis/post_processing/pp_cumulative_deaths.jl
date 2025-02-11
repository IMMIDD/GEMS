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

    deaths = tick_deaths(postProcessor)

    res = DataFrame(
        death_cum = zeros(nrow(deaths))
    )
    
    for i in 1:nrow(res)
        res[i, "death_cum"] = i == 1 ? deaths[1, "death_cnt"] : res[i-1, "death_cum"] + deaths[i, "death_cnt"]
    end

    return res
end