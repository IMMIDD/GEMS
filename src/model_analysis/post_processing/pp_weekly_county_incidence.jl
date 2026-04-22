export county_infections_between
export weekly_county_incidence

"""
    county_infections_between(postProcessor::PostProcessor, start_tick::Int64, end_tick::Int64)

Returns a two-column `DataFrame` with the county region code (`AGS`)
and the number of infections in that region during the provided time
window (`start_tick` and `end_tick`)
"""
function county_infections_between(postProcessor::PostProcessor, start_tick::Int64, end_tick::Int64)
   
    if start_tick > end_tick
        throw("Start tick cannot be larger than end tick.")
    end

    # filter for infections in time frame
    return infectionsDF(postProcessor) |>
        df -> DataFrames.select(df, :tick, :household_ags_b) |>
        df -> df[start_tick .<= df.tick .&& df.tick .<= end_tick, :] |>
        # get county AGS of infected idividual
        df -> transform(df, :household_ags_b => (a -> county.(a)) => :ags) |>
        # sum up infection per county
        df -> groupby(df, :ags) |>
        df -> combine(df, nrow => :infections)
end


"""
    weekly_county_incidence(postProcessor::PostProcessor)

Calculates the incidence per county (AGS) and week (7-day period)
in the simulation, starting at tick 1. Weeks are tick 1-7, 8-14, etc...

Returns a `DataFrame` with an index column (`AGS`) for each German county
and one column for each week of the simulation (`week_1`, `week_2`, `...`).
Each row contains the weekly incidence per 100,000 per county.
"""
function weekly_county_incidence(postProcessor::PostProcessor)

    if postProcessor |> simulation |> municipalities |> isempty
        #@warn "There are no regions (municipalities) in the input model. Therefore, GEMS cannot process regional incidences."
        return DataFrame()
    end

    ft = postProcessor |> simulation |> tick

    # get county information from simulation
    cnts = postProcessor |> simulation |> municipalities |>
        m -> DataFrame(
                ags = county.(ags.(m)),
                size = size.(m)) |>
        # sum up municipality sizes
        df -> groupby(df, :ags) |>
        df -> combine(df, :size => sum => :size)

    week = 0
    while (week + 1) * 7 <= ft
        # name for new column
        new_col = Symbol("week_$week")
        
        # get weekly infections
        cnts = county_infections_between(
            postProcessor,
            week * 7 + 1, # start tick
            (week + 1) * 7) |> # end tick
        # join with municipality data
        df -> rename(df, :infections => new_col) |>
        df -> leftjoin(cnts, df, on = :ags) |>
        df -> transform(df, new_col => ByRow(x -> coalesce(x, 0)) => new_col) |>
        # get incidence per 100,000
        df -> transform(df, [new_col, :size] => ((i, s) -> (i .* 100_000) ./ s) => new_col)

        week += 1
    end

    return DataFrames.select(cnts, Not(:size))
end