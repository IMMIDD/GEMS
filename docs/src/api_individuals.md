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
education(::Individual)
end_quarantine!(::Individual)
has_municipality(::Individual)
home_quarantine!(::Individual)
household_id(::Individual)
id(::Individual)
infection_id(::Individual)
infectiousness!(::Individual, infectiousness)
infectiousness(::Individual)
is_student(::Individual)
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
quarantine_release_tick!(::Individual, ::Int16)
quarantine_release_tick(::Individual)
quarantine_status(::Individual)
quarantine_tick!(::Individual, ::Int16)
quarantine_tick(::Individual)
reset!(::Individual)
setting_id!(::Individual, ::DataType, ::Int32)
setting_id(::Individual, ::DataType)
settings(::Individual, ::Simulation)
sex(::Individual)
social_factor!(::Individual, ::Float32)
social_factor(::Individual)
vaccination_tick(::Individual)
vaccine_id(::Individual)
```