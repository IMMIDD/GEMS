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


## Using Contact Matrices

The default simulation samples contacts at random from a person's associated settings.
For settings with a strong internal structure (e.g., `Household`s or `SchoolClass`es), this leads to a noticeable age-age coupling for within-setting contacts, as people who cohabit or attend the same school class tend to be of similar age.
For less structured settings (e.g., `Municipality`s), GEMS offers the option to use contact matrices, i.e., from the [POLYMOD](https://journals.plos.org/plosmedicine/article?id=10.1371/journal.pmed.0050074) study.

To use this feature, you need two things:
- A `.txt` file with a space-separated `NxN` contact matrix (that sums up to 1.0)
- A custom config file that specifies the usage of age-based contact sampling for certain settings and links the contact matrix file.

!!! info "Example"
    The repository contains an [example folder](https://github.com/IMMIDD/GEMS/examples/age-based-contact-sampling) with a working config file and a contact matrix.

In your custom config file, specify the use of the `AgeBasedContactSampling` method for your desired settings, and provide the average number of contacts (`contactparameter`), the age-group sizes in your contact data (`interval`), and the reference to the contact data file (`contact_matrix_file`).
The example below shows how to do that for the `GlobalSetting`.
If you are not comfortable with where to put this, [here's](@ref config-contact-sampling) the explanation on config file layouts.

```@TOML
### Settings section of the config file ###

[Settings.GlobalSetting]
    [Settings.GlobalSetting.contact_sampling_method]
            type = "AgeBasedContactSampling"
            [Settings.GlobalSetting.contact_sampling_method.parameters]
                contactparameter = 1.0
                interval = 5
                contact_matrix_file = "age_group_contact.txt"
```

Here's an excerpt of a contact matrix:

```
1.809543958454122858e-01 1.754155024045680467e-01 ...
1.492398952058478501e-01 1.539522716226224552e-01 ...
...
```

!!! warning "Contact Matrix File Path"
    If you specify a relative path to your (`contact_matrix_file`) in your config file, it must be relative to your current working directory; not relative to the config file. Copy both files from the example folder directly into your current project root folder and it should work.

In the simulations below, we compare the default model (that samples random contacts in all settings) and the custom scenario where we apply age-based sampling in the `GlobalSetting`.
This is the single setting that contains all individuals. 
The `GlobalSetting` is switched off by default as it has a significant impact on performance and is usually only used for code-testing purposes.
But here it does a good job visualizing the differences in the sampling methods.

```julia
using GEMS
default = Simulation(label = "default", global_setting = true)
custom = Simulation("age-based-sampling.toml", label = "custom global contacts")
run!(default)
run!(custom)
rd_d = ResultData(default)
rd_c = ResultData(custom)
gemsplot([rd_d, rd_c], type = :AggregatedSettingAgeContacts)
```

```@raw html
<p align="center">
    <img src="../assets/tutorials/tut_advanced_age-sampling.png" width="80%"/>
</p>
```

If you compare the simulated contacts in the `GlobalSetting`, you see the difference between random sampling and the age-based sampling.
However it should be noted, that the input matrix that we provide in the example folder was computer-generated and not based on empirical data.
We do not recommend to use this for any real-world application.

## Age-Stratified Disease Progression

coming soon ...

## Custom Start Conditions

coming soon ...

## [Custom Contact Sampling](@id custom-contacts)

coming soon ...

## [Custom Transmission Functions](@id custom-transmission)

coming soon ...