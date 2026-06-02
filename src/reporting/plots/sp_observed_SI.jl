export ObservedSerialInterval

###
### STRUCT
###

"""
    ObservedSerialInterval <: SimulationPlot

A simulation plot type for generating a observed-serial-interval-plot.
"""
@with_kw mutable struct ObservedSerialInterval <: SimulationPlot

    title::String = "Observed Serial Interval" # default title
    description::String = "" # default description empty
    filename::String = "observed_si.png" # default filename

    # indicates to which package the result plot belongs
    # is used to parallelize report generation and prevents
    # concurrent generation of plots coming from the same package
    # if you don't know the origin package or if the function
    # returns different plot types depending on the input,
    # just put ":other" which will trigger sequential generation
    package::Symbol = :Plots
end

###
### PLOT GENERATION
###

function _observed_SI_subplot(data, ft, uticks; plotargs...)
    upper_ticks = uppercasefirst(uticks)
    if isempty(data)
        p = emptyplot("There is no SI estimation data in this ResultData object.")
        plot!(p; plotargs...)
        return p
    end
    max_value = maximum(filter(!isnan, data.upper_95_SI))
    p = plot(xlabel = upper_ticks * "s", ylabel = "Serial Interval",
        xlim = (0, ft), ylim = (0, max_value + 1), dpi = 300, fontfamily = "Times Roman")
    plot!(p, data[!, "tick"], data[!, "mean_SI"], label="Rolling Observed Serial Interval", linewidth=2, color="blue")
    plot!(p, data[!, "tick"], data[!, "lower_95_SI"], fillrange=data[!, "upper_95_SI"],
        label = "95% Confidence Band", alpha=0.2, color="blue")
    plot!(p, data[!, "tick"], data[!, "lower_95_SI"], linewidth=1, linestyle=:dot, label=nothing, alpha=0.5, color="blue")
    plot!(p, data[!, "tick"], data[!, "upper_95_SI"], linewidth=1, linestyle=:dot, label=nothing, alpha=0.5, color="blue")
    plot!(p; plotargs...)
    return p
end

"""
    generate(plt::ObservedSerialInterval, rd::ResultData; plotargs...)

Generates a plot for the estimation on the observed serial interval per tick.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::ObservedSerialInterval`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `pathogen::Union{Nothing, Int8, Integer, AbstractString} = nothing` *(optional)*: Filter to a single pathogen by id or name. Default shows all pathogens as subplots.
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Observed Serial Interval plot
"""
function generate(plt::ObservedSerialInterval, rd::ResultData; pathogen = nothing, plotargs...)

    ft = rd |> final_tick
    uticks = rd |> tick_unit

    desc  = "This graph shows the current observed serial interval (SI) which is being estimated based "
    desc *= "on all detected cases in a $SI_ESTIMATION_TIME_WINDOW-$uticks time window. "
    desc *= "The estimation requires at least $SI_ESTIMATION_CASE_THRESHOLD cases to be "
    desc *= "'known' to achieve a reliable estimation. If this threshold is not met with "
    desc *= "cases from only the last $SI_ESTIMATION_TIME_WINDOW $(uticks)s, the calculation "
    desc *= "expands the time window (into the past) until enough cases have been found. "
    desc *= "This threshold might result in parts of the graph being _empty_ suggesting "
    desc *= "either no detected cases or not enough cases for an SI estimation. "
    desc *= "As the calculation is being done _backwards_ in time, "
    desc *= "some scenarios might need some lead time, before enough infections "
    desc *= "have been recorded to begin estimating SI. "
    desc *= "The blue-shaded area indicates upper- and lower 95% confidence bounds."
    description!(plt, desc)

    si_all, pids, pnames, _ = _pathogen_setup(rolling_observed_SI(rd), rd, pathogen)

    clean_si(df, p) = filter(row -> row.pathogen_id == p, df) |>
        x -> dropmissing(x) |> x -> filter(row -> !any(isnan, row), x)

    if length(pids) == 1
        data = clean_si(si_all, pids[1])
        if isempty(data)
            p = emptyplot("There is no SI estimation data in this ResultData object.")
            plot!(p; plotargs...)
            return p
        end
        return _observed_SI_subplot(data, ft, uticks; plotargs...)
    end

    subplots = [_observed_SI_subplot(
        clean_si(si_all, pid), ft, uticks;
        _pathogen_subargs(pid, pnames, plotargs)...)
        for pid in pids]
    return _multi_pathogen_plot(subplots, plotargs)
end
