# [Config Files](@id config-files)

Using a config file, you can manipulate any parameter of a GEMS simulation.
Although you can spawn a simulation without a config file (e.g., by just calling `Simulation()`), GEMS will iternally load a default config file and override the values based on the custom parameter you might have provided.

This page gives an overview of what you can put into a config file and uses the default config file as demonstration.
Config files use the **\*.TOML** notation.
When working with the `Simulation()` function to create a simulation, you can **either** use keyword arguments **or** a config file.
Therefore, when you use a config file, you need to make sure that all parameters you want to pass are contained in the file.

## Default Config File

These are the internal defaults whenever you spawn a simulation without additional arguments.
Please look up the [Default Configuration](@ref default-config) section for a more readable summary of the values.
If you want to set up a custom config file, you can copy this one into your own \*.TOML file and change the values to your liking.

```@TOML
[Simulation]

    # seed = 1234
    tickunit = 'd'
    GlobalSetting = false
    startdate = '2024.01.01'
    enddate = '2024.12.31'
    [Simulation.StartCondition]
        type = "InfectedFraction"
        fraction = 0.001
        pathogen = "Covid19"   # BE AWARE, THAT NAME MUST BE THE SAME AS IN TOML SECTION

    [Simulation.StopCriterion]
        type = "TimesUp"
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

        [Pathogens.Covid19.onset_of_symptoms]
            distribution = "Poisson"
            parameters = [3]


        [Pathogens.Covid19.time_to_recovery]
            distribution = "Poisson"
            parameters = [7]

        [Pathogens.Covid19.onset_of_severeness]
            distribution = "Poisson"
            parameters = [3]

        [Pathogens.Covid19.infectious_offset]
            distribution = "Poisson"
            parameters = [1]

        [Pathogens.Covid19.mild_death_rate]
            distribution = "Binomial"
            parameters = [1, 0.0]

        [Pathogens.Covid19.severe_death_rate]
            distribution = "Binomial"
            parameters = [1, 0.05]

        [Pathogens.Covid19.critical_death_rate]
            distribution = "Binomial"
            parameters = [1, 0.2]

        [Pathogens.Covid19.hospitalization_rate]
            distribution = "Binomial"
            parameters = [1, 0.3]

        [Pathogens.Covid19.ventilation_rate]
            distribution = "Binomial"
            parameters = [1, 0.3]

        [Pathogens.Covid19.icu_rate]
            distribution = "Binomial"
            parameters = [1, 0.3]

        [Pathogens.Covid19.time_to_hospitalization]
            distribution = "Poisson"
            parameters = [7]

        [Pathogens.Covid19.time_to_icu]
            distribution = "Poisson"
            parameters = [7]

        [Pathogens.Covid19.length_of_stay]
            distribution = "Poisson"
            parameters = [7]

        [Pathogens.Covid19.dpr]
        # Matrix with Disease Progression
            age_groups = ["0+"]
            disease_compartments = ["Asymptomatic", "Mild", "Severe", "Critical"]
            stratification_matrix = [[0.4, 0.45, 0.1, 0.05]]

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

    [Settings.Municipality]
        [Settings.Municipality.contact_sampling_method]
                type = "ContactparameterSampling"

                [Settings.Municipality.contact_sampling_method.parameters]
                    contactparameter = 1.0

    [Settings.WorkplaceSite]
        [Settings.WorkplaceSite.contact_sampling_method]
                type = "ContactparameterSampling"

                [Settings.WorkplaceSite.contact_sampling_method.parameters]
                    contactparameter = 1.0

    [Settings.SchoolComplex]
        [Settings.SchoolComplex.contact_sampling_method]
                type = "ContactparameterSampling"

                [Settings.SchoolComplex.contact_sampling_method.parameters]
                    contactparameter = 1.0

    [Settings.SchoolYear]
        [Settings.SchoolYear.contact_sampling_method]
                type = "ContactparameterSampling"

                [Settings.SchoolYear.contact_sampling_method.parameters]
                    contactparameter = 1.0

    [Settings.Department]
        [Settings.Department.contact_sampling_method]
                type = "ContactparameterSampling"

                [Settings.Department.contact_sampling_method.parameters]
                    contactparameter = 1.0

    [Settings.Workplace]
        [Settings.Workplace.contact_sampling_method]
                type = "ContactparameterSampling"

                [Settings.Workplace.contact_sampling_method.parameters]
                    contactparameter = 1.0
                    
    [Settings.GlobalSetting]
        [Settings.GlobalSetting.contact_sampling_method]
                type = "ContactparameterSampling"

                [Settings.GlobalSetting.contact_sampling_method.parameters]
                    contactparameter = 1.0
```

## Manipulating Config Files

While you can adapt many parameters via the `Simulation()` constructor, config files are required if you want to add custom mechanics (like custom transmission functions or custom contact sampling functions).
Please have a look at the tutorial for [advanced parameterization](@ref advanced).

A config file contains four sections: `[Simulation]`, `[Population]`, `[Pathogens]`, and `[Settings]`.

```@contents
Pages   = ["config-files.md"]
Depth = 3:4
```


### Simulation

#### `seed`

Random seed used for the simulation.
The seed is being set upon creation of the `Simulation` object.

```@TOML
[Simulation]
    seed = 12345
    ...
```
The seed must be an integer value.


#### `tickunit`

Length of a simulated timestep.

```@TOML
[Simulation]
    tickunit = 'd'
    ...
```

The tick unit can either by days(`'d'`), hours(`'h'`), or weeks(`'w'`).

#### `GlobalSetting`


Boolean flag that adds a single setting containing all individuals of the simulations, the `GlobalSetting`.

```@TOML
[Simulation]
    GlobalSetting = false
    ...
```

Can be activated or deactivated with `true` or `false`.


#### `startdate`

t.b.d.


#### `enddate`

t.b.d.


### Population

#### `n`

The number of individuals to generate.

```@TOML
[Population]
    n = 100_000
    ...
```

Must be an integer value.
This parameter does not apply if you pass a dedicated population file.


#### `avg_household_size`

The average household size in a generated population.

```@TOML
[Population]
    avg_household_size = 3
    ...
```

Must be an integer value.
This parameter does not apply if you pass a dedicated population file.


#### `avg_office_size`

The average office size in a generated population.

```@TOML
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

```@TOML
[Population]
    avg_school_size = 100
    ...
```

Must be an integer value.
This parameter does not apply if you pass a dedicated population file.


#### `empty`

If true, overrides all other arguments and returns a completely empty population object.

```@TOML
[Population]
    empty = false
    ...
```

Must be a boolean value.


### Pathogens

The `[Pathogens]` section defines the pathogens contained in the simulation.
You can define an arbitrary number of pathogens.
However, currently only the first pathogen is being loaded.
We are working on a multi-pathogen implementation.

Every pathogen must be defined via a dedicated section where the pathogen name is the section identifier:

```@TOML
[Pathogen]
    [Pathogens.Covid19]
        # Pathogen Parameters
        ...
```

The following sections present the parameters that can be specified for a named pathogen.

#### `transmission_function`

Defines the routine which is used to evaluate the infection probability for any contact.
This can as well be used to model immunity and waning.

```@TOML
[Pathogens]
    [Pathogens.Covid19]
        [Pathogens.Covid19.transmission_function]
            type = "ConstantTransmissionRate"
            [Pathogens.Covid19.transmission_function.parameters]
                transmission_rate = 0.2
                ...
```

The `type` argument specifies the `TransmissionFunction` that conditions the dispatching to the respective `transmission_probability(...)` function when running GEMS.
The subsequent `[....parameters]` section holds the arguments that the GEMS engine will pass to the `TransmissionFunction` struct upon initialization.
Look up the tutorial on creating [Custom Transmission Functions](@ref custom-transmission) for more explanations and examples.


#### `onset_of_symptoms`

Speficies the distribution that is being used to draw the duration from exposure to onset of symptoms upon infection.

```@TOML
[Pathogens]
    [Pathogens.Covid19]
        [Pathogens.Covid19.onset_of_symptoms]
            distribution = "Poisson"
            parameters = [3]
            ...
```

The `distribution` argument must be a distribution of the `Distributions.jl` package.
The `parameters` argument must contain a vector of arguments that are being passed to the distribution's constructor.


#### `time_to_recovery`

Speficies the distribution that is being used to draw the duration from onset of symptoms to recovery upon infection.

```@TOML
[Pathogens]
    [Pathogens.Covid19]
        [Pathogens.Covid19.time_to_recovery]
            distribution = "Poisson"
            parameters = [7]
            ...
```

The `distribution` argument must be a distribution of the `Distributions.jl` package.
The `parameters` argument must contain a vector of arguments that are being passed to the distribution's constructor.


#### `onset_of_severeness`

Speficies the distribution that is being used to draw the duration from onset of symptoms to the onset of severeness (for a severe progression) upon infection.

```@TOML
[Pathogens]
    [Pathogens.Covid19]
        [Pathogens.Covid19.onset_of_severeness]
            distribution = "Poisson"
            parameters = [3]
            ...
```

The `distribution` argument must be a distribution of the `Distributions.jl` package.
The `parameters` argument must contain a vector of arguments that are being passed to the distribution's constructor.


#### `infectious_offset`

Speficies the distribution that is being used to draw the duration that infectiousness sets on before the onset of symptoms upon infection.

```@TOML
[Pathogens]
    [Pathogens.Covid19]
        [Pathogens.Covid19.infectious_offset]
            distribution = "Poisson"
            parameters = [1]
            ...
```

The `distribution` argument must be a distribution of the `Distributions.jl` package.
The `parameters` argument must contain a vector of arguments that are being passed to the distribution's constructor.


#### `mild_death_rate`

Speficies the distribution that determines the death probability with a mild disease progression upon infection.

```@TOML
[Pathogens]
    [Pathogens.Covid19.mild_death_rate]
        distribution = "Binomial"
        parameters = [1, 0.0]
        ...
```

The `distribution` argument must be a distribution of the `Distributions.jl` package.
The `parameters` argument must contain a vector of arguments that are being passed to the distribution's constructor.


#### `severe_death_rate`

Speficies the distribution that determines the death probability with a severe disease progression upon infection.

```@TOML
[Pathogens]
    [Pathogens.Covid19.severe_death_rate]
        distribution = "Binomial"
        parameters = [1, 0.05]
        ...
```

The `distribution` argument must be a distribution of the `Distributions.jl` package.
The `parameters` argument must contain a vector of arguments that are being passed to the distribution's constructor.


#### `critical_death_rate`

Speficies the distribution that determines the death probability with a critical disease progression upon infection.

```@TOML
[Pathogens]
    [Pathogens.Covid19.critical_death_rate]
        distribution = "Binomial"
        parameters = [1, 0.2]
        ...
```

The `distribution` argument must be a distribution of the `Distributions.jl` package.
The `parameters` argument must contain a vector of arguments that are being passed to the distribution's constructor.


#### `hospitalization_rate`

Speficies the distribution that determines the hospitalization probability with a severe disease progression upon infection.

```@TOML
[Pathogens]
    [Pathogens.Covid19.hospitalization_rate]
        distribution = "Binomial"
        parameters = [1, 0.3]
        ...
```

The `distribution` argument must be a distribution of the `Distributions.jl` package.
The `parameters` argument must contain a vector of arguments that are being passed to the distribution's constructor.


#### `ventilation_rate`

Speficies the distribution that determines the ventilation probability with a critical disease progression upon infection.

```@TOML
[Pathogens]
    [Pathogens.Covid19.ventilation_rate]
        distribution = "Binomial"
        parameters = [1, 0.3]
        ...
```

The `distribution` argument must be a distribution of the `Distributions.jl` package.
The `parameters` argument must contain a vector of arguments that are being passed to the distribution's constructor.


#### `icu_rate`

Speficies the distribution that determines the probability of being admitted to ICU with a critical disease progression upon infection.

```@TOML
[Pathogens]
    [Pathogens.Covid19.icu_rate]
        distribution = "Binomial"
        parameters = [1, 0.3]
        ...
```

The `distribution` argument must be a distribution of the `Distributions.jl` package.
The `parameters` argument must contain a vector of arguments that are being passed to the distribution's constructor.


#### `time_to_hospitalization`

Speficies the distribution that is being used to draw the duration from onset of symptoms to hospitalization upon infection.

```@TOML
[Pathogens]
    [Pathogens.Covid19]
        [Pathogens.Covid19.time_to_hospitalization]
            distribution = "Poisson"
            parameters = [7]
            ...
```

The `distribution` argument must be a distribution of the `Distributions.jl` package.
The `parameters` argument must contain a vector of arguments that are being passed to the distribution's constructor.


#### `time_to_icu`

Speficies the distribution that is being used to draw the duration from hospitalization to ICU admittance upon infection.

```@TOML
[Pathogens]
    [Pathogens.Covid19]
        [Pathogens.Covid19.time_to_icu]
            distribution = "Poisson"
            parameters = [7]
            ...
```

The `distribution` argument must be a distribution of the `Distributions.jl` package.
The `parameters` argument must contain a vector of arguments that are being passed to the distribution's constructor.


#### `length_of_stay`

Speficies the distribution that is being used to draw the duration from hospitalization to release/recovery upon infection.

```@TOML
[Pathogens]
    [Pathogens.Covid19]
        [Pathogens.Covid19.length_of_stay]
            distribution = "Poisson"
            parameters = [7]
            ...
```

The `distribution` argument must be a distribution of the `Distributions.jl` package.
The `parameters` argument must contain a vector of arguments that are being passed to the distribution's constructor.


#### `dpr` (Disease Progression)

Defines the severity of the disease progression by age group.

```@TOML
[Pathogens]
    [Pathogens.Covid19.dpr]
        age_groups = ["0-10", "11+"]
        disease_compartments = ["Asymptomatic", "Mild", "Severe", "Critical"]
        stratification_matrix = [[0.40, 0.45, 0.10, 0.05],
                                 [0.45, 0.30, 0.20, 0.05]]
        ...
```

The `age_groups` argument defines the age ranges that are differentiated when evaluating the severity of disease progressions.
Make sure to pass a vector of strings that contain an integer range of age-values.
The "+" indicates that this is an "open-end" age range.
All possible ages must be covered, therefore, you should always have a trailing "open-end" age range.
The `disease_compartments` argument defines the categories of disease progressions that are being simulated.
In most cases, the defaults (`["Asymptomatic", "Mild", "Severe", "Critical"]`) should not be changed.
The `stratification_matrix` must be a matrix representation that matches the age groups (rows) with the severity categories (columns).
Each row must sum to `1`.


### Settings

The `[Settings]` section defines the rules for how contacts are being drawn in settings of the respective type.
Setting type-specific definitions are introduced by a new subsection with the setting type as an identifier:

```@TOML
[Settings]
    [Settings.Household]
    ...
```

#### [`contact_sampling_method`](@id config-contact-sampling)

Defines the routine which is used to draw contacts in settings of the respective type in each timestep (tick).

```@TOML
[Settings]
    [Settings.Household]
        [Settings.Household.contact_sampling_method]
                type = "ContactparameterSampling"
                [Settings.Household.contact_sampling_method.parameters]
                    contactparameter = 1.0
```

The `type` argument specifies the `ContactSamplingMethod` that conditions the dispatching to the respective `sample_contacts(...)` function when running GEMS.
The subsequent `[....parameters]` section holds the arguments that the GEMS engine will pass to the `ContactSamplingMethod` struct upon initialization.
Look up the tutorial on creating [Custom Contact Functions](@ref custom-contacts) for more explanations and examples.