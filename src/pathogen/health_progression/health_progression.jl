export HealthProgression, HealthProfile
export calculate_health_progression, calculate_health_profile, compute_health!

"""
    HealthProgression

Abstract supertype for host-level health policies. A `HealthProgression` maps the
per-pathogen disease demand (the `severe`/`critical` intervals of an individual's active
infections) onto the host-level care timeline (hospital/ICU/ventilation admission and
discharge) and the host death tick.

Subtype it and implement `calculate_health_progression` to define a custom combination policy
(e.g. coinfection synergy).
"""
abstract type HealthProgression end

"""
    HealthProfile

Abstract supertype for a single disease tier's health profile (e.g. `SevereHealthProfile`,
`CriticalHealthProfile`). Implement `calculate_health_profile` to define how one infection of
that tier demands host care and/or mortality risk.
"""
abstract type HealthProfile end

"""
    calculate_health_progression(individual::Individual, infections::InfectionRegistry, hp::HealthProgression, tick::Int16, rng::Xoshiro)::HealthTimeline

Overridable combination policy. Maps the `severe`/`critical` demand of `individual`'s active
infections onto a single `HealthTimeline`. Iterate the active infections with
`each_infection(individual, infections)` and combine their per-infection care.
"""
function calculate_health_progression end

"""
    calculate_health_profile(profile::HealthProfile, infection::InfectionState, rng::Xoshiro)::HealthTimeline

Overridable per-tier policy. Maps a single infection's `severe`/`critical` schedule onto a
`HealthTimeline`. The host's `HealthProgression` combines the per-infection results.
"""
function calculate_health_profile end

"""
    compute_health!(individual::Individual, infections::InfectionRegistry, hp::HealthProgression, tick::Int16, rng::Xoshiro)

Framework entry point (not overridable). Calls `calculate_health_progression`, preserves any
already-realized care events, and writes the resulting timeline onto `individual`. Invoked
whenever a new infection is added.
"""
function compute_health! end
