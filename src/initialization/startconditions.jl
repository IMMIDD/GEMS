export start_conditions

###
### INCLUDE START CONDITIONS
###

# The src/initialization/start_conditions folder contains a dedicated file
# for each start condition. Files starting with "sc_" are
# StartCondition structs.
# If you want to set up a new start condition, simply add a file to the folder and
# make sure to define the new struct and the required initialize!()-function.

# include all Julia files from the "start_conditions"-folder
dir = basefolder() * "/src/initialization/start_conditions"

include.(
    filter(
        contains(r".jl$"),
        readdir(dir; join=true)
    )
)

"""
    start_conditions()::Vector{DataType}

Returns a vector of all available StartCondition subtypes.
"""
start_conditions() = subtypes(StartCondition)