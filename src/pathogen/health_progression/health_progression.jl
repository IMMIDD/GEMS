export HealthProgression, HealthProfile
export calculate_health_progression, calculate_health_profile, select_health_profile, compute_health!

"""
    HealthProgression

Abstract supertype for host-level health policies. A `HealthProgression` maps the
per-pathogen disease demand (the `severe`/`critical` intervals of an individual's active
infections) onto the host-level `CareTimeline` (hospital/ICU/ventilation admission and
discharge) and the terminal `HealthOutcome` (host death tick and its attributed pathogen).

Subtype it and implement `calculate_health_progression` to define a custom combination policy
(e.g. coinfection synergy, or mortality that depends on the computed `CareTimeline`). A policy is
invoked whenever a new infection is added to a host.
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
    calculate_health_progression(individual::Individual, infections::InfectionRegistry, hp::HealthProgression, ctx::HealthContext, rng::Xoshiro)::Tuple{CareTimeline, HealthOutcome}

Combination policy: maps the demand of `individual`'s active infections onto a single
`(CareTimeline, HealthOutcome)` pair. `infections` exposes every active infection, so a policy can
reason jointly across them (coinfection synergy); `ctx` carries the current tick, the infection
that triggered the call, and what the host is already committed to.

The result is the host's plan from `ctx.tick` onward: every tick in it must be `> ctx.tick`,
or identical to the corresponding committed field in `ctx`. 

The generic method draws only for `ctx.new_infection` and folds it into `ctx.committed_care`; see
`DefaultHealthProgression`. A synergy policy may re-evaluate the whole active set instead, but
must anchor its result after `ctx.tick`.
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
`nothing` if it demands no host care. The generic `calculate_health_progression` calls this for
the arriving infection; override it to route infections (e.g. by their `progression_id`) to
custom profiles while reusing the default combination.
"""
function select_health_profile end

"""
    compute_health!(individual::Individual, infections::InfectionRegistry, hp::HealthProgression, new_infection::InfectionState, tick::Int16, rng::Xoshiro)

Framework entry point (not overridable). Builds the `HealthContext`, calls
`calculate_health_progression`, validates the returned plan, caps care at a scheduled death, and
writes the result onto `individual`. Invoked whenever a new infection is added.
"""
function compute_health! end