
"""
    _county_infections_between(postProcessor::PostProcessor, start_tick::Int64, end_tick::Int64)

Returns a `DataFrame` with the county region code (`AGS`), pathogen id,
and the number of infections in that region during the provided time
window (`start_tick` and `end_tick`)
"""
function _county_infections_between(postProcessor::PostProcessor, start_tick::Int64, end_tick::Int64)

    if start_tick > end_tick
        throw(ArgumentError("Start tick cannot be larger than end tick."))
    end

    return infectionsDF(postProcessor) |>
        df -> subset(df, :tick => ByRow(t -> start_tick <= t <= end_tick), view=true) |>
        _county_infections
end

# the county counts of `_county_infections_between`, for infections already restricted to the time window
function _county_infections(infs::AbstractDataFrame)
    return infs |>
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
_weekly_county_incidence(postProcessor::PostProcessor) = _exclusive(() -> _weekly_county_incidence_inner(postProcessor))

function _weekly_county_incidence_inner(postProcessor::PostProcessor)

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

    # each week's rows, bucketed once instead of filtering every infection once per week
    infs = infectionsDF(postProcessor)
    week_rows = _rows_by_week(infs.tick, ft ÷ 7)

    week = 0
    while (week + 1) * 7 <= ft
        new_col = Symbol("week_$week")

        cnts = _county_infections(view(infs, week_rows[week + 1], :)) |>
        df -> rename(df, :infections => new_col) |>
        df -> leftjoin(cnts, df, on = [:ags, :pathogen_id]) |>
        df -> transform(df, new_col => ByRow(x -> coalesce(x, 0)) => new_col) |>
        df -> transform(df, [new_col, :size] => ((i, s) -> (i .* 100_000) ./ s) => new_col)

        week += 1
    end

    return DataFrames.select(cnts, Not(:size))
end

# row indices per week (week 1 = ticks 1-7), in row order
function _rows_by_week(ticks::AbstractVector, nweeks::Int)
    week(t) = t >= 1 ? (Int(t) - 1) ÷ 7 + 1 : 0
    # count first, so every bucket is allocated once at its final size
    counts = zeros(Int, nweeks)
    for t in ticks
        1 <= week(t) <= nweeks && (counts[week(t)] += 1)
    end
    rows = [sizehint!(Int32[], c) for c in counts]
    for (r, t) in enumerate(ticks)
        1 <= week(t) <= nweeks && push!(rows[week(t)], Int32(r))
    end
    return rows
end
