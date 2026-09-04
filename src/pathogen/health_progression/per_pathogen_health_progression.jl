export PerPathogenHealthProgression


"""
    PerPathogenHealthProgression <: HealthProgression

Host health policy routing each infection to the `HealthProfile` embedded on its own progression
category, keyed by `(pathogen_id, progression_id)`. An infection with no entry demands no host care.
This allows two pathogens with identical severity stratification to differ in mortality.

`profiles` is a plain `Dict`, so an entry may be added after construction without changing the
simulation's type.

# Example

```julia
# usually built by embedding care on the progressions and letting `Simulation` harvest it
covid = Pathogen(id = 1, name = "Covid19",
    progressions = [Critical(...; hospital_probability = 0.9, death_probability = 0.25)])
variant = Pathogen(id = 2, name = "Covid19-B",
    progressions = [Critical(...; hospital_probability = 0.9, death_probability = 0.5)])
sim = Simulation(pathogens = (covid, variant))

# or assembled directly, keyed by (pathogen_id, progression slot)
hp = PerPathogenHealthProgression(Dict(
    (Int8(1), Int8(1)) => CriticalHealthProfile(hospital_probability = 0.9, death_probability = 0.25),
    (Int8(2), Int8(1)) => CriticalHealthProfile(hospital_probability = 0.9, death_probability = 0.5)))
```
"""
struct PerPathogenHealthProgression <: HealthProgression
    profiles::Dict{NTuple{2,Int8}, HealthProfile}
end

"""
    select_health_profile(hp::PerPathogenHealthProgression, infection::InfectionState)

Routes `infection` to the profile embedded on its own progression category, or `nothing` if that
category embedded none. No tier check is needed: only categories that carry care have an entry, so
an asymptomatic or mild infection misses the table by construction.
"""
function select_health_profile(hp::PerPathogenHealthProgression, infection::InfectionState)
    return get(hp.profiles, (infection.pathogen_id, infection.progression_id), nothing)
end
