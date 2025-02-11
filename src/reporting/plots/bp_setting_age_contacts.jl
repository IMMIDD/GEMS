export BatchSettingAgeContacts, settingtype, populationfile

###
### STRUCT
###

"""
    BatchSettingAgeContacts <: BatchPlot
    
A batch plot type for sampling contacts from the model and build an `age` x `age` matrix for a given Setting type and population file.

"""
@with_kw mutable struct BatchSettingAgeContacts <: BatchPlot

    title::String = "Contact Structure" # default title
    description::String = "" # default description empty
    filename::String = "contact_structure.png" # default filename
    
    # indicates to which package the result plot belongs
    # is used to parallelize report generation and prevents
    # concurrent generation of plots coming from the same package
    # if you don't know the origin package or if the function
    # returns different plot types depending on the input, 
    # just put ":other" which will trigger sequential generation
    package::Symbol = :Plots

    settingtype::DataType
    populationfile::String

    BatchSettingAgeContacts(settingtype::DataType, populationfile::String) = 
        new(
            "Realized Age Contact Structure for Setting *" * string(settingtype) * "* in $(basename(populationfile))",
            "",
            "realized_age_contact_structure_" * string(settingtype) * "_$(basename(populationfile)).png",
            :Plots,
            settingtype,
            populationfile
        )
    
end

"""
    settingtype(batchSettingAgeContacts)

Returns the setting type from an associated `BatchSettingAgeContacts` object.
"""
function settingtype(plt::BatchSettingAgeContacts)
    return(plt.settingtype)
end


"""
    populationfile(batchSettingAgeContacts)

Returns the populationfile from an associated `BatchSettingAgeContacts` object.
"""
function populationfile(plt::BatchSettingAgeContacts)
    return(plt.populationfile)
end

###
### PLOT GENERATION
###

"""
    generate(batchSettingAgeContacts, batchData)

Generates and returns an `age` x `age` matrix from sampled contacts for a given Setting type.
"""
function generate(plt::BatchSettingAgeContacts, bd::BatchData)

    st = settingtype(plt)
    pf = populationfile(plt)
    co_age = setting_age_contacts(bd, st)[pf]

    # return empty plot with message, if result data does not contain setting age data
    if co_age |> isempty
        empty_plot = plot(xlabel="", ylabel="", legend=false, 
        fontfamily="Times Roman",
        dpi = 300)
        plot!([], [], annotation=(0.5, 0.5, Plots.text("There's no setting-age-contact data available in the BatchData object", :center, 10, :black, "Times Roman")), 
        fontfamily="Times Roman",
        dpi = 300)
        return(empty_plot)
    end

    # add description
    # TODO this is now somewhat inconsistent as the generate function
    # would've also have to have a "!" it changes the input's descrption
    desc  = "For this analysis, one contact for every individual in any instance of "
    desc *= "a setting $st was drawn "
    desc *= "according to the provided contact sampling procedure. This totals a sample "
    desc *= "of $(format(sum(co_age), commas=true)) contacts[^cnt].\n\n"
   
    desc *= "[^cnt]: This number might be smaller than the overall number of assigned "
    desc *= "individuals to this setting type if there are instances with only one assigned "
    desc *= "individual (e.g. single-person-households)"
    
    description!(plt, desc)

    # crete plot object
    p = heatmap(co_age, color =:viridis, xlabel="Ego Age", ylabel="Contact Age", 
    fontfamily="Times Roman",
    dpi = 300, 
    colorbar_title = "Number of Contacts")

    return(p)
end