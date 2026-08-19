export DiseaseProgression
export ProgressionCategory
export ProgressionAssignmentFunction

export pathogen_id

export exposure
export infectiousness_onset
export symptom_onset
export severeness_onset
export critical_onset
export critical_offset
export severeness_offset

export is_infected, isinfected, infected
export is_presymptomatic, ispresymptomatic, presymptomatic
export is_infectious, isinfectious, infectious
export is_asymptomatic, isasymptomatic, asymptomatic
export is_symptomatic, issymptomatic, symptomatic
export is_severe, issevere, severe
export is_critical, iscritical, critical
export is_mild, ismild, mild
export is_recovered, isrecovered, recovered

"""
    DiseaseProgression

A struct to represent the disease progression of an infectious disease.

# Fields
- `exposure::Int16`: Exposure (infection) tick of the disease.
- `infectiousness_onset::Int16`: Tick when the individual becomes infectious.
- `symptom_onset::Int16`: Tick when the individual develops symptoms.
- `severeness_onset::Int16`: Tick when the individual develops severe symptoms.
- `critical_onset::Int16`: Tick when the individual develops critical symptoms.
- `critical_offset::Int16`: Tick when the individual's critical symptoms subside.
- `severeness_offset::Int16`: Tick when the individual's severe symptoms subside.
- `recovery::Int16`: Tick when the individual recovers from the disease.

# Constraints
- `exposure` must be non-negative.
- `infectiousness_onset` must be at least one tick after `exposure`.
- `symptom_onset` is optional but must be at least one tick after `exposure` if set.
- `severeness_onset` is optional, but if set, requires `symptom_onset`, cannot be prior to `symptom_onset`, and requires `severeness_offset`.
- `severeness_offset` is optional, but if set, requires `severeness_onset` and cannot be prior to `severeness_onset`.
- `critical_onset` is optional, but if set, requires `severeness_onset`, cannot be prior to `severeness_onset`, and requires `critical_offset`.
- `critical_offset` is optional, but if set, requires `critical_onset` and cannot be prior to `critical_onset`.
- `recovery` must be set, at least one tick after `exposure`, and cannot be prior to `symptom_onset`, `severeness_offset`, or `critical_offset` if set.

# Examples

The following example represents a mild symptomatic progression.
An individual get infected at time `23`, becomes infectious at `25`, develops symptoms at `26`, recovers at `31`, and does not die.

```julia
julia> DiseaseProgression(exposure = 23, infectiousness_onset = 25, symptom_onset = 26, recovery  = 31)
```

Output:

```julia
DiseaseProgression(
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
    critical_onset::Int16
    critical_offset::Int16
    severeness_offset::Int16
    recovery::Int16

    function DiseaseProgression(
        exposure::Int16,
        infectiousness_onset::Int16,
        symptom_onset::Int16,
        severeness_onset::Int16,
        critical_onset::Int16,
        critical_offset::Int16,
        severeness_offset::Int16,
        recovery::Int16
    )

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
        severeness_onset >= 0 && severeness_offset < 0 && throw(ArgumentError("Severeness onset cannot be set if severeness offset is unset (severeness_onset: $severeness_onset, severeness_offset: $severeness_offset)."))
        # severeness offset
        severeness_offset >= 0 && severeness_onset < 0 && throw(ArgumentError("Severeness onset must be given if severeness offset is set (severeness_onset: $severeness_onset, severeness_offset: $severeness_offset)."))
        severeness_offset >= 0 && severeness_offset < severeness_onset && throw(ArgumentError("Severeness offset cannot happen before severeness onset (severeness_onset: $severeness_onset, severeness_offset: $severeness_offset)."))
        # critical onset
        critical_onset >= 0 && severeness_onset < 0 && throw(ArgumentError("Severeness onset must be given if critical onset is set (severeness_onset: $severeness_onset, critical_onset: $critical_onset)."))
        critical_onset >= 0 && critical_onset < severeness_onset && throw(ArgumentError("Critical onset cannot happen before severeness onset (severeness_onset: $severeness_onset, critical_onset: $critical_onset)."))
        critical_onset >= 0 && critical_offset < 0 && throw(ArgumentError("Critical onset cannot be set if critical offset is unset (critical_onset: $critical_onset, critical_offset: $critical_offset)."))
        # critical offset
        critical_offset >= 0 && critical_onset < 0 && throw(ArgumentError("Critical onset must be given if critical offset is set (critical_onset: $critical_onset, critical_offset: $critical_offset)."))
        critical_offset >= 0 && critical_offset < critical_onset && throw(ArgumentError("Critical offset cannot happen before critical onset (critical_onset: $critical_onset, critical_offset: $critical_offset)."))
        # recovery
        recovery < 0 && throw(ArgumentError("Individuals must recover (recovery: $recovery)."))
        recovery < infectiousness_onset && throw(ArgumentError("Infectiousness cannot set on after recovery (infectiousness_onset: $infectiousness_onset, recovery: $recovery)."))
        severeness_offset >= 0 && recovery < severeness_offset && throw(ArgumentError("Recovery cannot happen before severeness offset (severeness_offset: $severeness_offset, recovery: $recovery)."))
        critical_offset >= 0 && recovery < critical_offset && throw(ArgumentError("Recovery cannot happen before critical offset (critical_offset: $critical_offset, recovery: $recovery)."))
        severeness_onset >= 0 && recovery < severeness_onset && throw(ArgumentError("Recovery cannot happen before severeness onset (severeness_onset: $severeness_onset, recovery: $recovery)."))
        symptom_onset >= 0 && recovery < symptom_onset && throw(ArgumentError("Recovery cannot happen before symptom onset (symptom_onset: $symptom_onset, recovery: $recovery)."))
        recovery < exposure && throw(ArgumentError("Recovery cannot happen before exposure (exposure: $exposure, recovery: $recovery)."))


        return new(
            exposure,
            infectiousness_onset,
            symptom_onset,
            severeness_onset,
            critical_onset,
            critical_offset,
            severeness_offset,
            recovery
        )
    end

    @inline function DiseaseProgression(;
        exposure = Int16(-1),
        infectiousness_onset = Int16(-1),
        symptom_onset = Int16(-1),
        severeness_onset = Int16(-1),
        critical_onset = Int16(-1),
        critical_offset = Int16(-1),
        severeness_offset = Int16(-1),
        recovery = Int16(-1)
    )
        return DiseaseProgression(
            Int16(exposure),
            Int16(infectiousness_onset),
            Int16(symptom_onset),
            Int16(severeness_onset),
            Int16(critical_onset),
            Int16(critical_offset),
            Int16(severeness_offset),
            Int16(recovery)
        )
    end
end

function Base.show(io::IO, dp::DiseaseProgression)
    
    max_val = dp.recovery
    max_width = max(4, length("$max_val")) # max width of tick column

    spcs(x, max) = length("$x") > max ? "" : repeat(" ", max - length("$x")) * "$x"

    res = "Disease Progression(\n"
    res *= "  $(spcs("tick", max_width)) | event\n"
    res *= dp.exposure >= 0 ?             "  $(spcs(dp.exposure, max_width)) | exposure\n" : ""
    res *= dp.infectiousness_onset >= 0 ? "  $(spcs(dp.infectiousness_onset, max_width)) | infectiousness_onset\n" : ""
    res *= dp.symptom_onset >= 0 ?        "  $(spcs(dp.symptom_onset, max_width)) | symptom_onset\n" : ""
    res *= dp.severeness_onset >= 0 ?     "  $(spcs(dp.severeness_onset, max_width)) | severeness_onset\n" : ""
    res *= dp.critical_onset >= 0 ?       "  $(spcs(dp.critical_onset, max_width)) | critical_onset\n" : ""
    res *= dp.critical_offset >= 0 ?      "  $(spcs(dp.critical_offset, max_width)) | critical_offset\n" : ""
    res *= dp.severeness_offset >= 0 ?     "  $(spcs(dp.severeness_offset, max_width)) | severeness_offset\n" : ""
    res *= dp.recovery >= 0 ?             "  $(spcs(dp.recovery, max_width)) | recovery\n" : ""
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
    critical_onset(dp::DiseaseProgression)

Returns the tick when the individual with disease progression `dp` develops critical symptoms.
If the individual will not develop critical symptoms, this will return `-1`.
"""
critical_onset(dp::DiseaseProgression) = dp.critical_onset

"""
    critical_offset(dp::DiseaseProgression)

Returns the tick when the individual with disease progression `dp`'s critical symptoms subside.
If the individual never has critical symptoms, this will return `-1`.
"""
critical_offset(dp::DiseaseProgression) = dp.critical_offset

"""
    severeness_offset(dp::DiseaseProgression)

Returns the tick when the individual with disease progression `dp`'s severeness is reduced (i.e., moves from severe to mild symptoms).
If the individual never has severe symptoms, this will return `-1`.
"""
severeness_offset(dp::DiseaseProgression) = dp.severeness_offset

"""
    recovery(dp::DiseaseProgression)

Returns the tick when the individual with disease progression `dp` recovers from the disease.
"""
recovery(dp::DiseaseProgression) = dp.recovery



####
#### checking disease states
####

"""
    is_infected(dp::DiseaseProgression, t::Int16)
    isinfected(dp::DiseaseProgression, t::Int16)
    infected(dp::DiseaseProgression, t::Int16)

Returns `true` if the individual with disease progression `dp` is infected at tick `t`, otherwise `false`.    
"""
is_infected(dp::DiseaseProgression, t::Int16) = dp.exposure <= t < dp.recovery
isinfected(dp::DiseaseProgression, t::Int16) = is_infected(dp, t)
infected(dp::DiseaseProgression, t::Int16) = is_infected(dp, t)

"""
    is_infectious(dp::DiseaseProgression, t::Int16)
    isinfectious(dp::DiseaseProgression, t::Int16)
    infectious(dp::DiseaseProgression, t::Int16)

Returns `true` if the individual with disease progression `dp` is infectious at tick `t`, otherwise `false`.
"""
is_infectious(dp::DiseaseProgression, t::Int16) = dp.infectiousness_onset <= t < dp.recovery
isinfectious(dp::DiseaseProgression, t::Int16) = is_infectious(dp, t)
infectious(dp::DiseaseProgression, t::Int16) = is_infectious(dp, t)

"""
    is_presymptomatic(dp::DiseaseProgression, t::Int16)
    ispresymptomatic(dp::DiseaseProgression, t::Int16)
    presymptomatic(dp::DiseaseProgression, t::Int16)

Returns `true` if the individual with disease progression `dp` is presymptomatic at tick `t`, otherwise `false`.
Presymptomatic means the individual is infected but has not yet developed symptoms (but will in the future).
"""
is_presymptomatic(dp::DiseaseProgression, t::Int16) = dp.exposure <= t < dp.symptom_onset
ispresymptomatic(dp::DiseaseProgression, t::Int16) = is_presymptomatic(dp, t)
presymptomatic(dp::DiseaseProgression, t::Int16) = is_presymptomatic(dp, t)

"""
    is_symptomatic(dp::DiseaseProgression, t::Int16)
    issymptomatic(dp::DiseaseProgression, t::Int16)
    symptomatic(dp::DiseaseProgression, t::Int16)

Returns `true` if the individual with disease progression `dp` is symptomatic at tick `t`, otherwise `false`.
"""
is_symptomatic(dp::DiseaseProgression, t::Int16) = 0 <= dp.symptom_onset <= t < dp.recovery
issymptomatic(dp::DiseaseProgression, t::Int16) = is_symptomatic(dp, t)
symptomatic(dp::DiseaseProgression, t::Int16) = is_symptomatic(dp, t)

"""
    is_asymptomatic(dp::DiseaseProgression, t::Int16)
    isasymptomatic(dp::DiseaseProgression, t::Int16)
    asymptomatic(dp::DiseaseProgression, t::Int16)

Returns `true` if the individual with disease progression `dp` is asymptomatic at tick `t`, otherwise `false`.
Asymptomatic means the individual is infected, does currently not have symptoms and will not develop symptoms in the future.
"""
is_asymptomatic(dp::DiseaseProgression, t::Int16) = is_infected(dp, t) && !is_symptomatic(dp, t) && dp.symptom_onset <= 0
isasymptomatic(dp::DiseaseProgression, t::Int16) = is_asymptomatic(dp, t)
asymptomatic(dp::DiseaseProgression, t::Int16) = is_asymptomatic(dp, t)

"""
    is_severe(dp::DiseaseProgression, t::Int16)
    issevere(dp::DiseaseProgression, t::Int16)
    severe(dp::DiseaseProgression, t::Int16)

Returns `true` if the individual with disease progression `dp` has severe symptoms at tick `t`, otherwise `false`.
"""
is_severe(dp::DiseaseProgression, t::Int16) = 0 <= dp.severeness_onset <= t < dp.severeness_offset
issevere(dp::DiseaseProgression, t::Int16) = is_severe(dp, t)
severe(dp::DiseaseProgression, t::Int16) = is_severe(dp, t)

"""
    is_critical(dp::DiseaseProgression, t::Int16)
    iscritical(dp::DiseaseProgression, t::Int16)
    critical(dp::DiseaseProgression, t::Int16)

Returns `true` if the individual with disease progression `dp` has critical symptoms at tick `t`, otherwise `false`.
"""
is_critical(dp::DiseaseProgression, t::Int16) = 0 <= dp.critical_onset <= t < dp.critical_offset
iscritical(dp::DiseaseProgression, t::Int16) = is_critical(dp, t)
critical(dp::DiseaseProgression, t::Int16) = is_critical(dp, t)

"""
    is_mild(dp::DiseaseProgression, t::Int16)
    ismild(dp::DiseaseProgression, t::Int16)
    mild(dp::DiseaseProgression, t::Int16)

Returns `true` if the individual with disease progression `dp` has mild symptoms at tick `t`, otherwise `false`.
A mild case is defined as symptomatic but not severe.
"""
is_mild(dp::DiseaseProgression, t::Int16) = is_symptomatic(dp, t) && !is_severe(dp, t)
ismild(dp::DiseaseProgression, t::Int16) = is_mild(dp, t)
mild(dp::DiseaseProgression, t::Int16) = is_mild(dp, t)

"""
    is_recovered(dp::DiseaseProgression, t::Int16)
    isrecovered(dp::DiseaseProgression, t::Int16)
    recovered(dp::DiseaseProgression, t::Int16)

Returns `true` if the individual with disease progression `dp` has recovered before tick `t`, otherwise `false`.
"""
is_recovered(dp::DiseaseProgression, t::Int16) = 0 <= dp.recovery <= t
isrecovered(dp::DiseaseProgression, t::Int16) = is_recovered(dp, t)
recovered(dp::DiseaseProgression, t::Int16) = is_recovered(dp, t)