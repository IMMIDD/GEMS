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
        
        # TODO remove this warning when multi-pathogen simulations are supported
        length(pathogen) > 0 && @warn "GEMS currently only supports single-pathogen simulations. Specifying a pathogen in InfectedFraction will have no effect."
        return new(fraction, pathogen)
    end
end

Base.show(io::IO, cnd::InfectedFraction) = write(io, "InfectedFraction(Random $(100*cnd.fraction)% $(cnd.pathogen))")


"""
    PatientZero <: StartCondition

A `StartCondition` that infects a single individual at random at the beginning of the simulation.

# Fields
- `pathogen::String`: The pathogen with which the individual has to be infected

"""
struct PatientZero <: StartCondition
    pathogen::String

    function PatientZero(;pathogen::String = "") 
        
        # TODO remove this warning when multi-pathogen simulations are supported
        length(pathogen) > 0 && @warn "GEMS currently only supports single-pathogen simulations. Specifying a pathogen in PatientZero will have no effect."
        return new(pathogen)
    end
end

"""
    PatientZeros <: StartCondition

A `StartCondition` that infects a single individual in each of the given AGS (community identification numbers) at the beginning of the simulation.

# Fields
- `pathogen::String`: The pathogen with which the individual has to be infected
- `ags::Vector{Int64}`: A vector of AGS (community identification number) where the initial seeds should be planted


"""
struct PatientZeros <: StartCondition
    pathogen::String
    ags::Vector{Int64}

    function PatientZeros(;pathogen::String = "", ags::Vector{Int64} = Int64[])
        isempty(ags) && throw(ArgumentError("At least one ags must be provided!"))
        length(pathogen) > 0 && @warn "GEMS currently only supports single-pathogen simulations. Specifying a pathogen in PatientZeros will have no effect."
        return new(pathogen, ags)
    end
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
    # TODO handle pathogen selection
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
    # TODO handle pathogen selection
    # TODO handle multiple pathogens
    
    # number of individuals to infect
    ind = individuals(population(simulation))
    to_infect = sample(ind, 1, replace=false)

    # infect individuals
    for i in to_infect
        infect!(i, tick(simulation), pathogen(simulation), sim = simulation)

        for (type, id) in settings(i, simulation)
            activate!(settings(simulation, type)[id])
        end
    end
end

function initialize!(simulation::Simulation, condition::PatientZeros)
    # TODO handle pathogen selection
    # TODO handle multiple pathogens

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
   
    # infect individuals
    for i in to_infect
        infect!(i, tick(simulation), pathogen(simulation), sim = simulation)
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