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

function _progression_categories_subplot(infs_sub; plotargs...)
    target_order = ["Asymptomatic", "Symptomatic", "Severe", "Hospitalized", "Critical"]
    order_dict = Dict(val => i for (i, val) in enumerate(target_order))
    sort_cats(cats) = sort(cats, by = x -> (get(order_dict, string(x), typemax(Int)), string(x)))
    bin_age(vec) = (vec .÷ 5) .* 5

    p = infs_sub |>
        df -> select(df, [:age_b, :progression_category]) |>
        df -> transform(df, :age_b => bin_age => :bin) |>
        df -> groupby(df, [:progression_category, :bin]) |>
        df -> combine(df, nrow => :count) |>
        df -> rightjoin(df,
            DataFrame(
                progression_category = repeat(sort_cats(unique(df.progression_category)), inner = maximum(df.bin) ÷ 5 + 1),
                bin = repeat(0:5:maximum(df.bin), outer = length(unique(df.progression_category)))
            ), on = [:progression_category, :bin]) |>
        df -> transform(df, :count => (c -> coalesce.(c, 0)) => :count) |>
        df -> transform(df, :bin => (b -> parse.(Int, string.(b))) => :bin) |>
        df -> sort(df, :bin) |>
        df -> unstack(df, :progression_category, :bin, :count, fill=0.0) |>
        df -> sort(df, :progression_category, by = x -> get(order_dict, string(x), typemax(Int))) |>
        df -> heatmap(
            Matrix(df[:, Not(:progression_category)]);
            color = :viridis,
            xlabel = "Age Group",
            xticks = 1:(length(names(df))-1),
            xformatter = x -> "$(Int(5(x-1)))-$(Int(5x -1))",
            xrotation = 45,
            yticks = (1:nrow(df), df.progression_category),
            ylabel = "Progression Category",
            colorbar_title = "Count",
            fontfamily="Times Roman",
            dpi = 300,
            bottom_margin = 5Plots.mm,
            plotargs...
        )
    return p
end

"""
    generate(plt::ProgressionCategories, rd::ResultData; plotargs...)

Generates and returns a `progression_category` x `age` matrix as heatmap.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::ProgressionCategories`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `pathogen::Union{Nothing, Int8, Integer, AbstractString} = nothing` *(optional)*: Filter to a single pathogen by id or name. Default shows all pathogens as subplots.
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Progression Categories plot
"""
function generate(plt::ProgressionCategories, rd::ResultData; pathogen = nothing, plotargs...)

    desc = "This graph shows the disease progression in terms of severity "
    desc *= "(_asymptomatic, mild, severe, critical_) per age group. The "
    desc *= "color-coding tells for which percentage of infected individuals of a certain age (x-axis) "
    desc *= "the disease progressed to a certain final state (y-axis). "
    desc *= "Look up the glossary for more detailed explanations on the particular progression categories."
    description!(plt, desc)

    infs_raw = infections(rd)
    if !isa(infs_raw, DataFrame) || isempty(infs_raw)
        ep = emptyplot("Infections data not available in this ResultData object.")
        plot!(ep; plotargs...)
        return ep
    end
    infs, pids, pnames, _ = _pathogen_setup(infs_raw, rd, pathogen)

    subplots = [_progression_categories_subplot(
        filter(row -> row.pathogen_id == pid, infs);
        (length(pids) > 1 ? _pathogen_subargs(pid, pnames, plotargs) : NamedTuple(plotargs))...)
        for pid in pids]
    return _multi_pathogen_plot(subplots, plotargs)
end
