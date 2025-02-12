export DefaultResultData

"""
    DefaultResultData <: ResultDataStyle

The default style for `ResultData` objects. It contains all that can currently
be calculated in the `PostProcessor`. Therefore, it is both, the most comprehensive
and computationally intensive (memory & runtime) option.

# Fields
- `data::Dict{String, Any}`:
    - `meta_data::Dict{String, Any}`
        - `timer_output::TimerOutput`: TimerOutput object    
        - `execution_date::String`: Time this ResultData object was generated
        - `GEMS_version::VersionNumber`: GEMS version this ResultData object was generated with 
        - `config_file::String`: Path to the config file
        - `config_file_val::Dict{String, Any}`: Deep copy of the supplied TOML config file
        - `population_file::String`: Path to the population file
        - `population_params::Dict{String, Any}`: Parameters used to generate population
        
    - `sim_data::Dict{String, Any}`
        - `label::String`: Label of this simulation run (needed for plotting)
        - `final_tick::Int16`: Tick counter at the end of the simulation run
        - `number_of_individuals::Int64`: Total number of individuals in the population model
        - `initial_infections::Int64`: Number of initial infected individuals
        - `total_infections::Int64`: Row count of the PostProcessor's `infections` DataFrame
        - `attack_rate::Float64`: Fraction of overall infected individuals
        - `setting_data::DataFrame`: DataFrame containing information on all setting types
        - `setting_sizes::Dict{Any, Any}`: Dictionary containing the setting sizes distributions for all included settingtypes
        - `region_info::Dataframe`: Municipality population size and area (if geolocalized model is used)
        - `pathogens::Vector{Pathogen}`: Array of pathogen parameters
        - `vaccine::Vaccine`: Vaccine parameter [CURRENTLY DEACTIVATED]
        - `vaccination_strategy::VaccineScheduler`: Vaccination strategy used in this model [CURRENTLY DEACTIVATED]
        - `tick_unit::String`: Unit of time that one tick corresponds to
        - `start_condition::StartCondition`: Initial setup of the simulation
        - `stop_criterion::StopCriterion`: Termination conditions
        - `strategies::Vector{Strategy}`: Intervention strategies
        - `symptom_triggers::Vector{ITrigger} `: Strategies that are triggered upon experiencing symptoms
        - `testtypes::Vector{AbstractTestType}`: Test types used in the model (e.g. Antigen Tests)
        - `total_quarantines::Int64`: Total person-ticks (e.g. days) spent in isolation
        - `total_tests::Dict{Any, Any}`: Total number of performed tests per TestType
        - `detection_rate::Float64`: Fraction of detected infections (by testing)

    - `system_data::Dict{String, Any}`
        - `kernel::String`: System kernel
        - `julia_version::String`: Julia version that was used to generate this data object
        - `word_size::Int64`: System word size
        - `threads::Int64`: Number of threads this Julia instance was started with
        - `cpu_data::Markdown.MD`: Information on the processor (not available for ARM Macs)
        - `total_mem_size::Float64`: Total system memory
        - `free_mem_size::Float64`: Available system memory
        - `git_repo::SubString{String}`: Current Git repository
        - `git_branch::SubString{String}`: Current Git branch
        - `git_commit::SubString{String}`: Current Git commit ID
        - `model_size::Int64`: Size of the simulation model in memory [CURRENTLY DACTIVATED]
        - `population_size::Int64`: Size of the population model in memory [CURRENTLY DACTIVATED]

    - `setting_age_contacts::Dict{String, Any}`
        - `Household`: age X age contact matrix for Households based on sampled data [CURRENTLY DACTIVATED]
        - `GlobalSetting`: age X age contact matrix for GlobalSettings based on sampled data [CURRENTLY DACTIVATED]
    
    - `aggregated_setting_age_contacts::Dict{String, Any}`
        - `Household::ContactMatrix{Float64}`: `age group` x `age group` "ContactMatrix" object for Households based on sampled data
        - `SchoolClass::ContactMatrix{Float64}`: `age group` x `age group` "ContactMatrix" object for SchoolClass based on sampled data
        - `School::ContactMatrix{Float64}`: `age group` x `age group` "ContactMatrix" object for School based on sampled data
        - `SchoolComplex::ContactMatrix{Float64}`: `age group` x `age group` "ContactMatrix" object for SchoolComplex based on sampled data
        - `Office::ContactMatrix{Float64}`: `age group` x `age group` "ContactMatrix" object for Office based on sampled data
        - `Department::ContactMatrix{Float64}`: `age group` x `age group` "ContactMatrix" object for Department based on sampled data
        - `Workplace::ContactMatrix{Float64}`: `age group` x `age group` "ContactMatrix" object for Workplace based on sampled data
        - `WorkplaceSite::ContactMatrix{Float64}`: `age group` x `age group` "ContactMatrix" object for WorkplaceSite based on sampled data
        - `Municipality::ContactMatrix{Float64}`: `age group` x `age group` "ContactMatrix" object for Municipality based on sampled data
        - `GlobalSetting::ContactMatrix{Float64}`: `age group` x `age group` "ContactMatrix" object for GlobalSetting based on sampled data

    - `dataframes::Dict{String, Any}`
        - `infections::DataFrame`: Infection data joined with individuals' attributes
        - `vaccinations::DataFrame`: Vaccination data joined with individuals' attributes
        - `deaths::DataFrame`: Death data joined with individuals' attributes
        - `tests::DataFrame`: Test data joined with individuals' attributes
        - `effectiveR::DataFrame`: Effective R value over time
        - `compartment_periods::DataFrame`: Duration of exposed and infectious states for all infections
        - `aggregated_compartment_periods::DataFrame`: Statistics on time individuals spend in each disease compartment
        - `tick_cases::DataFrame`: Infections per tick
        - `tick_deaths::DataFrame`: Deaths per tick
        - `tick_vaccinations::DataFrame`: Vaccinations per tick
        - `tick_serial_intervals::DataFrame`: Aggregated data on serial intervals per tick
        - `tick_generation_times::DataFrame`: Aggregated data on generation timess per tick        
        - `tick_tests::DataFrame`: Number of tests performed per tick
        - `tick_pooltests::DataFrame`: Number of (pooled) tests per tick
        - `tick_cases_per_setting::DataFrame`: Tick cases aggregated by settingtype,
        - `detected_tick_cases::DataFrame`: Number of detected infections per tick
        - `compartment_fill::DataFrame`: Number of individuals currently in any of the disease compartments
        - `cumulative_cases::DataFrame`: Cumulative infections over time
        - `cumulative_deaths::DataFrame`: Cumulative deaths over time
        - `cumulative_vaccinations::DataFrame`: Cumulative vaccinations over time
        - `cumulative_disease_progressions::DataFrame`: Cumulative information on disease states N ticks after exposure
        - `cumulative_quarantines::DataFrame`: Number of quarantined individuals per tick
        - `age_incidence::DataFrame`: Incidence over time stratified by age groups
        - `population_pyramid::DataFrame`: Data required to plot population pyramid (age, sex, count)
        - `rolling_observed_SI::DataFrame`: Serial interval estimation based on the last 14 days of detected cases
        - `observed_R::DataFrame`: Reproduction number estimation based on detected cases and the SI estimation
        - `hospital_df::DataFrame`: DataFrame containing the daily hospitalizations etc.
        - `time_to_detection::DataFrame`: Statistics on the time between exposure and first detection of an infection through a test
        - `household_attack_rates::DataFrame`: Statistics on the seconary infections in households
        - `customlogger::DataFrame`: Dataframe obtained from any custom logger that might have been set
"""
mutable struct DefaultResultData <: ResultDataStyle
    data::Dict{String, Any}
    function DefaultResultData(pP::PostProcessor)
        funcs = Dict(
            "meta_data" =>
                Dict(
                    "timer_output" => () -> TimerOutput(),
                    "execution_date" => () -> Dates.format(now(), "yyyy-mm-ddTHH:MM:SS"),
                    "GEMS_version" => () -> PkgVersion.Version(GEMS),
                    "config_file" => () -> pP |> simulation |> configfile,
                    "config_file_val" => () -> isfile(pP |> simulation |> configfile) ? TOML.parsefile(pP |> simulation |> configfile) : Dict(), #TODO potentially adapt for no config file
                    "population_file" => () -> pP |> simulation |> populationfile,
                    "population_params" => () -> pP |> simulation |> population |> params
                ),
            "sim_data" =>
                Dict(
                    "label" => () -> pP |> simulation |> label,
                    "final_tick" => () -> pP |> simulation |> tick,
                    "number_of_individuals" => () -> pP |> simulation |> population |> individuals |> length,
                    "initial_infections" => () -> (pP |> infectionsDF |> nrow) - (pP |> sim_infectionsDF |> nrow),
                    "total_infections" => () -> pP |> infectionsDF |> nrow,
                    "attack_rate" => () -> pP |> attack_rate,
                    "setting_data" => () -> pP |> settingdata,
                    "setting_sizes" => () -> pP |> setting_sizes,
                    "region_info" => () -> pP |> simulation |> region_info,
                    "pathogens" => () -> [pP |> simulation |> pathogen],
                    "tick_unit" => () -> pP |> simulation |> tickunit,
                    "start_condition" => () -> pP |> simulation |> start_condition,
                    "stop_criterion" =>  () -> pP |> simulation |> stop_criterion,
                    "strategies" => () -> pP |> simulation |> strategies,
                    "symptom_triggers" => () -> pP |> simulation |> symptom_triggers,
                    "testtypes" => () -> pP |> simulation |> testtypes,
                    "total_quarantines" => () -> pP |> total_quarantines,
                    "total_tests" => () -> pP |> total_tests,
                    "detection_rate" => () -> pP |> detection_rate
                ),
            
            # system data
            "system_data" => 
                Dict(
                    "kernel" => () -> String(Base.Sys.KERNEL) * String(Base.Sys.MACHINE),
                    "julia_version" => () -> string(Base.VERSION),
                    "word_size" => () -> Base.Sys.WORD_SIZE,
                    "threads" => () -> Threads.nthreads(),
                    "cpu_data" => () -> cpudata(),
                    "total_mem_size" => () -> round(Sys.total_memory()/2^20, digits = 2),
                    "free_mem_size" => () -> round(Sys.free_memory()/2^20, digits = 2),
                    "git_repo" => () -> read_git_repo(),
                    "git_branch" => () -> read_git_branch(),
                    "git_commit" => () -> read_git_commit()#,
                    #"model_size" => round(Base.summarysize(pP |> simulation)/2^20, digits = 2),
                    #"population_size" => round(Base.summarysize(population(pP |> simulation))/2^20, digits = 2),
                ),

            "setting_age_contacts" =>
                Dict(
                    #"Household" => () -> setting_age_contacts(pP, Household),
                    #"GlobalSetting" => () -> setting_age_contacts(pP, GlobalSetting),
                ),

            "aggregated_setting_age_contacts" =>
                Dict(
                    # TODO: interval_steps shouldn't be hard coded. They rather should be defined in the config file.
                    # TODO: This list should be determined dynamically depending on what settings are present in the simulation
                    "Household" => () -> mean_contacts_per_age_group(pP, Household, 5),
                    "SchoolClass" => () -> mean_contacts_per_age_group(pP, SchoolClass, 2),
                    "SchoolYear" => () -> mean_contacts_per_age_group(pP, SchoolYear, 2),
                    "School" => () -> mean_contacts_per_age_group(pP, School, 2),
                    "SchoolComplex" => () -> mean_contacts_per_age_group(pP, SchoolComplex, 2),
                    "Office" => () -> mean_contacts_per_age_group(pP, Office, 5), 
                    "Department" => () -> mean_contacts_per_age_group(pP, Department, 5), 
                    "Workplace" => () -> mean_contacts_per_age_group(pP, Workplace, 5), 
                    "WorkplaceSite" => () -> mean_contacts_per_age_group(pP, WorkplaceSite, 5), 
                    "Municipality" => () -> mean_contacts_per_age_group(pP, Municipality, 5),
                    "GlobalSetting" => () -> mean_contacts_per_age_group(pP, GlobalSetting, 5)
                ),

            "dataframes" =>
                Dict(
                    "infections" => () -> pP |> infectionsDF,
                    "deaths" => () -> pP |> deathsDF,
                    "tests" => () -> pP |> testsDF,
                    "effectiveR" => () -> pP |> effectiveR,
                    "compartment_periods" => () -> pP |> compartment_periods,
                    "aggregated_compartment_periods" => () -> pP |> aggregated_compartment_periods,
                    "tick_cases" => () -> pP |> tick_cases,
                    "tick_deaths" => () -> pP |> tick_deaths,
                    "tick_serial_intervals" => () -> pP |> tick_serial_intervals,
                    "tick_generation_times" => () -> pP |> tick_generation_times,
                    "cumulative_cases" => () -> pP |> cumulative_cases,
                    "compartment_fill" => () -> pP |> compartment_fill,
                    "cumulative_deaths" => () -> pP |> cumulative_deaths,
                    "age_incidence" => () -> age_incidence(pP, 7, 100_000),
                    "population_pyramid" => () -> pP |> population_pyramid,
                    "cumulative_disease_progressions" => () -> pP |> cumulative_disease_progressions,
                    "cumulative_quarantines" => () -> pP |> cumulative_quarantines,
                    "tick_tests" => () -> pP |> tick_tests,
                    "tick_pooltests" => () -> pP |> tick_pooltests,
                    "detected_tick_cases" => () -> pP |> detected_tick_cases,
                    "rolling_observed_SI" => () -> pP |> rolling_observed_SI,
                    "observed_R" => () -> pP |> observed_R,
                    "time_to_detection" => () -> pP |> time_to_detection,
                    "tick_cases_per_setting" => () -> pP |> tick_cases_per_setting,
                    "customlogger" => () -> pP |> simulation |> customlogger |> dataframe,
                    "household_attack_rates" => () -> pP |> household_attack_rates
                )      
        )

        # call all provided functions and replace
        # the dicts with their return values
        return(
            new(process_funcs(funcs))
        )
    end
end