export InfectionDuration

###
### STRUCT
###

"""
    InfectionDuration <: SimulationPlot

A simulation plot type for visualizing the distribution of infection durations as a histogram.
"""
@with_kw mutable struct InfectionDuration <: SimulationPlot
    title::String = "Infection Duration"
    description::String = "" 
    filename::String = "infection_duration.png" 

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
    generate(plt::InfectionDuration, rd::ResultData; plotargs...)

Generates and returns a histogram of the total infection durations in ticks.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::InfectionDuration`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Infection Duration plot
"""
function generate(plt::InfectionDuration, rd::ResultData; plotargs...)

    data = rd |> aggregated_compartment_periods

    if data |> isempty
        @warn "Infection duration data not available in RD-object. Consider adding the 'aggregated_compartment_periods' field to your RD-Style."
        return emptyplot("Infection duration data not available in RD-object.")
    end
    
    uticks = rd |> tick_unit

    # mean duration
    mean_dur = data.duration .* data.total

    # add description
    desc  = "The duration is the time between exposure to the pathogen until and recovery. "
    desc *= "The mean duration was $(mean_dur), digits = 3)) $(uticks)s."

    description!(plt, desc)

    # formatting y-axis to show percentages
    formatter = x -> string(round(x * 100; digits=1), "%")

    id_plot = bar(data.duration, data.total,
        bar_width=0.8,
        label="Disease Duration",
        xlabel=uppercasefirst(uticks) * "s",
        ylabel="Fraction of Infections", 
        yformatter=formatter,
        fontfamily="Times Roman",
        dpi = 300)
   
    # add custom arguments that were passed
    plot!(id_plot; plotargs...)

    return id_plot
end


"""
    generate(plt::InfectionDuration, rds::Vector{ResultData}; plotargs...)

Generates and returns a histogram of the total infection durations in ticks for a provided vector of `ResultData` objects.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::InfectionDuration`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Infection Duration plot
"""
function generate(plt::InfectionDuration, rds::Vector{ResultData}; plotargs...)

    if someempty(aggregated_compartment_periods, rds)
        @warn "Infection duration data not available in all RD-objects. Consider adding the 'aggregated_compartment_periods' field to your RD-Style or use a style that already contains the required data (e.g., the DefaultResultData style)"
        return emptyplot("Infection duration data not available in all RD-object.")
    end

    uticks = rds[1] |> tick_unit
    
    # get all compartment durations and append the dataframes
    data = vcat(map(aggregated_compartment_periods, rds)...)

    sort!(data, :duration)
    max_len = rds|> length
    ids = unique(data.duration)

    result_matrix = zeros(max_len, length(ids))
    for (idx, id) in enumerate(ids)
        col_values = data.total[data.duration .== id]
        result_matrix[1:length(col_values), idx] .= col_values
    end


    formatter = x -> string(round(x * 100; digits=1), "%")
    p = boxplot(transpose(ids), result_matrix, 
        legend = false,
        xlabel=uppercasefirst(uticks) * "s",
        color = haskey(plotargs, :color) ? plotargs[:color] : palette(:auto, 1)[1],
        ylabel="Fraction of Infections", 
        yformatter=formatter,
        fontfamily="Times Roman",
        dpi = 300)

    plot!(p; plotargs...)

    return p
end