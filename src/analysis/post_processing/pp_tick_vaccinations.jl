export tick_vaccinations

"""
    tick_vaccinations(postProcessor::PostProcessor)

Returns a `DataFrame` containing the count of vaccine doses given per tick and pathogen.

# Returns

- `DataFrame` with the following columns:

| Name              | Type    | Description                            |
| :---------------- | :------ | :------------------------------------- |
| `tick`            | `Int16` | Simulation tick (time)                 |
| `pathogen_id`     | `Int8`  | Pathogen identifier                    |
| `vaccination_cnt` | `Int64` | Number of vaccine doses given          |
| `first_dose_cnt`  | `Int64` | Number of those that were first doses  |

"""
function tick_vaccinations(postProcessor::PostProcessor)::DataFrame

    # load cached DF if available
    if in_cache(postProcessor, "tick_vaccinations")
        return(load_cache(postProcessor, "tick_vaccinations"))
    end

    vaccinations = vaccinationsDF(postProcessor) |>
        x -> groupby(x, [:tick, :pathogen_id]) |>
        x -> combine(x, nrow => :vaccination_cnt, :dose_number => (d -> count(==(1), d)) => :first_dose_cnt) |>
        x -> DataFrames.select(x, :tick, :pathogen_id, :vaccination_cnt, :first_dose_cnt)

    base = crossjoin(
        DataFrame(tick = collect(Int16, 0:tick(simulation(postProcessor)))),
        DataFrame(pathogen_id = collect(map(id, pathogens(simulation(postProcessor))))))

    res = leftjoin!(base, vaccinations, on = [:tick, :pathogen_id]) |>
        x -> transform!(x, [:vaccination_cnt, :first_dose_cnt] .=> ByRow(x -> coalesce(x, 0)) .=> [:vaccination_cnt, :first_dose_cnt]) |>
        x -> sort!(x, [:pathogen_id, :tick])

    # cache dataframe
    store_cache(postProcessor, "tick_vaccinations", res)

    return(res)
end
