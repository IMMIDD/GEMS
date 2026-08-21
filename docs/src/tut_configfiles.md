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

Beyond the default progression categories (`Asymptomatic`, `Mild`, `Severe`, and `Critical`), GEMS allows you to specify custom disese progressions.
To do that, you need to define two things:
- A struct for your new progression that inherits from `ProgressionCategory` and
- A `calculate_progression()` function that defines the actual progression for an individual

A disease progression only describes the *disease* timeline (when an individual becomes infectious, symptomatic, severe, and so on).
Host-level care and mortality (hospitalization, ICU, ventilation, death) are decided separately by a [`HealthProgression`](@ref custom-health-progression), covered in the next section.

A custom progression is useful when the timeline itself needs logic the built-in tracks can't express, such as correlated transition times. Below, a single incubation draw drives both symptom onset *and* recovery, so individuals who start slowly are also ill for longer.

```julia
using GEMS, Distributions, Random, Parameters
import GEMS.calculate_progression

# define disease progression category struct
@with_kw mutable struct CorrelatedProgression <: GEMS.ProgressionCategory
    exposure_to_symptom_onset::Distribution
    illness_length_factor::Float64
end

# define progression calculation function
function GEMS.calculate_progression(individual::Individual, tick::Int16, dp::CorrelatedProgression;
    rng::AbstractRNG = Random.default_rng())

    # draw the incubation period once ...
    incubation = gems_rand(rng, dp.exposure_to_symptom_onset)
    symptom_onset = tick + Int16(1) + incubation
    # ... and let it drive the illness length too: a slow start means a long illness
    recovery = symptom_onset + Int16(1) + round(Int16, dp.illness_length_factor * incubation)

    return DiseaseProgression(
        exposure = tick,
        infectiousness_onset = symptom_onset, # infectiousness begins with symptoms
        symptom_onset = symptom_onset,
        recovery = recovery)
end

# set up a disease progression instance
my_prog = CorrelatedProgression(
    exposure_to_symptom_onset = Poisson(4),
    illness_length_factor = 3.0) # each incubation day adds ~3 days of illness

p = Pathogen(name = "TestProgression", progressions = [my_prog])
sim = Simulation(pathogen = p)
run!(sim)
```

Every infection now follows this custom timeline, with illness length tied to each individual's incubation period rather than drawn independently.

!!! info "DiseaseProgression struct"
    The `calculate_progression()` needs to return a `DiseaseProgression` struct. This struct contains discrete values for the time points when an individual transitions from one disease state into another. These events are: `exposure`, `infectiousness_onset`, `symptom_onset`, `severeness_onset`, `critical_onset`, `critical_offset`, `severeness_offset`, and `recovery`. The `DiseaseProgression` struct does internal validity checks (e.g., to prevent an individual from reaching critical severity without first passing through severeness onset). Please look up the `DiseaseProgression` documentation.

## [Custom Health Progression](@id custom-health-progression)

Hospitalization, ICU, ventilation, and death are decided separately from the disease timeline, by a `HealthProgression`. Unlike a disease progression, it sees *all* of a host's active infections at once, so a co-infected host's outcome can be decided jointly rather than by whichever infection "wins".

A policy does not write the host's care directly. It contributes `CareContribution`s — intervals of demand — and the host occupies a care level for as long as any contribution demands it. Overlapping contributions therefore produce one continuous stay, and contributions separated by a gap produce two separate episodes.

By default, GEMS applies a `DefaultHealthProgression`: `Severe` cases may be hospitalized, and `Critical` cases may escalate to ICU or ventilation and carry a death risk.

!!! tip "Single-pathogen convenience: inline care parameters"
    For a single pathogen you don't need a custom policy. Write the care parameters straight into the `Severe`/`Critical` progression and they are routed into the default policy automatically:
    ```julia
    Critical(...; hospital_probability = 0.9, hospital_to_icu_probability = 0.6, death_probability = 0.25)
    ```
    See the [config reference](@ref config-files) for the config-file form and the exact rules.

To go further, you can replace the policy entirely. Suppose we want a share of `severe` cases to die *without* ever being hospitalized — because death is host-level, this belongs in a health progression, not a disease one. Define a struct that inherits from `GEMS.HealthProgression` and a `calculate_health_progression!()` method: it `push!`es its care demand onto `contributions` and returns the death it proposes.

The method is invoked once per arriving infection, and `new_infection` is the one that triggered it.

!!! warning "Contribute only the increment"
    Contributions superpose and are never retracted, so a policy must contribute only what previous calls did not. Re-deriving the whole active set and contributing all of it again on every call leaves the host admitted for the rest of the run, and nothing detects it. The returned `HealthOutcome` is likewise this call's own contribution: GEMS folds it with the host's committed death (earliest wins), so returning an empty `HealthOutcome()` means "no mortality from this infection", not "cancel the scheduled death".

```julia
using GEMS, Distributions, Random, Parameters
import GEMS.calculate_health_progression!

# define custom health progression struct
@with_kw struct SevereWithDeathProgression <: GEMS.HealthProgression
    hospital_probability::Float64
    severeness_onset_to_hospital_admission::Union{Distribution, Real}
    hospital_admission_to_hospital_discharge::Union{Distribution, Real}
    death_probability::Float64
    severeness_onset_to_death::Union{Distribution, Real}
end

# override the health progression function for your struct. Every argument must be annotated:
# differing from the generic method only in `hp` is what keeps the override unambiguous
function GEMS.calculate_health_progression!(contributions::Vector{CareContribution},
    individual::Individual, infections::InfectionRegistry, hp::SevereWithDeathProgression,
    new_infection::InfectionState, tick::Int16, rng::Xoshiro)

    # a non-severe infection demands no host care
    new_infection.severeness_onset < 0 && return HealthOutcome()

    # nothing may be scheduled at or before the current tick
    onset = max(new_infection.severeness_onset, Int16(tick + 1))

    # a share of severe cases die (without any hospitalization) ...
    if gems_rand(rng) <= hp.death_probability
        death = round(Int16, onset + GEMS._rand_val(hp.severeness_onset_to_death, rng))
        return HealthOutcome(death = death, death_pathogen_id = new_infection.pathogen_id)

    # ... and a share are admitted to a normal ward
    elseif gems_rand(rng) <= hp.hospital_probability
        admission = round(Int16, onset +
            GEMS._rand_val(hp.severeness_onset_to_hospital_admission, rng))
        discharge = round(Int16, admission +
            GEMS._rand_val(hp.hospital_admission_to_hospital_discharge, rng))
        push!(contributions, CareContribution(CARE_HOSPITAL, admission, discharge))
    end

    return HealthOutcome()
end
```

`CareContribution(CARE_HOSPITAL, admission, discharge)` fills in every care level below the one you name, so contributing at `CARE_ICU` carries its ward cover automatically. To nest a short ICU stay inside a longer ward stay, use the keyword constructor instead.

To reason across a host's infections — coinfection synergy, say — iterate `each_infection(individual, infections)`. Two things to know when you do: it already includes `new_infection`, and a co-active infection's window may have started at or before `tick`, so clamp any overlap to `tick + 1` as above.

Now pass your policy to the `Simulation` via `health_progression`, reusing the built-in `Severe` progression so infections reach the severe state it reacts to:

```julia
sev = Severe(
    exposure_to_infectiousness_onset = Poisson(1),
    infectiousness_onset_to_symptom_onset = Poisson(1),
    symptom_onset_to_severeness_onset = Poisson(1),
    severeness_onset_to_severeness_offset = Poisson(7),
    severeness_offset_to_recovery = Poisson(4))

p = Pathogen(name = "SevereDisease", progressions = [sev])

hp = SevereWithDeathProgression(
    hospital_probability = 0.5, # 50% of severe cases are hospitalized
    severeness_onset_to_hospital_admission = Poisson(2),
    hospital_admission_to_hospital_discharge = Poisson(10),
    death_probability = 0.15,   # 15% of severe cases die, without hospitalization
    severeness_onset_to_death = Poisson(5))

sim = Simulation(pathogen = p, health_progression = hp)
run!(sim)
rd = ResultData(sim)
gemsplot(rd, type = :TickCases)
```

**Plot**

```@raw html
<p align="center">
    <img src="../assets/tutorials/tut_advanced_health-progression.png" width="60%"/>
</p>
```

The `deaths` series of the `:TickCases` plot now shows deaths from `severe` cases that never pass through the ICU. The `CareContribution` and `HealthOutcome` types are documented in the [Health Progression](@ref) API section.

As with the other custom types, you can also configure the policy from a config file via the top-level `[HealthProgression]` section:

```@TOML
### top-level HealthProgression section of the config file ###

[HealthProgression]
    type = "SevereWithDeathProgression"
    [HealthProgression.parameters]
        hospital_probability = 0.5
        death_probability = 0.15
        [HealthProgression.parameters.severeness_onset_to_hospital_admission]
            distribution = "Poisson"
            parameters = [2]
        [HealthProgression.parameters.hospital_admission_to_hospital_discharge]
            distribution = "Poisson"
            parameters = [10]
        [HealthProgression.parameters.severeness_onset_to_death]
            distribution = "Poisson"
            parameters = [5]
```

!!! warning "Module Visibility"
    As with custom transmission functions and progressions, if you define `SevereWithDeathProgression` in an external script or module, make sure it is loaded into your Julia environment *before* you initialize `Simulation("config.toml")`. The TOML parser needs the struct definition to exist in the global scope to build it.

## Custom Progression Assignment

In GEMS, disease progressions are split into two concepts: the **Progression** (the timeline of the disease) and the **Progression Assignment** (the logic that decides which timeline an infected individual gets). 

While the default model uses an `AgeBasedProgressionAssignment` to distribute cases based on age groups, you might want to assign disease tracks based on other individual attributes, such as their vaccination status.

Here is how you can create a custom assignment method that protects vaccinated individuals from severe progressions.

First, define a struct inheriting from `ProgressionAssignmentFunction`. We use the `@with_kw` macro so we can easily pass parameters from a TOML file later.

```julia
using GEMS
using Parameters, Random

@with_kw struct VaccBasedAssignment <: ProgressionAssignmentFunction
    # Probability of an unvaccinated person getting a severe progression
    prob_severe_unvaxxed::Float64 = 0.3 
end
```

Next, extend the `GEMS.assign` function. This function takes the individual, your custom assignment struct, and a random number generator. It must return the `DataType` of the progression category the individual should be assigned to (e.g., returning the type `Mild`, not an instance of it).

```julia
function GEMS.assign(individual::Individual, pa::VaccBasedAssignment, rng::AbstractRNG)
    
    # Check the custom attribute we might have assigned during population creation
    if individual.number_of_vaccinations > 0
        return Mild # Vaccinated individuals always get a mild track
    else
        # Unvaccinated individuals have a risk of severe progression
        if rand(rng) < pa.prob_severe_unvaxxed
            return Severe
        else
            return Mild
        end
    end
end
```

Finally, to use this in a simulation, you simply define it in your custom config file under the pathogen's `progression_assignment` block. We can overwrite the default value of our parameter.

```toml
[Pathogens.Covid19.progression_assignment]
    type = "VaccBasedAssignment"
    [Pathogens.Covid19.progression_assignment.parameters]
        prob_severe_unvaxxed = 0.5
```

When you load this config file using `sim = Simulation("path/to/config.toml")`, GEMS will automatically apply your custom vaccination-based logic to every newly infected individual using your `assign` function. We can easily verify that our custom assignment works by running two scenarios: one baseline where no individuals are vaccinated, and one where we manually vaccinate the entire population before running.

```julia
# Scenario 1: Baseline (0% Vaccinated)
sim_baseline = Simulation("path/to/config.toml", label = "0% Vaccinated")

# Scenario 2: 100% Vaccinated
sim_vaxxed = Simulation("path/to/config.toml", label = "100% Vaccinated")
foreach(i -> i.number_of_vaccinations = 1, individuals(sim_vaxxed))

run!(sim_baseline)
run!(sim_vaxxed)

rd_baseline = ResultData(sim_baseline)
rd_vaxxed = ResultData(sim_vaxxed)

gemsplot([rd_baseline, rd_vaxxed], type = :ProgressionCategories, xticks = [1, 18], combined = :bylabel)
```

**Plot**

```@raw html
<p align="center">
    <img src="../assets/tutorials/tut_custom_progression_assignment.png" width="80%"/>
</p>
``` 

As expected, the right plot shows that the vaccinated population experiences entirely symptomatic tracks and is completely protected from the `Severe` progression category!

## Custom Individual Extensions

Sometimes a study needs per-agent attributes that go beyond what `Individual` provides by default. GEMS lets you add these without changing the core model by passing `ind_extension` to the `Population` or `Simulation` constructor.

When extension data lives in a separate table, pass it directly as `ind_extension`. Individuals whose ID is not present receive a zero-filled value with a warning:

```julia
using GEMS
using DataFrames

pop = Population(DataFrame(
    id = Int32.(1:100), 
    age = Int8.(rand(20:60, 100)),
    sex = Int8.(rand(0:1, 100))
))

ext_df = DataFrame(id = Int32.(1:100), my_custom_attribute = rand(Float32, 100))

sim = Simulation(population = pop, ind_extension = ext_df)

ind = individuals(population(sim))[1]
show(ind)
```

**Output**

```
Individual
  ID:                          1
  Age:                         40
  Sex:                         female
  ...
  my_custom_attribute:         0.07483196
```

Extension fields are also accessible and mutable directly:

```julia
ind.my_custom_attribute        # e.g. 0.07483196
ind.my_custom_attribute = 0.9
```

If the extension data is already part of your population DataFrame, you can name the columns directly instead:

```julia
using GEMS
using DataFrames

pop = Population(DataFrame(
    id = Int32.(1:100),
    age = Int8.(rand(20:60, 100)),
    sex = Int8.(rand(0:1, 100)),
    my_custom_attribute = rand(Float32, 100)
); ind_extension = [:my_custom_attribute])

sim = Simulation(population = pop)
```

When extension values need to be computed from individual attributes (for example, assigning a parameter based on age) pass an `ind_extension` factory function to the constructor. It receives each base individual and returns an extension struct:

```julia
using GEMS

mutable struct MyParams
    my_custom_attribute::Float32
end

sim = Simulation(ind_extension = ind -> MyParams(age(ind) > 60 ? 0.8 : 0.3))
```

Or, if you define the extension as a keyword struct (`@kwdef`), the factory can construct it with keyword arguments. This keeps the call readable when the struct has many fields:

```julia
using GEMS

@kwdef mutable struct MyParams
    my_custom_attribute_a::Float32
    my_custom_attribute_b::Float32 
end

sim = Simulation(ind_extension = ind -> 
    MyParams(
        my_custom_attribute_a = age(ind) > 60 ? 0.8 : 0.3, 
        my_custom_attribute_b = rand(Float32)
    )
)
```

Extension fields behave exactly like built-in fields regardless of how they were created. All existing GEMS functions that accept `::Individual` continue to work on extended individuals unchanged.

!!! warning "Extension names must not collide with core fields"
    Extension fields share the `Individual` property namespace, so their names must differ from
    the built-in fields (e.g. `sex`, `age`, `household`, `office`, `number_of_vaccinations`, …).
    Reusing a core name is rejected at load time with an explicit error (otherwise `ind.sex`
    would silently return the built-in attribute instead of your value, and the population could
    not be exported back to a `DataFrame`). Rename the offending column or struct field.

!!! warning "Custom field reads are type-unstable"
    Extension data is stored in a boxed `extensions` field (typed `Any`), so reading a custom field
    such as `ind.my_custom_attribute` is **type-unstable**. This is harmless in most code, but if you
    read custom fields in a hot loop it can noticeably slow a simulation. See below for how to recover
    full type stability.

In practice the boxed read is cheap in custom `transmission_probability` / `sample_contacts!` methods, which are already reached through dynamic dispatch, so a single boxed read adds negligible cost there.

If you do heavy per-contact computation on custom fields and want full type stability, recover it with a *function barrier*: read the extension once and dispatch on its concrete type.

```julia
import GEMS.transmission_probability

# thin outer method: hands the concrete extension to a specialized inner function
GEMS.transmission_probability(tf::MyTransFunc, pathogen_id, infecter::Individual,
        infectee::Individual, setting, tick, sim, rng) =
    _tp(tf, infecter.extensions, infectee.extensions, pathogen_id, setting, tick, sim, rng)

# inner method specializes on MyExt, so ea/eb field access is fully type-stable
_tp(tf::MyTransFunc, ea::MyExt, eb::MyExt, pathogen_id, setting, tick, sim, rng) = # ...
```

## Custom Start Conditions

coming soon ...

## [Custom Contact Sampling](@id custom-contacts)

coming soon ...

