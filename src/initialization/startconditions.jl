export start_conditions
export MultiStartCondition

"""
    MultiStartCondition <: StartCondition

A composite `StartCondition` that wraps multiple individual start conditions,
one per pathogen. Each sub-condition is initialized in order.
"""
struct MultiStartCondition <: StartCondition
    conditions::Vector{StartCondition}

    function MultiStartCondition(conditions::Vector{<:StartCondition})
        isempty(conditions) && throw(ArgumentError("At least one StartCondition must be provided."))
        return new(conditions)
    end
end

function initialize!(simulation::Simulation, condition::MultiStartCondition; kwargs...)
    for sc in condition.conditions
        initialize!(simulation, sc; kwargs...)
    end
end


Base.show(io::IO, c::MultiStartCondition) = write(io, "MultiStartCondition($(join(c.conditions, ", ")))")

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