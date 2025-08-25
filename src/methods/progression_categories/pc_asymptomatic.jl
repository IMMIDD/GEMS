export Asymptomatic

"""
    Asymptomatic <: ProgressionCategory

A disease progression category where individuals do not show symptoms but can spread the disease.

**IMPORTANT**: The infectiousness onset must be at least 1 tick after exposure to avoid issues with immediate transmission.
Therefore, the calculation for infectiousness_onset includes a +1 offset.
The provided distributions should account for this offset to ensure realistic timing.
Providing, for example a Poisson(2) distribution would result in an average of 3 ticks from exposure to infectiousness onset (Poisson(2) + 1).

# Disease events
`exposure` -> `infectiousness_onset` -> `recovery`.

# Parameters
- `exposure_to_infectiousness::Union{Distribution, Real}`: Time from exposure to becoming infectious.
- `infectiousness_to_recovery::Union{Distribution, Real}`: Time from becoming infectious to recovery.

# Example
The code below instantiates an `Asymptomatic` progression category with specific distributions for the time intervals.

```julia
dp = Asymptomatic(
    exposure_to_infectiousness = Poisson(3),
    infectiousness_to_recovery = Poisson(7)
)
```
"""
@with_kw mutable struct Asymptomatic <: ProgressionCategory
    exposure_to_infectiousness::Union{Distribution, Real}
    infectiousness_to_recovery::Union{Distribution, Real}
end


function calculate_progression(individual::Individual, tick::Int16, dp::Asymptomatic)
    # Calculate the time to infectiousness
    infectiousness_onset = tick + Int16(1) + rand_val(dp.exposure_to_infectiousness)

    # Calculate the time to recovery
    recovery = infectiousness_onset + rand_val(dp.infectiousness_to_recovery)

    return DiseaseProgression(
        exposure = tick,
        infectiousness_onset = infectiousness_onset,
        recovery = recovery
    )
end