###
### VACCINES (TYPE DEFINITION & BASIC FUNCTIONALITY)
###
export Vaccine
export id, name, waning
export parameters

"""
    Vaccine <: Parameter

A type representing a vaccine.

# Fields
- `id::Int8`: Unique identifier of the vaccine
- `name::String`: Name of the vaccine
- `waning::AbstractWaningStruct`: Waning Struct to represent the time to full effectiveness
    and degrading efficacy
- `logger::VaccinationLogger`. Logger to log vaccinations with the vaccine
"""
@with_kw mutable struct Vaccine <: Parameter
    id::Int8
    name::String
    waning::AbstractWaning = DiscreteWaning(time_to_effectiveness = 7, duration =30)

    logger::VaccinationLogger = VaccinationLogger()
end

### BASIC FUNCTIONALITY aka GETTER/SETTER
"""
    id(vaccine)

Returns the unique identifier of the vaccine.
"""
function id(vaccine::Vaccine)::Int16
    return vaccine.id
end

"""
    name(vaccine)

Returns the name of the vaccine.
"""
function name(vaccine::Vaccine)::String
    return vaccine.name
end

"""
    waning(vaccine)

Returns the waning struct associated with the vaccine.
"""
function waning(vaccine::Vaccine)::AbstractWaning
    return vaccine.waning
end

"""
    logger(vaccine)

Returns the `VaccinationsLogger` attached to the vaccine.
"""
function logger(vaccine::Vaccine)::VaccinationLogger
    return vaccine.logger
end

"""
    parameters(v::Vaccine)::Dict

Returns a dictionary containing the parameters of the vaccine.
"""
function parameters(v::Vaccine)::Dict
    return Dict(
        "id" => v |> id,
        "name" => v |> name,
        "waning" => v |> waning
    )
end