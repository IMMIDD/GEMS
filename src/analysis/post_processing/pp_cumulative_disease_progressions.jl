export cumulative_disease_progressions

"""
    calc_cum_dis_values(df)

Helper function that calculates the cumulative number of individuals in a certain disease
state (latent, presymptomatic, symptomatic and asymptomatic) after the
individual has been infected. Rows indicate the number of elapsed ticks since infections.
"""
function calc_cum_dis_values(df)
    return [[
        # duration
        t,
        # latent
        (t .< df.infectiousness_onset) |> sum,
        # pre symptomatic
        (df.infectiousness_onset .<= t .< df.symptom_onset) |> sum,
        # symptomatic
        (0 .<= df.symptom_onset .<= t .< df.removed) |> sum,
        # asymptomatic
        ((df.infectiousness_onset .<= t .< df.removed) .& (df.symptom_onset .< 0)) |> sum
    ] for t in 0:maximum(df.removed)] |>
    # convert array of arrays to a DataFrame
    mat -> DataFrame(mapreduce(permutedims, vcat, mat), [:tick, :latent,:pre_symptomatic,:symptomatic,:asymptomatic])

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

| Name             | Type    | Description                                                  |
| :--------------- | :------ | :----------------------------------------------------------- |
| `pathogen_id`    | `Int8`  | Pathogen identifier                                          |
| `latent`         | `Int64` | Number of latent individuals X ticks after exposure          |
| `pre_symptomatic`| `Int64` | Number of pre-symptomatic individuals X ticks after exposure |
| `symptomatic`    | `Int64` | Number of symptomatic individuals X ticks after exposure     |
| `asymptomatic`   | `Int64` | Number of asymptomatic individuals X ticks after exposure    |
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
            removed = max.(p_infs.recovery, p_infs.death) .- p_infs.tick
        )
        res = calc_cum_dis_values(df)
        res.pathogen_id .= pid
        push!(results, res)
    end
    return isempty(results) ? DataFrame() : vcat(results...)
end
