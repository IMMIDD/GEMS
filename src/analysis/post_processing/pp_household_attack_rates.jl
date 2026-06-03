export household_attack_rate

"""
    household_attack_rates(postProcessor::PostProcessor; hh_samples::Int64 = HOUSEHOLD_ATTACK_RATE_SAMPLES)

Returns a `DataFrame` containing data on the in-household attack rate, per pathogen.
The in-household attack rate is defined as the fraction of individuals
in a given household that got infected within the household
(in-household infection chain) caused by the *first* introduction of
the pathogen in this household. It does *not* reflect *overall*
fraction of individuals that were infected in this household throughout
the course of the simuation. As the attack rate calculation is very
computationally intensive, it is not done for _all_ household but rather
for a subset of households. You can change the desired subset size
through the optional `hh_samples` argument. Its default can be found
in `constants.jl`

# Returns

- `DataFrame` with the following columns:

| Name                 | Type      | Description                                                           |
| :------------------- | :-------- | :-------------------------------------------------------------------- |
| `pathogen_id`        | `Int8`    | Pathogen identifier                                                   |
| `first_introduction` | `Int16`   | Time of when the first member of the respective household was exposed |
| `hh_id`              | `Int32`   | Household setting identifier                                          |
| `hh_size`            | `Int16`   | Household size                                                        |
| `chain_size`         | `Int32`   | Number of individuals that got infected within the household          |
| `hh_attack_rate`     | `Float64` | Number of infected individuals divided by household size              |
"""
function household_attack_rates(postProcessor::PostProcessor; hh_samples::Int64 = HOUSEHOLD_ATTACK_RATE_SAMPLES)
    # exception handling
    hh_samples <= 100 ? throw(ArgumentError("Sample too low. You need at least 100 households to proceed with the calculation")) : nothing

    # randomly sample the required number of households from the infections dataframe
    hh_selection = (postProcessor |> infectionsDF).household_b |> unique |>
        x -> gems_sample(rng(postProcessor |> simulation), x, min(hh_samples, length(x)), replace = false) |>
        x -> DataFrame(household_b = x, select = fill(true, length(x)))

    # make a copy of the infections dataframe to
    # not add this calculation to the internal infections dataframe
    # and take only a subset based on the specified sample size
    infs = postProcessor |> infectionsDF |>
        x -> DataFrames.select(x, :tick, :id_b, :household_b, :infection_id, :source_infection_id, :setting_type, :pathogen_id) |>
        x -> leftjoin(x, hh_selection, on = :household_b) |>
        x -> subset(x, :select => ByRow(!ismissing), view=true) |>
        x -> sort(x, :infection_id) |>
        copy

    # return an empty DataFrame if there are no infections
    if nrow(infs) == 0
        return DataFrame(pathogen_id = Int8[], first_introduction = Int16[], hh_id = Int32[], hh_size = Int16[], chain_size = Int32[], hh_attack_rate = Float64[])
    end

    # Extract columns to standard vectors for type-stable loop operations
    source_id_col = infs.source_infection_id
    inf_id_col = infs.infection_id
    setting_col = infs.setting_type

    # size of infection chain this particular infection started in a household
    home_chain_col = zeros(Int32, nrow(infs))

    # flag whether this infection was acquired outside the household (primary cases)
    started_chain_col = fill(true, nrow(infs))

    # Pre-calculate the parent->child relationships in a Dictionary
    home_children = Dict{eltype(source_id_col), Vector{Int}}()
    for j in 1:nrow(infs)
        if setting_col[j] == 'h'
            push!(get!(home_children, source_id_col[j], Int[]), j)
        end
    end

    # iterate through sorted infections dataframe backwards
    for i in nrow(infs):-1:1
        current_inf_id = inf_id_col[i]

        if haskey(home_children, current_inf_id)
            for j in home_children[current_inf_id]
                started_chain_col[j] = false
                home_chain_col[i] += (1 + home_chain_col[j])
            end
        end
    end

    infs.home_chain = home_chain_col
    infs.started_chain = started_chain_col

    # generate dataframe of households
    hh_sizes = DataFrame(
        ind_id = Int32.(id.(postProcessor |> simulation |> individuals)),
        hh_id = Int32.(id.((i -> household(i, postProcessor |> simulation)).(postProcessor |> simulation |> individuals))),
        hh_size = Int16.(size.((i -> household(i, postProcessor |> simulation)).(postProcessor |> simulation |> individuals))))

    return infs |>
        x -> leftjoin(x, hh_sizes, on = [:id_b => :ind_id]) |>
        x -> DataFrames.select(x, :tick, :hh_id, :home_chain, :started_chain, :hh_size, :pathogen_id) |>
        x -> x[x.started_chain, :] |>
        x -> groupby(x, [:hh_id, :pathogen_id]) |>
        x -> combine(x,
            :tick => minimum => :first_introduction,
            [:tick, :home_chain] => ((tick, chain) -> isempty(chain) ? 0 : chain[argmin(tick)]) => :chain_size,
            [:tick, :hh_size] => ((tick, size) -> isempty(size) ? 0 : size[argmin(tick)]) => :hh_size) |>
        x -> transform(x, [:chain_size, :hh_size] => ByRow((c, h) -> (h == 0 ? 0 : c / (h - 1))) => :hh_attack_rate) |>
        x -> sort(x, :first_introduction) |>
        x -> DataFrames.select(x, :pathogen_id, :first_introduction, :hh_id, :hh_size, :chain_size, :hh_attack_rate)
end
