###
### PATHOGENS (TYPE DEFINITION & BASIC FUNCTIONALITY)
###
export Pathogen
export id, name
export infection_rate, mild_death_rate, severe_death_rate, critical_death_rate
export hospitalization_rate, ventilation_rate, icu_rate
export onset_of_symptoms, onset_of_severeness, infectious_offset, time_to_recovery
export time_to_hospitalization, time_to_icu, length_of_stay
export disease_progression_strat, transmission_function, transmission_function!
export parameters

"""
    Pathogen <: Parameter

A type representing a pathogen.

# Instantiation

The instantiation requires at least an `id` and a `name` that must be supplied
as keyword arguments. All other fields are optional parameters.

```julia
covid = Pathogen(id = 1, name = "COVID19")
flu = Pathogen(id = 2, name = "Flu", onset_of_symptoms = Poission(3))
```
# Parameters

- `id::Int8`: Unique identifier pathogen
- `name::String`: Name of the pathogen
- `dpr::DiseaseProgressionStrat = DiseaseProgressionStrat()` *(optional)*: Defines the distribution of symptom categories across age groups
- `infection_rate::Distribution = Uniform(0,1)` *(optional)*: Distribution of the infection rate
- `mild_death_rate::Distribution = Uniform(0,0.005)` *(optional)*: Distribution of the death rate for mild cases
- `severe_death_rate::Distribution = Uniform(0,0.1)` *(optional)*: Distribution of the death rate for severe cases
- `critical_death_rate::Distribution = Uniform(0,0.1)` *(optional)*: Distribution of the death rate for critical cases
- `hospitalization_rate::Distribution = Uniform(0, 0.1)` *(optional)*: Distribution of the probability for a severe case to be hospitalized
- `ventilation_rate::Distribution = Uniform(0, 0.1)` *(optional)*: Distribution of the probability for a critical case to need ventilation
- `icu_rate::Distribution = Uniform(0, 0.1)` *(optional)*: Distribution of the probability for a critical case to need ICU
- `onset_of_symptoms::Distribution = Uniform(2,3)` *(optional)*: Distribution of time till onset of symptoms from becoming exposed
- `onset_of_severeness::Distribution = Uniform(2,3)` *(optional)*: Distribution of time till onset of severeness from onset of symptoms
- `infectious_offset::Distribution = Uniform(0,1)` *(optional)*: Distribution of the offset to become infectious compared to the onset of symptoms
- `time_to_hospitalization::Distribution = Uniform(0,1)` *(optional)*: Distribution of time till hospitalization from onset of symptoms
- `time_to_icu::Distribution = Uniform(0,1)` *(optional)*: Distribution of time till ICU from hospitalization
- `time_to_recovery::Distribution = Uniform(5,6) ` *(optional)*: Distribution of time till recovery from becoming exposed
- `length_of_stay::Distribution = Uniform(6,7)` *(optional)*: Distribution of time duration to stay in hospital
"""
@with_kw mutable struct Pathogen <: Parameter
    id::Int8
    name::String

    # Probability Distributions
    infection_rate::Distribution = Uniform(0,1) # probability of infection per contact TODO REMOVE!!!!!
    mild_death_rate::Distribution = Uniform(0,0.005) # probability of death with mild progression
    severe_death_rate::Distribution = Uniform(0,0.1) # probability of death with severe progression
    critical_death_rate::Distribution = Uniform(0,0.1) # probability of death with critical progression
    
    hospitalization_rate::Distribution = Uniform(0, 0.1) # probability of hospitalization with severe progression
    ventilation_rate::Distribution = Uniform(0, 0.1) # probability of ventilation with critical progression
    icu_rate::Distribution = Uniform(0, 0.1) # probability of icu with ventilation

    # Time Distributions
    onset_of_symptoms::Distribution = Uniform(2,3) # Uniform distribution (2-3 days) as default for testing purposes
    onset_of_severeness::Distribution = Uniform(2,3) # Uniform distribution (2-3 days) as default for testing purposes
    infectious_offset::Distribution = Uniform(0,1) # Uniform distribution (0-1 days)
    time_to_hospitalization::Distribution = Uniform(0,1) # as an increment from onset of symptoms
    time_to_icu::Distribution = Uniform(0,1) # as an increment from time to hospitalization 

    time_to_recovery::Distribution = Uniform(5,6) # as an increment from onset of symptoms
    length_of_stay::Distribution = Uniform(6,7) # as an increment from time_to_hospitalization

    # Probabilities of Disease Progression
    dpr::DiseaseProgressionStrat = DiseaseProgressionStrat()

    # Function for the transmission Probability
    transmission_function::TransmissionFunction = ConstantTransmissionRate()
end

### BASIC FUNCTIONALITY aka GETTER/SETTER
"""
    id(pathogen::Pathogen)

Returns the id of the pathogen.
"""
function id(pathogen::Pathogen)
    return pathogen.id
end

"""
    name(pathogen::Pathogen)

Returns the name of the pathogen.
"""
function name(pathogen::Pathogen)
    return pathogen.name
end

### Probability Distributions ###
"""
    infection_rate(pathogen::Pathogen)

Returns the infection rate (distribution) of the pathogen.
"""
function infection_rate(pathogen::Pathogen)::Distribution
    return pathogen.infection_rate
end

"""
    mild_death_rate(pathogen::Pathogen)

Returns the death rate (distribution) of the pathogen in the case of mild symptoms.
"""
function mild_death_rate(pathogen::Pathogen)::Distribution
    return pathogen.mild_death_rate
end

"""
    severe_death_rate(pathogen::Pathogen)

Returns the death rate (distribution) of the pathogen in the case of severe symptoms.
"""
function severe_death_rate(pathogen::Pathogen)::Distribution
    return pathogen.severe_death_rate
end

"""
    critical_death_rate(pathogen::Pathogen)

Returns the death rate (distribution) of the pathogen in the case of critical progression.
"""
function critical_death_rate(pathogen::Pathogen)::Distribution
    return pathogen.critical_death_rate
end

"""
    hospitalization_rate(pathogen::Pathogen)

Returns the hospitalization rate (distribution) of the pathogen in the case
 of a severe disease progression.
"""
function hospitalization_rate(pathogen::Pathogen)::Distribution
    return pathogen.hospitalization_rate
end
 
"""
    ventilation_rate(pathogen::Pathogen)

Returns the ventilation rate (distribution) of the pathogen in the case
 of a critical disease progression.
"""
function ventilation_rate(pathogen::Pathogen)::Distribution
    return pathogen.ventilation_rate
end

"""
    icu_rate(pathogen::Pathogen)

Returns the icu rate (distribution) of the pathogen in the case
 of a critical disease progression.
"""
function icu_rate(pathogen::Pathogen)::Distribution
    return pathogen.icu_rate
end


### Time Distributions ###

"""
    onset_of_symptoms(pathogen::Pathogen)

Returns the time distribution for the onset of symptoms.
"""
function onset_of_symptoms(pathogen::Pathogen)::Distribution
    return pathogen.onset_of_symptoms
end

"""
    onset_of_severeness(pathogen::Pathogen)

Returns the time distribution for the onset of severe symptoms.
"""
function onset_of_severeness(pathogen::Pathogen)::Distribution
    return pathogen.onset_of_severeness
end

"""
    infectious_offset(pathogen::Pathogen)

Returns the time distribution for the offset of becoming infectious,
    before developing symptoms.
"""
function infectious_offset(pathogen::Pathogen)::Distribution
    return pathogen.infectious_offset
end

"""
    time_to_hospitalization(pathogen::Pathogen)

Returns the distribution for the time till hospitalization starting
    from the onset of symptoms.
"""
function time_to_hospitalization(pathogen::Pathogen)::Distribution
    return pathogen.time_to_hospitalization
end

"""
    time_to_icu(pathogen::Pathogen)

Returns the distribution for the time till ICU starting
    from the hospitalization time.
"""
function time_to_icu(pathogen::Pathogen)::Distribution
    return pathogen.time_to_icu
end

"""
    time_to_recovery(pathogen::Pathogen)
    
Returns the time to recovery (distribution) of the pathogen.
"""
function time_to_recovery(pathogen::Pathogen)
    return pathogen.time_to_recovery
end

"""
    length_of_stay(pathogen::Pathogen)
    
Returns the time distribution of the duration an individual will be hospitalized.
"""
function length_of_stay(pathogen::Pathogen)
    return pathogen.length_of_stay
end


### Disease Progression ###

"""
    disease_progression_strat(pathogen::Pathogen)

Returns the stratified probabilities for disease progression.
"""
function disease_progression_strat(pathogen::Pathogen)::DiseaseProgressionStrat
    return pathogen.dpr
end

### Transmission Function ###

"""
    transmission_function(pathogen::Pathogen)

Returns the transmission_function for the pathogen.
"""
function transmission_function(pathogen::Pathogen)::TransmissionFunction
    return pathogen.transmission_function
end

"""
    transmission_function!(pathogen::Pathogen, transFunc::TransmissionFunction)

Returns the transmission_function for the pathogen.
"""
function transmission_function!(pathogen::Pathogen, transFunc::TransmissionFunction)
    pathogen.transmission_function = transFunc
end

"""
    parameters(pathogen::Pathogen):::Dict

Obtains a dictionary containing the parameters of the Pathogen.
Distributions and the disease progression are formatted using their
parameters function.
"""
function parameters(pathogen::Pathogen)::Dict

    res = Dict(
        "id" => pathogen |> id,
        "name" => pathogen |> name,

        "infection_rate" => pathogen |> infection_rate |> parameters,

        "mild_death_rate" => pathogen |> mild_death_rate |> parameters,
        "severe_death_rate" => pathogen |> severe_death_rate |> parameters,
        "critical_death_rate" => pathogen |> critical_death_rate |> parameters,

        "hospitalization_rate" => pathogen |> hospitalization_rate |> parameters,
        "ventilation_rate" => pathogen |> ventilation_rate |> parameters,
        "icu_rate" => pathogen |> icu_rate |> parameters,

        "onset_of_symptoms" => pathogen |> onset_of_symptoms |> parameters,
        "onset_of_severeness" => pathogen |> onset_of_severeness |> parameters,
        "infectious_offset" => pathogen |> infectious_offset |> parameters,
        "time_to_hospitalization" => pathogen |> time_to_hospitalization |> parameters,
        "time_to_icu" => pathogen |> time_to_icu |> parameters,

        "time_to_recovery" => pathogen |> time_to_recovery |> parameters,
        "length_of_stay" => pathogen |> length_of_stay |> parameters,

        "disease_progression_strat" => pathogen |> disease_progression_strat |> parameters,

        "transmission_function" => pathogen |> transmission_function |> parameters
    )
    return res
end