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
    fraction::Float64
    pathogen::String # if empty, will be applied to all pathogens

    function InfectedFraction(;fraction::Float64 = 0.1, pathogen::String = "")
        fraction < 0.0 && throw(ArgumentError("Fraction must be greater than or equal to 0!"))
        fraction > 1.0 && throw(ArgumentError("Fraction must be less than or equal to 1!"))
        return new(fraction, pathogen)
    end
end

Base.show(io::IO, cnd::InfectedFraction) = write(io, "InfectedFraction(Random $(100*cnd.fraction)% $(cnd.pathogen))")


#TODO docs
struct PatientZero <: StartCondition
    pathogen::String

    PatientZero(;pathogen::String = "") = new(pathogen)
end


struct PatientZeros <: StartCondition
    pathogen::String
    ags::Vector{Int64}
end

"""
    pathogen(patientZero)

Returns pathogen used to infect individuals at the beginning in this start condition.
"""
function pathogen(patientzero::PatientZero)
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
function pathogen(patientzeros::PatientZeros)
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
function pathogen(infectedFraction::InfectedFraction)
    return infectedFraction.pathogen
end

### NECESSARY INTERFACE
"""
    initialize!(simulation, infectedFraction)

Initializes the simulation model with a fraction of infected individuals, provided by the start condition.
"""
function initialize!(simulation::Simulation, condition::InfectedFraction)
    # TODO handle case where pathogen is not specified
    # TODO handle multiple pathogens
    
    # number of individuals to infect
    ind = individuals(population(simulation))
    to_sample = Int64(round(fraction(condition) * length(ind)))
    to_infect = sample(ind, to_sample, replace=false)

    # infect individuals
    for i in to_infect
        infect!(i, tick(simulation), pathogen(simulation), sim = simulation)

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