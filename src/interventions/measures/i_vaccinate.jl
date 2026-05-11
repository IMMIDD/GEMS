export Vaccinate
export vaccine, follow_up, skip_vaccinated

###
### STRUCT
###

"""
    Vaccinate <: IMeasure

Intervention measure to vaccinate an individual with a given `Vaccine`.

Wraps the low-level `vaccinate!` call so that vaccination can be composed
with other intervention measures inside an `IStrategy`.  An optional
`follow_up` strategy lets you chain subsequent actions (e.g. a booster reminder)
directly through the event queue without a separate scheduler.

# Fields

- `vaccine::Vaccine`: The vaccine to administer.
- `follow_up::Union{IStrategy, Nothing}`: Strategy to trigger for the individual
    after vaccination. Defaults to `nothing`.
- `skip_vaccinated::Bool`: When `true` (default), individuals who have already
    received any vaccine are silently skipped and the `follow_up` strategy is
    **not** triggered for them.  Set to `false` to model booster doses, where
    re-vaccination should always proceed.

# Examples

## Single-dose vaccination

```julia
vacc_strategy = IStrategy("vaccinate", sim)
add_measure!(vacc_strategy, Vaccinate(my_vaccine))
```

## Two-dose regimen via `follow_up` and `delay`

```julia
second_dose = IStrategy("second-dose", sim)
add_measure!(second_dose, Vaccinate(my_vaccine, skip_vaccinated = false))

first_dose = IStrategy("first-dose", sim)
add_measure!(first_dose, Vaccinate(my_vaccine, follow_up = second_dose), delay = _ -> 21)
```

## Booster campaign (always re-vaccinate)

```julia
booster = IStrategy("booster", sim)
add_measure!(booster, Vaccinate(my_vaccine, skip_vaccinated = false))
```
"""
struct Vaccinate <: IMeasure
    vaccine::Vaccine
    follow_up::Union{IStrategy, Nothing}
    skip_vaccinated::Bool

    Vaccinate(vaccine::Vaccine; follow_up::Union{IStrategy, Nothing} = nothing, skip_vaccinated::Bool = true) =
        new(vaccine, follow_up, skip_vaccinated)
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

"""
    skip_vaccinated(m::Vaccinate)

Returns `true` if individuals who have already been vaccinated are skipped by this measure.
"""
skip_vaccinated(m::Vaccinate) = m.skip_vaccinated


###
### PROCESS MEASURE
###

"""
    process_measure(sim::Simulation, ind::Individual, m::Vaccinate)

Administers the vaccine carried by `m` to `ind`.

When `skip_vaccinated(m)` is `true` and the individual has already been
vaccinated, the measure is a no-op and a `Handover` with `nothing` is returned.
Otherwise `vaccinate!` is called and a `Handover` containing the
configured `follow_up` strategy (if any) is returned for the event queue to
process.

# Parameters

- `sim::Simulation`: The running simulation.
- `ind::Individual`: The individual to vaccinate.
- `m::Vaccinate`: The measure instance.

# Returns

- `Handover`: The focus individual paired with the follow-up strategy (or `nothing`).
"""
function process_measure(sim::Simulation, ind::Individual, m::Vaccinate)
    vacc = vaccine(m)
    registry = immunity_registry(sim, ind)

    if skip_vaccinated(m) && isvaccinated(ind, registry, target_pathogen_id(vacc))
        @debug "Individual $(id(ind)) already vaccinated; skipping at tick $(tick(sim))"
        return Handover(ind, nothing)
    end

    vaccinate!(ind, vacc, tick(sim), registry)

    @debug "Individual $(id(ind)) vaccinated with $(name(vacc)) at tick $(tick(sim))"

    return Handover(ind, follow_up(m))
end