using DataFrames, FileIO, JLD2, VegaLite, DataVoyager, StatsBase, Plots, BenchmarkTools, ZipFile, Tables

function load_people(path)

    # Load data for people
    people = DataFrame(
        id = Int32.(load(joinpath(path, "P_PID.jld2"),"data")),        # Load ID data
        #household = load(joinpath(path, "P_AID.jld2"),"data"), # Load household data
        household = load(joinpath(path, "P_AID2.jld2"),"data"), # Load household data
        # BID = load(joinpath(path, "P_BID.jld2"),"data"),       # Load building ID data
        age = load(joinpath(path, "P_Age.jld2"),"data"),       # Load age data
        sex = load(joinpath(path, "P_Gender.jld2"),"data"),    # Load sex data
        AGS = load(joinpath(path, "P_AGS.jld2"),"data"),       # Load AGS data
        lon = load(joinpath(path, "P_Lon.jld2"),"data"),       # Load longitude data
        lat = load(joinpath(path, "P_Lat.jld2"),"data"),       # Load latitude data
        # OCCUPATION = load(joinpath(path, "P_Occupation.jld2"),"data"), # Load occupation data
        # OCC_TYPE = load(joinpath(path, "P_Occupation_type.jld2"),"data"), # Load occupation data
        # OCC_TYPE = load(joinpath(path, "P_Occupation_type.jld2"),"data"),
        # OCCUPATION = load(joinpath(path, "P_Occupation.jld2"),"data"),
        OCC_TYPE = load(joinpath(path, "P_Occupation_type_b.jld2"),"data"),
        OCCUPATION = load(joinpath(path, "P_Occupation_b.jld2"),"data"),
	    ef137 = Int16.(load(joinpath(path, "P_EF137.jld2"),"data"))
        # GGK = load(joinpath(path, "P_GGK.jld2"),"data"),       # Load GGK data
        # S = load(joinpath(path, "P_S.jld2"),"data"),           # Load S data
        # NORTH = load(joinpath(path, "P_North.jld2"),"data")    # Load NORTH data
    )

    return people
end


function load_buildings(path)
    # Load data for people
    buildings = DataFrame(
        ags = Int32.(load(joinpath(path, "B_AGS.jld2"),"data")),        # Load AGS data
        # apartment = load(joinpath(path, "B_Apartment.jld2"),"data"), # Load apartment data
        bid = load(joinpath(path, "B_BID.jld2"),"data"),       # Load building ID data
        # height = load(joinpath(path, "B_Building_height.jld2"),"data"),       # Load building height data
        # type = load(joinpath(path, "B_Building_type.jld2"),"data"),    # Load building type data
        lon = Float32.(load(joinpath(path, "B_Lon.jld2"),"data")),       # Load longitude data
        lat = Float32.(load(joinpath(path, "B_Lat.jld2"),"data")),       # Load latitude data
        # name = load(joinpath(path, "B_Location_Names_SH.jld2"),"data"),    # Load location names data
        # size = load(joinpath(path, "B_location_Sizes_SH.jld2"),"data"),       # Load location sizes data
        # location = load(joinpath(path, "B_Location.jld2"),"data"),       # Load location data
        # osm_id = load(joinpath(path, "B_osm_id.jld2"),"data"), # Load OSM ID data
        # osm_type = load(joinpath(path, "B_osm_type.jld2"),"data"), # Load OSM type data
    )
    return buildings
end

"""
    obtain_levels(people_in, occ_types)

    This function is used to obtain the levels of settings for a given set of occupation types.
    The levels are stored in a dictionary where the keys are the level numbers and the values
    are the DataFrames including a row for each setting of that level. The DataFrames include
    the columns `id`, `type`, `contains`, and `individuals`. The `id` column is the unique id
    of the setting, the `type` column is the type of the setting, i.e., the structural parameter
    of that level or the BID for the highest level of setting, the `contains` column is a vector 
    of the unique ids of the settings contained in the setting, i.e., of the settings one level
    lower, and the `individuals` column, only present in the lowest level, is a vector of the unique
    ids of the individuals contained in the setting.

    # Arguments
    - `people_in`: Dataframe including the population data.
    - `occ_types`: The list of occupation types to be considered.
    - `max_sublevels`: The maximum number of sublevels to be considered (= 0 -> using just the building).

    # Returns
    - `levels`: The levels of the settings in a dictionary.
 """
function obtain_levels(people_in, occ_types; max_sublevels = 5)
    people = deepcopy(people_in)
    # Filter where the occupation is not [] the people DataFrame by the occupation type
    filter!(row -> row.OCCUPATION != [] && row.OCC_TYPE in occ_types, people)

    lvls = Dict()

    # Get the last elements of the occupation vector and store them in the workhome and inroom column
    # Also remove them and the second element from the occupation vector in each row
    select!(people, :, [:OCCUPATION] => ByRow(occ-> (Int8(occ[end-1]), Int8(occ[end]), occ[vcat(1, 3:min(length(occ)-2, max_sublevels + 2) )], occ[1])) => [:inroom, :workhome, :OCCUPATION, :bid])

    # Group by occupation
    people = groupby(people, :OCCUPATION) |>
        # Combine entries and create columns for contained individuals and unique id
        x -> combine(x, 
        :workhome => first => :workhome, # just use the first entry as they are all the same
        :inroom => first => :inroom,  # just use the first entry as they are all the same
        :bid => first => :bid,  # just use the first entry as they are all the same
        :id => (x -> [collect(x)]) => :individuals)

    # Add a column for the unique id corresponding to the lowest level id
    people.id = Int32.(1:size(people, 1))

    # Transform occupation vector and remove last entry if empty
    select!(people, :, [:OCCUPATION] => ByRow(occ-> (Int32.(occ[end]), occ[1:end-1] == [] ? missing : occ[1:end-1])) => [:type, :OCCUPATION])

    # Store lvl1 in the dictionary
    lvls[1] = select!(deepcopy(people), Not(:OCCUPATION))

    # Remove rows with missing entries
    people = dropmissing!(people)

    # Initialize the current level
    current_lvl = 1

    # Iterate until the current level reaches max_sublevels
    while current_lvl < max_sublevels
        # Increment the current level
        current_lvl += 1
        
        # Group the people DataFrame by OCCUPATION
        grouped_people = groupby(people, :OCCUPATION) 
        
        # Check if there are no more groups
        if length(grouped_people) == 0
            break
        else
            # Combine the groups and create a new column for contains
            people = combine(grouped_people, :id => (x -> [collect(x)]) => :contains)
            
            # Add a column for the unique id
            people.id = Int32.(1:size(people, 1))
            
            # Transform the OCCUPATION column and remove the last entry if empty
            # If the building should not be considered as a level, entries of length 1 must be turned into missing
            transform!(people, :OCCUPATION => ByRow(occ -> Int32(occ[end])) => :type,
                    :OCCUPATION => ByRow(occ -> occ[1:end-1] == [] ? missing : occ[1:end-1]) => :OCCUPATION)
            
            # Store the current level DataFrame in the lvls dictionary
            lvls[current_lvl] = select!(deepcopy(people), Not(:OCCUPATION))
            
            # Remove rows with missing entries
            people = dropmissing!(people)
        end
    end

    # Move through the levels and add the contained by column
    for i in sort(collect(keys(lvls)), rev = true)[2:end]
        lvls[i][:, "contained"] = Int32.(fill(-1, nrow(lvls[i])))
        for row in eachrow(lvls[i+1])
            lvls[i][row.contains, "contained"] = Int32.(fill(row.id, length(row.contains)))
        end
    end

    return lvls
end

"""
    add_lowest_level(people, stng_df, setting_name_df)

Add the ids of the lowest level of settings, i.e., those directly containing 
the individuals (provided in the stng_df), to the in a column of the `people` DataFrame.
The name of the column is given by `setting_name_df`.

# Arguments
- `people`: DataFrame representing the population data.
- `stng_df`: DataFrame containing the settings data.
- `setting_name_df`: Name to be used for the setting column in the people dataframe.

"""
function add_lowest_level!(people, stng_df, setting_name_df)
    # Prepare a DataFrame from expanding `SchoolClass` settings
    expanded_df = DataFrame(individual_id = Int[])
    expanded_df[:, setting_name_df] = Int[]
    sname = Symbol(setting_name_df)
    # Expand the individuals into rows
    for row in eachrow(stng_df)
        for individual in row.individuals
            push!(expanded_df,  NamedTuple{(:individual_id, sname)}((individual, row.id)))
        end
    end

    # Performing the left join
    leftjoin!(people, expanded_df, on = :id => :individual_id)

    # Handle missing schoolclass_id (assuming that these should be set to -1)
    people[!,setting_name_df] = coalesce.(people[:,setting_name_df], -1)
end


"""
    add_buildings!(people, identifiers, lvl_names, lowest_lvl_name, buildings, stng_dict; max_sublevels = 4)

Add buildings to the population data.

# Arguments
- `people`: DataFrame containing population data.
- `identifiers`: Vector containing identifiers, i.e., occupation type in the .
- `lvl_names`: Vector of symbols representing the names of the building levels.
- `lowest_lvl_name`: String representing the name of the lowest level of settings to be added in the population dataframe.
- `buildings`: DataFrame containing building data.
- `stng_dict`: Dictionary containing the settings data, where the new settings data will be appended.
- `max_sublevels`: Optional argument specifying the maximum number of sublevels.

"""
function add_buildings!(people, identifiers, lvl_names, lowest_lvl_name, buildings, stng_dict; max_sublevels = 4)
    # Get the building levels
    building_lvls = obtain_levels(people, identifiers; max_sublevels = max_sublevels)

    # Add the buildings ags to the lowest level of the settings
    leftjoin!(building_lvls[1], buildings, on = :bid => :bid)

    # Setting names for the levels
    rename_dict = Dict(zip([1,2,3,4], lvl_names))

    # Rename the level_cols column to setting_names
    addition_dict = Dict(
        get(rename_dict, k, k) => v for (k, v) in building_lvls
    )
    merge!(stng_dict, addition_dict)

        
    # Add the ids of the lowest level of settings to the people DataFrame
    # as these settings are created from the population not setting file
    add_lowest_level!(people, building_lvls[1], lowest_lvl_name)

end

"""
    filter_bundesland(people, bundesland, ags_length = 8)

Helper function to filter only a specific bundesland from the people DataFrame.

# Arguments
- `people`: DataFrame containing the population data.
- `bundesland`: String representing the bundesland to be filtered. "01" for Schleswig-Holstein.
- `ags_length`: Optional argument specifying the length of the ags.

"""
function filter_bundesland(people, bundesland, ags_length = 8)
    if bundesland == "00"
        return people
    end
    f = (x) -> lpad(string(x), ags_length, '0')
    return filter(row -> startswith(f(row.AGS), bundesland), people)
end

"""
    filter_ags(people, ags)

Helper function to filter only a specific ags from the people DataFrame. 
Leading zeros should be omitted from the ags.
"""
function filter_ags(people, ags)
    return filter(row -> row.AGS == ags, people)
end


"""
    create_people_settings(raw_people, buildings)

This function is used to create the settings for the population data. The function takes the following inputs:
    - `raw_people`: The raw population data.
    - `buildings`: The building data.

The function returns the people DataFrame and the settings dictionary.
"""
function create_people_settings(raw_people, buildings)
    people = deepcopy(raw_people)
    people.household = groupby(people, :household) |> groupindices |> x -> [Int32(i) for i in x]

    # Add municipality to the individuals
    people.municipality = groupby(people, :AGS) |> groupindices |> x -> [Int32(i) for i in x]
    municipalities = groupby(people, :municipality) |> x -> combine(x, :AGS => (first) => :ags) |> x -> select(x, :municipality => :id, :ags => ByRow(x -> Int32(x)) => :ags)

    # Get ags for households
    households = groupby(people, :household) |> 
    x -> combine(x, :AGS => (first) => :ags, :lon => (first) => :lon, :lat => (first)=> :lat  ) |> 
    x -> select(x, [:household, :ags, :lon, :lat] => ByRow( (hh, ags, lon,lat)-> (hh, Int32(ags), Float32(lon), Float32(lat))) =>  [:id, :ags, :lon, :lat])
    stng_dict = Dict(:Household => households, :Municipality => municipalities)


   
    # Get the school levels 
    # Note that these also include Kita Kinderkrippe Uni and FH
    schools = ["Kita", "Kinderkrippe", "FH", "Orientierungsstufe", "UNI", "Realschule", "Gymnasium", "Hauptschule", "Gesamtschule", "Grundschule", "Berufsbildendeschule", "Sonderschule"]
    school_symbols = [:SchoolClass, :SchoolYear, :School, :SchoolComplex]
    add_buildings!(people, schools, school_symbols, "schoolclass", buildings, stng_dict; max_sublevels = 4)

    # Get the workplace levels
    workplaces = ["wz2008_01","wz2008_02","wz2008_03", "wz2008_04", "wz2008_05", "wz2008_06",
    "wz2008_07", "wz2008_08", "wz2008_09", "wz2008_10", "wz2008_11", "wz2008_12",
    "wz2008_13", "wz2008_14", "wz2008_15", "wz2008_16", "wz2008_17", "wz2008_18", "wz2008_19"]
    workplace_symbols = [:Office, :Department, :Workplace, :WorkplaceSite]
    add_buildings!(people, workplaces, workplace_symbols, "office", buildings, stng_dict; max_sublevels = 4)
    
    select!(people, Not(:OCCUPATION, :OCC_TYPE))
    rename!(people, :ef137 => :occupation)
    return people, stng_dict
end


"""
    create_files(in_path::String, out_path::String; fltr::Function = x->x, filter_dict::Dict = Dict(), zp = false)

This function is used to create the settings and population files for a given input path. The function takes the following inputs:
    - `in_path::String`: The path to the input files.
    - `out_path::String`: The path to the output files.
    - `fltr::Function`: A function to filter the people DataFrame.
    - `filter_dict::Dict`: A dictionary containing the filter values.
    - `zp::Bool`: A boolean indicating whether the output files should be compressed.

The function returns nothing.
"""
function create_files(in_path::String, out_path::String; fltr::Function = x->x, filter_dict::Dict = Dict(), zp = false)
    # Load the people and buildings
    @info "Loading input files..."
    people = load_people(in_path)
    buildings = load_buildings(in_path)
    buildings = unique(buildings, :bid)
    @info "\u2514 Done loading input files."
    # Filter the people
    if length(filter_dict) > 0
        for (key, value) in filter_dict
            @info "Creating output for $key..."
            people_out, stng_dict = create_people_settings(fltr(people, value), buildings)
            setting_path = joinpath(out_path, "settings_$key.jld2")
            people_path = joinpath(out_path, "people_$key.jld2")

             # Save the settings
            optimized_settings = NamedTuple(k => Tables.columntable(v) for (k, v) in stng_dict)
            save(setting_path, "data", optimized_settings)
            
            # Save the people
            optimized_people = Tables.columntable(people_out)
            save(people_path, "data", optimized_people)
    
            if zp
                @info "\u2514 Compressing output files for $key..."
                # Create a zip archive
                zip_path = joinpath(joinpath(out_path, "$key.zip"))
    
                run(`zip -j $zip_path $setting_path $people_path`)
        
                # Delete the original files
                rm(setting_path)
                rm(people_path)
        
                @info "\u2514 Saved and compressed output files for $key."
            else
                @info "\u2514 Saved output files for $key."
            end
        end
    else
        people, stng_dict = create_people_settings(people, buildings)
    
        # Save the settings
        optimized_settings = NamedTuple(k => Tables.columntable(v) for (k, v) in stng_dict)
        save(joinpath(out_path, "settings.jld2"), "data", optimized_settings)
        
        # Save the people
        optimized_people = Tables.columntable(people)
        save(joinpath(out_path, "people.jld2"), "data", optimized_people)
    
        if zp
            @info "\u2514 Compressing output files..."
            # Create a zip archive
            zip_path = joinpath(out_path, "people_and_settings.zip")
            settings_path = joinpath(out_path, "settings.jld2")
            people_path = joinpath(out_path, "people.jld2")
            ZipFile.zip(zip_path, [settings_path, people_path])
    
            # Delete the original files
            rm(settings_path)
            rm(people_path)
    
            @info "\u2514 Saved and compressed output files."
        else
            @info "\u2514 Saved output files."
        end
    end
end

# Filter dictionary for the bundeslaender
bundeslaender = Dict(
    "SH" => "01", # Schleswig-Holstein
    "HH" => "02", # Hamburg
    "NI" => "03", # Niedersachsen
    "HB" => "04", # Bremen
    "NRW" => "05", # Nordrhein-Westfalen
    "HE" => "06", # Hessen
    "RP" => "07", # Rheinland-Pfalz
    "BW" => "08", # Baden-Württemberg
    "BY" => "09", # Bayern
    "SL" => "10", # Saarland
    "BE" => "11", # Berlin
    "BB" => "12", # Brandenburg
    "MV" => "13", # Mecklenburg-Vorpommern
    "SN" => "14", # Sachsen
    "ST" => "15", # Sachsen-Anhalt
    "TH" => "16",  # Thüringen
    )




# Create the settings and population files
create_files("/home/patznju/gesyland_occupation/gesyland_2019_v03", "/home/patznju/gesyland_occupation/gesyland_2019_v03_transformed"; zp = true, filter_dict = bundeslaender2, fltr = filter_bundesland)
