export Parameter

### PARAMETER
"Supertype for all simulation parameters"
abstract type Parameter end

# CONCRETE SUBTYPES
include("parameters/transmission_structs.jl")
include("parameters/pathogens.jl")
include("parameters/vaccines.jl")
include("parameters/ags.jl")
include("parameters/contact_matrix.jl")
include("parameters/contact_sampling_method_structs.jl")