export transmission_probability
export transmission_factor
export effective_transmission_probability
export transmission_functions
export progression_categories
export progression_assignments
export health_progressions
export calculate_infectiousness
export calculate_immunity
export immunity_is_stable
export susceptibility_factor

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
dir = _basefolder() * "/src/pathogen/progression_categories"

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
dir = _basefolder() * "/src/pathogen/progression_assignments"

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
dir = _basefolder() * "/src/pathogen/transmission_functions"

include.(
    filter(
        contains(r".jl$"),
        readdir(dir; join=true)
    )
)

# includde infectiousness
include(_basefolder() * "/src/pathogen/infectiousness_profile.jl")
include(_basefolder() * "/src/pathogen/immunity_profile.jl")



### ABSTRACT INTERFACE

# fallback for assign functions
function assign(individual::Individual, pa_func::ProgressionAssignmentFunction, rng::Xoshiro)
    error("The assign function is not defined for the provided ProgressionAssignmentFunction struct $(typeof(pa_func)).")
end

"""
    assign(individual::Individual, pa_func::ProgressionAssignmentFunction, sim::Union{Simulation, Nothing}, pathogen_id::Int8, tick::Int16, rng::Xoshiro)

Entry point called by `infect!`, with `sim` `nothing` outside a simulation; falls through to the registry form.
Read the infectee's immunity with `immunity_level(individual, sim, pathogen_id, tick)` or `each_immunity(individual, sim)`.
"""
assign(individual::Individual, pa_func::ProgressionAssignmentFunction, sim::Union{Simulation, Nothing}, pathogen_id::Int8, tick::Int16, rng::Xoshiro) =
    assign(individual, pa_func, isnothing(sim) ? ImmunityRegistry() : immunity_registry(sim, individual), pathogen_id, rng)

"""
    assign(individual::Individual, pa_func::ProgressionAssignmentFunction, immunities::ImmunityRegistry, pathogen_id::Int8, rng::Xoshiro)

Deprecated: override the form with `sim` and `tick`, which can read immunity levels. Still called for
existing methods; falls through to the three-argument `assign`.
"""
assign(individual::Individual, pa_func::ProgressionAssignmentFunction, immunities::ImmunityRegistry, pathogen_id::Int8, rng::Xoshiro) =
    assign(individual, pa_func, rng)


# Fallback translating internal positional calls into the keyword form used by
# user-defined ProgressionCategories.
function calculate_progression(individual::Individual, tick::Int16, dp::ProgressionCategory, rng::Xoshiro)
    return calculate_progression(individual, tick, dp; rng=rng)
end

"""
    calculate_progression(individual::Individual, tick::Int16, dp::ProgressionCategory, sim::Union{Simulation, Nothing}, pathogen_id::Int8, rng::Xoshiro)

Entry point called by `infect!`, with `sim` `nothing` outside a simulation; falls through to the registry form.
Read the infectee's immunity with `immunity_level(individual, sim, pathogen_id, tick)` or `each_immunity(individual, sim)`.
"""
calculate_progression(individual::Individual, tick::Int16, dp::ProgressionCategory, sim::Union{Simulation, Nothing}, pathogen_id::Int8, rng::Xoshiro) =
    calculate_progression(individual, tick, dp, isnothing(sim) ? ImmunityRegistry() : immunity_registry(sim, individual), pathogen_id, rng)

"""
    calculate_progression(individual::Individual, tick::Int16, dp::ProgressionCategory, immunities::ImmunityRegistry, pathogen_id::Int8, rng::Xoshiro)

Deprecated: override the form with `sim`, which can read immunity levels. Still called for existing
methods; falls through to the four-argument `calculate_progression`.
"""
calculate_progression(individual::Individual, tick::Int16, dp::ProgressionCategory, immunities::ImmunityRegistry, pathogen_id::Int8, rng::Xoshiro) =
    calculate_progression(individual, tick, dp, rng)





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
`base_rate × infectiousness/100 × susceptibility_factor(immunity_profile, immunity_level)`.

How much the infectee's immunity reduces the probability is decided by the pathogen's
`ImmunityProfile` via `susceptibility_factor`, which defaults to `1 − immunity/100`.

Throws an `ArgumentError` if the infecter has zero infectiousness for `pathogen_id`.

Override this (instead of `transmission_probability`) only when full control is needed,
e.g. to handle infectiousness differently. To change only how immunity acts on transmission,
override `susceptibility_factor` instead.
"""
function effective_transmission_probability(transFunc::TransmissionFunction, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, sim::Simulation, rng::Xoshiro)::Float64
    inf = infectiousness(infecter, sim, pathogen_id)
    inf == 0 && throw(ArgumentError("Infecting individual must have nonzero infectiousness to calculate transmission probability."))
    state = get_immunity_state(infectee, sim, pathogen_id)
    susceptibility = _with_pathogen(sim.pathogens, pathogen_id) do p
        level = _immunity_recorded(state) ? _immunity_level(p, state, infectee, sim, tick) : Int8(0)
        susceptibility_factor(immunity_profile(p), level)
    end
    return transmission_probability(transFunc, pathogen_id, infecter, infectee, setting, tick, sim, rng) *
           inf / 100.0 *
           susceptibility
end

"""
    effective_transmission_probability(transFunc::TransmissionFunction, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, sim::Simulation)::Float64

Convenience wrapper without explicit RNG that delegates to the rng-accepting overload using `default_gems_rng()`.
"""
effective_transmission_probability(transFunc::TransmissionFunction, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, sim::Simulation)::Float64 =
    effective_transmission_probability(transFunc, pathogen_id, infecter, infectee, setting, tick, sim, default_gems_rng())

"""
    calculate_infectiousness(profile::InfectiousnessProfile, state::InfectionState, individual::Individual, tick::Int16, rng::Xoshiro)::Int8

Returns the infectiousness (0-100) of the infection `state` at `tick`; concrete profiles must implement it.
`rng` draws the same numbers for the whole infection; re-key it per tick with `infectiousness_rng!`.
"""
function calculate_infectiousness(profile::InfectiousnessProfile, state::InfectionState, individual::Individual, tick::Int16, rng::Xoshiro)::Int8
    error("calculate_infectiousness is not implemented for InfectiousnessProfile type $(typeof(profile)).")
end

"""
    calculate_immunity(profile::ImmunityProfile, state::ImmunityState, individual::Individual, tick::Int16, rng::Xoshiro)::Int8

Returns the immunity level (0-100) of `state` at `tick`; called on every read from any thread, so it must be
cheap and deterministic and must not yield or read other levels. `rng` draws the same numbers on every read for
this host and pathogen; re-key it per acquisition with `immunity_rng!`.
"""
function calculate_immunity(profile::ImmunityProfile, state::ImmunityState, individual::Individual, tick::Int16, rng::Xoshiro)::Int8
    error("calculate_immunity is not implemented for ImmunityProfile type $(typeof(profile)).")
end

"""
    calculate_immunity(profile::ImmunityProfile, state::ImmunityState, individual::Individual, tick::Int16)::Int8

For profiles that don't draw: passes the unkeyed `default_gems_rng()`, so draws differ from reads
during a simulation.
"""
@inline function calculate_immunity(profile::ImmunityProfile, state::ImmunityState, individual::Individual, tick::Int16)::Int8
    return calculate_immunity(profile, state, individual, tick, default_gems_rng())
end

"""
    immunity_is_stable(profile::ImmunityProfile, state::ImmunityState, individual::Individual, tick::Int16)::Bool

Deprecated and unused: levels are computed on read. Kept so existing methods compile.
"""
immunity_is_stable(profile::ImmunityProfile, state::ImmunityState, individual::Individual, tick::Int16)::Bool = false

"""
    susceptibility_factor(profile::ImmunityProfile, level::Int8)::Float64

Returns the factor in `[0, 1]` by which an immunity `level` (0-100) scales the per-contact
transmission probability. Defaults to `1 - level/100`. Override it to have immunity act
elsewhere than on transmission: `1.0` leaves the level readable by the rest of the model
(e.g. a progression assignment that attenuates severity) without affecting transmission.
"""
susceptibility_factor(profile::ImmunityProfile, level::Int8)::Float64 = 1.0 - level / 100.0


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

"""
    health_progressions()

Returns all known health progressions (subtypes of `HealthProgression`).
"""
health_progressions() = subtypes(HealthProgression)



# JP TODO: Add abstract interface for progression assignments and progression categories