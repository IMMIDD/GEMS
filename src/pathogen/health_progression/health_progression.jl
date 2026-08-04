export HealthProgression, HealthProfile
export calculate_health_progression, calculate_health_profile, select_health_profile, compute_health!

"""
    HealthProgression

Abstract supertype for host-level health policies. A `HealthProgression` maps the
per-pathogen disease demand (the `severe`/`critical` intervals of an individual's active
infections) onto the host-level `CareTimeline` (hospital/ICU/ventilation admission and
discharge) and the terminal `HealthOutcome` (host death tick and its attributed pathogen).

Subtype it and implement `calculate_health_progression` to define a custom combination policy
(e.g. coinfection synergy, or mortality that depends on the computed `CareTimeline`).
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
    calculate_health_progression(individual::Individual, infections::InfectionRegistry, hp::HealthProgression, tick::Int16, rng::Xoshiro)::Tuple{CareTimeline, HealthOutcome}

Combination policy: maps the demand of `individual`'s active infections onto a single
`(CareTimeline, HealthOutcome)` pair. A generic method folds each active infection's
`select_health_profile` contribution independently; override this instead of `select_health_profile`
to define a different combination (e.g. coinfection synergy).
"""
function calculate_health_progression end

"""
    calculate_health_profile(profile::HealthProfile, individual::Individual, infection::InfectionState, rng::Xoshiro)::Tuple{CareTimeline, HealthOutcome}

Overridable per-tier policy. Maps a single infection's `severe`/`critical` schedule onto a
`(CareTimeline, HealthOutcome)` pair. `individual` is available so a custom `HealthProfile` can
condition on host traits (e.g. comorbidities); the built-in profiles ignore it.
"""
function calculate_health_profile end

"""
    select_health_profile(hp::HealthProgression, infection::InfectionState)::Union{HealthProfile, Nothing}

Overridable per-infection routing. Returns the `HealthProfile` to apply to `infection`, or
`nothing` if it demands no host care. The generic `calculate_health_progression` loop calls this
for each active infection; override it to route infections (e.g. by their `progression_id`) to
custom profiles while reusing the default combination.
"""
function select_health_profile end

"""
    compute_health!(individual::Individual, infections::InfectionRegistry, hp::HealthProgression, tick::Int16, rng::Xoshiro)

Framework entry point (not overridable). Calls `calculate_health_progression`, caps care at a
scheduled death, preserves any already-realized care events, and writes the resulting timeline
onto `individual`. Invoked whenever a new infection is added.
"""
function compute_health! end