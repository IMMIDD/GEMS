export InfectionRegistry, InfectionState


"""
    InfectionState

Immutable, bits-type record used for both storage in `InfectionRegistry` (overflow)
and as the on-individual cache (`infection_cache`) and the public snapshot passed to
`InfectiousnessProfile.calculate_infectiousness`.

`active = false` signals an empty cache slot or a missing registry lookup.
`next::Int32` chains overflow nodes in the linked list; always 0 for cache states.
`infectiousness::Int8` is computed each tick by `progress_disease!` and stored
here so the spread phase reads it directly from the individual without touching
the registry.
"""
struct InfectionState
    infection_id::Int32
    next::Int32
    exposure::Int16
    infectiousness_onset::Int16
    symptom_onset::Int16
    severeness_onset::Int16
    hospital_admission::Int16
    icu_admission::Int16
    icu_discharge::Int16
    ventilation_admission::Int16
    ventilation_discharge::Int16
    hospital_discharge::Int16
    severeness_offset::Int16
    recovery::Int16
    death::Int16
    infectiousness::Int8
    pathogen_id::Int8
    active::Bool
end

"""
    InfectionState(pathogen_id::Int8, infection_id::Int32, dp::DiseaseProgression)

Constructs a new, active `InfectionState` directly from a `DiseaseProgression`.
"""
function InfectionState(pathogen_id::Int8, infection_id::Int32, dp::DiseaseProgression)::InfectionState
    return InfectionState(
        infection_id, Int32(0),
        exposure(dp),
        infectiousness_onset(dp),
        symptom_onset(dp),
        severeness_onset(dp),
        hospital_admission(dp),
        icu_admission(dp),
        icu_discharge(dp),
        ventilation_admission(dp),
        ventilation_discharge(dp),
        hospital_discharge(dp),
        severeness_offset(dp),
        recovery(dp),
        death(dp),
        Int8(0),
        pathogen_id,
        true
    )
end

"""
    InfectionState()

Constructs an empty/inactive `InfectionState` sentinel.
Used for initialising caches and clearing inactive slots.
"""
function InfectionState()::InfectionState
    return InfectionState(
        DEFAULT_INFECTION_ID, Int32(0),
        Int16(-1), Int16(-1), Int16(-1), Int16(-1),
        Int16(-1), Int16(-1), Int16(-1), Int16(-1),
        Int16(-1), Int16(-1), Int16(-1), Int16(-1), Int16(-1),
        Int8(0), Int8(0), false
    )
end

"""
    InfectionRegistry

Overflow store for infections that exceed `INFECTIONS_CACHE_SIZE` per individual.
For single-pathogen simulations this is never populated — all infections live in
`individual.infection_cache` and this registry is never accessed in the hot path.

- `states::Vector{InfectionState}`: record store; freed indices are recycled.
- `free_slots::Vector{Int32}`: LIFO stack of reusable indices.
  individual (0 if no overflow). 
"""
struct InfectionRegistry
    states::Vector{InfectionState}
    free_slots::Vector{Int32}

    function InfectionRegistry(n::Int32, num_shards::Int = 1; overflow_fraction::Float64 = 0.0)
        states = InfectionState[]
        capacity = max(1, round(Int, (n * overflow_fraction) / num_shards))
        sizehint!(states, capacity)
        free_slots = Int32[]
        sizehint!(free_slots, capacity)
        return new(states, free_slots)
    end

    InfectionRegistry() = new(InfectionState[], Int32[])
end


"""
    _PendingInfection

Per-thread transfer struct staged in `infection_buffers` during the threaded
contact phase, then drained into the individual cache / registry by
`flush_pending_infections!`.
"""
struct _PendingInfection
    host_id::Int32
    infection_id::Int32
    pathogen_id::Int8
    dp::DiseaseProgression
end