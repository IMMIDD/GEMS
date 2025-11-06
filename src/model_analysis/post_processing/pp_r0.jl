export r0

"""
    r0(postProcessor::PostProcessor; sample_fraction = R0_CALCULATION_SAMPLE_FRACTION)

Returns the R0 value for the provided post processor.
Requires the `infectionsDF` to have consecutive infection IDs starting from 1
(which is the default in GEMS)

The R0 value is calculated as the number of infections that were caused by the first `sample_fraction`% of infections.
The default value can be changed in the `R0_CALCULATION_SAMPLE_FRACTION` constant
or just pass a different value as `sample_fraction` argument.

**Attention**: This variant of the R0 calculation expects that the infections
occur in a fully susceptible population, i.e. no immunity is present.
If you have a scenario that includes vaccination or natural immunity,
the R0 value will not be accurate.
"""
function r0(postProcessor::PostProcessor; sample_fraction = R0_CALCULATION_SAMPLE_FRACTION)

    res_r0 = infectionsDF(postProcessor)
    sample_size = max(Int(ceil(sample_fraction * nrow(res_r0))), 1)

    return res_r0.source_infection_id |>
        vec -> (vec .>= 0 .&& vec .<= sample_size)  |>
        bools -> sum(bools) / sample_size
end