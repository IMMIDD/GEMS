export PopulationPyramid

###
### STRUCT
###

"""
    PopulationPyramid <: SimulationPlot

A simulation plot type for generating a population pyramid for the associated population model.
"""
@with_kw mutable struct PopulationPyramid <: SimulationPlot

    title::String = "Population Pyramid" # default title
    description::String = "" # default description empty
    filename::String = "population_pyramid.png" # default filename

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
    generate(plt::PopulationPyramid, rd::ResultData; plotargs...)

Generates population pyramid for a the associated population model.

The current implementation does not offer the option for additional keyworded arguments.
The `plotargs...` argument is just a placeholder.

# Parameters

- `plt::PopulationPyramid`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `plotargs...` *(optional)*: PLACEHOLDER. Currently not implemented.

# Returns

- `Plots.Plot`: Population Pyramid plot
"""
function generate(plt::PopulationPyramid, rd::ResultData; plotargs...)

    # add description
    desc = "This graph shows the number of female and male individuals per age."
    description!(plt, desc)

    df = rd.data["dataframes"]["population_pyramid"]
    # Filter by gender
    male_data = filter(row -> row.gender == "Male", df)
    female_data = filter(row -> row.gender == "Female", df)

    # Setting up the plot
    p = plot(legend=:topright,
        ylims=(0, 105),
        xlabel="Number of Individuals in Age Group",
        ylabel="Age",
        yticks=0:5:100,
        dpi=300,
        fontfamily="Times Roman")

    # Plot male and female data
    bar!(male_data[!, :age], male_data[!, :sum], label="Male", orientation=:h, color=palette(:auto,2)[1], linecolor = :match, bar_width=0.5)
    bar!(female_data[!, :age], female_data[!, :sum], label="Female", orientation=:h, color=palette(:auto,2)[2], linecolor = :match, bar_width=0.5)

    # Get the automatic tick positions
    x_ticks, _ = xticks(p)[1]

    # Create custom labels by removing the minus sign
    x_labels = []
    for tick in x_ticks
        if abs(tick) < 1000
            push!(x_labels, "$(abs(tick))")  # Use regular number
        else
            # for scientific notation
            exponent = floor(Int, log10(abs(tick)))
            mantissa = abs(tick) / (10^exponent)
            push!(x_labels, "$(mantissa)*10^{$(exponent)}")
        end
    end

    # Apply both tick positions and labels
    plot!(p, xticks=(x_ticks, x_labels))
    plot!(p; plotargs...)

    return p

end