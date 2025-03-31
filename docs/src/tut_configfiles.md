# [6 - Advanced Parameterization](@id advanced)

The `Simulation()` function provides a large varitey of optional arguments to parameterize models.
However, in some cases, you might want to change how disease progressions are calculated, how contacts are sampled, or how infections happen.
In those cases, we use so-called *[config files](@ref config-files)* to pass advanced parameterizations to the GEMS engine.
Config files are also useful to keep track of all your custom parameters in one file.
This tutorial shows you how what you can do with them.


## Using Config Files

Config files use the **\*.TOML** notation. When working with the `Simulation()` function to create a simulation, you can **either** use keyword arguments **or** a config file.
Therefore, when you use a config file, you need to make sure that all parameters you want to pass are contained in the file.
Please look up the [config file](@ref config-files) documentation to learn how to construct config files.

If you have a config file, here's how you load it in GEMS:

```julia
using GEMS
sim = Simulation("path/to/my/config-file.toml")
```


## Age-Stratified Disease Progression

## Custom Start Conditions

## [Custom Contact Sampling](@id custom-contacts)

## [Custom Transmission Functions](@id custom-transmission)

