export EssentialResultData

"""
    EssentialResultData <: ResultDataStyle

This style only includes the essential fields. It includes all the fields necessary
to generate an arbitrary field during the import function.
"""
mutable struct EssentialResultData <: ResultDataStyle
    data::Dict{String, Any}
    function EssentialResultData(pP::PostProcessor)
        funcs = Dict(
            "meta_data" =>
                Dict(
                    "config_file" => () -> pP |> simulation |> configfile,
                    "config_file_val" => () -> isfile(pP |> simulation |> configfile) ? TOML.parsefile(pP |> simulation |> configfile) : Dict(), #TODO potentially adapt for no config file
                    "population_file" => () -> pP |> simulation |> populationfile
                ),
            "sim_data" =>
                Dict(
                "label" => () -> pP |> simulation |> label,     
                "final_tick" => () -> pP |> simulation |> tick
                ),
            "dataframes" =>
                Dict(
                    "infections" => () -> pP |> infectionsDF,
                    "deaths" => () -> pP |> deathsDF,
                    "tests" => () -> pP |> testsDF,
                    "cumulative_quarantines" => () -> pP |> cumulative_quarantines,
                )         
        )
        
        # call all provided functions and replace
        # the dicts with their return values
        return(
            new(process_funcs(funcs))
        )
    end
end