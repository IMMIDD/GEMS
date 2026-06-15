# simulations
SIMS_INSTANTIATED::Int64 = 0


# printing
PRINT_INFOS = true # flag to enable or disable outputs via the printinfo() function

# interventions
# compile-time switch for @debug logging in the process_measure functions. kept off so the
# logging machinery is fully elided on the intervention hot path. flip to true when debugging.
const INTERVENTION_DEBUG = false