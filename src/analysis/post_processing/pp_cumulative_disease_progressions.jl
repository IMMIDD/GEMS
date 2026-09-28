export cumulative_disease_progressions

"""
    calc_cum_dis_values(df)

Helper function that calculates the cumulative number of individuals in a certain disease
state (latent, presymptomatic, symptomatic and asymptomatic) after the
individual has been infected. Rows indicate the number of elapsed ticks since infections.
"""
function calc_cum_dis_values(df)
    return _progression_counts(df.infectiousness_onset, df.symptom_onset, df.removed)
end

# Every state is a tick interval per infection, so each is counted with a difference array instead of one pass
# over all infections per tick.
function _progression_counts(infectiousness_onset::AbstractVector, symptom_onset::AbstractVector, removed::AbstractVector)
    last_tick = Int(maximum(removed))
    # columns latent, pre-symptomatic, symptomatic, asymptomatic; one spare row for intervals ending after last_tick
    counts = zeros(Int, last_tick + 2, 4)
    function add!(state, from, to) # in `state` for ticks from <= t < to
        from, to = max(Int(from), 0), min(Int(to), last_tick + 1)
        from < to || return
        counts[from + 1, state] += 1
        counts[to + 1, state] -= 1
    end
    for (i, s, r) in zip(infectiousness_onset, symptom_onset, removed)
        add!(1, 0, i)
        add!(2, i, s)
        s >= 0 ? add!(3, s, r) : add!(4, i, r)
    end
    cumsum!(counts, counts, dims = 1)
    return DataFrame(tick = collect(0:last_tick), latent = counts[1:end-1, 1], pre_symptomatic = counts[1:end-1, 2],
        symptomatic = counts[1:end-1, 3], asymptomatic = counts[1:end-1, 4])
end

"""
    cumulative_disease_progressions(postProcessor::PostProcessor)

Calculates the accumulated number of individuals in a certain disease
state (latent, presymptomatic, symptomatic and asymptomatic) after the
individual has been infected, per pathogen. Rows indicate the number of elapsed
ticks since infections. Latent means infected but not yet infectious.
Presymptomatic means infectious but not yet symptomatic. Symptomatic
means infectious and symptomatic. Asymptomatic means infectious but
not symptomatic and will never develop symptoms.

Example: Row 8 showing [20, 47, 290, 50] would mean that eight ticks
after exposure, 20 individuals were latent, 47 were presymptomatic
(no symptoms yet, but will be developing), 290 had symptoms and
50 are not experiencing symptoms and won't ever do.

# Returns

- `DataFrame` with the following columns:

| Name              | Type    | Description                                                  |
| :---------------- | :------ | :----------------------------------------------------------- |
| `tick`            | `Int64` | Ticks since exposure                                         |
| `latent`          | `Int64` | Number of latent individuals X ticks after exposure          |
| `pre_symptomatic` | `Int64` | Number of pre-symptomatic individuals X ticks after exposure |
| `symptomatic`     | `Int64` | Number of symptomatic individuals X ticks after exposure     |
| `asymptomatic`    | `Int64` | Number of asymptomatic individuals X ticks after exposure    |
| `pathogen_id`     | `Int8`  | Pathogen identifier                                          |
"""
function cumulative_disease_progressions(postProcessor::PostProcessor)
    infs = infectionsDF(postProcessor)

    if nrow(infs) == 0
        return DataFrame(pathogen_id=Int8[], tick=Int[], latent=Int[], pre_symptomatic=Int[], symptomatic=Int[], asymptomatic=Int[])
    end

    results = DataFrame[]
    for p in pathogens(simulation(postProcessor))
        pid = id(p)
        p_infs = subset(infs, :pathogen_id => ByRow(==(pid)), view=true)
        nrow(p_infs) == 0 && continue
        df = DataFrame(
            symptom_onset = p_infs.symptom_onset .- p_infs.tick,
            infectiousness_onset = p_infs.infectiousness_onset .- p_infs.tick,
            removed = p_infs.removed .- p_infs.tick
        )
        res = calc_cum_dis_values(df)
        res.pathogen_id .= pid
        push!(results, res)
    end
    return isempty(results) ? DataFrame() : vcat(results...)
end
