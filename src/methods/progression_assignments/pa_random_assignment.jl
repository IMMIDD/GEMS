export RandomProgressionAssignment

mutable struct RandomProgressionAssignment <: ProgressionAssignmentFunction
    # Matrix with Disease Progression
    progression_categories::Vector{DataType}

    function RandomProgressionAssignment(progression_categories::Vector{DataType})
        isempty(progression_categories) && throw(ArgumentError("At least one progression category must be provided for RandomProgressionAssignment!"))
        return new(progression_categories)
    end

    RandomProgressionAssignment(;progression_categories::Vector{String}) =
        RandomProgressionAssignment(get_subtype.(progression_categories, ProgressionCategory))
end


function assign(individual::Individual, sim::Simulation, random_assignment::RandomProgressionAssignment)
    return rand(random_assignment.progression_categories)
end

function Base.show(io::IO, a::RandomProgressionAssignment)
    print(io, "RandomProgressionAssignment(progressions: $(join(a.progression_categories, ", ")))")
end