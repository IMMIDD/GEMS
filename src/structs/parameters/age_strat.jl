###
### AGE STRATIFICATION & SYMPTOM CATEGORIES (TYPE DEFINITION & BASIC FUNCTIONALITY)
###
export AgeStratification
export DiseaseProgressionStrat

###
### ABSTRACT TYPES
###
abstract type AgeStratification end


###
### DISEASE PROGRESSION STRATIFICATION
###
"""
    DiseaseProgressionStrat <: AgeStratification
    
A wrapper type for an age stratification matrix regarding the disease progression.

# Fields
- `age_groups::Vector{String}`: A list of the age groups in order of the rows of the 
        stratification matrix. The first entry in `age_groups` belongs to the first row in
        the matrix.
- `disease_compartments::Vector{String}`: A list of the compartments/terminal states in
        the disease progression in order of the columns of the stratification matrix. First
        entry in `disease_compartments` belongs to the first column in the stratification
        matrix.
- `stratification_matrix::Vector{Vector{T}} where T <: Real`: The matrix that holds the
        probabilities for the age stratified disease progression.
        The entries of each row have to add up to 1.


"""
mutable struct DiseaseProgressionStrat <: AgeStratification
    age_groups::Vector{String}
    disease_compartments::Vector{DataType}
    stratification_matrix::Vector{Vector{T}} where T <: Real

    @doc """
        DiseaseProgressionStrat(dict)
    
    Constructs the Disease Progression Matrix from a Dictionary. `dict` has to provide the
    fields `"age_groups", "disease_compartments", "stratification_matrix"`. The shape of 
    the matrix has to adhere to the provided list and the stochastic property.
    """
    function DiseaseProgressionStrat(dict::Dict)
        matrix = dict["stratification_matrix"]

        rows = length(dict["age_groups"])
        columns = length(dict["disease_compartments"])

        # make sure that attributes match up in size and stochasticity
        if length(matrix)!=rows
            error("Provided age groups and the stratification matrix don't match in dimensions"*
                " as there are "*string(rows)*" age groups, but only "*string(length(matrix))*
                " rows in the stratification matrix."
            )
        end

        for i in range(1, length(matrix))
            if !isapprox(sum(matrix[i]), 1.0)
                error("Provided stratification matrix for disease progression is NOT "*
                    "stochastic! Sum of entries in row "*string(i)*" don't sum up to 1"*
                    ", but to "*string(sum(matrix[i]))*".")
            end
            if columns != length(matrix[i])
                error("Provided disease compartments and the stratification matrix don't match"*
                    " in dimensions as there are "*string(columns)*" age groups, but only "*
                    string(length(matrix[i]))*" columns in the stratification matrix in row "*
                    string(i)*"."
                )
            end
        end
        disease_compartments = [find_subtype(name, SymptomCategory) for name in dict["disease_compartments"]]
        return new(dict["age_groups"], disease_compartments, dict["stratification_matrix"])
    end
end

"""
    DiseaseProgressionStrat()

A constructor for a default Disease Progression, where every individual will only be assigned
to be asymptomatic. Mainly for testing purposes.
"""
function DiseaseProgressionStrat()::DiseaseProgressionStrat
    dict = Dict(
        "age_groups" =>  ["0+"],
        "disease_compartments" => ["Asymptomatic"],
        "stratification_matrix" => [[1]]
    )
    return DiseaseProgressionStrat(dict)
end


"""
    parameters(dps::DiseaseProgressionStrat)::Dict

Obtains a dictionary containing the parameters of the DiseaseProgressionStrat.
"""
function parameters(dps::DiseaseProgressionStrat)::Dict
    return Dict(
        "age_groups" =>  dps.age_groups,
        "disease_compartments" => dps.disease_compartments,
        "stratification_matrix" => dps.stratification_matrix
    )
end