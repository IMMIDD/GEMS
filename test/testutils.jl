###
### SHARED TEST FIXTURES
###


import GEMS: INFECTIONS_CACHE_SIZE, DEFAULT_INFECTION_ID, DEFAULT_TICK, push_infection!, infected!

"""
    set_progression!(ind::Individual, dp::DiseaseProgression, pathogen_id::Int8 = Int8(1))

Applies `dp` directly to `ind` by writing an active `InfectionState` into the individual's
infection cache, bypassing the normal simulation buffer and flush cycle.
The individual is immediately visible as infected for `pathogen_id` without needing a running
`Simulation` or a call to `step!`.

If `ind` is already actively infected with `pathogen_id`, this is a no-op (with a warning):
at most one active infection per pathogen is allowed.
"""
function set_progression!(ind::Individual, dp::DiseaseProgression, pathogen_id::Int8 = Int8(1))
    # at most one active infection per pathogen; skip a duplicate rather than corrupt the invariant
    if infected(ind, pathogen_id)
        @warn "set_progression!: individual $(id(ind)) is already infected with pathogen $pathogen_id; skipping to preserve the one-active-infection-per-pathogen invariant."
        return nothing
    end
    _free_cache_slot(ind) # without a persistent registry, an overflow would dangle
    push_infection!(InfectionRegistry(), ind, pathogen_id, DEFAULT_INFECTION_ID, dp)
    infected!(ind, true)
    infected!(ind, pathogen_id, true)
    return nothing
end

"""
    set_progression!(ind::Individual, pathogen_id::Int8 = Int8(1))

Seeds an active `InfectionState` with all fields set to `DEFAULT_TICK` (i.e. -1).
Useful when you need an active infection slot for a specific pathogen without
constraining any timeline values.
"""
function set_progression!(ind::Individual, pathogen_id::Int8 = Int8(1))
    # at most one active infection per pathogen; skip a duplicate rather than corrupt the invariant
    if infected(ind, pathogen_id)
        @warn "set_progression!: individual $(id(ind)) is already infected with pathogen $pathogen_id; skipping to preserve the one-active-infection-per-pathogen invariant."
        return nothing
    end
    blank = InfectionState(
        DEFAULT_INFECTION_ID, Int32(0),
        DEFAULT_TICK, DEFAULT_TICK, DEFAULT_TICK, DEFAULT_TICK,
        DEFAULT_TICK, DEFAULT_TICK, DEFAULT_TICK, DEFAULT_TICK,
        Int8(0), pathogen_id, Int8(0), true
    )
    # a free slot, not slot 1: a fixed slot overwrites an existing infection while
    # active_pathogens_mask still claims it, leaving a flag no recovery can clear
    ind.infection_cache = Base.setindex(ind.infection_cache, blank, _free_cache_slot(ind))
    infected!(ind, true)
    infected!(ind, pathogen_id, true)
    return nothing
end

# index of the first free infection cache slot; throws if the cache is full
function _free_cache_slot(ind::Individual)
    i = findfirst(i -> !ind.infection_cache[i].active, 1:INFECTIONS_CACHE_SIZE)
    isnothing(i) && throw(ArgumentError("set_progression! cannot store more than $INFECTIONS_CACHE_SIZE concurrent infection(s) per individual without a Simulation context."))
    return i
end
