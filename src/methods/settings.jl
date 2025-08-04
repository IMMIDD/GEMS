export household, office, schoolclass, municipality, getsetting
export min_individuals, avg_individuals, max_individuals, min_max_avg_individuals, incidence, get_containers!, get_contained!, individuals, individuals!, ags
export geolocation, lat, lon, remove_empty_settings!, present_individuals, present_individuals!, is_open, get_open_contained!, open!, close!
export sample_individuals


### setting extraction from individuals
"""
    household(i::Individual, sim::Simulation)::Household

Returns the `Household` instance referenced in an individual. 
"""
function household(i::Individual, sim::Simulation)::Household
    return sim |> settings |>
        x -> x[Household] |>
        x -> x[household_id(i)]
end

"""
    office(i::Individual, sim::Simulation)::Office

Returns the `Office` instance referenced in an individual. 
"""
function office(i::Individual, sim::Simulation)::Office
    !is_working(i) ? throw("Individual $(id(i)) is not assigned to an Office") :

    return sim |> settings |>
        x -> x[Office] |>
        x -> x[office_id(i)]
end


"""
    getsetting(i::Individual, sim::Simulation, ::Type{Office})::Office

Return the `Office` setting to which the individual `i` belongs, based on
their `office` ID.
"""
function getsetting(i::Individual, sim::Simulation, ::Type{Office})
    return office(i, sim)
end


"""
    getsetting(i::Individual, sim::Simulation, ::Type{Department})::Department

Return the `Department` that contains the individual's `Office`.
"""
function getsetting(i::Individual, sim::Simulation, ::Type{Department})
    return getsetting(i, sim, Office).contained |>
        id -> settings(sim, Department)[id]
end


"""
    getsetting(i::Individual, sim::Simulation, ::Type{Workplace})::Workplace

Return the `Workplace` that contains the individual's `Department`.
"""
function getsetting(i::Individual, sim::Simulation, ::Type{Workplace})
    return getsetting(i, sim, Department).contained |>
        id -> settings(sim, Workplace)[id]
end


"""
    getsetting(i::Individual, sim::Simulation, ::Type{WorkplaceSite})::WorkplaceSite

Return the `WorkplaceSite` that contains the individual's `Workplace`.
"""
function getsetting(i::Individual, sim::Simulation, ::Type{WorkplaceSite})
    return getsetting(i, sim, Workplace).contained |>
        id -> settings(sim, WorkplaceSite)[id]
end


"""
    schoolclass(i::Individual, sim::Simulation)::SchoolClass

Returns the `SchoolClass` instance referenced in an individual. 
"""
function schoolclass(i::Individual, sim::Simulation)::SchoolClass
    !is_student(i) ? throw("Individual $(id(i)) is not assigned to a School Class") :

    return sim |> settings |>
        x -> x[SchoolClass] |>
        x -> x[class_id(i)]
end

"""
    getsetting(i::Individual, sim::Simulation, ::Type{SchoolClass})::SchoolClass

Return the `SchoolClass` setting to which the individual `i` belongs, based on
their `schoolclass` ID.
"""
function getsetting(i::Individual, sim::Simulation, ::Type{SchoolClass})
    return schoolclass(i, sim)
end


"""
    getsetting(i::Individual, sim::Simulation, ::Type{SchoolYear})::SchoolYear
"""
function getsetting(i::Individual, sim::Simulation, ::Type{SchoolYear})
    class = getsetting(i, sim, SchoolClass)
    year_id = class.contained
    return settings(sim, SchoolYear)[year_id]
end


"""
    getsetting(i::Individual, sim::Simulation, ::Type{School})::School

Return the `School` setting containing the individual's `SchoolYear`.
"""
function getsetting(i::Individual, sim::Simulation, ::Type{School})
    year = getsetting(i, sim, SchoolYear)
    school_id = year.contained
    return settings(sim, School)[school_id]
end


"""
    getsetting(i::Individual, sim::Simulation, ::Type{SchoolComplex})::SchoolComplex

Return the `SchoolComplex` setting containing the individual's `School`.
"""
function getsetting(i::Individual, sim::Simulation, ::Type{SchoolComplex})
    school = getsetting(i, sim, School)
    complex_id = school.contained
    return settings(sim, SchoolComplex)[complex_id]
end

"""
    municipality(i::Individual, sim::Simulation)::Municipality

Returns the `Municipality` instance referenced in an individual. 
"""
function municipality(i::Individual, sim::Simulation)::Municipality
    return sim |> settings |>
        x -> x[Municipality] |>
        x -> x[municipality_id(i)]
end

### Setting access functions

"""
    isopen(setting::Setting)

Returns wether the setting is opened (contacts can occur) or not. Without considering its containers.
"""
function is_open(setting::Setting)::Bool
    return(setting.isopen)
end

"""
    get_contained!(stng::Setting, dct::Dict{DataType, Vector{Int32}}, sim::Simulation)

Recursively gets the contained settings of the setting `stng` and adds them to the dictionary `dct`.

# Parameters

- `stng::ContainerSetting`: Setting that may contain more settings on lower levels
- `dct::Dict{DataType, Vector{Int32}}`: Dictionary that will be filed with the found settings
- `sim::Simulation`: Simulation object
"""
function get_contained!(stng::ContainerSetting, dct::Dict{DataType, Vector{Int32}}, sim::Simulation)
    if stng.contains != DEFAULT_SETTING_ID
        if haskey(dct, stng |> contains_type)
            push!(dct[stng |> contains_type], (stng |> contains)...)
        else
            dct[stng |> contains_type] = stng |> contains |> deepcopy
        end
        for s in stng.contains
            get_contained!(settings(sim, stng |> contains_type)[s], dct, sim)
        end
    end
end

"""
    get_contained!(stng::IndividualSetting, dct::Dict, sim::Simulation)

Gets the contained settings of an IndividualSetting, i.e., none.

# Parameters

- `stng::IndividualSetting`: Lowest-level setting
- `dct::Dict{DataType, Vector{Int32}}`: Dictionary that will be filed with the found settings
- `sim::Simulation`: Simulation object
"""
function get_contained!(stng::IndividualSetting, dct::Dict{DataType, Vector{Int32}}, sim::Simulation)
    return
end

"""
    get_open_contained!(stng::ContainerSetting, dct::Dict{DataType, Vector{Int32}}, sim::Simulation)

Recursively gets the contained settings of the setting `stng` and adds them to the dictionary `dct`
if the containing setting is open.

# Parameters

- `stng::ContainerSetting`: Setting that may contain more settings on lower levels
- `dct::Dict{DataType, Vector{Int32}}`: Dictionary that will be filed with the found settings
- `sim::Simulation`: Simulation object
"""
function get_open_contained!(stng::ContainerSetting, dct::Dict{DataType, Vector{Int32}}, sim::Simulation)
    if is_open(stng)
        if !haskey(dct, typeof(stng))
            dct[typeof(stng)] = [stng |> id]
        else
            push!(dct[typeof(stng)], stng |> id)
        end
        if stng.contains != DEFAULT_SETTING_ID
            for s in stng.contains
                get_open_contained!(settings(sim, stng.contains_type)[s], dct, sim)
            end
        end
    end
end

"""
    get_open_contained!(stng::IndividualSetting, dct::Dict{DataType, Vector{Int32}}, sim::Simulation)

Adds the individualsetting to the provided dictionary if it is open.

# Parameters

- `stng::IndividualSetting`: Lowest-level setting
- `dct::Dict{DataType, Vector{Int32}}`: Dictionary that will be filed with the found settings
- `sim::Simulation`: Simulation object
"""
function get_open_contained!(stng::IndividualSetting, dct::Dict{DataType, Vector{Int32}}, sim::Simulation)
    if is_open(stng)
        if !haskey(dct, typeof(stng))
            dct[typeof(stng)] = [stng |> id]
        else
            push!(dct[typeof(stng)], stng |> id)
        end
    end
end


"""
    get_containers!(stng::Setting, dct::Dict{DataType, Int32}, sim::Simulation)

Recursively gets the containers of the setting `stng` and adds them to the dictionary dct.

# Parameters

- `stng::Setting`: Setting to get upper-level settings for
- `dct::Dict{DataType, Vector{Int32}}`: Dictionary that will be filed with the found settings
- `sim::Simulation`: Simulation object
"""
function get_containers!(stng::Setting, dct::Dict{DataType, Int32}, sim::Simulation)::Nothing
    if hasproperty(stng, :contained)
        if stng.contained != DEFAULT_SETTING_ID
            dct[stng.contained_type] = stng.contained
            get_containers!(settings(sim, stng.contained_type)[stng.contained], dct, sim)
        end
    end
end

### Getting the individuals of a setting

"""
    individuals!(setting::IndividualSetting, indivs::Vector{Individual}, simulation::Simulation)

Appends the individuals associated with a given IndividualSetting to the provided `indivs` vector.

# Parameters

- `setting::IndividualSetting`: Setting to get the individuals from
- `indivs::Vector{Individual}`: List that will be appeneded with the setting's individuals
- `simulation::Simulation`: Simulation object
"""
function individuals!(setting::IndividualSetting, indivs::Vector{Individual}, simulation::Simulation)
    append!(indivs, setting |> individuals)
end

"""
    individuals!(setting::ContainerSetting, indivs::Vector{Individual}, simulation::Simulation)

Appends the individuals associated with a given ContainerSetting to the provided `indivs` vector by
recursively calling the `individuals!` function. 

# Parameters

- `setting::ContainerSetting`: Setting to get the individuals from
- `indivs::Vector{Individual}`: List that will be appeneded with the setting's individuals
- `simulation::Simulation`: Simulation object
"""
function individuals!(setting::ContainerSetting, indivs::Vector{Individual}, simulation::Simulation)
    for s in setting.contains
        individuals!(settings(simulation, setting.contains_type)[s], indivs, simulation)
    end
end

"""
    individuals(setting::IndividualSetting, simulation::Simulation)

Returns the individuals associated with a given IndividualSetting.
"""
function individuals(setting::IndividualSetting, simulation::Simulation)::Vector{Individual}
    return setting |> individuals
end

"""
    individuals(setting::ContainerSetting, indivs::Vector{Individual}, simulation::Simulation)::Vector{Individual}

Returns the individuals associated with a given ContainerSetting by recursively getting the individuals of 
all contained settings using the `individuals!` function.
"""
function individuals(setting::ContainerSetting, simulation::Simulation)::Vector{Individual}
    indivs = Vector{Individual}()
    for s in setting.contains
        individuals!(settings(simulation, setting.contains_type)[s], indivs, simulation)
    end
    return indivs
end


"""
    sample_individuals(individuals::Vector{Individual}, n::Int64)

Returns a subsample of a vector of `Individuals` of sample size `n`.
"""
function sample_individuals(individuals::Vector{Individual}, n::Int64)
    if n >= length(individuals)
        return individuals
    else
        return sample(individuals, n, replace = false)
    end
end


"""
    sample_individuals(setting::IndividualSetting, n::Int64)

Returns a subsample of the setting's `Individuals` of sample size `n`.
"""
sample_individuals(setting::IndividualSetting, n::Int64) = sample_individuals(setting |> individuals, n)


"""
    present_individuals!(setting::IndividualSetting, indivs::Vector{Individual}, simulation::Simulation)

Pushes the individuals present in a given IndividualSetting, i.e., only those in open settings to the provided `indivs` vector. 

# Parameters

- `setting::IndividualSetting`: Setting to get the individuals from
- `indivs::Vector{Individual}`: List that will be appeneded with the setting's individuals
- `simulation::Simulation`: Simulation object
"""
function present_individuals!(setting::IndividualSetting, indivs::Vector{Individual}, simulation::Simulation)
    if is_open(setting)
        append!(indivs, setting |> individuals)
    end
end

"""
    present_individuals!(setting::ContainerSetting, indivs::Vector{Individual}, simulation::Simulation)

Pushes the individuals present in a given ContainerSetting, i.e., only those in open contained settings to the provided `indivs` vector.  

# Parameters

- `setting::ContainerSetting`: Setting to get the individuals from
- `indivs::Vector{Individual}`: List that will be appeneded with the setting's individuals
- `simulation::Simulation`: Simulation object
"""
function present_individuals!(setting::ContainerSetting, indivs::Vector{Individual}, simulation::Simulation)
    # Check that setting and all containers are open
    if setting |> is_open
        for s in setting |> contains
            present_individuals!(settings(simulation, setting.contains_type)[s], indivs, simulation)
        end
    end
end

"""
    present_individuals(setting::IndividualSetting, simulation::Simulation)

Returns the individuals present in a given IndividualSetting, i.e., only those in open settings. 
"""
function present_individuals(setting::IndividualSetting, simulation::Simulation)::Vector{Individual}
    if is_open(setting)
        return individuals(setting)
    else
        return Vector{Individual}()
    end
end

"""
    present_individuals(setting::ContainerSetting, simulation::Simulation)

Returns the individuals present in a given ContainerSetting, i.e., only those in open contained settings. 
"""
function present_individuals(setting::ContainerSetting, simulation::Simulation)::Vector{Individual}
    # Check that setting and all containers are open
    indivs = Vector{Individual}()
    present_individuals!(setting, indivs, simulation)
    return indivs
end

"""
    ags(stng::ContainerSetting, sim::Simulation)

Get the ags of a ContainerSetting.
"""
function ags(stng::ContainerSetting, sim::Simulation)::AGS
    return length(stng.contains) > 0 ? ags(settings(sim, stng.contains_type)[stng.contains |> Base.first], sim) : AGS()
end

"""
    ags(stng::IndividualSetting)

Get the ags of a IndividualSetting.
"""
function ags(stng::IndividualSetting)::AGS
    return stng.ags
end

"""
    ags(stng::IndividualSetting, sim::Simulation)

Get the ags of a IndividualSetting.
"""
function ags(stng::IndividualSetting, simulation::Simulation)::AGS
    return stng |> ags
end


"""
    lat(stng::Geolocated)

Returns latitude of geolocated setting.
"""
lat(stng::Geolocated) = stng.lat

"""
    lon(stng::Geolocated)

Returns longitude of geolocated setting.
"""
lon(stng::Geolocated) = stng.lon

"""
    geolocation(stng::ContainerSetting, sim::Simulation)

Get the location of a ContainerSetting by getting the location of the first contained setting.
"""
function geolocation(stng::ContainerSetting, sim::Simulation)::Vector{Float32}
    return geolocation(settings(sim, stng |> contains_type)[stng |> contains |> Base.first], sim)
end

"""
    geolocation(stng::IndividualSetting, sim::Simulation)

Get the location of a IndividualSetting. Fallback for non geolocated settings.
"""
function geolocation(stng::IndividualSetting, simulation::Simulation)::Vector{Float32}
    return [NaN32, NaN32]
end

"""
    geolocation(stng::IndividualSetting)

Get the location of a IndividualSetting. Fallback for non geolocated settings.
"""
function geolocation(stng::IndividualSetting)::Vector{Float32}
    return [NaN32, NaN32]
end

"""
    geolocation(stng::IndividualSetting, sim::Simulation)

Get the location of a IndividualSetting.
"""
function geolocation(stng::Geolocated, simulation::Simulation)::Vector{Float32}
    return [stng.lon, stng.lat]
end

"""
    geolocation(stng::IndividualSetting)

Get the location of a IndividualSetting.
"""
function geolocation(stng::Geolocated)::Vector{Float32}
    return [stng.lon, stng.lat]
end

"""
    size(setting::ContainerSetting, simulation::Simulation)

Returns the sum of the sizes of all contained settings.
"""
function Base.size(setting::ContainerSetting, simulation::Simulation)::Int
    total_size = 0
    for s_id in setting.contains
        contained_setting = settings(simulation, setting.contains_type)[s_id]
        total_size += size(contained_setting, simulation)
    end
    return total_size
end

function Base.size(setting::IndividualSetting, simulation::Simulation)::Int
    return length(individuals(setting, simulation))
end

"""
    min_individuals(stngs::Vector{Setting}, simulation::Simulation)

Returns the minimum number of individuals across all provided settings.
"""
function min_individuals(stngs::Vector{Setting}, simulation::Simulation)
    min = nothing

    for s in stngs
        cnt = length(individuals(s, simulation))
        if isnothing(min)
            min = cnt
        elseif cnt < min
            min = cnt 
        end
    end

    return(min)
end


"""
    max_individuals(stngs::Vector{Setting}, simulation::Simulation)

Returns the maximum number of individuals across all provided settings.
"""
function max_individuals(stngs::Vector{Setting}, simulation::Simulation)
    max = nothing

    for s in stngs
        cnt = length(individuals(s, simulation))
        if isnothing(max)
            max = cnt
        elseif cnt > max
            max = cnt 
        end
    end

    return(max)
end


"""
    avg_individuals(stngs::Vector{Setting}, simulation::Simulation)

Returns the average number of individuals across all provided settings.
"""
function avg_individuals(stngs::Vector{Setting}, simulation::Simulation)
    cnt = length(stngs)

    if cnt <= 0
        return(nothing)
    end

    total = 0
    for s in stngs
        total += length(individuals(s, simulation))
    end

    return(total/cnt)
end

"""
    min_max_avg_individuals(stngs::Vector{Setting}, simulation::Simulation)

Returns a three-way tuple with `(minimum, maximum, mean)` number of individuals associated with 
a setting in the provided `stngs` vector.
"""
function min_max_avg_individuals(stngs::Vector{Setting}, simulation::Simulation)

    min = nothing
    max = nothing

    scnt = length(stngs)
    
    if scnt <= 0
        return(
            (nothing, nothing, nothing)
        )
    end

    total = 0

    for s in stngs
        cnt = length(individuals(s, simulation))
        total += cnt

        # update min
        if isnothing(min)
            min = cnt
        elseif cnt < min
            min = cnt 
        end

        # update max
        if isnothing(max)
            max = cnt
        elseif cnt > max
            max = cnt 
        end
    end

    return(
        (min, max, total/scnt)
    )

end

### Open and Closing Settings

"""
    open!(setting::Setting)

Opens the setting.
"""
function open!(setting::Setting)
    setting.isopen = true
end
"""
    open!(setting::Setting, simulation::Simulation)

Sets the setting and all settings contained by it as open.
"""
function open!(setting::Setting, simulation::Simulation)
    setting.isopen = true
    d::Dict{DataType, Vector{Int32}} = Dict()
    get_contained!(setting, d, simulation)
    for (k, v) in d
        for s in settings(simulation, k)[v]
            open!(s)
        end
    end
end

"""
    close!(setting::Setting)

Closes the setting.
"""
function close!(setting::Setting)
    setting.isopen = false
end

"""
    close!(setting::Setting, simulation::Simulation)

Sets the setting and all settings contained by it as closed (not open).
"""
function close!(setting::Setting, simulation::Simulation)
    setting.isopen = false
    d::Dict{DataType, Vector{Int32}} = Dict()
    get_contained!(setting, d, simulation)
    for (k, v) in d
        for s in settings(simulation, k)[v]
            close!(s)
        end
    end
end


### Setting modification functions

"""
    remove_empty_settings!(sim::Simulation)

Removes all settings that have no individuals associated with them.
In the end update all ids to ensure that they are still correspond to the
entry in the settings container.
"""
function remove_empty_settings!(sim::Simulation)
    # Create a dictionary with the types as keys and the indices of the settings that should be removed as values
    rem_dict = Dict()

    # Iterate through the settings and add those that do not include individuals
    # As the individuals function goes through all contained settings, the deletion of
    # a container only occurs if all contained settings are empty as well. No dangling ids 
    # are therefore created.
    for (type, settinglist) in settings(sim)
        rem_dict[type] = []
        for (i, s) in enumerate(settinglist)
            if length(individuals(s, sim)) == 0
                push!(rem_dict[type], i)
            end
        end
    end

    # Delete all settings that have no individuals
    for (type, deleteats) in rem_dict
        deleteat!(settings(sim, type), deleteats)
    end

    # Update all ids
    new_setting_ids!(settingscontainer(sim))
end 