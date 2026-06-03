export plot_age_contact_distribution
export plot_all_age_contact_distributions
export plot_multiple_age_contact_distributions
export plot_ageGroup_contact_distribution
export plot_multiple_ageGroup_contact_distributions

"""
    plot_age_contact_distribution(age_contact_distribution::AgeContactDistribution; style::Symbol=:rel_histogram, titlefontsize::Union{Nothing, Int64}=nothing) 

Create a single plot of a "Age x Age Contact Distribution".
This function supports different styles to plot the contact distribution.

# Parameters

- `age_contact_distribution::AgeContactDistribution`: Age x Age Contact Distribution
- `style::Symbol`: different style options. Currently supported:
    - `:abs_histogram`: displays the contact distribution as a histogram with absolute frequencies.
    - `:rel_histogram`: displays the contact distribution as a histogram with relative frequencies.
- `titlefontsize::Union{Nothing, Int64}`: optional fontsize for all fonts used in the plot

"""
function plot_age_contact_distribution(age_contact_distribution::AgeContactDistribution; style::Symbol=:rel_histogram, titlefontsize::Union{Nothing, Int64}=nothing) 
    supported_styles = [:abs_histogram, :rel_histogram]

    if !(style in supported_styles)
        throw(ArgumentError("style: $style not supported. Please choose one of: $(supported_styles)."))
    end

    distribution_vector::Vector = age_contact_distribution.distribution_data
    ego_age::Int = age_contact_distribution.ego_age
    contact_age::Int = age_contact_distribution.contact_age

    if style == :abs_histogram
        println("Generating histogram!")
        # data to center each bar of the histogram
        xmin = floor(minimum(distribution_vector))
        xmax = ceil(maximum(distribution_vector))
        nbins = Int(xmax - xmin + 1)
        edges = range(xmin - 0.5, stop = xmax + 0.5, length = nbins + 1)
        

        if !isnothing(titlefontsize) 
            # plot with a given titlefontsize
            hist = histogram(distribution_vector, bins = edges, xticks=[x for x in 0:xmax], xlabel="number of contacts", ylabel="absolute frequency", title="$ego_age x $contact_age Contact Distribution", legend=false, titlefont=titlefontsize)
        else
            # plot with julia default titlefontsize
            hist = histogram(distribution_vector, bins = edges, xticks=[x for x in 0:xmax], xlabel="number of contacts", ylabel="absolute frequency", title="$ego_age x $contact_age Contact Distribution", legend=false)
        end

        
        # get highest frequency of the distribution_vector
        highest_frequency = maximum(values(StatsBase.countmap(distribution_vector)))

        # limit the y axis to the highest frequency measured in the distribution_vector
        ylims!(0, highest_frequency)
        return hist
    end

    # Plot histogram with relative values
    if style == :rel_histogram
        println("Generating histogram!")
        # data to center each bar of the histogram
        xmin = floor(minimum(distribution_vector))
        xmax = ceil(maximum(distribution_vector))
        nbins = Int(xmax - xmin + 1)
        edges = range(xmin - 0.5, stop = xmax + 0.5, length = nbins + 1)
        

        if !isnothing(titlefontsize) 
            # plot with a given titlefontsize
            hist = histogram(distribution_vector, bins = edges, xticks=[x for x in 0:xmax], xlabel="number of contacts", ylabel="relative frequency", title="$ego_age x $contact_age Contact Distribution", legend=false, titlefont=titlefontsize, normalize=:probability)
        else
            # plot with julia default titlefontsize
            hist = histogram(distribution_vector, bins = edges, xticks=[x for x in 0:xmax], xlabel="number of contacts", ylabel="relative frequency", title="$ego_age x $contact_age Contact Distribution", legend=false, normalize=:probability)
        end

        return hist
    end
end



"""
    plot_multiple_age_contact_distributions(age_contact_distributions::Vector{AgeContactDistribution}; style::Symbol=:rel_histogram)

Generate a subplot containing plots with the style `style` for every `AgeContactDistribution` defined in `age_contact_distributions`
This function supports different styles to plot the contact distribution.

# Parameters 

- `age_contact_distributions::Vector{AgeContactDistribution}`: Vector of `AgeContactDistribution`s that should be plotted.

- `style::Symbol`: different style options. Currently supported:
    - `:abs_histogram`: displays the contact distribution as a histogram with absolute frequencies.
    - `:rel_histogram`: displays the contact distribution as a histogram with relative frequencies.

"""
function plot_multiple_age_contact_distributions(age_contact_distributions::Vector{AgeContactDistribution}; style::Symbol=:rel_histogram)

    supported_styles = [:abs_histogram, :rel_histogram]

    if !(style in supported_styles)
        throw(ArgumentError("style: $style not supported. Please choose one of: $(supported_styles)."))
    end

    # count how many plots will be created
    number_of_plots = length(age_contact_distributions)

    plots = []

    # arbitrary number. Needs some testing for higher numbers of plots than 25 at the same time
    fontsize = 14 - floor(Int,number_of_plots/1.1)

    for distribution in age_contact_distributions
        plot = plot_age_contact_distribution(distribution, titlefontsize=fontsize, style=style)
        push!(plots, plot)
    end

    rows = ceil(Int, sqrt(number_of_plots))
    cols = ceil(Int, number_of_plots / rows)
    
    # create subplots for all histograms
    subplot = plot(plots..., layout=(rows,cols), legend=false)

    return subplot
end


"""
    plot_all_age_contact_distributions(age_contact_distribution_matrix::Matrix{AgeContactDistribution}; style::Symbol=:rel_histogram)

Generates a subplot containing plots with the style `style` for every entry of `distribution_matrix`.
This function supports different styles to plot the contact distribution.

# Parameters 

- `age_contact_distribution_matrix::Matrix{AgeContactDistribution}`: matrix containing a distribution of contacts in each cell.
- `style::Symbol`: different style options. Currently supported:
    - `:abs_histogram`: displays the contact distribution as a histogram with absolute frequencies.
    - `:rel_histogram`: displays the contact distribution as a histogram with relative frequencies.
"""
function plot_all_age_contact_distributions(age_contact_distribution_matrix::Matrix{AgeContactDistribution}; style::Symbol=:rel_histogram)

    supported_styles = [:abs_histogram, :rel_histogram]

    if !(style in supported_styles)
        throw(ArgumentError("style: $style not supported. Please choose one of: $(supported_styles)."))
    end

    plots = []

    # count how many plots will be created
    # Assumption: Every vector in the matrix will be plotted
    # empty vectors in the matrix should result in a plot with no data
    number_of_plots::Int = size(age_contact_distribution_matrix, 1) * size(age_contact_distribution_matrix, 2)

    # arbitrary number. Needs some testing for higher numbers of plots than 25 at the same time
    fontsize::Int = 14 - floor(Int,number_of_plots/1.1)

    for i in 1:size(age_contact_distribution_matrix,1)
        for j in 1:size(age_contact_distribution_matrix,2)
            try
                plot = plot_age_contact_distribution(age_contact_distribution_matrix[i, j], style=style, titlefontsize=fontsize)
                push!(plots, plot)
            catch error
                println("Error while trying to generate a plot for: '$i x $j Contact Distribution!'")
                println(error)
            end
        end
    end

    rows = ceil(Int, sqrt(number_of_plots))
    cols = ceil(Int, number_of_plots / rows)
    
    # create subplots for all histograms
    subplot = plot(plots..., layout=(rows,cols), legend=false)

    return subplot
end

"""
    plot_ageGroup_contact_distribution(ageGroup_contact_distribution::AgeGroupContactDistribution; style::Symbol=:histogram, titlefontsize::Union{Nothing, Int64}=nothing)

Create a single plot of a "AgeGroup x AgeGroup Contact Distribution". 
This function supports different styles to plot the contact distribution.

# Parameters

- `ageGroup_contact_distribution::AgeGroupContactDistribution`: AgeGroup x AgeGroup Contact Distribution
- `style::Symbol`: different style options. Currently supported:
    - `:abs_histogram`: displays the contact distribution as a histogram with absolute frequencies.
    - `:rel_histogram`: displays the contact distribution as a histogram with relative frequencies.
- `titlefontsize::Union{Nothing, Int64}`: optional fontsize for all fonts used in the plot

"""
function plot_ageGroup_contact_distribution(ageGroup_contact_distribution::AgeGroupContactDistribution; style::Symbol=:rel_histogram, titlefontsize::Union{Nothing, Int64}=nothing)

    supported_styles = [:abs_histogram, :rel_histogram]

    if !(style in supported_styles)
        throw(ArgumentError("style: $style not supported. Please choose one of: $(supported_styles)."))
    end

    age_group_distribution_vector::Vector = ageGroup_contact_distribution.distribution_data
    ego_age_group::Tuple{Int, Int} = ageGroup_contact_distribution.ego_age_group
    contact_age_group::Tuple{Int, Int} = ageGroup_contact_distribution.contact_age_group

    ego_low = ego_age_group[1]
    ego_up = ego_age_group[2]

    contact_low = contact_age_group[1]
    contact_up = contact_age_group[2]

    # Plot histogram with absolute values
    if style == :abs_histogram
        println("Generating histogram!")
        # data to center each bar of the histogram
        xmin = floor(minimum(age_group_distribution_vector))
        xmax = ceil(maximum(age_group_distribution_vector))
        nbins = Int(xmax - xmin + 1)
        edges = range(xmin - 0.5, stop = xmax + 0.5, length = nbins + 1)
        

        if !isnothing(titlefontsize) 
            # plot with a given titlefontsize
            hist = histogram(age_group_distribution_vector, bins = edges, xticks=[x for x in 0:xmax], xlabel="number of contacts", ylabel="frequency", title="[$ego_low,$ego_up)  x [$contact_low,$contact_up) Contact Distribution", legend=false, titlefont=titlefontsize)
        else
            # plot with julia default titlefontsize
            hist = histogram(age_group_distribution_vector, bins = edges, xticks=[x for x in 0:xmax], xlabel="number of contacts", ylabel="frequency", title="[$ego_low,$ego_up) x [$contact_low,$contact_up) Contact Distribution", legend=false)
        end
        
        # get highest frequency of the distribution_vector
        highest_frequency = maximum(values(StatsBase.countmap(age_group_distribution_vector)))

        # limit the y axis to the highest frequency measured in the distribution_vector
        ylims!(0, highest_frequency)
        
        return hist
    end

    # Plot histogram with relative values
    if style == :rel_histogram
        println("Generating histogram!")
        # data to center each bar of the histogram
        xmin = floor(minimum(age_group_distribution_vector))
        xmax = ceil(maximum(age_group_distribution_vector))
        nbins = Int(xmax - xmin + 1)
        edges = range(xmin - 0.5, stop = xmax + 0.5, length = nbins + 1)

        if !isnothing(titlefontsize) 
            # plot with a given titlefontsize
            hist = histogram(age_group_distribution_vector, bins = edges, xticks=[x for x in 0:xmax], xlabel="number of contacts", ylabel="relative frequency", title="[$ego_low,$ego_up)  x [$contact_low,$contact_up) Contact Distribution", legend=false, titlefont=titlefontsize, normalize=:probability)
        else
            # plot with julia default titlefontsize
            hist = histogram(age_group_distribution_vector, bins = edges, xticks=[x for x in 0:xmax], xlabel="number of contacts", ylabel="relative frequency", title="[$ego_low,$ego_up) x [$contact_low,$contact_up) Contact Distribution", legend=false, normalize=:probability)
        end

        return hist
    end
end




"""
    plot_multiple_ageGroup_contact_distributions(age_group_contact_distributions::Vector{AgeGroupContactDistribution}; style=:rel_histogram)

Generates a subplot containing plots with the style `style` for every entry of `age_group_contact_distributions`. For each entry, a plot of the 'AgeGroup x AgeGroup Contact Distribution' will be created.
This function supports different styles to plot the contact distribution.

# Parameters 

- `age_group_contact_distributions::Vector{AgeGroupContactDistribution}`: 'AgeGroup x AgeGroup Contact Distribution's that should be plotted.
- `style::Symbol`: different style options. Currently supported:
    - `:abs_histogram`: displays the contact distribution as a histogram with absolute frequencies.
    - `:rel_histogram`: displays the contact distribution as a histogram with relative frequencies.
"""
function plot_multiple_ageGroup_contact_distributions(age_group_contact_distributions::Vector{AgeGroupContactDistribution}; style::Symbol=:rel_histogram)

    supported_styles = [:abs_histogram, :rel_histogram]

    if !(style in supported_styles)
        throw(ArgumentError("style: $style not supported. Please choose one of: $(supported_styles)."))
    end

    # count how many plots will be created
    number_of_plots = length(age_group_contact_distributions)

    plots = []

    # arbitrary number. Needs some testing for higher numbers of plots than 25 at the same time
    fontsize = 14 - floor(Int,number_of_plots/1.1)

    for distribution in age_group_contact_distributions
        plot = plot_ageGroup_contact_distribution(distribution, titlefontsize=fontsize, style=style)
        push!(plots, plot)
    end

    rows = ceil(Int, sqrt(number_of_plots))
    cols = ceil(Int, number_of_plots / rows)
    
    # create subplots for all histograms
    subplot = plot(plots..., layout=(rows,cols), legend=false)

    return subplot
end