###
### INFECTEDFRACTION (TYPE DEFINITION & BASIC FUNCTIONALITY)
###
export fraction, pathogen, seeds
export initialize!
export parameters


##### GENERAL STUFF

"""
    parameters(s::StartCondition)

Returns an empty dictionary.
"""
function parameters(s::StartCondition)
    return Dict()
end


##### INFECTED FRACTION

"""
    InfectedFraction <: StartCondition

A `StartCondition` that specifies a fraction of infected individuals (drawn at random).

# Fields
- `fraction::Float64`: A fraction of the whole population that has to be infected
- `pathogen::Pathogen`: The pathogen with which the fraction has to be infected
"""
struct InfectedFraction <: StartCondition
    # TODO throw exception when initialized with values not between 0 and 1
    fraction::Float64
    pathogen::Pathogen
end

Base.show(io::IO, cnd::StartCondition) = write(io, "InfectedFraction(Random $(100*cnd.fraction)% $(cnd.pathogen.name))")


"""
    fraction(infectedFraction::InfectedFraction)

Returns fraction of individuals that shall be infected at the beginning using the `InfectedFraction` start condition.
"""
function fraction(infectedFraction::InfectedFraction)
    return infectedFraction.fraction
end


"""
    pathogen(infectedFraction::InfectedFraction)

Returns pathogen used to infect individuals at the beginning using the `InfectedFraction` start condition.
"""
function pathogen(infectedFraction::InfectedFraction)::Pathogen
    return infectedFraction.pathogen
end

### NECESSARY INTERFACE
"""
    initialize!(simulation::Simulation, condition::InfectedFraction; seed_sample::Union{Int64,Nothing}=nothing)

Initialize the simulation model with a fraction of infected individuals, provided by the start condition.
For sampling the individuals to infect, a new `Xoshiro` RNG is created. If `seed_sample` is `nothing` (default), 
the seed is drawn from `rng(simulation)`. Otherwise, the provided `seed_sample` is used.
"""
function initialize!(simulation::Simulation, condition::InfectedFraction; seed_sample::Union{Int64,Nothing}=nothing)
    # create a new Xoshiro RNG for sampling, seeded from rng(simulation) if seed_sample is nothing, or from seed_sample otherwise
    rng_sample = isnothing(seed_sample) ? Xoshiro(gems_rand(rng(simulation), Int64)) : Xoshiro(seed_sample)

    # number of individuals to infect
    ind = individuals(population(simulation))
    to_sample = Int64(round(fraction(condition) * length(ind)))
    to_infect = gems_sample(rng_sample, ind, to_sample, replace=false)

    # overwrite pathogen in simulation struct
    pathogen!(simulation, pathogen(condition))

    # infect individuals
    for i in to_infect
        infect!(i, tick(simulation), pathogen(condition), sim = simulation, rng=rng(simulation))

        for (type, id) in settings(i, simulation)
            activate!(settings(simulation, type)[id])
        end
    end

end


##### INFECTED INDIVIDUALS

"""
    InfectedIndividuals <: StartCondition

A `StartCondition` that specifies the number of initially infected individuals (drawn at random).

# Fields
- `seeds::Int64`: The number of initially infected individuals
- `pathogen::Pathogen`: The pathogen with which the fraction has to be infected
"""
struct InfectedIndividuals <: StartCondition
    seeds::Int64
    pathogen::Pathogen

    function InfectedIndividuals(seeds::Int64, pathogen::Pathogen)
        if seeds <= 0
            throw("The minimum number of initially infected individuals is 1.")
        end
        
        return new(seeds, pathogen)
    end
end


"""
    seeds(infectedIndividuals::InfectedIndividuals)

Returns number of individuals that shall be infected at the beginning using the `InfectedIndividuals` start condition.
"""
function seeds(infectedIndividuals::InfectedIndividuals)
    return infectedIndividuals.seeds
end


"""
    pathogen(infectedIndividuals::InfectedIndividuals)

Returns pathogen used to infect individuals at the beginning using the `InfectedIndividuals` start condition.
"""
function pathogen(infectedIndividuals::InfectedIndividuals)::Pathogen
    return infectedIndividuals.pathogen
end


"""
    parameters(infinds::InfectedIndividuals)

Returns a dictionary containing the parameters of the `InfectedIndividuals`
start condition.
"""
function parameters(infinds::InfectedIndividuals)
    return Dict(
        "pathogen" => infinds |> pathogen |> name,
        "pathogen_id" => infinds |> pathogen |> id,
        "seeds" => infinds |> fraction
        )
end


"""
    initialize!(simulation::Simulation, condition::InfectedIndividuals; seed_sample::Union{Int64,Nothing}=nothing)

Initializes the simulation model with a number of infected individuals, provided by the start condition.
"""
function initialize!(simulation::Simulation, condition::InfectedIndividuals; seed_sample::Union{Int64,Nothing}=nothing)
    # create a new Xoshiro RNG for sampling, seeded from rng(simulation) if seed_sample is nothing, or from seed_sample otherwise
    rng_sample = isnothing(seed_sample) ? rng(simulation) : Xoshiro(seed_sample)


    # number of individuals to infect
    ind = individuals(population(simulation))
    to_sample = seeds(condition)
    to_infect = gems_sample(rng_sample, ind, to_sample, replace=false)

    # overwrite pathogen in simulation struct
    pathogen!(simulation, pathogen(condition))

    # infect individuals
    for i in to_infect
        infect!(i, tick(simulation), pathogen(condition), sim = simulation)

        for (type, id) in settings(i, simulation)
            activate!(settings(simulation, type)[id])
        end
    end

end



##### PATIENT ZERO

"""
    PatientZero <: StartCondition

A `StartCondition` that infects exactly one individual at the beginning (drawn at random).

# Fields
- `pathogen::Pathogen`: The pathogen with which the individual has to be infected
"""
struct PatientZero <: StartCondition
    pathogen::Pathogen
end

"""
    pathogen(patientzero::PatientZero)

Returns pathogen used to infect individuals at the beginning using the `PatientZero` start condition.
"""
function pathogen(patientzero::PatientZero)::Pathogen
    return patientzero.pathogen
end

"""
    initialize!(simulation::Simulation, condition::PatientZero)

Initializes the simulation model with one infected individual drawn at random.
"""
function initialize!(simulation::Simulation, condition::PatientZero; seed_sample::Union{Int64,Nothing}=nothing)
    # create a new Xoshiro RNG for sampling, seeded from rng(simulation) if seed_sample is nothing, or from seed_sample otherwise
    rng_sample = isnothing(seed_sample) ? rng(simulation) : Xoshiro(seed_sample)

    # number of individuals to infect
    ind = individuals(population(simulation))
    to_infect = gems_sample(rng_sample, ind, 1, replace=false)

    # overwrite pathogen in simulation struct
    pathogen!(simulation, pathogen(condition))

    # infect individuals
    for i in to_infect
        infect!(i, tick(simulation), pathogen(condition), sim = simulation, rng=rng(simulation))

        for (type, id) in settings(i, simulation)
            activate!(settings(simulation, type)[id])
        end
    end
end



"""
    parameters(p0::PatientZero)

Returns a dictionary containing the parameters of the `PatientZero`
start condition.
"""
function parameters(p0::PatientZero)
    return Dict(
        "pathogen" => p0 |> pathogen |> name,
        "pathogen_id" => p0 |> pathogen |> id
        )
end



##### PATIENT ZEROS

"""
    PatientZeros <: StartCondition

A `StartCondition` that infects exactly one individual at the beginning (drawn at random) in each 
of the regions provided by their AGS (community identification number) .

# Fields
- `pathogen::Pathogen`: The pathogen with which the individual(s) has to be infected
- `ags::Vector{Int64}`: Vector of regions (AGS) as Integers
"""
struct PatientZeros <: StartCondition
    pathogen::Pathogen
    ags::Vector{Int64}
end


"""
    pathogen(patientzeros::PatientZeros)

Returns pathogen used to infect individuals at the beginning  using the `PatientZeros` start condition.
"""
function pathogen(patientzeros::PatientZeros)::Pathogen
    return patientzeros.pathogen
end


"""
    ags(patientzeros::PatientZeros)

Returns the vector of ags where intial seeds should be planted.
"""
function ags(patientzeros::PatientZeros)::Vector{Int64}
    return patientzeros.ags
end


"""
    parameters(p0::PatientZeros)

Returns a dictionary containing the parameters of the `PatientZeros`
start condition.
"""
function parameters(p0::PatientZeros)
    return Dict(
        "pathogen" => p0 |> pathogen |> name,
        "pathogen_id" => p0 |> pathogen |> id,
        "ags" => p0 |> ags
        )
end


"""
    initialize!(simulation::Simulation, condition::PatientZeros; seed_sample::Union{Int64,Nothing}=nothing)

Initializes the simulation model with one infected individual drawn at random for
each of the regions provided via their community identifaction number (AGS) in the
`PatientZeros` start condition.
"""
function initialize!(simulation::Simulation, condition::PatientZeros; seed_sample::Union{Int64,Nothing}=nothing)
    # create a new Xoshiro RNG for sampling, seeded from rng(simulation) if seed_sample is nothing, or from seed_sample otherwise
    rng_sample = isnothing(seed_sample) ? rng(simulation) : Xoshiro(seed_sample)

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
        to_infect = push!(to_infect, gems_sample(rng_sample, inds, 1, replace=false) |> Base.first)
    end
    
    # overwrite pathogen in simulation struct
    pathogen!(simulation, pathogen(condition))

    # infect individuals
    for i in to_infect
        infect!(i, tick(simulation), pathogen(condition), sim = simulation, rng=rng(simulation))
        for (type, id) in settings(i, simulation)
            activate!(settings(simulation, type)[id])
        end
    end
end


##### REGIONAL SEEDS

"""
    RegionalSeeds <: StartCondition

A `StartCondition` that infects the provided number of individual at the beginning (drawn at random) in 
the regions provided by their AGS (community identification number).

# Fields
- `pathogen::Pathogen`: The pathogen with which the individual(s) has to be infected
- `seeds::Dict{Int64, Int64}`: Dict that holds {AGS, NUMBER} pairs specifying the regions and the respective number of individuals that shall be infected at initialization. 
"""
struct RegionalSeeds <: StartCondition
    pathogen::Pathogen
    # region and number of seeds
    seeds::Dict{Int64, Int64}

    function RegionalSeeds(pathogen::Pathogen, seeds::Dict)
        sds = Dict{Int64, Int64}()
        for (k, v) in seeds
            try
                sds[parse(Int64, k)] = typeof(v) <: Int ? v : parse(Int64, v)
            catch
                throw("You need to pass values that can be parsed to integers to the RegionalSeeds start condition.")
            end
        end

        return new(pathogen, sds)
    end
end

"""
    pathogen(regionalseeds::RegionalSeeds)

Returns pathogen used to infect individuals at the beginning  using the `RegionalSeeds` start condition.
"""
function pathogen(regionalseeds::RegionalSeeds)::Pathogen
    return regionalseeds.pathogen
end

"""
    seeds(regionalseeds::RegionalSeeds)

Returns the dictionary holding the {AGS, NUMBER} pairs, specifying the regions
(via community identification number (AGS)) and the number of initial infections
using the `RegionalSeeds` start condition.
"""
function seeds(regionalseeds::RegionalSeeds)
    return regionalseeds.seeds
end


"""
    parameters(rs::RegionalSeeds)

Returns a dictionary containing the parameters of the `RegionalSeeds` 
start condition.
"""
function parameters(rs::RegionalSeeds)
    return Dict(
        "pathogen" => rs |> pathogen |> name,
        "pathogen_id" => rs |> pathogen |> id,
        "seeds" => rs |> seeds
        )
end

"""
    initialize!(simulation::Simulation, condition::RegionalSeeds; seed_sample::Union{Int64,Nothing}=nothing)

Initializes the simulation model, infecting the number of individuals
in the regions, both provided by the `RegionalSeeds` start condition.
Regions can be specified as states, counties or municipalities.

It would also be possible to provide, e.g., a municiaplity AND its
surrounding county. In that case, an individual could be sampled twice.
This function will not prevent that but throw a warning.
"""
function initialize!(simulation::Simulation, condition::RegionalSeeds; seed_sample::Union{Int64,Nothing}=nothing)
    # create a new Xoshiro RNG for sampling, seeded from rng(simulation) if seed_sample is nothing, or from seed_sample otherwise
    rng_sample = isnothing(seed_sample) ? rng(simulation) : Xoshiro(seed_sample)

    # takes an input vector of AGS and a reference AGS
    # returns a bitvector indicating whether the respective
    # AGS is equal to (for municipalities) or contained
    # in the proivided "parent_ags"
    function filter_by_ags(ags_vector, parent_ags)
        if is_state(parent_ags)
            return (a -> in_state(a, parent_ags)).(ags_vector)
        elseif is_county(parent_ags)
            return (a -> in_state(a, parent_ags)).(ags_vector)
        else
            return parent_ags .== ags_vector
        end
    end

    # build dataframe referencing AGS (extracted from households)
    # and individuals
    ind_ags = individuals(simulation) |>
        inds -> DataFrame(
            ags = (i -> ags(household(i, simulation))).(inds),
            individual = inds)

    # build array of individuals to infect
    to_infect = Individual[]
    for (a, cnt) in seeds(condition)
        try
            AGS(a) |>
                # filter individuals depending on AGS
                # (whether its a state, county, or municipality)
                in_ags -> ind_ags.individual[filter_by_ags(ind_ags.ags, in_ags)] |>
                # sample required number of individuals
                inds -> gems_sample(rng_sample, inds, cnt, replace=false) |>
                inds -> append!(to_infect, inds)
        catch
            throw("Getting the seeding infections crashed. You might have provided a region in the configs that is not available in the population model or asked to infect a number of people that exceeds the population size of the region.")
        end
    end

    # theoretically, an individual can get selected multiple times
    # if the dict has AGSs' that are contained in others
    # we don't resample in that case but just print a warning
    if length(unique(to_infect)) != length(to_infect)
        @warn "One or more individuals were sampled multiple times for the seeding infections. You may have passed nested regions (AGS) to the StartCondition causing this problem."
    end

    # overwrite pathogen in simulation struct
    pathogen!(simulation, pathogen(condition))

    # infect individuals
    for i in to_infect
        infect!(i, tick(simulation), pathogen(condition))
        for (type, id) in settings(i, simulation)
            activate!(settings(simulation, type)[id])
        end
    end
end