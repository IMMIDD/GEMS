export AgeDependentTransmissionRate

"""
    AgeDependentTransmissionRate <: TransmissionFunction

A `TransmissionFunction` type that allows to define transmission probabilities for specific age groups.

"""
mutable struct AgeDependentTransmissionRate <: TransmissionFunction
    # JP TODO: At some point this should be "harmonized"
    # with the age-representation in the disease progression assignment
    
    # JP TODO: This should also allow for constant rates per age group

    transmission_rate::Distribution
    ageGroups::Vector{Vector{Int}}
    ageTransmissions::Vector{Distribution}

    @doc """
        AgeDependentTransmissionRate(;transmission_rate, ageGroups, ageTransmissions, distribution)

    Constructor for the age-dependent transmission rate struct. The parameters for the constructor include:
    
    - `transmission_rate::Vector`: A vector containing the parameters from which the distribution of the `transmission_rate` is constructed.
    - `ageGroups::Vector`: A vector containing the age groups. Should contain a vector for each age group consisting of two integers.
    - `ageTransmissions::Vector`: A vector containing the parameters for the distributions of the transmission rates for the specific age groups.
                                Should contain a vector for each age group consisting of as many real number as parameters required for the spec. distribution.
    - `distribution::String`: A string that corresponds to a distribution of the distribution package. 
    """
    function AgeDependentTransmissionRate(;transmission_rate::Vector{Float64} = [0.5,0.1], ageGroups::Vector{Vector{Int}} = [[0,130]], ageTransmissions::Vector{Vector{Float64}} = [[0.8,0.02]], distribution::String = "Normal")
        if length(ageTransmissions) != length(ageGroups) || any(length.(ageGroups) .!= 2)
            error("Check the provided parameters! ageTransmissions and ageGroups must have the same length, and each ageGroup must have two values.")
        elseif !(vcat(ageGroups...) |> x -> issorted(x) && all(diff(x) .> 0))
            error("Age groups should be provided in ascending order without overlaps!")
        end
        ageTransmissionDistributions = [eval(Meta.parse(distribution))(aT...) for aT in ageTransmissions] 
        baselTransmissionDistribution = eval(Meta.parse(distribution))(transmission_rate...)
        return new(baselTransmissionDistribution,
                    ageGroups,
                    ageTransmissionDistributions)
    end
end



"""
    transmission_probability(transFunc::AgeDependentTransmissionRate, infecter::Individual, infected::Individual, setting::Setting, tick::Int16; rng::AbstractRNG = Random.default_rng())

Calculates the transmission probability for the `AgeDependentTransmissionRate`. Selects the correct distribution 
dependent on the age of the potentially infected agent from the `AgeDependentTransmissionRate`, draws from it and
returns the value. If no age group is found for the individual the transmission rate is drawn from the transmission_rate distribution.
If the individual has already recovered, the function returns `0.0`, assuming full indefinite natural immunity.

# Parameters

- `transFunc::AgeDependentTransmissionRate`: Transmission function struct
- `infecter::Individual`: Infecting individual
- `infectee::Individual`: Individual to infect
- `setting::Setting`: Setting in which the infection happens
- `tick::Int16`: Current tick
- `rng::AbstractRNG = Random.default_rng()` *(optional)*: RNG used for probability. Uses Random's default RNG as default.

# Returns

- `Float64`: Transmission probability p (`0 <= p <= 1`)
"""
function transmission_probability(transFunc::AgeDependentTransmissionRate, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, rng::AbstractRNG)::Float64
    # error handling
    !infected(infecter) && throw(ArgumentError("Infecting individual must be infected to calculate transmission probability."))
    
    if  -1 < recovery(infectee) <= tick # if the agent has already recovered (natural immunity)
        return 0.0
    end
    
    for (i,ageGroup) in enumerate(transFunc.ageGroups)
        if ageGroup[1] <= infectee.age <= ageGroup[2]
            return gems_rand(rng, transFunc.ageTransmissions[i])
        end
    end
    return gems_rand(rng, transFunc.transmission_rate)
end
# if no RNG was passed, use default RNG
transmission_probability(transFunc::AgeDependentTransmissionRate, infecter::Individual, infected::Individual, setting::Setting, tick::Int16) = 
    transmission_probability(transFunc, infecter, infected, setting, tick, Random.default_rng())