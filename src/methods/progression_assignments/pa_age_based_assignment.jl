export AgeBasedProgressionAssignment

mutable struct AgeBasedProgressionAssignment <: ProgressionAssignmentFunction
    # Matrix with Disease Progression
    age_groups::Vector{String}
    progression_categories::Vector{DataType}
    stratification_matrix::Matrix{Float64}

    AgeBasedProgressionAssignment(;
        age_groups::Vector{String},
        progression_categories::Vector{String},
        stratification_matrix::Vector{Vector{T}} where T <: Real) =
       
        new(
            age_groups,
            get_subtype.(progression_categories, ProgressionCategory),
            hcat(stratification_matrix...)
        )
end




function assign(individual::Individual, sim::Simulation, age_based_assignment::AgeBasedProgressionAssignment)
    return Asymptomatic
end

function Base.show(io::IO, a::AgeBasedProgressionAssignment)
    print(io, "AgeBasedProgressionAssignment(age groups: $(join(a.age_groups, ", ")); progressions: $(join(a.progression_categories, ",")))")
end