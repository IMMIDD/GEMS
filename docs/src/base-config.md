# [Default Parameters](@id default-config)

This list shows the parameters that are applied when spawning a simulation without additional arguments like `sim = Simulation()`.

| Parameter | Value |
| :----------------------------------- | :------------------------------------------------------------------------------------------- |
| **Simulation** | |
| Time Unit | `days` |
| Global setting | `false` (single common setting for all individuals is deactivated) |
| Start date | `2024-01-01` |
| End date | `2024-12-31` |
| Start condition | `0.1%` randomly infected individuals |
| Stop criterion | Times up after `365` days |
| **Population** | |
| Size | `100,000` individuals |
| Average household size | `3` individuals |
| Average school size | `100` individuals (everybody 6-18 years assigned); internally handled as `SchoolClass` |
| Average office size | `5` individuals (everybody 18-65 years assigned) |
| **Pathogen** | |
| Name | `Covid19` |
| Transmission rate | `20%` infection chance for each contact (Constant Transmission Rate) |
| Progression assignment | Stratified by age groups (`-14`, `15-65`, `66-`) across 5 categories (`Asymptomatic`, `Symptomatic`, `Severe`, `Hospitalized`, `Critical`) |
| **Asymptomatic Progression** | |
| Time to infectiousness | `1` day after exposure (Poisson-distributed) |
| Time to recovery | `8` days after infectiousness onset (Poisson-distributed) |
| **Symptomatic Progression** | |
| Time to infectiousness | `1` day after exposure (Poisson-distributed) |
| Time to symptom onset | `1` day after infectiousness onset (Poisson-distributed) |
| Time to recovery | `7` days after symptom onset (Poisson-distributed) |
| **Severe Progression** | |
| Time to infectiousness | `1` day after exposure (Poisson-distributed) |
| Time to symptom onset | `1` day after infectiousness onset (Poisson-distributed) |
| Time to severeness onset | `1` day after symptom onset (Poisson-distributed) |
| Time to severeness offset | `7` days after severeness onset (Poisson-distributed) |
| Time to recovery | `4` days after severeness offset (Poisson-distributed) |
| **Hospitalized Progression** | |
| Time to infectiousness | `1` day after exposure (Poisson-distributed) |
| Time to symptom onset | `1` day after infectiousness onset (Poisson-distributed) |
| Time to severeness onset | `1` day after symptom onset (Poisson-distributed) |
| Time to hospital admission | `2` days after severeness onset (Poisson-distributed) |
| Time to hospital discharge | `7` days after hospital admission (Poisson-distributed) |
| Time to severeness offset | `3` days after hospital discharge (Poisson-distributed) |
| Time to recovery | `4` days after severeness offset (Poisson-distributed) |
| **Critical Progression** | |
| Critical Death Rate | `30%` for cases hitting the critical ICU pathway |
| Time to infectiousness | `1` day after exposure (Poisson-distributed) |
| Time to symptom onset | `1` day after infectiousness onset (Poisson-distributed) |
| Time to severeness onset | `1` day after symptom onset (Poisson-distributed) |
| Time to hospital admission | `2` days after severeness onset (Poisson-distributed) |
| Time to ICU admission | `2` days after hospital admission (Poisson-distributed) |
| Time to ICU discharge | `7` days after ICU admission (Poisson-distributed, if recovering) |
| Time to hospital discharge | `7` days after ICU discharge (Poisson-distributed, if recovering) |
| Time to severeness offset | `3` days after hospital discharge (Poisson-distributed, if recovering) |
| Time to recovery | `4` days after severeness offset (Poisson-distributed, if recovering) |
| Time to death | `10` days after ICU admission (Poisson-distributed, if dying) |
| **Contacts** | |
| Household contact rate | `1` contact per day (poisson distributed), randomly drawn from member list |
| School contact rate | `1` contact per day (poisson distributed), randomly drawn from member list |
| Office contact rate | `1` contact per day (poisson distributed), randomly drawn from member list |
| *Any other setting* | If you load a population model with more setting types, they will have the same parameters |