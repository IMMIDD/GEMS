export AgeGroup, in_group, check_continuity


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