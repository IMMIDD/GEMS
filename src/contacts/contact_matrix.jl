# TODO: find a better directory in this project
export ContactMatrix


# Factoring: As those contact matrices only represent data from one study, its necessary to have the option to assign an "importance factor" to the contact number (e.g. 0-10 year olds have 300% more contacts than in the study associated to the contact matrix)

#=
IDEA: if we also want to aggregate contact matrices by other categories than "age" we should formalize each category as it's own type. Instead of having 1 specific struct "ContactMatrix" we would have to make "ContactMatrix" an abstract type and then implement each different aggregation style as it's own "struct". The following types could be an idea for the stated formalisation:

"An abstract type for all AggregationTypes"
abstract type AggregationType end

"A type representing the aggreagtion type 'Age' for aggregating contact matrices."
struct Age <: AggregationType end
=#

"""
    ContactMatrix{T <: Number}

Interface for epidemiologic contact matrices. Contact Matrices are important for simulation models of infectious diseases, as they contain information about contact behavior of individuals inside a population.
Contact matrices are symmetric matrices that show the aggregated number of contacts of individuals. The aggregation of ContactMatrix in GEMS is "by age". By providing `interval_steps` = 1, the matrix isn't aggregated and represents contacts between two ages.

# Fields
- `data::Matrix{T}`: Raw data of the contact matrix. Each cell has to represent an age group with the same step size as `interval_steps`
- `interval_steps::Int64`: Steps size of each age group
- `aggregation_bound::Int64`: Maximum age up to which the contact matrix is aggregated. This is often used if the last age group is smaller than `interval_steps`. This parameter is optional.
- `_size::Int64`: Internal attribute. Defines the size of one matrix dimension.

# Example
In this example, we create a 3x3 matrix where each column/row represents an age group of 10 but the last age group only goes until 26 (these numbers are made up!), so we cap it at 20 (see "[0-10), [10-20), 20+").

Here [1 4 7] represent age group [0-10), [2 5 8] age group [10-20) and [3 6 9] age group 20+.

```jldoctest
julia> matrix = [1 2 3; 4 5 6; 7 8 9]
3×3 Matrix{Int64}:
 1  2  3
 4  5  6
 7  8  9

julia> ContactMatrix{Int64}(matrix, 10, 20)
ContactMatrix{Int64}([1 2 3; 4 5 6; 7 8 9], 10, 20, 3)

``` 
"""
struct ContactMatrix{T <: Number}

    data::Matrix{T}
    interval_steps::Int64 
    aggregation_bound::Union{Int64, Nothing}
    _size::Int64

    @doc """
        ContactMatrix{T}(data::Matrix{T}, interval_steps::Int64, aggregation_bound::Union{Int64, Nothing}) where T <: Number

    Create a ContactMatrix with `interval_steps` and `aggregation_bound`. `_size` will be derived from `data`.
    """
    function ContactMatrix{T}(data::Matrix{T}, interval_steps::Int64, aggregation_bound::Union{Int64, Nothing}) where T <: Number
        if (length(data[:,1]) != length(data[1,:])) 
            throw(ArgumentError("Matrix dimensions have to be identical"))
        end

        if (interval_steps < 1)
            throw(ArgumentError("Interval steps have to be at least 1 or greater!"))
        end

        _size = length(data[:,1])

        if (!isnothing(aggregation_bound))
            if (aggregation_bound <= 1)
                throw(ArgumentError("Aggregation bound has to be at least 2 or greater!"))
            end
        
            if (aggregation_bound < interval_steps)
                throw(ArgumentError("Aggregation bound has to be greater or equal to interval steps!"))
            end
        
            if ((aggregation_bound % interval_steps) != 0)
                throw(ArgumentError("Interval steps have to be a multiple of aggregation bound!"))
            end

            if (aggregation_bound > _size * interval_steps)
                throw(ArgumentError("Matrix size doesn't match the specified aggregation bound!"))
            end
        end

        return new{T}(data, interval_steps, aggregation_bound, _size)
    end

    @doc """
        ContactMatrix{T}(data::Matrix{T}, interval_steps::Int64) where T <: Number

    Create a ContactMatrix with `interval_steps`. `_size` will be derived from `data`.
    """
    function ContactMatrix{T}(data::Matrix{T}, interval_steps::Int64) where T <: Number
        return ContactMatrix{T}(data, interval_steps, nothing)
    end
end
