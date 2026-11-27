export cumulative_vaccinations

"""
    cumulative_vaccinations(postProcessor::PostProcessor)

Returns a `DataFrame` containing the total count of vaccine doses given and of vaccinated individuals, per pathogen.

# Returns

- `DataFrame` with the following columns:

| Name               | Type    | Description                                    |
| :----------------- | :------ | :--------------------------------------------- |
| `tick`             | `Int16` | Simulation tick (time)                         |
| `pathogen_id`      | `Int8`  | Pathogen identifier                            |
| `vaccinations_cum` | `Int64` | Total number of vaccine doses given until now  |
| `vaccinated_cum`   | `Int64` | Individuals with at least one dose until now   |

"""
function cumulative_vaccinations(postProcessor::PostProcessor)::DataFrame

    return tick_vaccinations(postProcessor) |>
        df -> transform(groupby(df, :pathogen_id),
            :vaccination_cnt => cumsum => :vaccinations_cum,
            :first_dose_cnt => cumsum => :vaccinated_cum) |>
        df -> DataFrames.select(df, :tick, :pathogen_id, :vaccinations_cum, :vaccinated_cum)
end
