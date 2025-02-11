export OptimisedResultData

"""
    OptimisedResultData <: ResultDataStyle

The fields are equal to those of the `DefaultResultData` except for the 
computationally intensive `population_size` and `model_size` fields.
"""
mutable struct OptimisedResultData <: ResultDataStyle
    data::Dict{String, Any}
    function OptimisedResultData(pP::PostProcessor)
        funcs = Dict(
            "meta_data" =>
                Dict(
                    "execution_date" => () -> Dates.format(now(), "yyyy-mm-ddTHH:MM:SS"),
                    "GEMS_version" => () -> PkgVersion.Version(GEMS),
                    "config_file" => () -> pP |> simulation |> configfile,
                    "config_file_val" => () -> isfile(pP |> simulation |> configfile) ? TOML.parsefile(pP |> simulation |> configfile) : Dict(), #TODO potentially adapt for no config file
                    "population_file" => () -> pP |> simulation |> populationfile,
                    "timer_output" => () -> TimerOutput()
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
                    "pathogens" => () -> [pP |> simulation |> pathogen],
                    "tick_unit" => () -> pP |> simulation |> tickunit,
                    "start_condition" => () -> pP |> simulation |> start_condition,
                    "stop_criterion" =>  () -> pP |> simulation |> stop_criterion
                ),
            "setting_age_contacts" =>
            Dict(
                "Household" => () -> setting_age_contacts(pP, Household),
                "GlobalSetting" => () -> setting_age_contacts(pP, GlobalSetting),
            ),

            "aggregated_setting_age_contacts" =>
                Dict(
                    # TODO: interval_steps shouldn't be hard coded. They rather should be defined in the config file.
                    "Household" => () -> mean_contacts_per_age_group(pP, Household, 10) 
                ),
            
            "system_data" =>
                Dict(
                "kernel" => () -> String(Base.Sys.KERNEL) * String(Base.Sys.MACHINE),
                "julia_version" => () -> string(Base.VERSION),
                "threads" => () -> Threads.nthreads(),
                "cpu_data" => () -> cpudata(),
                "git_repo" => () -> read_git_repo(),
                "git_branch" => () -> read_git_branch(),
                "git_commit" => () -> read_git_commit(),
                ),

            "dataframes" =>
                Dict(
                    "infections" => () -> pP |> infectionsDF,
                    "deaths" => () -> pP |> deathsDF,
                    "tests" => () -> pP |> testsDF,
                    "effectiveR" => () -> pP |> effectiveR,
                    "compartment_periods" => () -> pP |> compartment_periods,
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
                    "customlogger" => () -> pP |> simulation |> customlogger |> dataframe
                )        
        )
        
        # call all provided functions and replace
        # the dicts with their return values
        return(
            new(process_funcs(funcs))
        )
    end
end