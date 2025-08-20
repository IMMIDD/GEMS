export compartment_fill

"""
    compartment_fill(postProcessor::PostProcessor)

Returns a `DataFrame` containing the total count of infected individuals in the respective
disease states exposed, infectious, deceased and recovered.

# Returns

- `DataFrame` with the following columns:

| Name             | Type    | Description                                         |
| :--------------- | :------ | :-------------------------------------------------- |
| `tick`           | `Int16` | Simulation tick (time)                              |
| `exposed_cnt`    | `Int64` | Total number of individuals in the exposed state    |
| `infectious_cnt` | `Int64` | Total number of individuals in the infectious state |
| `recovered_cnt`  | `Int64` | Total number of individuals in the recovered state  |
| `deaths_cnt`     | `Int64` | Total number of individuals in the deceased state   |

"""
function compartment_fill(postProcessor::PostProcessor)::DataFrame

    # raw infections data frame required for "detected_cnt"
    infs = infectionsDF(postProcessor)

    cases = tick_cases(postProcessor)
    deaths = tick_deaths(postProcessor)

    res = DataFrame(
        tick = cases.tick,
        exposed_cnt = zeros(nrow(cases)),
        infectious_cnt = zeros(nrow(cases)),
        deaths_cnt = zeros(nrow(cases)),
        recovered_cnt = zeros(nrow(cases)),
        detected_cnt = zeros(nrow(cases))
    )
    
    for i in 1:nrow(res)
        res[i, "exposed_cnt"] = i == 1 ? cases[1, "exposed_cnt"] - cases[1, "infectious_cnt"] : res[i-1, "exposed_cnt"] + cases[i, "exposed_cnt"] - cases[i, "infectious_cnt"]
        res[i, "infectious_cnt"] = i == 1 ? cases[1, "infectious_cnt"] : res[i-1, "infectious_cnt"] + cases[i, "infectious_cnt"] - cases[i, "removed_cnt"]
        res[i, "detected_cnt"] = isempty(infs) ? 0 : sum((infs.tick .<= i .< infs.removed_tick) .& (coalesce.(infs.first_detected_tick, Inf) .<= i))
    end
    res[!, "deaths_cnt"] = cumsum(deaths[!, "death_cnt"])
    res[!, "recovered_cnt"] = cumsum(cases[!, "removed_cnt"]) .- res[!, "deaths_cnt"]

    return res
end