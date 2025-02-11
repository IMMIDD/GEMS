export SettingAgeContacts, settingtype

###
### STRUCT
###

"""
    SettingAgeContacts <: SimulationPlot

A simulation plot type for sampling contacts from the model and build an `age` x `age` matrix for a given Setting type.
"""
@with_kw mutable struct SettingAgeContacts <: SimulationPlot

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

    SettingAgeContacts(settingtype::DataType) = 
        new(
            "Realized Age Contact Structure for Setting *" * string(settingtype) * "*",
            "",
            "realized_age_contact_structure_" * string(settingtype) * ".png",
            :Plots,
            settingtype
        )
    
end

"""
    settingtype(plt::SettingAgeContacts)

Returns the setting type from an associated `SettingAgeContacts` object.
"""
function settingtype(plt::SettingAgeContacts)
    return(plt.settingtype)
end

###
### PLOT GENERATION
###

"""
    generate(plt::SettingAgeContacts, rd::ResultData; plotargs...)

Generates and returns an `age` x `age` matrix from sampled contacts for a given Setting type.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::SettingAgeContacts`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Setting Age Contacts plot
"""
function generate(plt::SettingAgeContacts, rd::ResultData; plotargs...)

    st = settingtype(plt)
    co_age = setting_age_contacts(rd, st)

    contact_sampling_method = meta_data(rd)["config_file_val"]["Settings"]["$st"]["contact_sampling_method"]["type"]

    # add description
    # TODO this is now somewhat inconsistent as the generate function
    # would've also have to have a "!" it changes the input's descrption
    desc  = "The contacts where drawn based on the Contact Sampling Method '$contact_sampling_method' for "
    desc *= "the setting '$st' at tick $(format(rd |> final_tick, commas=true)). "
    desc *= "This totals a sample "
    desc *= "of $(format(sum(co_age), commas=true)) contacts[^cnt_$st].\n\n"
   
    desc *= "[^cnt_$st]: This number might be smaller than the overall number of assigned "
    desc *= "individuals to this setting type if there are instances with only one assigned "
    desc *= "individual (e.g. single-person-households)"
    
    description!(plt, desc)

    # crete plot object
    p = heatmap(
        co_age, 
        color =:viridis, 
        xlabel="Ego Age", 
        ylabel="Contact Age", 
        colorbar_title = "Number of Contacts",
        dpi = 300,
        fontfamily = "Times Roman"
    )

    # add custom arguments that were passed
    plot!(p; plotargs...)    

    return(p)
end