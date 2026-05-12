export hospital_df

"""
    hospital_df(postProcessor::PostProcessor)

Creates a DataFrame that includes information about the current hospitalizations etc., per pathogen.

# Returns

- `DataFrame` with the following columns:

| Name                     | Type    | Description                                               |
| :----------------------- | :------ | :-------------------------------------------------------- |
| `tick`                   | `Int16` | Simulation tick (time)                                    |
| `pathogen_id`            | `Int8`  | Pathogen identifier                                       |
| `hospital_admissions`    | `Int64` | Number of individuals admitted to hospital at tick        |
| `hospital_discharges`    | `Int64` | Number of individuals discharged from hospital at tick    |
| `icu_admissions`         | `Int64` | Number of individuals admitted to ICU at tick             |
| `icu_discharges`         | `Int64` | Number of individuals discharged from ICU at tick         |
| `ventilation_admissions` | `Int64` | Number of individuals admitted to ventilation at tick     |
| `ventilation_discharges` | `Int64` | Number of individuals discharged from ventilation at tick |
| `current_hospitalized`   | `Int64` | Current number of individuals in hospital at tick         |
| `current_icu`            | `Int64` | Current number of individuals in ICU at tick              |
| `current_ventilation`    | `Int64` | Current number of individuals on ventilation at tick      |
"""
function hospital_df(postProcessor::PostProcessor)

    infs = infectionsDF(postProcessor)
    base = crossjoin(
        DataFrame(tick = collect(Int16, 0:tick(simulation(postProcessor)))),
        DataFrame(pathogen_id = map(id, pathogens(simulation(postProcessor)))))

    hospital_admissions = infs |>
        df -> DataFrames.select(df, :tick, :pathogen_id, :hospital_admission) |>
        df -> subset(df, :hospital_admission => ByRow(>=(0)), view=true) |>
        df -> groupby(df, [:hospital_admission, :pathogen_id]) |>
        df -> combine(df, nrow => :hospital_admissions) |>
        df -> DataFrames.select(df, :hospital_admission => :tick, :pathogen_id, :hospital_admissions)

    hospital_discharges = infs |>
        df -> DataFrames.select(df, :tick, :pathogen_id, :hospital_discharge) |>
        df -> subset(df, :hospital_discharge => ByRow(>=(0)), view=true) |>
        df -> groupby(df, [:hospital_discharge, :pathogen_id]) |>
        df -> combine(df, nrow => :hospital_discharges) |>
        df -> DataFrames.select(df, :hospital_discharge => :tick, :pathogen_id, :hospital_discharges)

    icu_admissions = infs |>
        df -> DataFrames.select(df, :tick, :pathogen_id, :icu_admission) |>
        df -> subset(df, :icu_admission => ByRow(>=(0)), view=true) |>
        df -> groupby(df, [:icu_admission, :pathogen_id]) |>
        df -> combine(df, nrow => :icu_admissions) |>
        df -> DataFrames.select(df, :icu_admission => :tick, :pathogen_id, :icu_admissions)

    icu_discharges = infs |>
        df -> DataFrames.select(df, :tick, :pathogen_id, :icu_discharge) |>
        df -> subset(df, :icu_discharge => ByRow(>=(0)), view=true) |>
        df -> groupby(df, [:icu_discharge, :pathogen_id]) |>
        df -> combine(df, nrow => :icu_discharges) |>
        df -> DataFrames.select(df, :icu_discharge => :tick, :pathogen_id, :icu_discharges)

    ventilation_admissions = infs |>
        df -> DataFrames.select(df, :tick, :pathogen_id, :ventilation_admission) |>
        df -> subset(df, :ventilation_admission => ByRow(>=(0)), view=true) |>
        df -> groupby(df, [:ventilation_admission, :pathogen_id]) |>
        df -> combine(df, nrow => :ventilation_admissions) |>
        df -> DataFrames.select(df, :ventilation_admission => :tick, :pathogen_id, :ventilation_admissions)

    ventilation_discharges = infs |>
        df -> DataFrames.select(df, :tick, :pathogen_id, :ventilation_discharge) |>
        df -> subset(df, :ventilation_discharge => ByRow(>=(0)), view=true) |>
        df -> groupby(df, [:ventilation_discharge, :pathogen_id]) |>
        df -> combine(df, nrow => :ventilation_discharges) |>
        df -> DataFrames.select(df, :ventilation_discharge => :tick, :pathogen_id, :ventilation_discharges)

    result = leftjoin!(base, hospital_admissions, on = [:tick, :pathogen_id])
    leftjoin!(result, hospital_discharges, on = [:tick, :pathogen_id])
    leftjoin!(result, icu_admissions, on = [:tick, :pathogen_id])
    leftjoin!(result, icu_discharges, on = [:tick, :pathogen_id])
    leftjoin!(result, ventilation_admissions, on = [:tick, :pathogen_id])
    leftjoin!(result, ventilation_discharges, on = [:tick, :pathogen_id])
    sort!(result, [:pathogen_id, :tick])
    mapcols!(col -> replace(col, missing => 0), result)

    # cumulative current counts per pathogen
    transform!(groupby(result, :pathogen_id),
        [:hospital_admissions, :hospital_discharges] => ((a, d) -> cumsum(a) .- cumsum(d)) => :current_hospitalized,
        [:icu_admissions, :icu_discharges] => ((a, d) -> cumsum(a) .- cumsum(d)) => :current_icu,
        [:ventilation_admissions, :ventilation_discharges] => ((a, d) -> cumsum(a) .- cumsum(d)) => :current_ventilation
    )

    return result
end
