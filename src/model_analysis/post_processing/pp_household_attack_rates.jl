export household_attack_rates, household_attack_rates_fast

""" 
    household_attack_rates(postProcessor::PostProcessor; hh_samples::Int64 = HOUSEHOLD_ATTACK_RATE_SAMPLES)

Returns a `DataFrame` containing data on the in-household attack rate.
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
| `first_introduction` | `Int16`   | Time of when the first member of the respective household was exposed |
| `hh_id`              | `Int32`   | Household setting identifier                                          |
| `hh_size`            | `Int16`   | Household size                                                        |
| `chain_size`         | `Int32`   | Number of individuals that got infected within the household          |
| `hh_attack_rate`     | `Float64` | Number of infected individuals divided by household size              |
"""
function household_attack_rates(postProcessor::PostProcessor; hh_samples::Int64 = HOUSEHOLD_ATTACK_RATE_SAMPLES)
    # exception handling
    hh_samples <= 100 ? throw("Sample too low. You need at least 100 households to proceed with the calculation") : nothing

    # randomly sample the required number of households from the infections dataframe
    hh_selection = (postProcessor |> infectionsDF).household_b |> unique |>
        x -> sample(x, min(hh_samples, length(x)), replace = false) |>
        x -> DataFrame(household_b = x, select = fill(true, length(x)))

    # make a copy of the infections dataframe to
    # not add this calculation to the internal infections dataframe
    # and take only a subset based on the specified sample size
    infs = postProcessor |> infectionsDF |>
        x -> DataFrames.select(x, :tick, :id_b, :household_b, :infection_id, :source_infection_id, :setting_type) |>
        # filter for infections of agents with selected households
        x -> leftjoin(x, hh_selection, on = :household_b) |>
        x -> x[.!ismissing.(x.select), :] |>
        x -> sort(x, :infection_id) |>
        copy

    # return an empty DataFrame if there are no infections
    if nrow(infs) == 0
        return DataFrame(first_introduction = Int16[], hh_id = Int32[], hh_size = Int16[], chain_size = Int32[], hh_attack_rate = Float64[])
    end

    # size of infection chain this particular infection
    # started in a household
    infs.home_chain = zeros(Int32, nrow(infs))
    # flag whether this individual is the first to introduce
    # an infection into its household
    infs.started_chain = fill(true, nrow(infs))
    # tempoary id
    infs.temp_id = collect(1:nrow(infs))
    
    # iterate through sorted infections dataframe backwards
    # and "semi-recursively" add up the infection chain
    # in their household starting from this individual
    # TODO: This loop can probably be parallelized
    for i in nrow(infs):-1:1
        # (direct) infections were caused by this infection at home
        secondary = infs[infs.source_infection_id .== infs.infection_id[i] .&& infs.setting_type .== 'h', :]

        # iterate over secondary cases
        for s in eachrow(secondary)
            # tell secondary cases, they're not the first
            infs.started_chain[s.temp_id] = false
            # count infection chain length (in households)
            infs.home_chain[i] += (1 + s.home_chain)
        end
    end

    # generate dataframe of households
    hh_sizes = DataFrame(
        ind_id = Int32.(id.(postProcessor |> simulation |> individuals)),
        hh_id = Int32.(id.((i -> household(i, postProcessor |> simulation)).(postProcessor |> simulation |> individuals))),
        hh_size = Int16.(size.((i -> household(i, postProcessor |> simulation)).(postProcessor |> simulation |> individuals))))

    return infs |> 
        # join infections with household data
        x -> leftjoin(x, hh_sizes, on = [:id_b => :ind_id]) |>
        x -> DataFrames.select(x, :tick, :hh_id, :home_chain, :started_chain, :hh_size) |>
        # filter for infections that were the first introduced in a household
        x -> x[x.started_chain, :] |>
        # group by household IDs to find first introduction
        x -> groupby(x, :hh_id) |>
        x -> combine(x,
            :tick => minimum => :first_introduction,
            [:tick, :home_chain] => ((tick, chain) -> isempty(chain) ? 0 : chain[argmin(tick)]) => :chain_size,
            [:tick, :hh_size] => ((tick, size) -> isempty(size) ? 0 : size[argmin(tick)]) => :hh_size) |>
        # calculate household attack rate
        x -> transform(x, [:chain_size, :hh_size] => ByRow((c, h) -> (h == 0 ? 0 : c / (h - 1))) => :hh_attack_rate) |>
        x -> sort(x, :first_introduction) |>
        x -> DataFrames.select(x, :first_introduction, :hh_id, :hh_size, :chain_size, :hh_attack_rate)
end

function household_attack_rates_fast(postProcessor::PostProcessor)
    infs = copy(postProcessor |> infectionsDF)
    select!(infs, :tick, :id_b, :household_b, :infection_id, :source_infection_id, :setting_type)

    n = nrow(infs)
    if n == 0
        return DataFrame(first_introduction = Int16[], hh_id = Int32[], hh_size = Int16[], chain_size = Int32[], hh_attack_rate = Float64[])
    end
    infs.home_chain = zeros(Int32, n)  # size of household infection subtree
    infs.started_chain = fill(true, n) # true if this infection started a household chain

    # indexing
    id_to_row = Dict{Int, Int}(infs.infection_id[i] => i for i in 1:n)
    household_to_first_infection = Dict{Int, Int}()

    # identify household introductions
    for i in 1:n
        hh = infs.household_b[i]
        # update if this is the earliest infection in the household
        if !haskey(household_to_first_infection, hh) || infs.tick[i] < infs.tick[household_to_first_infection[hh]]
            household_to_first_infection[hh] = i
        end
    end

    #compute household chain sizes
    for i in n:-1:1
        parent_id = infs.source_infection_id[i]
        # skip if no parent (parent_id == -1) or non-household infection
        parent_id == -1 && continue
        infs.setting_type[i] != 'h' && continue

        # find parent row 
        parent_row = get(id_to_row, parent_id, -1)
        parent_row == -1 && continue 

        # propagate chain size upward and mark as secondary
        infs.home_chain[parent_row] += 1 + infs.home_chain[i]
        infs.started_chain[i] = false
    end

    # generate dataframe of households
    hh_sizes = DataFrame(
        ind_id = Int32.(id.(postProcessor |> simulation |> individuals)),
        hh_id = Int32.(id.((i -> household(i, postProcessor |> simulation)).(postProcessor |> simulation |> individuals))),
        hh_size = Int16.(size.((i -> household(i, postProcessor |> simulation)).(postProcessor |> simulation |> individuals))))


    return infs |> 
        # join infections with household data
        x -> leftjoin(x, hh_sizes, on = [:id_b => :ind_id]) |>
        x -> DataFrames.select(x, :tick, :hh_id, :home_chain, :started_chain, :hh_size) |>
        # filter for infections that were the first introduced in a household
        x -> x[x.started_chain, :] |>
        # group by household IDs to find first introduction
        x -> groupby(x, :hh_id) |>
        x -> combine(x,
            :tick => minimum => :first_introduction,
            [:tick, :home_chain] => ((tick, chain) -> chain[argmin(tick)]) => :chain_size,
            [:tick, :hh_size] => ((tick, size) -> size[argmin(tick)]) => :hh_size) |>
        # calculate household attack rate
        x -> transform(x, [:chain_size, :hh_size] => ByRow((c, h) -> (h == 0 ? 0 : c / (h - 1))) => :hh_attack_rate) |>
        x -> sort(x, :first_introduction) |>
        x -> DataFrames.select(x, :first_introduction, :hh_id, :hh_size, :chain_size, :hh_attack_rate)
end