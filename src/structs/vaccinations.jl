# THIS FILE CONTAINS THE TYPE DEFINITION OF VACCINATION STRATEGIES AND SCHEDULERS
# AS WELL AS THEIR BASIC INTERFACE
export AbstractScheduler, VaccinationStrategy
export VaccinationScheduler, DailyDoseStrategy

export ticks, scheduled, schedule!, vaccinate!, dailydose, available_from

"Supertype for all Scheduler Structs"
abstract type AbstractScheduler end


###
### VACCINE-SCHEDULER
###
"""
    VaccinationScheduler <: AbstractScheduler

A Scheduler for the vaccinations. 

# Fields
- `schedule::Dict{Int16, Vector{Tuple{Individual, Vaccine}}}`: Individuals that have 
        to be vaccinated sorted by tick. Keys are ticks, values are the marked individuals
        with associated vaccines.
"""
@with_kw mutable struct VaccinationScheduler <: AbstractScheduler
    schedule::Dict{Int16, Vector{Tuple{Individual, Vaccine}}} = 
        Dict{Int16, Vector{Tuple{Individual, Vaccine}}}()
end

### INTERFACE
"""
    ticks(scheduler)

Returns all the ticks, when individuals are scheduled for vaccination.
"""
function ticks(scheduler::VaccinationScheduler)::Vector{Int16}
    return sort(collect(keys(scheduler.schedule)))
end

"""
    scheduled(scheduler, tick)

Returns the for time `tick` scheduled individuals with associated vaccine.
"""
function scheduled(scheduler::VaccinationScheduler, tick::Int16)::Vector{Tuple{Individual, Vaccine}}
    return scheduler.schedule[tick]
end

"""
    schedule!(scheduler, individual, vaccine, tick)

Schedules the `individual` for vaccination at time `tick` with the `vaccine`.
"""
function schedule!(
        scheduler::VaccinationScheduler,
        individual::Individual,
        vaccine::Vaccine,
        tick::Int16
    )
    if tick in keys(scheduler.schedule)
        push!(scheduler.schedule[tick], (individual, vaccine))
    else
        scheduler.schedule[tick] = [(individual, vaccine)]
    end
end

"""
    vaccinate!(scheduler, tick)

Vaccinates all individuals that are scheduled to be vaccinated at time tick.
"""
function vaccinate!(scheduler::VaccinationScheduler, tick::Int16)
    if tick in keys(scheduler.schedule)
        for (indiv, vacc) in scheduler.schedule[tick]
            if !infected(indiv)
            # how to handle already infected and how to reschedule?
                vaccinate!(indiv, vacc, tick)
            end
        end
    end
    # remove saved ticks?
end

###
### VACCINE-STRATEGY
###

"Supertype for all vaccination strategies"
abstract type VaccinationStrategy end

###
### DailyDoseStrategy
###
"""
    DailyDoseStrategy <: VaccinationStrategy

A Strategy to distribute a certain amount of doses per day until noone can be vaccinated.

# Fields
- `dailydose::Int32`: Daily number of vaccine doses to be distributed
"""
@with_kw mutable struct DailyDoseStrategy <: VaccinationStrategy
    available_from::Int16
    dailydose::Int32
end 

"""
    dailydose(dds)

Returns the daily dose that has to be scheduled according to the DailyDoseStrategy `dds`.
"""
function dailydose(dds::DailyDoseStrategy)
    return dds.dailydose
end

"""
    available_from(dds)

Returns the tick, when the vaccine should be available.
"""
function available_from(dds::DailyDoseStrategy)
    return dds.available_from
end