export AggregatedSettingAgeContacts, settingtype

###
### STRUCT
###

"""
    AggregatedSettingAgeContacts <: SimulationPlot    

A simulation plot type for sampling contacts from the model and build an `age group` x `age group` matrix for a given Setting type. The plot 
displays aggregated age groups and their mean number of contacts.
"""
@with_kw mutable struct AggregatedSettingAgeContacts <: SimulationPlot

    title::String = "Contact Structure" # default title
    description::String = "" # default description empty
    filename::String = "contact_structures.png" # default filename
    
    # indicates to which package the result plot belongs
    # is used to parallelize report generation and prevents
    # concurrent generation of plots coming from the same package
    # if you don't know the origin package or if the function
    # returns different plot types depending on the input, 
    # just put ":other" which will trigger sequential generation
    package::Symbol = :Plots

    settingtype::Union{DataType, Nothing} = nothing
end

AggregatedSettingAgeContacts(settingtype::DataType) = AggregatedSettingAgeContacts(settingtype = settingtype)

"""
    settingtype(plt::AggregatedSettingAgeContacts)

Returns the setting type from an associated `AggregatedSettingAgeContacts` object.
"""
function settingtype(plt::AggregatedSettingAgeContacts)
    return(plt.settingtype)
end

###
### PLOT GENERATION
###

"""
    generate(plt::AggregatedSettingAgeContacts, rd::ResultData;
        settingtype::Union{DataType, Nothing} = nothing, plotargs...)

Generates and returns an `age group` x `age group` matrix from sampled contacts for a given Setting type.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::AggregatedSettingAgeContacts`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `settingtype::Union{DataType, Nothing} = nothing` *(optional)*: Setting type (e.g. "Household"). If nothing is passed, all
    setting types in the `ResultData` object are being ploted.
- `show_values = true` *(optional)*: If true, values will be printed in the contact matrix
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Aggregated Setting Age Contacts plot

"""
function generate(plt::AggregatedSettingAgeContacts, rd::ResultData;
    settingtype::Union{DataType, Nothing} = nothing, show_values = true, plotargs...)

    # check if a particular setting type was passed
    st = isnothing(settingtype) ? plt.settingtype : settingtype

    # load setting data from RD object to veryfiy that there
    # are settings of the specified type
    if !isnothing(st)
        sdata = rd |> setting_data
        if isempty(sdata) ||
            sdata[sdata.setting_type .== string(st), :].number_of_settings |> sum <= 0
            ep = emptyplot("There's no $(string(st)) contact data available in this ResultData object.")
            plot!(ep; plotargs...)
            return ep
        end

        # if a particular setting type was passed, adapt meta data
        stypes = [string(st)]
        title!(plt, "Realized Age Group Contact Structure for Setting *" * string(st) * "*")
        filename!(plt, "realized_age_group_contact_structure_" * string(st) * ".png")
    else
        stypes = (rd |> setting_data).setting_type
    end


    contact_sampling_method = ""

    try
        contact_sampling_method = meta_data(rd)["config_file_val"]["Settings"]["$st"]["contact_sampling_method"]["type"] 
    catch e
        # if no "ContactSamplingMethod" is defined in the config file
        contact_sampling_method = "RandomSampling"
    end
    

    # add description
    desc  = "The contacts where drawn based on the Contact Sampling Method '$contact_sampling_method' for"
    desc *= " the setting $st at tick $(format(rd |> final_tick, commas=true)). "
    desc *= "Each cell represents the mean number of contacts between individuals of the two age groups, "
    desc *= "relative to the total number of members in this age group. "
    
    description!(plt, desc)


    plts = []
    for st in stypes

        contact_matrix_data = aggregated_setting_age_contacts(rd, eval(Symbol(st))).data
        interval_steps = aggregated_setting_age_contacts(rd, eval(Symbol(st))).interval_steps
    
        # create axis tick labels based on given age groups
        age_group_labels = ["[$(i * interval_steps):$((i + 1) * interval_steps))" for i in 0:length(contact_matrix_data[:,1]) - 2]
        last_age_group = "$((length(contact_matrix_data[:,1]) - 1)  * interval_steps)+"
        push!(age_group_labels, last_age_group)

        # create plot object
        p = heatmap(
            xticks=(1:length(age_group_labels), age_group_labels), 
            yticks=(1:length(age_group_labels), age_group_labels), 
            #age_group_labels, 
            #age_group_labels, 
            contact_matrix_data, 
            color =:viridis, 
            xlabel = length(stypes) == 1 ? "Ego Age Group\n$st" : "", 
            ylabel = length(stypes) == 1 ? "Contact Age Group" : "", 
            showaxis = length(stypes) == 1 ? true : false,
            margin = length(stypes) == 1 ? 0Plots.mm : -5Plots.mm,
            left_margin = st == first(stypes) ? 0Plots.mm : -10Plots.mm,
            colorbar_title = " \nRelative Frequency",
            dpi = 300,
            fontfamily = "Times Roman",
            aspect_ratio = :equal,
            xlims = (1, length(age_group_labels)),
            ylims = (1, length(age_group_labels)),
            legend = length(stypes) > 1 ? false : true
        )

       
        # only add in-cell annotations for single-plots
        if length(stypes) == 1

            # x and y coordinates, to find the center of each cell in the plot axis
            x_coords = range(0.5, stop=size(contact_matrix_data, 1) + 0.5)
            y_coords = range(0.5, stop=size(contact_matrix_data, 2) + 0.5)

            # from randomly trying, this fits best (80% of the interval steps)
            pointsize = Int(ceil(interval_steps * 0.8))

            # add values to heatmap, if wanted
            if show_values
                for i in 1:size(contact_matrix_data, 1)
                    for j in 1:size(contact_matrix_data, 2)
                        # display each cell value rounded to 2 decimals in the center of each plot cell
                        annotate!(y_coords[j], x_coords[i], Plots.text(string(round(contact_matrix_data[i, j]; digits = 2)), pointsize = pointsize, :white,  "Times Roman"))
                    end
                end
            end
        else 
            plot!(p, annotation=(length(age_group_labels) / 2, -length(age_group_labels) / 15, Plots.text(st, :center, 8, :black, "Times Roman")))
        end

        push!(plts, p)
    end

    # if only one plot was created, return that one
    if length(plts) == 1
        return plot!(plts[1]; plotargs...)
    end

    # return multiplots
    
    # calcuate plot layout
    num_columns = min(4, length(stypes)) 
    num_rows = ceil(Int, length(stypes) / num_columns) 

    data_plot = plot(plts..., layout=(num_rows, num_columns), size=(200 * num_columns, 250 * num_rows))

    if haskey(plotargs, :title)
        t_plot = plot(
            title = "\n$(plotargs[:title])",
            legend=false,
            grid=false,
            showaxis=false,
            size = (200, 30))
        p = plot(t_plot, data_plot, layout = grid(2, 1, heights=[0.1 ,0.9]))
    else
        p = data_plot
    end

    # add custom arguments that were passed
    plot!(p; remove_kw(:title, plotargs)...)

    return(p)
end
