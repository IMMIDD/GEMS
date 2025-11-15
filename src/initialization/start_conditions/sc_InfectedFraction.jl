export InfectedFraction
export pathogen, fraction
export initialize!

"""
    InfectedFraction <: StartCondition

A `StartCondition` that specifies a fraction of infected individuals (drawn at random).

# Fields
- `fraction::Float64`: A fraction of the whole population that has to be infected
- `pathogen::Pathogen`: The pathogen with which the fraction has to be infected

Example
```julia
condition = InfectedFraction(fraction=0.05) # 5% of the population infected at random
sim = Simulation(start_condition = condition)
```
"""
struct InfectedFraction <: StartCondition
    fraction::Float64
    pathogen::String # if empty, will be applied to all pathogens

    function InfectedFraction(;fraction::Float64, pathogen::String = "")
        fraction < 0.0 && throw(ArgumentError("Fraction must be greater than or equal to 0!"))
        fraction > 1.0 && throw(ArgumentError("Fraction must be less than or equal to 1!"))
        
        # TODO remove this warning when multi-pathogen simulations are supported
        length(pathogen) > 0 && @warn "GEMS currently only supports single-pathogen simulations. Specifying a pathogen in InfectedFraction will have no effect."
        return new(fraction, pathogen)
    end
end

Base.show(io::IO, cnd::InfectedFraction) = write(io, "InfectedFraction(Random $(100*cnd.fraction)%)")


"""
    pathogen(infectedFraction::InfectedFraction)

Returns pathogen used to infect individuals at the beginning using the `InfectedFraction` start condition.
"""
function pathogen(infectedFraction::InfectedFraction)
    return infectedFraction.pathogen
end

"""
    fraction(infectedFraction::InfectedFraction)

Returns fraction of individuals that shall be infected at the beginning using the `InfectedFraction` start condition.
"""
function fraction(infectedFraction::InfectedFraction)
    return infectedFraction.fraction
end


"""
    initialize!(simulation::Simulation, condition::InfectedFraction; seed_sample::Union{Int64,Nothing}=nothing)

Initialize the simulation model with a fraction of infected individuals, provided by the start condition.
For sampling the individuals to infect, a new `Xoshiro` RNG is created. If `seed_sample` is `nothing` (default), 
the seed is drawn from `rng(simulation)`. Otherwise, the provided `seed_sample` is used.
"""
function initialize!(simulation::Simulation, condition::InfectedFraction; seed_sample::Union{Int64,Nothing}=nothing)
    # create a new Xoshiro RNG for sampling, seeded from rng(simulation) if seed_sample is nothing, or from seed_sample otherwise
    rng_sample = isnothing(seed_sample) ? rng(simulation) : Xoshiro(seed_sample)

    # TODO handle pathogen selection
    # TODO handle multiple pathogens
    
    # number of individuals to infect
    ind = individuals(population(simulation))
    to_sample = Int64(round(fraction(condition) * length(ind)))
    to_infect = gems_sample(rng_sample, ind, to_sample, replace=false)

    # infect individuals
    for i in to_infect
        infect!(i, tick(simulation), pathogen(simulation), sim = simulation, rng = rng_sample)

        for (type, id) in settings(i, simulation)
            activate!(settings(simulation, type)[id])
        end
    end

end