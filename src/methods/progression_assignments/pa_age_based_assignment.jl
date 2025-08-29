export AgeBasedProgressionAssignment


"""
    AgeGroup

A struct representing an age group with minimum and maximum ages.
At least one of min_age or max_age must be provided.
If min_age is `nothing`, there is no lower bound.
If max_age is `nothing`, there is no upper bound.

# Examples
```julia
julia> AgeGroup(0, 10)  # Represents ages 0 to 10 inclusive
AgeGroup(0-10)
julia> AgeGroup(nothing, 18)  # Represents ages up to 18 inclusive
AgeGroup(0-18)
julia> AgeGroup(65, nothing)  # Represents ages 65 and above
AgeGroup(65-Inf)
julia> AgeGroup("-10")  # Represents ages 0 to 10 inclusive
AgeGroup(0-10)
julia> AgeGroup("10-20")  # Represents ages 10 to 20 inclusive
AgeGroup(10-20)
julia> AgeGroup("65-")  # Represents ages 65 and above
AgeGroup(65-Inf)
```
"""
struct AgeGroup
    min_age::Union{Int64, Nothing}
    max_age::Union{Int64, Nothing}

    function AgeGroup(min_age::Union{Int64, Nothing}, max_age::Union{Int64, Nothing})
        isnothing(min_age) && isnothing(max_age) && throw(ArgumentError("At least one of min_age or max_age must be provided for AgeGroup!"))
        new(min_age, max_age)
    end

    function AgeGroup(string::String)
        # only allows input in the format -X, X-Y, or Y-
        pattern = r"^(-\d+|\d+-\d+|\d+-)$"
        occursin(pattern, string) || throw(ArgumentError("AgeGroup string must be in the format -A, A-B, or B- where A and B are non-negative integers."))

        parts = split(string, '-')
        min_age = isempty(parts[1]) ? nothing : parse(Int64, parts[1])
        max_age = length(parts) == 1 || isempty(parts[2]) ? nothing : parse(Int64, parts[2])

        return AgeGroup(min_age, max_age)
    end
end

function Base.show(io::IO, group::AgeGroup)
    min_str = isnothing(group.min_age) ? "0" : string(group.min_age)
    max_str = isnothing(group.max_age) ? "Inf" : string(group.max_age)
    print(io, "AgeGroup($min_str-$max_str)")
end


"""
    in_group(age::Real, group::AgeGroup)

Returns true if age is in the specified age group.
The minimum and maximum ages are inclusive.

# Examples
```julia
julia> group = AgeGroup(0, 10)
julia> in_group(5, group)
true
julia> in_group(0, group)
true
julia> in_group(10, group)
true
julia> in_group(-1, group)
false
```
"""
in_group(age::Real, group::AgeGroup) =
    (isnothing(group.min_age) || age >= group.min_age) &&
    (isnothing(group.max_age) || age <= group.max_age)

"""
    check_continuity(age_groups::Vector{AgeGroup}, min_age::Int64, max_age::Int64)

Checks if the provided age groups cover all ages between min_age and max_age without gaps or overlaps.
Throws an ArgumentError if the age groups are not continuous.
Returns true if the age groups are continuous.

# Examples
```julia
julia> groups = [AgeGroup(0, 10), AgeGroup(11, 20), AgeGroup(21, nothing)]
julia> check_continuity(groups, 0, 100)
true
julia> groups = [AgeGroup(0, 10), AgeGroup(10, 20), AgeGroup(21, nothing)]
julia> check_continuity(groups, 0, 100)
ERROR: ArgumentError: Age groups must not overlap! Age 10 is in 2 groups.
julia> groups = [AgeGroup(0, 10), AgeGroup(12, 20), AgeGroup(21, nothing)]
julia> check_continuity(groups, 0, 100)
ERROR: ArgumentError: Age groups must cover all ages between 0 and 100 without gaps! Age 11 is not covered.
```
"""
function check_continuity(age_groups::Vector{AgeGroup}, min_age::Int64, max_age::Int64)
    # exception handling
    (min_age < 0 || max_age < 0) && throw(ArgumentError("Ages must be positive integers."))
    min_age > max_age && throw(ArgumentError("min_age must be smaller or equal to max_age."))
    max_age > 120 && throw(ArgumentError("max_age cannot be larger than 120."))

    for a in min_age:max_age
        num_grps = sum(in_group.(a, age_groups))
        # if age is in two groups, the groups are overlapping
        num_grps > 1 && throw(ArgumentError("Age groups must not overlap! Age $a is in $num_grps groups."))
        # if age is in no group, the groups do not cover all ages
        num_grps == 0 && throw(ArgumentError("Age groups must cover all ages between $min_age and $max_age without gaps! Age $a is not covered."))
    end

    return true
end

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
        stratification_matrix::Vector{Vector{T}} where T <: Real)

        # exception handling
        isempty(age_groups) && throw(ArgumentError("At least one age group must be provided for AgeBasedProgressionAssignment!"))
        isempty(progression_categories) && throw(ArgumentError("At least one progression category must be provided for AgeBasedProgressionAssignment!"))
        
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
        rand |>
        rval -> age_based_assignment.progression_categories[rval]
end