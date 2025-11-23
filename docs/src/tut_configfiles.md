# [7 - Advanced Parameterization](@id advanced)

The `Simulation()` function provides a large variety of optional arguments to parameterize models.
However, in some cases, you might want to change how disease progressions are calculated, how contacts are sampled, or how infections happen.
In those cases, we use so-called *[config files](@ref config-files)* to pass advanced parameterizations to the GEMS engine.
Config files are also useful to keep track of all your custom parameters in one file.
This tutorial shows you how what you can do with them.


## Using Config Files

Config files use the **\*.TOML** notation.
Since v0.7.0 it is also possible to load a configfile and pass additional arguments to the `Simulation()` function that override the configfile values.
Please look up the [config file](@ref config-files) documentation to learn how to construct config files.

If you have a config file, here's how you load it in GEMS:

```julia
using GEMS
sim = Simulation(configfile = "path/to/my/config-file.toml")
```


## Using Contact Matrices

The default simulation samples contacts at random from a person's associated settings.
For settings with a strong internal structure (e.g., `Household`s or `SchoolClass`es), this leads to a noticeable age-age coupling for within-setting contacts, as people who cohabit or attend the same school class tend to be of similar age.
For less structured settings (e.g., `Municipality`s), GEMS offers the option to use contact matrices, i.e., from the [POLYMOD](https://journals.plos.org/plosmedicine/article?id=10.1371/journal.pmed.0050074) study.

To use this feature, you need a `.txt` file with a space-separated `NxN` contact matrix (that sums up to 1.0)

!!! info "Example"
    The repository contains an [example folder](https://github.com/IMMIDD/GEMS/tree/main/examples/age-based-contact-sampling) with a contact matrix file and a working config file if you prefer to not parameterize everything in the code.

Here's an excerpt of a contact matrix:

```
1.809543958454122858e-01 1.754155024045680467e-01 ...
1.492398952058478501e-01 1.539522716226224552e-01 ...
...
```

In the simulations below, we compare the default model (that samples random contacts in all settings) and the custom scenario where we apply age-based sampling in the `GlobalSetting`.
This is the single setting that contains all individuals. 
The `GlobalSetting` is switched off by default as it has a significant impact on performance and is usually only used for code-testing purposes.
But here it does a good job visualizing the differences in the sampling methods.

```julia
using GEMS
default = Simulation(label = "default", global_setting = true)
contsamp = AgeBasedContactSampling(
        contactparameter = 1.0,
        interval = 5,
        contact_matrix_file = "examples/age-based-contact-sampling/age_group_contact.txt")
custom = Simulation(label = "custom global contacts", global_setting = true, global_setting_contacts = contsamp)
run!(default)
run!(custom)
rd_d = ResultData(default)
rd_c = ResultData(custom)
gemsplot([rd_d, rd_c], type = :AggregatedSettingAgeContacts)
```

**Plot**

```@raw html
<p align="center">
    <img src="../assets/tutorials/tut_advanced_age-sampling.png" width="80%"/>
</p>
```

If you compare the simulated contacts in the `GlobalSetting`, you see the difference between random sampling and the age-based sampling.
However it should be noted, that the input matrix that we provide in the example folder was computer-generated and not based on empirical data.
We do not recommend to use this for any real-world application.

If you want to use a config file, specify the use of the `AgeBasedContactSampling` method for your desired settings, and provide the average number of contacts (`contactparameter`), the age-group sizes in your contact data (`interval`), and the reference to the contact data file (`contact_matrix_file`).
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

!!! warning "Contact Matrix File Path"
    If you specify a relative path to your (`contact_matrix_file`) in your config file, it must be relative to your current working directory; not relative to the config file. Copy both files from the example folder directly into your current project root folder and it should work.



## [Custom Transmission Functions](@id custom-transmission)

GEMS' default configuration assumes that each contact yields the same probability to pass on an infection and previously infected individuals are immune.
However, in reality, transmission patterns might be much more complex.
Custom transmission functions can be used to integrate complex dynamics.

To use this feature, you need a custom `TransmissionFunction` struct and its accopanying `transmission_probability()` function that provides the rules of how transmission chances are being calculated.

Here's an example of a custom transmission struct and the required function.
First, import the `GEMS.transmission_probability` function.
Then define a new keyworded struct and make it inherit from `GEMS.TransmissionFunction`.
In this struct you can define any parameters as fields that you would like to pass via a config file.
In the example below, we want to differentiate transmission probability based on whether the contact happens in a household or in another setting.
We thus specify a `household_rate` and a `general_rate`.
An individual who was infected before shall have perfect immunity.
Now define the `transmission_probability()` function for the new type.
The transmission probability must return a value between `0` and `1` and is used to calculate the infection risk for each contact.
A value of `0` means, the agent cannot be infected (perfect immunity).
A value of `1` means, the agent will definitely be infected.
Make sure that the function has the exact signature as shown below were the first argument is the new `TransmissionFunction` struct, followed by the `infecter` individual, the `infected` individual, the `setting` both individuals are currently in, and the current `tick`.
All of these arguments can be used to determine the actual transmission probability.

```julia
using GEMS
using Parameters
import GEMS.transmission_probability

# define custom transmission struct
@with_kw mutable struct SettingRate <: GEMS.TransmissionFunction
    household_rate::Float64
    general_rate::Float64
end

# override transmission probability function for your struct
function GEMS.transmission_probability(transFunc::SettingRate,
    infecter::Individual, infected::Individual,
    setting::Setting, tick::Int16)::Float64

    # if the agent has already been infected (natural immunity)
    if number_of_infections(infected) > 0
        return 0.0
    end

    # if the contact setting is a household, return household_rate
    # and the general_rate otherwise
    return isa(setting, Household) ? transFunc.household_rate : transFunc.general_rate
end
```

Now, run a baseline simulation and one with your custom transmission function and plot the `:TickCasesBySetting`.
We should see a significant difference between the number of infections that happen within and outside households.

```julia
default = Simulation(label = "default")
tf = SettingRate(general_rate = 0.1, household_rate = 0.3)
custom = Simulation(label = "custom transmission", transmission_function = tf)
run!(default)
run!(custom)
rd_d = ResultData(default)
rd_c = ResultData(custom)
gemsplot([rd_d, rd_c], type = :TickCasesBySetting)
```

**Plot**

```@raw html
<p align="center">
    <img src="../assets/tutorials/tut_advanced_custom-transmission.png" width="80%"/>
</p>
```

If you want to use it in a config file, specify the use of the `SettingRate` method and provide the parameters as you defined them.
The example below shows the parameterization in a custom config file.
If you are not comfortable with where to put this, [here's](@ref config-contact-sampling) the explanation on config file layouts.

```@TOML
### Pathogen section of the config file ###

[Pathogens]
    [Pathogens.Covid19]
        [Pathogens.Covid19.transmission_function]
            type = "SettingRate"
            [Pathogens.Covid19.transmission_function.parameters]
                general_rate = 0.1
                household_rate = 0.3
```

!!! info "Example"
    The repository contains an [example folder](https://github.com/IMMIDD/GEMS/tree/main/examples/custom-transmission-function) with a working config file for the code snippet above.

## Immunity & Waning

Individuals in GEMS don't have an immunity attribute.
Immunity is considered implicitly by the `transmission_probabilty()` function.
Making an individual "immune" corresponds to having the transmission probability function return `0`, e.g., if we assume perfect natural immunity after infection and that the individual has been infected at least once.
Waning (of natural immunity or vaccination protection) can be modeled the same way.
All cases require the definition of a custom transmission function.
We recommend doing [this](@ref custom-transmission) tutorial first, if you have not yet built a custom transmission function yourself.

For this example, we want an individual to have natural immunty against a pathogen after infection for exactly 50 days.
The example below shows a custom transmission function including that rule.
The `FixedWaning` struct takes two parameters.
A `rate` representing the infection probability if no immunity applies and a `waning_time` specifying the duration of immunity after recovery.

```julia
using GEMS
using Parameters
import GEMS.transmission_probability

# define custom transmission struct
@with_kw mutable struct FixedWaning <: GEMS.TransmissionFunction
    rate::Float64
    waning_time::Int64
end

# override transmission probability function for your struct
function GEMS.transmission_probability(transFunc::FixedWaning,
    infecter::Individual, infected::Individual,
    setting::Setting, tick::Int16)::Float64

    # if never infected before, usual rate applies
    if number_of_infections(infected) == 0
        return transFunc.rate
    end

    # calculate until when individual is immune if he was previously infected
    immune_until = recovery(infected) + transFunc.waning_time
    
    # if waning date is in the future, return 0 as transmission probability,
    # else, return provided rate
    return immune_until > tick ? 0.0 : transFunc.rate
end
```

Now, run a simulation as such and inspect the results:

```julia
tf = FixedWaning(rate = 0.2, waning_time = 50)
sim = Simulation(transmission_function = tf)
run!(sim)
rd = ResultData(sim)
gemsplot(rd)
```


**Plot**

```@raw html
<p align="center">
    <img src="../assets/tutorials/tut_advanced_fixed-waning.png" width="80%"/>
</p>
```

The plots show oscillating behavior of the daily infections and the effective reproduction number as individuals are becoming susceptible again a few weeks after their initial infection.

If you want to use a config file, specify the use of the `FixedWaning` method and provide the parameters as you defined them.
The example below shows the parameterization in a custom config file.
If you are not comfortable with where to put this, [here's](@ref config-contact-sampling) the explanation on config file layouts.

```@TOML
### Pathogen section of the config file ###

[Pathogens]
    [Pathogens.Covid19]
        [Pathogens.Covid19.transmission_function]
            type = "FixedWaning"
            [Pathogens.Covid19.transmission_function.parameters]
                rate = 0.2
                waning_time = 50
```

!!! info "Example"
    The repository contains an [example folder](https://github.com/IMMIDD/GEMS/tree/main/examples/fixed-waning) with a working config file for the code snippet above.


## Custom Disease Progression

Beyond the default progression categories (`Asymptomatic`, `Symptomatic`, `Severe`, `Hospitalized`, and `Critical`), GEMS allows you to specify custom disese progressions.
To do that, you need to define two things:
- A struct for your new progression that inherits from `ProgressionCategory` and
- A `calculate_progression()` function that defines the actual progression for an individual

In this example, we want to define a disease that always ends in a symptomatic progression.
A certain percentage of infections should result in death.
If individuals die, death should occur ~3 days after symptom onset.
If individuals recover, it should take ~20 days after symptom onset.

Here's the code:

```julia
using GEMS, Distributions, Random, Parameters
import GEMS.calculate_progression

# define disease progression category struct
@with_kw mutable struct MyProgression <: GEMS.ProgressionCategory
    death_probability::Float64
    exposure_to_symptom_onset::Distribution
    symptom_onset_to_death::Distribution
    symptom_onset_to_recovery::Distribution
end

# define progression calculation function
function GEMS.calculate_progression(individual::Individual, tick::Int16, dp::MyProgression;
    rng::AbstractRNG = Random.default_rng())

    # Calculate the time to symptom onset
    symptom_onset =  tick + Int16(1) + gems_rand(rng, dp.exposure_to_symptom_onset)
    # decide if individual will die
    should_die = gems_rand(rng) <= dp.death_probability

    if should_die
        # Calculate the time to death
        death = symptom_onset + gems_rand(rng, dp.symptom_onset_to_death)
        # return disease progression with death
        return DiseaseProgression(
            exposure = tick,
            infectiousness_onset = symptom_onset, # let infectiousness begin with symptoms
            symptom_onset = symptom_onset,
            death = death
        )
    else
        # Calculate the time to recovery
        recovery = symptom_onset + gems_rand(rng, dp.symptom_onset_to_recovery)
        return DiseaseProgression(
            exposure = tick,
            infectiousness_onset = symptom_onset, # let infectiousness begin with symptoms
            symptom_onset = symptom_onset,
            recovery = recovery
        )
    end
end

# set up a disease progression instance
my_prog = MyProgression(
    death_probability = 0.2, # 20% will die
    exposure_to_symptom_onset = Poisson(1),
    symptom_onset_to_death = Poisson(3), # if people die, it will happen after ~3 days
    symptom_onset_to_recovery = Poisson(20) # if people recover, it will take ~20 days
)

# set up a pathogen with the new progression category
p = Pathogen(
    name = "TestProgression",
    progressions = [my_prog]
)

# run a simulation with the new progression type
sim = Simulation(pathogen = p)
run!(sim)
rd = ResultData(sim)
gemsplot(rd, type = (:TickCases, :InfectionDuration, :ProgressionCategories))
```

**Plot**

```@raw html
<p align="center">
    <img src="../assets/tutorials/tut_advanced_progression.png" width="60%"/>
</p>
```

The plots show that all progressions now follow your new custom `MyProgression` type.
The middle plot suggests two peaks in disease durations.
The lower (left) peak is caused by the dying individuals and the higher (right) peak by the recovering individuals.

!!! info "DiseaseProgression struct"
    The `calculate_progression()` needs to return a `DiseaseProgression` struct. This struct contains discrete values for time points when an individual transitions from one disease state into another. These events are: `exposure`,  `infectiousness_onset`, `symptom_onset`, `severeness_onset`, `hospital_admission`, `icu_admission`, `icu_discharge`, `ventilation_admission`, `ventilation_discharge`, `hospital_discharge`, `severeness_offset`, `recovery`, `death`. The `DiseaseProgression` struct does internal validity checks (e.g., to prevent individuals from being released from hospital without being admitted). Please look up the `DiseaseProgression` documentation.

## Custom Progression Assignment

coming soon ...

## Custom Start Conditions

coming soon ...

## [Custom Contact Sampling](@id custom-contacts)

coming soon ...

