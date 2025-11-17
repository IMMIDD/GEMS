export transmission_probability

# the main defintion of pathogens is in src/structs/parameters/pathogens.jl


###
### INCLUDE PROGRESSION CATEGORIES
###

# The src/pathogen/progression_categories folder contains a dedicated file
# for each progresion category. Files starting with "pc_" are
# ProgressionCategory functions.
# If you want to set up a new disease progression category, simply add a file to the folder and
# make sure to define the function.

# include all Julia files from the "progression_categories"-folder
dir = basefolder() * "/src/pathogen/progression_categories"

include.(
    filter(
        contains(r".jl$"),
        readdir(dir; join=true)
    )
)


###
### INCLUDE PROGRESSION ASSIGNMENT FUNCTIONS
###

# The src/pathogen/progression_assignments folder contains a dedicated file
# for each progression assignment function. Files starting with "pa_" are
# ProgressionAssignment functions.
# If you want to set up a new progression assignment function, simply add a file to the folder and
# make sure to define the function.

# include all Julia files from the "progression_assignment"-folder
dir = basefolder() * "/src/pathogen/progression_assignments"

include.(
    filter(
        contains(r".jl$"),
        readdir(dir; join=true)
    )
)


###
### INCLUDE TRANSMISSION FUNCTIONS
###

# The src/pathogen/transmission_functions folder contains a dedicated file
# for each transmission function. Files starting with "tf_" are
# Transmission functions.
# If you want to set up a new transmission function, simply add a file to the folder and
# make sure to define the function.

# include all Julia files from the "transmission_functions"-folder
dir = basefolder() * "/src/pathogen/transmission_functions"

include.(
    filter(
        contains(r".jl$"),
        readdir(dir; join=true)
    )
)



### ABSTRACT INTERFACE

# fallback for assign functions
function assign(individual::Individual, pa_func::ProgressionAssignmentFunction, rng::AbstractRNG)
    @error "The assign function is not defined for the provided ProgressionAssignmentFunction struct $(typeof(pa_func))."
end





# fallback for tranmission functions
function transmission_probability(transFunc::TransmissionFunction, infecter::Individual, infected::Individual, setting::Setting, tick::Int16)::Float64
    @error "The transmission_probability function is not defined for the provided TransmissionFunction struct $(typeof(transFunc))."
end

"""
    transmission_probability(transFunc::TransmissionFunction, infecter::Individual, infected::Individual, setting::Setting, tick::Int16; rng::AbstractRNG = Random.default_rng())

General function for TransmissionFunction struct. Should be overwritten for newly created structs, as it only serves
to catch undefined `transmission_probability` functions.
"""
function transmission_probability(transFunc::TransmissionFunction, infecter::Individual, infected::Individual, setting::Setting, tick::Int16, rng::AbstractRNG)::Float64
    # this is the fallback function that is called if no of the specific transmission_proability
    # functions has already fired. In that case, we try finding a transmission_probability
    # function without a dedicated RNG passed. If that doesn't work, the default 
    # TF-function (above) will trigger an error
    return transmission_probability(transFunc, infecter, infected, setting, tick)
end

"""
    transmission_functions()

Returns all known transmission functions (subtypes of `TransmissionFunction`).
"""
transmission_functions() = subtypes(TransmissionFunction)


# JP TODO: Add abstract interface for progression assignments and progression categories