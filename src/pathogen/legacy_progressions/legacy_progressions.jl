###
### LEGACY BACKWARDS-COMPATIBILITY LAYER
###
### Self-contained, removable compat shim for the pre-decoupling health model. Delete this folder and
### drop the include in GEMS.jl (plus the reroute/legacy hooks in simulation.jl) to remove it.
###

include(_basefolder() * "/src/pathogen/legacy_progressions/pc_symptomatic.jl")
include(_basefolder() * "/src/pathogen/legacy_progressions/pc_hospitalized.jl")
include(_basefolder() * "/src/pathogen/legacy_progressions/pc_legacy_critical.jl")
include(_basefolder() * "/src/pathogen/legacy_progressions/legacy_health_progression.jl")
include(_basefolder() * "/src/pathogen/legacy_progressions/legacy_config.jl")
