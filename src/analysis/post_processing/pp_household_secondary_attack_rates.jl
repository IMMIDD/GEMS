export household_secondary_attack_rates, household_secondary_attack_rate

"""
    household_secondary_attack_rates(postProcessor::PostProcessor; window::Int = 14, coprimary_days::Int = 0,
        index_ticks = nothing, exclude_prior::Bool = true)

Returns household secondary attack rate counts per pathogen and household size, like a household transmission study
with perfect ascertainment (every infection is a case, at its infection tick). An infection in a household where no one
is infected is an index case; household cases within `coprimary_days` of it are co-primaries, later ones within `window` are secondary.

# Parameters

- `window`: Follow-up ticks after the index case; episodes whose window ends after the last tick are dropped
- `coprimary_days`: Cases this many ticks after the index or earlier are co-primaries. 0 separates them exactly, as an
  infection can't spread on its own tick; 2-4 mimics studies that drop contacts already positive at enrolment
- `index_ticks`: Only count episodes whose index case falls in this range (default: all)
- `exclude_prior`: Don't count members whose earlier infection has ended as contacts (exact with lasting immunity)

# Returns

- `DataFrame` with one row per pathogen and household size of 2 or more, also without episodes (rates are then `NaN`):

| Name             | Type      | Description                                                          |
| :--------------- | :-------- | :------------------------------------------------------------------- |
| `pathogen_id`    | `Int8`    | Pathogen identifier                                                  |
| `hh_size`        | `Int16`   | Household size                                                       |
| `episodes`       | `Int64`   | Number of index cases                                                |
| `contacts`       | `Int64`   | Members other than index, co-primaries, dead, infected, prior cases  |
| `secondary`      | `Int64`   | Contacts infected after the co-primary period, within the window     |
| `secondary_home` | `Int64`   | Secondary cases infected in their household                          |
| `sar`            | `Float64` | Secondary attack rate (`secondary / contacts`)                       |
| `sar_home`       | `Float64` | Model-only `secondary_home / contacts`, incl. tertiary cases         |
"""
function household_secondary_attack_rates(postProcessor::PostProcessor; window::Int = 14, coprimary_days::Int = 0,
        index_ticks = nothing, exclude_prior::Bool = true)
    window < 1 && throw(ArgumentError("The window must be at least 1 tick (got $window)."))
    0 <= coprimary_days < window || throw(ArgumentError("coprimary_days must be between 0 and window - 1 (got $coprimary_days)."))

    sim = simulation(postProcessor)
    infs = infectionsDF(postProcessor)
    deaths = deathsDF(postProcessor)
    hh_sizes = map(hh -> Int16(size(hh)), households(sim))

    # `tick(sim)` is one past the last simulated tick
    return _household_sar_counts(_sorted_pathogen_ids(postProcessor), infs.pathogen_id, infs.household_b, infs.id_b,
        infs.infection_id, infs.tick, infs.removed, infs.setting_type, hh_sizes,
        coalesce.(deaths.household, Int32(0)), deaths.id, deaths.tick;
        window = window, coprimary_days = coprimary_days, last_tick = tick(sim) - 1, index_ticks = index_ticks,
        exclude_prior = exclude_prior)
end

"""
    household_secondary_attack_rate(postProcessor::PostProcessor; kwargs...)

Returns the household secondary attack rate per pathogen, pooled over household sizes (`sum(secondary) / sum(contacts)`
of `household_secondary_attack_rates`, which takes the same keyword arguments).

# Returns

- `DataFrame` with the following columns:

| Name                 | Type      | Description                                                    |
| :------------------- | :-------- | :------------------------------------------------------------- |
| `pathogen_id`        | `Int8`    | Pathogen identifier                                            |
| `household_sar`      | `Float64` | Pooled secondary attack rate                                   |
| `household_sar_home` | `Float64` | Pooled model-only `sar_home`                                   |
"""
function household_secondary_attack_rate(postProcessor::PostProcessor; kwargs...)
    return household_secondary_attack_rates(postProcessor; kwargs...) |>
        x -> groupby(x, :pathogen_id) |>
        x -> combine(x,
            [:secondary, :contacts] => ((s, c) -> sum(s) / sum(c)) => :household_sar,
            [:secondary_home, :contacts] => ((s, c) -> sum(s) / sum(c)) => :household_sar_home)
end

# Episode counts per pathogen in `pathogens` and household size from the infection columns; `hh_sizes` is indexed by household id.
function _household_sar_counts(pathogens::Vector{Int8}, pathogen_ids::AbstractVector, households::AbstractVector,
        ids::AbstractVector, infection_ids::AbstractVector, ticks::AbstractVector, removed::AbstractVector,
        setting_types::AbstractVector, hh_sizes::Vector{Int16}, death_households::Vector{Int32},
        death_ids::AbstractVector, death_ticks::AbstractVector;
        window::Int, coprimary_days::Int, last_tick::Integer, index_ticks, exclude_prior::Bool)

    order, offsets = _rows_by_household(households, length(hh_sizes))

    # deaths by household, so each household's deaths are one range
    dorder = sortperm(death_households)
    dh, did, dt = death_households[dorder], death_ids[dorder], death_ticks[dorder]

    # (pathogen, household size) => (episodes, contacts, secondary, secondary_home)
    counts = Dict{Tuple{Int8, Int16}, NTuple{4, Int}}()
    prior, excluded, seen = Int32[], Int32[], Int32[]

    for h in eachindex(hh_sizes)
        lo, hi = offsets[h] + 1, offsets[h + 1]
        lo > hi && continue
        _sort_household_cases!(order, lo, hi, pathogen_ids, ticks, infection_ids)
        dead = searchsorted(dh, h)

        # rows i:j are this household's cases of one pathogen; k:e is one episode
        i = lo
        while i <= hi
            p = pathogen_ids[order[i]]
            j = i
            while j < hi && pathogen_ids[order[j + 1]] == p
                j += 1
            end
            empty!(prior)
            busy_until = Int16(-1)

            k = i
            while k <= j
                t0 = ticks[order[k]]

                # a member still infected at t0 means an earlier outbreak goes on, so this case is no index
                if busy_until > t0
                    ids[order[k]] in prior || push!(prior, ids[order[k]])
                    busy_until = max(busy_until, removed[order[k]])
                    k += 1
                    continue
                end

                e = k
                while e < j && ticks[order[e + 1]] <= t0 + window
                    e += 1
                end

                if t0 + window <= last_tick && (isnothing(index_ticks) || t0 in index_ticks)
                    empty!(excluded)
                    exclude_prior && append!(excluded, prior)
                    for d in dead
                        dt[d] <= t0 && !(did[d] in excluded) && push!(excluded, did[d])
                    end
                    # members still infected at t0 can't be infected again
                    for m in i:k - 1
                        r = order[m]
                        removed[r] > t0 && !(ids[r] in excluded) && push!(excluded, ids[r])
                    end
                    for m in k:e
                        r = order[m]
                        ticks[r] <= t0 + coprimary_days || break
                        ids[r] in excluded || push!(excluded, ids[r])
                    end

                    empty!(seen)
                    home = 0
                    for m in k:e
                        r = order[m]
                        (ticks[r] <= t0 + coprimary_days || ids[r] in excluded || ids[r] in seen) && continue
                        push!(seen, ids[r])
                        setting_types[r] == 'h' && (home += 1)
                    end

                    key = (Int8(p), hh_sizes[h])
                    c = get(counts, key, (0, 0, 0, 0))
                    counts[key] = (c[1] + 1, c[2] + hh_sizes[h] - length(excluded), c[3] + length(seen), c[4] + home)
                end

                for m in k:e
                    ids[order[m]] in prior || push!(prior, ids[order[m]])
                    busy_until = max(busy_until, removed[order[m]])
                end
                k = e + 1
            end
            i = j + 1
        end
    end

    # every pathogen and household size gets a row, so runs return the same rows
    sizes = sort!(unique(s for s in hh_sizes if s > 1))
    df = DataFrame(pathogen_id = repeat(pathogens, inner = length(sizes)), hh_size = repeat(sizes, outer = length(pathogens)))
    c = [get(counts, (p, s), (0, 0, 0, 0)) for (p, s) in zip(df.pathogen_id, df.hh_size)]
    df.episodes = getindex.(c, 1)
    df.contacts = getindex.(c, 2)
    df.secondary = getindex.(c, 3)
    df.secondary_home = getindex.(c, 4)
    df.sar = df.secondary ./ df.contacts
    df.sar_home = df.secondary_home ./ df.contacts
    return df
end

# Rows grouped by household, keeping row order: household h's rows are `order[offsets[h] + 1 : offsets[h + 1]]`.
# A counting sort, O(rows + households).
function _rows_by_household(households::AbstractVector, n_households::Int)
    offsets = zeros(Int32, n_households + 2)
    for h in households
        ismissing(h) && continue
        offsets[h + 2] += 1
    end
    cumsum!(offsets, offsets)
    order = Vector{Int32}(undef, offsets[end])
    for (r, h) in enumerate(households)
        ismissing(h) && continue
        offsets[h + 1] += 1
        order[offsets[h + 1]] = r
    end
    return order, offsets
end

# Insertion sort of `order[lo:hi]` by pathogen, tick and infection id (the lowest id is the index on ties);
# a household holds only a few cases.
function _sort_household_cases!(order::Vector{Int32}, lo::Integer, hi::Integer, pathogen_ids::AbstractVector,
        ticks::AbstractVector, infection_ids::AbstractVector)
    for a in lo + 1:hi
        r = order[a]
        key = (pathogen_ids[r], ticks[r], infection_ids[r])
        b = a - 1
        while b >= lo && (pathogen_ids[order[b]], ticks[order[b]], infection_ids[order[b]]) > key
            order[b + 1] = order[b]
            b -= 1
        end
        order[b + 1] = r
    end
end
