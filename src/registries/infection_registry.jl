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
`progression_id::Int8` is the infecting category's index in `pathogen.progressions`
(`0` if unset), letting a `HealthProgression` tell categories apart.
"""
struct InfectionState
    infection_id::Int32
    next::Int32
    exposure::Int16
    infectiousness_onset::Int16
    symptom_onset::Int16
    severeness_onset::Int16
    critical_onset::Int16
    critical_offset::Int16
    severeness_offset::Int16
    recovery::Int16
    infectiousness::Int8
    pathogen_id::Int8
    progression_id::Int8
    active::Bool
end

"""
    InfectionState(pathogen_id::Int8, infection_id::Int32, dp::DiseaseProgression, progression_id::Int8 = Int8(0))

Constructs a new, active `InfectionState` directly from a `DiseaseProgression`.
"""
function InfectionState(pathogen_id::Int8, infection_id::Int32, dp::DiseaseProgression, progression_id::Int8 = Int8(0))::InfectionState
    return InfectionState(
        infection_id, Int32(0),
        exposure(dp),
        infectiousness_onset(dp),
        symptom_onset(dp),
        severeness_onset(dp),
        critical_onset(dp),
        critical_offset(dp),
        severeness_offset(dp),
        recovery(dp),
        Int8(0),
        pathogen_id,
        progression_id,
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
        Int8(0), Int8(0), Int8(0), false
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

Per-thread transfer struct staged in `infection_buffers` during the threaded contact
phase, then logged and drained into the individual cache / registry by
`flush_pending_infections!`, which assigns the infection id.
"""
struct _PendingInfection
    host_id::Int32
    infecter_id::Int32
    source_infection_id::Int32
    setting_id::Int32
    ags::Int32
    infecter_position::Int32
    lat::Float32
    lon::Float32
    setting_type::Char
    tick::Int16
    pathogen_id::Int8
    progression_id::Int8
    type_rank::UInt8
    dp::DiseaseProgression
end

# canonical order of the spread loop nest: setting type, then setting, then infecter within it.
# The smallest key wins its (host, pathogen); exact ties go to whichever is scanned first.
const _DeduplicationKey = Tuple{UInt8, Int32, Int32}
@inline _deduplication_key(p::_PendingInfection)::_DeduplicationKey =
    (p.type_rank, p.setting_id, p.infecter_position)

"""
    _EndedInfection

Per-thread transfer struct staged in `removal_buffers` when an infection ends, then drained
by `flush_ended_infections!`. `index` is the cache slot index (`is_overflow == false`) or the
overflow node index (`is_overflow == true`). `pathogen_id == DEFAULT_PATHOGEN_ID` grants no
immunity (the death path).
"""
struct _EndedInfection
    host_id::Int32
    index::Int32
    recovery::Int16
    pathogen_id::Int8
    is_overflow::Bool
end