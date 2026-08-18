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
            pathogen = "all"

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

            # MILD PROGRESSION [TOTAL DURATION ~ 10 DAYS]
            [Pathogens.Covid19.progressions.Mild]
                [Pathogens.Covid19.progressions.Mild.exposure_to_infectiousness_onset]
                    distribution = "Poisson"
                    parameters = [1]
                [Pathogens.Covid19.progressions.Mild.infectiousness_onset_to_symptom_onset]
                    distribution = "Poisson"
                    parameters = [1]
                [Pathogens.Covid19.progressions.Mild.symptom_onset_to_recovery]
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

            # CRITICAL PROGRESSION [disease tier only; hospital/ICU/death are decided by the HealthProgression]
            [Pathogens.Covid19.progressions.Critical]
                [Pathogens.Covid19.progressions.Critical.exposure_to_infectiousness_onset]
                    distribution = "Poisson"
                    parameters = [1]
                [Pathogens.Covid19.progressions.Critical.infectiousness_onset_to_symptom_onset]
                    distribution = "Poisson"
                    parameters = [1]
                [Pathogens.Covid19.progressions.Critical.symptom_onset_to_severeness_onset]
                    distribution = "Poisson"
                    parameters = [1]
                [Pathogens.Covid19.progressions.Critical.severeness_onset_to_critical_onset]
                    distribution = "Poisson"
                    parameters = [2]
                [Pathogens.Covid19.progressions.Critical.critical_onset_to_critical_offset]
                    distribution = "Poisson"
                    parameters = [7]
                [Pathogens.Covid19.progressions.Critical.critical_offset_to_severeness_offset]
                    distribution = "Poisson"
                    parameters = [3]
                [Pathogens.Covid19.progressions.Critical.severeness_offset_to_recovery]
                    distribution = "Poisson"
                    parameters = [4]

        # progression assignment method
        [Pathogens.Covid19.progression_assignment]
            type = "AgeBasedProgressionAssignment"
            [Pathogens.Covid19.progression_assignment.parameters]
                age_groups = ["-14", "15-65", "66-"]
                progression_categories = ["Asymptomatic", "Mild", "Severe", "Critical"]
                stratification_matrix = [[0.400, 0.580, 0.017, 0.003],
                                         [0.250, 0.600, 0.140, 0.010],
                                         [0.150, 0.400, 0.370, 0.080]]

# host-level care/death policy; each infection contributes care for its peak tier, folded per host
[HealthProgression]
    type = "DefaultHealthProgression"

    # SEVERE-PEAK CARE [ward admission only]
    [HealthProgression.parameters.severe]
        hospital_probability = 0.05
        [HealthProgression.parameters.severe.severeness_onset_to_hospital_admission]
            distribution = "Poisson"
            parameters = [2]
        [HealthProgression.parameters.severe.hospital_admission_to_hospital_discharge]
            distribution = "Poisson"
            parameters = [10]

    # CRITICAL-PEAK CARE [hospital -> ICU -> ventilation, plus ungated death; ventilation off by default]
    [HealthProgression.parameters.critical]
        hospital_probability = 0.95
        hospital_to_icu_probability = 0.5
        icu_to_ventilation_probability = 0.0
        death_probability = 0.3          # ungated by hospital/ICU
        icu_admission_to_ventilation_admission = 0
        ventilation_admission_to_ventilation_discharge = 0
        ventilation_discharge_to_icu_discharge = 0
        [HealthProgression.parameters.critical.critical_onset_to_hospital_admission]
            distribution = "Poisson"
            parameters = [1]
        [HealthProgression.parameters.critical.hospital_admission_to_hospital_discharge]
            distribution = "Poisson"
            parameters = [10]
        [HealthProgression.parameters.critical.hospital_admission_to_icu_admission]
            distribution = "Poisson"
            parameters = [1]
        [HealthProgression.parameters.critical.icu_admission_to_icu_discharge]
            distribution = "Poisson"
            parameters = [8]
        [HealthProgression.parameters.critical.icu_discharge_to_hospital_discharge]
            distribution = "Poisson"
            parameters = [5]
        [HealthProgression.parameters.critical.critical_onset_to_death]
            distribution = "Poisson"
            parameters = [7]

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

A config file contains five sections: `[Simulation]`, `[Population]`, `[Pathogens]`, `[HealthProgression]`, and `[Settings]`.

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

#### `StartCondition`
The initial infections of the simulation. The `type` is any of the available start conditions (`InfectedFraction`, `PatientZero`, `PatientZeros`, `RegionalSeeds`, `ImportedCases`) and `parameters` are passed to its constructor.

```toml
[Simulation.StartCondition]
    type = "InfectedFraction"
    [Simulation.StartCondition.parameters]
        fraction = 0.001
        pathogen = "all"
```

Every start condition takes a `pathogen` parameter with three possible values:

- a pathogen name (e.g. `"Covid19"`): seeds that pathogen. The name must exist in `[Pathogens]`.
- `"all"`: seeds every pathogen of the simulation. Each pathogen gets its own copy of the condition, so the example above infects 0.1% of the population *per pathogen* rather than splitting 0.1% between them.
- `""` (or omitting the parameter): seeds the only pathogen. This is a convenience for single-pathogen simulations and throws if the simulation has more than one pathogen.

To seed pathogens differently from one another, use the `[[Simulation.StartConditions]]` array of tables instead, which takes one entry per condition.

```toml
[[Simulation.StartConditions]]
    type = "InfectedFraction"
    [Simulation.StartConditions.parameters]
        fraction = 0.001
        pathogen = "Covid19"

[[Simulation.StartConditions]]
    type = "PatientZero"
    [Simulation.StartConditions.parameters]
        pathogen = "Influenza"
```

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
Defines distinct disease progression tracks. The engine currently supports explicit pathways like `Asymptomatic`, `Mild`, `Severe`, and `Critical`. `Severe` and `Critical` may also carry host-care parameters (see [`HealthProgression`](#healthprogression) below) directly inline, as a single-pathogen convenience.

Within each category, you must define the intervals between state transitions (e.g., `exposure_to_infectiousness_onset`, `symptom_onset_to_recovery`). Every interval requires two arguments to initialize the underlying random distribution:
* **`distribution`**: A string representing the statistical distribution (e.g., `"Poisson"`, `"Binomial"`).
* **`parameters`**: An array of numerical values required by the chosen distribution (e.g., `[7]` for a Poisson distribution with $\lambda = 7$).

```toml
[Pathogens.Covid19.progressions.Mild]
    [Pathogens.Covid19.progressions.Mild.symptom_onset_to_recovery]
        distribution = "Poisson"
        parameters = [7]
```
*Note: For distributions representing days, GEMS internally adds +1 to early stages like exposure-to-infectiousness to prevent zero-day state transitions.*

#### `progression_assignment`
Determines how the distinct disease tracks defined above are distributed among the infected population. By passing an `AgeBasedProgressionAssignment`, probabilities can be mapped explicitly via age stratifications.

```toml
[Pathogens.Covid19.progression_assignment]
    type = "AgeBasedProgressionAssignment"
    [Pathogens.Covid19.progression_assignment.parameters]
        age_groups = ["-14", "15-65", "66-"]
        progression_categories = ["Asymptomatic", "Mild", "Severe", "Critical"]
        stratification_matrix = [[0.400, 0.580, 0.017, 0.003],
                                 [0.250, 0.600, 0.140, 0.010],
                                 [0.150, 0.400, 0.370, 0.080]]
```

The nested `[.parameters]` block requires three lists:
* **`age_groups`**: An array of strings defining age brackets. `"-14"` means 0-14, `"15-65"` means 15-65, and `"66-"` means 66+.
* **`progression_categories`**: An array of strings defining the available progression structs. These must exactly match the names defined in your `[Pathogens.<Name>.progressions]` block.
* **`stratification_matrix`**: A 2D array mapping the age groups (rows) to the progression categories (columns). The sum of probabilities in each row must equal `1.0`.

#### `infectiousness_profile`
Defines how infectious an individual is at each tick of their infection. This section is optional;
if omitted, the pathogen uses `ConstantInfectiousness` (one fixed level for the whole infectious
window).

```toml
[Pathogens.Covid19.infectiousness_profile]
    type = "BetaInfectiousness"
    [Pathogens.Covid19.infectiousness_profile.parameters]
        time_to_peak = 2
        concentration = 5
```
`StagedInfectiousness` sets a level per disease stage. `BetaInfectiousness` gives a shedding curve
that rises to a peak `time_to_peak` ticks after infectiousness onset and declines to zero at
recovery — the peak stays at that tick however long the infection lasts, while a longer infection
stretches the decay. Both accept optional per-stage arguments; see the pathogen API reference.

#### `immunity_profile`
Defines how immunity acquired through recovery or vaccination builds up, combines, and wanes over time.
This section is optional; if omitted, the pathogen uses `FullImmunity` (sterilising immunity from the
moment of recovery or vaccination onwards, never waning).

```toml
[Pathogens.Covid19.immunity_profile]
    type = "ExponentialWaning"
    [Pathogens.Covid19.immunity_profile.parameters]
        halflife = 180
        floor = 10
```
The `type` argument specifies the `ImmunityProfile` that conditions the dispatching to the respective
`calculate_immunity(...)` function when running GEMS. The subsequent `[.parameters]` section holds the
arguments passed to the `ImmunityProfile` struct upon initialization, and can be omitted entirely for
profiles that take no arguments (such as `FullImmunity` and `NoImmunity`).

### HealthProgression

Host-level care and mortality (hospitalization, ICU, ventilation, death) are decided independently
of the disease progression, by a `HealthProgression` that folds the demand of *all* of a host's
active infections into one care timeline. The `[HealthProgression]` section configures this policy
for the whole simulation.

```toml
[HealthProgression]
    type = "DefaultHealthProgression"
    [HealthProgression.parameters.severe]
        hospital_probability = 0.05
        ...
    [HealthProgression.parameters.critical]
        hospital_probability = 0.95
        hospital_to_icu_probability = 0.5
        death_probability = 0.3
        ...
```

For `DefaultHealthProgression`, the `[.parameters]` block holds a `severe` and a `critical`
sub-table, corresponding to a `SevereHealthProfile` and a `CriticalHealthProfile` respectively (see
the pathogen API reference for their full parameter lists).

If your simulation has exactly **one** pathogen, you can skip this section entirely and instead
write the `severe`/`critical` parameters directly inside that tier's disease progression in
`[Pathogens.<Name>.progressions]` — they will be routed into the global `HealthProgression`
automatically. This convenience is rejected (with an error) if you also define an explicit
`[HealthProgression]` section, or if your simulation has more than one pathogen (since a single
global policy cannot unambiguously combine care embedded in more than one pathogen's progressions).

### Settings

The `[Settings]` section defines the interaction mechanics for the different setting types in the simulation.
By default, simulations only include the `Household`, `SchoolClass`, and `Office` setting.
If you want to configure mechanics for other setting types, you have to load a population model that includes those settings first.

#### `contact_sampling_method`
Defines the routine which is used to generate contacts between individuals in a setting.

```toml
[Settings]
    [Settings.Household]
        [Settings.Household.contact_sampling_method]
                type = "ContactparameterSampling"
                [Settings.Household.contact_sampling_method.parameters]
                    contactparameter = 1.0
```
The `type` argument specifies the `ContactSamplingMethod` that conditions the dispatching to the respective `sample_contacts!(...)` function when running GEMS.
The subsequent `[.parameters]` section holds the arguments that the GEMS engine will pass to the `ContactSamplingMethod` struct upon initialization.