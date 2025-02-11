# Code Structure (For Maintenance and Development)
As you can see in [GEMS.jl](src/GEMS.jl) and the structure of this folder, GEMS loads a lot of different files, that handle different aspects of the module. This section is here to give you some orientation for further development and maintenance.

## Why so many files and so many include(...)?
To be able to bring order into the development, we aimed to keep functions of a common theme together in one file. For example keeping all functions spreading infections in one file [methods/infections.jl](src/methods/infections.jl). The problem is that Julia needs to parse the code that defines the types first before we are able to use those types in a signature.

> Consider for example the function `try_to_infect!(individual::Individual, sim::Simulation, pathogen::Pathogen, setting::Setting;`. For this function to be correctly precompiled by Julia, we need to first define `Individual` as well as `Pathogen`, `Simulation` and `Setting`. But those types also depend on each other (for example settings are composed of multiple individuals), so it is difficult to add this function to the definition of one of those types. Thus we decided it would be easier for development to put `try_to_infect!` together with other similar functions like `infect!` into one file.

## Functionality of the Simulation Routine
### Basic Types
The definition of structs for basic types for the active *run* of the simulation is done in [structs](src/structs/). Here we distinguish between entities (e.g. individuals and settings) and parameters (e.g. pathogens and vaccines). The files defining the basic types of the simulation also contain the part of the interface for that type, that is independent of other types.

> As an example: The file [structs/entities/pathogens.jl](src/structs/entities/pathogens.jl) contains the type `Pathogen`. It will also contain getter-functions like `id(::Pathogen)` to return the attributes of a pathogen. It will **not** contain the function `infect!(infectee::Individual, tick::Int16, pathogen::Pathogen)` to infect an individual with a certain pathogen as we would need the type `Individual` for this.

You can think of the included functions in [structs](src/structs/) as somehow "elementary" functions.

If you need to add a new type via a new file, you have to explicitly include that new file in the current code structure. Files defining entities are included in [structs/entities.jl](src/structs/entities.jl), parameters are included in [structs/parameters.jl](src/structs/parameters.jl). Those two files themselves as well as all other files in [structs](src/structs/) are included in [structs.jl](src/structs.jl).

### Complex Methods
Methods that aren't only dependent on one struct, that represent complex behaviour between different types or share a common theme with different methods are often put into seperate files (consider the example of `infect!` above). Those methods are defined in files in [methods](src/methods). If you want to add a new file to this folder, you have to explicitly include that new file in [methods.jl](src/methods.jl).

## Further Functionality and Types
Types and function that aren't part of the simulation routine like `ResultData` for reporting are defined in their specific subfolder.

> For example:
> `PostProcessor`, which handles the aggregation and calculation of variables for the report of a run, is defined in [model_analysis/post_processing.jl](src/model_analysis/post_processing.jl).
> The function `markdown(pathogen::Pathogen)`, which returns information about the pathogen's attributes as a markdown string, is defined in [reporting/markdown.jl](src/reporting/markdown.jl).

## DevTools and Utils
Functions that are only meant for testing purposes like `test_all` are included in the file [devtools.jl](src/devtools.jl). Functions that are considered to be general utility functions like `concrete_subtypes(type::Type)::Vector{Type}`, which returns all concrete subtypes given an abstract type, are included in the file [utils.jl](src/utils.jl).