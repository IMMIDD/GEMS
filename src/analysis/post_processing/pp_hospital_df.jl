
"""
    _hospital_df(postProcessor::PostProcessor)

Creates a DataFrame with host-level hospital/ICU/ventilation occupancy over time. These
are host states (not per-pathogen), read from the simulation's `HealthLogger`.

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
function _hospital_df(postProcessor::PostProcessor)

    sim = simulation(postProcessor)
    events = dataframe(healthlogger(sim))
    base = DataFrame(tick = collect(Int16, 0:tick(sim)))

    # number of events of the given type per tick
    function _counts(event::Symbol, name::Symbol)
        sub = subset(events, :event => ByRow(==(event)), view = true)
        return DataFrames.select(combine(groupby(sub, :tick), nrow => name), :tick, name)
    end

    result = leftjoin!(base, _counts(:hospital_admission, :hospital_admissions), on = :tick)
    leftjoin!(result, _counts(:hospital_discharge, :hospital_discharges), on = :tick)
    leftjoin!(result, _counts(:icu_admission, :icu_admissions), on = :tick)
    leftjoin!(result, _counts(:icu_discharge, :icu_discharges), on = :tick)
    leftjoin!(result, _counts(:ventilation_admission, :ventilation_admissions), on = :tick)
    leftjoin!(result, _counts(:ventilation_discharge, :ventilation_discharges), on = :tick)
    sort!(result, :tick)
    mapcols!(col -> replace(col, missing => 0), result)

    # current occupancy per tick
    transform!(result,
        [:hospital_admissions, :hospital_discharges] => ((a, d) -> cumsum(a) .- cumsum(d)) => :current_hospitalized,
        [:icu_admissions, :icu_discharges] => ((a, d) -> cumsum(a) .- cumsum(d)) => :current_icu,
        [:ventilation_admissions, :ventilation_discharges] => ((a, d) -> cumsum(a) .- cumsum(d)) => :current_ventilation
    )

    return result
end
