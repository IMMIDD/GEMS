###
### PATHOGENS (TYPE DEFINITION & BASIC FUNCTIONALITY)
###
export Pathogen
export ProgressionCategory
export ProgressionAssignmentFunction
export TransmissionFunction
export InfectiousnessProfile
export ImmunityProfile

export id, name
export progressions, progression, progression_assignment, transmission_function
export transmission_function!
export infectiousness_profile, infectiousness_profile!


# Abstract types for disease progression categories and progression assignment functions
abstract type ProgressionCategory end
abstract type ProgressionAssignmentFunction end
abstract type TransmissionFunction end
abstract type InfectiousnessProfile end
abstract type ImmunityProfile end

"""
    Pathogen <: Parameter

A type that holds all relevant information about a pathogen.

# Fields
- `id::Int8`: Unique identifier for the pathogen.
- `name::String`: Name of the pathogen.
- `progressions::OrderedDict{DataType, ProgressionCategory}`: An ordered dictionary that
    maps progression category types to their instances.
- `progression_assignment::ProgressionAssignmentFunction`: A function that assigns a
    progression category to an individual. Must be a subtype of `ProgressionAssignmentFunction`.
- `transmission_function::TransmissionFunction`: A function that calculates the
    transmission probability of the pathogen. Must be a subtype of `TransmissionFunction`.

# Example

```julia
# Define disease progressions
dp_a = Asymptomatic(
    exposure_to_infectiousness = Poisson(2),
    symptom_onset_to_recovery = Poisson(5)
)
dp_s = Symptomatic(
    exposure_to_infectiousness = Poisson(3),
    infectiousness_to_symptom_onset = Poisson(1),
    symptom_onset_to_recovery = Poisson(7)
)

# Define progression assignment function
pa = RandomProgressionAssignment([Asymptomatic, Symptomatic])

# Define transmission function
tf = ConstantTransmissionRate(transmission_rate = 0.3)

# Create pathogen
pathogen = Pathogen(
    id = 1,
    name = "Covid19",
    progressions = [dp_a, dp_s],
    progression_assignment = pa,
    transmission_function = tf
)
```

"""
mutable struct Pathogen{TF<:TransmissionFunction, IP<:InfectiousnessProfile, IM<:ImmunityProfile}
    id::Int8
    name::String

    # disease progressions
    progressions::OrderedDict{DataType, ProgressionCategory}

    # progression assignment
    progression_assignment::ProgressionAssignmentFunction

    # Function for the transmission Probability
    transmission_function::TF

    # infectiousness profile
    infectiousness_profile::IP
    
    # immunity profile
    immunity_profile::IM

    # default constructor
    function Pathogen(;
        id::Int64 = -1,  # id is set later
        name::String = "",
        progressions::Vector{<:ProgressionCategory} = ProgressionCategory[],
        progression_assignment::Union{ProgressionAssignmentFunction, Nothing} = nothing,
        transmission_function::Union{TransmissionFunction, Nothing} = nothing,
        infectiousness_profile::InfectiousnessProfile = ConstantInfectiousness(),
        immunity_profile::ImmunityProfile = FullImmunity()
    )

        # exception handling
        length(name) <= 0 && throw(ArgumentError("Pathogen name must not be empty!"))
        length(unique(typeof.(progressions))) < length(progressions) && throw(ArgumentError("Pathogen must not have multiple progressions of the same type!"))

        if isempty(progressions)
            @warn "Pathogen $name ($id) has no progressions defined. Defining a default Symptomatic progression."
            progressions = [Symptomatic(
                exposure_to_infectiousness_onset = Poisson(2),
                infectiousness_onset_to_symptom_onset = Poisson(1),
                symptom_onset_to_recovery = Poisson(7)
            )]
        end

        if isnothing(progression_assignment)
            @warn "Pathogen $name ($id) has no progression assignment function defined. Setting to default RandomProgressionAssignment with all provided progressions."
            progression_assignment = RandomProgressionAssignment(typeof.(progressions))
        end

        # setting defaults, if nothing provided
        if isnothing(transmission_function)
            @warn "Pathogen $name ($id) has no transmission function defined. Setting to default ConstantTransmissionRate with rate 0.2."
            transmission_function = ConstantTransmissionRate(transmission_rate = 0.2)
        end

        # convert progression vector to dict for quick lookups
        prg = Dict{DataType, ProgressionCategory}()
        for dp in progressions
            prg[typeof(dp)] = dp
        end

        return new{typeof(transmission_function), typeof(infectiousness_profile), typeof(immunity_profile)}(
            id,
            name,
            prg,
            progression_assignment,
            transmission_function,
            infectiousness_profile,
            immunity_profile
        )
    end

end



###
### GETTER & SETTER
###

id(p::Pathogen) = p.id
name(p::Pathogen) = p.name

progressions(p::Pathogen) = p.progressions
progression(p::Pathogen, dp_type::DataType) = p.progressions[dp_type]
progression_assignment(p::Pathogen) = p.progression_assignment
transmission_function(p::Pathogen) = p.transmission_function
infectiousness_profile(p::Pathogen) = p.infectiousness_profile

transmission_function!(p::Pathogen, tf::TransmissionFunction) = p.transmission_function = tf
infectiousness_profile!(p::Pathogen, ip::InfectiousnessProfile) = p.infectiousness_profile = ip

immunity_profile(p::Pathogen) = p.immunity_profile
immunity_profile!(p::Pathogen, ip::ImmunityProfile) = p.immunity_profile = ip


function Base.show(io::IO, p::Pathogen)
    res = "Pathogen: $(p.name) (ID: $(p.id))\n"
    res *= "\u2514 Progressions:\n"
    
    # get column width for pretty printing
    max_width = [maximum(length.(string.(fieldnames(dp_type)))) for (dp_type, _) in p.progressions] |> maximum

    for (dp_type, progression) in p.progressions
        res *= "  \u2514 $(dp_type)\n"
        for nm in fieldnames(dp_type)
            value = getfield(progression, nm)
            res *= "    \u2514 $(rpad(string(nm) * ":", max_width + 1)) $(value)\n"
        end
    end
    res *= "\u2514 Progression Assignment: $(p.progression_assignment)\n"
    res *= "\u2514 Transmission Function: $(p.transmission_function)\n"
    res *= "\u2514 Infectiousness Profile: $(p.infectiousness_profile)\n"
    res *= "\u2514 Immunity Profile: $(p.immunity_profile)\n"
    print(io, res)
end

"""
    _rebuild_pathogen(pg::Pathogen, tf, ip, im)

Internal helper: returns a new Pathogen with one or more of the three hot-path
components replaced by a different concrete type. Used by `determine_pathogens`
to override the transmission function after initial construction without violating
the parametric type constraint.
"""
function _rebuild_pathogen(pg::Pathogen;
        transmission_function  = pg.transmission_function,
        infectiousness_profile = pg.infectiousness_profile,
        immunity_profile  = pg.immunity_profile)
    return Pathogen(
        id  = Int64(id(pg)),
        name = name(pg),
        progressions = collect(values(progressions(pg))),
        progression_assignment = progression_assignment(pg),
        transmission_function = transmission_function,
        infectiousness_profile = infectiousness_profile,
        immunity_profile  = immunity_profile
    )
end