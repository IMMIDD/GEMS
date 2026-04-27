export InfectionState
export push_infection!, remove_infection!

"""
    InfectionState

A flat Struct-of-Arrays (SoA) registry holding the disease progression and 
pathogen information for all currently active infections in the simulation.
"""
mutable struct InfectionState
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
    
    function InfectionState(population_size::Int)
        return new(
            zeros(Int32, population_size),
            Int32[], Int8[], Int32[], Int8[],
            Int16[], Int16[], Int16[], Int16[],
            Int16[], Int16[], Int16[], Int16[],
            Int16[], Int16[], Int16[], Int16[], Int16[]
        )
    end
end

"""
    push_infection!(state::InfectionState, host_id::Int32, pathogen_id::Int8, infection_id::Int32, dp::DiseaseProgression)

Pushes a new infection record into the `InfectionState` struct. 
"""
function push_infection!(state::InfectionState, host_id::Int32, pathogen_id::Int8, infection_id::Int32, dp::DiseaseProgression)
    # Check if already infected to prevent duplicate rows
    state.id_to_index[host_id] != 0 && return nothing

    push!(state.host_id, host_id)
    push!(state.pathogen_id, pathogen_id)
    push!(state.infection_id, infection_id)
    push!(state.infectiousness, Int8(0)) # Default infectiousness

    push!(state.exposure, exposure(dp))
    push!(state.infectiousness_onset, infectiousness_onset(dp))
    push!(state.symptom_onset, symptom_onset(dp))
    push!(state.severeness_onset, severeness_onset(dp))
    push!(state.hospital_admission, hospital_admission(dp))
    push!(state.icu_admission, icu_admission(dp))
    push!(state.icu_discharge, icu_discharge(dp))
    push!(state.ventilation_admission, ventilation_admission(dp))
    push!(state.ventilation_discharge, ventilation_discharge(dp))
    push!(state.hospital_discharge, hospital_discharge(dp))
    push!(state.severeness_offset, severeness_offset(dp))
    push!(state.recovery, recovery(dp))
    push!(state.death, death(dp))

    @inbounds state.id_to_index[host_id] = length(state.host_id)
    return nothing
end


"""
    remove_infection!(state::InfectionState, host_id::Int32)

Removes an infection from the SoA in O(1) time using the Swap and Pop technique,
ensuring no memory is shifted and arrays remain perfectly dense.
"""
function remove_infection!(state::InfectionState, host_id::Int32)
    @inbounds idx_to_remove = state.id_to_index[host_id]
    idx_to_remove == 0 && return nothing # Not infected
    
    last_idx = length(state.host_id)
    
    # if the one we want to remove is not the last one, we swap
    if idx_to_remove != last_idx
        @inbounds begin
            # identify who is currently at the end of the arrays
            last_host_id = state.host_id[last_idx]
            
            # overwrite the removed slot with the data from the last slot
            state.host_id[idx_to_remove] = state.host_id[last_idx]
            state.pathogen_id[idx_to_remove] = state.pathogen_id[last_idx]
            state.infection_id[idx_to_remove] = state.infection_id[last_idx]
            state.infectiousness[idx_to_remove] = state.infectiousness[last_idx]
            state.exposure[idx_to_remove] = state.exposure[last_idx]
            state.recovery[idx_to_remove] = state.recovery[last_idx]
            
            # update the map for the host we just moved
            state.id_to_index[last_host_id] = idx_to_remove
        end
    end
    
    # pop the ends
    pop!(state.host_id)
    pop!(state.pathogen_id)
    pop!(state.infection_id)
    pop!(state.infectiousness)
    pop!(state.exposure)
    pop!(state.recovery)
    
    # clear the map for the recovered host
    @inbounds state.id_to_index[host_id] = 0
    
    return nothing
end