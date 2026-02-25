# [Config Files](@id config-files)

Using a config file, you can manipulate any parameter of a GEMS simulation.
Although you can spawn a simulation without a config file (e.g., by just calling `Simulation()`), GEMS will internally load a default config file and override the values based on the custom parameter you might have provided.

This page gives an overview of what you can put into a config file and uses the default config file as demonstration.
Config files use the **\*.TOML** notation. When working with the `Simulation()` function to create a simulation, you can **either** use keyword arguments **or** a config file.
Therefore, when you use a config file, you need to make sure that all parameters you want to pass are contained in the file.

## Default Config File

These are the internal defaults whenever you spawn a simulation without additional arguments.
Please look up the [Default Configuration](@ref default-config) section for a more readable summary of the values.

If you want to set up a custom config file, you can copy this one into your own \*.TOML file and change the values to your liking.

```toml
[Simulation]

    # seed = 1234
    tickunit = 'd'
    GlobalSetting = false
    startdate = '2024-01-01'
    enddate = '2024-12-31'
    [Simulation.StartCondition]
        type = "InfectedFraction"
        [Simulation.StartCondition.parameters]
            fraction = 0.001
            #pathogen = "Covid19"

    [Simulation.StopCriterion]
        type = "TimesUp"
        [Simulation.StopCriterion.parameters]
            limit = 365

[Population]
    n = 100_000
    avg_household_size = 3
    avg_office_size = 5
    avg_school_size = 100
    empty = false

[Pathogens]

    [Pathogens.Covid19]
        [Pathogens.Covid19.transmission_function]
            type = "ConstantTransmissionRate"
            [Pathogens.Covid19.transmission_function.parameters]
                transmission_rate = 0.2

        [Pathogens.Covid19.progressions]

            # ASYMPTOMATIC PROGRESSION [TOTAL DURATION ~ 10 DAYS]
            [Pathogens.Covid19.progressions.Asymptomatic]
                [Pathogens.Covid19.progressions.Asymptomatic.exposure_to_infectiousness_onset]
                    distribution = "Poisson"
                    parameters = [1]
                [Pathogens.Covid19.progressions.Asymptomatic.infectiousness_onset_to_recovery]
                    distribution = "Poisson"
                    parameters = [8]

            # SYMPTOMATIC PROGRESSION [TOTAL DURATION ~ 10 DAYS]
            [Pathogens.Covid19.progressions.Symptomatic]
                [Pathogens.Covid19.progressions.Symptomatic.exposure_to_infectiousness_onset]
                    distribution = "Poisson"
                    parameters = [1]
                [Pathogens.Covid19.progressions.Symptomatic.infectiousness_onset_to_symptom_onset]
                    distribution = "Poisson"
                    parameters = [1]
                [Pathogens.Covid19.progressions.Symptomatic.symptom_onset_to_recovery]
                    distribution = "Poisson"
                    parameters = [7]

            # SEVERE PROGRESSION [TOTAL DURATION ~ 15 DAYS]
            [Pathogens.Covid19.progressions.Severe]
                [Pathogens.Covid19.progressions.Severe.exposure_to_infectiousness_onset]
                    distribution = "Poisson"
                    parameters = [1]
                [Pathogens.Covid19.progressions.Severe.infectiousness_onset_to_symptom_onset]
                    distribution = "Poisson"
                    parameters = [1]
                [Pathogens.Covid19.progressions.Severe.symptom_onset_to_severeness_onset]
                    distribution = "Poisson"
                    parameters = [1]
                [Pathogens.Covid19.progressions.Severe.severeness_onset_to_severeness_offset]
                    distribution = "Poisson"
                    parameters = [7]
                [Pathogens.Covid19.progressions.Severe.severeness_offset_to_recovery]
                    distribution = "Poisson"
                    parameters = [4]

            # HOSPITALIZED PROGRESSION [TOTAL DURATION ~ 20 DAYS]
            [Pathogens.Covid19.progressions.Hospitalized]
                [Pathogens.Covid19.progressions.Hospitalized.exposure_to_infectiousness_onset]
                    distribution = "Poisson"
                    parameters = [1]
                [Pathogens.Covid19.progressions.Hospitalized.infectiousness_onset_to_symptom_onset]
                    distribution = "Poisson"
                    parameters = [1]
                [Pathogens.Covid19.progressions.Hospitalized.symptom_onset_to_severeness_onset]
                    distribution = "Poisson"
                    parameters = [1]
                [Pathogens.Covid19.progressions.Hospitalized.severeness_onset_to_hospital_admission]
                    distribution = "Poisson"
                    parameters = [2]
                [Pathogens.Covid19.progressions.Hospitalized.hospital_admission_to_hospital_discharge]
                    distribution = "Poisson"
                    parameters = [7]
                [Pathogens.Covid19.progressions.Hospitalized.hospital_discharge_to_severeness_offset]
                    distribution = "Poisson"
                    parameters = [3]
                [Pathogens.Covid19.progressions.Hospitalized.severeness_offset_to_recovery]
                    distribution = "Poisson"
                    parameters = [4]

            # CRITICAL PROGRESSION [TOTAL DURATION ~ 30 DAYS]
            [Pathogens.Covid19.progressions.Critical]
                death_probability = 0.3
                [Pathogens.Covid19.progressions.Critical.exposure_to_infectiousness_onset]
                    distribution = "Poisson"
                    parameters = [1]
                [Pathogens.Covid19.progressions.Critical.infectiousness_onset_to_symptom_onset]
                    distribution = "Poisson"
                    parameters = [1]
                [Pathogens.Covid19.progressions.Critical.symptom_onset_to_severeness_onset]
                    distribution = "Poisson"
                    parameters = [1]
                [Pathogens.Covid19.progressions.Critical.severeness_onset_to_hospital_admission]
                    distribution = "Poisson"
                    parameters = [2]
                [Pathogens.Covid19.progressions.Critical.hospital_admission_to_icu_admission]
                    distribution = "Poisson"
                    parameters = [2]
                
                # RECOVERY PATHWAY
                [Pathogens.Covid19.progressions.Critical.icu_admission_to_icu_discharge]
                    distribution = "Poisson"
                    parameters = [7]
                [Pathogens.Covid19.progressions.Critical.icu_discharge_to_hospital_discharge]
                    distribution = "Poisson"
                    parameters = [7]
                [Pathogens.Covid19.progressions.Critical.hospital_discharge_to_severeness_offset]
                    distribution = "Poisson"
                    parameters = [3]
                [Pathogens.Covid19.progressions.Critical.severeness_offset_to_recovery]
                    distribution = "Poisson"
                    parameters = [4]

                # DEATH PATHWAY
                [Pathogens.Covid19.progressions.Critical.icu_admission_to_death]
                    distribution = "Poisson"
                    parameters = [10]

        # progression assignment method
        [Pathogens.Covid19.progression_assignment]
            type = "AgeBasedProgressionAssignment"
            [Pathogens.Covid19.progression_assignment.parameters]
                age_groups = ["-14", "15-65", "66-"]
                progression_categories = ["Asymptomatic", "Symptomatic", "Severe", "Hospitalized", "Critical"]
                stratification_matrix = [[0.400, 0.580, 0.010, 0.007, 0.003],
                                         [0.250, 0.600, 0.110, 0.030, 0.010],
                                         [0.150, 0.400, 0.250, 0.120, 0.080]]

[Settings]

    [Settings.Household]
        [Settings.Household.contact_sampling_method]
                type = "ContactparameterSampling"
                [Settings.Household.contact_sampling_method.parameters]
                    contactparameter = 1.0

    [Settings.Office]
        [Settings.Office.contact_sampling_method]
                type = "ContactparameterSampling"
                [Settings.Office.contact_sampling_method.parameters]
                    contactparameter = 1.0
                    
    [Settings.School]
        [Settings.School.contact_sampling_method]
                type = "ContactparameterSampling"
                [Settings.School.contact_sampling_method.parameters]
                    contactparameter = 1.0

    [Settings.SchoolClass]
        [Settings.SchoolClass.contact_sampling_method]
                type = "ContactparameterSampling"
                [Settings.SchoolClass.contact_sampling_method.parameters]
                    contactparameter = 1.0
```

## Manipulating Config Files

While you can adapt many parameters via the `Simulation()` constructor, config files are required if you want to add custom mechanics (like custom transmission functions or custom contact sampling functions).
Please have a look at the tutorial for [advanced parameterization](@ref advanced).

A config file contains four sections: `[Simulation]`, `[Population]`, `[Pathogens]`, and `[Settings]`.

```@contents
Pages = ["config-files.md"]
Depth = 3:4
```

### Simulation

#### `seed`
Random seed used for the simulation.
The seed is being set upon creation of the `Simulation` object.

```toml
[Simulation]
    seed = 12345
    ...
```
The seed must be an integer value.

#### `tickunit`
Length of a simulated timestep.
```toml
[Simulation]
    tickunit = 'd'
    ...
```
The tick unit can either by days(`'d'`), hours(`'h'`), or weeks(`'w'`).

#### `GlobalSetting`
Boolean flag that adds a single setting containing all individuals of the simulations, the `GlobalSetting`.

```toml
[Simulation]
    GlobalSetting = false
    ...
```
Can be activated or deactivated with `true` or `false`.

#### `startdate`
Start date in a `YYYY-MM-DD` format (e.g. `2024-01-01`).

#### `enddate`
End date in a `YYYY-MM-DD` format (e.g. `2024-12-31`).

### Population

#### `n`
The number of individuals to generate.

```toml
[Population]
    n = 100_000
    ...
```
Must be an integer value.
This parameter does not apply if you pass a dedicated population file.

#### `avg_household_size`
The average household size in a generated population.

```toml
[Population]
    avg_household_size = 3
    ...
```
Must be an integer value.
This parameter does not apply if you pass a dedicated population file.

#### `avg_office_size`
The average office size in a generated population.

```toml
[Population]
    avg_office_size = 5
    ...
```
Must be an integer value.
This parameter does not apply if you pass a dedicated population file.

#### `avg_school_size`
The average school size in a generated population.
This is internally handled as `SchoolClass`es, as `School`s are a `ContainerSetting` that cannot directly hold individuals.
Look up the explanation of [setting hierarchies](@ref setting-hierarchy).

```toml
[Population]
    avg_school_size = 100
    ...
```
Must be an integer value.
This parameter does not apply if you pass a dedicated population file.

#### `empty`
If true, overrides all other arguments and returns a completely empty population object.

```toml
[Population]
    empty = false
    ...
```
Must be a boolean value.

### Pathogens

The `[Pathogens]` section defines the pathogens contained in the simulation. You can define an arbitrary number of pathogens.
Every pathogen must be defined via a dedicated section where the pathogen name is the section identifier:
```toml
[Pathogens]
    [Pathogens.Covid19]
        # Pathogen Parameters
        ...
```

#### `transmission_function`
Defines the routine which is used to evaluate the infection probability for any contact.
This can as well be used to model immunity and waning.

```toml
[Pathogens]
    [Pathogens.Covid19]
        [Pathogens.Covid19.transmission_function]
            type = "ConstantTransmissionRate"
            [Pathogens.Covid19.transmission_function.parameters]
                transmission_rate = 0.2
                ...
```
The `type` argument specifies the `TransmissionFunction` that conditions the dispatching to the respective `transmission_probability(...)` function when running GEMS.
The subsequent `[.parameters]` section holds the arguments that the GEMS engine will pass to the `TransmissionFunction` struct upon initialization.

#### `progressions`
Defines distinct disease progression tracks. The engine currently supports explicit pathways like `Asymptomatic`, `Symptomatic`, `Severe`, `Hospitalized`, and `Critical`. Each category specifies Poisson or Binomial distributions to compute state intervals (e.g. `exposure_to_infectiousness_onset`, `symptom_onset_to_recovery`).

#### `progression_assignment`
Determines how disease tracks are distributed among the infected population. By passing an `AgeBasedProgressionAssignment`, probabilities can be mapped explicitly via age stratifications.