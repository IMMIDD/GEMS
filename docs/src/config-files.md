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

                # HOST HEALTH FOR THIS TIER [staying home only]
                [Pathogens.Covid19.progressions.Mild.health]
                    symptomatic_homebound_probability = 0.0

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

                # HOST HEALTH FOR THIS TIER [ward admission only]
                [Pathogens.Covid19.progressions.Severe.health]
                    hospital_probability = 0.05
                    symptomatic_homebound_probability = 0.0
                    severe_homebound_probability = 1.0
                    [Pathogens.Covid19.progressions.Severe.health.severeness_onset_to_hospital_admission]
                        distribution = "Poisson"
                        parameters = [2]
                    [Pathogens.Covid19.progressions.Severe.health.hospital_admission_to_hospital_discharge]
                        distribution = "Poisson"
                        parameters = [10]

            # CRITICAL PROGRESSION [disease tier; hospital/ICU/death live in its `health` block]
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

                # HOST HEALTH FOR THIS TIER [hospital -> ICU -> ventilation, plus ungated death; ventilation off by default]
                [Pathogens.Covid19.progressions.Critical.health]
                    hospital_probability = 0.95
                    hospital_to_icu_probability = 0.5
                    icu_to_ventilation_probability = 0.0
                    death_probability = 0.3          # ungated by hospital/ICU
                    symptomatic_homebound_probability = 0.0
                    severe_homebound_probability = 1.0
                    icu_admission_to_ventilation_admission = 0
                    ventilation_admission_to_ventilation_discharge = 0
                    ventilation_discharge_to_icu_discharge = 0
                    [Pathogens.Covid19.progressions.Critical.health.severeness_onset_to_hospital_admission]
                        distribution = "Poisson"
                        parameters = [1]
                    [Pathogens.Covid19.progressions.Critical.health.hospital_admission_to_hospital_discharge]
                        distribution = "Poisson"
                        parameters = [10]
                    [Pathogens.Covid19.progressions.Critical.health.critical_onset_to_icu_admission]
                        distribution = "Poisson"
                        parameters = [1]
                    [Pathogens.Covid19.progressions.Critical.health.icu_admission_to_icu_discharge]
                        distribution = "Poisson"
                        parameters = [8]
                    [Pathogens.Covid19.progressions.Critical.health.icu_discharge_to_hospital_discharge]
                        distribution = "Poisson"
                        parameters = [5]
                    [Pathogens.Covid19.progressions.Critical.health.critical_onset_to_death]
                        distribution = "Poisson"
                        parameters = [7]

        # progression assignment method
        [Pathogens.Covid19.progression_assignment]
            type = "AgeBasedProgressionAssignment"
            [Pathogens.Covid19.progression_assignment.parameters]
                age_groups = ["-14", "15-65", "66-"]
                progression_categories = ["Asymptomatic", "Mild", "Severe", "Critical"]
                stratification_matrix = [[0.400, 0.580, 0.017, 0.003],
                                         [0.250, 0.600, 0.140, 0.010],
                                         [0.150, 0.400, 0.370, 0.080]]

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

A config file contains four required sections: `[Simulation]`, `[Population]`, `[Pathogens]`, and `[Settings]`, plus the optional `[HealthProgression]`.

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

#### `layer_seed`
Random seed of the setting layers' draws (see [`layer`](@ref config-layer) below).

```toml
[Simulation]
    layer_seed = 42
    ...
```
Defaults to `seed`, so every simulation of a batch draws its layers anew.
Set it to keep the same layers across simulations.

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

#### `transmission_prethinning`
Boolean flag that thins sampled contacts by an upper bound on their infection probability before attempting infections. This saves work without changing the distribution of results, but not the random draws of a seeded run. Defaults to `true`.

```toml
[Simulation]
    transmission_prethinning = true
    ...
```

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

#### `PriorImmunity`
Optional natural immunity that part of the population acquired before the start of the simulation. It is applied before the start condition. The parameters are passed to the `PriorImmunity` constructor:

- `fraction`: the immune fraction, one number without `age_groups`, else one per age group
- `age_groups` (optional): age groups such as `"-17"`, `"18-64"`, `"65-"`. Ages outside every group get no immunity.
- `ags` (optional): restricts the immunity to a region
- `ticks_ago`: how many ticks before the start the immunity was acquired, either a number between 1 and 16384 or a distribution drawn per individual. Values are rounded up, and draws outside the bounds are clamped.
- `pathogen` (optional): a pathogen name from `[Pathogens]`, `"all"` for every pathogen (drawn separately for each), or `""` / omitted for the only pathogen (throws if there are several)

```toml
[Simulation.PriorImmunity]
    pathogen = "Covid19"
    age_groups = ["-17", "18-64", "65-"]
    fraction = [0.2, 0.35, 0.5]
    ticks_ago = { distribution = "Uniform", parameters = [30, 365] }
```

To use several entries (e.g. one per pathogen), write `[[Simulation.PriorImmunity]]` instead, once for each entry. If two entries cover the same individual and pathogen, the later one wins.

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
Defines distinct disease progression tracks. The engine currently supports explicit pathways like `Asymptomatic`, `Mild`, `Severe`, `Ward`, `Critical`, `ICU`, and `Fatal`. `Mild`, `Severe` and `Critical` may also carry host-health parameters (see [`HealthProgression`](#healthprogression) below), either as a `health` sub-table or inline, giving that pathogen its own care and mortality rates and deciding who stays home.

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

Host-level health (staying home, hospitalization, ICU, ventilation, death) is decided independently
of the disease progression. Each disease tier carries its own `HealthProfile`, written as a `health`
sub-table of that progression:

```toml
[Pathogens.Covid19.progressions.Critical]
    # ... disease timings ...
    [Pathogens.Covid19.progressions.Critical.health]
        hospital_probability = 0.95
        hospital_to_icu_probability = 0.5
        death_probability = 0.3
        [Pathogens.Covid19.progressions.Critical.health.critical_onset_to_death]
            distribution = "Poisson"
            parameters = [7]
```

`Mild` takes a `MildHealthProfile`, `Severe` a `SevereHealthProfile` and `Critical` a
`CriticalHealthProfile`; see the pathogen API reference for their full parameter lists. The same
parameters may be written flat among the timings instead; the two forms are mutually exclusive.
Because the profile belongs to the pathogen's own progression, two pathogens can differ in mortality
while sharing a severity stratification.

Two parameters decide who is too sick to leave the house. `symptomatic_homebound_probability` is the
share of infections that keep their host home from symptom onset to recovery, and
`severe_homebound_probability` the share that keep it home while severe, at least the former (`1.0` by
default). A homebound host neither infects nor is infected outside its household. Unlike isolation,
this is a health state, not an intervention: there is no compliance, and the host does not count as
quarantined. The draw is made per infection.

A category with no `health` of its own demands no hospitalization and causes no deaths, though its
severe cases still stay home; GEMS warns when that happens.

`Ward`, `ICU`, and `Fatal` fix their outcome instead of drawing it: a `Ward` infection is always admitted
to the ward, an `ICU` infection always reaches the ICU, and a `Fatal` infection always dies. They take the
timings of `Severe` (`Ward`) or `Critical` (`ICU`, `Fatal`) and require a `health` block without the fixed
probabilities. Adding them to the stratification matrix lets ward, ICU, and death rates vary by age independently:

```toml
[Pathogens.Covid19.progressions.Fatal]
    # ... disease timings as for Critical ...
    [Pathogens.Covid19.progressions.Fatal.health]
        hospital_probability = 0.7
        hospital_to_icu_probability = 0.3
        [Pathogens.Covid19.progressions.Fatal.health.critical_onset_to_death]
            distribution = "Poisson"
            parameters = [10]
```

#### HealthProgression

The `[HealthProgression]` section names the *combination* policy — how a host's concurrent infections
fold into one care timeline — and not the profiles. The default is `DefaultHealthProgression`, under
which infections do not interact, so the section is only needed for a custom policy.

```toml
[HealthProgression]
    type = "DefaultHealthProgression"
```

!!! warning "Deprecated"
    `severe` and `critical` sub-tables here are the old per-tier form. They still work, with a
    warning, and fill in the categories of that tier carrying no `health`. Write a `health` block
    into the progressions instead. Pathogens passed to `Simulation` directly ignore them as soon as
    any of them embeds health, even if only a `Mild` one. There is no `mild` sub-table.

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

#### [Declaring Setting Types](@id config-setting-types)
A section whose name is not one of the built-in setting types declares a new setting type of that name.
Its settings work like the built-in ones: they take their contact sampling method from the section and show up in the results.
Individuals join them through a memberships file (see [Creating Populations](@ref tut_pops)) or a [`layer`](@ref config-layer).
If a Julia struct of that name exists (see [Custom Setting Types](@ref custom-setting-types)), GEMS uses the struct instead.

```toml
[Settings]
    [Settings.Gym]
        char = "G"
        [Settings.Gym.contact_sampling_method]
                type = "ContactparameterSampling"
                [Settings.Gym.contact_sampling_method.parameters]
                    contactparameter = 2.0
```
The optional `char` is the single character that marks the setting type in the infection log.
It defaults to the upper-case first letter of the name.
If another setting type already uses that character, GEMS throws an error and asks you to set a different `char`.
GEMS warns about a declared type that no individual belongs to once the simulation is set up, as that is usually a typo or a missing memberships file.

#### [`layer`](@id config-layer)
Generates settings of the section's type from a few parameters and adds individuals to them before the simulation starts.
We call this a *setting layer*.
The example lets 30% of all adults visit gyms of about 20 members:

```toml
[Settings.Gym]
    [Settings.Gym.layer]
        ages = [18, 99]
        participation = 0.3
        [Settings.Gym.layer.assignment]
            type = "PackedSettings"
            size = { distribution = "Poisson", parameters = [20] }
```
A layer table takes these keys:

- `assignment`: how participants are put into settings; a table with a `type` (see below) and that type's parameters
- `ages` (optional): `[lowest, highest]` age of the individuals who can take part, both included
- `sex`, `occupation`, `education` (optional): the value, or a list of values, that an individual's field must have to take part, as the population stores it: `sex` is `1` (female), `2` (male), or `3` (diverse); GEMS's own populations code `occupation` as in the Mikrozensus (EF172) and `education` as an ISCED 2011 level; `-1` means unknown.
- `holding` / `not_holding` (optional): a setting type, or a list of them, that an individual must / must not belong to already
- `participation` (optional): probability that an individual who can take part does so; defaults to `1`. Can also depend on attributes (see below).
- `participation_unit` (optional): a setting type, e.g. `"Household"`, whose members decide together: with the same probability, they all take part or none of them does
- `entries` (optional): how many settings of the type each participant joins, an integer between `0` and `127` or a distribution; defaults to `1`
- `scale` (optional): contacts in these settings relative to a regular member, a number or a distribution; defaults to `1`
- `rescale` (optional): a table of setting types and factors, e.g. `{ Office = 0.7 }`, that multiplies each participant's contacts in the settings of that type they already belonged to; every type in it must be in `holding`
- `name` (optional): the layer's name in the population's records; it also seeds the layer's draws. Defaults to the type's name with a counter, e.g. `Gym[1]`.

An individual has to match every attribute key a layer gives.
Numbers can be replaced by a distribution everywhere except in `ages` and `participation`.
To cap `entries`, use a bounded distribution such as `Binomial`.

For a `participation` that depends on attributes, give it as rows, each with a probability `p` and any of the keys `ages`, `sex`, `occupation`, and `education`:

```toml
[Settings.Gym]
    [Settings.Gym.layer]
        [[Settings.Gym.layer.participation]]
            ages = [18, 39]
            p = 0.4
        [[Settings.Gym.layer.participation]]
            ages = [40, 99]
            p = 0.2
        [Settings.Gym.layer.assignment]
            type = "PackedSettings"
            size = 20
```
The first row an individual matches gives their probability; an individual who matches no row doesn't take part.

The assignment `type` is one of these:

| `type` | Parameters | Puts participants into |
| :--- | :--- | :--- |
| `PackedSettings` | `size` | new settings of `size` members, filled in random order |
| `RandomSettings` | `size` | new settings drawn at random for each participant, so sizes vary around `size` |
| `GroupedSettings` | `size`, `by` | new settings of about `size` members that keep the members of a `by` setting together (by default `"Household"`); `size = 1` gives one setting per `by` setting |
| `AgeSortedSettings` | `size` | new settings of `size` members of similar age |
| `SpatialSettings` | `size`, `spread` | new settings of `size` members living near each other |
| `JoinExisting` | - | existing settings of the type, each picked in proportion to its number of members |
| `JoinNearby` | `spread` | existing settings near the participant's home |
| `JoinVia` | `via`, `primary_only` | existing settings that someone in the participant's `via` setting (by default `"Household"`) already belongs to; with `primary_only = true`, only their primary settings of the type |

`spread` is the distance in km by which a participant's home is moved before GEMS looks for settings nearby: a number is the standard deviation of a random shift, a distribution gives the shift's length in a random direction.
`SpatialSettings` and `JoinNearby` take the household coordinates from the settings file.

A layer can also add settings to a built-in type.
This one gives 10% of all workers a second office, picked among the existing offices:

```toml
[Settings.Office]
    [Settings.Office.layer]
        name = "second_job"
        holding = "Office"
        participation = 0.1
        [Settings.Office.layer.assignment]
            type = "JoinExisting"
```
Add `rescale = { Office = 0.7 }` to lower their contacts in the offices they already had to 70%.

For several layers of one type, write `[[Settings.<Name>.layer]]` once per layer.
GEMS applies them in the order of their section names and, within a section, in file order.
Have a look at the [setting layers](@ref setting-layers) section of the population tutorial before you use them.