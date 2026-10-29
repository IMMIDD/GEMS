
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
    events = healthDF(postProcessor)
    base = DataFrame(tick = collect(Int16, 0:tick(sim)))

    # all event types counted per tick in one pass over the events
    event_types = [:hospital_admission, :hospital_discharge, :icu_admission, :icu_discharge,
        :ventilation_admission, :ventilation_discharge]
    counts = _events_per_tick(events.tick, events.event, event_types, tick(sim))

    result = base
    for (i, event) in enumerate(event_types)
        result[!, Symbol(string(event, "s"))] = counts[:, i]
    end

    # current occupancy per tick
    transform!(result,
        [:hospital_admissions, :hospital_discharges] => ((a, d) -> cumsum(a) .- cumsum(d)) => :current_hospitalized,
        [:icu_admissions, :icu_discharges] => ((a, d) -> cumsum(a) .- cumsum(d)) => :current_icu,
        [:ventilation_admissions, :ventilation_discharges] => ((a, d) -> cumsum(a) .- cumsum(d)) => :current_ventilation
    )

    return result
end

# events of each type in `event_types` per tick (0:final_tick), as a ticks x types matrix
function _events_per_tick(ticks::AbstractVector, events::AbstractVector, event_types::Vector{Symbol}, final_tick::Integer)
    counts = zeros(Int, final_tick + 1, length(event_types))
    for (t, e) in zip(ticks, events)
        (ismissing(t) || !(0 <= t <= final_tick)) && continue
        i = findfirst(==(e), event_types)
        i === nothing || (counts[t + 1, i] += 1)
    end
    return counts
end