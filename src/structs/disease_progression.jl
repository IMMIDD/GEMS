export DiseaseProgression

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
    res *= dp.hospital_discharge >= 0 ?   "  $(spcs(dp.hospital_discharge, max_width)) | hospital_discharge\n" : ""
    res *= dp.recovery >= 0 ?             "  $(spcs(dp.recovery, max_width)) | recovery\n" : ""
    res *= dp.death >= 0 ?                "  $(spcs(dp.death, max_width)) | death\n" : ""
    res *= ")"
    print(io, res)
end