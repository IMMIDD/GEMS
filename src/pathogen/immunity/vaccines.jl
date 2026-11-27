###
### VACCINES (TYPE DEFINITION & BASIC FUNCTIONALITY)
###
export Vaccine, VaccineProtection
export id, name, waning, logger, target_pathogen_id, peak, severity_peak, buildup_duration

"""
    Vaccine

A type representing a vaccine.

# Fields
- `id::Int8`: Unique identifier of the vaccine
- `name::String`: Name of the vaccine
- `target_pathogen_id::Int8`: Identifier of the pathogen this vaccine targets
- `peak::Int8`: Immunity level (protection against infection, 0-100) a dose reaches after its buildup (default: 100)
- `severity_peak::Int8`: Protection against severe disease (0-100) a dose reaches, per exposure against unprotected
  hosts like published effectiveness against hospitalisation, so it includes the cases `peak` prevents; at least
  `peak` (default: `peak`)
- `buildup_duration::Union{Nothing, Int16}`: Ticks from a dose to its peak; `nothing` uses the pathogen's
  `vaccine_buildup_duration` (default: `nothing`)
- `logger::VaccinationLogger`. Deprecated: vaccinations are logged in `vaccinationlogger(sim)`; this logger only
  records doses from the deprecated `vaccinate!(individual, registry, vaccine, tick)`
"""
@with_kw mutable struct Vaccine
    id::Int8
    name::String
    target_pathogen_id::Int8          # pathogen this vaccine protects against
    peak::Int8 = Int8(100)
    severity_peak::Int8 = peak
    buildup_duration::Union{Nothing, Int16} = nothing

    logger::VaccinationLogger = VaccinationLogger()

    function Vaccine(id, name, target_pathogen_id, peak, severity_peak, buildup_duration, logger)
        0 <= peak <= 100 || throw(ArgumentError("peak must be in [0, 100] (got $peak)."))
        severity_peak <= 100 || throw(ArgumentError("severity_peak must be in [0, 100] (got $severity_peak)."))
        peak <= severity_peak || throw(ArgumentError("peak ($peak, protection against infection, default 100) must not exceed severity_peak ($severity_peak, protection against severe disease, default peak)."))
        isnothing(buildup_duration) || buildup_duration >= 0 ||
            throw(ArgumentError("buildup_duration must be non-negative or nothing (got $buildup_duration)."))
        return new(Int8(id), String(name), Int8(target_pathogen_id), Int8(peak), Int8(severity_peak),
            isnothing(buildup_duration) ? nothing : Int16(buildup_duration), logger)
    end
end

"""
    Vaccine(id, name, target_pathogen_id, logger)

Positional constructor with the default peaks and buildup.
"""
Vaccine(id, name, target_pathogen_id, logger::VaccinationLogger) =
    Vaccine(id, name, target_pathogen_id, 100, 100, nothing, logger)

### BASIC FUNCTIONALITY aka GETTER/SETTER
"""
    id(vaccine)

Returns the unique identifier of the vaccine.
"""
function id(vaccine::Vaccine)::Int8
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
    peak(vaccine)

Returns the immunity level (protection against infection) a dose reaches after its buildup.
"""
function peak(vaccine::Vaccine)::Int8
    return vaccine.peak
end

"""
    severity_peak(vaccine)

Returns the protection against severe disease a dose reaches after its buildup.
"""
function severity_peak(vaccine::Vaccine)::Int8
    return vaccine.severity_peak
end

"""
    buildup_duration(vaccine)

Returns the ticks from a dose to its peak, or `nothing` if the pathogen's `vaccine_buildup_duration` applies.
"""
function buildup_duration(vaccine::Vaccine)::Union{Nothing, Int16}
    return vaccine.buildup_duration
end


"""
    logger(vaccine)

Returns the `VaccinationLogger` attached to the vaccine. Deprecated: use `vaccinationlogger(sim)`.
"""
function logger(vaccine::Vaccine)::VaccinationLogger
    @warn "logger(vaccine) is deprecated; vaccinations are logged in vaccinationlogger(sim)." maxlog=1
    return vaccine.logger
end

# whether the vaccine sets a peak or buildup other than the defaults
_sets_protection(vaccine::Vaccine)::Bool =
    peak(vaccine) != 100 || severity_peak(vaccine) != peak(vaccine) || !isnothing(buildup_duration(vaccine))


###
### VACCINE PROTECTION
###

"""
    VaccineProtection

Peaks and buildup of a vaccine as the simulation stores them per vaccine id and pathogen.
A `buildup_duration` of -1 means the pathogen's `vaccine_buildup_duration`.
"""
struct VaccineProtection
    peak::Int8
    severity_peak::Int8
    buildup_duration::Int16

    function VaccineProtection(peak::Integer, severity_peak::Integer, buildup_duration::Integer)
        0 <= peak <= severity_peak <= 100 ||
            throw(ArgumentError("Vaccine peaks must satisfy 0 <= peak <= severity_peak <= 100 (got peak $peak, severity_peak $severity_peak)."))
        buildup_duration >= -1 || throw(ArgumentError("buildup_duration must be non-negative (got $buildup_duration)."))
        return new(Int8(peak), Int8(severity_peak), Int16(buildup_duration))
    end
end

"""
    VaccineProtection()

The protection of an unregistered vaccine id: full peaks and the pathogen's buildup.
"""
VaccineProtection() = VaccineProtection(100, 100, -1)

"""
    VaccineProtection(vaccine::Vaccine)

The protection `vaccine` gives, checking its current values.
"""
VaccineProtection(vaccine::Vaccine) =
    VaccineProtection(peak(vaccine), severity_peak(vaccine), something(buildup_duration(vaccine), -1))

