export health_episodes

# care level each health event belongs to
const _CARE_LEVEL = Dict(
    :hospital_admission => :hospital, :hospital_discharge => :hospital,
    :icu_admission => :icu, :icu_discharge => :icu,
    :ventilation_admission => :ventilation, :ventilation_discharge => :ventilation)

_is_admission(event::Symbol) = event in (:hospital_admission, :icu_admission, :ventilation_admission)

"""
    health_episodes(postProcessor::PostProcessor)

Reconstructs host-level care episodes (hospital/ICU/ventilation stays) from the simulation's
`HealthLogger` by pairing each admission with its discharge. One row per episode: a host may appear
in several rows — once per care level, and once per stay if it is hospitalized more than once (e.g.
re-infected long after recovering). These are host states, not per-pathogen: one episode can be
driven by several co-active infections. To attribute an episode to infections, join this against
`infections` on the host and an overlap of the episode window with the infection's active window.

# Returns

- `DataFrame` with the following columns:

| Name             | Type     | Description                            |
| :--------------- | :------- | :------------------------------------- |
| `host_id`        | `Int32`  | Individual id                          |
| `care_level`     | `Symbol` | `:hospital` / `:icu` / `:ventilation`  |
| `admission_tick` | `Int16`  | Tick of admission                      |
| `discharge_tick` | `Int16`  | Tick of discharge (capped at death)    |
"""
function health_episodes(postProcessor::PostProcessor)

    # load cached DF if available
    if in_cache(postProcessor, "health_episodes")
        return load_cache(postProcessor, "health_episodes")
    end

    events = dataframe(healthlogger(simulation(postProcessor)))

    result = DataFrame(host_id = Int32[], care_level = Symbol[],
        admission_tick = Int16[], discharge_tick = Int16[])

    if nrow(events) > 0
        # tag each event with its care level, then pair admission -> discharge within (host, level)
        ev = transform(events, :event => ByRow(e -> _CARE_LEVEL[e]) => :care_level)
        # grouped only for the group order, which the rows come out in
        groups = collect(Int, groupindices(groupby(ev, [:id, :care_level])))
        result = _pair_episodes(groups, ev.id, ev.care_level, ev.tick, ev.event)
    end

    store_cache(postProcessor, "health_episodes", result)

    return result
end

# Pairs each admission with the next discharge of its (host, care level) group, in one pass over the events
# sorted by group, then tick with admissions before discharges (0-length stays pair correctly).
function _pair_episodes(groups::Vector{Int}, ids::AbstractVector, levels::AbstractVector, ticks::AbstractVector,
        events::AbstractVector)
    order = sortperm(eachindex(groups); by = i -> (groups[i], ticks[i], !_is_admission(events[i])))
    host_id = eltype(ids)[]
    care_level = eltype(levels)[]
    admission_tick = Int16[]
    discharge_tick = Int16[]
    open_admission = Int16(-1)
    for (k, i) in enumerate(order)
        k > 1 && groups[i] != groups[order[k - 1]] && (open_admission = Int16(-1))
        if _is_admission(events[i])
            open_admission = ticks[i]
        elseif open_admission >= 0
            push!(host_id, ids[i])
            push!(care_level, levels[i])
            push!(admission_tick, open_admission)
            push!(discharge_tick, ticks[i])
            open_admission = Int16(-1)
        end
    end
    return DataFrame(host_id = host_id, care_level = care_level, admission_tick = admission_tick,
        discharge_tick = discharge_tick)
end
