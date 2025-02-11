export create_batch_configs, func_from_string, generate_batch_info, get_nested_value, generate_combinations
"""
    set_nested!(dict, keys, value)

Set a value in a nested dictionary using a list of keys.

# Arguments
- `dict::Dict`: The dictionary in which the value should be set.
- `keys::Vector{String}`: The sequence of keys leading to the desired location.
- `value`: The value to be set at the specified location.

# Returns
- None. The function modifies the `dict` in-place.

"""
function set_nested!(dict, keys, value)
    # Traverse the dictionary using keys up to the penultimate one
    for key in keys[1:end-1]
        dict = get!(dict, key, Dict())  # If key is not found, it initializes with an empty dictionary
    end
    # Set the value at the final key location
    dict[keys[end]] = value
end

"""
    get_nested_value(dict, key_path)
    
Retrieve a value from a nested dictionary using a dot-separated key path (key.key.key.key...).

# Arguments
- `dict`: The nested dictionary from which to retrieve the value.
- `key_path::AbstractString`: A dot-separated string representing the path to the desired value in the nested dictionary.

# Returns
- The value found at the specified key path, or `nothing` if the path does not exist in the dictionary.

"""
function get_nested_value(dict, key_path)
    keys = split(key_path, ".")
    result = get(dict, keys[1], nothing)

    for key in keys[2:end]
        if result === nothing
            break
        end
        result = get(result, key, nothing)
    end

    return result
end

"""
    func_from_string(fct_string::String)

Convert the provided string into a applicable function.

# Arguments
- `fct_string::String`: The function in string format.

# Returns
- `Function`: The parsed function.

"""
function func_from_string(fct_string::String)::Function
    func = eval(Meta.parse(fct_string))
    return x -> Base.invokelatest(func, x)
end


"""
    create_parameter_list(parameter)

Create a parameter list based on the input parameter dictionary. The parameter list can be provided
by either a list with the key `value` or an interval with the key `bounds` and the number of values
in the interval with the key `number`. In the latter case a function can be provided with the key 
`function` that is being applied to each of the generated parameter values to, e.g., change the shape 
of the parameter list.

Arguments:
- `parameter::Dict`: A dictionary containing information about a parameter.

Returns:
- `Vector`: A list of parameter values.
"""
function create_parameter_list(parameter::Dict)
    parameter_list = []
    # Check if parameters are given as a list
    if haskey(parameter, "values")
        parameter_list = parameter["values"]
    # Check if parameters are given as bounds and steps in inteval
    elseif haskey(parameter, "bounds") && haskey(parameter, "number")
        parameter_list = range(parameter["bounds"][1], parameter["bounds"][2], parameter["number"])
        # Check if additionally a function is provided for parameter manipulation
        if haskey(parameter, "function")
            func = func_from_string(parameter["function"])
            parameter_list = [x |> func for x in parameter_list]
        end
    else
        @warn "No parameter list generated for $(parameter["key"])"
    end
    
    return parameter_list
end

"""
    generate_combinations(parameters_dict)

Generate combinations of the provided parameter values. For each parameter a list of values is provided
in the parameters_dict. The resulting parameter combinations are all permutations of these values.

Arguments:
- `parameters_dict::Dict`: A dictionary containing parameter lists.

Returns:
- `Vector`: A vector of dictionaries, where each dictionary contains the parameter keys as keys and the value as an entry.
"""
function generate_combinations(parameters_dict)
    keyz = collect(keys(parameters_dict))
    values_list = [parameters_dict[k] for k in keyz]
    combinations = [Dict(keyz[i] => comb[i] for i in 1:length(keyz)) for comb in Iterators.product(values_list...)]
    return combinations
end

"""
    create_config_files(base_config, combinations, directory)

Create the individual configuration files based on combinations of parameters provided as a vector of dictionaries.
The files are being saved in the provided directory with the name `config_i` where i is an integer ranging from one
to the total number of provided combinations.

Arguments:
- `base_config::Dict`: A dictionary containing the base configuration.
- `combinations::Vector`: A vector of dictionaries representing combinations of parameter values.
- `directory::String`: The directory where the configuration files will be saved.

Returns:
- Nothing.
"""
function create_config_files(base_config, combinations, directory)
    paths = []

    if !isdir(directory)
        mkpath(directory)
    end

    # Check if there actually are any parameter variations
    # If not save the base config and add it to paths
    if length(combinations[1]) == 0
        open(joinpath(directory, "config.toml"), "w") do file
            TOML.print(file, base_config)
        end
        push!(paths, joinpath(directory, "config.toml"))
    # Otherwise create config files for all combinations
    else
        for (i, combination) in enumerate(combinations)
            config = deepcopy(base_config)
            for (param, value) in combination
                keys = split(param, ".")
                set_nested!(config, keys, value)
            end
            open(joinpath(directory, "config_$(i).toml"), "w") do file
                TOML.print(file, config)
            end
            push!(paths, joinpath(directory, "config_$(i).toml"))
        end
    end
    return paths
end

"""
    create_batch_configs(config_dict, base_config, directory)

Generates batch configurations. A folder `config` will be created in the directory provided as an
argument. In this folder the base_config file and the batch config will both be saved as TOML files.
The parametervariation will be saved as a parameter list in the batch config. In the `config` folder
a subfolder `files` will be created where for each parameterset a config file will be saved.  

Arguments:
- `batch_config::Dict`: A dictionary containing information about the batch parameters.
- `directory::String`: The directory where the configuration files will be saved.

Returns:
- `Array`: The file paths of the created config files.
"""
function create_batch_configs(batch_config::Dict, directory::String, base_config = nothing, bc_path = nothing)

    # Check if the base config is provided and parse it
    # It may be provided in the config file as a dict a string or a filepath
    if isnothing(base_config)
        if isa(batch_config["BatchParameters"]["base_config_file"], Dict)
            base_config = batch_config["BatchParameters"]["base_config_file"]
        elseif isa(batch_config["BatchParameters"]["base_config_file"], String)
            base_config = TOML.tryparse(batch_config["BatchParameters"]["base_config_file"])
            if !isa(base_config, Dict)
                if isfile(batch_config["BatchParameters"]["base_config_file"])
                    base_config = TOML.parsefile(batch_config["BatchParameters"]["base_config_file"])
                elseif !isnothing(bc_path) isfile(joinpath(bc_path |> dirname, batch_config["BatchParameters"]["base_config_file"]))
                    base_config = TOML.parsefile(joinpath(bc_path |> dirname, batch_config["BatchParameters"]["base_config_file"]))
                else
                    error("Base configuration '$base_config_file' was not properly provided.")
                end
            end
        else
            error("Base configuration '$base_config_file' was not properly provided.")
        end
    else
        try
            base_config = TOML.parsefile(base_config)
        catch e
            error("The provided filepath $base_config could not be parsed into a config file! An attempt resulted in $e .")
        end
    end

    # Remove potentially included seed from the config file
    delete!(base_config["Simulation"], "seed")

    # Create the directory for the config files
    if !isdir(joinpath(directory, "config"))
        mkdir(joinpath(directory, "config"))
    end

    # Save the base config as a file in the provided directory
    open(joinpath(directory, "config", "base_config.toml"), "w") do io
        TOML.print(io, base_config)
    end

    # Build the parameter dict from the provided config file
    parameters_dict = Dict()
    vp = []
    for parameter in get(batch_config["BatchParameters"], "VariedParameters", [])
        parameter_list = create_parameter_list(parameter)
        if !isempty(parameter_list)
            parameters_dict[parameter["key"]] = parameter_list
            push!(vp, Dict("key" => parameter["key"], "values" => parameter_list))
        end
    end

    batch_config["BatchParameters"]["VariedParameters"] = vp
    batch_config["BatchParameters"]["base_config_file"] = base_config
    # Save the batch config as a file in the provided directory
    open(joinpath(directory, "config", "batch_config.toml"), "w") do io
        TOML.print(io, batch_config)
    end

    # Determine all parameter combinations
    combinations = generate_combinations(parameters_dict)

    # Return a list of the filepaths of all the created config files
    return create_config_files(base_config, combinations, joinpath(directory, "config", "files"))
end

"""
    generate_batch_info(date, seeds, configfile, populationfile, directory)

Exports the batchinfo including the date, used seeds, configfile and population file. It is being saved in the provided directory as a json.
"""
function generate_batch_info(date::DateTime, seeds::Vector, configfile::String, populationfile::String, directory::String)
    out = Dict(
        "date" => date,
        "configfile" => TOML.parsefile(configfile),
        "seeds" => seeds,
        "populationfile" => populationfile
    )

    mkpath(directory)
    open(directory * "/batchinfo.json", "w") do file
        write(file, JSON.json(out))
        close(file)
    end
end
