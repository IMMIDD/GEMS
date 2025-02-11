export setting_sizes

""" 
    setting_sizes(postProcessor::PostProcessor)

Returns a `Dictionary` containing information about size of the settings.
The keys are equal to the settingtypes and the values correspond to a countmap
of the setting sizes.

# Returns

- `Dict{String, Dict{Int64, Int64}}`: Nested dictionary where the first key is the 
    name of the setting type (e.g., "Household") and the innter dictionary is a
    countmap with the key being a setting size (e.g., 5) and the value the number of occurences.

"""
function setting_sizes(postProcessor::PostProcessor)

    dic = Dict()
    for (type, stngs) in postProcessor |> simulation |> settings
        if length(stngs) != 0
            dic[string(type)]= countmap([individuals(x, postProcessor |> simulation) |> length for x in stngs])
        end
    end

    return(dic)
end