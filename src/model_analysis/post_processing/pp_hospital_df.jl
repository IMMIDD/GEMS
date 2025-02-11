export hospital_df

"""
    hospital_df(postProcessor::PostProcessor)

Creates a DataFrame that includes information about the current hospitalizations etc.

# Returns

- `DataFrame` with the following columns:

| Name                  | Type    | Description                                         |
| :-------------------- | :------ | :-------------------------------------------------- |
| `tick`                | `Int16` | Simulation tick (time)                              |
| `hospital_cnt`        | `Int64` | New hospitalizations per tick                       |
| `hospital_releases`   | `Int64` | Hospital releases per tick                          |
| `icu_cnt`             | `Int64` | New ICU admissions per tick                         |
| `icu_releases`        | `Int64` | ICU releases per tick                               |
| `ventilation_cnt`     | `Int64` | New ventilations per tick                           |
| `ventilation_releases`| `Int64` | Ventilation stops                                   |
| `current_hospitalized`| `Int64` | Number of currently hospitalized agents             |
| `current_icu`         | `Int64` | Number of agents currently in the ICU               |
| `current_ventilation` | `Int64` | Number of currently ventilated agents               |

"""
function hospital_df(postProcessor::PostProcessor)

    hospital = infectionsDF(postProcessor) |>
    x -> filter(row -> row.hospital_tick != -1, x) |> 
    x -> groupby(x, :hospital_tick) |>
    x -> combine(x, nrow => :hospital_cnt) |>
    x -> DataFrames.select(x, :hospital_tick => :tick, :hospital_cnt)
    
    hospitalrel = infectionsDF(postProcessor) |>
    x -> filter(row -> row.hospital_tick != -1, x) |> 
    x -> groupby(x, :removed_tick) |>
    x -> combine(x, nrow => :hospital_releases) |>
    x -> DataFrames.select(x, :removed_tick => :tick, :hospital_releases)

    ventilation = infectionsDF(postProcessor) |>
    x -> filter(row -> row.hospital_tick != -1, x) |> 
    x -> groupby(x, :ventilation_tick) |>
    x -> combine(x, nrow => :ventilation_cnt) |>
    x -> DataFrames.select(x, :ventilation_tick => :tick, :ventilation_cnt)
    
    ventilationrel = infectionsDF(postProcessor) |>
    x -> filter(row -> row.ventilation_tick != -1, x) |> 
    x -> groupby(x, :removed_tick) |>
    x -> combine(x, nrow => :ventilation_releases) |>
    x -> DataFrames.select(x, :removed_tick => :tick, :ventilation_releases)

    icu = infectionsDF(postProcessor) |>
    x -> filter(row -> row.hospital_tick != -1, x) |> 
    x -> groupby(x, :icu_tick) |>
    x -> combine(x, nrow => :icu_cnt) |>
    x -> DataFrames.select(x, :icu_tick => :tick, :icu_cnt)
    
    icurel = infectionsDF(postProcessor) |>
    x -> filter(row -> row.icu_tick != -1, x) |> 
    x -> groupby(x, :removed_tick) |>
    x -> combine(x, nrow => :icu_releases) |>
    x -> DataFrames.select(x, :removed_tick => :tick, :icu_releases)
    
    hospital_df = DataFrame(tick = 0:tick(simulation(postProcessor))) |>
    x -> leftjoin(x, hospital, on = :tick) |>
    x -> leftjoin(x, hospitalrel, on = :tick) |>
    x -> leftjoin(x, icu, on = :tick) |>
    x -> leftjoin(x, icurel, on = :tick) |>
    x -> leftjoin(x, ventilation, on = :tick) |>
    x -> leftjoin(x, ventilationrel, on = :tick) |>
    x -> sort(x, :tick) |>
    x -> mapcols(col -> replace(col, missing => 0), x)
    
    hospital_df.current_hospitalized = cumsum(hospital_df.hospital_cnt) .- cumsum(hospital_df.hospital_releases)
    hospital_df.current_icu = cumsum(hospital_df.icu_cnt) .- cumsum(hospital_df.icu_releases)
    hospital_df.current_ventilation = cumsum(hospital_df.ventilation_cnt) .- cumsum(hospital_df.ventilation_releases)

    return hospital_df
end