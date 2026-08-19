export start_conditions
export MultiStartCondition
export ALL_PATHOGENS

"""
    MultiStartCondition <: StartCondition

A composite `StartCondition` that wraps multiple individual start conditions,
one per pathogen. Each sub-condition is initialized in order.
"""
struct MultiStartCondition <: StartCondition
    conditions::Vector{StartCondition}

    function MultiStartCondition(conditions::Vector{<:StartCondition})
        isempty(conditions) && throw(ArgumentError("At least one StartCondition must be provided."))
        return new(conditions)
    end
end

function initialize!(simulation::Simulation, condition::MultiStartCondition; kwargs...)
    for sc in condition.conditions
        initialize!(simulation, sc; kwargs...)
    end
end


Base.show(io::IO, c::MultiStartCondition) = write(io, "MultiStartCondition($(join(c.conditions, ", ")))")


###
### PATHOGEN RESOLUTION
###

# rebuilds a condition with a different pathogen name, which is how an ALL_PATHOGENS
# condition becomes one copy per pathogen. All condition constructors are keyword-based
# with kwargs named after their fields
_with_pathogen(c::T, name::String) where {T<:StartCondition} =
    T(; (f => (f === :pathogen ? name : getfield(c, f)) for f in fieldnames(T))...)

"""
    _expand_pathogens(condition, pathogens::Tuple)

Resolves a condition's pathogen selection against the simulation's pathogens: `ALL_PATHOGENS`
becomes one condition per pathogen, a name is validated, and an empty name is rejected unless
there is exactly one pathogen.
"""
function _expand_pathogens(c::StartCondition, pathogens::Tuple)
    isempty(pathogens) && return c # nothing to resolve against
    if isempty(c.pathogen)
        length(pathogens) > 1 && throw(ArgumentError("$(nameof(typeof(c))) does not name a pathogen, but the simulation has $(length(pathogens)) ($(join((p.name for p in pathogens), ", "))). Name one, or use pathogen = \"$ALL_PATHOGENS\" to seed all of them."))
        return c
    end
    if c.pathogen != ALL_PATHOGENS
        any(p -> p.name == c.pathogen, pathogens) || throw(ArgumentError("$(nameof(typeof(c))) names pathogen '$(c.pathogen)', which the simulation does not have ($(join((p.name for p in pathogens), ", ")))."))
        return c
    end
    length(pathogens) == 1 && return _with_pathogen(c, first(pathogens).name)
    return MultiStartCondition([_with_pathogen(c, p.name) for p in pathogens])
end

_expand_pathogens(c::MultiStartCondition, pathogens::Tuple) =
    MultiStartCondition([_expand_pathogens(sc, pathogens) for sc in c.conditions])


###
### INCLUDE START CONDITIONS
###

# The src/simulation/initialization/start_conditions folder contains a dedicated file
# for each start condition. Files starting with "sc_" are
# StartCondition structs.
# If you want to set up a new start condition, simply add a file to the folder and
# make sure to define the new struct and the required initialize!()-function.
# The struct needs a pathogen::String field and a keyword constructor named after its fields
# so that _with_pathogen() can rebuild it.

# include all Julia files from the "start_conditions"-folder
dir = _basefolder() * "/src/simulation/initialization/start_conditions"

include.(
    filter(
        contains(r".jl$"),
        readdir(dir; join=true)
    )
)

"""
    start_conditions()::Vector{DataType}

Returns a vector of all available StartCondition subtypes.
"""
start_conditions() = subtypes(StartCondition)