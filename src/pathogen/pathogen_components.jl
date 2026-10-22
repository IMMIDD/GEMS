export transmission_probability
export transmission_factor
export effective_transmission_probability
export transmission_functions
export progression_categories
export progression_assignments
export health_progressions
export calculate_infectiousness
export next_infectiousness_change, next_tick_after
export calculate_immunity
export immunity_is_stable
export susceptibility_factor
export max_transmission_probability, max_transmission_probability_in_type
export max_transmission_factor, max_transmission_factor_in_type
export susceptibility_bound

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

Convenience wrapper without explicit RNG that delegates to the rng-accepting overload using a fresh `Xoshiro()`.
"""
function transmission_probability(transFunc::TransmissionFunction, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, sim::Simulation)::Float64
    return transmission_probability(transFunc, pathogen_id, infecter, infectee, setting, tick, sim, Xoshiro())
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
    max_transmission_probability(transFunc::TransmissionFunction, pathogen_id::Int8, infecter::Individual, setting::Setting, tick::Int16, sim::Simulation)::Float64

Upper bound on `transmission_probability` over every possible infectee in `setting`. Defaults to
`max_transmission_probability_in_type`, or `1.0` without one, which disables transmission pre-thinning.
"""
function max_transmission_probability(transFunc::TransmissionFunction, pathogen_id::Int8, infecter::Individual, setting::Setting, tick::Int16, sim::Simulation)::Float64
    p = max_transmission_probability_in_type(transFunc, pathogen_id, infecter, typeof(setting), tick, sim)
    return isinf(p) ? 1.0 : p
end

"""
    max_transmission_probability_in_type(transFunc::TransmissionFunction, pathogen_id::Int8, infecter::Individual, ::Type{S}, tick::Int16, sim::Simulation) where {S<:Setting}

Upper bound on `max_transmission_probability` over every setting of type `S`. Defaults to `Inf`,
which the effective bound caps at `1.0`.
"""
max_transmission_probability_in_type(transFunc::TransmissionFunction, pathogen_id::Int8, infecter::Individual, ::Type{S}, tick::Int16, sim::Simulation) where {S<:Setting} = Inf

"""
    max_transmission_factor(modifier::TransmissionModifier, pathogen_id::Int8, infecter::Individual, setting::Setting, tick::Int16, sim::Simulation)::Float64

Upper bound on `transmission_factor` over every possible infectee in `setting`. Defaults to
`max_transmission_factor_in_type`.
"""
max_transmission_factor(modifier::TransmissionModifier, pathogen_id::Int8, infecter::Individual, setting::Setting, tick::Int16, sim::Simulation)::Float64 =
    max_transmission_factor_in_type(modifier, pathogen_id, infecter, typeof(setting), tick, sim)

"""
    max_transmission_factor_in_type(modifier::TransmissionModifier, pathogen_id::Int8, infecter::Individual, ::Type{S}, tick::Int16, sim::Simulation) where {S<:Setting}

Upper bound on `max_transmission_factor` over every setting of type `S`. Defaults to `Inf`, as a
modifier may raise the probability.
"""
max_transmission_factor_in_type(modifier::TransmissionModifier, pathogen_id::Int8, infecter::Individual, ::Type{S}, tick::Int16, sim::Simulation) where {S<:Setting} = Inf

"""
    effective_transmission_probability(transFunc::TransmissionFunction, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, sim::Simulation, rng::Xoshiro)::Float64

Framework entry point called by the simulation loop. Applies infectiousness and standard
immunity exactly once around the base rate from `transmission_probability`:
`min(base_rate, 1) × infectiousness/100 × susceptibility_factor(immunity_profile, immunity_level)`.

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
    return min(1.0, transmission_probability(transFunc, pathogen_id, infecter, infectee, setting, tick, sim, rng)) *
           inf / 100.0 *
           susceptibility
end

"""
    effective_transmission_probability(transFunc::TransmissionFunction, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, sim::Simulation)::Float64

Convenience wrapper without explicit RNG that delegates to the rng-accepting overload using a fresh `Xoshiro()`.
"""
effective_transmission_probability(transFunc::TransmissionFunction, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, sim::Simulation)::Float64 =
    effective_transmission_probability(transFunc, pathogen_id, infecter, infectee, setting, tick, sim, Xoshiro())

"""
    max_effective_transmission_probability(transFunc::TransmissionFunction, pathogen_id::Int8, infecter::Individual, setting::Setting, tick::Int16, sim::Simulation)::Float64

Upper bound on `effective_transmission_probability` over every possible infectee in `setting`, at most `1.0`.
"""
function max_effective_transmission_probability(transFunc::TransmissionFunction, pathogen_id::Int8, infecter::Individual, setting::Setting, tick::Int16, sim::Simulation)::Float64
    profile = immunity_profile(get_pathogen(sim, pathogen_id))
    p = max_transmission_probability(transFunc, pathogen_id, infecter, setting, tick, sim) *
        infectiousness(infecter, sim, pathogen_id) / 100.0 *
        susceptibility_bound(profile)
    # a zero factor zeroes the probability, whatever an unbounded one says
    return isnan(p) ? 0.0 : min(1.0, p)
end

"""
    max_effective_transmission_probability_in_type(transFunc::TransmissionFunction, pathogen_id::Int8, infecter::Individual, ::Type{S}, tick::Int16, sim::Simulation) where {S<:Setting}

Upper bound on `max_effective_transmission_probability` over every setting of type `S`, at most `1.0`.
"""
function max_effective_transmission_probability_in_type(transFunc::TransmissionFunction, pathogen_id::Int8, infecter::Individual, ::Type{S}, tick::Int16, sim::Simulation)::Float64 where {S<:Setting}
    profile = immunity_profile(get_pathogen(sim, pathogen_id))
    p = max_transmission_probability_in_type(transFunc, pathogen_id, infecter, S, tick, sim) *
        infectiousness(infecter, sim, pathogen_id) / 100.0 *
        susceptibility_bound(profile)
    # same expression as `max_effective_transmission_probability`, so equal bounds give equal values
    return isnan(p) ? 0.0 : min(1.0, p)
end

# whether transmission pre-thinning may rely on the pathogen's bounds
function _prethinnable(pathogen::Pathogen)::Bool
    TF = typeof(transmission_function(pathogen))
    IM = typeof(immunity_profile(pathogen))
    _overrides(effective_transmission_probability, TF, TransmissionFunction) && return false
    return !_overrides(susceptibility_factor, IM, ImmunityProfile) || _overrides(susceptibility_bound, IM, ImmunityProfile)
end

# whether `f` has a method taking a `T` first, other than its fallback on `fallback`
function _overrides(f, T::Type, fallback::Type)::Bool
    for m in methods(f)
        P = Base.unwrap_unionall(m.sig).parameters[2]
        P === fallback && continue
        T <: Base.rewrap_unionall(P, m.sig) && return true
    end
    return false
end

"""
    calculate_infectiousness(profile::InfectiousnessProfile, state::InfectionState, individual::Individual, tick::Int16, rng::Xoshiro)::Int8

Returns the infectiousness (0-100) of the infection `state` at `tick`; concrete profiles must implement it and
must not read immunity levels. `rng` draws the same numbers for the whole infection; re-key it per tick
with `infectiousness_rng!`.
"""
function calculate_infectiousness(profile::InfectiousnessProfile, state::InfectionState, individual::Individual, tick::Int16, rng::Xoshiro)::Int8
    error("calculate_infectiousness is not implemented for InfectiousnessProfile type $(typeof(profile)).")
end

# whether `calculate_infectiousness` may draw from its rng; one that never does gets it unkeyed
_draws_from_rng(::InfectiousnessProfile) = true

"""
    next_infectiousness_change(profile::InfectiousnessProfile, state::InfectionState, tick::Int16)::Int16

Returns the first tick after `tick` at which `calculate_infectiousness` may return a different level, so the
disease update can skip the ticks before it. Optional: the default, `tick + 1`, is always correct, while a
tick past the next change makes the update miss it.

# Example
A profile whose level only changes at infectiousness onset and recovery:
```julia
GEMS.next_infectiousness_change(p::MyProfile, state::InfectionState, tick::Int16) =
    next_tick_after(tick, state.infectiousness_onset, state.recovery)
```
"""
@inline next_infectiousness_change(profile::InfectiousnessProfile, state::InfectionState, tick::Int16) = tick + Int16(1)

"""
    next_tick_after(tick::Int16, ticks::Int16...)::Int16

Returns the first of `ticks` after `tick`, or `typemax(Int16)` if there is none. Unset ticks (`-1`) are never after `tick`.
"""
@inline function next_tick_after(tick::Int16, ticks::Int16...)
    next = typemax(Int16)
    for t in ticks
        tick < t < next && (next = t)
    end
    return next
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

For profiles that don't draw: passes a fresh, unkeyed `Xoshiro()`, so draws differ from reads
during a simulation.
"""
@inline function calculate_immunity(profile::ImmunityProfile, state::ImmunityState, individual::Individual, tick::Int16)::Int8
    return calculate_immunity(profile, state, individual, tick, Xoshiro())
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
    susceptibility_bound(profile::ImmunityProfile)::Float64

Upper bound on `susceptibility_factor` over every immunity level. Defaults to `1.0`; a profile
that overrides `susceptibility_factor` without it is not pre-thinned.
"""
susceptibility_bound(profile::ImmunityProfile)::Float64 = 1.0


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