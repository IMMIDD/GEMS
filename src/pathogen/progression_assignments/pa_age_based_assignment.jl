export AgeBasedProgressionAssignment

"""
    AgeBasedProgressionAssignment <: ProgressionAssignmentFunction

An assignment function that assigns disease progression categories based on age groups and a stratification matrix.

# Fields
- `age_groups::Vector{AgeGroup}`: A vector of age groups.
- `progression_categories::Vector{DataType}`: A vector of progression categories.
- `stratification_matrix::Matrix{Float64}`: A matrix where each column corresponds to an age group and each row corresponds to a progression category.

# Parameters for constructor
- `age_groups::Vector{String}`: A vector of age group strings in the format "-X", "X-Y", or "Y-".
- `progression_categories::Vector{String}`: A vector of progression category type names as strings.
- `stratification_matrix::Vector{Vector{T}} where T <: Real`: A matrix (as a vector of vectors) where each column corresponds to an age group and each row corresponds to a progression category. Each column must sum to 1 and contain no negative values.

# Example
The code below instantiates an `AgeBasedProgressionAssignment` with specific age groups, progression
categories, and a stratification matrix.
```julia
aba = AgeBasedProgressionAssignment(
    age_groups = ["-14", "15-65", "66-"],
    progression_categories = ["Asymptomatic", "Symptomatic", "Hospitalized", "Critical"],
    stratification_matrix = [[0.4, 0.45, 0.1, 0.05],
                             [0.2, 0.6, 0.15, 0.05],
                             [0.1, 0.4, 0.3, 0.2]]
)
```
"""
mutable struct AgeBasedProgressionAssignment <: ProgressionAssignmentFunction
    # Matrix with Disease Progression
    age_groups::Vector{AgeGroup}
    progression_categories::Vector{DataType}
    stratification_matrix::Matrix{Float64}

    function AgeBasedProgressionAssignment(;
        age_groups::Vector{String},
        progression_categories::Vector{String},
        stratification_matrix::Vector{<:Any})

        # check that the stratification matrix is a vector of vectors
        all(x -> isa(x, AbstractVector{<:Real}), stratification_matrix) ||
            throw(ArgumentError("Stratification matrix must be a vector of vectors of real numbers."))

        # exception handling
        isempty(age_groups) && throw(ArgumentError("At least one age group must be provided for AgeBasedProgressionAssignment!"))
        isempty(progression_categories) && throw(ArgumentError("At least one progression category must be provided for AgeBasedProgressionAssignment."))
        length(progression_categories) != length(unique(progression_categories)) &&
            throw(ArgumentError("Progression categories cannot contain duplicates ($(join(progression_categories, ", ")))."))

        # convert age group strings to AgeGroup structs        
        gprs = AgeGroup.(age_groups)
        check_continuity(gprs, 0, 100) # throw error if not continuous

        mtrx = hcat(stratification_matrix...)
        length(progression_categories) != size(mtrx, 1) && throw(ArgumentError("Number of progression categories must match number of columns in stratification matrix. (Got $(length(progression_categories)) categories and $(size(mtrx, 2)) columns in matrix.)"))
        length(age_groups) != size(mtrx, 2) && throw(ArgumentError("Number of age groups must match number of rows in stratification matrix. (Got $(length(age_groups)) age groups and $(size(mtrx, 1)) rows in matrix.)"))

        # check that each row sums to 1 and contains no negative values
        for (i, row) in enumerate(stratification_matrix)
            sum_row = sum(row)
            sum_row ≈ 1.0 || throw(ArgumentError("Each row of the stratification matrix must sum to 1. Row $i sums to $sum_row."))
            any(x -> x < 0.0, row) && throw(ArgumentError("Stratification matrix cannot contain negative values. Row $i contains negative values."))
        end

        return new(
            gprs,
            get_subtype.(progression_categories, ProgressionCategory),
            mtrx
        )
    end
end


function Base.show(io::IO, a::AgeBasedProgressionAssignment)
    print(io, "AgeBasedProgressionAssignment(age groups: $(join(a.age_groups, ", ")); progressions: $(join(a.progression_categories, ",")))")
end


###
### ASSIGNMENT FUNCTION
###

"""
    assign(individual::Individual, sim::Simulation, age_based_assignment::AgeBasedProgressionAssignment)

Assigns a disease progression category to an individual based on their age using the provided AgeBasedProgressionAssignment.
"""
function assign(individual::Individual, sim::Simulation, age_based_assignment::AgeBasedProgressionAssignment)
    # get the index of the age group the individual belongs to
    pos = findfirst(g -> in_group(individual.age, g), age_based_assignment.age_groups)

    isnothing(pos) && throw(ArgumentError("No age group found for individual with age $(individual.age)."))

    # sample from the categorical distribution defined by the stratification matrix for the age group
    return Categorical(age_based_assignment.stratification_matrix[:, pos]) |>
        dist -> gems_rand(sim, dist) |>
        rval -> age_based_assignment.progression_categories[rval]
end