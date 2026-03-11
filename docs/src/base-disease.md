# Base Disease Model

## Disease Progression 

For a given pathogen we assume a disease progression that branches out depending on the severity of the infection.

```@raw html
<p align="center">
    <img src="../assets/disease_progression_diagram.png" width="90%"/>
</p>
```

An infected person will be considered exposed until they become infectious.
After this, they can stay without symptoms (resulting in asymptomatic cases) or progress through a disease pathway until leaving to the recovered or dead state.

Throughout GEMS we use the term "removed" for the state of an individual leaving this disease progression by either recovering from the disease or dying.
GEMS categorizes disease states internally using symbols (e.g., `:Symptomatic`, `:Critical`). Depending on the terminal state an individual reaches before being removed, we can categorize the infected individuals into the following progression tracks:

| **Symptoms Category** | **Terminal State** |
| :-------------------- | :----------------- |
| Asymptomatic          | Presymptomatic     |
| Symptomatic           | Symptomatic        |
| Severe                | Severe             |
| Hospitalized          | Hospitalized       |
| Critical              | Critical           |

As the symptom category and terminal state are closely related, the terms "exposed" and "asymptomatic" might be used synonymously, as well as "mild" and "symptomatic".
Furthermore, the progression for some symptom categories includes the need for hospitalization. Severe cases do not require hospitalization in the default config, but `Hospitalized` cases do. `Critical` cases will additionally require ICU admission (intensive care unit).
While asymptotic, symptomatic, severe, and hospitalized cases can't die by means of the disease in the default setup, critical cases are assigned a `30%` death probability.

## Infectiousness

The infectiousness of an individual is tracked separately from the disease state.
Generally an individual should become infectious some time after becoming exposed and before getting symptoms.
In asymptomatic cases, the individual will become infectious between becoming exposed and recovering from a disease.

## Age Stratification

To estimate the disease progression, we make use of age-stratified stochastic matrices passed to the `AgeBasedProgressionAssignment`.
As an example, consider three distinct age groups (`-14`, `15-65`, `66-`) as well as the five symptom categories mentioned above.
A possible age stratification matrix is given by the following $3 \times 5$ matrix:

```math
\begin{bmatrix}
    0.400 & 0.580 & 0.010 & 0.007 & 0.003 \\ 
    0.250 & 0.600 & 0.110 & 0.030 & 0.010 \\
    0.150 & 0.400 & 0.250 & 0.120 & 0.080
\end{bmatrix}
```

In this example, the first row contains the probability of an individual up to 14 years of age ending up in the progression categories "Asymptomatic", "Symptomatic", "Severe", "Hospitalized", or "Critical" in this order.

## True- vs. Observed Cases

We generally differentiate "true" cases and "observed" cases.
While a true case is an actual infection, an observed case is a recorded, thus "known" infection.
Not every true infection will automatically result in an observed infection. 
Depending on the specific pathogen, asymptomatic cases might be highly unlikely to get tested and thus will not be recorded.
In general, one must keep in mind that the number of unrecorded cases can only be roughly estimated in reality and highly depends on the testing strategy in place.
Depending on the kind of study you want to perform with GEMS, you will have to find a reasonable mechanism to map true to observed cases yourself.
You can, for example, evaluate this using a testing strategy via interventions or model it in postprocessing logic.