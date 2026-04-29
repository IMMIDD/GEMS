export ActiveInfections, InfectionState, PendingInfection
export get_infection_state, push_infection!, remove_infection!

"""
    ActiveInfections

A flat Struct-of-Arrays (SoA) registry holding the disease progression and 
pathogen information for all currently active infections in the simulation.
"""
mutable struct ActiveInfections
    # Index Map (0 means not infected)
    id_to_index::Vector{Int32}

    # Points to the next infection index in the SoA for the same host
    next_infection_index::Vector{Int32}

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
    
    function ActiveInfections(n::Int32)
        return new(
            zeros(Int32, n),
            Int32[], Int32[], Int8[], Int32[], Int8[],
            Int16[], Int16[], Int16[], Int16[], Int16[], 
            Int16[], Int16[], Int16[], Int16[], Int16[], 
            Int16[], Int16[], Int16[]
        )
    end
end

"""
    InfectionState

An immutable, stack-allocated representation of a single individual's disease state.
Used to cleanly pass all relevant disease progression data into pure mathematical models 
without exposing the underlying `ActiveInfections` memory pool.
"""
struct InfectionState
    active::Bool          # False if the agent is not currently infected
    host_id::Int32
    pathogen_id::Int8
    infection_id::Int32
    infectiousness::Int8
    exposure::Int16
    infectiousness_onset::Int16
    symptom_onset::Int16
    severeness_onset::Int16
    hospital_admission::Int16
    icu_admission::Int16
    icu_discharge::Int16
    ventilation_admission::Int16
    ventilation_discharge::Int16
    hospital_discharge::Int16
    severeness_offset::Int16
    recovery::Int16
    death::Int16
end

"""
    PendingInfection

A lightweight transfer struct used to temporarily hold new infection data 
during the multithreaded contact simulation phase. 

By storing newly generated infections in thread-local vectors of `PendingInfection`, 
the simulation avoids race conditions and expensive thread locks. These pending 
infections are later flushed into the global `ActiveInfections` SoA using 
high-performance block memory allocation.
"""
struct PendingInfection
    host_id::Int32
    pathogen_id::Int8
    infection_id::Int32
    dp::DiseaseProgression
end




"""
    get_infection_state(infections::ActiveInfections, idx::Int, host_id::Int32)

Extracts a stack-allocated `InfectionState` from the global `ActiveInfections` pool by index idx.
If `idx == 0` , it returns a default uninfected `InfectionState. 
"""
function get_infection_state(infections::ActiveInfections, idx::Int32, host_id::Int32)::InfectionState
    if idx == 0
        # Return a blank state if there is no infection
        return InfectionState(
            false, host_id, Int8(0), Int32(0), Int8(0), 
            Int16(-1), Int16(-1), Int16(-1), Int16(-1), 
            Int16(-1), Int16(-1), Int16(-1), Int16(-1), 
            Int16(-1), Int16(-1), Int16(-1), Int16(-1), Int16(-1)
        )
    end
    
    @inbounds return InfectionState(
        true,
        infections.host_id[idx],
        infections.pathogen_id[idx],
        infections.infection_id[idx],
        infections.infectiousness[idx],
        infections.exposure[idx],
        infections.infectiousness_onset[idx],
        infections.symptom_onset[idx],
        infections.severeness_onset[idx],
        infections.hospital_admission[idx],
        infections.icu_admission[idx],
        infections.icu_discharge[idx],
        infections.ventilation_admission[idx],
        infections.ventilation_discharge[idx],
        infections.hospital_discharge[idx],
        infections.severeness_offset[idx],
        infections.recovery[idx],
        infections.death[idx]
    )
end

"""
    get_infection_state(host_id::Int32, infections::ActiveInfections, pathogen_id::Int8)

Retrieves the `InfectionState` for a specific host and pathogen by traversing 
the active infections linked list. Returns a default uninfected state if the 
host is not currently infected with the specified pathogen.
"""
function get_infection_state(host_id::Int32, infections::ActiveInfections, pathogen_id::Int8)::InfectionState
    @inbounds idx = infections.id_to_index[host_id]
    
    # Traverse the linked list to find the specific pathogen
    while idx != 0
        @inbounds if infections.pathogen_id[idx] == pathogen_id
            return get_infection_state(infections, idx, host_id)
        end
        @inbounds idx = infections.next_infection_index[idx]
    end
    
    # Pathogen not found, return the blank state using the internal helper
    return get_infection_state(infections, Int32(0), host_id)
end

"""
    push_infection!(infections::ActiveInfections, host_id::Int32, pathogen_id::Int8, infection_id::Int32, dp::DiseaseProgression)

Pushes a new infection record into the `ActiveInfections` struct. 
"""
function push_infection!(infections::ActiveInfections, host_id::Int32, pathogen_id::Int8, infection_id::Int32, dp::DiseaseProgression)
    # Traverse linked list to prevent duplicate infections of the same pathogen
    curr_idx = infections.id_to_index[host_id]
    while curr_idx != 0
        if infections.pathogen_id[curr_idx] == pathogen_id
            return nothing # Already infected with this pathogen
        end
        curr_idx = infections.next_infection_index[curr_idx]
    end

    new_idx = length(infections.host_id) + 1

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

    push!(infections.next_infection_index, infections.id_to_index[host_id]) 
    @inbounds infections.id_to_index[host_id] = new_idx
    return nothing
end

"""
    remove_infection!(infections::ActiveInfections, host_id::Int32, pathogen_id::Int8)

Removes an infection from the SoA by swapping it to the end and then popping it.
"""
function remove_infection!(infections::ActiveInfections, host_id::Int32, pathogen_id::Int8)
    prev_idx = 0
    idx_to_remove = infections.id_to_index[host_id]
    
    # find the infection to remove
    while idx_to_remove != 0 && infections.pathogen_id[idx_to_remove] != pathogen_id
        prev_idx = idx_to_remove
        idx_to_remove = infections.next_infection_index[idx_to_remove]
    end
    idx_to_remove == 0 && return nothing # Not found

    # unlink idx_to_remove from its host's list
    next_idx = infections.next_infection_index[idx_to_remove]
    if prev_idx == 0
        infections.id_to_index[host_id] = next_idx
    else
        infections.next_infection_index[prev_idx] = next_idx
    end

    last_idx = length(infections.host_id)
    
    # if the one we want to remove is not the last one, we swap
    if idx_to_remove != last_idx
        @inbounds begin
            # identify who is currently at the end of the arrays
            last_host_id = infections.host_id[last_idx]

            # find who points to last_idx to update their pointer
            prev_of_last = 0
            curr = infections.id_to_index[last_host_id]
            while curr != last_idx && curr != 0
                prev_of_last = curr
                curr = infections.next_infection_index[curr]
            end
            
            # patch the pointer
            if prev_of_last == 0
                infections.id_to_index[last_host_id] = idx_to_remove
            else
                infections.next_infection_index[prev_of_last] = idx_to_remove
            end
            
            # overwrite the removed slot with the data from the last slot
            infections.host_id[idx_to_remove] = infections.host_id[last_idx]
            infections.pathogen_id[idx_to_remove] = infections.pathogen_id[last_idx]
            infections.infection_id[idx_to_remove] = infections.infection_id[last_idx]
            infections.next_infection_index[idx_to_remove] = infections.next_infection_index[last_idx] # <-- FIXED
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
        end
    end
    
    # pop the ends
    pop!(infections.host_id)
    pop!(infections.pathogen_id)
    pop!(infections.infection_id)
    pop!(infections.next_infection_index) # <-- FIXED
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
    
    
    return nothing
end

"""
Removes all active infections for a given host.
"""
function remove_infection!(infections::ActiveInfections, host_id::Int32)
    # Continue as long as the host has at least one active infection
    while infections.id_to_index[host_id] != 0
        curr_head_idx = infections.id_to_index[host_id]
        pid_to_remove = infections.pathogen_id[curr_head_idx]
        
        remove_infection!(infections, host_id, pid_to_remove)
    end
    
    return nothing
end