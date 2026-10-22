export MildHealthProfile, SevereHealthProfile, CriticalHealthProfile
export WardHealthProfile, ICUHealthProfile, FatalHealthProfile


"""
    MildHealthProfile

Health profile for an infection whose peak tier is `mild`: no care or mortality, only whether the
host stays home while symptomatic.

# Parameters
- `symptomatic_homebound_probability::Real`: Probability of being homebound from symptom onset to recovery (`0.0` by default).
"""
struct MildHealthProfile <: HealthProfile
    symptomatic_homebound_probability::Float64

    function MildHealthProfile(; symptomatic_homebound_probability = DEFAULT_SYMPTOMATIC_HOMEBOUND_PROBABILITY)
        0.0 <= symptomatic_homebound_probability <= 1.0 || throw(ArgumentError("symptomatic_homebound_probability must be between 0 and 1 (got $symptomatic_homebound_probability)."))
        return new(symptomatic_homebound_probability)
    end
end

"""
    calculate_health_profile(mc::MildHealthProfile, individual::Individual, infection::InfectionState, rng::Xoshiro)

A `mild`-peak infection demands no care and carries no mortality risk.
"""
calculate_health_profile(mc::MildHealthProfile, individual::Individual, infection::InfectionState, rng::Xoshiro) =
    (CareContribution(), HealthOutcome())

"""
    SevereHealthProfile

Health profile for an infection whose peak tier is `severe`: a possible hospital (ward)
admission, anchored at the infection's `severeness_onset`, and whether the host stays home.

# Parameters
- `hospital_probability::Real`: Hospital admission probability (`0.0` by default).
- `severeness_onset_to_hospital_admission::Union{Distribution, Real}`: Admission delay after severeness onset.
- `hospital_admission_to_hospital_discharge::Union{Distribution, Real}`: Ward stay length.
- `symptomatic_homebound_probability::Real`: Probability of being homebound from symptom onset to recovery (`0.0` by default).
- `severe_homebound_probability::Real`: Probability of being homebound while severe, at least `symptomatic_homebound_probability` (`1.0` by default).
"""
struct SevereHealthProfile <: HealthProfile
    hospital_probability::Float64
    severeness_onset_to_hospital_admission::Union{Distribution, Real}
    hospital_admission_to_hospital_discharge::Union{Distribution, Real}
    symptomatic_homebound_probability::Float64
    severe_homebound_probability::Float64

    function SevereHealthProfile(;
        hospital_probability = 0.0,
        severeness_onset_to_hospital_admission = 0,
        hospital_admission_to_hospital_discharge = 0,
        symptomatic_homebound_probability = DEFAULT_SYMPTOMATIC_HOMEBOUND_PROBABILITY,
        severe_homebound_probability = DEFAULT_SEVERE_HOMEBOUND_PROBABILITY)

        for (nm, p) in ((:hospital_probability, hospital_probability),
            (:symptomatic_homebound_probability, symptomatic_homebound_probability),
            (:severe_homebound_probability, severe_homebound_probability))
            0.0 <= p <= 1.0 || throw(ArgumentError("$nm must be between 0 and 1 (got $p)."))
        end
        _check_homebound_order(symptomatic_homebound_probability, severe_homebound_probability)

        return new(hospital_probability, severeness_onset_to_hospital_admission,
            hospital_admission_to_hospital_discharge, symptomatic_homebound_probability,
            severe_homebound_probability)
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
P(ventilation | ICU)); discharges chain inward-out so the stays nest by construction. Care and
mortality are computed independently here and reconciled once, downstream, by `compute_health!`.

The ward is anchored at `severeness_onset`, the ICU at `critical_onset`. If the ICU admission comes
first, the ward admission is moved to it.

# Parameters
- `hospital_probability::Real`: Hospital admission probability (`0.0` by default).
- `severeness_onset_to_hospital_admission::Union{Distribution, Real}`: Admission delay after severeness onset, unless the ICU admission comes first.
- `hospital_admission_to_hospital_discharge::Union{Distribution, Real}`: Ward stay length when the patient does not enter the ICU.
- `hospital_to_icu_probability::Real`: ICU probability for a hospitalized patient (`0.0` by default).
- `critical_onset_to_icu_admission::Union{Distribution, Real}`: ICU admission delay after critical onset.
- `icu_admission_to_icu_discharge::Union{Distribution, Real}`: ICU stay length when the patient is not ventilated.
- `icu_to_ventilation_probability::Real`: Ventilation probability for an ICU patient (`0.0` by default).
- `icu_admission_to_ventilation_admission::Union{Distribution, Real}`: Delay from ICU to ventilation admission.
- `ventilation_admission_to_ventilation_discharge::Union{Distribution, Real}`: Ventilation length.
- `ventilation_discharge_to_icu_discharge::Union{Distribution, Real}`: ICU stay after ventilation ends.
- `icu_discharge_to_hospital_discharge::Union{Distribution, Real}`: Hospital stay after ICU discharge.
- `death_probability::Real`: Death probability (`0.0` by default).
- `critical_onset_to_death::Union{Distribution, Real}`: Delay from critical onset to death.
- `symptomatic_homebound_probability::Real`: Probability of being homebound from symptom onset to recovery (`0.0` by default).
- `severe_homebound_probability::Real`: Probability of being homebound while severe, at least `symptomatic_homebound_probability` (`1.0` by default).
"""
struct CriticalHealthProfile <: HealthProfile
    hospital_probability::Float64
    severeness_onset_to_hospital_admission::Union{Distribution, Real}
    hospital_admission_to_hospital_discharge::Union{Distribution, Real}
    hospital_to_icu_probability::Float64
    critical_onset_to_icu_admission::Union{Distribution, Real}
    icu_admission_to_icu_discharge::Union{Distribution, Real}
    icu_to_ventilation_probability::Float64
    icu_admission_to_ventilation_admission::Union{Distribution, Real}
    ventilation_admission_to_ventilation_discharge::Union{Distribution, Real}
    ventilation_discharge_to_icu_discharge::Union{Distribution, Real}
    icu_discharge_to_hospital_discharge::Union{Distribution, Real}
    death_probability::Float64
    critical_onset_to_death::Union{Distribution, Real}
    symptomatic_homebound_probability::Float64
    severe_homebound_probability::Float64

    function CriticalHealthProfile(;
        hospital_probability = 0.0,
        severeness_onset_to_hospital_admission = 0,
        hospital_admission_to_hospital_discharge = 0,
        hospital_to_icu_probability = 0.0,
        critical_onset_to_icu_admission = 0,
        icu_admission_to_icu_discharge = 0,
        icu_to_ventilation_probability = 0.0,
        icu_admission_to_ventilation_admission = 0,
        ventilation_admission_to_ventilation_discharge = 0,
        ventilation_discharge_to_icu_discharge = 0,
        icu_discharge_to_hospital_discharge = 0,
        death_probability = 0.0,
        critical_onset_to_death = 0,
        symptomatic_homebound_probability = DEFAULT_SYMPTOMATIC_HOMEBOUND_PROBABILITY,
        severe_homebound_probability = DEFAULT_SEVERE_HOMEBOUND_PROBABILITY)

        for (nm, p) in ((:hospital_probability, hospital_probability),
            (:hospital_to_icu_probability, hospital_to_icu_probability),
            (:icu_to_ventilation_probability, icu_to_ventilation_probability),
            (:death_probability, death_probability),
            (:symptomatic_homebound_probability, symptomatic_homebound_probability),
            (:severe_homebound_probability, severe_homebound_probability))
            0.0 <= p <= 1.0 || throw(ArgumentError("$nm must be between 0 and 1 (got $p)."))
        end
        _check_homebound_order(symptomatic_homebound_probability, severe_homebound_probability)

        return new(hospital_probability, severeness_onset_to_hospital_admission,
            hospital_admission_to_hospital_discharge, hospital_to_icu_probability,
            critical_onset_to_icu_admission, icu_admission_to_icu_discharge,
            icu_to_ventilation_probability, icu_admission_to_ventilation_admission,
            ventilation_admission_to_ventilation_discharge, ventilation_discharge_to_icu_discharge,
            icu_discharge_to_hospital_discharge, death_probability, critical_onset_to_death,
            symptomatic_homebound_probability, severe_homebound_probability)
    end
end

"""
    calculate_health_profile(cc::CriticalHealthProfile, individual::Individual, infection::InfectionState, rng::Xoshiro)

Care and mortality contribution of a single `critical`-peak infection, the ward anchored at
`infection.severeness_onset` and the ICU at `infection.critical_onset`. Hospital, ICU, and
ventilation escalate via nested Bernoulli draws; death is drawn independently of them.
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
        hospital_admission = rand_round(infection.severeness_onset + _rand_val(cc.severeness_onset_to_hospital_admission, rng), rng)
        if gems_rand(rng) <= cc.hospital_to_icu_probability
            icu_admission = rand_round(infection.critical_onset + _rand_val(cc.critical_onset_to_icu_admission, rng), rng)
            # the ward admission cannot come after the ICU admission
            hospital_admission = min(hospital_admission, icu_admission)
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
    WardHealthProfile

Health profile for the `Ward` tier: a certain hospital (ward) admission, anchored at the infection's
`severeness_onset`, with no ICU and no mortality risk, and whether the host stays home.

# Parameters
- `severeness_onset_to_hospital_admission::Union{Distribution, Real}`: Admission delay after severeness onset.
- `hospital_admission_to_hospital_discharge::Union{Distribution, Real}`: Ward stay length.
- `symptomatic_homebound_probability::Real`: Probability of being homebound from symptom onset to recovery (`0.0` by default).
- `severe_homebound_probability::Real`: Probability of being homebound while severe, at least `symptomatic_homebound_probability` (`1.0` by default).
"""
struct WardHealthProfile <: HealthProfile
    severeness_onset_to_hospital_admission::Union{Distribution, Real}
    hospital_admission_to_hospital_discharge::Union{Distribution, Real}
    symptomatic_homebound_probability::Float64
    severe_homebound_probability::Float64

    function WardHealthProfile(;
        severeness_onset_to_hospital_admission = 0,
        hospital_admission_to_hospital_discharge = 0,
        symptomatic_homebound_probability = DEFAULT_SYMPTOMATIC_HOMEBOUND_PROBABILITY,
        severe_homebound_probability = DEFAULT_SEVERE_HOMEBOUND_PROBABILITY)

        for (nm, p) in ((:symptomatic_homebound_probability, symptomatic_homebound_probability),
            (:severe_homebound_probability, severe_homebound_probability))
            0.0 <= p <= 1.0 || throw(ArgumentError("$nm must be between 0 and 1 (got $p)."))
        end
        _check_homebound_order(symptomatic_homebound_probability, severe_homebound_probability)

        return new(severeness_onset_to_hospital_admission, hospital_admission_to_hospital_discharge,
            symptomatic_homebound_probability, severe_homebound_probability)
    end
end

"""
    calculate_health_profile(wc::WardHealthProfile, individual::Individual, infection::InfectionState, rng::Xoshiro)

Care contribution of a single `Ward` infection: a ward admission anchored at `infection.severeness_onset`.
"""
function calculate_health_profile(wc::WardHealthProfile, individual::Individual, infection::InfectionState, rng::Xoshiro)
    hospital_admission::Int16 = rand_round(infection.severeness_onset + _rand_val(wc.severeness_onset_to_hospital_admission, rng), rng)
    hospital_discharge::Int16 = rand_round(hospital_admission + _rand_val(wc.hospital_admission_to_hospital_discharge, rng), rng)
    care = CareContribution(hospital_admission = hospital_admission, hospital_discharge = hospital_discharge)
    return care, HealthOutcome()
end

"""
    ICUHealthProfile

Health profile for the `ICU` tier: a certain hospital admission that always escalates to ICU, with optional
ventilation and mortality risk, and whether the host stays home. The ward is anchored at `severeness_onset`,
the ICU at `critical_onset`.

# Parameters
- `severeness_onset_to_hospital_admission::Union{Distribution, Real}`: Admission delay after severeness onset, unless the ICU admission comes first.
- `critical_onset_to_icu_admission::Union{Distribution, Real}`: ICU admission delay after critical onset.
- `icu_admission_to_icu_discharge::Union{Distribution, Real}`: ICU stay length when the patient is not ventilated.
- `icu_to_ventilation_probability::Real`: Ventilation probability (`0.0` by default).
- `icu_admission_to_ventilation_admission::Union{Distribution, Real}`: Delay from ICU to ventilation admission.
- `ventilation_admission_to_ventilation_discharge::Union{Distribution, Real}`: Ventilation length.
- `ventilation_discharge_to_icu_discharge::Union{Distribution, Real}`: ICU stay after ventilation ends.
- `icu_discharge_to_hospital_discharge::Union{Distribution, Real}`: Hospital stay after ICU discharge.
- `death_probability::Real`: Death probability (`0.0` by default).
- `critical_onset_to_death::Union{Distribution, Real}`: Delay from critical onset to death.
- `symptomatic_homebound_probability::Real`: Probability of being homebound from symptom onset to recovery (`0.0` by default).
- `severe_homebound_probability::Real`: Probability of being homebound while severe, at least `symptomatic_homebound_probability` (`1.0` by default).
"""
struct ICUHealthProfile <: HealthProfile
    severeness_onset_to_hospital_admission::Union{Distribution, Real}
    critical_onset_to_icu_admission::Union{Distribution, Real}
    icu_admission_to_icu_discharge::Union{Distribution, Real}
    icu_to_ventilation_probability::Float64
    icu_admission_to_ventilation_admission::Union{Distribution, Real}
    ventilation_admission_to_ventilation_discharge::Union{Distribution, Real}
    ventilation_discharge_to_icu_discharge::Union{Distribution, Real}
    icu_discharge_to_hospital_discharge::Union{Distribution, Real}
    death_probability::Float64
    critical_onset_to_death::Union{Distribution, Real}
    symptomatic_homebound_probability::Float64
    severe_homebound_probability::Float64

    function ICUHealthProfile(;
        severeness_onset_to_hospital_admission = 0,
        critical_onset_to_icu_admission = 0,
        icu_admission_to_icu_discharge = 0,
        icu_to_ventilation_probability = 0.0,
        icu_admission_to_ventilation_admission = 0,
        ventilation_admission_to_ventilation_discharge = 0,
        ventilation_discharge_to_icu_discharge = 0,
        icu_discharge_to_hospital_discharge = 0,
        death_probability = 0.0,
        critical_onset_to_death = 0,
        symptomatic_homebound_probability = DEFAULT_SYMPTOMATIC_HOMEBOUND_PROBABILITY,
        severe_homebound_probability = DEFAULT_SEVERE_HOMEBOUND_PROBABILITY)

        for (nm, p) in ((:icu_to_ventilation_probability, icu_to_ventilation_probability),
            (:death_probability, death_probability),
            (:symptomatic_homebound_probability, symptomatic_homebound_probability),
            (:severe_homebound_probability, severe_homebound_probability))
            0.0 <= p <= 1.0 || throw(ArgumentError("$nm must be between 0 and 1 (got $p)."))
        end
        _check_homebound_order(symptomatic_homebound_probability, severe_homebound_probability)

        return new(severeness_onset_to_hospital_admission, critical_onset_to_icu_admission,
            icu_admission_to_icu_discharge, icu_to_ventilation_probability,
            icu_admission_to_ventilation_admission, ventilation_admission_to_ventilation_discharge,
            ventilation_discharge_to_icu_discharge, icu_discharge_to_hospital_discharge,
            death_probability, critical_onset_to_death,
            symptomatic_homebound_probability, severe_homebound_probability)
    end
end

"""
    calculate_health_profile(ic::ICUHealthProfile, individual::Individual, infection::InfectionState, rng::Xoshiro)

Care and mortality contribution of a single `ICU` infection: hospital and ICU are always entered, ventilation
and death are drawn as in `CriticalHealthProfile`.
"""
function calculate_health_profile(ic::ICUHealthProfile, individual::Individual, infection::InfectionState, rng::Xoshiro)
    icu_discharge::Int16 = Int16(-1)
    ventilation_admission::Int16 = Int16(-1)
    ventilation_discharge::Int16 = Int16(-1)
    death::Int16 = Int16(-1)

    hospital_admission::Int16 = rand_round(infection.severeness_onset + _rand_val(ic.severeness_onset_to_hospital_admission, rng), rng)
    icu_admission::Int16 = rand_round(infection.critical_onset + _rand_val(ic.critical_onset_to_icu_admission, rng), rng)
    # the ward admission cannot come after the ICU admission
    hospital_admission = min(hospital_admission, icu_admission)
    if gems_rand(rng) <= ic.icu_to_ventilation_probability
        ventilation_admission = rand_round(icu_admission + _rand_val(ic.icu_admission_to_ventilation_admission, rng), rng)
        ventilation_discharge = rand_round(ventilation_admission + _rand_val(ic.ventilation_admission_to_ventilation_discharge, rng), rng)
        icu_discharge = rand_round(ventilation_discharge + _rand_val(ic.ventilation_discharge_to_icu_discharge, rng), rng)
    else
        icu_discharge = rand_round(icu_admission + _rand_val(ic.icu_admission_to_icu_discharge, rng), rng)
    end
    hospital_discharge::Int16 = rand_round(icu_discharge + _rand_val(ic.icu_discharge_to_hospital_discharge, rng), rng)

    # death is independent of ventilation here; the ladder and the outcome are reconciled downstream
    if gems_rand(rng) <= ic.death_probability
        death = rand_round(infection.critical_onset + _rand_val(ic.critical_onset_to_death, rng), rng)
    end

    care = CareContribution(hospital_admission = hospital_admission, hospital_discharge = hospital_discharge,
        icu_admission = icu_admission, icu_discharge = icu_discharge,
        ventilation_admission = ventilation_admission, ventilation_discharge = ventilation_discharge)
    outcome = HealthOutcome(death = death, death_pathogen_id = infection.pathogen_id)
    return care, outcome
end

"""
    FatalHealthProfile

Health profile for the `Fatal` tier: a certain death, anchored at the infection's `critical_onset`, with care
drawn as in `CriticalHealthProfile`, and whether the host stays home.

# Parameters
- `hospital_probability::Real`: Hospital admission probability (`0.0` by default).
- `severeness_onset_to_hospital_admission::Union{Distribution, Real}`: Admission delay after severeness onset, unless the ICU admission comes first.
- `hospital_admission_to_hospital_discharge::Union{Distribution, Real}`: Ward stay length when the patient does not enter the ICU.
- `hospital_to_icu_probability::Real`: ICU probability for a hospitalized patient (`0.0` by default).
- `critical_onset_to_icu_admission::Union{Distribution, Real}`: ICU admission delay after critical onset.
- `icu_admission_to_icu_discharge::Union{Distribution, Real}`: ICU stay length when the patient is not ventilated.
- `icu_to_ventilation_probability::Real`: Ventilation probability for an ICU patient (`0.0` by default).
- `icu_admission_to_ventilation_admission::Union{Distribution, Real}`: Delay from ICU to ventilation admission.
- `ventilation_admission_to_ventilation_discharge::Union{Distribution, Real}`: Ventilation length.
- `ventilation_discharge_to_icu_discharge::Union{Distribution, Real}`: ICU stay after ventilation ends.
- `icu_discharge_to_hospital_discharge::Union{Distribution, Real}`: Hospital stay after ICU discharge.
- `critical_onset_to_death::Union{Distribution, Real}`: Delay from critical onset to death.
- `symptomatic_homebound_probability::Real`: Probability of being homebound from symptom onset to recovery (`0.0` by default).
- `severe_homebound_probability::Real`: Probability of being homebound while severe, at least `symptomatic_homebound_probability` (`1.0` by default).
"""
struct FatalHealthProfile <: HealthProfile
    hospital_probability::Float64
    severeness_onset_to_hospital_admission::Union{Distribution, Real}
    hospital_admission_to_hospital_discharge::Union{Distribution, Real}
    hospital_to_icu_probability::Float64
    critical_onset_to_icu_admission::Union{Distribution, Real}
    icu_admission_to_icu_discharge::Union{Distribution, Real}
    icu_to_ventilation_probability::Float64
    icu_admission_to_ventilation_admission::Union{Distribution, Real}
    ventilation_admission_to_ventilation_discharge::Union{Distribution, Real}
    ventilation_discharge_to_icu_discharge::Union{Distribution, Real}
    icu_discharge_to_hospital_discharge::Union{Distribution, Real}
    critical_onset_to_death::Union{Distribution, Real}
    symptomatic_homebound_probability::Float64
    severe_homebound_probability::Float64

    function FatalHealthProfile(;
        hospital_probability = 0.0,
        severeness_onset_to_hospital_admission = 0,
        hospital_admission_to_hospital_discharge = 0,
        hospital_to_icu_probability = 0.0,
        critical_onset_to_icu_admission = 0,
        icu_admission_to_icu_discharge = 0,
        icu_to_ventilation_probability = 0.0,
        icu_admission_to_ventilation_admission = 0,
        ventilation_admission_to_ventilation_discharge = 0,
        ventilation_discharge_to_icu_discharge = 0,
        icu_discharge_to_hospital_discharge = 0,
        critical_onset_to_death = 0,
        symptomatic_homebound_probability = DEFAULT_SYMPTOMATIC_HOMEBOUND_PROBABILITY,
        severe_homebound_probability = DEFAULT_SEVERE_HOMEBOUND_PROBABILITY)

        for (nm, p) in ((:hospital_probability, hospital_probability),
            (:hospital_to_icu_probability, hospital_to_icu_probability),
            (:icu_to_ventilation_probability, icu_to_ventilation_probability),
            (:symptomatic_homebound_probability, symptomatic_homebound_probability),
            (:severe_homebound_probability, severe_homebound_probability))
            0.0 <= p <= 1.0 || throw(ArgumentError("$nm must be between 0 and 1 (got $p)."))
        end
        _check_homebound_order(symptomatic_homebound_probability, severe_homebound_probability)

        return new(hospital_probability, severeness_onset_to_hospital_admission,
            hospital_admission_to_hospital_discharge, hospital_to_icu_probability,
            critical_onset_to_icu_admission, icu_admission_to_icu_discharge,
            icu_to_ventilation_probability, icu_admission_to_ventilation_admission,
            ventilation_admission_to_ventilation_discharge, ventilation_discharge_to_icu_discharge,
            icu_discharge_to_hospital_discharge, critical_onset_to_death,
            symptomatic_homebound_probability, severe_homebound_probability)
    end
end

"""
    calculate_health_profile(fc::FatalHealthProfile, individual::Individual, infection::InfectionState, rng::Xoshiro)

Care and mortality contribution of a single `Fatal` infection: care is drawn as in `CriticalHealthProfile`,
death always occurs.
"""
function calculate_health_profile(fc::FatalHealthProfile, individual::Individual, infection::InfectionState, rng::Xoshiro)
    hospital_admission::Int16 = Int16(-1)
    hospital_discharge::Int16 = Int16(-1)
    icu_admission::Int16 = Int16(-1)
    icu_discharge::Int16 = Int16(-1)
    ventilation_admission::Int16 = Int16(-1)
    ventilation_discharge::Int16 = Int16(-1)

    if gems_rand(rng) <= fc.hospital_probability
        hospital_admission = rand_round(infection.severeness_onset + _rand_val(fc.severeness_onset_to_hospital_admission, rng), rng)
        if gems_rand(rng) <= fc.hospital_to_icu_probability
            icu_admission = rand_round(infection.critical_onset + _rand_val(fc.critical_onset_to_icu_admission, rng), rng)
            # the ward admission cannot come after the ICU admission
            hospital_admission = min(hospital_admission, icu_admission)
            if gems_rand(rng) <= fc.icu_to_ventilation_probability
                ventilation_admission = rand_round(icu_admission + _rand_val(fc.icu_admission_to_ventilation_admission, rng), rng)
                ventilation_discharge = rand_round(ventilation_admission + _rand_val(fc.ventilation_admission_to_ventilation_discharge, rng), rng)
                icu_discharge = rand_round(ventilation_discharge + _rand_val(fc.ventilation_discharge_to_icu_discharge, rng), rng)
            else
                icu_discharge = rand_round(icu_admission + _rand_val(fc.icu_admission_to_icu_discharge, rng), rng)
            end
            hospital_discharge = rand_round(icu_discharge + _rand_val(fc.icu_discharge_to_hospital_discharge, rng), rng)
        else
            hospital_discharge = rand_round(hospital_admission + _rand_val(fc.hospital_admission_to_hospital_discharge, rng), rng)
        end
    end
    # the ladder and the death are reconciled downstream
    death::Int16 = rand_round(infection.critical_onset + _rand_val(fc.critical_onset_to_death, rng), rng)

    care = CareContribution(hospital_admission = hospital_admission, hospital_discharge = hospital_discharge,
        icu_admission = icu_admission, icu_discharge = icu_discharge,
        ventilation_admission = ventilation_admission, ventilation_discharge = ventilation_discharge)
    outcome = HealthOutcome(death = death, death_pathogen_id = infection.pathogen_id)
    return care, outcome
end

# splits the built-in profiles so `f` dispatches statically on them; custom profiles dispatch dynamically
@inline function _with_profile(f::F, profile::Union{Nothing, HealthProfile}) where {F}
    profile === nothing && return f(nothing)
    profile isa MildHealthProfile && return f(profile)
    profile isa SevereHealthProfile && return f(profile)
    profile isa CriticalHealthProfile && return f(profile)
    profile isa WardHealthProfile && return f(profile)
    profile isa ICUHealthProfile && return f(profile)
    profile isa FatalHealthProfile && return f(profile)
    return f(profile)
end


# anyone homebound from symptom onset is homebound while severe
_check_homebound_order(symptomatic_homebound_probability, severe_homebound_probability) =
    symptomatic_homebound_probability <= severe_homebound_probability || throw(ArgumentError(
        "symptomatic_homebound_probability ($symptomatic_homebound_probability) cannot exceed severe_homebound_probability ($severe_homebound_probability)."))



"""
    StandardOfCare

Internal carrier for per-tier health, applied to a progression category embedding none of its own.
Not part of the API: health belongs on the progression categories, and this exists only to carry the
deprecated `severe`/`critical` sub-tables of a pre-split `[HealthProgression]` section forward.
Delete along with that deprecation.

# Parameters
- `severe::Union{Nothing, HealthProfile}`: profile for `severe`-peak categories (`nothing` by default).
- `critical::Union{Nothing, HealthProfile}`: profile for `critical`-peak categories (`nothing` by default).
"""
struct StandardOfCare
    severe::Union{Nothing, HealthProfile}
    critical::Union{Nothing, HealthProfile}

    function StandardOfCare(;
        severe::Union{Nothing, HealthProfile} = nothing,
        critical::Union{Nothing, HealthProfile} = nothing
        )

        return new(severe, critical)
    end
end