###
### POPULATION INJECTION (STAGED POPULATION CHANGES)
###
### Engine that injects an Injector's staged population changes into a running Simulation.
### Semantics (stage -> inject, the same pattern as GEMS' internal event staging):
###   - no snapshot:            event timestamp t        -> applied at simulation tick t
###   - population_snapshot t0: events <= t0 baked in at construction;
###                             event timestamp t > t0   -> applied at simulation tick t - t0
###   - the simulation clock always starts at tick 0
###   - an event on the death column marks the individual dead from the event's timestamp
###     (the decoded value is not interpreted as a tick)
###

# EXPORTS
export PopulationInjection
export PopulationInjectionState
export new_injector, population_injection, apply_injection_events!, inject_population_changes!
export validate_injection_base!, reset_injection!

# Staged column(s) encoding "this individual has died" (matches the `Individual.death` field).
# Extend this tuple if the staged changes use a different column name (e.g. :is_dead).
const INJECTION_DEATH_FIELDS = (:death,)


"""
    population_injection(simulation)

Return the attached `PopulationInjectionState` or `nothing` when no injector is attached.
"""
population_injection(simulation::Simulation) = simulation.population_injection


"""
    new_injector(population)

Convenience: creates an `Injector` ready for staging for a GEMS population — the schema
is derived from the canonical `dataframe(population)` (correct element types for the
hash-based validation).
"""
function new_injector(pop::Population)::PopulationInjection.Injector
    PopulationInjection.Injector(PopulationInjection.create_column_schema(dataframe(pop)))
end


"""
    _set_individual_field!(ind, field, value)

Set an `Individual` field via `setproperty!` with conversion to the declared field type
(staged values may carry a wider integer type than the `Individual` field).
"""
function _set_individual_field!(ind::Individual, field::Symbol, value)
    T = fieldtype(Individual, field)
    setproperty!(ind, field, convert(T, value))
    return nothing
end


"""
    _extension_fieldtype(pop::Population)

The boxed extension type shared by the population's individuals: the `NamedTuple` type
wrapped by an `AutoExtension`, the user struct type for a custom extension, or `nothing`
when no individual carries an extension.
"""
function _extension_fieldtype(pop::Population)
    inds = individuals(pop)
    ext_idx = findfirst(ind -> ind.extensions !== nothing, inds)
    isnothing(ext_idx) && return nothing
    ext = inds[ext_idx].extensions
    return ext isa AutoExtension ? fieldtype(typeof(ext), :data) : typeof(ext)
end


"""
    _is_stored_field(pop::Population, field::Symbol)

`true` when the population stores `field` per individual — as a core `Individual` base
field or as an extension column (`ind_extension`).
"""
function _is_stored_field(pop::Population, field::Symbol)
    field in individual_base_fieldnames() && return true
    ext_type = _extension_fieldtype(pop)
    return !isnothing(ext_type) && field in fieldnames(ext_type)
end


"""
    _is_extension_field(ind::Individual, field::Symbol)

`true` when `field` is a field of the individual's boxed extension (`AutoExtension` or
custom struct).
"""
function _is_extension_field(ind::Individual, field::Symbol)
    ext = ind.extensions
    ext === nothing && return false
    ext_fields = ext isa AutoExtension ? fieldnames(fieldtype(typeof(ext), :data)) : fieldnames(typeof(ext))
    return field in ext_fields
end


"""
    _default_extension(ext_type)

A new extension value with every field at its zero default (same convention as GEMS'
`_build_individuals_from_ext_df`), for newborn individuals that receive staged extension
fields.
"""
function _default_extension(ext_type)
    if ext_type <: NamedTuple
        names = fieldnames(ext_type)
        return AutoExtension(NamedTuple{names}(map(f -> zero(fieldtype(ext_type, f)), names)))
    end
    return ext_type(map(zero, fieldtypes(ext_type))...)
end


"""
    _warn_unstored_field!(injector::Injector, field::Symbol, where)

Warn once per (injector, field) that staged changes on `field` are skipped because the
population stores no such column (neither an `Individual` field nor an extension column).
"""
function _warn_unstored_field!(injector::PopulationInjection.Injector, field::Symbol, where)
    if !(field in injector.warned)
        push!(injector.warned, field)
        @warn "population injection: field :$field is not stored on this population (neither an Individual nor an extension field); the staged change is skipped ($where). This warning is shown once per field."
    end
    return nothing
end


"""
    _realize_death!(ind, t)

Mark `ind` dead with death tick `t` (simulation time). Mirrors the flag/mask effects of
GEMS' `_process_death!` so the state is consistent even when the individual update loop
does not run (dormant simulation). Idempotent. `killing_pathogen_id` is intentionally
left at `DEFAULT_PATHOGEN_ID` (non-disease death; grants no immunity, cf. `_EndedInfection`).
"""
function _realize_death!(ind::Individual, t::Int16)
    ind.death = t
    dead!(ind, true)
    ind.active_pathogens_mask = 0
    ind.detected_mask = 0
    return nothing
end


# The staged columns that change setting membership (column -> setting type). Derived from
# GEMS' setting membership definitions (`setting_fieldmap`, single source of truth);
# resolved lazily because `individual_methods.jl` (and the settings module) are included
# after this file, so a load-time `const` is not possible.
const _SETTING_FIELDS_CACHE = Ref{Union{Dict{Symbol,DataType},Nothing}}(nothing)
function setting_fields()::Dict{Symbol,DataType}
    _SETTING_FIELDS_CACHE[] === nothing && (_SETTING_FIELDS_CACHE[] = setting_fieldmap())
    return _SETTING_FIELDS_CACHE[]
end


"""
    _lookup_setting(cntnr, T, sid)

The setting of type `T` with id `sid` in the container, or `nothing` (for
`DEFAULT_SETTING_ID` and out-of-range / mismatched ids).
"""
function _lookup_setting(cntnr::SettingsContainer, T::DataType, sid::Int32)
    sid == DEFAULT_SETTING_ID && return nothing
    vec = get(cntnr, T)
    sid > length(vec) && return nothing
    s = vec[sid]
    return s.id == sid ? s : nothing
end


"""
    _get_or_create_setting!(cntnr, T, new_id)

The setting of type `T` with id `new_id`; creates it when `new_id` is the next free id —
GEMS indexes setting vectors by id without gaps (ids 1:N), so a new setting can only be
the last one + 1. The new setting inherits the contact sampling method of the existing
settings (sampling consistency). Throws an `ArgumentError` when `new_id` would leave a gap.
"""
function _get_or_create_setting!(cntnr::SettingsContainer, T::DataType, new_id::Int32)
    s = _lookup_setting(cntnr, T, new_id)
    s !== nothing && return s
    vec = get(cntnr, T)
    new_id == length(vec) + Int32(1) || throw(ArgumentError(
        "population injection: staged $(T) id $new_id cannot be created — the container has " *
        "$(length(vec)) $(T) setting(s) and GEMS indexes settings by id without gaps (ids 1:N); " *
        "the next creatable id is $(length(vec) + 1)."
    ))
    add_type!(cntnr, T)
    s = T(id = new_id)
    !isempty(vec) && contact_sampling_method!(s, contact_sampling_method(vec[1]))
    add!(cntnr, s)
    return s
end


"""
    _apply_setting_move!(cntnr, T, ind, new_id)

Move `ind` to the setting of type `T` with id `new_id` (or out of the setting when
`new_id == DEFAULT_SETTING_ID`), keeping the individual's id field and the setting's member
list in sync via GEMS' `add!`/`remove!` (which also invalidate the contact-sampling caches).
Creating the target setting is covered by `_get_or_create_setting!`. Idempotent for replay
(`reset!`): `remove!` is a no-op for non-members and `add!` is guarded against duplicates.
"""
function _apply_setting_move!(cntnr::SettingsContainer, T::DataType, ind::Individual, new_id::Int32)
    old_id = setting_id(ind, T)
    new_id == old_id && return nothing
    old = _lookup_setting(cntnr, T, old_id)
    new = new_id == DEFAULT_SETTING_ID ? nothing : _get_or_create_setting!(cntnr, T, new_id)
    (old === nothing && new === nothing) && return nothing
    old !== nothing && remove!(old, ind)
    if new !== nothing
        ind in individuals(new) || add!(new, ind)
        activate!(new)
    end
    return nothing
end


"""
    apply_injection_events!(pop, injector, events, death_tick; cntnr=nothing)

Shared core: apply a batch of already-selected staged events to a `Population`.
- attribute changes on existing individuals (`Event.ind_id` = individual id); extension
  columns (`ind_extension`) are written into the boxed extension via `setproperty!`
- setting columns (`household`, `office`, `schoolclass`, `municipality`): when a
  `SettingsContainer` (`cntnr`) is given, the membership is moved with GEMS' `add!`/
  `remove!` (creating the target setting for a new, next-free id) instead of only writing
  the individual's id field; without a container the id field is written as before
- fields the population does not store (neither an `Individual` field nor an extension
  column) are skipped, with one warning per (injector, field)
- deaths: events on `INJECTION_DEATH_FIELDS` mark the individual dead from `death_tick`
  (simulation time: `0` for the construction-time bake-in, the application tick otherwise)
- new individuals from ids that do not exist yet (`:sex`/`:age` required; an individual
  that already exists is skipped, making re-application idempotent); staged extension
  fields of a new individual are realized on a zero-filled default extension; staged
  setting fields of a new individual add it to the corresponding settings

Maintains `minid`/`maxid`/`id_map` and invalidates the cached `maxage` when ages change
or individuals are added.

# Returns

- `Tuple{Int, Int, Vector{Int32}}`: (n_attribute_updates, n_births, ids of individuals marked dead)
"""
function apply_injection_events!(pop::Population,
                                 injector::PopulationInjection.Injector,
                                 events::Vector{<:PopulationInjection.Event},
                                 death_tick::Int16,
                                 cntnr::Union{SettingsContainer, Nothing} = nothing)::Tuple{Int,Int,Vector{Int32}}
    n_updates = 0
    touched_age = false
    death_ids = Int32[]
    births = IdDict{Int32, Dict{Symbol,Any}}()   # individual id -> collected fields

    for ev in events
        field = injector.schema.index_to_field[Int(ev.field) + 1]
        value = PopulationInjection.get_original_value(injector, ev)
        ind_id = Int32(ev.ind_id)

        ind = get_individual_by_id(pop, ind_id)
        if ind === nothing
            # not present yet: accumulate fields, materialized below (birth or born-dead)
            ind_props = get(births, ind_id, Dict{Symbol, Any}())
            births[ind_id] = ind_props
            ind_props[field] = value
        else
            if field in INJECTION_DEATH_FIELDS
                _realize_death!(ind, death_tick)
                push!(death_ids, ind_id)
            elseif field === :id
                continue                        # identity is immutable
            elseif field in individual_base_fieldnames()
                T = get(setting_fields(), field, nothing)
                if T !== nothing && cntnr !== nothing
                    _apply_setting_move!(cntnr, T, ind, Int32(value))   # id field + membership stay in sync
                else
                    _set_individual_field!(ind, field, value)
                end
                field === :age && (touched_age = true)
                n_updates += 1
            elseif _is_extension_field(ind, field)
                # extension columns (ind_extension) are stored per individual — inject them
                setproperty!(ind, field, value)     # Individual.setproperty! routes to the boxed extension
                n_updates += 1
            else
                _warn_unstored_field!(injector, field, "individual $ind_id")
            end
        end
    end

    n_births = 0
    for (ind_id, props) in births
        get_individual_by_id(pop, ind_id) !== nothing && continue   # idempotency guard (reset replay)
        haskey(props, :sex) ||
            throw(ArgumentError("population injection: new individual with id $ind_id is missing required field :sex"))
        haskey(props, :age) ||
            throw(ArgumentError("population injection: new individual with id $ind_id is missing required field :age"))
        ind = Individual(id = ind_id, sex = convert(Int8, props[:sex]), age = convert(Int8, props[:age]))
        died = any(f -> f in INJECTION_DEATH_FIELDS, keys(props))
        ext_type = nothing
        for (f, v) in props
            (f === :id || f === :sex || f === :age) && continue
            f in INJECTION_DEATH_FIELDS && continue    # applied via _realize_death! below
            if f in individual_base_fieldnames()
                T = get(setting_fields(), f, nothing)
                T !== nothing && cntnr !== nothing && continue   # setting membership is applied below, after the individual exists
                _set_individual_field!(ind, f, v)
            else
                isnothing(ext_type) && (ext_type = _extension_fieldtype(pop))
                if !isnothing(ext_type) && f in fieldnames(ext_type)
                    ind.extensions === nothing && (ind.extensions = _default_extension(ext_type))
                    setproperty!(ind, f, v)
                else
                    _warn_unstored_field!(injector, f, "individual $ind_id")
                end
            end
        end
        if died
            _realize_death!(ind, death_tick)
            push!(death_ids, ind_id)
        end
        add!(pop, ind)
        pop.maxid = max(pop.maxid, ind_id)
        pop.minid = min(pop.minid, ind_id)
        if cntnr !== nothing
            for (f, v) in props
                T = get(setting_fields(), f, nothing)
                T === nothing && continue
                _apply_setting_move!(cntnr, T, ind, Int32(v))
            end
        end
        n_births += 1
    end

    if n_births > 0 || touched_age
        make_id_map!(pop)      # id_map is indexed by id and must reflect new ids
        pop.maxage = -1        # invalidate the maxage() cache
    end
    return (n_updates, n_births, death_ids)
end


"""
    inject_population_changes!(simulation)

Per-tick hook (called at the top of `step!`). Returns immediately (O(1)) when no injector
is attached or no staged change is due at the current tick; otherwise applies every event
with `timestamp <= tick + offset` that has not been applied yet, exactly once.
Deaths applied during the run are recorded exactly once in the `DeathLogger`.
"""
function inject_population_changes!(simulation::Simulation)
    st = population_injection(simulation)
    isnothing(st) && return nothing

    injector = st.injector
    n = length(injector.events)
    st.cursor >= n && return nothing

    # "now" in days (Int32: tick + offset can exceed Int16)
    t = Int32(tick(simulation)) + Int32(st.offset)
    evts = injector.events

    # per-tick "is injection necessary?" check
    Int32(evts[st.order[st.cursor + 1]].timestamp) > t && return nothing

    end_idx = st.cursor
    while end_idx < n && Int32(evts[st.order[end_idx + 1]].timestamp) <= t
        end_idx += 1
    end

    cur_tick = tick(simulation)
    (n_updates, n_births, death_ids) =
        apply_injection_events!(population(simulation), injector,
                                evts[st.order[st.cursor + 1:end_idx]], Int16(cur_tick),
                                settingscontainer(simulation))
    st.cursor = end_idx

    # record run-time deaths exactly once; the engine's was_dead->dead transition check
    # skips them (flag already set) so there is no double logging
    for d in death_ids
        log!(deathlogger(simulation), d, DEFAULT_PATHOGEN_ID, Int16(cur_tick))
    end

    @info "population injection: applied $n_updates attribute change(s), $(length(death_ids)) death(s) and $n_births birth(s) at tick $cur_tick"
    return nothing
end


"""
    validate_injection_base!(pop, injector)

Construction-time safety check (must run BEFORE any snapshot bake-in): verifies that the
provided population matches the base population the injector was staged from, using the
per-column hashes stored in the schema metadata (checked on the column intersection;
columns absent from GEMS' `dataframe(population)` — e.g. a death column — are skipped).
Also warns (once per field) about staged fields the population does not store — neither
as an `Individual` field nor as an extension column.
"""
function validate_injection_base!(pop::Population, injector::PopulationInjection.Injector)
    hashes = injector.schema.meta[:hash]
    df = dataframe(pop)
    for f in names(df)
        fsym = Symbol(f)
        haskey(hashes, fsym) || continue
        computed = PopulationInjection.stable_hash(df[!, f])
        computed == hashes[fsym] || throw(ArgumentError(
            "population injection: column $fsym of the provided population does not match the base " *
            "population the injector was staged from (hash mismatch). Use the same base population " *
            "(day 0) that was passed to PopulationInjection.create_column_schema, produced with " *
            "the same element types (e.g. via GEMS' dataframe(population) or new_injector(population))."
        ))
    end
    for f in keys(injector.schema.columns)
        (f === :id) && continue
        f in INJECTION_DEATH_FIELDS && continue
        _is_stored_field(pop, f) && continue
        _warn_unstored_field!(injector, f, "at construction")
    end
    return nothing
end


"""
    reset_injection!(simulation)

Restore the baked-in (pre-snapshot) state after `reset!`: `reset!` cleared the death state
of all individuals, so the prefix is re-applied — idempotently (attribute re-sets are
no-ops, births are skipped because the individuals already exist, deaths are re-marked).
Baked-in deaths are initial state and are NOT re-logged in the (fresh) DeathLogger.
The simulation clock is handled by `reset_tick!`.
"""
function reset_injection!(simulation::Simulation)
    st = population_injection(simulation)
    isnothing(st) && return nothing
    if st.initial_cursor > 0
        evts = st.injector.events
        apply_injection_events!(population(simulation), st.injector,
                                evts[st.order[1:st.initial_cursor]], Int16(0),
                                settingscontainer(simulation))
    end
    st.cursor = st.initial_cursor
    return nothing
end
