export transmission_probability
export effective_transmission_probability
export transmission_functions
export progression_categories
export progression_assignments
export calculate_infectiousness
export calculate_immunity
export immunity_is_stable

# the main defintion of pathogens is in src/pathogen/pathogens.jl


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





"""
    transmission_probability(transFunc::TransmissionFunction, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, sim::Simulation)::Float64

Convenience wrapper without explicit RNG that delegates to the rng-accepting overload using `default_gems_rng()`.
"""
function transmission_probability(transFunc::TransmissionFunction, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, sim::Simulation)::Float64
    return transmission_probability(transFunc, pathogen_id, infecter, infectee, setting, tick, sim, default_gems_rng())
end

"""
    transmission_probability(transFunc::TransmissionFunction, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, sim::Simulation, rng::Xoshiro)::Float64

Fallback that raises an error. Every concrete `TransmissionFunction` subtype must implement
its own `transmission_probability` method returning the base transmission rate only,
without infectiousness or immunity scaling. The framework applies those automatically via
`effective_transmission_probability`.
"""
function transmission_probability(transFunc::TransmissionFunction, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, sim::Simulation, rng::Xoshiro)::Float64
    error("transmission_probability is not implemented for $(typeof(transFunc)).")
end

"""
    effective_transmission_probability(transFunc::TransmissionFunction, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, sim::Simulation, rng::Xoshiro)::Float64

Framework entry point called by the simulation loop. Applies infectiousness and standard
immunity exactly once around the base rate from `transmission_probability`:
`base_rate × infectiousness/100 × (1 − immunity/100)`.

Throws an `ArgumentError` if the infecter has zero infectiousness for `pathogen_id`.

Override this (instead of `transmission_probability`) only when full control is needed,
e.g. to bypass the standard immunity model or handle infectiousness differently.
"""
function effective_transmission_probability(transFunc::TransmissionFunction, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, sim::Simulation, rng::Xoshiro)::Float64
    infectiousness(infecter, pathogen_id, sim) == 0 && throw(ArgumentError("Infecting individual must have nonzero infectiousness to calculate transmission probability."))
    return transmission_probability(transFunc, pathogen_id, infecter, infectee, setting, tick, sim, rng) *
           infectiousness(infecter, pathogen_id, sim) / 100.0 *
           (1.0 - immunity_level(infectee, pathogen_id, sim) / 100.0)
end

"""
    effective_transmission_probability(transFunc::TransmissionFunction, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, sim::Simulation)::Float64

Convenience wrapper without explicit RNG that delegates to the rng-accepting overload using `default_gems_rng()`.
"""
effective_transmission_probability(transFunc::TransmissionFunction, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, sim::Simulation)::Float64 =
    effective_transmission_probability(transFunc, pathogen_id, infecter, infectee, setting, tick, sim, default_gems_rng())

"""
    calculate_infectiousness(profile::InfectiousnessProfile, state::InfectionState, individual::Individual, tick::Int16, rng::Xoshiro)::Int8

This fallback raises an error; any concrete subtype must provide its own method.
"""
function calculate_infectiousness(profile::InfectiousnessProfile, state::InfectionState, individual::Individual, tick::Int16, rng::Xoshiro)::Int8
    @error "calculate_infectiousness is not implemented for InfectiousnessProfile type $(typeof(profile))."
    return Int8(0)
end

"""
    calculate_immunity(profile::ImmunityProfile, state::ImmunityState, individual::Individual, tick::Int16, rng::Xoshiro)::Int8

This fallback raises an error; any concrete subtype must provide its own method.
"""
function calculate_immunity(profile::ImmunityProfile, state::ImmunityState, individual::Individual, tick::Int16, rng::Xoshiro)::Int8
    @error "calculate_immunity is not implemented for ImmunityProfile type $(typeof(profile))."
    return Int8(0)
end

"""
    calculate_immunity(profile::ImmunityProfile, state::ImmunityState, individual::Individual, tick::Int16)::Int8

Fallback for `ImmunityProfile` that doesn't need an RNG.
"""
@inline function calculate_immunity(profile::ImmunityProfile, state::ImmunityState, individual::Individual, tick::Int16)::Int8
    return calculate_immunity(profile, state, individual, tick, default_gems_rng())
end

"""
    immunity_is_stable(profile::ImmunityProfile, state::ImmunityState, individual::Individual, tick::Int16)::Bool

Returns `true` if the immunity level produced by `profile` for the given `state` at `tick`
is guaranteed not to change in any future tick, allowing the per-individual immunity cache
to skip recomputation. Falls back to `false` for any profile that does not provide a
concrete method, which is always safe.
"""
immunity_is_stable(profile::ImmunityProfile, state::ImmunityState, individual::Individual, tick::Int16)::Bool = false


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