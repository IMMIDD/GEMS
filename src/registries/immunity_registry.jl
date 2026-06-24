export ImmunityRegistry, ImmunityState


"""
    ImmunityState

Immutable, bits-type record used for both storage in `ImmunityRegistry` (overflow)
and as the on-individual cache (`immunity_cache`) and the public snapshot passed to
`ImmunityProfile.calculate_immunity`.

One entry per `(individual, pathogen)` — combines natural and vaccine immunity.
`next::Int32` chains overflow nodes; always 0 for cache states.
`immunity_level::Int8` is the computed immunity level (0–100), updated each tick
by `update_immunity!` and read by transmission functions directly from the
individual without touching the registry.

An entry is considered inactive when `pathogen_id == DEFAULT_PATHOGEN_ID`.
"""
struct ImmunityState
    next::Int32
    natural_acquired_tick::Int16  # DEFAULT_TICK if no natural immunity
    vaccine_acquired_tick::Int16  # DEFAULT_TICK if not vaccinated
    immunity_level::Int8          # computed each tick; 0 until update_immunity! runs
    pathogen_id::Int8             # DEFAULT_PATHOGEN_ID signals an empty slot
    vaccine_id::Int8              # DEFAULT_VACCINE_ID if not vaccinated
    dose_number::Int8             # 0 if not vaccinated
end

"""
    ImmunityState()

Constructs an empty/inactive `ImmunityState` sentinel.
Used for initializing caches and representing unassigned immunity slots.
"""
function ImmunityState()::ImmunityState
    return ImmunityState(Int32(0), DEFAULT_TICK, DEFAULT_TICK, Int8(0), DEFAULT_PATHOGEN_ID, DEFAULT_VACCINE_ID, Int8(0))
end

"""
    ImmunityState(pathogen_id::Int8)

Constructs an empty `ImmunityState` reserved for a specific pathogen.
Used as a safe return value when querying immunity for a pathogen the individual has no record of.
"""
function ImmunityState(pathogen_id::Int8)::ImmunityState
    return ImmunityState(Int32(0), DEFAULT_TICK, DEFAULT_TICK, Int8(0), pathogen_id, DEFAULT_VACCINE_ID, Int8(0))
end

"""
    ImmunityRegistry

Overflow store for immunity records that exceed `IMMUNITY_CACHE_SIZE` per individual.
For single-pathogen simulations this is never populated.

- `states::Vector{ImmunityState}`: record store; freed indices are recycled.
- `free_slots::Vector{Int32}`: LIFO stack of reusable indices.
"""
struct ImmunityRegistry
    states::Vector{ImmunityState}
    free_slots::Vector{Int32}

    function ImmunityRegistry(n::Int32, num_shards::Int = 1; overflow_fraction::Float64 = 0.0)
        states = ImmunityState[]
        capacity = max(1, round(Int, (n * overflow_fraction) / num_shards))
        sizehint!(states, capacity)
        free_slots = Int32[]
        sizehint!(free_slots, capacity)
        return new(states, free_slots)
    end

    ImmunityRegistry() = new(ImmunityState[], Int32[])
end

