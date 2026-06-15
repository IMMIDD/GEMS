export Vaccinate
export vaccine, follow_up

###
### STRUCT
###

"""
    Vaccinate <: IMeasure

Intervention measure to vaccinate an individual with a given `Vaccine`.

Wraps the low-level `vaccinate!` call so that vaccination can be composed
with other intervention measures inside an `IStrategy`.  An optional
`follow_up` strategy lets you chain subsequent actions (e.g. a second dose)
directly through the event queue.

# Fields

- `vaccine::Vaccine`: The vaccine to administer.
- `follow_up::Union{IStrategy, Nothing}`: Strategy to trigger for the individual
    after vaccination. Defaults to `nothing`.

# Examples

## Single-dose vaccination

```julia
vacc_strategy = IStrategy("vaccinate", sim)
add_measure!(vacc_strategy, Vaccinate(my_vaccine))
```

## Two-dose regimen via `follow_up` and `delay`

```julia
second_dose = IStrategy("second-dose", sim)
add_measure!(second_dose, Vaccinate(my_vaccine))

first_dose = IStrategy("first-dose", sim)
add_measure!(first_dose, Vaccinate(my_vaccine, follow_up = second_dose), delay = _ -> 21)
```

## Only vaccinate individuals who have not yet been vaccinated

```julia
vacc_strategy = IStrategy("vaccinate", sim, condition = ind -> !isvaccinated(ind))
add_measure!(vacc_strategy, Vaccinate(my_vaccine))
```
"""
struct Vaccinate <: IMeasure
    vaccine::Vaccine
    follow_up::Union{IStrategy, Nothing}

    Vaccinate(vaccine::Vaccine; follow_up::Union{IStrategy, Nothing} = nothing) = new(vaccine, follow_up)
end

"""
    vaccine(m::Vaccinate)

Returns the `Vaccine` administered by this measure.
"""
vaccine(m::Vaccinate) = m.vaccine

"""
    follow_up(m::Vaccinate)

Returns the follow-up `IStrategy` triggered after vaccination, or `nothing`.
"""
follow_up(m::Vaccinate) = m.follow_up


###
### PROCESS MEASURE
###

"""
    process_measure(sim::Simulation, ind::Individual, m::Vaccinate)

Administers the vaccine carried by `m` to `ind` and returns a `Handover`
containing the configured `follow_up` strategy (or `nothing`).

# Parameters

- `sim::Simulation`: The running simulation.
- `ind::Individual`: The individual to vaccinate.
- `m::Vaccinate`: The measure instance.

# Returns

- `Handover`: The focus individual paired with the follow-up strategy (or `nothing`).
"""
function process_measure(sim::Simulation, ind::Individual, m::Vaccinate)
    vaccinate!(ind, vaccine(m), tick(sim))

    INTERVENTION_DEBUG && @debug "Individual $(id(ind)) vaccinated with $(name(vaccine(m))) at tick $(tick(sim))"

    return Handover(ind, follow_up(m))
end