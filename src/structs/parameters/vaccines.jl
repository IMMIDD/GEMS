###
### VACCINES (TYPE DEFINITION & BASIC FUNCTIONALITY)
###
export Vaccine
export id, name, waning
export parameters

"""
    Vaccine

A type representing a vaccine.

# Fields
- `id::Int8`: Unique identifier of the vaccine
- `name::String`: Name of the vaccine
- `target_pathogen_id::Int8`: Identifier of the pathogen this vaccine targets
- `logger::VaccinationLogger`. Logger to log vaccinations with the vaccine
"""
@with_kw mutable struct Vaccine
    id::Int8
    name::String
    target_pathogen_id::Int8          # pathogen this vaccine protects against

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
    target_pathogen_id(vaccine)

Returns the identifier of the pathogen this vaccine targets.
"""
function target_pathogen_id(vaccine::Vaccine)::Int8
    return vaccine.target_pathogen_id
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
    )
end