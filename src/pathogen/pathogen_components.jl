export transmission_probability
export transmission_functions
export progression_categories
export progression_assignments
export infectiousness
export calculate_immunity
export immunity_is_stable

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

# includde infectiousness
include(basefolder() * "/src/pathogen/infectiousness_profile.jl")
include(basefolder() * "/src/pathogen/immunity_profile.jl")



### ABSTRACT INTERFACE

# fallback for assign functions
function assign(individual::Individual, pa_func::ProgressionAssignmentFunction, rng::Xoshiro)
    @error "The assign function is not defined for the provided ProgressionAssignmentFunction struct $(typeof(pa_func))."
end





# fallback for tranmission functions
function transmission_probability(transFunc::TransmissionFunction, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16)::Float64
    @error "The transmission_probability function is not defined for the provided TransmissionFunction struct $(typeof(transFunc))."
end

"""
    transmission_probability(transFunc::TransmissionFunction, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, rng::Xoshiro)

General function for TransmissionFunction struct. Should be overwritten for newly created structs, as it only serves
to catch undefined `transmission_probability` functions.
"""
function transmission_probability(transFunc::TransmissionFunction, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, rng::Xoshiro)::Float64
    # this is the fallback function that is called if no of the specific transmission_proability
    # functions has already fired. In that case, we try finding a transmission_probability
    # function without a dedicated RNG passed. If that doesn't work, the default 
    # TF-function (above) will trigger an error
    return transmission_probability(transFunc, pathogen_id, infecter, infectee, setting, tick)
end

"""
    infectiousness(profile::InfectiousnessProfile, state::InfectionState, t::Int16)::Int8

This fallback raises an error; any concrete subtype must provide its own method.
"""
function infectiousness(profile::InfectiousnessProfile, ::InfectionState, ::Int16)::Int8
    @error "infectiousness is not implemented for InfectiousnessProfile type $(typeof(profile))."
    return Int8(0)
end

"""
    calculate_immunity(profile::ImmunityProfile, state::ImmunityState, tick::Int16)::Int8

This fallback raises an error; any concrete subtype must provide its own method.
"""
function calculate_immunity(profile::ImmunityProfile, ::ImmunityState, ::Int16)::Int8
    @error "calculate_immunity is not implemented for ImmunityProfile type $(typeof(profile))."
    return Int8(0)
end

"""
    immunity_is_stable(profile::ImmunityProfile, state::ImmunityState, tick::Int16)::Bool

Returns `true` if the immunity level produced by `profile` for the given `state` at `tick`
is guaranteed not to change in any future tick, allowing the per-individual immunity cache
to skip recomputation. Falls back to `false` for any profile that does not provide a
concrete method, which is always safe.
"""
immunity_is_stable(::ImmunityProfile, ::ImmunityState, ::Int16)::Bool = false


"""
    progressions()

Returns all known progression categories (subtypes of `ProgressionCategory`).
"""
progression_categories() = subtypes(ProgressionCategory)


"""
    progression_assignments()

Returns all known progression assignment functions (subtypes of `ProgressionAssignmentFunction`).
"""
progression_assignments() = subtypes(ProgressionAssignmentFunction)

"""
    transmission_functions()

Returns all known transmission functions (subtypes of `TransmissionFunction`).
"""
transmission_functions() = subtypes(TransmissionFunction)



# JP TODO: Add abstract interface for progression assignments and progression categories