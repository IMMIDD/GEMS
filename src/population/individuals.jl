###
### AGENTS (TYPE DEFINITION & BASIC FUNCTIONALITY)
###

# EXPORTS
# types
export Individual, DiseaseFlags
# basic attributes
export age, id, education, occupation, sex
# behaviour
export mandate_compliance, social_factor
# settings
export setting_id, household_id, class_id, office_id, municipality_id
export is_working, is_student, has_municipality
# health status
export comorbidities, has_comorbidity
export is_infected, isinfected, infected
export is_infectious, isinfectious, infectious
export is_exposed, isexposed, exposed
export is_presymptomatic, ispresymptomatic, presymptomatic
export is_symptomatic, issymptomatic, symptomatic
export is_asymptomatic, isasymptomatic, asymptomatic
export is_severe, issevere, severe
export is_critical, iscritical, critical
export is_mild, ismild, mild
export is_hospitalized, ishospitalized, hospitalized
export is_icu, isicu, icu
export is_ventilated, isventilated, ventilated
export is_recovered, isrecovered, recovered
export is_dead, isdead, dead
export is_detected, isdetected, detected
export active_pathogens_mask
export number_of_infections
#quarantine
export quarantine_release_tick
export quarantine_tick
export quarantine_status, home_quarantine!, end_quarantine!
export is_quarantined, isquarantined, quarantined
export AutoExtension



###
### DISEASE FLAGS
###
"""
    DiseaseFlags

Bit-packed per-pathogen disease state of a host (`infected`/`infectious`/`symptomatic`/`severe`/
`critical`/`dead`). Read with the `is_*` accessors and combine with `|`. Stored on the
`Individual` and rebuilt each tick by `progress_disease!`.
"""
struct DiseaseFlags
    bits::UInt8
end

const FLAG_INFECTED = UInt8(1) << 0
const FLAG_INFECTIOUS = UInt8(1) << 1
const FLAG_SYMPTOMATIC = UInt8(1) << 2
const FLAG_SEVERE = UInt8(1) << 3
const FLAG_CRITICAL = UInt8(1) << 4
const FLAG_DEAD = UInt8(1) << 5

DiseaseFlags() = DiseaseFlags(UInt8(0))

is_infected(f::DiseaseFlags) = (f.bits & FLAG_INFECTED) != 0
is_infectious(f::DiseaseFlags) = (f.bits & FLAG_INFECTIOUS) != 0
is_symptomatic(f::DiseaseFlags) = (f.bits & FLAG_SYMPTOMATIC) != 0
is_severe(f::DiseaseFlags) = (f.bits & FLAG_SEVERE) != 0
is_critical(f::DiseaseFlags) = (f.bits & FLAG_CRITICAL) != 0
is_dead(f::DiseaseFlags) = (f.bits & FLAG_DEAD) != 0

# functional single-flag update (returns a new value)
@inline _set_flag(f::DiseaseFlags, mask::UInt8, val::Bool) = DiseaseFlags(val ? (f.bits | mask) : (f.bits & ~mask))

# union, used to fold an individual's active infections each tick
@inline Base.:|(a::DiseaseFlags, b::DiseaseFlags) = DiseaseFlags(a.bits | b.bits)

###
### INDIVIDUALS
###
"""
    Individual

A type to represent individuals that act as agents inside the simulation.

# Fields
- General
    - `id::Int32`: Unique identifier of the individual
    - `sex::Int8`: Sex (Female (1), Male(2), Diverse (3))
    - `age::Int8`: Age
    - `occupation::Int16`: Occupation class (i.e. manual labour, office job, etc...)
    - `education::Int8`: Education class (i.e. highest degree)

- Comorbidities
    - `comorbidities::UInt16`: Bitmask indicating prevalence of certain health conditions

- Behaviour
    - `social_factor::Float32`: Parameter for risk-willingness (-1 to 1)
    - `mandate_compliance::Float32`: Probability of complying to mandates (-1 to 1)

- Associated Settings
    - `household::Int32`: Reference to household id
    - `office::Int32`: Reference to office id
    - `schoolclass::Int32`: Reference to schoolclass id
    - `municipality::Int32`: Reference to municipality id

- Bookkeeping
    - `needs_immunity_update::Bool`: Flag for deferred immunity calculations
    - `number_of_infections::Int8`: Lifetime infection count
    - `disease_flags::UInt8`: Bitpacked disease-state flags (`infected`/`infectious`/`symptomatic`/`severe`/`critical`/`dead`), accessed via the `is_*`/`*!` accessors
    - `killing_pathogen_id::Int8`: Pathogen credited for the host death (set when death is scheduled, read by the death logger)

- Interventions
    - `detected_mask::UInt32`: Bitmask of pathogens for which an infection is detected
    - `quarantine_tick::Int16`: Start tick of quarantine
    - `quarantine_release_tick::Int16`: End tick of quarantine
    - `quarantine_status::Int8`: Status indicator (none, household, etc.)

- Host Health Timeline (precomputed by the `HealthProgression`; `hospitalized`/`icu`/`ventilated` derived on the fly)
    - `hospital_admission::Int16`: Tick of hospital admission
    - `hospital_discharge::Int16`: Tick of hospital discharge
    - `icu_admission::Int16`: Tick of ICU admission
    - `icu_discharge::Int16`: Tick of ICU discharge
    - `ventilation_admission::Int16`: Tick of ventilation admission
    - `ventilation_discharge::Int16`: Tick of ventilation discharge
    - `death::Int16`: Tick of host death

- Pathogen
    - `infection_cache::NTuple{N, InfectionState}`: Fixed-size cache of current infections
    - `infection_head::Int32`: Pointer to the first overflow node in the InfectionRegistry
    - `active_pathogens_mask::UInt32`: Bitmask of currently active pathogen types

- Immunity
    - `immunity_cache::NTuple{N, ImmunityState}`: Fixed-size cache of pathogen immunities
    - `immunity_head::Int32`: Pointer to the first overflow node in the ImmunityRegistry

- Extensions
    - `extensions::Any`: Optional container for dynamically added per-individual attributes (`nothing` when unused)
"""
@with_kw_noshow mutable struct Individual
    # GENERAL
    id::Int32                                       # off 0,   4B,  line 0
    sex::Int8                                       # off 4,   1B,  line 0
    age::Int8                                       # off 5,   1B,  line 0
    occupation::Int16 = DEFAULT_SETTING_ID          # off 6,   2B,  line 0
    education::Int8 = DEFAULT_SETTING_ID            # off 8,   1B,  line 0

    # COMORBIDITIES
    comorbidities::UInt16 = 0                       # off 10,  2B,  line 0

    # BEHAVIOR
    social_factor::Float32 = 0                      # off 12,  4B,  line 0
    mandate_compliance::Float32 = 0                 # off 16,  4B,  line 0

    # ASSIGNED SETTINGS
    household::Int32 = DEFAULT_SETTING_ID           # off 20,  4B,  line 0
    office::Int32 = DEFAULT_SETTING_ID              # off 24,  4B,  line 0
    schoolclass::Int32 = DEFAULT_SETTING_ID         # off 28,  4B,  line 0
    municipality::Int32 = DEFAULT_SETTING_ID        # off 32,  4B,  line 0

    # BOOKKEEPING
    needs_immunity_update::Bool = false             # off 36,  1B,  line 0
    number_of_infections::Int8 = 0                  # off 37,  1B,  line 0
    disease_flags::DiseaseFlags = DiseaseFlags()    # off 38,  1B,  line 0
    killing_pathogen_id::Int8 = DEFAULT_PATHOGEN_ID # off 39,  1B,  line 0

    # INTERVENTIONS
    detected_mask::UInt32 = 0                       # off 40,  4B,  line 0
    quarantine_tick::Int16 = DEFAULT_TICK           # off 44,  2B,  line 0
    quarantine_release_tick::Int16 = DEFAULT_TICK   # off 46,  2B,  line 0
    quarantine_status::Int8 = QUARANTINE_STATE_NO_QUARANTINE # off 48, 1B, line 0

    # HOST HEALTH TIMELINE
    hospital_admission::Int16 = DEFAULT_TICK        # off 50,  2B,  line 0
    hospital_discharge::Int16 = DEFAULT_TICK        # off 52,  2B,  line 0
    icu_admission::Int16 = DEFAULT_TICK             # off 54,  2B,  line 0
    icu_discharge::Int16 = DEFAULT_TICK             # off 56,  2B,  line 0
    ventilation_admission::Int16 = DEFAULT_TICK     # off 58,  2B,  line 0
    ventilation_discharge::Int16 = DEFAULT_TICK     # off 60,  2B,  line 0
    death::Int16 = DEFAULT_TICK                     # off 62,  2B,  line 0

    # PATHOGEN
    infection_cache::NTuple{INFECTIONS_CACHE_SIZE, InfectionState} =
        ntuple(_ -> InfectionState(), INFECTIONS_CACHE_SIZE)  # off 64,  28B, line 1
    infection_head::Int32 = 0                       # off 92,  4B,  line 1
    active_pathogens_mask::UInt32 = 0               # off 96,  4B,  line 1

    # IMMUNITY
    immunity_cache::NTuple{IMMUNITY_CACHE_SIZE, ImmunityState} =
        ntuple(_ -> ImmunityState(), IMMUNITY_CACHE_SIZE)     # off 100, 12B, line 1
    immunity_head::Int32 = 0                        # off 112, 4B,  line 1

    # EXTENSIONS
    extensions::Any = nothing                       # off 120, 8B,  line 1
end

# CONSTRUCTOR
"""
    Individual(properties::Dict)

Create an individual with the provided properties. Properties must *have at least* keys
`id`, `sex`, `age`.
"""
function Individual(properties::Dict)::Individual
    ind = Individual(id=properties["id"], sex=properties["sex"], age=properties["age"])

    # set every field that is provided by properties
    for field in individual_base_fieldnames()
        if haskey(properties, String(field))
            setproperty!(ind, field, properties[String(field)])
        end
    end

    return ind
end


"""
    Individual(properties::DataFrameRow)

Create an individual with the provided properties. Properties must *have at least* keys
`id`, `sex`, `age`.
"""
function Individual(properties::DataFrameRow)::Individual
    return Individual(; (Symbol(k) => v for (k, v) in pairs(properties))...)
end


### GETTER OF BASIC ATTRIBUTES ###

"""
    id(individual::Individual)

Return the unique identifier of the individual.
"""
function id(individual::Individual)::Int32
    return individual.id
end

"""
    sex(individual::Individual)

Return an individual's sex.
"""
function sex(individual::Individual)::Int8
    return individual.sex
end

"""
    age(individual::Individual)

Return an individual's age.
"""
function age(individual::Individual)::Int8
    return individual.age
end

"""
    education(individual::Individual)

Return an individual's education class
"""
function education(individual::Individual)::Int8
    return individual.education
end

"""
    occupation(individual::Individual)

Returns an individual's occupation class.
"""
function occupation(individual::Individual)::Int16
    return individual.occupation
end

### BEHAVIOUR ###

"""
    social_factor(individual::Individual)

Returns an individual's `social_factor` value.
"""
function social_factor(individual::Individual)::Float32
    return individual.social_factor
end

"""
    social_factor!(individual::Individual, val::Float32)

Overwrites the individual's `social_factor` attribute.
"""
function social_factor!(individual::Individual, val::Float32)
    individual.social_factor = val
end

social_factor!(individual::Individual, val::Float64) = social_factor!(individual, Float32(val))

"""
    mandate_compliance(individual::Individual)

Return an individual's `mandate_compliance` value.
"""
function mandate_compliance(individual::Individual)::Float32
    return individual.mandate_compliance
end

"""
    mandate_compliance!(individual::Individual, val::Float32)

Overwrites the individual's `mandate_compliance` attribute.
"""
function mandate_compliance!(individual::Individual, val::Float32)
    individual.mandate_compliance = val
end

mandate_compliance!(individual::Individual, val::Float64) = mandate_compliance!(individual, Float32(val))

### SETTINGS ###

"""
    household_id(individual::Individual)

Returns an individual's associated household's ID.
"""
function household_id(individual::Individual)::Int32
    return individual.household
end

"""
    office_id(individual::Individual)

Returns an individual's associated office's ID.
"""
function office_id(individual::Individual)::Int32
    return individual.office
end

"""
    class_id(individual::Individual)

Returns an individual's associated class's ID.
"""
function class_id(individual::Individual)::Int32
    return individual.schoolclass
end

"""
    municipality_id(individual::Individual)

Returns an individual's associated municipalities ID.
"""
function municipality_id(individual::Individual)::Int32
    return individual.municipality
end


"""
    is_working(individual::Individual)

Returns `true` if individual is assigned to an  instance of type `Office`.
"""
is_working(individual::Individual) = office_id(individual) != DEFAULT_SETTING_ID

"""
    is_student(individual::Individual)

Returns `true` if individual is assigned to an  instance of type `SchoolClass`.
"""
is_student(individual::Individual) = class_id(individual) != DEFAULT_SETTING_ID

"""
    has_municipality(individual::Individual)

Returns `true` if individual is assigned to an instance of type `Municipality`.
"""
has_municipality(individual::Individual) = municipality_id(individual) != DEFAULT_SETTING_ID


### HEALTH STATUS ###

"""
    comorbidities(individual::Individual)

Returns an individual's comorbidities.
"""
function comorbidities(individual::Individual)::UInt16
    return individual.comorbidities
end

"""
    has_comorbidity(individual::Individual, n::Int16)

Returns `true` if the individual has the `n`-th comorbidity flag set.
`n` is 1-indexed and should be between 1 and 16.
"""
function has_comorbidity(individual::Individual, n::Int16)
    # Ensure n is in the valid range for a UInt16
    if !(1 <= n <= 16)
        throw(ArgumentError("Comorbidity index must be between 1 and 16."))
    end
    
    # Shift a bit to the (n-1)th position and apply bitwise AND
    return (individual.comorbidities & (UInt16(1) << (n - 1))) != 0
end

"""
    is_infected(individual::Individual)
    isinfected(individual::Individual)
    infected(individual::Individual)

Returns the `infected` flag of the individual.
"""
is_infected(individual::Individual) = is_infected(individual.disease_flags)
isinfected(individual::Individual) = is_infected(individual)
infected(individual::Individual) = is_infected(individual)

"""
    infected!(individual::Individual, infected::Bool)

Sets the `infected` flag of the individual.
"""
infected!(individual::Individual, infected::Bool) = (individual.disease_flags = _set_flag(individual.disease_flags, FLAG_INFECTED, infected))

"""
    infected!(individual::Individual, pathogen_id::Int8, val::Bool)

Sets or clears the active bit for `pathogen_id` in the individual's `active_pathogens_mask`.
Mirrors `detected!(individual, pathogen_id, val)`; read back with `infected(individual, pathogen_id)`.
"""
@inline function infected!(individual::Individual, pathogen_id::Int8, val::Bool)
    if val
        individual.active_pathogens_mask |= (UInt32(1) << (pathogen_id - 1))
    else
        individual.active_pathogens_mask &= ~(UInt32(1) << (pathogen_id - 1))
    end
end

"""
    is_infectious(individual::Individual)
    isinfectious(individual::Individual)
    infectious(individual::Individual)

Returns `true` iff the individual currently has nonzero shedding for at least one of their active pathogens.
"""
is_infectious(individual::Individual) = is_infectious(individual.disease_flags)
isinfectious(individual::Individual) = is_infectious(individual)
infectious(individual::Individual) = is_infectious(individual)

"""
    infectious!(individual::Individual, infectious::Bool)

Sets the `infectious` flag of the individual.
"""
infectious!(individual::Individual, infectious::Bool) = (individual.disease_flags = _set_flag(individual.disease_flags, FLAG_INFECTIOUS, infectious))

"""
    is_exposed(individual::Individual)
    isexposed(individual::Individual)
    exposed(individual::Individual)

Returns `true` if the individual is exposed at the current tick.
Exposed means infected but not yet infectious.
"""
is_exposed(individual::Individual) = is_infected(individual) && !is_infectious(individual)
isexposed(individual::Individual) = is_exposed(individual)
exposed(individual::Individual) = is_exposed(individual)



"""
    is_symptomatic(individual::Individual)
    issymptomatic(individual::Individual)
    symptomatic(individual::Individual)

Returns the `symptomatic` flag of the individual.
"""
is_symptomatic(individual::Individual) = is_symptomatic(individual.disease_flags)
issymptomatic(individual::Individual) = is_symptomatic(individual)
symptomatic(individual::Individual) = is_symptomatic(individual)

"""
    symptomatic!(individual::Individual, symptomatic::Bool)

Sets the `symptomatic` flag of the individual.
"""
symptomatic!(individual::Individual, symptomatic::Bool) = (individual.disease_flags = _set_flag(individual.disease_flags, FLAG_SYMPTOMATIC, symptomatic))

"""
    is_severe(individual::Individual)
    issevere(individual::Individual)
    severe(individual::Individual)

Returns the `severe` flag of the individual.
"""
is_severe(individual::Individual) = is_severe(individual.disease_flags)
issevere(individual::Individual) = is_severe(individual)
severe(individual::Individual) = is_severe(individual)

"""
    severe!(individual::Individual, severe::Bool)

Sets the `severe` flag of the individual.
"""
severe!(individual::Individual, severe::Bool) = (individual.disease_flags = _set_flag(individual.disease_flags, FLAG_SEVERE, severe))

"""
    is_critical(individual::Individual)
    iscritical(individual::Individual)
    critical(individual::Individual)

Returns the `critical` flag of the individual.
"""
is_critical(individual::Individual) = is_critical(individual.disease_flags)
iscritical(individual::Individual) = is_critical(individual)
critical(individual::Individual) = is_critical(individual)

"""
    critical!(individual::Individual, critical::Bool)

Sets the `critical` flag of the individual.
"""
critical!(individual::Individual, critical::Bool) = (individual.disease_flags = _set_flag(individual.disease_flags, FLAG_CRITICAL, critical))

"""
    is_hospitalized(individual::Individual, t::Int16)
    ishospitalized(individual::Individual, t::Int16)
    hospitalized(individual::Individual, t::Int16)

Returns `true` if the individual is in hospital at tick `t`, derived from the precomputed host timeline.
"""
is_hospitalized(individual::Individual, t::Int16) = 0 <= individual.hospital_admission <= t < individual.hospital_discharge
ishospitalized(individual::Individual, t::Int16) = is_hospitalized(individual, t)
hospitalized(individual::Individual, t::Int16) = is_hospitalized(individual, t)

"""
    is_icu(individual::Individual, t::Int16)
    isicu(individual::Individual, t::Int16)
    icu(individual::Individual, t::Int16)

Returns `true` if the individual is in the ICU at tick `t`, derived from the precomputed host timeline.
"""
is_icu(individual::Individual, t::Int16) = 0 <= individual.icu_admission <= t < individual.icu_discharge
isicu(individual::Individual, t::Int16) = is_icu(individual, t)
icu(individual::Individual, t::Int16) = is_icu(individual, t)

"""
    is_ventilated(individual::Individual, t::Int16)
    isventilated(individual::Individual, t::Int16)
    ventilated(individual::Individual, t::Int16)

Returns `true` if the individual is on a ventilator at tick `t`, derived from the precomputed host timeline.
"""
is_ventilated(individual::Individual, t::Int16) = 0 <= individual.ventilation_admission <= t < individual.ventilation_discharge
isventilated(individual::Individual, t::Int16) = is_ventilated(individual, t)
ventilated(individual::Individual, t::Int16) = is_ventilated(individual, t)

"""
    is_dead(individual::Individual)
    isdead(individual::Individual)
    dead(individual::Individual)

Returns `true` if the individual is dead.
"""
is_dead(individual::Individual) = is_dead(individual.disease_flags)
isdead(individual::Individual) = is_dead(individual)
dead(individual::Individual) = is_dead(individual)


"""
    dead!(individual::Individual, dead::Bool)

Set the `dead` flag of the individual.
"""
dead!(individual::Individual, dead::Bool) = (individual.disease_flags = _set_flag(individual.disease_flags, FLAG_DEAD, dead))

"""
    is_detected(individual::Individual)
 
Returns `true` if the individual has been detected for any currently active pathogen.
"""
is_detected(individual::Individual) = individual.detected_mask != 0
isdetected(individual::Individual) = is_detected(individual)
detected(individual::Individual) = is_detected(individual)
 
"""
    is_detected(individual::Individual, pathogen_id::Int8)
 
Returns `true` if the individual has been detected for the specific `pathogen_id`.
"""
is_detected(individual::Individual, pathogen_id::Int8) = (individual.detected_mask & (UInt32(1) << (pathogen_id - 1))) != 0
isdetected(individual::Individual, pathogen_id::Int8) = is_detected(individual, pathogen_id)
detected(individual::Individual, pathogen_id::Int8) = is_detected(individual, pathogen_id) 
"""
    detected!(individual::Individual, pathogen_id::Int8, val::Bool)
 
Sets or clears the detected bit for `pathogen_id` on the individual.
"""
@inline function detected!(individual::Individual, pathogen_id::Int8, val::Bool)
    if val
        individual.detected_mask |= (UInt32(1) << (pathogen_id - 1))
    else
        individual.detected_mask &= ~(UInt32(1) << (pathogen_id - 1))
    end
end

"""
    detected!(individual::Individual, val::Bool)

Set or clear the detected flag for all pathogens (sets all bits of `detected_mask`).
"""
function detected!(individual::Individual, val::Bool)
    individual.detected_mask = val ? ~UInt32(0) : UInt32(0)
end


# ### PATHOGEN ATTRIBUTES ###

"""
    active_pathogens_mask(individual::Individual)::UInt32

Returns the individual's `active_pathogens_mask`: a bitmask where bit `pathogen_id - 1` is set
for every pathogen the individual is currently actively infected with (cache and overflow
alike). Use `infected(individual, pathogen_id)` to test a single pathogen without decoding.
"""
@inline active_pathogens_mask(ind::Individual)::UInt32 = ind.active_pathogens_mask

"""
    infected(individual::Individual, pathogen_id::Int8)::Bool

Returns `true` if the individual currently has an active infection with the given
`pathogen_id`. Uses the per-individual `active_pathogens_mask`.

This is the preferred overload for use in `IStrategy` conditions, as the condition
function only receives an `Individual`:

```julia
IStrategy("isolate-pathogen-a", sim, condition = ind -> infected(ind, Int8(1)))
```
"""
@inline function infected(individual::Individual, pathogen_id::Int8)::Bool
    return (individual.active_pathogens_mask & (UInt32(1) << (pathogen_id - 1))) != 0
end



"""
    number_of_infections(individual::Individual)

Returns an individual's number of infections (currently infected).
"""
function number_of_infections(individual::Individual)::Int8
    return individual.number_of_infections
end

"""
    inc_number_of_infections!(individual::Individual)

Increments an individual's number of infections by one.
"""
function inc_number_of_infections!(individual::Individual)
    individual.number_of_infections += 1
end


### QUARANTINE STATUS ###


"""
    quarantine_status(individual::Individual)

Returns an individuals quarantine status.
"""
function quarantine_status(individual::Individual)::Int8
    return individual.quarantine_status
end

"""
    quarantine_tick(individual::Individual)

Returns an individual's quarantine tick.
"""
function quarantine_tick(individual::Individual)::Int16
    return individual.quarantine_tick
end

"""
    quarantine_tick!(individual::Individual, tick::Int16)

Sets an individual's quarantine tick.
"""
function quarantine_tick!(individual::Individual, tick::Int16)
    individual.quarantine_tick = tick
end

"""
    quarantine_release_tick(individual::Individual)

Returns an individual's quarantine release tick.
"""
function quarantine_release_tick(individual::Individual)::Int16
    return individual.quarantine_release_tick
end

"""
    quarantine_release_tick!(individual::Individual, tick::Int16)

Sets an individual's quarantine release tick.
"""
function quarantine_release_tick!(individual::Individual, tick::Int16)
    individual.quarantine_release_tick = tick
end

"""
    is_quarantined(individual::Individual)
    isquarantined(individual::Individual)
    quarantined(individual::Individual)

Returns wether the individual is in quarantine or not.
"""
is_quarantined(individual::Individual) = individual.quarantine_status != QUARANTINE_STATE_NO_QUARANTINE
isquarantined(individual::Individual) = is_quarantined(individual)
quarantined(individual::Individual) = is_quarantined(individual)

"""
    is_quarantined(individual::Individual, tick::Int16)
    isquarantined(individual::Individual, tick::Int16)
    quarantined(individual::Individual, tick::Int16)

Returns wether the individual is in quarantine at tick `tick`.
"""
is_quarantined(individual::Individual, tick::Int16) = quarantine_tick(individual) <= tick < quarantine_release_tick(individual)
isquarantined(individual::Individual, tick::Int16) = is_quarantined(individual, tick)
quarantined(individual::Individual, tick::Int16) = is_quarantined(individual, tick)


"""
    quarantined!(individual::Individual, quarantined::Bool)

Sets an individual's quarantine status to either home quarantine or no quarantine.
"""
function quarantined!(individual::Individual, quarantined::Bool)
    individual.quarantine_status = quarantined ? QUARANTINE_STATE_HOUSEHOLD_QUARANTINE : QUARANTINE_STATE_NO_QUARANTINE
end

"""
    home_quarantine!(individual::Individual)

Quarantines an individual in their household.
"""
function home_quarantine!(individual::Individual)
    individual.quarantine_status = QUARANTINE_STATE_HOUSEHOLD_QUARANTINE
end

"""
    end_quarantine!(individual::Individual)

Ends an individuals quarantine.
"""
function end_quarantine!(individual::Individual)
    @debug "Individual $(id(individual)) ending quarantine"
    individual.quarantine_status = QUARANTINE_STATE_NO_QUARANTINE
end


### EXTENSIONS ###

"""
    AutoExtension{NT <: NamedTuple}

Mutable wrapper around a NamedTuple used for auto-detected extension fields
from CSV/DataFrame extra columns. Stored in an `Individual`'s boxed `extensions`
field, it allows transparent field access and mutation without requiring a
user-defined struct.
"""
mutable struct AutoExtension{NT <: NamedTuple}
    data::NT
end

"""
    individual_base_fieldnames()

Return the field names of `Individual` excluding `:extensions`.
Used by constructors that iterate over fields (e.g. from a `Dict` or `DataFrame`) so that
they don't accidentally try to populate the extension slot from a column that doesn't exist.
"""
individual_base_fieldnames() = filter(!=(:extensions), fieldnames(Individual))

"""
    assert_no_core_collision(names)

Throw an error if any of `names` of extension fields collides with a core `Individual` field name.
"""
function assert_no_core_collision(names)
    clash = intersect(Symbol.(collect(names)), individual_base_fieldnames())
    isempty(clash) || error(
        "ind_extension field(s) $(collect(clash)) collide with core Individual fields. " *
        "Extension fields must use distinct names. Rename the offending column(s).")
end

"""
    Base.getproperty(ind::Individual, name::Symbol)

Transparent read access for both core and extension fields. Core fields are read directly;
any other name is forwarded to the boxed `extensions` value (its fields, or — for an
`AutoExtension` — the wrapped NamedTuple's fields).

For a literal field name (e.g. `ind.infected`) the `hasfield` check is constant-folded and the
call inlines to a single `getfield`, so core-field access keeps the same performance as the
default. Only dynamic names (e.g. the `Dict`/`DataFrame` constructor loop) pay the runtime branch.
Extension-field reads are intentionally type-unstable (the `extensions` slot is `Any`).
"""
@inline function Base.getproperty(ind::Individual, name::Symbol)
    hasfield(Individual, name) && return getfield(ind, name)
    ext = getfield(ind, :extensions)
    return ext isa AutoExtension ? getfield(getfield(ext, :data), name) : getfield(ext, name)
end

"""
    Base.setproperty!(ind::Individual, name::Symbol, val)

Transparent write access for both core and extension fields, with the same type-coercion
behaviour as Julia's default `setproperty!` (i.e. `convert(fieldtype(...), val)` before
`setfield!`). Non-core names are forwarded to the boxed `extensions` value; for an
`AutoExtension` the wrapped NamedTuple is replaced via `merge`.
"""
@inline function Base.setproperty!(ind::Individual, name::Symbol, val)
    if hasfield(Individual, name)
        return setfield!(ind, name, convert(fieldtype(Individual, name), val))
    end
    ext = getfield(ind, :extensions)
    if ext isa AutoExtension
        nt = getfield(ext, :data)
        return setfield!(ext, :data,
            merge(nt, NamedTuple{(name,)}((convert(fieldtype(typeof(nt), name), val),))))
    else
        return setfield!(ext, name, convert(fieldtype(typeof(ext), name), val))
    end
end


### PRINTING ###

function Base.show(io::IO, individual::Individual)
    sex_str = individual.sex == 1 ? "female" : individual.sex == 2 ? "male" : "diverse"

    attributes = [
        "ID" => individual.id,
        "Age" => individual.age,
        "Sex" => sex_str,
        "Education" => individual.education != DEFAULT_SETTING_ID ? individual.education : "n/a",
        "Occupation" => individual.occupation != DEFAULT_SETTING_ID ? individual.occupation : "n/a",
        "Social Factor" => individual.social_factor,
        "Mandate Compliance" => individual.mandate_compliance,
        
        "Is Infected" => is_infected(individual),
        "Is Infectious" => is_infectious(individual),
        "Is Symptomatic" => is_symptomatic(individual),
        "Is Severe" => is_severe(individual),
        "Is Critical" => is_critical(individual),
        "Hospital Admission" => individual.hospital_admission >= 0 ? individual.hospital_admission : "n/a",
        "ICU Admission" => individual.icu_admission >= 0 ? individual.icu_admission : "n/a",
        "Ventilation Admission" => individual.ventilation_admission >= 0 ? individual.ventilation_admission : "n/a",
        "Is Dead" => is_dead(individual),

        "Household ID" => individual.household,
        "Office ID" => individual.office != DEFAULT_SETTING_ID ? individual.office : "n/a",
        "School Class ID" => individual.schoolclass != DEFAULT_SETTING_ID ? individual.schoolclass : "n/a",
        "Municipality ID" => individual.municipality != DEFAULT_SETTING_ID ? individual.municipality : "n/a",

        "Number of Infections" => individual.number_of_infections,
        
        "Quarantine Status" => individual.quarantine_status,
        "Quarantine Tick" => individual.quarantine_tick != DEFAULT_TICK ? individual.quarantine_tick : "n/a",
        "Quarantine Release Tick" => individual.quarantine_release_tick != DEFAULT_TICK ? individual.quarantine_release_tick : "n/a"
    ]

    # Append any extension fields
    ext = individual.extensions
    if ext !== nothing
        ext_fields = ext isa AutoExtension ? fieldnames(fieldtype(typeof(ext), :data)) : fieldnames(typeof(ext))
        for f in ext_fields
            push!(attributes, string(f) => getproperty(individual, f))
        end
    end

    max_label_length = maximum(length ∘ first, attributes)

    println(io, "Individual")
    for (label, value) in attributes
        println(io, "  ", rpad(label * ":", max_label_length + 3), value)
    end
end

function Base.show(io::IO, #=::MIME"text/plain",=# individuals::Vector{Individual})
    n = length(individuals)
    println(io, "$(n)-element Vector{Individual}:")
    
    if n <= 50
        for individual in individuals
            sex_str = individual.sex == 1 ? "female" : individual.sex == 2 ? "male" : "diverse"
            println(io, "  Individual[ID: $(individual.id), $sex_str, $(individual.age)y]")
        end
    else
        for individual in individuals[1:20]
            sex_str = individual.sex == 1 ? "female" : individual.sex == 2 ? "male" : "diverse"
            println(io, "  Individual[ID: $(individual.id), $sex_str, $(individual.age)y]")
        end
        
        println(io, "  ⋮")
        
        for individual in individuals[end-19:end]
            sex_str = individual.sex == 1 ? "female" : individual.sex == 2 ? "male" : "diverse"
            println(io, "  Individual[ID: $(individual.id), $sex_str, $(individual.age)y]")
        end
    end
end