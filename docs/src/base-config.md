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
| Progression assignment | Stratified by age groups (`-14`, `15-65`, `66-`) across 4 categories (`Asymptomatic`, `Mild`, `Severe`, `Critical`) |
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
| Severe-tier hospital probability | `5%`; admitted `2` days after severeness onset, ward stay `10` days (Poisson-distributed) |
| Critical-tier hospital probability | `95%`; admitted `1` day after critical onset |
| Critical-tier ICU probability | `50%` of hospitalized; admitted `1` day after hospital admission, ICU stay `8` days if not ventilated |
| Critical-tier ventilation probability | `0%` (disabled by default) |
| Critical-tier death probability | `30%`, ungated by hospital/ICU; `7` days after critical onset |
| Ward stay after ICU discharge | `5` days (Poisson-distributed) |
| **Contacts** | |
| Household contact rate | `1` contact per day (poisson distributed), randomly drawn from member list |
| School contact rate | `1` contact per day (poisson distributed), randomly drawn from member list |
| Office contact rate | `1` contact per day (poisson distributed), randomly drawn from member list |
| *Any other setting* | If you load a population model with more setting types, they will have the same parameters |