export r0_per_county

"""
    r0_per_county(postProcessor::PostProcessor; sample_fraction = R0_CALCULATION_SAMPLE_FRACTION)

Returns a two-column dataframe with AGS on county level and a regional reproduction rate.

The R0 value is calculated as the number of infections that were caused
by the first `sample_fraction`% of infections in each county. The default
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

    # calcuates R for infection ids in grouped dataframe
    function calc_r(infection_ids)
        sample_size = max(Int(ceil(sample_fraction * length(infection_ids))), 1)
        
        # select first "sample_fraction" infections
        return sort(infection_ids) |>
            vec -> vec[1:sample_size] |>
            vec -> DataFrame(id = vec) |>
            # join with source infection to get secondary cases
            df -> leftjoin(df, select(infectionsDF(postProcessor), :source_infection_id), on = [:id => :source_infection_id]) |>
            df -> (nrow(df) / sample_size)
    end

    return sim_infectionsDF(postProcessor) |>
        # select and transform AGS to county codes
        df -> DataFrames.select(df, :infection_id, :household_ags_a => (a -> county.(a)) => :ags) |>
        df -> groupby(df, :ags) |>
        df -> combine(df, :infection_id => calc_r => :r0)
end