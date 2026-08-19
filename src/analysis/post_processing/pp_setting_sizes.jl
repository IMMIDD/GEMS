export setting_sizes

"""
    _get_size(indivs, x::T, sim) where T

Internal function barrier to efficiently calculate the number of individuals in a setting `x`. This resolves potential type instabilities when iterating over settings.
"""
function _get_size(indivs, x::T, sim) where T
    empty!(indivs)
    individuals!(indivs, x, sim)
    return length(indivs)
end

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
    indivs = sim.present_buffers[Threads.threadid()]

    for (type, stngs) in settings(sim)
        if !isempty(stngs)
            dic[string(type)] = countmap(_get_size(indivs, x, sim) for x in stngs)
        end
    end
    return dic
end
