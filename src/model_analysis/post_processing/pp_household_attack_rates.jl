export household_attack_rates

""" 
    household_attack_rates(postProcessor::PostProcessor; hh_samples::Int64 = HOUSEHOLD_ATTACK_RATE_SAMPLES)

Returns a `DataFrame` containing data on the in-household attack rate.
The in-household attack rate is defined as the fraction of individuals
in a given household that got infected within the household
(in-household infection chain) caused by the *first* introduction of 
the pathogen in this household. It does *not* reflect *overall*
fraction of individuals that were infected in this household throughout
the course of the simuation.

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

function household_attack_rates(postProcessor::PostProcessor)
    infs = postProcessor |> infectionsDF

    n = nrow(infs)
    if n == 0
        return DataFrame(first_introduction = Int16[], hh_id = Int32[], hh_size = Int16[], chain_size = Int32[], hh_attack_rate = Float64[])
    end

    # permutation for sorting by infection_id
    sort_idx = sortperm(infs.infection_id)

    home_chain = zeros(Int32, n)  # size of household infection subtree
    started_chain = fill(true, n) # true if this infection started a household chain

    # indexing
    id_to_row = Dict{Int, Int}(infs.infection_id[sort_idx[i]] => sort_idx[i] for i in 1:n)
    household_to_first_infection = Dict{Int, Int}()

    # identify household introductions
    for i in 1:n
        idx = sort_idx[i]
        hh = infs.household_b[idx]
        # update if this is the earliest infection in the household
        if !haskey(household_to_first_infection, hh) || infs.tick[idx] < infs.tick[household_to_first_infection[hh]]
            household_to_first_infection[hh] = idx
        end
    end

    #compute household chain sizes
    for i in n:-1:1
        idx = sort_idx[i]
        parent_id = infs.source_infection_id[idx]
        # skip if no parent (parent_id == -1) or non-household infection
        parent_id == -1 && continue
        infs.setting_type[idx] != 'h' && continue

        # find parent row 
        parent_row = get(id_to_row, parent_id, -1)
        parent_row == -1 && continue 

        # propagate chain size upward and mark as secondary
        if infs.household_b[idx] == infs.household_b[parent_row]
            home_chain[parent_row] += 1 + home_chain[idx]
            started_chain[idx] = false
        end
    end

    # generate dataframe of households
    hh_sizes = DataFrame(
        ind_id = Int32.(id.(postProcessor |> simulation |> individuals)),
        hh_id = Int32.(id.((i -> household(i, postProcessor |> simulation)).(postProcessor |> simulation |> individuals))),
        hh_size = Int16.(size.((i -> household(i, postProcessor |> simulation)).(postProcessor |> simulation |> individuals)))
    )

    # filter for first introductions
    first_infs = Int[]
    hh_ids = Int32[]
    ticks = Int[]
    chain_sizes = Int32[]
    id_bs = Int32[]
    for i in 1:n
        if started_chain[i]
            push!(first_infs, i)
            push!(hh_ids, infs.household_b[i])
            push!(ticks, infs.tick[i])
            push!(chain_sizes, home_chain[i])
            push!(id_bs, infs.id_b[i])
        end
    end

    intro_df = DataFrame(
        tick = Int.(ticks),
        hh_id = Int32.(hh_ids),
        chain_size = Int32.(chain_sizes),
        id_b = Int32.(id_bs)
    )
    
    # join with hh_sizes
    result = leftjoin(intro_df, select(hh_sizes, :ind_id, :hh_size), on = [:id_b => :ind_id])

    # group by hh_id and compute aggregates 
    grouped = groupby(result, :hh_id)
    combined = combine(grouped,
        :tick => minimum => :first_introduction,
        [:tick, :chain_size] => ((tick, chain) -> isempty(chain) ? 0 : chain[argmin(tick)]) => :chain_size,
        [:tick, :hh_size] => ((tick, size) -> isempty(size) ? 0 : size[argmin(tick)]) => :hh_size
    )

    # calculate household attack rate
    transform!(combined, [:chain_size, :hh_size] => ByRow((c, h) -> (h == 0 ? 0 : c / (h - 1))) => :hh_attack_rate)
    sort!(combined, :first_introduction)
    select!(combined, :first_introduction, :hh_id, :hh_size, :chain_size, :hh_attack_rate)

    return combined
end