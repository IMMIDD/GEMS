# Base Disease Model

## Disease Progression 

For a given pathogen we assume a disease progression that branches out depending on the severity of the infection.

```@raw html
<p align="center">
    <img src="../assets/disease_progression_diagram.png" width="90%"/>
</p>
```

!!! warning "Diagram pending update"
    The diagram above still depicts the pre-decoupling model, where hospitalization, ICU, ventilation, and death appear as part of the disease path. These are now host-level outcomes decided by a separate `HealthProgression` (see below) and are no longer part of the disease progression. The diagram is pending regeneration.

An infected person will be considered exposed until they become infectious.
After this, they can stay without symptoms (resulting in asymptomatic cases) or progress through a disease pathway until recovering.

Throughout GEMS we use the term "removed" for the state of an individual leaving a disease progression, either by recovering or by dying.
GEMS categorizes disease states internally using symbols (e.g., `:Mild`, `:Critical`). Depending on the peak severity an individual reaches, we can categorize the infected individuals into the following progression tracks:

| **Symptoms Category** | **Terminal State** |
| :-------------------- | :----------------- |
| Asymptomatic          | Presymptomatic     |
| Mild                  | Symptomatic        |
| Severe                | Severe             |
| Critical              | Critical           |

As the symptom category and terminal state are closely related, the terms "exposed" and "asymptomatic" might be used synonymously, as well as "mild" and "symptomatic".

Host-level care and mortality (hospitalization, ICU, ventilation, death) are **not** part of the
disease progression: they are decided by a separate `HealthProgression`, which folds the demand of
*all* of a host's currently active infections into one host-level care timeline. This is what lets a
host who is concurrently infected with multiple pathogens have their hospitalization or death
decided jointly, rather than by whichever single infection happens to "win". Each infection
contributes when it arrives, and the policy is told what the host is already committed to, so an
infection whose contribution has been decided is never re-decided by a later co-infection. In the default
configuration, only `Severe` and `Critical` infections demand any host care: a `Severe`-peak
infection may lead to a ward admission; a `Critical`-peak infection may additionally require ICU
admission (and, optionally, ventilation), and carries an ungated `30%` death probability. In the
default configuration, all care and timing offsets (admission delays and stay lengths) are drawn
from Poisson distributions; see the `health` block on each progression in `DefaultConf.toml` for the
concrete parameters. See the "Health Progression" section of the pathogen API reference for the
extension API.

## Infectiousness

The infectiousness of an individual is tracked separately from the disease state.
Generally an individual should become infectious some time after becoming exposed and before getting symptoms.
In asymptomatic cases, the individual will become infectious between becoming exposed and recovering from a disease.

## Age Stratification

To estimate the disease progression, we make use of age-stratified stochastic matrices passed to the `AgeBasedProgressionAssignment`.
As an example, consider three distinct age groups (`-14`, `15-65`, `66-`) as well as the four symptom categories mentioned above.
A possible age stratification matrix is given by the following $3 \times 4$ matrix:

```math
\begin{bmatrix}
    0.400 & 0.580 & 0.017 & 0.003 \\ 
    0.250 & 0.600 & 0.140 & 0.010 \\
    0.150 & 0.400 & 0.370 & 0.080
\end{bmatrix}
```

In this example, the first row contains the probability of an individual up to 14 years of age ending up in the progression categories "Asymptomatic", "Mild", "Severe", or "Critical" in this order.

## True- vs. Observed Cases

We generally differentiate "true" cases and "observed" cases.
While a true case is an actual infection, an observed case is a recorded, thus "known" infection.
Not every true infection will automatically result in an observed infection. 
Depending on the specific pathogen, asymptomatic cases might be highly unlikely to get tested and thus will not be recorded.
In general, one must keep in mind that the number of unrecorded cases can only be roughly estimated in reality and highly depends on the testing strategy in place.
Depending on the kind of study you want to perform with GEMS, you will have to find a reasonable mechanism to map true to observed cases yourself.
You can, for example, evaluate this using a testing strategy via interventions or model it in postprocessing logic.