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
in `constants.jl`. If several infections introduce a pathogen into a household
at the same first tick, the one with the lowest infection id counts.

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
    hh_col = infectionsDF(postProcessor).household_b
    hh_selection = _unique_households(hh_col) |>
        x -> gems_sample(_post_processing_rng(simulation(postProcessor), "household_attack_rates"),
            x, min(hh_samples, length(x)), replace = false)

    # sampled households marked by id, so finding their rows needs no hashing
    selected = falses(maximum(skipmissing(hh_col); init = 0))
    foreach(h -> selected[h] = true, hh_selection)

    # make a copy of the infections dataframe to
    # not add this calculation to the internal infections dataframe
    # and take only the rows of the sampled households
    infs = postProcessor |> infectionsDF |>
        x -> DataFrames.select(x, :tick, :id_b, :household_b, :infection_id, :source_infection_id, :setting_type, :pathogen_id, copycols = false) |>
        x -> x[findall(h -> !ismissing(h) && selected[h], hh_col), :] |>
        x -> sort(x, :infection_id)

    # return an empty DataFrame if there are no infections
    if nrow(infs) == 0
        return DataFrame(pathogen_id = Int8[], first_introduction = Int16[], hh_id = Int32[], hh_size = Int16[], chain_size = Int32[], hh_attack_rate = Float64[])
    end

    infs.home_chain, infs.started_chain = _home_chains(infs.infection_id, infs.source_infection_id, infs.setting_type)

    # `household_b` is the infectee's primary household, so only the sampled households are looked up
    hhs = households(simulation(postProcessor))
    infs.hh_id = Int32.(infs.household_b)
    infs.hh_size = Int16[size(hhs[h]) for h in infs.hh_id]

    return infs |>
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

# Per infection, the size of the household chain it started, and whether it started one (was not infected
# at home). Rows are sorted by infection id, so a source's row comes before its infectees' and every chain is
# complete by the time it is added to its source.
function _home_chains(inf_ids::AbstractVector, source_ids::AbstractVector, setting_types::AbstractVector)
    source_rows = _matching_rows(source_ids, inf_ids)
    home_chain = zeros(Int32, length(inf_ids))
    started_chain = fill(true, length(inf_ids))
    for j in length(inf_ids):-1:1
        (setting_types[j] == 'h' && source_rows[j] != 0) || continue
        started_chain[j] = false
        home_chain[source_rows[j]] += 1 + home_chain[j]
    end
    return home_chain, started_chain
end

# `unique(col)` of household ids in first-appearance order, marking seen ids instead of hashing them
function _unique_households(col::AbstractVector)
    seen = falses(maximum(skipmissing(col); init = 0))
    households = eltype(col)[]
    for h in col
        (ismissing(h) || seen[h]) && continue
        seen[h] = true
        push!(households, h)
    end
    return households
end
