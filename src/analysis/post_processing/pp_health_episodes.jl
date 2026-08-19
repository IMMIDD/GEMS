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
        result = combine(groupby(ev, [:id, :care_level])) do sdf
            # by tick, admissions before discharges within a tick (0-length stays pair correctly)
            order = sortperm(collect(zip(sdf.tick, .!_is_admission.(sdf.event))))
            ticks = sdf.tick[order]
            evs = sdf.event[order]
            admission_tick = Int16[]
            discharge_tick = Int16[]
            open_admission = Int16(-1)
            for i in eachindex(ticks)
                if _is_admission(evs[i])
                    open_admission = ticks[i]
                elseif open_admission >= 0
                    push!(admission_tick, open_admission)
                    push!(discharge_tick, ticks[i])
                    open_admission = Int16(-1)
                end
            end
            return (admission_tick = admission_tick, discharge_tick = discharge_tick)
        end
        rename!(result, :id => :host_id)
    end

    store_cache(postProcessor, "health_episodes", result)

    return result
end
