# [Default Parameters](@id default-config)

This list shows the parameters that are applied when spawning a simulation without additional arguments like `sim = Simulation()`.

## Simulation
| Parameter | Value |
| :----------------------------------- | :------------------------------------------------------------------------------------------- |
| Time Unit | `days` |
| Global setting | `false` (single common setting for all individuals is deactivated) |
| Start date | `2024-01-01` |
| End date | `2024-12-31` |
| Start condition | `0.1%` randomly infected individuals |
| Stop criterion | Times up after `365` days |

## Population
| Parameter | Value |
| :----------------------------------- | :------------------------------------------------------------------------------------------- |
| Size | `100,000` individuals |
| Average household size | `3` individuals |
| Average office size | `5` individuals (everybody 18-65 years assigned) |
| Average school size | `100` individuals (everybody 6-18 years assigned); internally handled as `SchoolClass` |

## Pathogene
| Parameter | Value |
| :----------------------------------- | :------------------------------------------------------------------------------------------- |
| Number of Pathogenes | `1` |
| Name | `Covid19` |
| Transmission rate | `20%` infection chance for each contact (Constant Transmission Rate) |
| Progression assignment | Stratified by age groups (`-14`, `15-65`, `66-`) across 4 categories (`Asymptomatic`, `Mild`, `Severe`, `Critical`) |
| Infectiousness profile | `ConstantInfectiousness` (no changes between days, set to 100% each day) |
| **Asymptomatic Progression** | |
| Time to infectiousness | `1` day after exposure (Poisson-distributed) |
| Time to recovery | `8` days after infectiousness onset (Poisson-distributed) |
| **Mild Progression** | |
| Time to infectiousness | `1` day after exposure (Poisson-distributed) |
| Time to symptom onset | `1` day after infectiousness onset (Poisson-distributed) |
| Time to recovery | `7` days after symptom onset (Poisson-distributed) |
| **Severe Progression** | |
| Time to infectiousness | `1` day after exposure (Poisson-distributed) |
| Time to symptom onset | `1` day after infectiousness onset (Poisson-distributed) |
| Time to severeness onset | `1` day after symptom onset (Poisson-distributed) |
| Time to severeness offset | `7` days after severeness onset (Poisson-distributed) |
| Time to recovery | `4` days after severeness offset (Poisson-distributed) |
| **Critical Progression** (disease tier only; hospital/ICU/death are decided by the `HealthProgression`, below) | |
| Time to infectiousness | `1` day after exposure (Poisson-distributed) |
| Time to symptom onset | `1` day after infectiousness onset (Poisson-distributed) |
| Time to severeness onset | `1` day after symptom onset (Poisson-distributed) |
| Time to critical onset | `2` days after severeness onset (Poisson-distributed) |
| Time to critical offset | `7` days after critical onset (Poisson-distributed) |
| Time to severeness offset | `3` days after critical offset (Poisson-distributed) |
| Time to recovery | `4` days after severeness offset (Poisson-distributed) |
| **Health Progression** (host-level care/death; folds all of a host's active infections) | |
| Severe-tier hospital probability | `5%` |
| Severe-tier hospital admission | `2` days after severeness onset (Poisson-distributed) |
| Severe-tier hospital discharge | `10` days after admission (Poisson-distributed) |
| Critical-tier hospital probability | `95%`; admitted `1` day after critical onset |
| Critical-tier ICU probability | `50%` (of those admitted to the hospital, `47.5%` of all critical) |
| Critical-tier ventilation probability | `0%` (disabled by default) |
| Critical-tier death probability | `30%`, ungated by hospital/ICU |
| Critical-tier hospital admission | `1` days after severeness onset (Poisson-distributed) |
| Critical-tier hospital discharge | `10` days after admission when not admitted to ICU (Poisson-distributed) |
| Critical-tier ICU admission | `1` days after hospital admission (Poisson-distributed) |
| Critical-tier ICU duration | `8` days (Poisson-distributed) |
| Critical-tier ICU discharge | `5` days after ICU duration (Poisson-distributed) |
| Critical-tier death | `7` days after critical onset (Poisson-distributed) |

## Contacts
| Parameter | Value |
| :----------------------------------- | :------------------------------------------------------------------------------------------- |
| Base Setting contact rate | `1` contact per day (poisson distributed), randomly drawn from member list |
| *Any other setting* | If you load a population model with more setting types, they will have the same parameters |
