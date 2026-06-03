export PatientZero
export pathogen
export initialize!

"""
    PatientZero <: StartCondition

A `StartCondition` that infects a single individual at random at the beginning of the simulation.

# Fields
- `pathogen::String`: The pathogen with which the individual has to be infected

Example
```julia
condition = PatientZero() # single individual infected at random
sim = Simulation(start_condition = condition)
```
"""
struct PatientZero <: StartCondition
    pathogen::String

    function PatientZero(;pathogen::String = "") 
        return new(pathogen)
    end
end
Base.show(io::IO, cnd::PatientZero) = write(io, "PatientZero()")


"""
    pathogen(patientzero::PatientZero)

Returns pathogen used to infect individuals at the beginning in this start condition.
"""
function pathogen(patientzero::PatientZero)
    return patientzero.pathogen
end


"""
    initialize!(simulation::Simulation, condition::PatientZero)

Initialize the simulation model by infecting a single individual at random at the beginning of the simulation.
"""
function initialize!(simulation::Simulation, condition::PatientZero; seed_sample::Union{Int64,Nothing}=nothing)
    # create a new Xoshiro RNG for sampling, seeded from rng(simulation) if seed_sample is nothing, or from seed_sample otherwise
    rng_sample = isnothing(seed_sample) ? rng(simulation) : Xoshiro(seed_sample)
    
    # number of individuals to infect
    ind = individuals(population(simulation))
    to_infect = gems_sample(rng_sample, ind, 1, replace=false)

    pathogen = get_pathogen(simulation, condition.pathogen)

    # infect individuals
    for i in to_infect
        infect!(i, tick(simulation), pathogen, sim = simulation, rng = rng_sample)

        for (type, id) in settings_tuple(i)
            if id != DEFAULT_SETTING_ID
                current_setting = settings(simulation, type)[id]
                activate!(current_setting, simulation)
            end
        end
    end

    # push pending infections to InfectionRegistry 
    flush_pending_infections!(simulation)
end