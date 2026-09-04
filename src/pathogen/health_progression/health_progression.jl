export HealthProgression, HealthProfile
export calculate_health_progression!, calculate_health_profile

"""
    HealthProgression

Abstract supertype for host-level health policies. A `HealthProgression` turns the `severe`/`critical`
intervals of an individual's active infections into `CareContribution`s, which superpose into the
host's hospital/ICU/ventilation occupancy, and into a `HealthOutcome`.

Subtype it and implement `calculate_health_progression!` for a custom combination policy, e.g.
coinfection synergy. A policy is invoked whenever a new infection is added to a host. It does not
route infections to profiles; the `HealthProfileIndex` it is handed already does.

A policy cannot read the host's scheduled future care; joint reasoning is done over `each_infection`,
whose courses are already drawn.
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
    calculate_health_progression!(contributions::Vector{CareContribution}, individual::Individual, infections::InfectionRegistry, hp::HealthProgression, new_infection::InfectionState, index::HealthProfileIndex, tick::Int16, rng::Xoshiro)::HealthOutcome

Combination policy: `push!`es this call's care demand onto `contributions` and returns the death it
proposes. Invoked once per arriving infection. Care unions and death minimizes, hence the asymmetry.

Draw one infection's own care and mortality from `index` with
`calculate_health_profile(_health_profile(index, infection), individual, infection, rng)`. A policy
may skip that, replace it, or draw for co-active infections too.

**Contribute only the increment.** Contributions superpose and are never retracted, so contributing
the whole active set again on each call leaves the host admitted for the rest of the run, silently.
A policy must therefore be deterministic (never re-draw what it already contributed), monotone
(demand only ever rises as infections are added), and incremental.

The returned `HealthOutcome` is likewise this call's own, not the host's total, so `HealthOutcome()`
means "no mortality from this infection", not "cancel the scheduled death".

Every tick contributed must be `> tick`. `contributions` is a reused buffer: only `push!` to it.

When reasoning across infections:

- `each_infection` already includes `new_infection`.
- A co-active infection's window may start at or before `tick`, so clamp overlaps to `tick + 1`.
- From the seeding path, `each_infection` can include an infection that recovers this tick.

Every argument must be annotated. There is no fallback: a `HealthProgression` that implements no
method for its own type errors on the first infection. `DefaultHealthProgression`'s method is the
template to start from.
"""
function calculate_health_progression! end

"""
    calculate_health_profile(profile::HealthProfile, individual::Individual, infection::InfectionState, rng::Xoshiro)::Tuple{CareContribution, HealthOutcome}

Overridable per-tier policy. Maps a single infection's `severe`/`critical` schedule onto a
`(CareContribution, HealthOutcome)` pair. `individual` is available so a custom `HealthProfile` can
condition on host traits (e.g. comorbidities); the built-in profiles ignore it.
"""
function calculate_health_profile end

