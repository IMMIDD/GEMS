###
### PATHOGENS (TYPE DEFINITION & BASIC FUNCTIONALITY)
###
export Pathogen

export id, name
export progressions, progression, progression_assignment, transmission_function
export transmission_function!

mutable struct Pathogen <: Parameter
    id::Int8
    name::String

    # disease progressions
    progressions::Dict{DataType, ProgressionCategory}

    # progression assignment
    progression_assignment::ProgressionAssignmentFunction

    # Function for the transmission Probability
    transmission_function::TransmissionFunction

    # default constructor
    function Pathogen(;
        id::Int64 = -1,  # id is set later
        name::String = "",
        progressions::Vector{ProgressionCategory} = [
            TEMP_Asymptomatic(
                exposure_to_infectiousness = Poisson(1),
                infectiousness_to_recovery = Poisson(7)
            ),
            TEMP_Mild(
                exposure_to_infectiousness = Poisson(1),
                infectiousness_to_symptom_onset = Poisson(3),
                symptom_onset_to_recovery = Poisson(7)
            )],
        progression_assignment::ProgressionAssignmentFunction = AgeBasedProgressionAssignment(
            age_groups = ["0+"],
            progression_categories = ["TEMP_Asymptomatic"],
            stratification_matrix = [[1.0]]
        ),
        transmission_function::TransmissionFunction = ConstantTransmissionRate()
    )

        # exception handling
        length(name) <= 0 && throw(ArgumentError("Pathogen name must not be empty!"))
        length(progressions) <= 0 && throw(ArgumentError("Pathogen must have at least one disease progression!"))
        length(unique(typeof.(progressions))) > length(progressions) && throw(ArgumentError("Pathogen must not have multiple progressions of the same type!"))

        # convert progression vector to dict for quick lookups
        prg = Dict{DataType, ProgressionCategory}()
        for dp in progressions
            prg[typeof(dp)] = dp
        end

        return new(
            id,
            name,
            prg,
            progression_assignment,
            transmission_function
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

transmission_function!(p::Pathogen, tf::TransmissionFunction) = p.transmission_function = tf


function Base.show(io::IO, p::Pathogen)
    res = "Pathogen: $(p.name) (ID: $(p.id))\n"
    res *= "\u2514 Progressions:\n"
    for (dp_type, progression) in p.progressions
        res *= "  \u2514 $(dp_type)\n"
        for nm in fieldnames(dp_type)
            value = getfield(progression, nm)
            res *= "    \u2514 $(nm): $(value)\n"
        end
    end
    res *= "\u2514 Progression Assignment: $(p.progression_assignment)\n"
    res *= "\u2514 Transmission Function: $(p.transmission_function)\n"
    print(io, res)
end