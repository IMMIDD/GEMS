export county_infections_between
export weekly_county_incidence

"""
    county_infections_between(postProcessor::PostProcessor, start_tick::Int64, end_tick::Int64)

Returns a `DataFrame` with the county region code (`AGS`), pathogen id,
and the number of infections in that region during the provided time
window (`start_tick` and `end_tick`)
"""
function county_infections_between(postProcessor::PostProcessor, start_tick::Int64, end_tick::Int64)

    if start_tick > end_tick
        throw(ArgumentError("Start tick cannot be larger than end tick."))
    end

    return infectionsDF(postProcessor) |>
        df -> subset(df, :tick => ByRow(t -> start_tick <= t <= end_tick), view=true) |>
        df -> dropmissing(df, :household_ags_b, view=true) |>
        df -> groupby(df, [:household_ags_b, :pathogen_id]) |>
        df -> combine(df, nrow => :infections) |>
        df -> transform(df, :household_ags_b => ByRow(county) => :ags) |>
        df -> groupby(df, [:ags, :pathogen_id]) |>
        df -> combine(df, :infections => sum => :infections)
end


"""
    weekly_county_incidence(postProcessor::PostProcessor)

Calculates the incidence per county (AGS), pathogen and week (7-day period)
in the simulation, starting at tick 1. Weeks are tick 1-7, 8-14, etc...

Returns a `DataFrame` with columns `ags`, `pathogen_id` and one column for each week
of the simulation (`week_1`, `week_2`, `...`).
Each row contains the weekly incidence per 100,000 per county and pathogen.
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
        df -> groupby(df, :ags) |>
        df -> combine(df, :size => sum => :size)

    # cross with all pathogens so every (ags, pathogen_id) gets an entry
    cnts = crossjoin(cnts, DataFrame(pathogen_id = collect(map(id, pathogens(simulation(postProcessor))))))

    week = 0
    while (week + 1) * 7 <= ft
        new_col = Symbol("week_$week")

        cnts = county_infections_between(
            postProcessor,
            week * 7 + 1,
            (week + 1) * 7) |>
        df -> rename(df, :infections => new_col) |>
        df -> leftjoin(cnts, df, on = [:ags, :pathogen_id]) |>
        df -> transform(df, new_col => ByRow(x -> coalesce(x, 0)) => new_col) |>
        df -> transform(df, [new_col, :size] => ((i, s) -> (i .* 100_000) ./ s) => new_col)

        week += 1
    end

    return DataFrames.select(cnts, Not(:size))
end
