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
        
        # TODO remove this warning when multi-pathogen simulations are supported
        length(pathogen) > 0 && @warn "GEMS currently only supports single-pathogen simulations. Specifying a pathogen in PatientZero will have no effect."
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
    # TODO handle pathogen selection
    # TODO handle multiple pathogens
    
    # number of individuals to infect
    ind = individuals(population(simulation))
    to_infect = gems_sample(rng_sample, ind, 1, replace=false)

    # infect individuals
    for i in to_infect
        infect!(i, tick(simulation), pathogen(simulation), sim = simulation, rng = rng_sample)

        for (type, id) in settings(i, simulation)
            activate!(settings(simulation, type)[id])
        end
    end
end