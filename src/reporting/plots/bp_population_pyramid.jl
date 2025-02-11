export BatchPopulationPyramid, populationfile

###
### STRUCT
###

""" 
    BatchPopulationPyramid <: BatchPlot

A batch plot type for generating a population pyramid for a specified population file.
It has to be passed to the constructor via a string identifier.
"""
@with_kw mutable struct BatchPopulationPyramid <: BatchPlot

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

    populationfile::String

    BatchPopulationPyramid(populationfile::String) = 
        new(
            "Population Pyramid for $(basename(populationfile))",
            "",
            "population_pyramid_$(basename(populationfile)).png",
            :Plots,
            populationfile
        )
    
end

"""
    populationfile(batchPopulationPyramid)

Returns the populationfile from an associated `BatchPopulationPyramid` object.
"""
function populationfile(plt::BatchPopulationPyramid)
    return(plt.populationfile)
end

###
### PLOT GENERATION
###

"""
    generate(batchPopulationPyramid, batchData)

Generates population pyramid for a specified population file within a batch.
"""
function generate(plt::BatchPopulationPyramid, bd::BatchData)

    pf = populationfile(plt)

    # Extract and process the data from the population file
    processed_data = (bd |> population_pyramid)[pf]
    
    # Filter by gender
    male_data = filter(row -> row.gender == "Male", processed_data)
    female_data = filter(row -> row.gender == "Female", processed_data)
    println(basename(pf))

    # Setting up the plot
    p = plot(legend=:topright,
             ylims=(0,105),
             xlabel = "Number of Individuals in Age Group in $(basename(pf))",
             ylabel = "Age",
             yticks=0:5:100,
             dpi=300, 
             fontfamily = "Times Roman")
    
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
                
    return p
    
end