export DefaultHealthProgression

"""
    DefaultHealthProgression <: HealthProgression

Default host health policy. Holds a `SevereHealthProfile` and a `CriticalHealthProfile`; each
infection contributes care and mortality risk from the profile for its peak tier once, when it
arrives. Care contributions superpose into the host's occupancy and mortality folds by earliest death;
the two are independent. Ventilation is disabled by default (`CriticalHealthProfile` has zero
ventilation probability and length).

Contributions are independent, not synergistic: a host's occupancy is the union of what each infection
demanded on its own, so two infections that each demand a ward bed never escalate to ICU. Override
`calculate_health_progression!` to model interaction between co-active infections.

# Example

```julia
hp = DefaultHealthProgression(
    severe = SevereHealthProfile(hospital_probability = 0.1),
    critical = CriticalHealthProfile(hospital_to_icu_probability = 0.6, death_probability = 0.25))
```
"""
struct DefaultHealthProgression{S<:HealthProfile, C<:HealthProfile} <: HealthProgression
    severe::S
    critical::C

    # the canonical default policy; type parameters are inferred from the profiles
    function DefaultHealthProgression(;
        severe::HealthProfile = SevereHealthProfile(),
        critical::HealthProfile = CriticalHealthProfile()
        )

        return new{typeof(severe), typeof(critical)}(severe, critical)
    end
end

"""
    select_health_profile(hp::DefaultHealthProgression, infection::InfectionState)

Routes by peak tier: `severe` for a severe-peak infection, `critical` for a critical-peak one, and
`nothing` for an infection that never reached `severe`.
"""
function select_health_profile(hp::DefaultHealthProgression, infection::InfectionState)
    infection.severeness_onset < 0 && return nothing
    infection.critical_onset < 0 ? hp.severe : hp.critical
end
