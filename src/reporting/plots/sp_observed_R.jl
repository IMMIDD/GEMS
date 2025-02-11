export ObservedReproduction

###
### STRUCT
###

"""
    ObservedReproduction <: SimulationPlot

A simulation plot type for generating a observed-reproduction-number-plot.
"""
@with_kw mutable struct ObservedReproduction <: SimulationPlot

    title::String = "Observed Reproduction Number" # default title
    description::String = "" # default description empty
    filename::String = "observed_r.png" # default filename

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
     generate(plt::ObservedReproduction, rd::ResultData; plotargs...)

Generates a plot for the effective reproduction number per tick.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::ObservedReproduction`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Observed Reproduction Number plot
"""
function generate(plt::ObservedReproduction, rd::ResultData; plotargs...)

    # the dataframe may contain missing values
    # as R can only be calculated with enough baseline infection data
    data = rd |> observed_R |> dropmissing
    ft = rd |> final_tick

    # find y-limit parameter for plot
    y_max = data |> isempty ? 2 : maximum(data.upper_est_R) + 1

    uticks = rd |> tick_unit
    upper_ticks = uticks |> uppercasefirst

    # add description
    desc  = "The observed reproduction number is calculated based on the detected (!) cases "
    desc *= "in a $R_ESTIMATION_TIME_WINDOW-$uticks time window and "
    desc *= "the $SI_ESTIMATION_TIME_WINDOW-$uticks estimation of the serial interval (SI). "
    desc *= "To achieve somewhat reliable data, R is only calculated for time windows "
    desc *= "with a total of at least $R_CALCULATION_THRESHOLD detected infections "
    desc *= "which might result in parts of the graph being _empty_. "
    desc *= "Moreover, as the calculation of R is being done _backwards_ in time, "
    desc *= "some scenarios might need some lead time, before enough infections "
    desc *= "have been recorded to begin estimating R. "
    desc *= "The blue-shaded area indicates upper- and lower bounds of the R-estimation "
    desc *= "derived from the 95%-confidence bounds of the SI estimation."

    description!(plt, desc)

    obs_R = plot(xlabel=upper_ticks * "s", ylabel="Observed Effective R", xlim = (0, ft), ylim = (0, y_max), dpi=300, fontfamily = "Times Roman")

    # mean
    plot!(obs_R, data[!,"tick"], data[!,"mean_est_R"], label="Mean Estimated R", linewidth=2, color="blue")
    # upper/lower bounds with outline
    plot!(obs_R, data[!,"tick"], data[!,"lower_est_R"], fillrange=data[!,"upper_est_R"],label = "95% Confidence Band", alpha=0.2, color="blue")
    plot!(obs_R, data[!,"tick"], data[!,"lower_est_R"], linewidth=1,linestyle =:dot, label=nothing, alpha=0.5, color="blue")
    plot!(obs_R, data[!,"tick"], data[!,"upper_est_R"], linewidth=1,linestyle =:dot, label=nothing, alpha=0.5, color="blue")
    hline!(obs_R, [1], linewidth=1, linestyle=:dash, linecolor = :red, label="R=1") # add criticality threshold (R=1)

    # add custom arguments that were passed
    plot!(obs_R; plotargs...)    

    return(obs_R)
end