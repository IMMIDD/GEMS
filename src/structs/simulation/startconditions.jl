###
### INFECTEDFRACTION (TYPE DEFINITION & BASIC FUNCTIONALITY)
###
export fraction, pathogen, seeds
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

function pathogen(regionalseeds::RegionalSeeds)::Pathogen
    return regionalseeds.pathogen
end

function seeds(regionalseeds::RegionalSeeds)
    return regionalseeds.seeds
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
    initialize!(simulation, infectedFraction)

Initializes the simulation model with a fraction of infected individuals, provided by the start condition.
"""
function initialize!(simulation::Simulation, condition::InfectedFraction)
    # number of individuals to infect
    ind = individuals(population(simulation))
    to_sample = Int64(round(fraction(condition) * length(ind)))
    to_infect = sample(ind, to_sample, replace=false)

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



#TODO docs
function initialize!(simulation::Simulation, condition::PatientZero)
    # number of individuals to infect
    ind = individuals(population(simulation))
    to_infect = sample(ind, 1, replace=false)

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

function initialize!(simulation::Simulation, condition::PatientZeros)
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
        to_infect = push!( to_infect, sample(inds, 1, replace=false) |> Base.first)
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


function initialize!(simulation::Simulation, condition::RegionalSeeds)

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
                inds -> sample(inds, cnt, replace=false) |>
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