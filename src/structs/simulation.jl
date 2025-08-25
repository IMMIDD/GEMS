###
### SIMULATION (TYPE DEFINITION & BASIC FUNCTIONALITY)
###
export StartCondition, StopCriterion
export InfectedFraction, PatientZero, PatientZeros
export TimesUp
export Simulation

export tick, label, start_condition, stop_criterion, settingscontainer, settings, population
export municipalities, households, schoolclasses, schoolyears, schools, schoolcomplexes, offices, departments, workplaces, workplacesites, individuals
export region_info
export pathogen, pathogen!
export configfile, populationfile
export evaluate
export initialize!
export increment!, reset!
export tickunit
export infectionlogger, deathlogger, testlogger, quarantinelogger, pooltestlogger, seroprevalencelogger, customlogger, customlogger!
export infections, tests, deaths, quarantines, pooltests, seroprevalencetests, customlogs, populationDF
export symptom_triggers, add_symptom_trigger!, tick_triggers, add_tick_trigger!, hospitalization_triggers, add_hospitalization_trigger!
export event_queue
export add_strategy!, strategies, add_testtype!, testtypes
export stepmod

export info

"supertype for all start conditions"
abstract type StartCondition end

"supertype for all stop criteria"
abstract type StopCriterion end

###
### SIMULATION STRUCT
###
"""
    Simulation

A struct for the management of a single run, holding all necessary informations.

# Fields
- Data Sources
    - `configfile::String`: Path to config file
- General
    - `tick::Int16`: Current tick/timestep
    - `tickunit::Char`: Time unit of one simulation step (tick)
    - `startdate::Date`: Start date of the simulation
    - `enddate::Date`: End date of the simulation
    - `start_condition::StartCondition`: Starting condition that sets the initial situation
    - `stop_criterion::StopCriterion`: Criterion that terminates a simulation run
    - `label::String`: Label for plot visualizations
- Model
    - `population::Population`: Container to hold all present individuals
    - `settings::SettingsContainer`: All settings present in the simulation
    - `pathogen::Pathogen`: The pathogen of which infections are simulated
- Logger
    - `infectionlogger::InfectionLogger`: A logger tracking all infections    
    - `deathlogger::DeathLogger`: A logger specifically for the deaths of individuals
    - `testlogger::TestLogger`: A logger tracking all individual tests
    - `pooltestlogger::PoolTestLogger`: A logger tracking all pool tests
    - `seroprevalencelogger::SeroprevalenceLogger`: A logger tracking all seroprevalence tests
    - `quarantinelogger::QuarantineLogger`: A tracking cumulative quarantines per tick
    - `customlogger::CustomLogger`: A logger running custom methods on the `Simulation` object in each tick
- Interventions
    - `symptom_triggers::Vector{ITrigger}`: List of all `SymptomTriggers`
    - `tick_triggers::Vector{TickTrigger}`: List of all `TickTriggers`
    - `hospitalization_triggers::Vector{ITrigger}`: List of all `HospitalizationTriggers`
    - `event_queue::EventQueue`: Event Queue to apply intervention measures
    - `strategies::Vector{Strategy}`: List of all registered intervention strategies
    - `testtypes::Vector{AbstractTestType}`: List of all `TestTypes` (e.g. Antigen- or PCR-Test)
- Runtime Modifiers
    - `stepmod::Function`: Single-argment function that runs custom code on the simulation object in each tick

"""
mutable struct Simulation 

    # data TODO check if config file needs to be adapted actually
    configfile::String

    # config
    tick::Int16
    tickunit::Char
    startdate::Date
    enddate::Date
    start_condition::StartCondition
    stop_criterion::StopCriterion
    label::String

    # model
    population::Population
    settings::SettingsContainer
    pathogen::Pathogen

    # logger
    infectionlogger::InfectionLogger
    deathlogger::DeathLogger
    testlogger::TestLogger
    pooltestlogger::PoolTestLogger
    seroprevalencelogger::SeroprevalenceLogger
    quarantinelogger::QuarantineLogger
    customlogger::CustomLogger

    # NPI trigger
    symptom_triggers::Vector{ITrigger}
    tick_triggers::Vector{TickTrigger}
    hospitalization_triggers::Vector{ITrigger}
    event_queue::EventQueue
    strategies::Vector{Strategy}
    testtypes::Vector{AbstractTestType}

    # StepMod
    stepmod::Function

    # inner default constructor
    function Simulation(
        configfile::String,
        tickunit::Char,
        startdate::Date,
        enddate::Date,
        start_condition::StartCondition,
        stop_criterion::StopCriterion,
        population::Population,
        settings::SettingsContainer,
        pathogen::Pathogen,
        stepmod::Function
    )
        sim = new(
            # config
            configfile,
            Int16(0), # tick
            tickunit,
            startdate,
            enddate,
            start_condition,
            stop_criterion,
            "Simulation " * string(GEMS.SIMS_INSTANTIATED + 1), # label

            # model
            population,
            settings,
            pathogen,

            # logger
            InfectionLogger(),
            DeathLogger(),
            TestLogger(),
            PoolTestLogger(),
            SeroprevalenceLogger(),
            QuarantineLogger(),
            CustomLogger(),

            # NPI trigger
            [],
            [],
            [],
            EventQueue(),
            [],
            [],

            # StepMod
            stepmod
        )

        # increase simulation counter
        global GEMS.SIMS_INSTANTIATED += 1
        return sim
    end

    

    function Simulation(;
        configfile::String = "",

        # common parameters
        tickunit = nothing,
        start_date = nothing,
        end_date = nothing,
        label = nothing,

        # population
        population = nothing,
        pop_size = nothing,
        avg_household_size = nothing,
        avg_office_size = nothing,
        avg_school_size = nothing,

        # settings
        global_setting = nothing,
        settingsfile = nothing,

        # start condition
        start_condition = nothing,
        infected_fraction = nothing,

        # stop criterion
        stop_criterion = nothing,

        # pathogen
        pathogen = nothing,
        transmission_function = nothing,
        transmission_rate = nothing,

        # stepmod
        stepmod::Function = x -> x
    )

        # parse the config file (or default to default.toml)
        config = load_configfile(configfile)

        # GLOBAL SETTING FLAG
        gs = determine_global_setting(config, global_setting)

        # START DATE
        sd = determine_start_date(config, start_date)

        # END DATE
        ed = determine_end_date(config, end_date)

        # TICK UNIT
        tu = determine_tick_unit(config, tickunit)

        # POPULATION
        pop, settings = determine_population_and_settings(
            config,
            population,
            gs,
            pop_size,
            avg_household_size,
            avg_office_size,
            avg_school_size,
            settingsfile
        )

        # SETTINGS
        determine_setting_config!(settings, config)

        # START CONDITION
        start_condition = determine_start_condition(
            config,
            start_condition,
            infected_fraction)

        # STOP CRITERION
        stop_criterion = determine_stop_criterion(
            config,
            stop_criterion)

        # PATHOGENS
        pathogen = determine_pathogen(
            config,
            pathogen,
            transmission_function,
            transmission_rate
        )

        # CREATES SIMULATION OBJECT
        sim = Simulation(
            configfile,
            tu,
            sd,
            ed,
            start_condition,
            stop_criterion,
            pop,
            settings,
            pathogen,
            stepmod
        )

        # update label
        sim.label = isnothing(label) ? sim.label : string(label)

        # initialize simulation
        initialize!(sim)

        return sim
    end


    Simulation(params::Dict) = Simulation(params...)
        
end


### DETERMINATION FUNCTIONS

function determine_start_date(configfile_params::Dict, start_date)
    # if start_date is provided, use it
    if !isnothing(start_date)
        !isa(start_date, Date) && throw(ArgumentError("Provided start_date must be an object of type Date!"))
        return start_date
    end

    # if no start date is provided, look it up in config file
    if !haspath(configfile_params, ["Simulation", "startdate"])
        @warn "Start date not found in config file and not provided as argument; defualting to today."
        return today()
    end

    sd = configfile_params["Simulation"]["startdate"]
    return Date(sd)
end

function determine_end_date(configfile_params::Dict, end_date)
    # if end_date is provided, use it
    if !isnothing(end_date)
        !isa(end_date, Date) && throw(ArgumentError("Provided end_date must be an object of type Date!"))
        return end_date
    end

    # if no end date is provided, look it up in config file
    if !haspath(configfile_params, ["Simulation", "enddate"])
        @warn "End date not found in config file and not provided as argument; defualting to today + 1 year."
        return today() + Year(1)
    end

    ed = configfile_params["Simulation"]["enddate"]
    return Date(ed)
end

function determine_tick_unit(configfile_params::Dict, tickunit)
    # if tickunit is provided, use it
    if !isnothing(tickunit)
        !isa(only(tickunit), Char) && throw(ArgumentError("Provided tickunit must be a single character!"))
        return only(tickunit)
    end

    # if no tick unit is provided, look it up in config file
    if !haspath(configfile_params, ["Simulation", "tickunit"])
        @warn "Tick unit not found in config file and not provided as argument; defualting to 'd'."
        return 'd'
    end

    tu = configfile_params["Simulation"]["tickunit"]
    !isa(only(tu), Char) && throw(ArgumentError("Tick unit must be a single character!"))
    return only(tu)
end


"""
    determine_start_condition(configfile_params::Dict, start_condition, infected_fraction)

Determines the start condition for the simulation based on the provided parameters.
If a `start_condition` is provided, it will be used.
If not, it will check for an `infected_fraction`.
If `infected_fraction` is provided, it will create an `InfectedFraction` start condition with the specified fraction and pathogen.
If neither is provided, it will return the default start condition from the config file.
"""
function determine_start_condition(configfile_params::Dict, start_condition, infected_fraction)
    # return configfile start condition if nothing else provided
    if isnothing(start_condition) && isnothing(infected_fraction)
        !haspath(configfile_params, ["Simulation", "StartCondition"]) && throw(ArgumentError("No start condition found in config file!"))
        return create_start_condition(configfile_params["Simulation"]["StartCondition"])
    end

    # if start_condition is provided, use it
    if !isnothing(start_condition)
        !isa(start_condition, StartCondition) && throw(ArgumentError("Provided start_condition must be an object of type StartCondition! Try any of $(join(subtypes(StartCondition), ", "))"))
        !isnothing(infected_fraction) && @warn "A start_condition was provided, therefore infected_fraction will be ignored."
        return start_condition
    end

    # if infected_fraction is provided, use it
    return InfectedFraction(
        fraction = infected_fraction,
        pathogen = ""
    )

end

"""
    determine_stop_criterion(configfile_params::Dict, stop_criterion)

Determines the stop criterion for the simulation based on the provided parameters.
If a `stop_criterion` is provided, it will be used.
Otherwise, it will return the default stop criterion from the config file.
"""
function determine_stop_criterion(configfile_params::Dict, stop_criterion)
    # return configfile stop criterion if nothing else provided
    if isnothing(stop_criterion)
        !haspath(configfile_params, ["Simulation", "StopCriterion"]) && throw(ArgumentError("No stop criterion found in config file!"))
        return create_stop_criterion(configfile_params["Simulation"]["StopCriterion"])
    end

    # if stop_criterion is provided, use it
    !isa(stop_criterion, StopCriterion) && throw(ArgumentError("Provided stop_criterion must be an object of type StopCriterion! Try any of $(join(subtypes(StopCriterion), ", "))"))
    return stop_criterion
end

function determine_pathogen(configfile_params::Dict, pathogen, transmission_function, transmission_rate)
    if !isnothing(pathogen)
        !isa(pathogen, Pathogen) && throw(ArgumentError("Provided pathogen must be an object of type Pathogen!"))
        
        # throw warnings for unused parameters
        !isnothing(transmission_rate) && @warn "A pathogen was provided, therefore transmission_rate will be ignored."
        
        return pathogen
    end

    # if no pathogen is provided, create one from config file parameters
    !haspath(configfile_params, ["Pathogens"]) && throw(ArgumentError("No pathogens found in config file!"))
    pg = create_pathogens(configfile_params["Pathogens"])[1]# TODO: allow multiple pathogens
    
    if !isnothing(transmission_function)
        !isa(transmission_function, TransmissionFunction) && throw(ArgumentError("Provided transmission_function must be an object of type TransmissionFunction!"))
        transmission_function!(pg, transmission_function)
        !isnothing(transmission_rate) && @warn "A transmission_function was provided, therefore transmission_rate will be ignored."
        return pg
    end

     # if a transmission rate is provided, set
    if !isnothing(transmission_rate)
        transmission_function!(pg, ConstantTransmissionRate(transmission_rate = transmission_rate))
    end
    
    return pg
end


function determine_global_setting(configfile_params::Dict, global_setting)
    # if global_setting is provided, use it
    if !isnothing(global_setting)
        !isa(global_setting, Bool) && throw(ArgumentError("global_setting flag must be a boolean value!"))
        return global_setting
    end

    # if global_setting flag is not provided, look it up in config file
    if !haspath(configfile_params, ["Simulation", "GlobalSetting"])
        @warn "Global setting not found in config file and not provided as argument; defualting to 'false'."
        return false
    end

    gs = configfile_params["Simulation"]["GlobalSetting"]
    !isa(gs, Bool) && throw(ArgumentError("global_setting flag must be a boolean value!"))
    return gs
end


function determine_population(population::String, settingsfile, global_setting)
    # if a path was provided, load the population from the file, otherwise assume it's a population identifier
    (pop_path, settings_path) = try
        is_pop_file(population) ? (population, settingsfile) : obtain_remote_files(population)
    catch
        throw(ArgumentError("Provided population must be a valid population file path or a population model identifier (e.g., 'DE')!"))
    end
    
    pop = Population(pop_path)
    settings, renaming = settings_from_population(pop, global_setting)

    # if settingsfile is provided, load the settings from the file
    if !isnothing(settings_path)
        !endswith(settings_path, ".jld2") && throw(ArgumentError("Provided settings file path does not point to a valid .jld2 file: $settings_path"))
        settings_from_jld2!(settings_path, settings, renaming)
    end

    return pop, settings
end


function determine_population_and_settings(configfile_params::Dict, population, global_setting, pop_size, avg_household_size, avg_office_size, avg_school_size, settingsfile)
    # if population is provided, use it    
    if !isnothing(population)
        # if a Population object is provided, use it
        if isa(population, Population)
            # throw warning if any other parameters were provided
            !all(isnothing, [pop_size, avg_household_size, avg_office_size, avg_school_size, settingsfile]) && @warn "A population object was provided, therefore pop_size, avg_household_size, avg_office_size, avg_school_size, and settingsfile will be ignored."
            settings, renaming = settings_from_population(population, global_setting)
            return population, settings
        end

        # throw exception if population is neither a string nor a Population object
        !isa(population, String) && throw(ArgumentError("Provided population must be a String path to a population file, a population identifier (e.g., 'DE') or Population object!"))
        # throw warning if any other parameters were provided
        !all(isnothing, [pop_size, avg_household_size, avg_office_size, avg_school_size]) && @warn "A population object was provided, therefore pop_size, avg_household_size, avg_office_size, and avg_school_size will be ignored."
            
        # if a population file path is provided, load the population from the file
        return determine_population(population, settingsfile, global_setting)
    end

    # if no population is provided, use the provided parameters
    # baseline is configfile parameters
    params = haskey(configfile_params, "Population") ? Dict{Symbol, Any}(prepare_kw_args(configfile_params["Population"])) : Dict{Symbol, Any}()
    # update kw args
    !isnothing(pop_size) && (params[:n] = pop_size)
    !isnothing(avg_household_size) && (params[:avg_household_size] = avg_household_size)
    !isnothing(avg_office_size) && (params[:avg_office_size] = avg_office_size)
    !isnothing(avg_school_size) && (params[:avg_school_size] = avg_school_size)

    # create population object
    pop = Population(; params...)
    settings, renaming = settings_from_population(pop, global_setting)
    return pop, settings
end


function determine_setting_config!(stngs::SettingsContainer, configfile_params::Dict)
    # if no settings are provided, look them up in config file
    if !haspath(configfile_params, ["Settings"])
        @warn "No setting parameters found in config file; using default global setting only. This might cause 0 contacts and no infections."
        return
    end

    load_setting_attributes!(stngs, configfile_params["Settings"])
end



### CREATOR FUNCTIONS

function create_distribution(params::Dict)
    # find the distribution type in the parameters
    dist_type = GEMS.get_subtype(params["distribution"], Distribution)
    return dist_type(params["parameters"]...)

end

function create_progression_parameter(params::Union{Dict, Real})
    # If parameter is a dictionary, we assume it describes a distribution
    # Otherwise, we assume it is a single value
    return isa(params, Dict) ? create_distribution(params) : params
end

function create_progression(params::Dict, category::String)
    # convert parameters to keyword arguments
    kw_args = Dict(Symbol(k) => create_progression_parameter(v) for (k, v) in params)
    # create the progression category using the keyword arguments
    return GEMS.get_subtype(category, ProgressionCategory)(;kw_args...)
end

function create_progression_assignment(params::Dict)
    pa_type = GEMS.get_subtype(params["type"], ProgressionAssignmentFunction)
    kw_args = Dict(Symbol(k) => v for (k, v) in params["parameters"])
    return pa_type(;kw_args...)
end

function create_transmission_function(params::Dict)
    tf_type = GEMS.get_subtype(params["type"], TransmissionFunction)
    kw_args = Dict(Symbol(k) => v for (k, v) in params["parameters"])
    return tf_type(;kw_args...)
end

function create_pathogen(params::Dict, name, id)

    # create progressions
    progressions = [create_progression(pars, category) for (category, pars) in params["progressions"]]

    # create progression assignment
    pa = create_progression_assignment(params["progression_assignment"])

    # create transmission function
    tf = create_transmission_function(params["transmission_function"])

    return Pathogen(
        id = id,
        name = name,
        progressions = progressions,
        progression_assignment = pa,
        transmission_function = tf
    )
end

function create_pathogens(params::Dict)
    pathogens = []
    for (pathogen_name, pathogen_params) in params
        # create pathogen
        p = create_pathogen(pathogen_params, pathogen_name, length(pathogens) + 1)
        push!(pathogens, p)
    end

    # check if at least one pathogen was created
    length(pathogens) == 0 && throw(ArgumentError("No pathogens were found in the config file!"))
    return pathogens
end


function create_start_condition(params::Dict)
    sc_type = get_subtype(params["type"], StartCondition)
    kw_args = Dict(Symbol(k) => v for (k, v) in params["parameters"])
    return sc_type(;kw_args...)
end

function create_stop_criterion(params::Dict)
    sc_type = get_subtype(params["type"], StopCriterion)
    kw_args = Dict(Symbol(k) => v for (k, v) in params["parameters"])
    return sc_type(;kw_args...)
end

### FILE LOADERS


"""
    load_configfile(path::String)

Loads a config file from the specified path.
If no path is provided, it defaults to the `GEMS.DEFAULT_CONFIGFILE`.
"""
function load_configfile(path::String)
    
    # if no file path is provided, use the default config file
    if isempty(path)
        basefolder = dirname(dirname(pathof(GEMS)))
        #default_configfile = GEMS.DEFAULT_CONFIGFILE # "data/DefaultConf.toml"
        default_configfile = "data/DefaultConf.toml"
        default_configfile_path = joinpath(basefolder, default_configfile)
        return TOML.parsefile(default_configfile_path)
    else
        !isfile(path) && throw(ArgumentError("Provided config file path does not point to a valid file: $path"))
        !is_toml_file(path) && throw(ArgumentError("Provided config file path does not point to a valid .toml file: $path"))    
        return TOML.parsefile(path)
    end

end

### Helper Methods to set up parts of the simulation:

"""
    is_toml_file(filename::String)

Function to check if the provided file is a .toml file
"""
function is_toml_file(filename::String)
    return endswith(filename, ".toml")
end

"""
    is_pop_file(filename::String)

Function to check if the file ends with one of the endings identifying it as a population file (.csv and .jld2).
"""
function is_pop_file(filename::String)
    return endswith(filename, ".csv") || endswith(filename, ".jld2")
end


"""
    validate_file_paths(population_path::String, settings_path::String)

Checks if the paths to the settings and popualtion files differ to throw a warning if there is a mismatch indicating an error
"""
function validate_file_paths(population_path::String, settings_path::String)
    # Extract the directories from the file paths
    population_dir = dirname(population_path)
    settings_dir = dirname(settings_path)
    
    # Check if the directories are different
    if population_dir != settings_dir
        @warn "The population file and settings file are in different directories." *
              "\nPopulation file directory: $population_dir" *
              "\nSettings file directory: $settings_dir" *
              "\nEnsure that the settings file corresponds to the population file to avoid mismatches."
    end
end


"""
    load_setting_attributes!(stngs::SettingsContainer, attributes::Dict)

Loads the `Settings` from the `Simulation` config parameters.
"""
function load_setting_attributes!(stngs::SettingsContainer, attributes::Dict)

    for (type, setting_list) in settings(stngs)
        # for every setting type we assign the given attributes
        if structname(type) in keys(attributes)
            setting_attributes = attributes[structname(type)] # structnames() handles types like "GEMS.Houshold" that occur, if GEMS is loaded within another scope/package
            # for every provided key, we set the corresponding field
            for (key, value) in setting_attributes
                if Symbol(key) in fieldnames(type)
                    
                    # NOTE: This must be checked before "value" is converted, as in this case "value" equals to a Dict and can't be directly converted to a "ContactSamplingMethod"
                    # handle "ContactSamplingMethod"s in an extra step
                    # strings in the configfile must be matched exactly
                    if (key == "contact_sampling_method")
                        # create specific instance of "ContactSamplingMethod" from Dict
                        sampling_method = create_contact_sampling_method(value)
                        for s in setting_list
                            # set fitting value and convert it to the correct type
                            setfield!(s, Symbol(key), sampling_method)
                        end
                    else
                        value = convert(fieldtype(type, Symbol(key)), value)
                        for s in setting_list
                            # set fitting value and convert it to the correct type
                            setfield!(s, Symbol(key), value)
                        end
                    end
                else
                    @warn "Provided key not compatible with type" key type
                end
            end
        end
    end
end


"""
    initialize_seed(x::Int64)

Creates a random value based on the seed provided
"""
function initialize_seed(x::Int64)
    return Random.seed!(x)
end

"""
    obtain_remote_files(identifier::String; forcedownload::Bool = false)

Interface to remotely access a setting and population file
"""
function obtain_remote_files(identifier::String; forcedownload::Bool = false)

    printinfo("\u2514 Looking for \"$identifier\" population model")

    # if argument points to existing population and setting files and forcedownload is deactivated
    if peoplelocal(identifier) |> isfile && settingslocal(identifier) |> isfile && !forcedownload
        printinfo("\u2514 Retrieving population and settings from $(poplocal(identifier))")
        return (peoplelocal(identifier) , settingslocal(identifier))
    end

    # if not, download files
    printinfo("Population and setting file not available locally. Downloading files...")
    zipath = joinpath(poplocal(identifier), "data.zip")
    # make sure directory exists
    mkpath(dirname(zipath))
    # download stuff
    
    try 
        urldownload(popurl(identifier), true;
            compress = :none,
            parser = x -> nothing,
            save_raw = zipath)
        printinfo("Unpacking ZIP file")
    catch e
        throw("Attempted to download remote population `$(identifier)`. Data could not be downloaded. Are you sure the data is available at $(popurl(identifier))?")
    end

    # unzip
    z = ZipFile.Reader(zipath)
    for f in z.files
        # Determine the output file path
        out_path = joinpath(poplocal(identifier), f.name)
        
        # Ensure that the output directory exists
        mkpath(dirname(out_path))
        
        # Open the output file for writing
        open(out_path, "w") do io
            # Write the uncompressed data to the output file
            write(io, read(f))
        end
    end

    # Close the ZIP archive to free resources
    close(z)

    # remove temporary zipfile
    rm(zipath, force = true)

    # return local data paths
    return (peoplelocal(identifier) , settingslocal(identifier))       
end

### INTERFACE FOR CONDITION AND CRITERIA ###

# TODO REMOVE
"""
    initialize!(simulation, condition)

Initializes the simulation model according to a provided start condition.
    This is an 'abstract' function that must be implemented for concrete start condition types.
"""
function initialize!(simulation::Simulation, condition::StartCondition)
    error("`initialize!` not implemented for start condition "
        *string(typeof(condition)))
end

"""
    evaluate(simulation, criterion)

Evaluates whether the specified stop criterion is met for the simulation model. 
    Return `True` if criterion was met.
    This is an 'abstract' function that must be implemented for concrete criterion types.
"""
function evaluate(simulation::Simulation, criterion::StopCriterion)
    error("`evaluate` not implemented for stop criterion "
        *string(typeof(criterion)))
end




### GETTERS & SETTERS
"""
    configfile(simulation)

Returns configfile that was used to initialize simulation.
"""
function configfile(simulation::Simulation)
    return simulation.configfile
end

"""
    populationfile(simulation)

Returns populationfile that was used to initialize simulation.
"""
function populationfile(simulation::Simulation)
    return simulation |> population |> populationfile
end

"""
    tick(simulation)

Returns current tick of the simulation run.
"""
function tick(simulation::Simulation)
    return simulation.tick
end

"""
    label(simulation::Simulation)

Returns simulation object's string label.
"""
function label(simulation::Simulation)
    return simulation.label
end

"""
    tickunit(simulation)

Returns the unit of the ticks as a char like in date formats,
i.e. 'd' means days, 'h' mean hours, etc.
"""
function tickunit(simulation::Simulation)::String
    ut = simulation.tickunit
    if ut == 'y'
        return "year"
    elseif ut == 'm'
        return "month"
    elseif ut == 'd'
        return "day"
    elseif ut == 'w'
        return "week"
    elseif ut == 'h'
        return "hour"
    elseif ut == 'M'
        return "minute"
    elseif ut == 'S'
        return "second"
    else
        return "tick"
    end
end

"""
    start_condition(simulation)

Returns start condition associated with the simulation run.
"""
function start_condition(simulation::Simulation)
    return simulation.start_condition
end

"""
    stop_criterion(simulation)

Returns stop criterion associated with the simulation run.
"""
function stop_criterion(simulation::Simulation)
    return simulation.stop_criterion
end


"""
    population(simulation)

Returns the population associated with the simulation run.
"""
function population(simulation::Simulation)
    return simulation.population
end

"""
    populationDF(simulation::Simulation)

Calls the `dataframe()` function on the simulation's `Population object`.
"""
populationDF(simulation::Simulation) = simulation |> population |> dataframe

###
### SETTINGS
###

"""
    settingscontainer(simulation::Simulation)

Returns the container object of all settings of the simulation.
"""
function settingscontainer(simulation::Simulation)::SettingsContainer
    return simulation.settings
end

"""
    settings(simulation::Simulation)

Returns a dictionary containing all settings, separated by setting type (key).
"""
function settings(simulation::Simulation)
    return simulation |> settingscontainer |> settings
end

"""
    settings(simulation::Simulation, settingtype::DataType)

Returns all settings of `settingtype` of the simulation.
"""
function settings(simulation::Simulation, settingtype::DataType)::Union{Vector{Setting}, Nothing}
    # TODO: The function return is not type safe. Should be replaced with 
    # commented function above (but needs to fix tests then)
    return get(settingscontainer(simulation), settingtype)
end


municipalities(sim::Simulation) = settings(sim, Municipality)
households(sim::Simulation) = settings(sim, Household)

schoolclasses(sim::Simulation) = settings(sim, SchoolClass)
schoolyears(sim::Simulation) = settings(sim, SchoolYear)
schools(sim::Simulation) = settings(sim, School)
schoolcomplexes(sim::Simulation) = settings(sim, SchoolComplex)

offices(sim::Simulation) = settings(sim, Office)
departments(sim::Simulation) = settings(sim, Department)
workplaces(sim::Simulation) = settings(sim, Workplace)
workplacesites(sim::Simulation) = settings(sim, WorkplaceSite)

individuals(sim::Simulation) = sim |> population |> individuals

"""
    region_info(sim::Simulation)

Returns a `DataFrame` containing information about the 
`Municipality`s in the model with the following columns:

| Name         | Type      | Description                                                                  |
| :----------- | :-------- | :--------------------------------------------------------------------------- |
| `ags`        | `AGS`     | Amtlicher Gemeindeschlüssel (Community Identification Code)                  |
| `pop_size`   | `Int64`   | Number of individuals in that municipality                                   |
| `area`       | `Float64` | Area size of this municipality in km²                                        |

Note: This function will download the Germany shapefile, if it's not available locally,
and return `missing` values for `pop_size` and `area` if the download cannot be completed.
"""
function region_info(sim::Simulation)

    muns = sim |> municipalities
    isnothing(muns) ? muns = [] : nothing

    # try to load Germany shapefile. If it doesn't work,
    # return a dataframe with municipalities and missing pop_size data
    gshps = try
         germanshapes(3)
    catch e
        @warn "region_info() failed to obtain information with the following error: $e"
        return DataFrame(
            ags = ags.(muns),
            pop_size = fill(missing, length(muns)),
            area = fill(missing, length(muns)))
    end

    return DataFrame(
            ags = ags.(muns),
            pop_size = size.(muns)) |>
        x -> leftjoin(x, 
                # load shapefile to join dataframe with
                gshps |>
                    y -> DataFrame(
                        ags = AGS.(y.AGS_0),
                        area = y.KFL) |>
                    # there are duplicates in the AGS of the shapefile. We take the ones with the biggest area
                    y -> groupby(y, :ags) |>
                    y -> combine(y, :area => maximum => :area), # Katasterfläche
                on = :ags) 
end

###
### PATHOGEN
###

"""
    pathogen(simulation)

Returns the pathogen of the simulation.
"""
function pathogen(simulation::Simulation)::Pathogen
    return simulation.pathogen
end


"""
    pathogen!(simulation, pathogen)

Sets the pathogen of the simulation.
"""
function pathogen!(simulation::Simulation, pathogen::Pathogen)
    simulation.pathogen = pathogen
end



"""
    infectionlogger(simulation)

Returns the InfectionLogger of the simulation.
"""
function infectionlogger(simulation::Simulation)::InfectionLogger
    return simulation.infectionlogger
end

"""
    infections(simulation::Simulation)

Calls the `dataframe()` function on the internal simulation's `InfectionLogger`.
"""
infections(simulation::Simulation) = simulation |> infectionlogger |> dataframe
    

"""
    deathlogger(simulation)

Returns the `DeathLogger` of the simulation.
"""
function deathlogger(simulation::Simulation)::DeathLogger
    return simulation.deathlogger
end

"""
    deaths(simulation::Simulation)

Calls the `dataframe()` function on the internal simulation's `DeathLogger`.
"""
deaths(simulation::Simulation) = simulation |> deathlogger |> dataframe

"""
    testlogger(simulation)

Returns the `TestLogger` of the simulation.
"""
function testlogger(simulation::Simulation)::TestLogger
    return simulation.testlogger
end

"""
    tests(simulation::Simulation)

Calls the `dataframe()` function on the internal simulation's `TestLogger`.
"""
tests(simulation::Simulation) = simulation |> testlogger |> dataframe

"""
    pooltestlogger(simulation)

Returns the `PoolTestLogger` of the simulation.
"""
function pooltestlogger(simulation::Simulation)::PoolTestLogger
    return simulation.pooltestlogger
end

"""
    pooltests(simulation::Simulation)

Calls the `dataframe()` function on the internal simulation's `PoolTestLogger`.
"""
pooltests(simulation::Simulation) = simulation |> pooltestlogger |> dataframe

"""
    seroprevalencelogger(simulation)

Returns the `SeroprevalenceLogger` of the simulation.
"""
function seroprevalencelogger(simulation::Simulation)::SeroprevalenceLogger
    return simulation.seroprevalencelogger
end

"""
    seroprevalencetests(simulation::Simulation)

Calls the `dataframe()` function on the internal simulation's `SeroprevalenceLogger`.
"""
seroprevalencetests(simulation::Simulation) = simulation |> seroprevalencelogger |> dataframe

"""
    quarantinelogger(simulation)

Returns the `QuarantineLogger` of the simulation.
"""
function quarantinelogger(simulation::Simulation)::QuarantineLogger
    return simulation.quarantinelogger
end

"""
    quarantines(simulation::Simulation)

Calls the `dataframe()` function on the internal simulation's `QuarantineLogger`.
"""
quarantines(simulation::Simulation) = simulation |> quarantinelogger |> dataframe

"""
    customlogger!(simulation, customlogger)

Sets the Simulation's `CustomLogger`.
"""
function customlogger!(simulation::Simulation, customlogger::CustomLogger)
    simulation.customlogger = customlogger
end

"""
    customlogger(simulation)

Returns the `CustomLogger` of the simulation.
"""
function customlogger(simulation::Simulation)::CustomLogger
    return simulation.customlogger
end

"""
    customlogs(simulation::Simulation)

Calls the `dataframe()` function on the internal simulation's `CustomLogger`.
"""
customlogs(simulation::Simulation) = simulation |> customlogger |> dataframe


### LOGIC

"""
    increment!(simulation)

Increments the current simulation's tick counter by 1.
"""
function increment!(simulation::Simulation)
    simulation.tick += 1
end

"""
    reset!(simulation)

Resets the current simulation's tick counter to 0.
"""
function reset!(simulation::Simulation)
    simulation.tick = 0
end

### INITALIZATION
"""
    initialize!(simulation)

Initializes the simulation model with a provided start condition.
"""
function initialize!(simulation::Simulation)
    initialize!(simulation, start_condition(simulation))
end

###
### INTERVENTIONS
###

"""
    add_symptom_trigger!(simulation, trigger)

Adds a `SymptomTrigger` to the simulation.
"""
function add_symptom_trigger!(simulation::Simulation, trigger::ITrigger)
    push!(simulation.symptom_triggers, trigger)
end

"""
    symptom_triggers(simulation)

Returns the list of `SymptomTrigger`s registered in the simulation.
"""
function symptom_triggers(simulation::Simulation)
    return(simulation.symptom_triggers)
end

"""
    add_tick_trigger!(simulation, trigger)

Adds a `TickTrigger` to the simulation.
"""
function add_tick_trigger!(simulation::Simulation, trigger::TickTrigger)
    push!(simulation.tick_triggers, trigger)
end

"""
    tick_triggers(simulation)

Returns the list of `TickTrigger`s registered in the simulation.
"""
function tick_triggers(simulation::Simulation)
    return(simulation.tick_triggers)
end

"""
    add_hospitalization_trigger!(simulation, trigger)

Adds a `HospitalizationTrigger` to the simulation.
"""
function add_hospitalization_trigger!(simulation::Simulation, trigger::ITrigger)
    push!(simulation.hospitalization_triggers, trigger)
end

"""
    hospitalization_triggers(simulation)

Returns the list of `HospitalizationTrigger`s registered in the simulation.
"""
function hospitalization_triggers(simulation::Simulation)
    return(simulation.hospitalization_triggers)
end

"""
    event_queue(simulation)

Returns the simulation's intervention event queue.
"""
function event_queue(simulation::Simulation)
    return(simulation.event_queue) 
end

"""
    add_strategy!(simulation, strategy)

Adds an intervention `Strategy` to the simulation object.
A strategy must be added to the simulation object to make it appear in the report.
In order to execute a strategy during the simulation run, you 
must define a `Trigger` and link this strategy. Just adding it here 
will not execute the strategy.
"""
function add_strategy!(simulation::Simulation, strategy::Strategy)
    push!(simulation.strategies, strategy)
end

"""
    strategy(simulation)

Returns the intervention `Strategy`s registered in the simulation.
"""
function strategies(simulation::Simulation)
    return(simulation.strategies)
end

"""
    add_testtype!(simulation, testtype)

Adds a test type to the simulation.
"""
function add_testtype!(simulation::Simulation, testtype::AbstractTestType)
    push!(simulation.testtypes, testtype)
end

"""
    testtypes(simulation)

Returns the test types registered in the simulation.
"""
function testtypes(simulation::Simulation)
    return(simulation.testtypes)
end

"""
    stepmod(simulation::Simulation)

Returns the defined step mod.
"""
function stepmod(simulation::Simulation)
    return(simulation.stepmod)
end


###
### PRINTING
###

"""
    info(sim::Simulation)

Summary output for `Simulation` object configuration.
"""
function info(sim::Simulation)

    #TODO this function throws a duplicate definition warning
    # probably due to the usage of @with_kw. But as we plan
    # to remove that anyway, we will not touch it for now.
    res = "Simulation [$(sim |> label)] (current $(sim |> tickunit): $(sim |> tick))\n"

    res *= "\u2514 Config File: $(sim |> configfile)\n"
    res *= "\u2514 Population File: $(sim |> population |> populationfile)\n"

    res *= "\u2514 Population ($(sim |> population |> size) individuals):\n"
    for st in settingtypes(settingscontainer(sim))
        res *= "  \u2514 $(st)s: $(settings(sim, st) |> length)\n"
    end

    res *= "\u2514 Start Condition: $(sim |> start_condition)\n"
    res *= "\u2514 Stop Criterion: $(sim |> stop_criterion |> typeof)\n"
    
    # pathogen
    res *= "\u2514 Pathogen: $(sim |> pathogen |> name)\n"
    res *= "  \u2514 Transmission Function: $(sim |> pathogen |> transmission_function)\n"
    res *= "  \u2514 Onset of Symptoms: $(sim |> pathogen |> onset_of_symptoms)\n"
    res *= "  \u2514 Infectiousness Offset: $(sim |> pathogen |> infectious_offset)\n"
    res *= "  \u2514 Time to Recovery: $(sim |> pathogen |> time_to_recovery)\n"

    res *= "  \u2514 Onset of Severeness: $(sim |> pathogen |> onset_of_severeness)\n"

    res *= "  \u2514 Hospitalization Rate: $(sim |> pathogen |> hospitalization_rate)\n"
    res *= "  \u2514 Time to Hospitalization: $(sim |> pathogen |> time_to_hospitalization)\n"
    res *= "  \u2514 Length of Stay: $(sim |> pathogen |> length_of_stay)\n"

    res *= "  \u2514 ICU rate: $(sim |> pathogen |> icu_rate)\n"
    res *= "  \u2514 Time to ICU: $(sim |> pathogen |> time_to_icu)\n"
    res *= "  \u2514 Ventilation Rate: $(sim |> pathogen |> ventilation_rate)\n"

    res *= "  \u2514 Mild Death Rate: $(sim |> pathogen |> mild_death_rate)\n"
    res *= "  \u2514 Severe Death Rate: $(sim |> pathogen |> severe_death_rate)\n"
    res *= "  \u2514 Critical Death Rate: $(sim |> pathogen |> critical_death_rate)\n"

    res *= "  \u2514 Disease Progression Stratification...\n"


    

    if sim |> strategies |> length > 0
        res *= "\u2514 Intervention Strategies: \n"
        for st in sim |> strategies
            res *= "  \u2514 $(name(st)) ($(st |> measures |> length) measures) \n"
        end
    else
        res *= "\u2514 No Intervention Strategies\n"
    end

    tr_num = (sim |> symptom_triggers |> length) +
        (sim |> hospitalization_triggers |> length) +
        (sim |> tick_triggers |> length)
    
    tr_num > 0 ? res *= "\u2514 Intervention Triggers: $tr_num\n" : res *= "\u2514 No Intervention Triggers\n"

    res *= "\u2514 Loggers:\n"
    res *= "  \u2514 Infections: $(sim |> infectionlogger |> length)\n"
    res *= "  \u2514 Deaths: $(sim |> deathlogger |> length)\n"
    res *= "  \u2514 Tests: $(sim |> testlogger |> length)\n"
    res *= "  \u2514 Pooltests: $(sim |> pooltestlogger |> length)\n"
    res *= "  \u2514 Seroprevalencetests: $(sim |> seroprevalencelogger |> length)\n"

    println(res)
end


"""
    Base.show(io::IO, sim::Simulation)

Standard console output for `Simulation` objects.
For more comprehensive information use `info(sim)`.
"""
function Base.show(io::IO, sim::Simulation)
    res = "Simulation [$(sim |> label)] ($(sim |> population |> size) individuals; current $(sim |> tickunit): $(sim |> tick))\n"
    write(io, res)
end