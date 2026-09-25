export setting_sizes

# A countmap of the settings' sizes, counted without copying their members. A function barrier,
# so the loop is compiled for the concrete setting type.
_setting_size_counts(stngs::Vector, sim) = countmap(size(x, sim) for x in stngs)

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
    sim = simulation(postProcessor)

    for (type, stngs) in settings(sim)
        if !isempty(stngs)
            dic[string(type)] = _setting_size_counts(stngs, sim)
        end
    end
    return dic
end
