export hospital_df

"""
    hospital_df(postProcessor::PostProcessor)

Creates a DataFrame that includes information about the current hospitalizations etc.

# Returns

- `DataFrame` with the following columns:

| Name                     | Type    | Description                                               |
| :----------------------- | :------ | :-------------------------------------------------------- |
| `tick`                   | `Int16` | Simulation tick (time)                                    |
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

    hospital_admissions = infectionsDF(postProcessor) |>
        df -> DataFrames.select(df, :tick, :hospital_admission) |>
        df -> df[df.hospital_admission .>= 0, :] |>
        df -> groupby(df, :hospital_admission) |>
        df -> combine(df, nrow => :hospital_admissions) |>
        df -> DataFrames.select(df, :hospital_admission => :tick, :hospital_admissions)

    hospital_discharges = infectionsDF(postProcessor) |>
        df -> DataFrames.select(df, :tick, :hospital_discharge) |>
        df -> df[df.hospital_discharge .>= 0, :] |>
        df -> groupby(df, :hospital_discharge) |>
        df -> combine(df, nrow => :hospital_discharges) |>
        df -> DataFrames.select(df, :hospital_discharge => :tick, :hospital_discharges)

    icu_admissions = infectionsDF(postProcessor) |>
        df -> DataFrames.select(df, :tick, :icu_admission) |>
        df -> df[df.icu_admission .>= 0, :] |>
        df -> groupby(df, :icu_admission) |>
        df -> combine(df, nrow => :icu_admissions) |>
        df -> DataFrames.select(df, :icu_admission => :tick, :icu_admissions)

    icu_discharges = infectionsDF(postProcessor) |>
        df -> DataFrames.select(df, :tick, :icu_discharge) |>
        df -> df[df.icu_discharge .>= 0, :] |>
        df -> groupby(df, :icu_discharge) |>
        df -> combine(df, nrow => :icu_discharges) |>
        df -> DataFrames.select(df, :icu_discharge => :tick, :icu_discharges)

    ventilation_admissions = infectionsDF(postProcessor) |>
        df -> DataFrames.select(df, :tick, :ventilation_admission) |>
        df -> df[df.ventilation_admission .>= 0, :] |>
        df -> groupby(df, :ventilation_admission) |>
        df -> combine(df, nrow => :ventilation_admissions) |>
        df -> DataFrames.select(df, :ventilation_admission => :tick, :ventilation_admissions)

    ventilation_discharges = infectionsDF(postProcessor) |>
        df -> DataFrames.select(df, :tick, :ventilation_discharge) |>
        df -> df[df.ventilation_discharge .>= 0, :] |>
        df -> groupby(df, :ventilation_discharge) |>
        df -> combine(df, nrow => :ventilation_discharges) |>
        df -> DataFrames.select(df, :ventilation_discharge => :tick, :ventilation_discharges)

    
    hospital_df = DataFrame(tick = 0:tick(simulation(postProcessor))) |>
        df -> leftjoin(df, hospital_admissions, on = :tick) |>
        df -> leftjoin(df, hospital_discharges, on = :tick) |>
        df -> leftjoin(df, icu_admissions, on = :tick) |>
        df -> leftjoin(df, icu_discharges, on = :tick) |>
        df -> leftjoin(df, ventilation_admissions, on = :tick) |>
        df -> leftjoin(df, ventilation_discharges, on = :tick) |>
        df -> sort(df, :tick) |>
        df -> mapcols(col -> replace(col, missing => 0), df)

    hospital_df.current_hospitalized = cumsum(hospital_df.hospital_admissions) .- cumsum(hospital_df.hospital_discharges)
    hospital_df.current_icu = cumsum(hospital_df.icu_admissions) .- cumsum(hospital_df.icu_discharges)
    hospital_df.current_ventilation = cumsum(hospital_df.ventilation_admissions) .- cumsum(hospital_df.ventilation_discharges)

    return hospital_df
end