
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
function _weekly_county_incidence(postProcessor::PostProcessor)

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

    # counted in one pass over the infections instead of grouping each week's rows
    infs = infectionsDF(postProcessor)
    weekly = _weekly_county_infections(infs.tick, infs.household_ags_b, infs.pathogen_id, ft ÷ 7)

    week = 0
    while (week + 1) * 7 <= ft
        new_col = Symbol("week_$week")

        cnts = weekly[week + 1] |>
        df -> rename(df, :infections => new_col) |>
        df -> leftjoin(cnts, df, on = [:ags, :pathogen_id]) |>
        df -> transform(df, new_col => ByRow(x -> coalesce(x, 0)) => new_col) |>
        df -> transform(df, [new_col, :size] => ((i, s) -> (i .* 100_000) ./ s) => new_col)

        week += 1
    end

    return DataFrames.select(cnts, Not(:size))
end

# `_county_infections` for every week, counted in a single pass over the infections
function _weekly_county_infections(ticks::AbstractVector, ags_col::AbstractVector, pids::AbstractVector, nweeks::Int)
    weeks = [OrderedCounter{Tuple{Int32, eltype(pids)}}() for _ in 1:nweeks]
    for (t, a, p) in zip(ticks, ags_col, pids)
        (ismissing(t) || ismissing(a)) && continue
        w = _week_of(t)
        1 <= w <= nweeks && count!(weeks[w], (a.id, p))
    end
    return _county_frame.(weeks)
end

# one week's municipality counts, summed per county
function _county_frame(municipalities::OrderedCounter{Tuple{Int32, P}}) where {P}
    counties = OrderedCounter{Tuple{Int32, P}}()
    for ((ags_id, pid), n) in zip(municipalities.keys, municipalities.counts)
        count!(counties, (county(AGS(Int(ags_id))).id, pid), n)
    end
    return DataFrame(ags = [AGS(Int(first(k))) for k in counties.keys],
        pathogen_id = last.(counties.keys), infections = counties.counts)
end

# the week a tick belongs to; week 1 holds ticks 1-7
_week_of(tick::Integer) = tick >= 1 ? (Int(tick) - 1) ÷ 7 + 1 : 0
