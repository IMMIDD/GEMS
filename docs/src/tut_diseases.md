# 4 - Configuring Diseases

This tutorial will teach you how to configure disease progressions and the assignment of progressions upon infection.

!!! warning "Caution"
    If you pass a `Pathogen` to the `Simulation` constructor, it will override the `transmission_function` or `transmission_rate` parameters. This means, that you need to manually pass you transmission parameters if you want to deviate from the default.

## Static Symptomatic Progression

In this example, we want to configure a disease where all infections lead to a symptomatic progression.
You can display the available progression categories (e.g., `Symptomatic` or `Critical`) via the `progression_categories()` function:

```julia
progression_categories()
```

**Output**

```
5-element Vector{Any}:
 Asymptomatic
 Critical
 Hospitalized
 Severe
 Symptomatic
```

!!! info "How do I find out how to define any of the progressions?"
    Put a `?` into the Julia REPL and call `help?> Symptomatic` (or another progression) to learn about the parameters the constructor requires.

Let's set up a symptomatic progression where each agent will become infectious after two days.
They will then become symptomatic one day three and recover one week later.
Notice that all progression will have a minimum exposure of `1` and all additional parameters will be added on top.
The `Pathogen` struct combines all disease-related parameters.

```julia
using GEMS
symp = Symptomatic(
    exposure_to_infectiousness_onset = 1, # 1+1
    infectiousness_onset_to_symptom_onset = 1,
    symptom_onset_to_recovery = 7)

p = Pathogen(
    name = "10Day-Disease",    
    progressions = [symp])

sim = Simulation(pathogen = p)
run!(sim)
rd = ResultData(sim)
gemsplot(rd, type = (:TickCases, :InfectionDuration, :ProgressionCategories))
```

**Plot**

```@raw html
<p align="center">
    <img src="../assets/tutorials/tut_diseases_static.png" width="60%"/>
</p>
``` 

The middle plot shows that all infections take exactly 10 days and the bottom plot indicates that all progressions were symptomatic.


## Dynamic Symptomatic Progression

This example takes the previous model but instead of using fixed times for the durations, we pass Poisson distributions that get the previous paramters as the lambda values:

```julia
using GEMS, Distributions
symp = Symptomatic(
    exposure_to_infectiousness_onset = Poisson(1), # 1+1
    infectiousness_onset_to_symptom_onset = Poisson(1),
    symptom_onset_to_recovery = Poisson(7))

p = Pathogen(
    name = "10Day-Disease",    
    progressions = [symp])

sim = Simulation(pathogen = p)
run!(sim)
rd = ResultData(sim)
gemsplot(rd, type = (:TickCases, :InfectionDuration, :ProgressionCategories))
```

**Plot**

```@raw html
<p align="center">
    <img src="../assets/tutorials/tut_diseases_dynamic.png" width="60%"/>
</p>
```

As you can see, the disease durations are now drawn from distributions.

!!! info "Can I use other distributions than Poisson?"
    Yes, you can use any distribution from the `Distributions.jl` package and even create your own distribution using their framework.


## Multiple Progressions

In this example we want to have two progressions: short asymptomatic and long symptomatic progressions.
If nothing else is specified, the `Pathogen` class will assign a progression category at random upon infection.

```julia
using GEMS, Distributions
asymp = Asymptomatic(
    exposure_to_infectiousness_onset = Poisson(1), # 1+1
    infectiousness_onset_to_recovery = Poisson(2))
symp = Symptomatic(
    exposure_to_infectiousness_onset = Poisson(1), # 1+1
    infectiousness_onset_to_symptom_onset = Poisson(2),
    symptom_onset_to_recovery = Poisson(14))

p = Pathogen(
    name = "Two-Peaks-Disease",    
    progressions = [asymp, symp])

sim = Simulation(pathogen = p)
run!(sim)
rd = ResultData(sim)
gemsplot(rd, type = (:TickCases, :InfectionDuration, :ProgressionCategories))
```

**Plot**

```@raw html
<p align="center">
    <img src="../assets/tutorials/tut_diseases_multiprogression.png" width="60%"/>
</p>
```

In the infection duration plot, we see two peaks.
One is caused by the short asymptomatic infections and one by the much longer symptomatic progressions.
The bottom plot shows that all the number of asymptomatic and symptomatic progressions are roughly the same across the age groups (caused by the random progression assignment).


## Age-based Progression Assignment

Let's consider we want to parameterize a disease that causes symptomatic progressions for kids under the age of 15 and is asymptomatic for all older people.
For this, we use the `ProgressionAssingment` struct.
the `AgeBasedProgressionAssignment` takes age-groups and progressions, and a stratification matrix that provides the chances of any agent of a particular age group ending up in any of the defined progressions.

```julia
using GEMS, Distributions
asymp = Asymptomatic(
    exposure_to_infectiousness_onset = Poisson(1), # 1+1
    infectiousness_onset_to_recovery = Poisson(2))
symp = Symptomatic(
    exposure_to_infectiousness_onset = Poisson(1), # 1+1
    infectiousness_onset_to_symptom_onset = Poisson(2),
    symptom_onset_to_recovery = Poisson(14))

pass = AgeBasedProgressionAssignment(
    age_groups = ["0-14","15-"],
    progression_categories = ["Asymptomatic", "Symptomatic"],
    stratification_matrix = [[0.0, 1.0],
                             [1.0, 0.0]])

p = Pathogen(
    name = "Two-Peaks-Disease",
    progressions = [asymp, symp],
    progression_assignment = pass)

sim = Simulation(pathogen = p)
run!(sim)
rd = ResultData(sim)
gemsplot(rd, type = (:TickCases, :InfectionDuration, :ProgressionCategories))
```

**Plot**

```@raw html
<p align="center">
    <img src="../assets/tutorials/tut_diseases_age_assignment.png" width="60%"/>
</p>
```


## Complete Parameterization

This example will show you how to parameterize disease progressions, assignments and the tranmission function inside a `Pathogen`.

```julia
using GEMS, Distributions
asymp = Asymptomatic(
    exposure_to_infectiousness_onset = Poisson(1), # 1+1
    infectiousness_onset_to_recovery = Poisson(2))
symp = Symptomatic(
    exposure_to_infectiousness_onset = Poisson(1), # 1+1
    infectiousness_onset_to_symptom_onset = Poisson(2),
    symptom_onset_to_recovery = Poisson(14))

pass = AgeBasedProgressionAssignment(
    age_groups = ["0-14","15-"],
    progression_categories = ["Asymptomatic", "Symptomatic"],
    stratification_matrix = [[0.0, 1.0],
                             [1.0, 0.0]])

ctf = ConstantTransmissionRate(transmission_rate = 0.25)

p = Pathogen(
    name = "Two-Peaks-Disease",
    progressions = [asymp, symp],
    progression_assignment = pass,
    transmission_function = ctf)

sim = Simulation(pathogen = p)
run!(sim)
rd = ResultData(sim)
gemsplot(rd, type = (:TickCases, :InfectionDuration, :ProgressionCategories))
```

**Plot**

```@raw html
<p align="center">
    <img src="../assets/tutorials/tut_diseases_complete.png" width="60%"/>
</p>
```