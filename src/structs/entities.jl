### EXPORTS
export Entity

### ENTITIES
"Supertype for all simulated objects"
abstract type Entity end

# CONCRETE SUBTYPES
include("entities/agents.jl")
include("entities/populations.jl")
include("entities/settings.jl")
include("entities/settingscontainers.jl")