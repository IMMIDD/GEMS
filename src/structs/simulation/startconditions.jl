###
### INFECTEDFRACTION (TYPE DEFINITION & BASIC FUNCTIONALITY)
###
export fraction, pathogen
export initialize!
export parameters
"""
    InfectedFraction <: StartCondition

A `StartCondition` that specifies a fraction of infected individuals (drawn at random).

# Fields
- `fraction::Float64`: A fraction of the whole population that has ot be infected
- `pathogen::Pathogen`: The pathogen with which the fraction has to be infected
"""
struct InfectedFraction <: StartCondition
    # TODO throw exception when initialized with values not between 0 and 1
    fraction::Float64
    pathogen::Pathogen
end

Base.show(io::IO, cnd::StartCondition) = write(io, "InfectedFraction(Random $(100*cnd.fraction)% $(cnd.pathogen.name))")


#TODO docs
struct PatientZero <: StartCondition
    pathogen::Pathogen
end


struct PatientZeros <: StartCondition
    pathogen::Pathogen
    ags::Vector{Int64}
end

"""
    pathogen(patientZero)

Returns pathogen used to infect individuals at the beginning in this start condition.
"""
function pathogen(patientzero::PatientZero)::Pathogen
    return patientzero.pathogen
end

"""
    fraction(infectedFraction)

Returns fraction of individuals that shall be infected at the beginning in this start condition.
"""
function fraction(infectedFraction::InfectedFraction)
    return infectedFraction.fraction
end
"""
    pathogen(patientZeros)

Returns pathogen used to infect individuals at the beginning in this start condition.
"""
function pathogen(patientzeros::PatientZeros)::Pathogen
    return patientzeros.pathogen
end
"""
    ags(patientZeros)

Returns the vector of ags where intial seeds should be planted.
"""
function ags(patientzeros::PatientZeros)::Vector{Int64}
    return patientzeros.ags
end
"""
    pathogen(infectedFraction)

Returns pathogen used to infect individuals at the beginning in this start condition.
"""
function pathogen(infectedFraction::InfectedFraction)::Pathogen
    return infectedFraction.pathogen
end

### NECESSARY INTERFACE
"""
    initialize!(simulation, infectedFraction; seed_sample)

Initialize the simulation model with a fraction of infected individuals, provided by the start condition.
For sampling the individuals to infect, a new `Xoshiro` RNG is created. If `seed_sample` is `nothing` (default), 
the seed is drawn from `rng(simulation)`. Otherwise, the provided `seed_sample` is used.
"""
function initialize!(simulation::Simulation, condition::InfectedFraction; seed_sample::Union{Int64,Nothing}=nothing)
    # create a new Xoshiro RNG for sampling, seeded from rng(simulation) if seed_sample is nothing, or from seed_sample otherwise
    rng_sample = isnothing(seed_sample) ? Xoshiro(rand(rng(simulation), Int64)) : Xoshiro(seed_sample)

    # number of individuals to infect
    ind = individuals(population(simulation))
    to_sample = Int64(round(fraction(condition) * length(ind)))
    to_infect = sample(rng_sample, ind, to_sample, replace=false)

    # overwrite pathogen in simulation struct
    pathogen!(simulation, pathogen(condition))

    # infect individuals
    for i in to_infect
        infect!(i, tick(simulation), pathogen(condition), rng=rng(simulation))

        for (type, id) in settings(i, simulation)
            activate!(settings(simulation, type)[id])
        end
    end

end



#TODO docs
function initialize!(simulation::Simulation, condition::PatientZero; seed_sample::Union{Int64,Nothing}=nothing)
    # create a new Xoshiro RNG for sampling, seeded from rng(simulation) if seed_sample is nothing, or from seed_sample otherwise
    rng_sample = isnothing(seed_sample) ? Xoshiro(rand(rng(simulation), Int64)) : Xoshiro(seed_sample)

    # number of individuals to infect
    ind = individuals(population(simulation))
    to_infect = sample(rng_sample, ind, 1, replace=false)

    # overwrite pathogen in simulation struct
    pathogen!(simulation, pathogen(condition))

    # infect individuals
    for i in to_infect
        infect!(i, tick(simulation), pathogen(condition), rng=rng(simulation))

        for (type, id) in settings(i, simulation)
            activate!(settings(simulation, type)[id])
        end
    end
end

function initialize!(simulation::Simulation, condition::PatientZeros; seed_sample::Union{Int64,Nothing}=nothing)
    # create a new Xoshiro RNG for sampling, seeded from rng(simulation) if seed_sample is nothing, or from seed_sample otherwise
    rng_sample = isnothing(seed_sample) ? Xoshiro(rand(rng(simulation), Int64)) : Xoshiro(seed_sample)

    # number of individuals to infect
    to_infect = []
    for a in ags(condition)
        # Get all individuals in households with the given ags
        inds = []
        for h in settings(simulation, Household)
            if a == h |> ags |> id
                inds = push!(inds, individuals(h)...)
            end
        end
        if length(inds) == 0
            error("No individuals found in the given ags")
        end
        # Sample one individual from the list of individuals
        to_infect = push!(to_infect, sample(rng_sample, inds, 1, replace=false) |> Base.first)
    end
    
    # overwrite pathogen in simulation struct
    pathogen!(simulation, pathogen(condition))

    # infect individuals
    for i in to_infect
        infect!(i, tick(simulation), pathogen(condition), rng=rng(simulation))
        for (type, id) in settings(i, simulation)
            activate!(settings(simulation, type)[id])
        end
    end
end

"""
    parameters(s::StartCondition)

Returns an empty dictionary.
"""
function parameters(s::StartCondition)
    return Dict()
end

"""
    parameters(inffrac::InfectedFraction)

Returns a dictionary containing the parameters of the infected fraction
start condition.
"""
function parameters(inffrac::InfectedFraction)
    return Dict(
        "pathogen" => inffrac |> pathogen |> name,
        "pathogen_id" => inffrac |> pathogen |> id,
        "fraction" => inffrac |> fraction
        )
end

"""
    parameters(p0::PatientZero)

Returns a dictionary containing the parameters of the patient zero 
start condition.
"""
function parameters(p0::PatientZero)
    return Dict(
        "pathogen" => p0 |> pathogen |> name,
        "pathogen_id" => p0 |> pathogen |> id
        )
end

"""
    parameters(p0::PatientZero)

Returns a dictionary containing the parameters of the patient zero 
start condition.
"""
function parameters(p0::PatientZeros)
    return Dict(
        "pathogen" => p0 |> pathogen |> name,
        "pathogen_id" => p0 |> pathogen |> id,
        "ags" => p0 |> ags
        )
end