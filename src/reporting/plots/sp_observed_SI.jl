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

"""
    generate(plt::ObservedSerialInterval, rd::ResultData; plotargs...)

Generates a plot for the estimation on the observed serial interval per tick.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::ObservedSerialInterval`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Observed Serial Interval plot
"""
function generate(plt::ObservedSerialInterval, rd::ResultData; plotargs...)
    
    # the dataframe may contain missing values
    # as R can only be calculated with enough baseline infection data
    data = rd |> rolling_observed_SI |> dropmissing |>
        x -> filter(row -> (!any(isnan, row)), x)
    
    # return empty plot with message, if result data does not contain tests
    if data |> isempty
        desc  = "There is no data in the ResultData object to base an observed serial interval (SI) estimation on. "
        desc *= "Reasons can be: (1) no or not enough detected cases in this scenario or (2) The _ResultDataStyle_ "
        desc *= "you are using does not provide the SI estimation. **Note:** The 'Observed Progression' "
        desc *= "section bases all calculations on detected cases suggesting that you need some sort of "
        desc *= "_testing_ intervention in your scenario to identify infections."

        description!(plt, desc)
        
        plot_tests = emptyplot("There is no SI estimation data in this ResultData object.")
        plot!(plot_tests; plotargs...)
        return(plot_tests)
    end
    
    # find the maximum value to x- and y-scale the plot
    ft = rd |> final_tick
    max_value = maximum(filter(!isnan, data.upper_95_SI))

    uticks = rd |> tick_unit
    upper_ticks = uticks |> uppercasefirst

    # add description
    desc  = "This graph shows the current observed serial interval (SI) which is being estimated based "
    desc *= "on all detected cases in a $SI_ESTIMATION_TIME_WINDOW-$uticks time window. "
    desc *= "The estimation requires at least $SI_ESTIMATION_CASE_THRESHOLD cases to be "
    desc *= "'known' to achieve a reliable estimtaion. If this threshold is not met with "
    desc *= "cases from only the last $SI_ESTIMATION_TIME_WINDOW $(uticks)s, the calculation "
    desc *= "expands the time window (into the past) until enough cases have been found. "
    desc *= "This threshold might result in parts of the graph being _empty_ suggesting "
    desc *= "either no detected cases or not enough cases for an SI estimation. "
    desc *= "As the calculation is being done _backwards_ in time, "
    desc *= "some scenarios might need some lead time, before enough infections "
    desc *= "have been recorded to begin estimating SI. "
    desc *= "The blue-shaded area indicates upper- and lower 95% confidence bounds."

    description!(plt, desc)

    obs_SI = plot(xlabel=upper_ticks * "s", ylabel="Serial Interval", xlim = (0, ft), ylim = (0, max_value + 1), dpi=300, fontfamily = "Times Roman")

    # mean
    plot!(obs_SI, data[!,"tick"], data[!,"mean_SI"], label="Rolling Observed Serial Interval", linewidth=2, color="blue")
    # upper/lower bounds with outline
    plot!(obs_SI, data[!,"tick"], data[!,"lower_95_SI"], fillrange=data[!,"upper_95_SI"],label = "95% Confidence Band", alpha=0.2, color="blue")
    plot!(obs_SI, data[!,"tick"], data[!,"lower_95_SI"], linewidth=1,linestyle =:dot, label=nothing, alpha=0.5, color="blue")
    plot!(obs_SI, data[!,"tick"], data[!,"upper_95_SI"], linewidth=1,linestyle =:dot, label=nothing, alpha=0.5, color="blue")

    # add custom arguments that were passed
    plot!(obs_SI; plotargs...)

    return(obs_SI)
end