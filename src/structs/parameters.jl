export Parameter

### PARAMETER
"Supertype for all simulation parameters"
abstract type Parameter end

# CONCRETE SUBTYPES
include("parameters/age_strat.jl")
include("parameters/transmission_structs.jl")
include("parameters/pathogens.jl")
include("parameters/waning.jl")
include("parameters/vaccines.jl")
include("parameters/ags.jl")
include("parameters/contact_sampling_method_structs.jl")
include("parameters/contact_matrix.jl")