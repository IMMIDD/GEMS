export RandomProgressionAssignment

mutable struct RandomProgressionAssignment <: ProgressionAssignmentFunction
    # Matrix with Disease Progression
    progression_categories::Vector{DataType}
end




function assign(individual::Individual, sim::Simulation, random_assignment::RandomProgressionAssignment)
    return rand(random_assignment.progression_categories)
end

function Base.show(io::IO, a::RandomProgressionAssignment)
    print(io, "RandomProgressionAssignment(progressions: $(join(a.progression_categories, ", ")))")
end