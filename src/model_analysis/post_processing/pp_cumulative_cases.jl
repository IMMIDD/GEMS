export cumulative_cases

"""
    cumulative_cases(postProcessor::PostProcessor)

Returns a `DataFrame` containing the cumulative infections count of infected individuals in the respective
disease states exposed, infectious, and removed.

# Returns

- `DataFrame` with the following columns:

| Name             | Type    | Description                                         |
| :--------------- | :------ | :-------------------------------------------------- |
| `tick`           | `Int16` | Simulation tick (time)                              |
| `exposed_cum`    | `Int64` | Total number of individuals in the exposed state    |
| `infectious_cum` | `Int64` | Total number of individuals in the infectious state |
| `removed_cum`    | `Int64` | Total number of individuals in the removed state    |

"""
function cumulative_cases(postProcessor::PostProcessor)::DataFrame

    # load cached DF if available
    if in_cache(postProcessor, "cumulative_cases")
        return(load_cache(postProcessor, "cumulative_cases"))
    end

    cases = tick_cases(postProcessor)
    deaths = tick_deaths(postProcessor)

    res = DataFrame(
        exposed_cum = zeros(nrow(cases)),
        infectious_cum = zeros(nrow(cases)),
        recovered_cum = zeros(nrow(cases)),
        deaths_cum = zeros(nrow(cases))
    )
    
    for i in 1:nrow(res)
        res[i, "exposed_cum"] = i == 1 ? cases[1, "exposed_cnt"] : res[i-1, "exposed_cum"] + cases[i, "exposed_cnt"] - cases[i, "infectious_cnt"]
        res[i, "infectious_cum"] = i == 1 ? cases[1, "infectious_cnt"] : res[i-1, "infectious_cum"] + cases[i, "infectious_cnt"] - cases[i, "removed_cnt"]
        res[i, "deaths_cum"] = i == 1 ? deaths[1, "death_cnt"] : res[i-1, "deaths_cum"] + deaths[i, "death_cnt"]
    end
    res[!, "exposed_cum"] = cumsum(cases[!, "exposed_cnt"])
    res[!, "infectious_cum"] = cumsum(cases[!, "infectious_cnt"])
    res[!, "deaths_cum"] = cumsum(deaths[!, "death_cnt"])
    res[!, "recovered_cum"] = cumsum(cases[!, "removed_cnt"]) .- res[!, "deaths_cum"]


    # cache dataframe
    store_cache(postProcessor, "cumulative_cases", res)

    return res
end