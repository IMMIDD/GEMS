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
critical!(::Individual)
critical(::Individual)
dead(::Individual)
death_tick!(::Individual, ::Int16)
death_tick(::Individual)
disease_state(::Individual)
education(::Individual)
end_quarantine!(::Individual)
estimate_disease_progression(::DiseaseProgressionStrat, ::Individual)
exposed(::Individual)
exposed_tick!(::Individual, ::Int16)
exposed_tick(::Individual)
has_municipality(::Individual)
hospital_status(::Individual)
hospitalize!(::Individual)
hospitalized(::Individual)
hospitalized_tick!(::Individual, ::Int16)
hospitalized_tick(::Individual)
household_id(::Individual)
icu!(::Individual)
icu(::Individual)
icu_tick!(::Individual, ::Int16)
icu_tick(::Individual)
id(::Individual)
individuals!
individuals
infect!
infected(::Individual)
infection_id(::Individual)
infectious(::Individual)
infectious_tick!(::Individual, ::Int16)
infectious_tick(::Individual)
infectiousness!(::Individual, infectiousness)
infectiousness(::Individual)
is_student(::Individual)
is_working(::Individual)
isdetected(::Individual)
isquarantined(::Individual)
issubset(::Individual, ::Individual)
isvaccinated(::Individual)
kill!(::Individual)
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
onset_of_severeness!(::Individual, ::Int16)
onset_of_severeness(::Individual)
onset_of_symptoms!(::Individual, ::Int16)
onset_of_symptoms(::Individual)
pathogen_id(::Individual)
presymptomatic!(::Individual)
presymptomatic(::Individual)
progress_disease!(::Individual, ::Int16, ::Dict)
quarantine_release_tick!(::Individual, ::Int16)
quarantine_release_tick(::Individual)
quarantine_status(::Individual)
quarantine_tick!(::Individual, ::Int16)
quarantine_tick(::Individual)
recover!(::Individual)
removed_tick!(::Individual, ::Int16)
removed_tick(::Individual)
reset!(::Individual)
sample_critical_death_rate(::Pathogen, ::Individual)
sample_hospitalization_rate(::Pathogen, ::Individual)
sample_icu_rate(::Pathogen, ::Individual)
sample_individuals
sample_infectious_offset(::Pathogen, ::Individual)
sample_length_of_stay(::Pathogen, ::Individual)
sample_mild_death_rate(::Pathogen, ::Individual)
sample_onset_of_severeness(::Pathogen, ::Individual)
sample_onset_of_symptoms(::Pathogen, ::Individual)
sample_self_quarantine_rate(::Pathogen, ::Individual)
sample_severe_death_rate(::Pathogen, ::Individual)
sample_time_to_hospitalization(::Pathogen, ::Individual)
sample_time_to_icu(::Pathogen, ::Individual)
sample_time_to_recovery(::Pathogen, ::Individual)
sample_ventilation_rate(::Pathogen, ::Individual)
setting_id!(::Individual, ::DataType, ::Int32)
setting_id(::Individual, ::DataType)
severe!(::Individual)
severe(::Individual)
sex(::Individual)
social_factor!(::Individual, ::Float32)
social_factor(::Individual)
symptom_category!(::Individual, ::Int8)
symptom_category(::Individual)
symptomatic!(::Individual)
symptomatic(::Individual)
update_individual!(::Individual, ::Int16, ::Simulation)
vaccination_tick(::Individual)
vaccine_id(::Individual)
ventilate!(::Individual)
ventilated(::Individual)
ventilation_tick!(::Individual, ::Int16)
ventilation_tick(::Individual)
```