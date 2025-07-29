export HouseholdAttackRate

###
### STRUCT
###

"""
    HouseholdAttackRate <: SimulationPlot

A simulation plot type for generating a household-attack-rate plot.
"""
@with_kw mutable struct HouseholdAttackRate <: SimulationPlot

    title::String = "In-Household Attack Rate" # default title
    description::String = "" # default description empty
    filename::String = "household_attack_rate.png" # default filename

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
    generate(plt::HouseholdAttackRate, rd::ResultData; plotargs...)

Generates and returns a household-attack-rate plot for a provided simulation object.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.
However, be aware that the keyword arguments might be applied to each of the
subplots individually.

# Parameters

- `plt::HouseholdAttackRate`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `ar_only::Bool = false` *(optional)*: If `true`, only the attack rate plot will be returned, otherwise a multi-plot with attack rate and household size over time.
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Household Attack Rate plot
"""
function generate(plt::HouseholdAttackRate, rd::ResultData; ar_only::Bool = false,
    markersize = 5, plotargs...)

    # group attack rate data by household size, time of first introduction,
    # and look at change in attack rates and change in mean houeshold sizes
    mean_hh_AR = rd |> household_attack_rates |>
        x -> groupby(x, :hh_size) |>
        x -> combine(x, :hh_attack_rate => mean => :mean_hh_attack_rate)

    mean_hh_AR_over_time = rd |> household_attack_rates |>
        x -> groupby(x, :first_introduction) |>
        x -> combine(x, :hh_attack_rate => mean => :mean_hh_attack_rate)

    mean_hh_size_over_time = rd |> household_attack_rates |>
        x -> groupby(x, :first_introduction) |>
        x -> combine(x, :hh_size => mean => :mean_hh_size)
    
    uticks = rd |> tick_unit
    upper_ticks = uticks |> uppercasefirst
    ft = rd |> final_tick

    # add description
    desc = "This graph shows the in-household attack rates stratified by household size and over time. "
    desc *= "The in-household attack rate is defined as the fraction of individuals in a given household "
    desc *= "that got infected within the household (in-household infection chain) caused by the *first* "
    desc *= "introduction of the pathogen in this household. It does *not* reflect *overall* fraction of "
    desc *= "individuals that were infected in this household throughout the course of the simuation."
    description!(plt, desc) 

    hhs_ar = scatter(
        mean_hh_AR.hh_size,
        mean_hh_AR.mean_hh_attack_rate,
        xlims = (0, 15),
        ylims = (0, 1),
        xticks = (1:1:15),
        markersize = markersize,
        markerstrokewidth=0,
        label = "Attack rate and household sizes",
        xlabel = "Household Size",
        ylabel = "Mean Attack Rate",
        fontfamily = "Times Roman")

    time_ar = plot(
        mean_hh_AR_over_time.first_introduction,
        mean_hh_AR_over_time.mean_hh_attack_rate,
        xlims = (0, ft),
        ylims = (0, 1),
        label = "Avg. attack rate \n at first infection",
        xlabel = upper_ticks * "s",
        ylabel = "Mean Attack Rate")

    timem_hhs = plot(
        mean_hh_size_over_time.first_introduction,
        mean_hh_size_over_time.mean_hh_size,
        xlims = (0, ft),
        label = "Avg. size of households \n at first infection",
        xlabel = upper_ticks * "s",
        ylabel = "Mean Household Size")

    # if attack-rate only flag is set, return only the attack rate plot
    if ar_only
        return plot!(hhs_ar; plotargs...)
    end

    # return the multi-plot with the attack rate and household size over time
    l = @layout [a ; b c]
    ar_plot = plot(hhs_ar, time_ar, timem_hhs,
        layout = l,
        ylabelfontsize = 10,
        xlabelfontsize = 10)

    # add custom arguments that were passed
    plot!(ar_plot; plotargs...)

    return ar_plot    
end




"""
    generate(plt::HouseholdAttackRate, rds::Vector{ResultData}; plotargs...)

Generates and returns a household-attack-rate plot for a vector of provided `ResultData` objects.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.
However, be aware that the keyword arguments might be applied to each of the
subplots individually.

# Parameters

- `plt::HouseholdAttackRate`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rds::Vector{ResultData}`: Vector of input data objects used to generate plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Household Attack Rate multi plot
"""
function generate(plt::HouseholdAttackRate, rds::Vector{ResultData}; plotargs...)


    # prepare colors & data per label
    # read labels from result data vector
    labels = map(label, rds) |> unique
    colors = Dict(zip(labels, palette(:auto, length(labels))))
    data = []

    # process data and sort by label
    for rd in rds
        push!(data, 
            rd |> household_attack_rates |>
                x -> groupby(x, :hh_size) |>
                x -> combine(x, :hh_attack_rate => mean => :mean_hh_attack_rate) |>
                x -> transform(x, :hh_size => ByRow(h -> label(rd)) => :label) |>
                # add color. Take from plotargs if given, otherwise take from color dict
                x -> transform(x, :label => ByRow(l -> (haskey(plotargs, :color) ? plotargs[:color] : colors[l])) => :color)
        )
    end

    # put all result datas in one dataframe
    data = vcat(data...)

    # calculate mean values per batch grouped by label
    means = data |>
        x -> groupby(x, [:hh_size, :label]) |>
        x -> combine(x, :mean_hh_attack_rate => mean => :total_mean)

    # print scatter plot
    p = scatter(
        data.hh_size,
        data.mean_hh_attack_rate,
        group = data.label,
        color = data.color,
        markerstrokecolor = data.color,
        alpha = 0.7,
        xlims = (0, 15),
        ylims = (0, 1),
        xticks = (1:1:15),
        xlabel = "Household Size",
        ylabel = "Mean Attack Rate")

    # add mean-line per label
    for lab in labels
        plot!(p,
            means.hh_size[means.label .== lab],
            means.total_mean[means.label .== lab],
            color = haskey(plotargs, :color) ? plotargs[:color] : colors[lab],
            linewidth = 1.5,
            alpha = .5,
            label = "Mean of $lab")
    end

    plot!(p; plotargs...)

    return p
end