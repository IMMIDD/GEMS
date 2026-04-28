export ActiveInfections, PendingInfection
export push_infection!, remove_infection!

"""
    ActiveInfections

A flat Struct-of-Arrays (SoA) registry holding the disease progression and 
pathogen information for all currently active infections in the simulation.
"""
mutable struct ActiveInfections
    # Index Map (0 means not infected)
    id_to_index::Vector{Int32}

    # Entity reference
    host_id::Vector{Int32}
    
    # Pathogen metadata
    pathogen_id::Vector{Int8}
    infection_id::Vector{Int32}
    infectiousness::Vector{Int8}

    # Natural Disease History
    exposure::Vector{Int16}
    infectiousness_onset::Vector{Int16}
    symptom_onset::Vector{Int16}
    severeness_onset::Vector{Int16}
    hospital_admission::Vector{Int16}
    icu_admission::Vector{Int16}
    icu_discharge::Vector{Int16}
    ventilation_admission::Vector{Int16}
    ventilation_discharge::Vector{Int16}
    hospital_discharge::Vector{Int16}
    severeness_offset::Vector{Int16}
    recovery::Vector{Int16}
    death::Vector{Int16}
    
    function ActiveInfections(population_size::Int32)
        return new(
            zeros(Int32, population_size),
            Int32[], Int8[], Int32[], Int8[],
            Int16[], Int16[], Int16[], Int16[],
            Int16[], Int16[], Int16[], Int16[],
            Int16[], Int16[], Int16[], Int16[], Int16[]
        )
    end
end

struct PendingInfection
    host_id::Int32
    pathogen_id::Int8
    infection_id::Int32
    dp::DiseaseProgression
end

"""
    push_infection!(infections::ActiveInfections, host_id::Int32, pathogen_id::Int8, infection_id::Int32, dp::DiseaseProgression)

Pushes a new infection record into the `ActiveInfections` struct. 
"""
function push_infection!(infections::ActiveInfections, host_id::Int32, pathogen_id::Int8, infection_id::Int32, dp::DiseaseProgression)
    # Check if already infected to prevent duplicate rows
    infections.id_to_index[host_id] != 0 && return nothing

    push!(infections.host_id, host_id)
    push!(infections.pathogen_id, pathogen_id)
    push!(infections.infection_id, infection_id)
    push!(infections.infectiousness, Int8(0)) # Default infectiousness

    push!(infections.exposure, exposure(dp))
    push!(infections.infectiousness_onset, infectiousness_onset(dp))
    push!(infections.symptom_onset, symptom_onset(dp))
    push!(infections.severeness_onset, severeness_onset(dp))
    push!(infections.hospital_admission, hospital_admission(dp))
    push!(infections.icu_admission, icu_admission(dp))
    push!(infections.icu_discharge, icu_discharge(dp))
    push!(infections.ventilation_admission, ventilation_admission(dp))
    push!(infections.ventilation_discharge, ventilation_discharge(dp))
    push!(infections.hospital_discharge, hospital_discharge(dp))
    push!(infections.severeness_offset, severeness_offset(dp))
    push!(infections.recovery, recovery(dp))
    push!(infections.death, death(dp))

    @inbounds infections.id_to_index[host_id] = length(infections.host_id)
    return nothing
end


"""
    remove_infection!(infections::ActiveInfections, host_id::Int32)

Removes an infection from the SoA by swapping it to the end and then popping it.
"""
function remove_infection!(infections::ActiveInfections, host_id::Int32)
    @inbounds idx_to_remove = infections.id_to_index[host_id]
    idx_to_remove == 0 && return nothing # Not infected
    
    last_idx = length(infections.host_id)
    
    # if the one we want to remove is not the last one, we swap
    if idx_to_remove != last_idx
        @inbounds begin
            # identify who is currently at the end of the arrays
            last_host_id = infections.host_id[last_idx]
            
            # overwrite the removed slot with the data from the last slot
            infections.host_id[idx_to_remove] = infections.host_id[last_idx]
            infections.pathogen_id[idx_to_remove] = infections.pathogen_id[last_idx]
            infections.infection_id[idx_to_remove] = infections.infection_id[last_idx]
            infections.infectiousness[idx_to_remove] = infections.infectiousness[last_idx]
            infections.exposure[idx_to_remove] = infections.exposure[last_idx]
            infections.infectiousness_onset[idx_to_remove] = infections.infectiousness_onset[last_idx]
            infections.symptom_onset[idx_to_remove] = infections.symptom_onset[last_idx]
            infections.severeness_onset[idx_to_remove] = infections.severeness_onset[last_idx]
            infections.hospital_admission[idx_to_remove] = infections.hospital_admission[last_idx]
            infections.icu_admission[idx_to_remove] = infections.icu_admission[last_idx]
            infections.icu_discharge[idx_to_remove] = infections.icu_discharge[last_idx]
            infections.ventilation_admission[idx_to_remove] = infections.ventilation_admission[last_idx]
            infections.ventilation_discharge[idx_to_remove] = infections.ventilation_discharge[last_idx]
            infections.hospital_discharge[idx_to_remove] = infections.hospital_discharge[last_idx]
            infections.severeness_offset[idx_to_remove] = infections.severeness_offset[last_idx]
            infections.recovery[idx_to_remove] = infections.recovery[last_idx]
            infections.death[idx_to_remove] = infections.death[last_idx]
            
            # update the map for the host we just moved
            infections.id_to_index[last_host_id] = idx_to_remove
        end
    end
    
    # pop the ends
    pop!(infections.host_id)
    pop!(infections.pathogen_id)
    pop!(infections.infection_id)
    pop!(infections.infectiousness)
    pop!(infections.exposure)
    pop!(infections.infectiousness_onset)
    pop!(infections.symptom_onset)
    pop!(infections.severeness_onset)
    pop!(infections.hospital_admission)
    pop!(infections.icu_admission)
    pop!(infections.icu_discharge)
    pop!(infections.ventilation_admission)
    pop!(infections.ventilation_discharge)
    pop!(infections.hospital_discharge)
    pop!(infections.severeness_offset)
    pop!(infections.recovery)
    pop!(infections.death)
    
    # clear the map for the recovered host
    @inbounds infections.id_to_index[host_id] = 0
    
    return nothing
end