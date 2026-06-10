###
### PATHOGENS (TYPE DEFINITION & BASIC FUNCTIONALITY)
###
export Pathogen
export ProgressionCategory
export ProgressionAssignmentFunction
export TransmissionFunction
export TransmissionModifier
export InfectiousnessProfile
export ImmunityProfile

export id, name
export progressions, progression_assignment, transmission_function
export transmission_function!
export effective_transmission_probability
export infectiousness_profile, infectiousness_profile!

export get_progression

# Abstract types for disease progression categories and progression assignment functions
abstract type ProgressionCategory end
abstract type ProgressionAssignmentFunction end
abstract type TransmissionFunction end
abstract type TransmissionModifier end
abstract type InfectiousnessProfile end
abstract type ImmunityProfile end

"""
    Pathogen

A type that holds all relevant information about a pathogen.

# Fields
- `id::Int8`: Unique identifier for the pathogen.
- `name::String`: Name of the pathogen.
- `progressions::Tuple`: A typed tuple containing instances of `ProgressionCategory` that define the possible disease progressions.
- `progression_assignment::ProgressionAssignmentFunction`: A function that assigns a progression category to an individual. Must be a subtype of `ProgressionAssignmentFunction`.
- `transmission_function::TransmissionFunction`: A function that calculates the transmission probability of the pathogen. Must be a subtype of `TransmissionFunction`.
- `infectiousness_profile::InfectiousnessProfile`: The profile defining the infectiousness dynamics over time.
- `immunity_profile::ImmunityProfile`: The profile defining the immunity dynamics (e.g., acquisition and waning).

# Example

```julia
# Define disease progressions
dp_a = Asymptomatic(
    exposure_to_infectiousness_onset = Poisson(2),
    symptom_onset_to_recovery = Poisson(5)
)
dp_s = Symptomatic(
    exposure_to_infectiousness_onset = Poisson(3),
    infectiousness_onset_to_symptom_onset = Poisson(1),
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
    # infectiousness_profile and immunity_profile will use their defaults
)
"""
mutable struct Pathogen{PRG<:Tuple, PA<:ProgressionAssignmentFunction, TF<:TransmissionFunction, IP<:InfectiousnessProfile, IM<:ImmunityProfile}
    id::Int8
    name::String

    # disease progressions
    progressions::PRG

    # progression assignment
    progression_assignment::PA

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

        # convert progression vector to a typed tuple
        prg_tuple = (progressions...,)

        return new{typeof(prg_tuple), typeof(progression_assignment), typeof(transmission_function), typeof(infectiousness_profile), typeof(immunity_profile)}(
            id,
            name,
            prg_tuple,
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
progression_assignment(p::Pathogen) = p.progression_assignment
transmission_function(p::Pathogen) = p.transmission_function
infectiousness_profile(p::Pathogen) = p.infectiousness_profile

transmission_function!(p::Pathogen, tf::TransmissionFunction) = p.transmission_function = tf
infectiousness_profile!(p::Pathogen, ip::InfectiousnessProfile) = p.infectiousness_profile = ip

immunity_profile(p::Pathogen) = p.immunity_profile
immunity_profile!(p::Pathogen, ip::ImmunityProfile) = p.immunity_profile = ip


 """

    get_progression(progressions::PR, dp_type::DataType) where {PR<:Tuple}


Retrieves a progression by its DataType from a typed Tuple of progressions.

Emits a static if/elseif chain at compile time, enabling union-splitting.

"""

@generated function get_progression(progressions::PR, dp_type::DataType) where {PR<:Tuple}
    N = fieldcount(PR)
    exprs = Expr[]
    for i in 1:N
        T = fieldtype(PR, i) 
        push!(exprs, :( $T === dp_type && return progressions[$i] ))
    end
    push!(exprs, :(throw(ArgumentError("No progression of type $dp_type found."))))
    return quote $(exprs...) end
end
get_progression(p::Pathogen, dp_type::DataType) = get_progression(p.progressions, dp_type) 


function Base.show(io::IO, p::Pathogen)
    res = "Pathogen: $(p.name) (ID: $(p.id))\n"
    res *= "\u2514 Progressions:\n"
    
    # get column width for pretty printing
    max_width = isempty(p.progressions) ? 0 : maximum(maximum(length.(string.(fieldnames(typeof(prog))))) for prog in p.progressions)

    for progression in p.progressions
        dp_type = typeof(progression) # Extract the type from the object
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
        progression_assignment = pg.progression_assignment,
        transmission_function  = pg.transmission_function,
        infectiousness_profile = pg.infectiousness_profile,
        immunity_profile = pg.immunity_profile)
    return Pathogen(
        id  = Int64(id(pg)),
        name = name(pg),
        progressions = collect(progressions(pg)),
        progression_assignment = progression_assignment,
        transmission_function = transmission_function,
        infectiousness_profile = infectiousness_profile,
        immunity_profile  = immunity_profile
    )
end