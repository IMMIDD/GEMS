###
### CONTAINER TYPE FOR ALL SETTINGS (TYPE DEFINITION & BASIC FUNCTIONALITY)
###
export SettingsContainer
export add!, get, setting, settings, settingtypes, settings_from_jld2!, delete_dangling_ids!, new_setting_ids!, add_type!, add_types!
export municipalities, households, schoolclasses, schoolyears, schools, schoolcomplexes, offices, departments, workplaces, workplacesites 

"""
    SettingsContainer

A container structure for all settings.

# Fields
- `settings::Dict{DataType, Vector{Setting}}`: A dictionary holding all known settings
    structured by type
"""
mutable struct SettingsContainer
    settings::Dict{DataType, Vector{Setting}}
end


###
### SettingsContainer
###

"""
    SettingsContainer()

Return a empty container object.
"""
function SettingsContainer()
    return SettingsContainer(Dict{DataType, Vector{Setting}}())
end

"""
    add_type!(container::SettingsContainer, settingtype::Type)

Add a settingtype to the container if it is not yet included. 
Creates a new vector for the provided type in the settings dictionary.
"""
function add_type!(container::SettingsContainer, settingtype::Type)
    if !haskey(container.settings, settingtype)
        container.settings[settingtype] = Vector{Setting}()
    end
end

"""
    add_type!(container::SettingsContainer, settingtype::DataType)

Add a settingtype to the container if it is not yet included. 
Creates a new vector for the provided type in the settings dictionary.
"""
function add_type!(container::SettingsContainer, settingtype::DataType)
    if !haskey(container.settings, settingtype)
        container.settings[settingtype] = Vector{Setting}()
    end
end

"""
    add_types!(container::SettingsContainer, settingtypes::Vector{Type})

Adds settingtypes to the container if they are not yet included. 
Calls the `add_type!` function for each settingtype in the vector.
"""
function add_types!(container::SettingsContainer, settingtype::Vector{Type})
    for st in settingtype
        add_type!(container, st)
    end
end

"""
    add_types!(container::SettingsContainer, settingtypes::Vector{DataType})

Adds settingtypes to the container if they are not yet included. 
Calls the `add_type!` function for each settingtype in the vector.
"""
function add_types!(container::SettingsContainer, settingtype::Vector{DataType})
    for st in settingtype
        add_type!(container, st)
    end
end
"""
    add!(container::SettingsContainer, setting::Setting)

Add a setting to the container.
"""
function add!(container::SettingsContainer, setting::Setting)
    push!(container.settings[typeof(setting)], setting)
end

"""
    get(container::SettingsContainer, type::DataType)

Returns all settings of the specified type and `nothing` if The
setting container does not contain the type. Extends `Base.get`.
"""
function Base.get(container::SettingsContainer, type::DataType)::Any
    if haskey(container.settings, type)
        return container.settings[type]
    else
        return nothing
    end
end

"""
    settings(container::SettingsContainer)

Returns a dictionary with all concrete setting types as keys and vectors of all known 
settings as values. 
"""
function settings(container::SettingsContainer)::Dict{DataType, Vector{Setting}}
    return container.settings
end

"""
    settings(container::SettingsContainer, type::DataType)

Returns a vector of all known settings with provided type. 
"""
function settings(container::SettingsContainer, type::DataType)::Vector{Setting}
    return container.settings[type]
end

"""
    setting(container::SettingsContainer, type::DataType, id::Int32)

Returns a particular setting of a particular type and ID.
"""
function setting(container::SettingsContainer, type::DataType, id::Int32)
    return settings(container, type)[id]
end

"""
    settingtypes(container::SettingsContainer)

Returns all known setting types of the provided container.
"""
function settingtypes(container::SettingsContainer)
    return keys(container.settings)
end


"""
    new_setting_ids!(cntnr::SettingsContainer, renaming_dict::Dict = Dict())

This function checks and updates the ids of settings in a `SettingsContainer` object 
to ensure that they are continuous and start from 1. If the ids are not continuous 
or do not start from 1, the function will generate a warning and update the ids accordingly.
This is then also used to update the contained and contains fields of the settings.

# Arguments
- `cntnr::SettingsContainer`: The `SettingsContainer` object containing the settings.
"""
function new_setting_ids!(cntnr::SettingsContainer, renaming_dict::Dict = Dict())
    # If the renaming_dict is empty, create a new one by checking the ids of all settingtypes and updating them if 
    # they are not continuous and start from 1
    if renaming_dict == Dict()
        for (settingtype, settinglist) in settings(cntnr)

            # Sort the vector of settings by ID
            sort!(settinglist, by = x -> x.id)

            # Check if the ids are continuous and start from 1
            if length(settinglist) != 0 && (settinglist |> Base.first |> id != 1 || settinglist |> Base.last |> id != length(settinglist))

                # Add a new dictionary to the renaming_dict for the settingtype at hand
                renaming_dict[settingtype] = Dict()

                # Iterate through the settings, update the ids accordingly and store the changes in the dictionary
                for (i, setting) in enumerate(settinglist)
                    renaming_dict[settingtype][setting.id] = i
                    setting.id = i
                end
            end
        end
    end

    # Iterate through all settingtypes and update the contained and contains fields of the settings
    for (settingtype, settinglist) in settings(cntnr)

        # Change the id of the container setting if there are settings of this type
        if length(settinglist) != 0 && hasfield(settingtype, :contained)

            # Check if the contained setting type were reassigned an id
            if haskey(renaming_dict, settinglist[1].contained_type)

                # Iterate through the settings and update the contained field
                for setting in settinglist
                    try
                        setting.contained = renaming_dict[setting.contained_type][setting.contained]
                    catch
                        @warn "The container for $settingtype with id $(setting.id) was provided as $(setting.contained_type) with id $(setting.contained), but not found in the data."
                        setting.contained = DEFAULT_SETTING_ID
                    end
                end
            end
        end

        # Change the id of the contained setting
        if length(settinglist) != 0 && hasfield(settingtype, :contains)

            # Check if the contains setting type were reassigned an id
            if haskey(renaming_dict, settinglist[1].contains_type)

                # Iterate through the settings and update the contains field
                for setting in settinglist

                    # Get the new ids of the contains settings if they can not be found in the dicitonary turn them to missing and filter them out
                    setting.contains = [get(renaming_dict[setting.contains_type], sc, missing) for sc in setting.contains] |> x -> filter!(!ismissing, x) 
                    if length(setting.contains) == 0
                        @warn "The container with type $settingtype with id $(setting.id) is empty."
                    end
                end
            end
        end
    end
end

"""
    delete_dangling_ids!(cntnr::SettingsContainer)

Sets all dangling IDs, i.e., IDs that do not point to any setting, to the default setting ID.
"""
function delete_dangling_ids!(cntnr::SettingsContainer)
    # Iterate through the settingsconteiner
    for (type, setting_list) in settings(cntnr)

        # Iterate through the settings of the type
        for setting in setting_list

            # Handle settings with a contained field
            if hasproperty(setting, :contained)

                # Check if the contained ID is out of bounds, i.e., larger than the length of the settings of the contained_type
                if setting.contained != DEFAULT_SETTING_ID
                    if length(settings(cntnr)[setting.contained_type]) < setting.contained

                        # Log a warning message
                        @warn "Setting of type $(setting.contained) with id $(setting.id) has a contained ID that is out of bounds"

                        # Set the contained ID to the default setting ID
                        setting.contained = DEFAULT_SETTING_ID
                    end
                end
            end

            # Handle settings with a contains field
            if hasproperty(setting, :contains)

                # Iterate through the contains IDs
                for (i, s) in enumerate(setting.contains)

                    # Check if the contains ID is out of bounds, i.e., larger than the length of the settings of the contains_type
                    if length(settings(cntnr)[setting.contains_type]) < s

                        # Log a warning message
                        @warn "Setting of type $(setting.contains_type) with id $(setting.id) has a contains ID that is out of bounds"
                        
                        # Remove the out of bounds ID from the contains field
                        deleteat!(setting.contains, i)
                    end
                end
            end
        end
    end
end

"""
    settings_from_jld2!(jld2file::String, cntnr::SettingsContainer, d::Dict= Dict())

Loads the settings saved in `jld2file` and add them to the existing SettingsContainer. The renaming dictionary is used to
find the correct updated values of the ids of the IndividualSettings and change the values in the containers accordingly.
If the jld2file does not correspond to "" (corresponding to no settingfile) and does not exist, an error message is printed.
"""
function settings_from_jld2!(jld2file::String, cntnr::SettingsContainer, d::Dict= Dict())
    if jld2file == "" 
        return
    elseif isfile(jld2file)
        settings::Dict = load(jld2file, "data")

        # Default sampling method
        default_sampling = RandomSampling()

        # Get all setting types from the settings dictionary
        prov_settingtypes = settings |> keys |> collect |> x -> eval.(x)

        # Add all setting types to the container
        add_types!(cntnr, [s for s in prov_settingtypes if s in concrete_subtypes(Setting)])
        
        # Iterate over all setting types in parallel and add the settings to the container
        for settingtypesym::Symbol in settings |> keys |> collect
            settingtype::DataType = eval(settingtypesym)
            if "ags" in names(settings[settingtypesym])
                transform!(settings[settingtypesym], :ags => ByRow(ags -> AGS(ags)) => :ags)
            end

            # Handle individualsettings and containersettings differently
            if :individuals in fieldnames(settingtype)

                # Add the correct additional values to the low level settings
                for col in names(settings[settingtypesym])
                    if Symbol(col) in fieldnames(settingtype) && col != "individuals" && col != "id"
                        for row in eachrow(settings[settingtypesym])
                            try

                                # Check if ids were reassigned and alter them accordingly
                                if haskey(d, settingtype)

                                    # Check if the id is in the dictionary otherwise it might be missing
                                    # in the population file and the row will be ignored
                                    if haskey(d[settingtype], row.id)
                                        setfield!(cntnr.settings[settingtype][d[settingtype][row.id]], Symbol(col), row[col])
                                    end
                                else
                                    # Add the value to the setting if the id was not altered
                                    setfield!(cntnr.settings[settingtype][row.id], Symbol(col), row[col])
                                end
                            catch e
                                @warn("Could not set field $col in $settingtype of type $(Dict(zip(fieldnames(settingtype), fieldtypes(settingtype)))[Symbol(col)]) with id $(row.id) to value $(row[col]) of type $(typeof(row[col])) due to error $e")
                            end
                        end
                    end
                end

            # Handle the container settings
            else

                # Add the container settings from the dataframe
                for row in eachrow(settings[settingtypesym])
                    push!(cntnr.settings[settingtype], settingtype(contact_sampling_method = default_sampling; row...))
                end
                # Sort the vector of settings by ID
                sort!(cntnr.settings[settingtype], by = x -> x.id)

                # Check if the ids are continuous and start from 1
                if length(cntnr.settings[settingtype]) != 0 && (cntnr.settings[settingtype] |> Base.first |> id != 1 || cntnr.settings[settingtype] |> Base.last |> id != length(cntnr.settings[settingtype]))
                    d[settingtype] = Dict()
                    for (i, setting) in enumerate(cntnr.settings[settingtype])
                        d[settingtype][setting.id] = i
                        setting.id = i
                    end
                end
            end
        end

        # Rename all the settings according to the new ids determined during the creation procedure
        new_setting_ids!(cntnr, d)

        # Delete all ids that are out of bounds and set them to the default setting id
        delete_dangling_ids!(cntnr)
    else 
        error("The file $jld2file does not exist.\n Please provide a valid file path pointing to the desired settingfile!")
    end
end