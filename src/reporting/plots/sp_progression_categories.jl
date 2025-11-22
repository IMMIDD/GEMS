export ProgressionCategories

###
### STRUCT
###

"""
    ProgressionCategories <: SimulationPlot

A simulation plot type for visualizing the progression categories of infections by age.
"""
@with_kw mutable struct ProgressionCategories <: SimulationPlot

    title::String = "Progression Categories" # default title
    description::String = "" # default description empty
    filename::String = "progression_categories.png" # default filename

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
    generate(plt::ProgressionCategories, rd::ResultData; plotargs...)

Generates and returns a `progression_category` x `age` matrix as heatmap.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::ProgressionCategories`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Progression Categories plot
"""
function generate(plt::ProgressionCategories, rd::ResultData; plotargs...)

    # add description
    desc = "This graph shows the disease progression in terms of severity "
    desc *= "(_asymptomatic, mild, severe, critical_) per age group. The "
    desc *= "color-coding tells for which percentage of infected individuals of a certain age (x-axis) "
    desc *= "the disease progressed to a certain final state (y-axis). "
    desc *= "Look up the glossary for more detailed explanations on the particular progression categories."
    
    description!(plt, desc)

    # crete plot object
    bin_age(vec) = (vec .÷ 5) .* 5

    p = rd |> infections |>
        df -> select(df, [:age_b, :progression_category]) |>
        df -> transform(df, :age_b => bin_age => :bin) |>
        df -> groupby(df, [:progression_category, :bin]) |>
        df -> combine(df, nrow => :count) |>
        # ensure that every combination is considered
        # this will also sort the dataframe by progression_category and bin
        df -> rightjoin(df,
            DataFrame(
                progression_category = repeat(unique(df.progression_category), inner = maximum(df.bin) ÷ 5 + 1),
                bin = repeat(0:5:maximum(df.bin), outer = length(unique(df.progression_category)))
            ), on = [:progression_category, :bin]) |>
        # add missing values as 0 counts
        df -> transform(df, :count => (c -> coalesce.(c, 0)) => :count) |>
        df -> unstack(df, :progression_category, :bin, :count, fill=0.0) |>
        df -> Matrix(df[:, Not(:progression_category)]) |>
        mat -> heatmap(
            reverse(mat, dims = 2);
            color = :viridis,
            xlabel = "Age Group",
            xticks = 1:(length(names(df))-1),
            xformatter = x -> "$(Int(5(x-1))) - $(Int(5x -1))",
            xrotation = 45,
            yticks = (1:nrow(df), df.progression_category),
            ylabel = "Progression Category",
            colorbar_title = "Count",
            fontfamily="Times Roman",
            dpi = 300
        )

    # add custom arguments that were passed
    plot!(p; plotargs...)

    return(p)
end