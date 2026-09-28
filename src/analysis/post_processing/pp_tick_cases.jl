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
| `dead_cnt`       | `Int64` | Number of individuals dying, attributed to this pathogen |

A host death is credited to exactly one pathogen (the one the `HealthProgression` drew it from),
so `dead_cnt` summed over pathogens is the total number of deaths.
"""
function tick_cases(postProcessor::PostProcessor)::DataFrame

    # load cached DF if available
    if in_cache(postProcessor, "tick_cases")
        return(load_cache(postProcessor, "tick_cases"))
    end

    infs = infectionsDF(postProcessor)
    deaths = deathsDF(postProcessor)
    final_tick = tick(simulation(postProcessor))
    # rows are sorted by pathogen, then tick
    pathogen_ids = sort(collect(map(id, pathogens(simulation(postProcessor)))))
    counts(ticks, pids) = vec(_tick_counts(ticks, pids, pathogen_ids, final_tick))

    res = DataFrame(
        tick = repeat(collect(Int16, 0:final_tick), outer = length(pathogen_ids)),
        pathogen_id = repeat(pathogen_ids, inner = final_tick + 1),
        exposed_cnt = counts(infs.tick, infs.pathogen_id),
        infectious_cnt = counts(infs.infectiousness_onset, infs.pathogen_id),
        recovered_cnt = counts(infs.recovery, infs.pathogen_id),
        # a host death is one event attributed to one pathogen, so it comes from the death log
        dead_cnt = counts(deaths.tick, deaths.pathogen_id))

    # cache dataframe
    store_cache(postProcessor, "tick_cases", res)

    return(res)
end

# Rows per tick (0:final_tick) and pathogen, as a ticks × pathogens matrix; other ticks and pathogens are skipped
function _tick_counts(ticks::AbstractVector, pids::AbstractVector, pathogen_ids::Vector, final_tick::Integer)
    counts = zeros(Int, final_tick + 1, length(pathogen_ids))
    for (t, pid) in zip(ticks, pids)
        (ismissing(t) || ismissing(pid) || !(0 <= t <= final_tick)) && continue
        p = findfirst(==(pid), pathogen_ids)
        p === nothing || (counts[t + 1, p] += 1)
    end
    return counts
end
