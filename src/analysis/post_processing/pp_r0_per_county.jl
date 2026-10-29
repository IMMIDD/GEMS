export r0_per_county

"""
    r0_per_county(postProcessor::PostProcessor; sample_fraction = R0_CALCULATION_SAMPLE_FRACTION)

Returns a dataframe with AGS on county level, pathogen id and a regional reproduction rate.

The R0 value is calculated as the number of infections that were caused
by the first `sample_fraction`% of infections in each county and pathogen. The default
value can be changed in the `R0_CALCULATION_SAMPLE_FRACTION` constant
or just pass a different value as `sample_fraction` argument.

**Attention**: This variant of the R0 calculation expects that the infections
occur in a fully susceptible population, i.e. no immunity is present.
If you have a scenario that includes vaccination or natural immunity,
the R0 value will not be accurate. Since the infector-AGS must be known,
this calculation is based on the `sample_fraction`% of simulated infections
and excludes the seeding infection (as they have no infector ags).
"""
function r0_per_county(postProcessor::PostProcessor; sample_fraction = R0_CALCULATION_SAMPLE_FRACTION)

    if postProcessor |> simulation |> municipalities |> isempty
        #@warn "There are no regions (municipalities) in the input model. Therefore, GEMS cannot process regional incidences."
        return DataFrame()
    end

    # Precompute secondary cases
    infs = infectionsDF(postProcessor)
    # ids are sparse, so this sits slightly above the infection count
    max_inf_id = isempty(infs) ? 0 : maximum(infs.infection_id)

    secondary_counts = _secondary_counts(infs.source_infection_id, max_inf_id)

    return _county_r0(infs.infection_id, infs.pathogen_id, infs.household_ags_a, infs.id_a,
        secondary_counts, sample_fraction)
end

# R per (county, pathogen): the secondary infections caused by each group's first `sample_fraction` of
# infections (by id), per sampled infection. 
function _county_r0(inf_ids::AbstractVector, pids::AbstractVector, infecter_ags::AbstractVector, id_a::AbstractVector,
        secondary_counts::Vector{Int}, sample_fraction)
    # each infection's group by infection id, and each group's (county, pathogen) and size; seeds
    # (`id_a <= 0`) have no infecter and belong to no group
    groups = OrderedCounter{Tuple{Int32, eltype(pids)}}()
    group_of_id = zeros(Int32, isempty(inf_ids) ? 0 : maximum(inf_ids))
    for r in eachindex(inf_ids)
        id_a[r] > 0 || continue
        group_of_id[inf_ids[r]] = count!(groups, (county(infecter_ags[r]).id, pids[r]))
    end

    # ids are dense, so walking them in order visits every group's infections sorted by id
    sample_sizes = [max(Int(ceil(sample_fraction * n)), 1) for n in groups.counts]
    sampled = zeros(Int, length(groups.keys))
    total_secondary = zeros(Int, length(groups.keys))
    for (id, g) in enumerate(group_of_id)
        (g == 0 || sampled[g] == sample_sizes[g]) && continue
        sampled[g] += 1
        total_secondary[g] += id <= length(secondary_counts) ? secondary_counts[id] : 0
    end

    return DataFrame(ags = [AGS(Int(first(k))) for k in groups.keys], pathogen_id = last.(groups.keys),
        r0 = total_secondary ./ sample_sizes)
end

# barrier: a DataFrame column is untyped where it is read, so count behind its concrete type
function _secondary_counts(source_ids::AbstractVector, max_inf_id::Integer)
    counts = zeros(Int, max_inf_id)
    for sid in source_ids
        if !ismissing(sid) && sid > 0 && sid <= max_inf_id
            counts[sid] += 1
        end
    end
    return counts
end
