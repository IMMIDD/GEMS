# Individuals
hier eine subsection: wie fragt man den Status der agents ab (hier alle funktionen, wie man states queried)

## Overview Structs
```@index
Pages   = ["api_individuals.md"]
Order   = [:type]
```
## Overview Functions
```@index
Pages   = ["api_individuals.md"]
Order   = [:function]
```

## Structs
```@docs
Agent
Individual
```

## Constructors
```@docs
Individual(::Dict)
Individual(::DataFrameRow)
```

## Functions
```@docs
age
class_id
comorbidities
dead!(::Individual, ::Bool)
death(::Individual)
death!(::Individual, ::Int16)
detected!(::Individual, ::Bool)
education(::Individual)
end_quarantine!(::Individual)
exposure(::Individual)
exposure!(::Individual, ::Int16)
has_municipality(::Individual)
home_quarantine!(::Individual)
hospital_admission(::Individual)
hospital_admission!(::Individual, ::Int16)
hospital_discharge(::Individual)
hospital_discharge!(::Individual, ::Int16)
hospitalized!(::Individual, ::Bool)
household_id(::Individual)
icu_admission(::Individual)
icu_admission!(::Individual, ::Int16)
icu_discharge(::Individual)
icu_discharge!(::Individual, ::Int16)
id(::Individual)
infected!(::Individual,::Bool)
infection_id(::Individual)
infectious!(::Individual, ::Bool)
infectiousness!(::Individual, infectiousness)
infectiousness(::Individual)
infectiousness_onset(::Individual)
infectiousness_onset!(::Individual, ::Int16)
is_dead(::Individual)
is_dead(::Individual, ::Int16)
is_detected(::Individual)
is_detected(::Individual, ::Int16)
is_exposed(::Individual)
is_exposed(::Individual, ::Int16)
is_hospitalized(::Individual)
is_hospitalized(::Individual, ::Int16)
is_icu(::Individual)
is_icu(::Individual, ::Int16)
is_infected(::Individual)
is_infected(::Individual, ::Int16)
is_infectious(::Individual)
is_infectious(::Individual, ::Int16)
is_mild(::Individual, ::Int16)
is_presymptomatic(::Individual, ::Int16)
is_recovered(::Individual, ::Int16)
is_severe(::Individual)
is_severe(::Individual, ::Int16)
is_student(::Individual)
is_symptomatic(::Individual)
is_symptomatic(::Individual, ::Int16)
is_ventilated(::Individual)
is_ventilated(::Individual, ::Int16)
is_working(::Individual)
isquarantined(::Individual)
isvaccinated(::Individual)
last_reported_at!(::Individual, ::Int16)
last_reported_at(::Individual)
last_test!(::Individual, ::Int16)
last_test(::Individual)
last_test_result!(::Individual, ::Bool)
last_test_result(::Individual)
mandate_compliance!(::Individual, ::Float32)
mandate_compliance(::Individual)
municipality(::Individual, ::Simulation)
municipality_id(::Individual)
num_of_infected(::Vector{Individual})
number_of_infections(::Individual)
number_of_vaccinations(::Individual)
occupation(::Individual)
office(::Individual, ::Simulation)
office_id(::Individual)
pathogen_id(::Individual)
progress_disease!(::Individual, ::Int16)
quarantine_release_tick!(::Individual, ::Int16)
quarantine_release_tick(::Individual)
quarantine_status(::Individual)
quarantine_tick!(::Individual, ::Int16)
quarantine_tick(::Individual)
recovery(::Individual)
recovery!(::Individual, ::Int16)
reset!(::Individual)
setting_id!(::Individual, ::DataType, ::Int32)
setting_id(::Individual, ::DataType)
settings(::Individual, ::Simulation)
severe!(::Individual, ::Bool)
severeness_offset(::Individual)
severeness_offset!(::Individual, ::Int16)
severeness_onset(::Individual)
severeness_onset!(::Individual, ::Int16)
sex(::Individual)
social_factor!(::Individual, ::Float32)
social_factor(::Individual)
symptom_onset(::Individual)
symptom_onset!(::Individual, ::Int16)
symptomatic!(::Individual, ::Bool)
vaccination_tick(::Individual)
vaccine_id(::Individual)
ventilated!(::Individual, ::Bool)
ventilation_admission(::Individual)
ventilation_admission!(::Individual, ::Int16)
ventilation_discharge(::Individual)
ventilation_discharge!(::Individual, ::Int16)
```