export r0

"""
    r0(postProcessor::PostProcessor; sample_fraction = R0_CALCULATION_SAMPLE_FRACTION)

Returns a `DataFrame` with the R0 value per pathogen.
Requires the `infectionsDF` to have consecutive infection IDs starting from 1
(which is the default in GEMS).

The R0 value is calculated as the number of infections caused by the first
`sample_fraction`% of infections of each pathogen. `partialsort` is used to find
the infection-ID threshold in O(N) average time.

**Attention**: This variant of the R0 calculation expects that the infections
occur in a fully susceptible population, i.e. no immunity is present.
If you have a scenario that includes vaccination or natural immunity,
the R0 value will not be accurate.

# Returns

- `DataFrame` with the following columns:

| Name          | Type      | Description         |
| :------------ | :-------- | :------------------ |
| `pathogen_id` | `Int8`    | Pathogen identifier |
| `r0`          | `Float64` | Basic R0 value      |
"""
function r0(postProcessor::PostProcessor; sample_fraction = R0_CALCULATION_SAMPLE_FRACTION)
    infs = infectionsDF(postProcessor)
    result = DataFrame(pathogen_id = Int8[], r0 = Float64[])
    for p in pathogens(simulation(postProcessor))
        pid = id(p)
        p_infs = subset(infs, :pathogen_id => ByRow(==(pid)), view=true)
        nrow(p_infs) == 0 && continue
        sample_size = max(Int(ceil(sample_fraction * nrow(p_infs))), 1)
        threshold = partialsort(p_infs.infection_id, sample_size)
        count = sum(sid -> !ismissing(sid) && sid > 0 && sid <= threshold, p_infs.source_infection_id)
        push!(result, (pid, count / sample_size))
    end
    return result
end
