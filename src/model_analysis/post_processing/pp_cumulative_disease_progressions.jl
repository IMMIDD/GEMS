export cumulative_disease_progressions

""" 
    cumulative_disease_progressions(postProcessor::PostProcessor)

Calculates the accumulated number of individuals in a certain disease
state (latent, presymptomatic, symptomatic and asymptomatic) after the 
individual has been infected. Rows indicate the number of elapsed
ticks since infections.

Example: Row 8 showing [20, 47, 290, 50] would mean that eight ticks
after exposure, 20 individuals were latent, 47 were presymptomatic 
(no symptoms yet, but will be developing), 290 had symptoms and 
50 are not experiencing symptoms and won't ever do.

# Returns

- `DataFrame` with the following columns:

| Name             | Type    | Description                                                  |
| :--------------- | :------ | :----------------------------------------------------------- |
| `latent`         | `Int64` | Number of latent individuals X ticks after exposure          |
| `pre_symptomatic`| `Int64` | Number of pre-symptomatic individuals X ticks after exposure |
| `symptomatic`    | `Int64` | Number of symptomatic individuals X ticks after exposure     |
| `asymptomatic`   | `Int64` | Number of asymptomatic individuals X ticks after exposure    |
"""
function cumulative_disease_progressions(postProcessor::PostProcessor)

    # calculating the time points (ticks) where an individual switches to the next disease state
    inf = postProcessor |> infectionsDF |>
        x -> transform(x,
            # onset of infectiousness
            [:infectious_tick, :tick] => ByRow(-) => :infectiousness_onset,
            # onset of symptoms
            [:symptoms_tick, :tick] => ByRow(-) => :symptoms_onset,
            # recovery
            [:removed_tick, :tick] => ByRow(-) => :removed,
            copycols = true) |>
        x -> DataFrames.select(x,
            :infectiousness_onset,
            :symptoms_onset,
            :removed);

    # adding up the number of individuals in a certain
    # state after infection        
    res = [[
        # latent
        (t .< inf.infectiousness_onset) |> sum,
        # pre symptomatic
        (inf.infectiousness_onset .<= t .< inf.symptoms_onset) |> sum,
        # symptomatic
        (0 .<= inf.symptoms_onset .<= t .< inf.removed) |> sum,
        # asymptomatic
        ((inf.infectiousness_onset .<= t .< inf.removed) .& (inf.symptoms_onset .< 0)) |> sum    
    ] for t in 0:maximum(inf.removed)]
    res = DataFrame(mapreduce(permutedims, vcat, res), [:latent,:pre_symptomatic,:symptomatic,:asymptomatic])
    insertcols!(res,  1, :tick =>  1:(nrow(res)))
    # return converted DataFrame
    return(res)
end