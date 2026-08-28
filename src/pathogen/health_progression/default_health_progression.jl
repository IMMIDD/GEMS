export DefaultHealthProgression, SevereHealthProfile, CriticalHealthProfile

"""
    SevereHealthProfile

Health profile for an infection whose peak tier is `severe`: a possible hospital (ward)
admission, anchored at the infection's `severeness_onset`.

# Parameters
- `hospital_probability::Real`: Hospital admission probability (`0.0` by default).
- `severeness_onset_to_hospital_admission::Union{Distribution, Real}`: Admission delay after severeness onset.
- `hospital_admission_to_hospital_discharge::Union{Distribution, Real}`: Ward stay length.
"""
struct SevereHealthProfile <: HealthProfile
    hospital_probability::Real
    severeness_onset_to_hospital_admission::Union{Distribution, Real}
    hospital_admission_to_hospital_discharge::Union{Distribution, Real}

    function SevereHealthProfile(;
        hospital_probability = 0.0,
        severeness_onset_to_hospital_admission = 0,
        hospital_admission_to_hospital_discharge = 0)

        0.0 <= hospital_probability <= 1.0 || throw(ArgumentError("hospital_probability must be between 0 and 1 (got $hospital_probability)."))
        return new(hospital_probability, severeness_onset_to_hospital_admission,
            hospital_admission_to_hospital_discharge)
    end
end

"""
    calculate_health_profile(sc::SevereHealthProfile, individual::Individual, infection::InfectionState, rng::Xoshiro)

Care contribution of a single `severe`-peak infection: a Bernoulli hospital admission anchored
at `infection.severeness_onset`. `severe` carries no mortality risk, so the returned
`HealthOutcome` is always empty.
"""
function calculate_health_profile(sc::SevereHealthProfile, individual::Individual, infection::InfectionState, rng::Xoshiro)
    hospital_admission::Int16 = Int16(-1)
    hospital_discharge::Int16 = Int16(-1)
    if gems_rand(rng) <= sc.hospital_probability
        hospital_admission = rand_round(infection.severeness_onset + _rand_val(sc.severeness_onset_to_hospital_admission, rng), rng)
        hospital_discharge = rand_round(hospital_admission + _rand_val(sc.hospital_admission_to_hospital_discharge, rng), rng)
    end
    care = CareContribution(hospital_admission = hospital_admission, hospital_discharge = hospital_discharge)
    return care, HealthOutcome()
end

"""
    CriticalHealthProfile

Health profile for an infection whose peak tier is `critical`: a hospital admission that can
escalate to ICU and ventilation, plus mortality risk. Each step's probability is conditional
on the step below (`hospital_to_icu_probability` = P(ICU | hospitalized), `icu_to_ventilation_probability` =
P(ventilation | ICU)); discharges chain inward-out so the stays nest by construction. Timings
are anchored at the infection's `critical_onset`. Care and mortality are computed independently
here and reconciled once, downstream, by `compute_health!`.

# Parameters
- `hospital_probability::Real`: Hospital admission probability (`0.0` by default).
- `critical_onset_to_hospital_admission::Union{Distribution, Real}`: Admission delay after critical onset.
- `hospital_admission_to_hospital_discharge::Union{Distribution, Real}`: Ward stay length when the patient does not enter the ICU.
- `hospital_to_icu_probability::Real`: ICU probability for a hospitalized patient (`0.0` by default).
- `hospital_admission_to_icu_admission::Union{Distribution, Real}`: Delay from hospital to ICU admission.
- `icu_admission_to_icu_discharge::Union{Distribution, Real}`: ICU stay length when the patient is not ventilated.
- `icu_to_ventilation_probability::Real`: Ventilation probability for an ICU patient (`0.0` by default).
- `icu_admission_to_ventilation_admission::Union{Distribution, Real}`: Delay from ICU to ventilation admission.
- `ventilation_admission_to_ventilation_discharge::Union{Distribution, Real}`: Ventilation length.
- `ventilation_discharge_to_icu_discharge::Union{Distribution, Real}`: ICU stay after ventilation ends.
- `icu_discharge_to_hospital_discharge::Union{Distribution, Real}`: Hospital stay after ICU discharge.
- `death_probability::Real`: Death probability (`0.0` by default).
- `critical_onset_to_death::Union{Distribution, Real}`: Delay from critical onset to death.
"""
struct CriticalHealthProfile <: HealthProfile
    hospital_probability::Real
    critical_onset_to_hospital_admission::Union{Distribution, Real}
    hospital_admission_to_hospital_discharge::Union{Distribution, Real}
    hospital_to_icu_probability::Real
    hospital_admission_to_icu_admission::Union{Distribution, Real}
    icu_admission_to_icu_discharge::Union{Distribution, Real}
    icu_to_ventilation_probability::Real
    icu_admission_to_ventilation_admission::Union{Distribution, Real}
    ventilation_admission_to_ventilation_discharge::Union{Distribution, Real}
    ventilation_discharge_to_icu_discharge::Union{Distribution, Real}
    icu_discharge_to_hospital_discharge::Union{Distribution, Real}
    death_probability::Real
    critical_onset_to_death::Union{Distribution, Real}

    function CriticalHealthProfile(;
        hospital_probability = 0.0,
        critical_onset_to_hospital_admission = 0,
        hospital_admission_to_hospital_discharge = 0,
        hospital_to_icu_probability = 0.0,
        hospital_admission_to_icu_admission = 0,
        icu_admission_to_icu_discharge = 0,
        icu_to_ventilation_probability = 0.0,
        icu_admission_to_ventilation_admission = 0,
        ventilation_admission_to_ventilation_discharge = 0,
        ventilation_discharge_to_icu_discharge = 0,
        icu_discharge_to_hospital_discharge = 0,
        death_probability = 0.0,
        critical_onset_to_death = 0)

        for (nm, p) in ((:hospital_probability, hospital_probability),
            (:hospital_to_icu_probability, hospital_to_icu_probability),
            (:icu_to_ventilation_probability, icu_to_ventilation_probability),
            (:death_probability, death_probability))
            0.0 <= p <= 1.0 || throw(ArgumentError("$nm must be between 0 and 1 (got $p)."))
        end

        return new(hospital_probability, critical_onset_to_hospital_admission,
            hospital_admission_to_hospital_discharge, hospital_to_icu_probability,
            hospital_admission_to_icu_admission, icu_admission_to_icu_discharge,
            icu_to_ventilation_probability, icu_admission_to_ventilation_admission,
            ventilation_admission_to_ventilation_discharge, ventilation_discharge_to_icu_discharge,
            icu_discharge_to_hospital_discharge, death_probability, critical_onset_to_death)
    end
end

"""
    calculate_health_profile(cc::CriticalHealthProfile, individual::Individual, infection::InfectionState, rng::Xoshiro)

Care and mortality contribution of a single `critical`-peak infection, anchored at
`infection.critical_onset`. Hospital, ICU, and ventilation escalate via nested Bernoulli draws;
death is drawn independently of them.
"""
function calculate_health_profile(cc::CriticalHealthProfile, individual::Individual, infection::InfectionState, rng::Xoshiro)
    hospital_admission::Int16 = Int16(-1)
    hospital_discharge::Int16 = Int16(-1)
    icu_admission::Int16 = Int16(-1)
    icu_discharge::Int16 = Int16(-1)
    ventilation_admission::Int16 = Int16(-1)
    ventilation_discharge::Int16 = Int16(-1)
    death::Int16 = Int16(-1)

    if gems_rand(rng) <= cc.hospital_probability
        hospital_admission = rand_round(infection.critical_onset + _rand_val(cc.critical_onset_to_hospital_admission, rng), rng)
        if gems_rand(rng) <= cc.hospital_to_icu_probability
            icu_admission = rand_round(hospital_admission + _rand_val(cc.hospital_admission_to_icu_admission, rng), rng)
            if gems_rand(rng) <= cc.icu_to_ventilation_probability
                ventilation_admission = rand_round(icu_admission + _rand_val(cc.icu_admission_to_ventilation_admission, rng), rng)
                ventilation_discharge = rand_round(ventilation_admission + _rand_val(cc.ventilation_admission_to_ventilation_discharge, rng), rng)
                icu_discharge = rand_round(ventilation_discharge + _rand_val(cc.ventilation_discharge_to_icu_discharge, rng), rng)
            else
                icu_discharge = rand_round(icu_admission + _rand_val(cc.icu_admission_to_icu_discharge, rng), rng)
            end
            hospital_discharge = rand_round(icu_discharge + _rand_val(cc.icu_discharge_to_hospital_discharge, rng), rng)
        else
            hospital_discharge = rand_round(hospital_admission + _rand_val(cc.hospital_admission_to_hospital_discharge, rng), rng)
        end
    end
    # death is independent of hospital/ICU here; the ladder and the outcome are reconciled downstream
    if gems_rand(rng) <= cc.death_probability
        death = rand_round(infection.critical_onset + _rand_val(cc.critical_onset_to_death, rng), rng)
    end

    care = CareContribution(hospital_admission = hospital_admission, hospital_discharge = hospital_discharge,
        icu_admission = icu_admission, icu_discharge = icu_discharge,
        ventilation_admission = ventilation_admission, ventilation_discharge = ventilation_discharge)
    outcome = HealthOutcome(death = death, death_pathogen_id = infection.pathogen_id)
    return care, outcome
end

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
    calculate_health_progression!(contributions::Vector{CareContribution}, individual::Individual, infections::InfectionRegistry, hp::HealthProgression, new_infection::InfectionState, tick::Int16, rng::Xoshiro)

Generic combination policy: contributes for `new_infection` only. An infection that selects no profile
contributes nothing.

Non-synergy is structural here rather than documented — a contribution is drawn without reference to
any other, so two infections that each demand a ward bed produce a host in a ward, never an
escalation. Override this method to model interaction between co-active infections; it receives every
active infection via `infections`.
"""
function calculate_health_progression!(contributions::Vector{CareContribution}, individual::Individual,
        infections::InfectionRegistry, hp::HealthProgression, new_infection::InfectionState,
        tick::Int16, rng::Xoshiro)

    profile = select_health_profile(hp, new_infection)
    profile === nothing && return HealthOutcome()
    care, outcome = calculate_health_profile(profile, individual, new_infection, rng)
    care.hospital_admission >= 0 && push!(contributions, care)
    return outcome
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
