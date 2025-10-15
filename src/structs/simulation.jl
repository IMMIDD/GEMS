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
export statelogger, statelogger!, states
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

# Initialization

    Simulation(; kwargs...)
    Simulation(params::Dict)

You can initialize a simulation without any parameters, which will then use the default configuration file.
Providing any additional keyword arguments will override the respective configuration file parameter.
If you provide a custom config file, the parameters in the config file will be used as defaults and only the provided keyword arguments will override them.

Here's a list of all available parameters:

| Parameter                 | Type                               | Description                                                                                                                                                                       |
| :------------------------ | :--------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `configfile`              | `String`                           | Path to the configuration file. If not provided, the default configuration will be used.                                                                                          |
| `tickunit`                | `Char`                             | Time unit of one simulation step (tick). Must be one of 'h' (hours), 'd' (days), or 'w' (weeks).                                                                                  |
| `start_date`              | `Date`                             | Start date of the simulation.                                                                                                                                                     |
| `end_date`                | `Date`                             | End date of the simulation.                                                                                                                                                       |
| `label`                   | `String`                           | Label used for plot visualizations and aggregating simulations into batches.                                                                                                      |
| `population`              | `String` or `Population`           | Path to a population file, a population identifier (e.g., 'DE'), or a `Population` object.                                                                                        |
| `pop_size`                | `Int`                              | Size of the population to be created. Will be ignored if a `population` is provided.                                                                                              |
| `avg_household_size`      | `Float`                            | Average household size for the population to be created. Will be ignored if a `population` is provided.                                                                           |
| `avg_office_size`         | `Float`                            | Average office size for the population to be created. Will be ignored if a `population` is provided.                                                                              |
| `avg_school_size`         | `Float`                            | Average school size for the population to be created. Will be ignored if a `population` is provided.                                                                              |
| `global_setting`          | `Bool`                             | Flag indicating whether to use the global setting.                                                                                                                                |
| `settingsfile`            | `String`                           | Path to a settings file.                                                                                                                                                          |
| `household_contacts`      | `ContactSamplingMethod` or `Float` | Method for sampling household contacts or a fixed value that will be regarded as the expected value of a Poisson distribution.                                                    |
| `office_contacts`         | `ContactSamplingMethod` or `Float` | Method for sampling office contacts or a fixed value that will be regarded as the expected value of a Poisson distribution.                                                       |
| `department_contacts`     | `ContactSamplingMethod` or `Float` | Method for sampling department contacts or a fixed value that will be regarded as the expected value of a Poisson distribution.                                                   |
| `workplace_contacts`      | `ContactSamplingMethod` or `Float` | Method for sampling workplace contacts or a fixed value that will be regarded as the expected value of a Poisson distribution.                                                    |
| `workplace_site_contacts` | `ContactSamplingMethod` or `Float` | Method for sampling workplace site contacts or a fixed value that will be regarded as the expected value of a Poisson distribution.                                               |
| `school_class_contacts`   | `ContactSamplingMethod` or `Float` | Method for sampling school class contacts or a fixed value that will be regarded as the expected value of a Poisson distribution.                                                 |
| `school_year_contacts`    | `ContactSamplingMethod` or `Float` | Method for sampling school year contacts or a fixed value that will be regarded as the expected value of a Poisson distribution.                                                  |
| `school_contacts`         | `ContactSamplingMethod` or `Float` | Method for sampling school contacts or a fixed value that will be regarded as the expected value of a Poisson distribution.                                                       |
| `school_complex_contacts` | `ContactSamplingMethod` or `Float` | Method for sampling school complex contacts or a fixed value that will be regarded as the expected value of a Poisson distribution.                                               |
| `municipality_contacts`   | `ContactSamplingMethod` or `Float` | Method for sampling municipality contacts or a fixed value that will be regarded as the expected value of a Poisson distribution.                                                 |
| `global_setting_contacts` | `ContactSamplingMethod` or `Float` | Method for sampling global setting contacts or a fixed value that will be regarded as the expected value of a Poisson distribution. Requires `global_setting` to be true.         |
| `start_condition`         | `StartCondition`                   | A `StartCondition` object defining the initial situation of the simulation.                                                                                                       |
| `infected_fraction`       | `Float`                            | Fraction of the population to be initially infected. Will be ignored if a `start_condition` is provided.                                                                          |
| `stop_criterion`          | `StopCriterion`                    | A `StopCriterion` object defining the termination condition of the simulation.                                                                                                    |
| `pathogen`                | `Pathogen`                         | A `Pathogen` object defining the pathogen to be simulated.                                                                                                                        |
| `transmission_function`   | `TransmissionFunction`             | A `TransmissionFunction` object defining the transmission dynamics of the pathogen. Will be ignored if a `pathogen` is provided.                                                  |
| `transmission_rate`       | `Float`                            | A fixed transmission rate that will be used to create a `ConstantTransmissionRate` transmission function. Will be ignored if a `pathogen` or `transmission_function` is provided. |
| `stepmod`                 | `Function`                         | A single-argument function that runs custom code on the simulation object in each tick.                                                                                           |

# Examples

```julia
# Initialize a simulation with default configuration
sim = Simulation()

# Initialize a simulation with a custom configuration file
sim = Simulation(configfile="path/to/configfile.toml")

# Initialize a simulation with custom parameters
sim = Simulation(
    tickunit='d',
    label="My Simulation",
    avg_household_size=5,
)

# Initialize a simulation with a predefined population model
sim = Simulation(population="SH") # Schleswig-Holstein, Germany

# Initialize a simulation with a custom population file
sim = Simulation(population="path/to/populationfile.csv")

# Initialize a simulation with a custom start condition
sim = Simulation(start_condition=PatientZero()) # starts with a single infected individual

# Initialize a simulation with a custom transmission rate
sim = Simulation(transmission_rate=0.1) # sets a constant per-contact transmission rate (chance) of 0.1

# Initialize a simulation with a parameter dictionary
params = Dict(
    :tickunit => 'd',
    :label => "My Simulation",
    :avg_household_size => 5,
)
sim = Simulation(params)
```

# Internal Simulation Struct Fields

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
    statelogger::StateLogger
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
            StateLogger(),
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

    # outer constructor with keyword arguments
    # wrapper to _BUILD_Simulation
    function Simulation(; params...)
        # check if all parameters are known to _BUILD_Simulation
        validkeys = methods(GEMS._BUILD_Simulation) |> first |> Base.kwarg_decl
        errs = setdiff(keys(params), validkeys)
        length(errs) > 0 && throw(ArgumentError("Unknown keyword arguments provided to Simulation: $(join(errs, ", ")).\n\nValid arguments are: $(join(validkeys, ", "))"))

        # determine config file
        params = (; params..., configfile = haskey(params, :configfile) ? params[:configfile] : "")

        # determine other parameters
        passed_params = setdiff(keys(params), [:configfile])

        cnfg = isempty(params[:configfile]) ? "with default configuration" : "from $(params[:configfile])"
        prms = length(passed_params) > 0 ? " and additional parameter(s): $(join(passed_params, ", "))" : ""

        printinfo("Initializing Simulation $cnfg$prms")
        return _BUILD_Simulation(; params...)
    end

    # constructor from dictionary
    Simulation(params::Dict) = Simulation(;params...)

        
end

function _BUILD_Simulation(;
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

        # contacts
        household_contacts = nothing,
        office_contacts = nothing,
        department_contacts = nothing,
        workplace_contacts = nothing,
        workplace_site_contacts = nothing,
        school_class_contacts = nothing,
        school_year_contacts = nothing,
        school_contacts = nothing,
        school_complex_contacts = nothing,
        municipality_contacts = nothing,
        global_setting_contacts = nothing,

        
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

        # everything after this is just generating, not loading from disk
        printinfo("\u2514 Creating simulation object")

        # START DATE
        sd = determine_start_date(config, start_date)

        # END DATE
        ed = determine_end_date(config, end_date)

        # TICK UNIT
        tu = determine_tick_unit(config, tickunit)

        # SETTINGS & CONTACTS
        determine_setting_config!(settings, config,
            household_contacts = household_contacts,
            office_contacts = office_contacts,
            department_contacts = department_contacts,
            workplace_contacts = workplace_contacts,
            workplace_site_contacts = workplace_site_contacts,
            school_class_contacts = school_class_contacts,
            school_year_contacts = school_year_contacts,
            school_contacts = school_contacts,
            school_complex_contacts = school_complex_contacts,
            municipality_contacts = municipality_contacts,
            global_setting_contacts = global_setting_contacts)

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
        sim.label = isnothing(label) || isempty(label) ? sim.label : string(label)

        # initialize simulation
        initialize!(sim)

        return sim
    end


### DETERMINATION FUNCTIONS

"""
    determine_start_date(configfile_params::Dict, start_date)

Determines the start date for the simulation based on the provided parameters.
If a `start_date` is provided, it will be used.
If not, it will look for a `startdate` in the config file.
If neither is found, it will default to today.
"""
function determine_start_date(configfile_params::Dict, start_date)
    # if start_date is provided, use it
    if !isnothing(start_date)
        !isa(start_date, Date) && !isa(start_date, String) && throw(ArgumentError("Provided start_date must be an object of type Date!"))
        return Date(start_date)
    end

    # if no start date is provided, look it up in config file
    if !haspath(configfile_params, ["Simulation", "startdate"])
        @warn "Start date not found in config file and not provided as argument; defualting to today."
        return today()
    end

    sd = configfile_params["Simulation"]["startdate"]
    return try
        Date(sd)
    catch e
        throw(ConfigfileError("'[Simulation] => startdate' could not be read from config file.", e))
    end
end

"""
    determine_end_date(configfile_params::Dict, end_date)

Determines the end date for the simulation based on the provided parameters.
If a `end_date` is provided, it will be used.
If not, it will look for an `enddate` in the config file.
If neither is found, it will default to today + 1 year.
"""
function determine_end_date(configfile_params::Dict, end_date)
    # if end_date is provided, use it
    if !isnothing(end_date)
        !isa(end_date, Date) && !isa(end_date, String) && throw(ArgumentError("Provided end_date must be an object of type Date!"))
        return Date(end_date)
    end

    # if no end date is provided, look it up in config file
    if !haspath(configfile_params, ["Simulation", "enddate"])
        @warn "End date not found in config file and not provided as argument; defualting to today + 1 year."
        return today() + Year(1)
    end

    ed = configfile_params["Simulation"]["enddate"]
    return try
        Date(ed)
    catch e
        throw(ConfigfileError("'[Simulation] => enddate' could not be read from config file.", e))
    end
end

"""
    determine_tick_unit(configfile_params::Dict, tickunit)

Determines the tick unit for the simulation based on the provided parameters.
If a `tickunit` is provided, it will be used.
If not, it will look for a `tickunit` in the config file.
If neither is found, it will default to 'd' (days).
"""
function determine_tick_unit(configfile_params::Dict, tickunit)
    # if tickunit is provided, use it
    if !isnothing(tickunit)
        tu = try
            only(tickunit)
        catch
            throw(ArgumentError("Provided tickunit must be a single character!"))
        end
        !(tu in ['h', 'd', 'w']) && throw(ArgumentError("Provided tickunit must be one of: 'h', 'd', 'w'"))
        #!isa(only(tickunit), Char) && throw(ArgumentError("Provided tickunit must be a single character!"))
        return only(tickunit)
    end

    # if no tick unit is provided, look it up in config file
    if !haspath(configfile_params, ["Simulation", "tickunit"])
        @warn "Tick unit not found in config file and not provided as argument; defualting to 'd'."
        return 'd'
    end

    tu = configfile_params["Simulation"]["tickunit"]
    !isa(only(tu), Char) && throw(ConfigfileError("'[Simulation] => tickunit' must be a single character!"))
    return try
        only(tu)
    catch e
        throw(ConfigfileError("'[Simulation] => tickunit' could not be read from config file.", e))
    end
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
        !haspath(configfile_params, ["Simulation", "StartCondition"]) && throw(ConfigfileError("No start condition found in config file! Without a provided 'start_condition' or 'infected_fraction' argument, a '[Simulation.StartCondition]' section must be specified in the config file."))
        return try 
            create_start_condition(configfile_params["Simulation"]["StartCondition"])
        catch e
            throw(ConfigfileError("'[Simulation.StartCondition]' could not be read from config file.", e))
        end
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
        !haspath(configfile_params, ["Simulation", "StopCriterion"]) && throw(ConfigfileError("No stop criterion found in config file! Without a provided 'stop_criterion' argument, a '[Simulation.StopCriterion]' section must be specified in the config file."))

        return try
            create_stop_criterion(configfile_params["Simulation"]["StopCriterion"])
        catch e
            throw(ConfigfileError("'[Simulation.StopCriterion]' could not be created from config file.", e))
        end
    end

    # if stop_criterion is provided, use it
    !isa(stop_criterion, StopCriterion) && throw(ArgumentError("Provided stop_criterion must be an object of type StopCriterion! Try any of $(join(subtypes(StopCriterion), ", "))"))
    return stop_criterion
end

"""
    determine_pathogen(configfile_params::Dict, pathogen, transmission_function, transmission_rate)

Determines the pathogen for the simulation based on the provided parameters.
If a `pathogen` is provided, it will be used.
If not, it will look for a `Pathogens` section in the config file to create a pathogen.
If a `transmission_function` is provided, it will be set for the pathogen.
If a `transmission_rate` is provided, it will be set as a `ConstantTransmissionRate` for the pathogen.
The `transmission_rate` will be ignored if a `transmission_function` is provided.
"""
function determine_pathogen(configfile_params::Dict, pathogen, transmission_function, transmission_rate)
    if !isnothing(pathogen)
        !isa(pathogen, Pathogen) && throw(ArgumentError("Provided pathogen must be an object of type Pathogen!"))
        
        # throw warnings for unused parameters
        !isnothing(transmission_rate) && @warn "A pathogen was provided, therefore transmission_rate will be ignored."
        
        return pathogen
    end

    # if no pathogen is provided, create one from config file parameters
    !haspath(configfile_params, ["Pathogens"]) && throw(ConfigfileError("No pathogen found in config file! Without a provided 'pathogen' argument, a '[Pathogens]' section must be specified in the config file."))
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

"""
    determine_global_setting(configfile_params::Dict, global_setting)

Determines the global setting flag for the simulation based on the provided parameters.
If a `global_setting` is provided, it will be used.
If not, it will look for a `GlobalSetting` in the config file.
If neither is found, it will default to false.
"""
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

"""
    determine_population(population::String, settingsfile, global_setting)

Determines the population and settings for the simulation based on the provided parameters.
If a `population` string is provided, it will be used to load the population from a file or obtain remote files.
If a `settingsfile` is provided, it will be used to load the settings from a file.
If neither is provided, an error will be thrown.
"""
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
        printinfo("\u2514 Loading settings from $(basename(settings_path))")
        settings_from_jld2!(settings_path, settings, renaming)
    end

    return pop, settings
end

"""
    determine_population_and_settings(configfile_params::Dict, population, global_setting, pop_size, avg_household_size, avg_office_size, avg_school_size, settingsfile)

Determines the population and settings for the simulation based on the provided parameters.
If a `population` is provided, it will be used to load the population from a file or obtain remote files.
If not, it will create a new population based on the provided parameters or config file parameters.
"""
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
    printinfo("\u2514 Creating population")

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

"""
    determine_setting_type_config!(stngs::SettingsContainer, type::DataType, configfile_params::Dict; custom_par = nothing)

Determines the settings of a specific type for the simulation based on the provided parameters.
If a `custom_par` is provided, it will be used to set the settings of the specified type.
If not, it will look for the settings in the config file.
Requires to be called with a type that is actually present in the settings container.

# Example

```julia
determine_setting_type_config!(settings_container, Household, configfile_params; custom_par = 3.5)
```

This will set the number of contacts for all `Household` settings to `3.5`.
"""
function determine_setting_type_config!(stngs::SettingsContainer, type::DataType, configfile_params::Dict; custom_par = nothing)

    # if custom parameter is provided, use it
    if !isnothing(custom_par)
        # if a ContactSamplingMethod is provided, use it
        if isa(custom_par, ContactSamplingMethod)
            for s in settings(stngs, type)
                s.contact_sampling_method = custom_par
            end
            return stngs
        # if a number is provided set it as number of contacts
        elseif isa(custom_par, Real)
            for s in settings(stngs, type)
                s.contact_sampling_method = ContactparameterSampling(contactparameter = custom_par)
            end
            return stngs
        else
            throw(ArgumentError("Provided parameter for `$(structname(type))` contacts must be a ContactSamplingMethod or a number indicating the average number of contacts per ticks!"))
        end
    end

    # if no custom parameters are provided, check if config file has section for the setting type
    if !haspath(configfile_params, ["Settings", structname(type)])
        @warn "`$(structname(type))` settings not found in config file. Using default settings only. This might cause 0 contacts and no infections."
        return settings
    end

    # check if the setting type has a config part for contact sampling method
    if !haspath(configfile_params, ["Settings", structname(type), "contact_sampling_method"])
        @warn "`contact_sampling_method` for `$(structname(type))` settings not found in config file. Using default settings only. This might cause 0 contacts and no infections."
        return settings
    end

    # build contact sampling method
    csm_params = configfile_params["Settings"][structname(type)]["contact_sampling_method"]
    sampling_method = create_contact_sampling_method(csm_params)
    for s in settings(stngs, type)
        s.contact_sampling_method = sampling_method
    end    
end

"""
    determine_setting_config!(stngs::SettingsContainer, configfile_params::Dict; household_contacts = nothing,
        office_contacts = nothing,
        department_contacts = nothing,
        workplace_contacts = nothing,
        workplace_site_contacts = nothing,
        school_class_contacts = nothing,
        school_year_contacts = nothing,
        school_contacts = nothing,
        school_complex_contacts = nothing,
        global_setting_contacts = nothing
    )

Determines the settings for all setting types present in the simulation based on the provided parameters.
If a custom parameter for a specific setting type is provided, it will be used to set the settings of that type.
If not, it will look for the settings in the config file.
Requires to be called with setting types that are actually present in the settings container.
"""
function determine_setting_config!(stngs::SettingsContainer, configfile_params::Dict;
        household_contacts = nothing,
        office_contacts = nothing,
        department_contacts = nothing,
        workplace_contacts = nothing,
        workplace_site_contacts = nothing,
        school_class_contacts = nothing,
        school_year_contacts = nothing,
        school_contacts = nothing,
        school_complex_contacts = nothing,
        municipality_contacts = nothing,
        global_setting_contacts = nothing
    )

    # check if a contact parameter was passed without that setting type being present
    !isnothing(household_contacts) && !haskey(stngs.settings, Household) && throw(ArgumentError("Provided household_contacts but simulation only contains these settings: $(join(keys(stngs.settings), ", "))."))
    !isnothing(office_contacts) && !haskey(stngs.settings, Office) && throw(ArgumentError("Provided office_contacts but simulation only contains these settings: $(join(keys(stngs.settings), ", "))."))
    !isnothing(department_contacts) && !haskey(stngs.settings, Department) && throw(ArgumentError("Provided department_contacts but simulation only contains these settings: $(join(keys(stngs.settings), ", "))."))
    !isnothing(workplace_contacts) && !haskey(stngs.settings, Workplace) && throw(ArgumentError("Provided workplace_contacts but simulation only contains these settings: $(join(keys(stngs.settings), ", "))."))
    !isnothing(workplace_site_contacts) && !haskey(stngs.settings, WorkplaceSite) && throw(ArgumentError("Provided workplace_site_contacts but simulation only contains these settings: $(join(keys(stngs.settings), ", "))."))
    !isnothing(school_class_contacts) && !haskey(stngs.settings, SchoolClass) && throw(ArgumentError("Provided school_class_contacts but simulation only contains these settings: $(join(keys(stngs.settings), ", "))."))
    !isnothing(school_year_contacts) && !haskey(stngs.settings, SchoolYear) && throw(ArgumentError("Provided school_year_contacts but simulation only contains these settings: $(join(keys(stngs.settings), ", "))."))
    !isnothing(school_contacts) && !haskey(stngs.settings, School) && throw(ArgumentError("Provided school_contacts but simulation only contains these settings: $(join(keys(stngs.settings), ", "))."))
    !isnothing(school_complex_contacts) && !haskey(stngs.settings, SchoolComplex) && throw(ArgumentError("Provided school_complex_contacts but simulation only contains these settings: $(join(keys(stngs.settings), ", "))."))
    !isnothing(municipality_contacts) && !haskey(stngs.settings, Municipality) && throw(ArgumentError("Provided municipality_contacts but simulation only contains these settings: $(join(keys(stngs.settings), ", "))."))
    !isnothing(global_setting_contacts) && !haskey(stngs.settings, GlobalSetting) && throw(ArgumentError("Provided global_setting_contacts but simulation only contains these settings: $(join(keys(stngs.settings), ", "))."))


    # apply configuration
    for (type, settings_list) in settings(stngs)
        if type == Household
            determine_setting_type_config!(stngs, type, configfile_params; custom_par = household_contacts)
        elseif type == Office
            determine_setting_type_config!(stngs, type, configfile_params; custom_par = office_contacts)
        elseif type == Department
            determine_setting_type_config!(stngs, type, configfile_params; custom_par = department_contacts)
        elseif type == Workplace
            determine_setting_type_config!(stngs, type, configfile_params; custom_par = workplace_contacts)
        elseif type == WorkplaceSite
            determine_setting_type_config!(stngs, type, configfile_params; custom_par = workplace_site_contacts)
        elseif type == SchoolClass
            determine_setting_type_config!(stngs, type, configfile_params; custom_par = school_class_contacts)
        elseif type == SchoolYear
            determine_setting_type_config!(stngs, type, configfile_params; custom_par = school_year_contacts)
        elseif type == School
            determine_setting_type_config!(stngs, type, configfile_params; custom_par = school_contacts)
        elseif type == SchoolComplex
            determine_setting_type_config!(stngs, type, configfile_params; custom_par = school_complex_contacts)
        elseif type == Municipality
            determine_setting_type_config!(stngs, type, configfile_params; custom_par = municipality_contacts)
        elseif type == GlobalSetting
            determine_setting_type_config!(stngs, type, configfile_params; custom_par = global_setting_contacts)
        # for all other setting types, just look for config file parameters
        else
            determine_setting_type_config!(stngs, type, configfile_params)
        end
    end

    return stngs
end



### CREATOR FUNCTIONS

"""
    create_distribution(params::Dict)

Creates a distribution based on the provided parameters.
The `params` dictionary must contain a `distribution` key with the name of the distribution type
and a `parameters` key with a list of parameters for the distribution constructor.
"""
function create_distribution(params::Dict)
    # find the distribution type in the parameters
    dist_type = GEMS.get_subtype(params["distribution"], Distribution)
    return dist_type(params["parameters"]...)

end

"""
    create_progression_parameter(params::Union{Dict, Real})

Creates a progression parameter based on the provided parameters.
If `params` is a dictionary, it will be used to create a distribution.
If `params` is a real number, it will be used as a single value.
"""
function create_progression_parameter(params::Union{Dict, Real})
    # If parameter is a dictionary, we assume it describes a distribution
    # Otherwise, we assume it is a single value
    return isa(params, Dict) ? create_distribution(params) : params
end

"""
    create_progression(params::Dict, category::String)

Creates a progression of the specified category based on the provided parameters.
The `params` dictionary must contain the parameters for the progression constructor.
The `category` string must be the name of a subtype of `ProgressionCategory`.
"""
function create_progression(params::Dict, category::String)
    # convert parameters to keyword arguments
    kw_args = Dict(Symbol(k) => create_progression_parameter(v) for (k, v) in params)
    # create the progression category using the keyword arguments
    return try
        GEMS.get_subtype(category, ProgressionCategory)(;kw_args...)
    catch e
        throw("ProgressionCategory of type '$category' could not be created. $(sprint(showerror, e))")
    end
end

"""
    create_progression_assignment(params::Dict)

Creates a progression assignment function based on the provided parameters.
The `params` dictionary must contain a `type` key with the name of the progression assignment type
and a `parameters` key with a list of parameters for the progression assignment constructor.
"""
function create_progression_assignment(params::Dict)
    pa_type = GEMS.get_subtype(params["type"], ProgressionAssignmentFunction)
    kw_args = Dict(Symbol(k) => v for (k, v) in params["parameters"])

    return try
        pa_type(;kw_args...)
    catch e
        throw("ProgressionAssignmentFunction of type '$pa_type' could not be created. $(sprint(showerror, e))")
    end
end

"""
    create_transmission_function(params::Dict)

Creates a transmission function based on the provided parameters.
The `params` dictionary must contain a `type` key with the name of the transmission function
and a `parameters` key with a list of parameters for the transmission function constructor.
"""
function create_transmission_function(params::Dict)
    tf_type = GEMS.get_subtype(params["type"], TransmissionFunction)
    kw_args = Dict(Symbol(k) => v for (k, v) in params["parameters"])
    return try
        tf_type(;kw_args...)
    catch e
        throw("TransmissionFunction of type '$tf_type' could not be created. $(sprint(showerror, e))")
    end
end

"""
    create_pathogen(params::Dict, name, id)

Creates a pathogen based on the provided parameters.
The `params` dictionary must contain the parameters for the pathogen constructor.
The `name` string is the name of the pathogen.
The `id` integer is the unique identifier for the pathogen.
"""
function create_pathogen(params::Dict, name, id)

    # create progressions
    progressions = try
       [create_progression(pars, category) for (category, pars) in params["progressions"]] 
    catch e
        throw(ConfigfileError("progressions for pathogen '$name' could not be created from config file.", e))
    end
    # create progression assignment
    pa = try
        create_progression_assignment(params["progression_assignment"])
    catch e
        throw(ConfigfileError("progression assignment for pathogen '$name' could not be created from config file.", e))
    end

    # create transmission function
    tf = try 
        create_transmission_function(params["transmission_function"])
    catch e
        throw(ConfigfileError("transmission function for pathogen '$name' could not be created from config file.", e))
    end

    return Pathogen(
        id = id,
        name = name,
        progressions = progressions,
        progression_assignment = pa,
        transmission_function = tf
    )
end

"""
    create_pathogens(params::Dict)

Creates a list of pathogens based on the provided parameters.
The `params` dictionary must contain the parameters for each pathogen constructor.
"""
function create_pathogens(params::Dict)
    pathogens = []
    for (pathogen_name, pathogen_params) in params
        # create pathogen
        p = create_pathogen(pathogen_params, pathogen_name, length(pathogens) + 1)
        push!(pathogens, p)
    end

    # check if at least one pathogen was created
    length(pathogens) == 0 && throw(ConfigfileError("No pathogens were found in the config file! At least one pathogen must be specified in the '[Pathogens]' section. E.g., '[Pathogens.Covid19]'."))
    return pathogens
end

"""
    create_start_condition(params::Dict)

Creates a start condition based on the provided parameters.
The `params` dictionary must contain a `type` key with the name of the start condition type
and a `parameters` key with a list of parameters for the start condition constructor.
"""
function create_start_condition(params::Dict)
    sc_type = get_subtype(params["type"], StartCondition)
    kw_args = Dict(Symbol(k) => v for (k, v) in params["parameters"])
    return try
        sc_type(;kw_args...)
    catch e
        throw("StartCondition of type '$sc_type' could not be created. $(sprint(showerror, e))")
    end
end

"""
    create_stop_criterion(params::Dict)

Creates a stop criterion based on the provided parameters.
The `params` dictionary must contain a `type` key with the name of the stop criterion type
and a `parameters` key with a list of parameters for the stop criterion constructor.
"""
function create_stop_criterion(params::Dict)
    sc_type = get_subtype(params["type"], StopCriterion)
    kw_args = Dict(Symbol(k) => v for (k, v) in params["parameters"])
    return try
        sc_type(;kw_args...)
    catch e
        throw("StopCriterion of type '$sc_type' could not be created. $(sprint(showerror, e))")
    end
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
        !isfile(path) && throw(ConfigfileError("Provided config file path does not point to a valid file: '$path'"))
        !is_toml_file(path) && throw(ConfigfileError("Provided config file path does not point to a valid .toml file: '$path'"))    
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
    statelogger(simulation)

Returns the `StateLogger` of the simulation.
"""
function statelogger(simulation::Simulation)
    return simulation.statelogger
end

"""
    statelogger!(simulation, statelogger)

Sets the Simulation's `StateLogger`.
"""
function statelogger!(simulation::Simulation, statelogger::StateLogger)
    simulation.statelogger = statelogger
end

"""
    states(simulation::Simulation)

Calls the `dataframe()` function on the internal simulation's `StateLogger`.
"""
states(simulation::Simulation) = simulation |> statelogger |> dataframe

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