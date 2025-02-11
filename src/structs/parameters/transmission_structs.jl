export TransmissionFunction
export ConstantTransmissionRate, AgeDependentTransmissionRate, SettingDependentTransmissionRate
export parameters


"""
    TransmissionFunction

Abstract type for all transmission functions.
    
"""
abstract type TransmissionFunction end

"""
    ConstantTransmissionRate <: TransmissionFunction

A `TransmissionFunction` type that uses a constant transmission rate.

"""
mutable struct ConstantTransmissionRate <: TransmissionFunction
    transmission_rate::Float64

    ConstantTransmissionRate(;transmission_rate::Float64 = .5) = new(transmission_rate)
end

Base.show(io::IO, ctr::ConstantTransmissionRate) = write(io, "ConstantTranmissionRate(β=$(ctr.transmission_rate))")

"""
    AgeDependentTransmissionRate <: TransmissionFunction

A `TransmissionFunction` type that allows to define transmission probabilities for specific age groups.

"""
mutable struct AgeDependentTransmissionRate <: TransmissionFunction
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
    parameters(transfunc::TransmissionFunction)


Fallback function for transmission functions that returns the type of 
the transmission function as an entry in a dictionary
"""
function parameters(transfunc::TransmissionFunction)
    return Dict("type" => string(transfunc))
end

"""
    parameters(transfunc::AgeDependentTransmissionRate)

Returns the parameters of the `AgeDependentTransmissionRate` as a dictionary.
"""
function parameters(transfunc::AgeDependentTransmissionRate)
    return Dict("type" => string(transfunc),
                "parameters" => Dict("transmission_rate" => params(transfunc.transmission_rate),
                "age_groups" => transfunc.ageGroups,
                "age_transmissions " => [parameters(aT) for aT in transfunc.ageTransmissions]))
end

"""
    parameters(transfunc::ConstantTransmissionRate)

Returns the parameters of the `ConstantTransmissionRate` as a dictionary.
"""
function parameters(transfunc::ConstantTransmissionRate)
    return Dict("type" => string(transfunc),
                "parameters" => Dict("transmission_rate" => transfunc.transmission_rate))
end
