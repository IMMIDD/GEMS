export DefaultHealthProgression

"""
    DefaultHealthProgression <: HealthProgression

Default host health policy: infections do not interact. Each infection contributes care and mortality
risk once, when it arrives, from the `HealthProfile` its progression category carries; contributions
superpose into the host's occupancy and mortality folds by earliest death, the two independent.

A host's occupancy is the union of what each infection demanded on its own, so two infections that
each demand a ward bed never escalate to ICU. Implement `calculate_health_progression!` for your own
`HealthProgression` to model interaction between co-active infections.

Where the profiles come from is a separate question: embed them on the progression categories, or
pass a `StandardOfCare` to the simulation for the categories that embed none.
"""
struct DefaultHealthProgression <: HealthProgression end

"""
    calculate_health_progression!(contributions::Vector{CareContribution}, individual::Individual, infections::InfectionRegistry, hp::DefaultHealthProgression, new_infection::InfectionState, index::HealthProfileIndex, tick::Int16, rng::Xoshiro)

Default combination: draws and contributes for `new_infection` only. An infection whose category
carries no profile contributes nothing.

Non-synergy is structural here rather than documented — a contribution is drawn without reference to
any other, so two infections that each demand a ward bed produce a host in a ward, never an
escalation. A custom policy implements this method for its own type; it receives every active
infection via `infections`, and `index` their profiles.
"""
function calculate_health_progression!(contributions::Vector{CareContribution}, individual::Individual,
        infections::InfectionRegistry, hp::DefaultHealthProgression, new_infection::InfectionState,
        index::HealthProfileIndex, tick::Int16, rng::Xoshiro)

    profile = _health_profile(index, new_infection)
    profile === nothing && return HealthOutcome()
    care, outcome = calculate_health_profile(profile, individual, new_infection, rng)
    care.hospital_admission >= 0 && push!(contributions, care)
    return outcome
end
