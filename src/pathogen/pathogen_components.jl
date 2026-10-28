export transmission_probability
export transmission_factor
export effective_transmission_probability
export transmission_functions
export progression_categories
export progression_assignments
export health_progressions
export calculate_infectiousness
export calculate_immunity
export calculate_waning_immunity
export waning_level
export natural_peak
export calculate_severity_immunity
export calculate_waning_severity_immunity
export severity_waning_level
export severity_natural_peak
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
    calculate_infectiousness(profile::InfectiousnessProfile, state::InfectionState, individual::Individual, tick::Int16, rng::Xoshiro)::Int8

Returns the infectiousness (0-100) of the infection `state` at `tick`; concrete profiles must implement it and
must not read immunity levels. `rng` draws the same numbers for the whole infection; re-key it per tick
with `infectiousness_rng!`.
"""
function calculate_infectiousness(profile::InfectiousnessProfile, state::InfectionState, individual::Individual, tick::Int16, rng::Xoshiro)::Int8
    error("calculate_infectiousness is not implemented for InfectiousnessProfile type $(typeof(profile)).")
end

"""
    calculate_immunity(profile::ImmunityProfile, state::ImmunityState, vaccine_protection::VaccineProtection, individual::Individual, tick::Int16, rng::Xoshiro)::Int8

Returns the immunity level (0-100) of `state` at `tick`, given the peaks and buildup of the vaccine recorded in
`state` (only meaningful if `state` has a vaccine record). Called on every read from any thread, so it must be
cheap and deterministic and must not yield or read other levels. `rng` draws the same numbers on every read for
this host and pathogen; re-key it per acquisition with `immunity_rng!`. Falls back to the deprecated 5-arg method.
"""
@inline calculate_immunity(profile::ImmunityProfile, state::ImmunityState, vaccine_protection::VaccineProtection, individual::Individual, tick::Int16, rng::Xoshiro)::Int8 =
    calculate_immunity(profile, state, individual, tick, rng)

"""
    calculate_immunity(profile::ImmunityProfile, state::ImmunityState, individual::Individual, tick::Int16, rng::Xoshiro)::Int8

Deprecated to implement: profiles that only implement this form ignore vaccine peaks and buildup. Calling it on a
built-in profile gives the level with the default vaccine values.
"""
function calculate_immunity(profile::ImmunityProfile, state::ImmunityState, individual::Individual, tick::Int16, rng::Xoshiro)::Int8
    error("calculate_immunity is not implemented for ImmunityProfile type $(typeof(profile)); implement " *
        "calculate_immunity(profile, state, vaccine_protection, individual, tick, rng).")
end

"""
    calculate_immunity(profile::ImmunityProfile, state::ImmunityState, individual::Individual, tick::Int16)::Int8

For profiles that don't draw: passes the default vaccine values and a fresh, unkeyed `Xoshiro()`, so draws differ
from reads during a simulation.
"""
@inline function calculate_immunity(profile::ImmunityProfile, state::ImmunityState, individual::Individual, tick::Int16)::Int8
    return calculate_immunity(profile, state, VaccineProtection(), individual, tick, Xoshiro())
end

# whether `profile` has its own 6-arg calculate_immunity, not only the deprecated 5-arg one
function _implements_vaccine_protection(profile::ImmunityProfile)::Bool
    own = which(calculate_immunity, Tuple{typeof(profile), ImmunityState, VaccineProtection, Individual, Int16, Xoshiro})
    fallback = which(calculate_immunity, Tuple{ImmunityProfile, ImmunityState, VaccineProtection, Individual, Int16, Xoshiro})
    return own !== fallback
end

"""
    calculate_severity_immunity(profile::ImmunityProfile, state::ImmunityState, vaccine_protection::VaccineProtection, individual::Individual, tick::Int16, rng::Xoshiro)::Union{Int8, Nothing}

Returns the protection against severe disease (0-100) of `state` at `tick`, the counterpart of `calculate_immunity`
with the same contract. Defaults to `nothing`: the profile protects against severe disease as much as against
infection, and a vaccine's `severity_peak` has no effect.
"""
calculate_severity_immunity(profile::ImmunityProfile, state::ImmunityState, vaccine_protection::VaccineProtection, individual::Individual, tick::Int16, rng::Xoshiro)::Nothing = nothing

# whether `profile` has its own calculate_severity_immunity
function _implements_severity_protection(profile::ImmunityProfile)::Bool
    own = which(calculate_severity_immunity, Tuple{typeof(profile), ImmunityState, VaccineProtection, Individual, Int16, Xoshiro})
    fallback = which(calculate_severity_immunity, Tuple{ImmunityProfile, ImmunityState, VaccineProtection, Individual, Int16, Xoshiro})
    return own !== fallback
end

"""
    waning_level(profile::WaningImmunity, peak::Int8, elapsed::Int16, state::ImmunityState, source::Symbol, rng::Xoshiro)::Int8

Returns the level (0-100) `elapsed` ticks after a dose or a recovery reached `peak`. `source` is `:natural`,
`:vaccine` or `:prev_vaccine`; a curve that draws re-keys `rng` with `immunity_rng!(rng, state, source)`, so its
draws stay the same on every read of that acquisition.
"""
function waning_level(profile::WaningImmunity, peak::Int8, elapsed::Int16, state::ImmunityState, source::Symbol, rng::Xoshiro)::Int8
    error("waning_level is not implemented for WaningImmunity type $(typeof(profile)).")
end

"""
    natural_peak(profile::WaningImmunity)::Int8

Returns the level of natural immunity at recovery. Defaults to 100.
"""
natural_peak(profile::WaningImmunity)::Int8 = Int8(100)

"""
    calculate_waning_immunity(profile::WaningImmunity, state::ImmunityState, vaccine_protection::VaccineProtection, tick::Int16, rng::Xoshiro)::Int8

Returns the level of `state` at `tick` from the profile's `waning_level` and `natural_peak`: a dose ramps to the
vaccine's peak over its buildup, a booster's buildup keeps what the previous dose still gives, and natural and
vaccine immunity combine as 1 − (1−p)(1−q).
"""
@inline calculate_waning_immunity(profile::WaningImmunity, state::ImmunityState, vaccine_protection::VaccineProtection, tick::Int16, rng::Xoshiro)::Int8 =
    _waning_immunity(waning_level, profile, state, natural_peak(profile), vaccine_protection, vaccine_protection.peak, tick, rng)

"""
    calculate_immunity(profile::WaningImmunity, state::ImmunityState, vaccine_protection::VaccineProtection, individual::Individual, tick::Int16, rng::Xoshiro)::Int8

Calls `calculate_waning_immunity`, for `WaningImmunity` subtypes that don't define their own `calculate_immunity`.
"""
@inline calculate_immunity(profile::WaningImmunity, state::ImmunityState, vaccine_protection::VaccineProtection, individual::Individual, tick::Int16, rng::Xoshiro)::Int8 =
    calculate_waning_immunity(profile, state, vaccine_protection, tick, rng)

@inline calculate_immunity(profile::WaningImmunity, state::ImmunityState, individual::Individual, tick::Int16, rng::Xoshiro)::Int8 =
    calculate_immunity(profile, state, VaccineProtection(), individual, tick, rng)

"""
    severity_waning_level(profile::WaningImmunity, peak::Int8, elapsed::Int16, state::ImmunityState, source::Symbol, rng::Xoshiro)::Int8

Returns the protection against severe disease `elapsed` ticks after a dose or a recovery reached `peak`, with the
arguments of `waning_level`. Defaults to `waning_level`.
"""
@inline severity_waning_level(profile::WaningImmunity, peak::Int8, elapsed::Int16, state::ImmunityState, source::Symbol, rng::Xoshiro)::Int8 =
    waning_level(profile, peak, elapsed, state, source, rng)

"""
    severity_natural_peak(profile::WaningImmunity)::Int8

Returns the protection against severe disease of natural immunity at recovery. Defaults to `natural_peak`.
"""
severity_natural_peak(profile::WaningImmunity)::Int8 = natural_peak(profile)

"""
    calculate_waning_severity_immunity(profile::WaningImmunity, state::ImmunityState, vaccine_protection::VaccineProtection, tick::Int16, rng::Xoshiro)::Int8

The counterpart of `calculate_waning_immunity` for protection against severe disease, from `severity_waning_level`,
`severity_natural_peak` and the vaccine's `severity_peak`.
"""
@inline calculate_waning_severity_immunity(profile::WaningImmunity, state::ImmunityState, vaccine_protection::VaccineProtection, tick::Int16, rng::Xoshiro)::Int8 =
    _waning_immunity(severity_waning_level, profile, state, severity_natural_peak(profile), vaccine_protection, vaccine_protection.severity_peak, tick, rng)

"""
    calculate_severity_immunity(profile::WaningImmunity, state::ImmunityState, vaccine_protection::VaccineProtection, individual::Individual, tick::Int16, rng::Xoshiro)::Int8

Calls `calculate_waning_severity_immunity`, for `WaningImmunity` subtypes that don't define their own
`calculate_severity_immunity`.
"""
@inline calculate_severity_immunity(profile::WaningImmunity, state::ImmunityState, vaccine_protection::VaccineProtection, individual::Individual, tick::Int16, rng::Xoshiro)::Int8 =
    calculate_waning_severity_immunity(profile, state, vaccine_protection, tick, rng)

# the deprecated buildup a profile gives vaccines that set none
_profile_vaccine_buildup(profile::ImmunityProfile)::Int16 = Int16(0)

# natural and vaccine immunity of `state` on the curve `curve`, combined as independent barriers
@inline function _waning_immunity(curve::F, profile::WaningImmunity, state::ImmunityState, nat_peak::Int8,
        vaccine_protection::VaccineProtection, vaccine_peak::Int8, tick::Int16, rng::Xoshiro)::Int8 where {F}
    nat_level = natural_immunity_recorded(state) ?
        _dose_level(curve, profile, state, :natural, state.natural_acquired_tick, tick, Int16(0), nat_peak, rng) : Int8(0)
    # full natural immunity combined with any vaccine level is full
    nat_level == 100 && return nat_level
    vac_level = vaccine_immunity_recorded(state) ?
        _vaccine_level(curve, profile, state, vaccine_protection, vaccine_peak, tick, rng) : Int8(0)
    return Int8(clamp(round(Int, Int(nat_level) + Int(vac_level) - (Int(nat_level) * Int(vac_level)) / 100.0f0), 0, 100))
end

# a dose's level: ramps from 0 to `peak` over the buildup, then follows `curve`
@inline function _dose_level(curve::F, profile::WaningImmunity, state::ImmunityState, source::Symbol, acquired_tick::Int16,
        tick::Int16, buildup_duration::Int16, peak::Int8, rng::Xoshiro)::Int8 where {F}
    tick < acquired_tick && return Int8(0)
    elapsed = tick - acquired_tick
    if elapsed < buildup_duration
        return Int8(clamp(round(Int, Float32(peak) * elapsed / buildup_duration), 0, 100))
    end
    return curve(profile, peak, elapsed - buildup_duration, state, source, rng)
end

# during a dose's buildup, the vaccine level is at least what the previous dose still gives
@inline function _vaccine_level(curve::F, profile::WaningImmunity, state::ImmunityState, vaccine_protection::VaccineProtection,
        peak::Int8, tick::Int16, rng::Xoshiro)::Int8 where {F}
    buildup = vaccine_protection.buildup_duration < 0 ? _profile_vaccine_buildup(profile) : vaccine_protection.buildup_duration
    current = _dose_level(curve, profile, state, :vaccine, state.vaccine_acquired_tick, tick, buildup, peak, rng)
    elapsed = tick - state.vaccine_acquired_tick
    (0 <= elapsed < buildup && state.prev_dose_interval != 0x00) || return current
    prev_tick = Int(state.vaccine_acquired_tick) - Int(previous_dose_interval(state))
    prev_tick > typemin(Int16) || return current
    return max(current, _dose_level(curve, profile, state, :prev_vaccine, Int16(prev_tick), tick, buildup, peak, rng))
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