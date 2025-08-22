
###
### INCLUDE DISEASE PROGRESSION FUNCTIONS
###

# The src/methods/disease_progression folder contains a dedicated file
# for each disease progression function. Files starting with "dp_" are
# DiseaseProgression functions.
# If you want to set up a new disease progression function, simply add a file to the folder and
# make sure to define the function.

# include all Julia files from the "disease_progression"-folder
dir = basefolder() * "/src/methods/progression_categories"

include.(
    filter(
        contains(r".jl$"),
        readdir(dir; join=true)
    )
)


###
### INCLUDE PROGRESSION ASSIGNMENT FUNCTIONS
###

# The src/methods/progression_assignment folder contains a dedicated file
# for each progression assignment function. Files starting with "pa_" are
# ProgressionAssignment functions.
# If you want to set up a new progression assignment function, simply add a file to the folder and
# make sure to define the function.

# include all Julia files from the "progression_assignment"-folder
dir = basefolder() * "/src/methods/progression_assignments"

include.(
    filter(
        contains(r".jl$"),
        readdir(dir; join=true)
    )
)