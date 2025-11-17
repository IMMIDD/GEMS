export start_conditions

###
### INCLUD STOP CRITERIA
###

# The src/termination/stop_criteria folder contains a dedicated file
# for each stopping criterion. Files starting with "sc_" are
# StopCriteria structs.
# If you want to set up a new stop criterion, simply add a file to the folder and
# make sure to define the new struct and the required evaluate()-function.

# include all Julia files from the "stop_criteria"-folder
dir = basefolder() * "/src/termination/stop_criteria"

include.(
    filter(
        contains(r".jl$"),
        readdir(dir; join=true)
    )
)

"""
    stop_criteria()::Vector{DataType}

Returns a vector of all available StopCriterion subtypes.
"""
stop_criteria() = subtypes(StopCriterion)