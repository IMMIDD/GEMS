export DiseaseProgression
export ProgressionCategory
export ProgressionAssignmentFunction

export exposure
export infectiousness_onset
export symptom_onset
export severeness_onset
export hospital_admission
export ICU_admission
export ICU_discharge
export hospital_discharge

export is_infected, isinfected, infected
export is_presymptomatic, ispresymptomatic, presymptomatic
export is_infectious, isinfectious, infectious
export is_asymptomatic, isasymptomatic, asymptomatic
export is_symptomatic, issymptomatic, symptomatic
export is_severe, issevere, severe
export is_mild, ismild, mild
export is_hospitalized, ishospitalized, hospitalized
export is_ICU, isICU, ICU
export is_recovered, isrecovered, recovered
export is_dead, isdead, dead

# Abstract types for disease progression categories and progression assignment functions
abstract type ProgressionCategory end
abstract type ProgressionAssignmentFunction end

"""
    DiseaseProgression

A struct to represent the disease progression of an infectious disease.

# Fields
- `exposure::Int16`: Exposure (infection) tick of the disease.
- `infectiousness_onset::Int16`: Tick when the individual becomes infectious.
- `symptom_onset::Int16`: Tick when the individual develops symptoms.
- `severeness_onset::Int16`: Tick when the individual develops severe symptoms.
- `hospital_admission::Int16`: Tick when the individual is admitted to hospital.
- `ICU_admission::Int16`: Tick when the individual is admitted to ICU.
- `ICU_discharge::Int16`: Tick when the individual is discharged from ICU.
- `hospital_discharge::Int16`: Tick when the individual is discharged from hospital.
- `recovery::Int16`: Tick when the individual recovers from the disease.
- `death::Int16`: Tick when the individual dies from the disease.

# Constraints
- `exposure` must be non-negative.
- `infectiousness_onset` must be at least one tick after `exposure`.
- `symptom_onset` is optional but must be at least one tick after `exposure` if set.
- `severeness_onset` is optional, but if set, requires `symptom_onset` and cannot be prior to `symptom_onset`.
- `hospital_admission` is optional, but if set, requires `severeness_onset`, cannot be prior to `severeness_onset`, and requires `hospital_discharge`.
- `ICU_admission` is optional, but if set, requires `hospital_admission`, cannot be prior to `hospital_admission`, and requires `ICU_discharge`.
- `ICU_discharge` is optional, but if set, requires `ICU_admission`, must be at least one tick after `ICU_admission`.
- `ventilation_admission` is optional, but if set, requires `hospital_admission`, cannot be prior to `hospital_admission`, and requires `ventilation_discharge`.
- `ventilation_discharge` is optional, but if set, requires `ventilation_admission`, must be at least one tick after `ventilation_admission`.
- `hospital_discharge` is optional, but if set, requires `hospital_admission`, must be at least one tick after `hospital_admission`, and cannot be prior to `ICU_discharge` if set.
- `recovery` and `death` are mutually exclusive; at least one must be set.
- `recovery` must be at least one tick after `exposure`, `symptom_onset` if set, `severeness_onset` if set, and cannot be prior to `hospital_discharge`.
- `death` requires `symptom_onset` and cannot precede any other disease progression events.

# Examples

The following example represents a mild symptomatic progression.
An individual get infected at time `23`, becomes infectious at `25`, develops symptoms at `26`, recovers at `31`, and does not die.

```julia
julia> DiseaseProgression(exposure = 23, infectiousness_onset = 25, symptom_onset = 26, recovery  = 31)
```

Output:

```julia
Disease Progression(
  tick | event
    23 | exposure
    25 | infectiousness_onset
    26 | symptom_onset
    31 | recovery
)
```
"""
struct DiseaseProgression

    exposure::Int16
    infectiousness_onset::Int16
    symptom_onset::Int16
    severeness_onset::Int16
    hospital_admission::Int16
    ICU_admission::Int16
    ICU_discharge::Int16
    ventilation_admission::Int16
    ventilation_discharge::Int16
    hospital_discharge::Int16
    recovery::Int16
    death::Int16

    function DiseaseProgression(;
        exposure = -1,
        infectiousness_onset = -1,
        symptom_onset = -1,
        severeness_onset = -1,
        hospital_admission = -1,
        ICU_admission = -1,
        ICU_discharge = -1,
        ventilation_admission = -1,
        ventilation_discharge = -1,
        hospital_discharge = -1,
        recovery = -1,
        death = -1)

        # SANITY CHECKS
        # exposure
        exposure < 0 && throw(ArgumentError("Exposure time must be non-negative."))
        # infectiousness onset
        infectiousness_onset <= exposure && throw(ArgumentError("Infectiousness onset must be at least one tick after exposure (exposure: $exposure, infectiousness_onset: $infectiousness_onset)."))
        # symptom onset
        symptom_onset >= 0 && symptom_onset <= exposure && throw(ArgumentError("Symptom onset must be at least one tick after exposure (exposure: $exposure, symptom_onset: $symptom_onset)."))
        # severeness onset
        severeness_onset >= 0 && symptom_onset < 0 && throw(ArgumentError("Symptom onset must be given if severeness onset is set (symptom_onset: $symptom_onset, severeness_onset: $severeness_onset)."))
        severeness_onset >= 0 && severeness_onset < symptom_onset && throw(ArgumentError("Severeness onset cannot happen before symptom onset (symptom_onset: $symptom_onset, severeness_onset: $severeness_onset)."))
        # hospital admission
        hospital_admission >= 0 && severeness_onset < 0 && throw(ArgumentError("Severeness onset must be given if hospital admission is set (severeness_onset: $severeness_onset, hospital_admission: $hospital_admission)."))
        hospital_admission >= 0 && hospital_admission < severeness_onset && throw(ArgumentError("Hospital admission cannot happen before severeness onset (severeness_onset: $severeness_onset, hospital_admission: $hospital_admission)."))
        hospital_admission >= 0 && hospital_discharge < 0 && throw(ArgumentError("Hospital admission cannot be set if hospital discharge is unset (hospital_admission: $hospital_admission, hospital_discharge: $hospital_discharge)."))
        # ICU admission
        ICU_admission >= 0 && hospital_admission < 0 && throw(ArgumentError("Hospital admission must be given if ICU admission is set (hospital_admission: $hospital_admission, ICU_admission: $ICU_admission)."))
        ICU_admission >= 0 && ICU_admission < hospital_admission && throw(ArgumentError("ICU admission cannot happen before hospital admission (hospital_admission: $hospital_admission, ICU_admission: $ICU_admission)."))
        ICU_admission >= 0 && ICU_discharge < 0 && throw(ArgumentError("ICU admission cannot be set if ICU discharge is unset (ICU_admission: $ICU_admission, ICU_discharge: $ICU_discharge)."))
        # ICU discharge
        ICU_discharge >= 0 && ICU_admission < 0 && throw(ArgumentError("ICU admission must be given if ICU discharge is set (ICU_admission: $ICU_admission, ICU_discharge: $ICU_discharge)."))
        ICU_discharge >= 0 && ICU_discharge <= ICU_admission && throw(ArgumentError("ICU discharge must be at least one tick after ICU admission (ICU_admission: $ICU_admission, ICU_discharge: $ICU_discharge)."))
        # ventilation admission
        ventilation_admission >= 0 && hospital_admission < 0 && throw(ArgumentError("Hospital admission must be given if ventilation admission is set (hospital_admission: $hospital_admission, ventilation_admission: $ventilation_admission)."))
        ventilation_admission >= 0 && ventilation_admission < hospital_admission && throw(ArgumentError("Ventilation admission cannot happen before hospital admission (hospital_admission: $hospital_admission, ventilation_admission: $ventilation_admission)."))
        ventilation_admission >= 0 && ventilation_discharge < 0 && throw(ArgumentError("Ventilation admission cannot be set if ventilation discharge is unset (ventilation_admission: $ventilation_admission, ventilation_discharge: $ventilation_discharge)."))
        # ventilation discharge
        ventilation_discharge >= 0 && ventilation_admission < 0 && throw(ArgumentError("Ventilation admission must be given if ventilation discharge is set (ventilation_admission: $ventilation_admission, ventilation_discharge: $ventilation_discharge)."))
        ventilation_discharge >= 0 && ventilation_discharge <= ventilation_admission && throw(ArgumentError("Ventilation discharge must be at least one tick after ventilation admission (ventilation_admission: $ventilation_admission, ventilation_discharge: $ventilation_discharge)."))
        # hospital discharge
        hospital_discharge >= 0 && hospital_admission < 0 && throw(ArgumentError("Hospital admission must be given if hospital discharge is set (hospital_admission: $hospital_admission, hospital_discharge: $hospital_discharge)."))
        hospital_discharge >= 0 && hospital_discharge <= hospital_admission && throw(ArgumentError("Hospital discharge must be at least one tick after hospital admission (hospital_admission: $hospital_admission, hospital_discharge: $hospital_discharge)."))
        hospital_discharge >= 0 && ICU_discharge >= 0 && hospital_discharge < ICU_discharge && throw(ArgumentError("Hospital discharge requires ICU discharge (ICU_discharge: $ICU_discharge, hospital_discharge: $hospital_discharge)."))
        # recovery and death (mutually exclusive)
        recovery >= 0 && death >= 0 && throw(ArgumentError("Recovery and death cannot both happen (recovery: $recovery, death: $death)."))
        recovery < 0 && death < 0 && throw(ArgumentError("Individuals must either recover or die (recovery: $recovery, death: $death)."))
        # recovery
        recovery >= 0 && infectiousness_onset >= recovery && throw(ArgumentError("Infectiousness cannot set on at or after recovery (infectiousness_onset: $infectiousness_onset, recovery: $recovery)."))
        recovery >= 0 && hospital_discharge > 0 && recovery < hospital_discharge && throw(ArgumentError("Recovery cannot happen before hospital discharge (hospital_discharge: $hospital_discharge, recovery: $recovery)."))
        recovery >= 0 && severeness_onset >= 0 && recovery <= severeness_onset && throw(ArgumentError("Recovery must be at least one tick after severeness onset (severeness_onset: $severeness_onset, recovery: $recovery)."))
        recovery >= 0 && symptom_onset >= 0 && recovery <= symptom_onset && throw(ArgumentError("Recovery must be at least one tick after symptom onset (symptom_onset: $symptom_onset, recovery: $recovery)."))
        recovery >= 0 && recovery <= exposure && throw(ArgumentError("Recovery must be at least one tick after exposure (exposure: $exposure, recovery: $recovery)."))
        # death
        death >= 0 && infectiousness_onset >= death && throw(ArgumentError("Infectiousness cannot set on at or after death (infectiousness_onset: $infectiousness_onset, death: $death)."))
        death >= 0 && symptom_onset < 0 && throw(ArgumentError("Asymptomatic individuals cannot die; symptom onset must be set (symptom_onset: $symptom_onset, death: $death)."))
        death >= 0 && symptom_onset >= 0 && death < symptom_onset && throw(ArgumentError("Death cannot happen before symptom onset (symptom_onset: $symptom_onset, death: $death)."))
        death >= 0 && severeness_onset > death && throw(ArgumentError("Individuals cannot develop severe symptoms after they died (severeness_onset: $severeness_onset, death: $death)."))
        death >= 0 && hospital_admission > death && throw(ArgumentError("Individuals cannot be admitted to hospital after they died (hospital_admission: $hospital_admission, death: $death)."))


        return new(
            Int16(exposure),
            Int16(infectiousness_onset),
            Int16(symptom_onset),
            Int16(severeness_onset),
            Int16(hospital_admission),
            Int16(ICU_admission),
            Int16(ICU_discharge),
            Int16(ventilation_admission),
            Int16(ventilation_discharge),
            Int16(hospital_discharge),
            Int16(recovery),
            Int16(death)
        )
    end
end

function Base.show(io::IO, dp::DiseaseProgression)
    
    max_val = max(dp.recovery, dp.death)
    max_width = max(4, length("$max_val")) # max width of tick column

    spcs(x, max) = length("$x") > max ? "" : repeat(" ", max - length("$x")) * "$x"
    
    res = "Disease Progression(\n"
    res *= "  $(spcs("tick", max_width)) | event\n"
    res *= dp.exposure >= 0 ?             "  $(spcs(dp.exposure, max_width)) | exposure\n" : ""
    res *= dp.infectiousness_onset >= 0 ? "  $(spcs(dp.infectiousness_onset, max_width)) | infectiousness_onset\n" : ""
    res *= dp.symptom_onset >= 0 ?        "  $(spcs(dp.symptom_onset, max_width)) | symptom_onset\n" : ""
    res *= dp.severeness_onset >= 0 ?     "  $(spcs(dp.severeness_onset, max_width)) | severeness_onset\n" : ""
    res *= dp.hospital_admission >= 0 ?   "  $(spcs(dp.hospital_admission, max_width)) | hospital_admission\n" : ""
    res *= dp.ICU_admission >= 0 ?        "  $(spcs(dp.ICU_admission, max_width)) | ICU_admission\n" : ""
    res *= dp.ICU_discharge >= 0 ?        "  $(spcs(dp.ICU_discharge, max_width)) | ICU_discharge\n" : ""
    res *= dp.ventilation_admission >= 0 ? "  $(spcs(dp.ventilation_admission, max_width)) | ventilation_admission\n" : ""
    res *= dp.ventilation_discharge >= 0 ? "  $(spcs(dp.ventilation_discharge, max_width)) | ventilation_discharge\n" : ""
    res *= dp.hospital_discharge >= 0 ?   "  $(spcs(dp.hospital_discharge, max_width)) | hospital_discharge\n" : ""
    res *= dp.recovery >= 0 ?             "  $(spcs(dp.recovery, max_width)) | recovery\n" : ""
    res *= dp.death >= 0 ?                "  $(spcs(dp.death, max_width)) | death\n" : ""
    res *= ")"
    print(io, res)
end


####
#### getter
####

"""
    exposure(dp::DiseaseProgression)

Returns the exposure (infection) tick of the disease progression `dp`.
"""
exposure(dp::DiseaseProgression) = dp.exposure

"""
    infectiousness_onset(dp::DiseaseProgression)

Returns the tick when the individual with disease progression `dp` becomes infectious.
"""
infectiousness_onset(dp::DiseaseProgression) = dp.infectiousness_onset

"""
    symptom_onset(dp::DiseaseProgression)

Returns the tick when the individual with disease progression `dp` develops symptoms.
If the individual is asymptomatic, this will return `-1`.
"""
symptom_onset(dp::DiseaseProgression) = dp.symptom_onset

"""
    severeness_onset(dp::DiseaseProgression)

Returns the tick when the individual with disease progression `dp` develops severe symptoms.
If the individual will not develop severe symptoms, this will return `-1`.
"""
severeness_onset(dp::DiseaseProgression) = dp.severeness_onset

"""
    hospital_admission(dp::DiseaseProgression)

Returns the tick when the individual with disease progression `dp` is admitted to hospital.
If the individual is never admitted to hospital, this will return `-1`.
"""
hospital_admission(dp::DiseaseProgression) = dp.hospital_admission

"""
    ICU_admission(dp::DiseaseProgression)

Returns the tick when the individual with disease progression `dp` is admitted to ICU.
If the individual is never admitted to ICU, this will return `-1`.
"""
ICU_admission(dp::DiseaseProgression) = dp.ICU_admission

"""
    ICU_discharge(dp::DiseaseProgression)

Returns the tick when the individual with disease progression `dp` is discharged from ICU.
If the individual is never admitted to ICU, this will return `-1`.
"""
ICU_discharge(dp::DiseaseProgression) = dp.ICU_discharge

"""
    hospital_discharge(dp::DiseaseProgression)
Returns the tick when the individual with disease progression `dp` is discharged from hospital.
If the individual is never admitted to hospital, this will return `-1`.
"""
hospital_discharge(dp::DiseaseProgression) = dp.hospital_discharge

"""
    recovery(dp::DiseaseProgression)

Returns the tick when the individual with disease progression `dp` recovers from the disease.
If the individual dies instead, this will return `-1`.
"""
recovery(dp::DiseaseProgression) = dp.recovery

"""
    death(dp::DiseaseProgression)

Returns the tick when the individual with disease progression `dp` dies from the disease.
If the individual recovers instead, this will return `-1`.
"""
death(dp::DiseaseProgression) = dp.death



####
#### checking disease states
####

"""
    is_infected(dp::DiseaseProgression, t::Int)
    isinfected(dp::DiseaseProgression, t::Int)    
    infected(dp::DiseaseProgression, t::Int)

Returns `true` if the individual with disease progression `dp` is infected at tick `t`, otherwise `false`.    
"""
is_infected(dp::DiseaseProgression, t::Int) = dp.exposure <= t < max(dp.recovery, dp.death)
isinfected(dp::DiseaseProgression, t::Int) = is_infected(dp, t)
infected(dp::DiseaseProgression, t::Int) = is_infected(dp, t)

"""
    is_infectious(dp::DiseaseProgression, t::Int)
    isinfectious(dp::DiseaseProgression, t::Int)
    infectious(dp::DiseaseProgression, t::Int)

Returns `true` if the individual with disease progression `dp` is infectious at tick `t`, otherwise `false`.
"""
is_infectious(dp::DiseaseProgression, t::Int) = dp.infectiousness_onset <= t < max(dp.recovery, dp.death)
isinfectious(dp::DiseaseProgression, t::Int) = is_infectious(dp, t)
infectious(dp::DiseaseProgression, t::Int) = is_infectious(dp, t)

"""
    is_presymptomatic(dp::DiseaseProgression, t::Int)
    ispresymptomatic(dp::DiseaseProgression, t::Int)
    presymptomatic(dp::DiseaseProgression, t::Int)

Returns `true` if the individual with disease progression `dp` is presymptomatic at tick `t`, otherwise `false`.
Presymptomatic means the individual is infected but has not yet developed symptoms (but will in the future).
"""
is_presymptomatic(dp::DiseaseProgression, t::Int) = dp.exposure <= t < dp.symptom_onset
ispresymptomatic(dp::DiseaseProgression, t::Int) = is_presymptomatic(dp, t)
presymptomatic(dp::DiseaseProgression, t::Int) = is_presymptomatic(dp, t)

"""
    is_symptomatic(dp::DiseaseProgression, t::Int)
    issymptomatic(dp::DiseaseProgression, t::Int)
    symptomatic(dp::DiseaseProgression, t::Int)

Returns `true` if the individual with disease progression `dp` is symptomatic at tick `t`, otherwise `false`.
"""
is_symptomatic(dp::DiseaseProgression, t::Int) = dp.symptom_onset <= t < max(dp.recovery, dp.death)
issymptomatic(dp::DiseaseProgression, t::Int) = is_symptomatic(dp, t)
symptomatic(dp::DiseaseProgression, t::Int) = is_symptomatic(dp, t)

"""
    is_asymptomatic(dp::DiseaseProgression, t::Int)
    isasymptomatic(dp::DiseaseProgression, t::Int)
    asymptomatic(dp::DiseaseProgression, t::Int)

Returns `true` if the individual with disease progression `dp` is asymptomatic at tick `t`, otherwise `false`.
Asymptomatic means the individual is infected, does currently not have symptoms and will not develop symptoms in the future.
"""
is_asymptomatic(dp::DiseaseProgression, t::Int) = is_infected(dp, t) && !is_symptomatic(dp, t) && dp.symptom_onset > 0
isasymptomatic(dp::DiseaseProgression, t::Int) = is_asymptomatic(dp, t)
asymptomatic(dp::DiseaseProgression, t::Int) = is_asymptomatic(dp, t)

"""
    is_severe(dp::DiseaseProgression, t::Int)
    issevere(dp::DiseaseProgression, t::Int)
    severe(dp::DiseaseProgression, t::Int)

Returns `true` if the individual with disease progression `dp` has severe symptoms at tick `t`, otherwise `false`.
"""
is_severe(dp::DiseaseProgression, t::Int) = dp.severeness_onset <= t < max(dp.recovery, dp.death)
issevere(dp::DiseaseProgression, t::Int) = is_severe(dp, t)
severe(dp::DiseaseProgression, t::Int) = is_severe(dp, t)

"""
    is_mild(dp::DiseaseProgression, t::Int)
    ismild(dp::DiseaseProgression, t::Int)
    mild(dp::DiseaseProgression, t::Int)

Returns `true` if the individual with disease progression `dp` has mild symptoms at tick `t`, otherwise `false`.
A mild case is defined as symptomatic but not severe.
"""
is_mild(dp::DiseaseProgression, t::Int) = is_symptomatic(dp, t) && !is_severe(dp, t)
ismild(dp::DiseaseProgression, t::Int) = is_mild(dp, t)
mild(dp::DiseaseProgression, t::Int) = is_mild(dp, t)

"""
    is_hospitalized(dp::DiseaseProgression, t::Int)
    ishospitalized(dp::DiseaseProgression, t::Int)
    hospitalized(dp::DiseaseProgression, t::Int)

Returns `true` if the individual with disease progression `dp` is in hospital at tick `t`, otherwise `false`.
"""
is_hospitalized(dp::DiseaseProgression, t::Int) = dp.hospital_admission <= t < dp.hospital_discharge
ishospitalized(dp::DiseaseProgression, t::Int) = is_hospitalized(dp, t)
hospitalized(dp::DiseaseProgression, t::Int) = is_hospitalized(dp, t)

"""
    is_ICU(dp::DiseaseProgression, t::Int)
    isICU(dp::DiseaseProgression, t::Int)
    ICU(dp::DiseaseProgression, t::Int)

Returns `true` if the individual with disease progression `dp` is in the ICU at tick `t`, otherwise `false`.
"""
is_ICU(dp::DiseaseProgression, t::Int) = dp.ICU_admission <= t < dp.ICU_discharge
isICU(dp::DiseaseProgression, t::Int) = is_ICU(dp, t)
ICU(dp::DiseaseProgression, t::Int) = is_ICU(dp, t)

"""
    is_recovered(dp::DiseaseProgression, t::Int)
    isrecovered(dp::DiseaseProgression, t::Int)
    recovered(dp::DiseaseProgression, t::Int)

Returns `true` if the individual with disease progression `dp` has recovered before tick `t`, otherwise `false`.
"""
is_recovered(dp::DiseaseProgression, t::Int) = 0 <= dp.recovery <= t
isrecovered(dp::DiseaseProgression, t::Int) = is_recovered(dp, t)
recovered(dp::DiseaseProgression, t::Int) = is_recovered(dp, t)

"""
    is_dead(dp::DiseaseProgression, t::Int)
    isdead(dp::DiseaseProgression, t::Int)
    dead(dp::DiseaseProgression, t::Int)

Returns `true` if the individual with disease progression `dp` has died before tick `t`, otherwise `false`.
"""
is_dead(dp::DiseaseProgression, t::Int) = 0 <= dp.death <= t
isdead(dp::DiseaseProgression, t::Int) = is_dead(dp, t)
dead(dp::DiseaseProgression, t::Int) = is_dead(dp, t)