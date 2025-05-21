#= 
THIS FIEL HANDLES THE PROGRESSION OF DISEASES
The first part will handle the sampling of probabilities as well as
of a disease progression "path" for a certain individual when it becomes infected.
The second part will then be composed of the functionality to progress through this
disease path.
=#
export sample_mild_death_rate, sample_severe_death_rate, sample_critical_death_rate
export sample_hospitalization_rate, sample_ventilation_rate, sample_icu_rate
export sample_onset_of_symptoms, sample_infectious_offset, sample_onset_of_severeness
export sample_time_to_hospitalization, sample_time_to_icu
export sample_time_to_recovery, sample_length_of_stay
export estimate_disease_progression, disease_progression!
export sample_self_quarantine_rate

###
### SAMPLING PROBABILITIES
###

"""
    sample_mild_death_rate(pathogen::Pathogen, indiv::Individual)

Returns a randomly drawn value from the death rate distribution for cases 
with mild symptoms.
"""
function sample_mild_death_rate(pathogen::Pathogen, indiv::Individual)::Float32
    return rand(pathogen.mild_death_rate)
end

"""
    sample_severe_death_rate(pathogen::Pathogen, indiv::Individual)

Returns a randomly drawn value from the death rate distribution for severe 
disease progressions.
"""
function sample_severe_death_rate(pathogen::Pathogen, indiv::Individual)::Float32
    return rand(pathogen.severe_death_rate)
end

"""
    sample_critical_death_rate(pathogen::Pathogen, indiv::Individual)

Returns a randomly drawn value from the death rate distribution for critical 
disease progressions.
"""
function sample_critical_death_rate(pathogen::Pathogen, indiv::Individual)::Float32
    return rand(pathogen.critical_death_rate)
end

"""
    sample_hospitalization_rate(pathogen::Pathogen, indiv::Individual)

Returns a randomly drawn value from the hospitalization rate distribution.
"""
function sample_hospitalization_rate(pathogen::Pathogen, indiv::Individual)::Float32
    return rand(pathogen.hospitalization_rate)
end

"""
    sample_ventilation_rate(pathogen::Pathogen, indiv::Individual)

Returns a randomly drawn value from the Ventilation rate distribution.
"""
function sample_ventilation_rate(pathogen::Pathogen, indiv::Individual)::Float32
    return rand(pathogen.ventilation_rate)
end

"""
    sample_icu_rate(pathogen::Pathogen, indiv::Individual)

Returns a randomly drawn value from the ICU rate distribution.
"""
function sample_icu_rate(pathogen::Pathogen, indiv::Individual)::Float32
    return rand(pathogen.icu_rate)
end

"""
    sample_self_quarantine_rate(pathogen::Pathogen, indiv::Individual)

Returns a randomly drawn value from the ICU rate distribution.
"""
function sample_self_quarantine_rate(pathogen::Pathogen, indiv::Individual)::Float32
    return rand(pathogen.self_quarantine_rate)
end

###
### SAMPLING & CALCULATION OF TICKS
###
"""
    sample_time_to_recovery(pathogen::Pathogen,  indiv::Individual)
    
Returns a randomly drawn (rounded) value from the `time_to_recovery` distribution.
"""
function sample_time_to_recovery(pathogen::Pathogen,  indiv::Individual)::Int16
    return round(rand(pathogen.time_to_recovery))
end

"""
    sample_onset_of_symptoms(pathogen::Pathogen,  indiv::Individual)

Returns a randomly drawn (rounded) value from the `onset_of_symptoms` distribution.
"""
function sample_onset_of_symptoms(pathogen::Pathogen,  indiv::Individual)::Int16
    return round(rand(pathogen.onset_of_symptoms))
end

"""
    sample_infectious_offset(pathogen::Pathogen,  indiv::Individual)

Returns a randomly drawn (rounded) value from the infectious offset distribution.
"""
function sample_infectious_offset(pathogen::Pathogen,  indiv::Individual)::Int16
    return round(rand(pathogen.infectious_offset))
end

"""
    sample_onset_of_severeness(pathogen::Pathogen,  indiv::Individual)

Returns a randomly drawn (rounded) value from the `onset_of_symptoms` distribution.
"""
function sample_onset_of_severeness(pathogen::Pathogen,  indiv::Individual)::Int16
    return round(rand(pathogen.onset_of_severeness))
end

"""
    sample_time_to_hospitalization(pathogen::Pathogen,  indiv::Individual)

Returns a randomly drawn (rounded) value from the `time_to_hospitalization` distribution
for cases with severe disease progression.
"""
function sample_time_to_hospitalization(pathogen::Pathogen,  indiv::Individual)::Int16
    return round(rand(pathogen.time_to_hospitalization))
end

"""
    sample_length_of_stay(pathogen::Pathogen,  indiv::Individual)

Returns a randomly drawn (rounded) value from the `time_to_hopsitalization` distribution
for cases with severe disease progression.
"""
function sample_length_of_stay(pathogen::Pathogen,  indiv::Individual)::Int16
    return round(rand(pathogen.length_of_stay))
end

"""
    sample_time_to_icu(pathogen::Pathogen,  indiv::Individual)

Returns a randomly drawn (rounded) value from the `time_to_icu` distribution for cases
with critical disease progression.
"""
function sample_time_to_icu(pathogen::Pathogen,  indiv::Individual)::Int16
    return round(rand(pathogen.time_to_icu))
end

###
### DISEASE PROGRESSION
###

"""
    estimate_disease_progression(dpr::DiseaseProgressionStrat, indiv::Individual)

Estimates the final status an individual reaches during the progression of a disease.
"""
function estimate_disease_progression(dpr::DiseaseProgressionStrat, indiv::Individual)::DataType
    ag = agegroup(dpr.age_groups, indiv)
    probabilities = dpr.stratification_matrix[ag]
    ranges = cumsum(probabilities)

    r = rand()

    current = 1
    for (i, value) in enumerate(ranges)
        if r<value
            current = i
            break
        end
    end

    return dpr.disease_compartments[current]
end

"""
    agegroup(agegroups::Vector{String}, indiv::Individual)

Given that the `agegroup` argument contains a vector of agegroup identifiers, 
such as `["10-20", "21-30"]`, this function will evaluate in which group the 
age of the provided individual (`indiv`) belongs and returns the index of the respective
agrgroup in the argument vector.
"""
function agegroup(agegroups::Vector{String}, indiv::Individual)
    # function to evaluate the index of the individual in the agegroup vector
    for (i, elem) in enumerate(agegroups)
        if occursin("-", elem)
            # case of keys like "10-20"
            a, b = split(elem, "-")
            if parse(Int, a) <= indiv.age < parse(Int, b)
                return i
            end
        elseif occursin("+", elem)
            # case of keys like "80+"
            a, b = split(elem, "+")
            if parse(Int, a)<= indiv.age
                return i
            end
        end
    end
    
    return -1 # no index for the age group of the individual was found
end


"""
    disease_progression!(infectee::Individual, pathogen::Pathogen, exposedtick::Int16)

Assigns a disease progression to the `infectee` by assigning event ticks based on the 
`exposedtick`.
"""
function disease_progression!(infectee::Individual, pathogen::Pathogen, exposedtick::Int16)
    estimated_symptom_category = 
        estimate_disease_progression(
            disease_progression_strat(pathogen), 
            infectee
        )
    # dispatch on the type of symptom category to the correct function
    disease_progression!(infectee, pathogen, exposedtick, estimated_symptom_category)
end


function disease_progression!(
    infectee::Individual,
    pathogen::Pathogen,
    exposedtick::Int16, 
    ::Type{Asymptomatic}
)
    # calc infectious_tick from onset_of_symptoms like in Mild case, but ignore onset_of_symptoms
    theoretical_onset_of_symptoms = sample_onset_of_symptoms(pathogen, infectee)
    infectious_tick!(
        infectee,
        # prevent setting infectiouness to BEFORE infection
        max(exposedtick + Int16(1), exposedtick + 
            theoretical_onset_of_symptoms -
            sample_infectious_offset(pathogen, infectee))
    )

    # Calculate Asymptomatic Recovery tick.
    removed_tick!(
        infectee,
        exposedtick + 
            theoretical_onset_of_symptoms +
            sample_time_to_recovery(pathogen, infectee)
    )

    #TODO: JP: the onset_of_symptoms parameter is not set/reset
    # If the agent was symptomatic in a previous infection
    # this will still be the value stored in the agent. We
    # need to fix this. also in other progression types

    # final status is 1
    symptom_category!(infectee, SYMPTOM_CATEGORY_ASYMPTOMATIC)
end

function disease_progression!(
    infectee::Individual,
    pathogen::Pathogen,
    exposedtick::Int16,
    ::Type{Mild}
)
    # TODOS
    # calc onset of symptoms
    onset_of_symptoms!(
        infectee,
        max(exposedtick + Int16(1), exposedtick + sample_onset_of_symptoms(pathogen, infectee))
    )
    # decrement by random tick value drawn for the time to infectiousness
    infectious_tick!(
        infectee,
        # prevent setting infectiouness to BEFORE infection
        max(exposedtick + Int16(1), onset_of_symptoms(infectee) - sample_infectious_offset(pathogen, infectee))
    )
    # removed tick as normal
    removed_tick!(
        infectee,
        onset_of_symptoms(infectee) + sample_time_to_recovery(pathogen, infectee)
    )

    # estimate death probability
    death_probability = sample_mild_death_rate(pathogen, infectee)

    # calculate mild death or recovery rate. Sample length of symptoms for this.
    if rand() < death_probability
        death_tick!(infectee, removed_tick(infectee))
    end

    #=
    # estimate self quarantine probability
    if rand() < sample_self_quarantine_rate(pathogen, infectee)
        quarantine_tick!(infectee, onset_of_symptoms(infectee))
        quarantine_release_tick!(infectee, removed_tick(infectee))
    end
    =#

    # final status is 2
    symptom_category!(infectee, SYMPTOM_CATEGORY_MILD)
end

function disease_progression!(
    infectee::Individual,
    pathogen::Pathogen,
    exposedtick::Int16,
    ::Type{Severe}
)

    # calc onset of symptoms
    onset_of_symptoms!(
        infectee,
        max(exposedtick + Int16(1), exposedtick + sample_onset_of_symptoms(pathogen, infectee))
    )

    # decrement by random tick value drawn for the time to infectiousness
    infectious_tick!(
        infectee,
        # prevent setting infectiouness to BEFORE infection
        max(exposedtick + Int16(1), onset_of_symptoms(infectee) - sample_infectious_offset(pathogen, infectee))
    )

    # calculate onset of severe symptoms as increment on onset of symptoms
    onset_of_severeness!(
        infectee,
        onset_of_symptoms(infectee) + sample_onset_of_severeness(pathogen, infectee)
    )

    # random value to determine if hospitalized or not -> distribution from probability from the pathogen
        # calculate hospitalization tick if needed. If lower than onset_of_severeness, take minimum.
    hospitalization_probability = sample_hospitalization_rate(pathogen, infectee)
    
    death_probability = sample_severe_death_rate(pathogen, infectee)

    # estimate death probability
    willdie = rand() < death_probability

    if rand() < hospitalization_probability

        hospitalized_tick!(
            infectee,
            onset_of_symptoms(infectee) +
                sample_time_to_hospitalization(pathogen, infectee)
        )
        
        # fix if hospitalization would be before onset of onset_of_severeness
        hospitalized_tick!(
            infectee,
            max(hospitalized_tick(infectee), onset_of_severeness(infectee))
        )

        # calculate severe death or recovery rate. If hospitalized, as "end of hospital". Sample length of symptoms for this.
        removed_tick!(
            infectee,
            hospitalized_tick(infectee) + sample_length_of_stay(pathogen, infectee)
        )

        #=
        # hospital is a form of quarantine
        quarantine_tick!(infectee, hospitalized_tick(infectee))
        quarantine_release_tick!(infectee, removed_tick(infectee))
        =#

        if willdie
            death_tick!(infectee, removed_tick(infectee))
        end
    else
        # calculate severe death or recovery rate. If hospitalized, as "end of hospital". Sample length of symptoms for this.
        removed_tick!(
            infectee,
            onset_of_symptoms(infectee) + sample_time_to_recovery(pathogen, infectee)
        )

        #=
        # estimate self quarantine probability
        if rand() < sample_self_quarantine_rate(pathogen, infectee)
            quarantine_tick!(infectee, onset_of_symptoms(infectee))
            quarantine_release_tick!(infectee, removed_tick(infectee))
        end
        =#

        if willdie
            death_tick!(infectee, removed_tick(infectee))
        end
    end

    # final status is 3
    symptom_category!(infectee, SYMPTOM_CATEGORY_SEVERE)
end

function disease_progression!(
    infectee::Individual,
    pathogen::Pathogen,
    exposedtick::Int16,
    ::Type{Critical}
)
    # calc onset of symptoms
    onset_of_symptoms!(
        infectee,
        max(exposedtick + Int16(1), exposedtick + sample_onset_of_symptoms(pathogen, infectee))
    )

    # decrement by random tick value drawn for the time to infectiousness
    infectious_tick!(
        infectee,
        # prevent setting infectiouness to BEFORE infection
        max(exposedtick + Int16(1), onset_of_symptoms(infectee) - sample_infectious_offset(pathogen, infectee))
    )

    # calculate onset of severe symptoms as increment on onset of symptoms
    onset_of_severeness!(
        infectee,
        onset_of_symptoms(infectee) + sample_onset_of_severeness(pathogen, infectee)
    )

    # calculate hospitalization tick. If lower than onset_of_severeness, take minimum.
    hospitalized_tick!(
        infectee,
        onset_of_symptoms(infectee) +
            sample_time_to_hospitalization(pathogen, infectee)
    )

    # fix if hospitalization would be before onset of onset_of_severeness
    hospitalized_tick!(
        infectee,
        max(hospitalized_tick(infectee), onset_of_severeness(infectee))
    )

    # calculate death or recovery as "end of hospital"
    removed_tick!(
        infectee,
        hospitalized_tick(infectee) + sample_length_of_stay(pathogen, infectee)
    )

    # random value to determine ventilation. If yes, directly when hospitalized.
    ventilation_probability = sample_ventilation_rate(pathogen, infectee)
    if rand() < ventilation_probability
        ventilation_tick!(infectee, hospitalized_tick(infectee))

        # ICU only if ventilated and determined randomly. Then ICU tick as increment on hospitalization tick
        icu_probability = sample_icu_rate(pathogen, infectee)
        if rand()<icu_probability
            icu_tick!(
                infectee,
                hospitalized_tick(infectee) + sample_time_to_icu(pathogen, infectee)
            )
        end
    end

    #=
    # hospital is a form of quarantine
    quarantine_tick!(infectee, hospitalized_tick(infectee))
    quarantine_release_tick!(infectee, removed_tick(infectee))
    =#

    # estimate death probability
    death_probability = sample_critical_death_rate(pathogen, infectee)

    # calculate mild death or recovery rate. Sample length of symptoms for this.
    if rand() < death_probability
        death_tick!(infectee, removed_tick(infectee))
    end

    # final status is 5
    symptom_category!(infectee, SYMPTOM_CATEGORY_CRITICAL)
end


### UPDATE DISEASE PROGRESSION ###
"""
    progress_disease!(indiv::Individual, tick::Int16, lookup_dict::Dict = SYMPTOM_CATEGORY_DICT)

Progresses the disease of the (infected) individual. The dictionary `lookup_dict` can be
provided, if custom disease compartements were implemented. The key-value-pairs should 
align with the meaning of the parameter `disease_state` or `symptom_category`. This means,
that if `disease_state==1` means "Asymptomatic", that `status[1]=="Asymptomatic"`.

This function doesn't kill agents as this is handled a level higher 
for the simulation to log deaths.
"""
function progress_disease!(
        indiv::Individual,
        tick::Int16, 
        lookup_dict::Dict = SYMPTOM_CATEGORY_DICT
    )
    if infected(indiv)
        progress_disease!(indiv, tick, lookup_dict[symptom_category(indiv)])

        # update from anywhere to end of disease progression
        if exposed_tick(indiv) <= removed_tick(indiv) <= tick
            recover!(indiv)
        end
    end
end

# Comment on the progress functions:
# We use that every symptom category has a guaranteed progression.
# For example Symptomatic guarantees Presymptomatic -> Symptomatic and Exposed -> Infectious.
# This means, that the ticks must have to be valid, if the scheduling was valid
# before (for example no ticks with -1)

function progress_disease!(indiv::Individual, tick::Int16, ::Type{Asymptomatic})
    # progress to infectious stage with possible no symptoms
    if exposed(indiv)
        if !infectious(indiv) && infectious_tick(indiv) <= tick <= removed_tick(indiv)
            infectiousness!(indiv, 127) # for now set it to maximum infectiousness
        end
    end
end

function progress_disease!(indiv::Individual, tick::Int16, ::Type{Mild})
    # progress to infectious stage with possible no symptoms
    if exposed(indiv)
        if !infectious(indiv) && infectious_tick(indiv) <= tick <= removed_tick(indiv)
            infectiousness!(indiv, 127) # for now set it to maximum infectiousness
        end
    end
    # progress to symptomatic stage
    if presymptomatic(indiv)
        if onset_of_symptoms(indiv) <= tick <= removed_tick(indiv)
            symptomatic!(indiv)
        end
    end
    # if necessary quarantine the individual
    if !isquarantined(indiv)
        if quarantine_tick(indiv) <= tick <= quarantine_release_tick(indiv)
            home_quarantine!(indiv)
        end
    end
end

function progress_disease!(indiv::Individual, tick::Int16, ::Type{Severe})
    # progress to infectious stage with possible no symptoms
    if exposed(indiv)
        if !infectious(indiv) && infectious_tick(indiv) <= tick <= removed_tick(indiv)
            infectiousness!(indiv, 127) # for now set it to maximum infectiousness
        end
    end
    # progress to symptomatic stage
    if presymptomatic(indiv)
        if onset_of_symptoms(indiv) <= tick <= removed_tick(indiv)
            symptomatic!(indiv)
        end
    end
    # progress to severeness
    if symptomatic(indiv)
        if onset_of_severeness(indiv) <= tick <= removed_tick(indiv)
            severe!(indiv)
        end
    end
    # hospitalize if necessary
    if !hospitalized(indiv) && onset_of_severeness(indiv) <= hospitalized_tick(indiv) <= tick <= removed_tick(indiv)
        hospitalize!(indiv)
    end

    # if necessary quarantine the individual. If it was already hopsitalized, this will be skipped
    if !isquarantined(indiv)
        if quarantine_tick(indiv) <= tick <= quarantine_release_tick(indiv)
            home_quarantine!(indiv)
        end
    end
end

function progress_disease!(indiv::Individual, tick::Int16, ::Type{Critical})
    # progress to infectious stage with possible no symptoms
    if exposed(indiv)
        if !infectious(indiv) && infectious_tick(indiv) <= tick <= removed_tick(indiv)
            infectiousness!(indiv, 127) # for now set it to maximum infectiousness
        end
    end
    # progress to symptomatic stage
    if presymptomatic(indiv)
        if onset_of_symptoms(indiv) <= tick <= removed_tick(indiv)
            symptomatic!(indiv)
        end
    end
    # progress to severeness
    if symptomatic(indiv)
        if onset_of_severeness(indiv) <= tick <= removed_tick(indiv)
            severe!(indiv)
        end
    end
    # progress to hospitalization
    if !hospitalized(indiv) 
        if hospitalized_tick(indiv) <= tick <= removed_tick(indiv)
            hospitalize!(indiv)
        end
    end
    # ventilate if necessary
    if hospitalized(indiv) 
        if hospitalized_tick(indiv) <= ventilation_tick(indiv) <= tick <= removed_tick(indiv)
            ventilate!(indiv)
        end
    end
    # icu if necessary
    if ventilated(indiv)
        if ventilation_tick(indiv) <= icu_tick(indiv) <= tick <= removed_tick(indiv)
            icu!(indiv)
        end
    end

    # if necessary quarantine the individual. If it was already hopsitalized, this will be skipped
    if !isquarantined(indiv)
        if quarantine_tick(indiv) <= tick <= quarantine_release_tick(indiv)
            home_quarantine!(indiv)
        end
    end
end