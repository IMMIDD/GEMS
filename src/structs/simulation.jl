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

    
    ### INNER CONSTRUCTOR

    @doc"""
        Simulation(config_file::String, start_condition::StartCondition, stop_criterion::StopCriterion, population::Population, settings::SettingsContainer, label::String)
    
    Used as initializer and is called by the other constructors.
    """
    function Simulation(config_file::String, 
        start_condition::StartCondition,
        stop_criterion::StopCriterion,
        population::Population,
        settings::SettingsContainer,
        label::String)

        return new(
         config_file, # configfile::String
         0, # tick::Int16
         'd', # tickunit::Char
         Date(2024), # startdate::Date
         Date(2025), # enddate::Date
         start_condition, # start_condition::StartCondition
         stop_criterion, # stop_criterion::StopCriterion
         label, # label::String
         population, # population::Population
         settings, # settings::SettingsContainer
         Pathogen(id = 0, name = "TEST DEFAULT"), # pathogen::Pathogen
         InfectionLogger(), # infectionlogger::InfectionLogger
         DeathLogger(), # deathlogger::DeathLogger
         TestLogger(), # testlogger::TestLogger
         PoolTestLogger(), # pooltestlogger::PoolTestLogger
         SeroprevalenceLogger(), # seroprevalencelogger::SeroprevalenceLogger
         QuarantineLogger(), # quarantinelogger::QuarantineLogger
         CustomLogger(), # customlogger::CustomLogger
         [], # symptom_triggers::Vector{ITrigger}
         [], # tick_triggers::Vector{TickTrigger}
         [], # hospitalization_triggers::Vector{ITrigger}
         EventQueue(), # event_queue::EventQueue
         [], # strategies::Vector{Strategy}
         [], # testtypes::Vector{AbstractTestType}
         x -> x # stepmod::Function
         ) 
    end

    @doc"""
        Simulation(; simargs...)

    
    Constructor that creates and initializes a `Simulation` object based on various parameters.

    It uses the default configuration for the created run which is saved in `data/DefaultConf.toml` but should not be edited. See Usage and Examples on how to edit the simulation configuration.

    - The constructor can be called without any parameters which will create a default simulation.
    - A population can be provided. This can either be the path to a population file (.csv or .jdl2) or a `Population` object created. Either way the poulation will overwrite any population configurations in the config file.
    - Arguments can be provided overwriting just certain parameters. For all possible arguments see the table below.
        These arguments can be used in combination with a custom config file and will overwrite it where possible. Arguments can be combined.
    - All arguments can alse be put into Dictionary and provided to function. This dictionary must have Symbols as keys. The keys must be the same as the argument names.
    - All possibilities above can also be combined. Providing arguments will overwrite custom config file where possible. Custom populations will override custom arguments.

    The optional `stepmod` argument allows to pass a custom single-argument
    function that takes the simulation object as its argument and allows
    to do custom operations on the simulation object in each step.

    *Note*: Be careful with the `stepmod` option as there's no option
    to check whether your custom code invalidates simulation outputs or
    causes internal model inconsistencies. Please only use this option
    if you are sure you know what you're doing :-)

    # Examples

    ```Julia
    sim = Simulation() # returns a default simulation 
    ```
    ```Julia
    sim = Simulation(population = "data/TestPop.csv") # returns a Simulation using the assigned population file.
    ```
    ```Julia
    sim = Simulation(population = Population()) # returns a Simulation using the created Population.
    ```
    ```Julia
    my_population = Population(n=1_000);
    sim = Simulation(population = my_population) # returns a Simulation using the created Population that has its own parameters.
    ```
    ```Julia
    sim = Simulation(label = "My First Simulation") # returns a Simulation with a custom label
    ```
    ```Julia
    sim = Simulation(startdate = "2020.1.1", n = 100_000, transmission_rate = 0.2) # returns a Simulation starting at the 1.1.2020, having 100,000 individuals and a transmission rate of 0.2
    ```
    ```Julia
    my_arguments = Dict(
                        :transmission_rate => 0.3,
                        :pop_size => 10_000_000
                    )
    sim = Simulation(my_arguments) # returns a `Simulation` the arguments provided in the dictionary.
    ```
    ```Julia
    sim = Simulation(population = Population(n=100_000), label = "My First Simulation") # returns a Simulation with a custom label and a population partly overwriting the default configuration.
    ```

    # Parameters

    | **Name**                        | **Type**               | **Description**                                                                                                                       |
    | :------------------------------ | :--------------------- | :------------------------------------------------------------------------------------------------------------------------------------ |
    | `population`                    | `String`, `Population` | Path to a CSV or JLD2 file containing popultion data or a `Population` object                                                         |
    | `settingsfile`                  | `String`               | Path to a setting-file                                                                                                                |
    | `label`                         | `String`               | Label used to name simulation runs during analysis                                                                                    |
    | `stepmod`                       | `Function`             | One-agument function which will be executed each simulation step, called on the `Simulation` object                                   |
    | `seed`                          | `Int64`                | Random seed                                                                                                                           |
    | `global_setting`                 | `Bool`                 | Enable or disable a global setting that contains every individual                                                                     |
    | `startdate`                     | `Date`, `String`       | Simulation start date (format: `YYYY.MM.DD`)                                                                                          |
    | `enddate`                       | `Date`, `String`       | Simulation end date (format: `YYYY.MM.DD`)                                                                                            |
    | `infected_fraction`             | `Float64`              | Fraction of the initially infected agents for the `InfectedFraction` start condition                                                  |
    | `transmission_rate`             | `Float64`              | Infection probability (0-1) during a contact where one individual is infectious                                                       |
    | `onset_of_symptoms`             | `Float64`              | Average time from exposure to onset of symptoms (Poisson-distributed)                                                                 |
    | `onset_of_severeness`           | `Float64`              | Average time from onset of symptoms to onset of severeness (Poisson-distributed)                                                      |
    | `infectious_offset`             | `Float64`              | Average time from onset of infectiousness to onset of symptoms (Poisson-distributed); cannot be before exposure, obviously.           |
    | `mild_death_rate`               | `Float64`              | Probability of dying (0-1) with a mild disease progression                                                                            |
    | `severe_death_rate`             | `Float64`              | Probability of dying (0-1) with a severe disease progression                                                                          |
    | `critical_death_rate`           | `Float64`              | Probability of dying (0-1) with a critical disease progression                                                                        |
    | `hospitalization_rate`          | `Float64`              | Probability of being hospitalized (0-1) with a severe disease progression                                                             |
    | `ventilation_rate`              | `Float64`              | Probability of being ventilated (0-1) with a critical disease progression                                                             |
    | `icu_rate`                      | `Float64`              | Probability of being admitted to ICU (0-1) with a critical disease progression                                                        |
    | `time_to_recovery`              | `Float64`              | Average time from onset of symptoms to recovery (Poisson-distributed)                                                                 |
    | `time_to_hospitalization`       | `Float64`              | Average time from onset of symptoms to hospitalization (Poisson-distributed)                                                          |
    | `time_to_icu`                   | `Float64`              | Average time from hospitalization to ICU-addmitance (Poisson-distributed)                                                             |
    | `length_of_stay`                | `Float64`              | Average duration of hospitalization (Poisson-distributed)                                                                             |
    | `progression_categories`        | `Vector{Float64}`      | Four-value vector indicating the fraction of individuals with an asymptomatic, mild, severe, and critical progression (must sum to 1) |
    | `office_contact_rate`           | `Float64`              | Average number of office contacts per timestep (Poisson-distributed)                                                                  |
    | `household_contact_rate`        | `Float64`              | Average number of household contacts per timestep (Poisson-distributed)                                                               |
    | `school_contact_rate`           | `Float64`              | Average number of school contacts per timestep (Poisson-distributed)                                                                  |
    | `school_class_contact_rate`     | `Float64`              | Average number of school-class contacts per timestep (Poisson-distributed)                                                            |
    | `school_year_contact_rate`      | `Float64`              | Average number of school-year contacts per timestep (Poisson-distributed)                                                             |
    | `school_complex_contact_rate`   | `Float64`              | Average number of school-complex contacts per timestep (Poisson-distributed)                                                          |
    | `workplace_site_contact_rate`   | `Float64`              | Average number of workplace-site contacts per timestep (Poisson-distributed)                                                          |
    | `workplace_contact_rate`        | `Float64`              | Average number of workplace contacts per timestep (Poisson-distributed)                                                               |
    | `department_contact_rate`       | `Float64`              | Average number of department contacts per timestep (Poisson-distributed)                                                              |
    | `municipality_contact_rate`     | `Float64`              | Average number of municipality contacts per timestep (Poisson-distributed)                                                            |
    | `global_contact_rate`           | `Float64`              | Average number of contacts in the global per timestep (Poisson-distributed)                                                           |
    | **Population Parameters**       |                        |                                                                                                                                       |
    | `pop_size`                      | `Int64`                | Number of individuals in the population                                                                                               |
    | `avg_household_size`            | `Int64`                | Average size of households                                                                                                            |
    | `avg_office_size`               | `Int64`                | Average size of offices                                                                                                               |
    | `avg_school_size`               | `Int64`                | Average size of schools                                                                                                               |

    """
    function Simulation(;
        population::Union{String, Population, Nothing} = nothing, # The potential population overwrite
        settingsfile::String = "",
        label::String = "",
        tickunit::String = "d",
        stepmod::Function = x -> x, # Providing  stepmod function to the sim object later
        seed::Union{Int64, Nothing} = nothing,
        global_setting::Union{Bool, Nothing} = nothing,
        startdate::Union{String, Nothing} = nothing,
        enddate::Union{String, Nothing} = nothing,
        infected_fraction::Union{Real, Nothing} = nothing,
        transmission_rate::Union{Real, Nothing} = nothing,
        onset_of_symptoms::Union{Real, Nothing} = nothing,
        onset_of_severeness::Union{Real, Nothing} = nothing,
        infectious_offset::Union{Real, Nothing} = nothing,
        mild_death_rate::Union{Real, Nothing} =  nothing,
        severe_death_rate::Union{Real, Nothing} =  nothing,
        critical_death_rate::Union{Real, Nothing} = nothing,
        hospitalization_rate::Union{Real, Nothing} = nothing,
        ventilation_rate::Union{Real, Nothing} = nothing,
        icu_rate::Union{Real, Nothing} = nothing,
        time_to_recovery::Union{Real, Nothing} = nothing,
        time_to_hospitalization::Union{Real, Nothing} = nothing,
        time_to_icu::Union{Real, Nothing} = nothing,
        length_of_stay::Union{Real, Nothing} = nothing,
        progression_categories::Union{Array, Nothing} = nothing,
        household_contact_rate::Union{Real, Nothing} = nothing,
        office_contact_rate::Union{Real, Nothing} = nothing,
        school_contact_rate::Union{Real, Nothing} = nothing,
        school_class_contact_rate::Union{Real, Nothing} = nothing,
        school_year_contact_rate::Union{Real, Nothing} = nothing,
        school_complex_contact_rate::Union{Real, Nothing} = nothing,
        workplace_site_contact_rate::Union{Real, Nothing} = nothing,
        workplace_contact_rate::Union{Real, Nothing} = nothing,
        department_contact_rate::Union{Real, Nothing} = nothing,
        municipality_contact_rate::Union{Real, Nothing} = nothing,
        global_contact_rate::Union{Real, Nothing} = nothing,
        pop_size::Union{Int64, Nothing} = nothing,
        avg_household_size::Union{Int64, Nothing} = nothing,
        avg_office_size::Union{Int64, Nothing} = nothing,
        avg_school_size::Union{Int64, Nothing} = nothing,
        simargs...)
        

        # 1 Check for errors in the arguments:

        # Check if a config file was provided. This can be used by users who want to provide their configfile by keword. Reroute the constructor.
        if haskey(simargs, :configfile)
            configfile = simargs[:configfile]
            return Simulation(configfile, isnothing(population) ? "" : population, settingsfile = settingsfile, label = label, stepmod = stepmod)
        end

        # dpr:
        isnothing(progression_categories) ? nothing : (progression_categories[1] isa Array ? throw("Please submit a vector with 4 entries for the default disease progressuion. If you want to have a complex disease progression please provide a custom conig file.") : nothing)
        !isnothing(progression_categories) ? !(sum(Iterators.flatten(progression_categories)) ≈ 1) ? throw("The entries of the progression_categories must add up to one.") : nothing : nothing
        if !isnothing(progression_categories)
            if !all(x -> 0 ≤ x ≤ 1, progression_categories)
                throw("All entries in the progression_categories need to be between 0 and 1 (including)")
            end
        end

        # Global contact parmater
        if !isnothing(global_contact_rate) && !isnothing(global_setting)
            @warn "Global setting is turned off so setting the global contact parameter will not have an impact!"
        end

        # pop_size:
        !isnothing(pop_size) ? !(pop_size > 0) ? throw("The population must have at least one individual") : nothing : nothing

        # population parameters
        if (!isnothing(pop_size) || !isnothing(avg_household_size) || !isnothing(avg_office_size) || !isnothing(avg_school_size)) && !isnothing(population)
            @warn "The provided population will overwrite any population parameters"
        end

        # transmission rate
        if !isnothing(transmission_rate)
            if transmission_rate < 0 || transmission_rate > 1  
                throw("The transmission rate needs to be between and including 0 and 1")
            end
        end

        # 2 Define a dictionary that mirrors the structure of the properties with the desired updates
        parameters_to_update = Dict(
            "Simulation.seed" => seed,
            "Simulation.GlobalSetting" => global_setting,
            "Simulation.startdate" => startdate,
            #"Simulation.enddate" => enddate,
            "Simulation.tickunit" => tickunit,
            "Simulation.StartCondition.fraction" => infected_fraction,        
            "Pathogens.Covid19.transmission_function.parameters.transmission_rate" => transmission_rate,
            "Pathogens.Covid19.onset_of_symptoms.parameters" => isnothing(onset_of_symptoms) ? nothing : [onset_of_symptoms],
            "Pathogens.Covid19.onset_of_severeness.parameters" => isnothing(onset_of_severeness) ? nothing : [onset_of_severeness],
            "Pathogens.Covid19.infectious_offset.parameters" => isnothing(infectious_offset) ? nothing : [infectious_offset],
            "Pathogens.Covid19.mild_death_rate.parameters" => isnothing(mild_death_rate) ? nothing : [1, mild_death_rate],
            "Pathogens.Covid19.severe_death_rate.parameters" => isnothing(severe_death_rate) ? nothing : [1, severe_death_rate],
            "Pathogens.Covid19.critical_death_rate.parameters" => isnothing(critical_death_rate) ? nothing : [1, critical_death_rate],
            "Pathogens.Covid19.hospitalization_rate.parameters" => isnothing(hospitalization_rate) ? nothing : [1, hospitalization_rate],
            "Pathogens.Covid19.ventilation_rate.parameters" => isnothing(ventilation_rate) ? nothing : [1, ventilation_rate],
            "Pathogens.Covid19.icu_rate.parameters" => isnothing(icu_rate) ? nothing : [1, icu_rate],
            "Pathogens.Covid19.time_to_recovery.parameters" => isnothing(time_to_recovery) ? nothing : [time_to_recovery],
            "Pathogens.Covid19.time_to_hospitalization.parameters" => isnothing(time_to_hospitalization) ? nothing : [time_to_hospitalization],
            "Pathogens.Covid19.time_to_icu.parameters" => isnothing(time_to_icu) ? nothing : [time_to_icu],
            "Pathogens.Covid19.length_of_stay.parameters" => isnothing(length_of_stay) ? nothing : [length_of_stay],
            "Pathogens.Covid19.dpr.stratification_matrix" => isnothing(progression_categories) ? nothing : [progression_categories],
            "Settings.Household.contact_sampling_method.parameters.contactparameter" => household_contact_rate,
            "Settings.Office.contact_sampling_method.parameters.contactparameter" => office_contact_rate,
            "Settings.School.contact_sampling_method.parameters.contactparameter" => school_contact_rate,
            "Settings.SchoolClass.contact_sampling_method.parameters.contactparameter" => school_class_contact_rate,
            "Settings.Municipality.contact_sampling_method.parameters.contactparameter" => municipality_contact_rate,
            "Settings.WorkplaceSite.contact_sampling_method.parameters.contactparameter" => workplace_site_contact_rate,
            "Settings.SchoolComplex.contact_sampling_method.parameters.contactparameter" => school_complex_contact_rate,
            "Settings.SchoolYear.contact_sampling_method.parameters.contactparameter" => school_year_contact_rate,
            "Settings.Department.contact_sampling_method.parameters.contactparameter" => department_contact_rate,
            "Settings.Workplace.contact_sampling_method.parameters.contactparameter" => workplace_contact_rate,
            "Settings.GlobalSetting.contact_sampling_method.parameters.contactparameter" => global_contact_rate,
            "Population.n" => pop_size,
            "Population.avg_household_size" => avg_household_size,
            "Population.avg_office_size" => avg_office_size,
            "Population.avg_school_size" => avg_school_size
        )

        


        # 3 Parse default configuration file
        basefolder = dirname(dirname(pathof(GEMS)))
        default_configfile = GEMS.DEFAULT_CONFIGFILE # "data/DefaultConf.toml"
        default_configfile_path = joinpath(basefolder, default_configfile)
        properties = TOML.parsefile(default_configfile_path)

        if label == ""
            label = "Simulation " * string(GEMS.SIMS_INSTANTIATED)
        end
        global GEMS.SIMS_INSTANTIATED += 1
        
        provided_args = filter(kv -> kv[2] !== nothing && kv[2] !== "" && kv[2] !== (x -> x), parameters_to_update)
        if isempty(provided_args)
            printinfo("Initializing Simulation [$label] with default configuration.")
        else
            # Construct the message dynamically based on the number of parameters
            if length(provided_args) == 1
                printinfo("Initializing Simulation [$label] with default configuration and one custom parameter.")
            else
                printinfo("Initializing Simulation [$label] with default configuration and custom parameters.")
            end
        end
        

        if !isempty(simargs)
            @warn "Warning: Unhandled arguments provided - $simargs. Please have a look at the documentation for supported arguments when calling the constructor" # TODO eher exception?
        end


        # 4 Handle the individual parameters each:

        # handle special key seed first
        if !haskey(properties["Simulation"], "seed") && !isnothing(seed)
            properties["Simulation"]["seed"] = seed
        end

        update_properties!(properties, parameters_to_update)


        # call the deeper constructor
        return Simulation(default_configfile_path, properties, population, settingsfile, label, stepmod)
    end


    """
        Simulation(configfile::String,
            populationidentifier::String;
            settingsfile::String = "",
            label::String = "",
            stepmod::Function = x -> x,
            params::Dict{String, <:Any})

    Outer constructor to overwrite the default config file with a custom one.

    Please refer to the documentation on config files on how to create your own.

    - A custom config file can be provided via its path. This file will overwrite the default configuration 
        file and must contain all required fields.
        Use this if you want to add more pathogens. See the documentation on the Config file for more details. It must be a .toml file.

    The params dict can overwrite your provided config file. The key must contain the exact path as described in the config file and the value will be replaced.
    # Examples

    ```
        sim = Simulation("data/ChangedConf.toml") # returns a Simulation with the changed config as parameters.
    ```
    ```
        sim = Simulation("data/ChangedConf.toml", label = "My own simulation!") # returns a Simulation with the changed config and a custom label.
    ```
    ```
        sim = Simulation("data/ChangedConf.toml", "data/TestPop.csv") # returns a Simulation with the changed config as parameters and a population provided by path.
    ```
    ```
        sim = Simulation("data/ChangedConf.toml", "people_muenster.jld2", "settings_muenster.jld2") # returns a Simulation with the changed config as parameters and a population provided by path. It also uses custom settings for the population
    ```
    ```
        sim = Simulation("data/ChangedConf.toml", "people_muenster.jld2", settings = "settings_muenster.jld2") # returns a Simulation with the changed config as parameters and a population provided by path. It also uses custom settings for the population
    ```
    ```
        sim = Simulation(configfile = "data/ChangedConf.toml") # returns a Simulation with the changed config as parameters. All other parameters can then also be provided as keywords
    ```

    # Parameters

    | **Name**                        | **Type**                         | **Description**                                                                                                  |
    | :------------------------------ | :------------------------------- | :--------------------------------------------------------------------------------------------------------------- |
    | `settingsfile`                  | `String` (Mandatory)             | The path to a Config file. This config file will replace the default one.                                        |
    | `population`                    | `String`                         | The path to a population .csv or .jdl22 file. Replaces any population specifications in the config               |
    | `settingsfile`                  | `String`                         | The path to a setting file                                                                                       |
    | `label`                         | `String` (as Keyword)            | Gives each Simulation a label as identifier in the analyis. Increments Sims by default                           |
    | `stepmod`                       | `Function` (as Keyword)          | A function that is executed with each step of the simulation.                                                    |
    | `params`                        | `Dict{String, <|Any}`(as Keyword)| The params dict will overwrite your provided config file. The key must contain the exact path as in the config   |
    
    """
    function Simulation(configfile::String,
        populationidentifier::String;
        settingsfile::String = "",
        label::String = "",
        stepmod::Function = x -> x,
        params::Union{Dict{String, <:Any}, Nothing} = nothing,
        simargs...)

        
        # println("TEST: CONFIG CONSTR + POPFILE")

        if !isempty(simargs)
            throw("Warning: Unhandled arguments provided - $simargs. You cannot overwrite parameters in a provided config file")
        end

        properties = nothing

        if label == ""
            label = "Simulation " * string(GEMS.SIMS_INSTANTIATED)
        end
        global GEMS.SIMS_INSTANTIATED += 1

        # 4 Also parse the provided config file or directly use a provided dict
        if configfile != "No config file provided!" && configfile != "" 
            if is_toml_file(configfile)
                try
                    properties = TOML.parsefile(configfile)
                catch e
                    throw("Please make sure that the path provided to the configfile exists and starts from the base folder.
                    Have a look at the examples. Also please make sure the structure of the file is a correct .toml-file structure. $e")
                end
                 printinfo("Initializing Simulation [$label] with configuration from $(basename(configfile)).")
            else
                throw("Please provide a valid .toml file as config file! Refer to the documentation for explanation on the config file structure")
            end
        else
            throw("No Config file provided")
        end

        # TODO update config file with provided params dict

        # Call deeper constructor
        pop = (populationidentifier == "") ? nothing : populationidentifier
        return Simulation(configfile, properties, pop, settingsfile, label, stepmod)
    end


    """
        Simulation(configfile::String,
            properties::Dict{String, <:Any},
            population::Union{String, Population, Nothing} = nothing,
            settingsfile::String = "",
            label::String = "",
            stepmod::Function = x -> x)

    Only for internal usage to provide pipeline for both available constructors
    """
    function Simulation(configfile::String,
        properties::Dict{String, <:Any},
        population::Union{String, Population, Nothing},
        settingsfile::String,
        label::String,
        stepmod::Function)

        # println("TEST: INNER CONSTR")
        

        # Settigns and population file paths
        if (isa(population, Population) && settingsfile != "")
            @warn "You provided a settingsfile for a Population object. This might not work!"
        elseif (!isnothing(population) && settingsfile != "")
            validate_file_paths(population, settingsfile)
        end

        validate_pathogens(properties, 1) # TODO adapt if more than one pathogen is possible, replace 1 by number of pathogens automatically

        # 6 Create the population

        if isnothing(population)
            printinfo("\u2514 Creating population")
            if haskey(properties, "Population")
                symbolic_parameters = Dict(Symbol.(k) => v for (k, v) in properties["Population"])
                population = Population(;symbolic_parameters...)
            else
                @warn "There is no Population section in your config file. Please add this and ensure it is complete. Please refer to the documentation on config files"
                population = Population()
            end
        elseif isa(population, Population)
            printinfo("\u2514 Loading provided population object")
            population = population
        elseif isa(population, String)
            if is_pop_file(population)
                #printinfo("\u2514 Loading population from $(basename(population))")
                population = Population(population)
            else 
                #printinfo("\u2514 Downloading popfile and settings with remote identifier $(population)")
                if settingsfile != ""
                    throw("The remote download attempted to overwrite the settingsfile you provided. You need to define the populationfile you want to use locally.")
                end
                (populationfile, settingsfile) = obtain_remote_files(population)
                population = Population(populationfile)
            end
        end

        # 7 We create the sim object with the parameters

        
        if "seed" in keys(properties["Simulation"])
            seed = properties["Simulation"]["seed"]
            # println(seed)
            initialize_seed(seed)
        end
    
        # 8 create all necessary pathogens
        pathogens = create_pathogens(properties["Pathogens"])
    
        # load start condition
        start_condition = load_start_condition(properties["Simulation"]["StartCondition"], pathogens)
    
        # load stop criterion
        stop_criterion = load_stop_criterion(properties["Simulation"]["StopCriterion"])

        

        global_setting = only(get(properties["Simulation"], "GlobalSetting", false))
        settings, renaming = settings_from_population(population, global_setting)

        if settingsfile != ""
            printinfo("\u2514 Creating settings from $settingsfile")
            settings_from_jld2!(settingsfile, settings, renaming)
        end
    
        # create simulation
        printinfo("\u2514 Creating simulation object")
        
        sim = Simulation(configfile, start_condition, stop_criterion, population, settings, label)

        # Remove empty containersettings
        if settingsfile != ""
            remove_empty_settings!(sim)
        end
    
        # add tick unit
        sim.tickunit = only(properties["Simulation"]["tickunit"])

        # add Date if available TODO
        if haskey(properties["Simulation"], "startdate") 
            try
                startdate = Date(get(properties["Simulation"], "startdate", "2024.1.1"), dateformat"y.m.d")
                enddate = Date(get(properties["Simulation"], "enddate", "2025.1.1"), dateformat"y.m.d")
                if startdate >= enddate
                    throw("Start date ($startdate) of the simulation is after or at the end date ($enddate). Please provide valid start and end dates in the format yyyy.mm.dd")
                else
                    sim.startdate = startdate
                    sim.enddate = enddate
                end
            catch e
                throw("Please provide valid start and end dates in the format yyyy.mm.dd.
                Stack: $e")
            end

            
        else
            @warn "The used config file does not have a start and end date and might be deprecated!"
        end
    
        # set setting attributes
        load_setting_attributes!(sim.settings, properties["Settings"])
    
        # because we are single pathogen, set the first array entry to be simulation's pathogen
        pathogen!(sim, pathogens[1])
    

        # Append the StepMod! Function

        sim.stepmod = stepmod

        initialize!(sim)

        return sim
    end

end

### Outer constructors:

"""
    Simulation(file::String; simargs...)

Takes a path to a file as input and checks if it is a population or config file. Creates a simulation with that population or configuration. Further parameters can be defined.

Calls a deeper constructor
"""
function Simulation(file::String; simargs...)

    if is_toml_file(file)
        # printinfo("Identified file as config file!")
        return Simulation(file, ""; simargs...)
    elseif is_pop_file(file)
        # printinfo("Identified file as population file!")
        return Simulation(population =  file; simargs...)
    else 
        throw("The file you provided does not match any type recognised by this simulation. Please provide a .toml, .csv, or .jdl2 file!")
    end

end

"""
    Simulation(population::Population; simargs...)

Takes a created population as input and creates a Simulation object.

"""
function Simulation(population::Population; simargs...)

        return Simulation(population = population; simargs...)
end

"""
    Simulation(argsdict::Dict{Symbol, <:Any})

Takes a dict as input.

The dict contains the custom parameters of the other constructors but combined as `Dict` with Symbols as keys.

# Example

```
    my_arguments = Dict(
                        :transmission_rate = 0.3,
                        :configfile = "Data/ChangedConfig.toml",
                        :n = 10_000_000
                    )
    sim = Simulation(my_arguments) # returns a `Simulation` the arguments provided in the dictionary.
```

"""
function Simulation(params::Dict{Symbol, <:Any})
    # printinfo("Parameters provided as dictionary, converting...")
    return Simulation(; params...)
end

"""
    Simulation(configfile::String, populationfile::String, settingsfile::String; simargs...)

Takes the path to a configfile (.toml), a populationidentifier (either a file or remote), and a settingsfile as input and creates a Simulation object.

The configfile can contain anything to overwrite the used default config file. If constructs need to be added, please also provide the layer above.

Example config file:
"""
function Simulation(configfile::String, populationidentifier::String, settingsfile::String; simargs...)

        return Simulation(configfile, populationidentifier, settingsfile = settingsfile; simargs...)
end

# """
#     Simulation(configfile::String, populationfile::String; simargs...)

# Takes 2 files as input: Must be a population containing .jdl2 or .csv file and a config file as a .toml!

# Calls a deeper constructor
# """
# function Simulation(file1::String, file2::String; simargs...)
#     # 1. we initialize sim object through files

#     # assign files
#     configfile::String = ""
#     popfile::String = ""

#     if is_toml_file(file1)
#         configfile = file1
#     elseif is_pop_file(file1)
#         popfile = file1
#     else 
#         throw("The first file you provided does not match any type recognised by this simulation. Please provide a .toml, .csv, or .jdl2 file!")
#     end

#     if is_toml_file(file2)
#         configfile = file2
#     elseif is_pop_file(file2)
#         popfile = file2
#     else 
#         throw("The second file you provided does not match any type recognised by this simulation. Please provide a .toml, .csv, or .jdl2 file!")
#     end

#     return Simulation(configfile, popfile; simargs...)
# end

# """
#     Simulation(configfile::String, population::Population; simargs...)

# Takes a configfile (.toml) and a created population as input and creates a Simulation object.

# The configfile can contain anything to overwrite the used default config file. If constructs need to be added, please also provide the layer above.

# Example config file:
# """
# function Simulation(configfile::String, population::Population; simargs...)

#         return Simulation(configfile=configfile, population = population; simargs...)
# end

# """
#     Simulation( population::Population, configfile::String; simargs...)

# Takes a configfile (.toml) and a created population as input and creates a Simulation object.

# The configfile can contain anything to overwrite the used default config file. If constructs need to be added, please also provide the layer above.

# Example config file:
# """
# function Simulation(population::Population, configfile::String; simargs...)

#         return Simulation(configfile=configfile, population = population; simargs...)
# end


### Helper Methods to adapt the config file

"""
    update_properties!(properties::Dict{String, Any}, updates::Dict{String, Any})

Updates the properties dict to incorporate manual parameters provided with a sim constructor
"""
function update_properties!(properties::Dict{String, <:Any}, updates::Dict{String, <:Any})
    for (path, value) in updates
        if isnothing(value)
            continue  # Skip parameters with `nothing` values
        end

        keys = split(path, ".")  # Split the dot-separated path into keys
        sub_dict = properties
        for i in 1:(length(keys) - 1)
            key = keys[i]
            if haskey(sub_dict, key)
                sub_dict = sub_dict[key]  # Drill down into the nested dictionary
            else
                @warn "Path `$(join(keys[1:i], "."))` not found in properties dictionary."
                break
            end
        end

        # Update the final key if it exists
        final_key = keys[end]
        if haskey(sub_dict, final_key)
            if path == "Pathogens.Covid19.dpr.stratification_matrix"
                # Special case for the disease progression matrix validation
                if length(properties["Pathogens"]["Covid19"]["dpr"]["disease_compartments"]) == length(value[1]) &&
                   length(properties["Pathogens"]["Covid19"]["dpr"]["age_groups"]) == 1 && 
                   length(value) == 1
                    sub_dict[final_key] = value
                else
                    @warn "The provided disease_progression_matrix_2d does not match the compartments in properties."
                end
            else
                sub_dict[final_key] = value
            end
        else
            @warn "Key `$(final_key)` not found in path `$(path)` in properties dictionary."
        end
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
    validate_pathogens(properties, num_pathogens)

Checks if all pathogen names in the config file are consistent.
"""
function validate_pathogens(properties, num_pathogens)
    # Extract pathogen names from the Pathogens section
    pathogen_keys = keys(get(properties, "Pathogens", Dict()))
    unique_pathogens = Set(pathogen_keys)
    
    # Check if there is more than one unique pathogen name
    if length(unique_pathogens) > num_pathogens
        throw("Inconsistent pathogen names found in Pathogens section: $(collect(unique_pathogens))")
    else
        # println("Pathogens are consistent: $(first(unique_pathogens))")
    end

    # Check if pathogen name matches Simulation.StartCondition.pathogen
    if haskey(properties, "Simulation") && haskey(properties["Simulation"], "StartCondition")
        start_condition_pathogen = get(properties["Simulation"]["StartCondition"], "pathogen", nothing)
        if !isnothing(start_condition_pathogen) && start_condition_pathogen ∉ unique_pathogens
            throw("Pathogen in StartCondition ('$(start_condition_pathogen)') does not match the pathogens in the Pathogens section: $(collect(unique_pathogens))")
        else
            # println("StartCondition pathogen matches Pathogens section: $start_condition_pathogen")
        end
    end
end



"""
    create_pathogens(pathogens_dict::Dict)::Vector{Pathogen}

Creates the pathogens for the `Simulation` object out of the simulation parameters.
"""
function create_pathogens(pathogens_dict::Dict)::Vector{Pathogen}
    pathogens = []
    id = 1      # ID will be assigned to ensure it matches position in vector
    for (name, distributions_dict) in pathogens_dict
        p = Pathogen(id=id, name=name)  # name is taken from configuration file as the "section name" of the TOML section

        # for now, the only attributes possible are distributions
        for (key, attr) in distributions_dict
            #  To allow flexibility, we generate only those distributions, that are provided
            if Symbol(key) in fieldnames(Pathogen)
                # Treat the special cases transmissionfunction and DiseaseProgressionStrat individually
                if key == "dpr"
                    setfield!(p, Symbol(key), DiseaseProgressionStrat(attr))
                elseif key == "transmission_function"
                    setfield!(p, Symbol(key), create_transmission_function(attr))
                else
                    distribution = create_distribution(attr["parameters"], attr["distribution"])
                    setfield!(p, Symbol(key), distribution)
                end
            end
        end
        push!(pathogens, p)
        id+=1
    end
    return pathogens
end


"""
    create_distribution(params::Vector{<:Real}, type::String)::Distribution

Creates statistical distributions to be used by other parts of the `Simulation` object.
"""

function create_distribution(params::Vector{<:Real}, type::String)
    gems_string = string(nameof(@__MODULE__))
    id = findfirst(x -> x == type || x == "$gems_string.$type" || x == "Distributions.$type", string.(subtypes(Distribution)))

    dist_type = nothing
    if !isnothing(id)
        dist_type = subtypes(Distribution)[id]
    end

    try
        return dist_type(params...)
    catch e
        error("Failed to create distribution '$type' with parameters $params: $e")
    end
end

"""
    create_waning(params::Vector{<:Real}, type::String)::AbstractWaning

Creates a waning effect for other parameters of the `Simulation` object.
"""
function create_waning(params::Vector{<:Real}, type::String)::AbstractWaning
    if is_existing_subtype(type, AbstractWaning)
        waning = find_subtype(type, AbstractWaning)
        return waning(params...)
    else
        # If no type is found, throw an error
        error("The waning type "*type*" provided in the configfile is not known!")
    end
end

"""
    load_start_condition(start_condition_dict::Dict, pathogens::Vector{Pathogen})::StartCondition

Initializes the `Start Conditions` for the `Simulation` object based on the config parameters. If an infection is provided it must have a unique name.
"""
function load_start_condition(start_condition_dict::Dict, pathogens::Vector{Pathogen})::StartCondition
    if start_condition_dict["type"] == "InfectedFraction"
        # find pathogen under assumption, that the name is UNIQUE
        pathogen = nothing
        for p in pathogens
            if name(p) == start_condition_dict["pathogen"]
                pathogen = p
            end
        end
        if isnothing(pathogen)
            error("The Pathogen of name "*start_condition_dict["pathogen"]*" could not be found for the starting condition")
        end
        return InfectedFraction(start_condition_dict["fraction"], pathogen)
    elseif start_condition_dict["type"] == "PatientZero"
        # find pathogen under assumption, that the name is UNIQUE
        pathogen = nothing
        for p in pathogens
            if name(p) == start_condition_dict["pathogen"]
                pathogen = p
            end
        end
        if isnothing(pathogen)
            error("The Pathogen of name "*start_condition_dict["pathogen"]*" could not be found for the starting condition")
        end
        return PatientZero(pathogen)
    elseif start_condition_dict["type"] == "PatientZeros"
        # find pathogen under assumption, that the name is UNIQUE
        pathogen = nothing
        for p in pathogens
            if name(p) == start_condition_dict["pathogen"]
                pathogen = p
            end
        end
        if isnothing(pathogen)
            error("The Pathogen of name "*start_condition_dict["pathogen"]*" could not be found for the starting condition")
        end
        return PatientZeros(pathogen, start_condition_dict["ags"])
    else
        error("StartCondition "*start_condition_dict["type"]*" is not implemented!")
    end
end

"""
    load_stop_criterion(stop_criterion_dict::Dict)::StopCriterion

Initializes the `Stop Conditions` for the `Simulation` object based on the config parameters.
"""
function load_stop_criterion(stop_criterion_dict::Dict)::StopCriterion
    if stop_criterion_dict["type"] == "TimesUp"
        return TimesUp(stop_criterion_dict["limit"])
    elseif stop_criterion_dict["type"] == "NoneInfected"
        return NoneInfected()
    else
        error("StopCriterion "*stop_criterion_dict["type"]*" is not implemented!")
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

Retursn the pathogen of the simulation.
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