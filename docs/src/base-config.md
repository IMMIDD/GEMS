# [Default Parameters](@id default-config)

This list shows the parameters that are applied when spawning a simulation without additional arguments like `sim = Simulation()`.

| Parameter                            | Value                                                                                        |
| :----------------------------------- | :------------------------------------------------------------------------------------------- |
| **Simulation**                       |                                                                                              |
| Time Unit                            | `days`                                                                                       |
| Global setting                       | `false` (single common setting for all individuals is deactivated)                           |
| Setting types                        | `Household`, `SchoolClass`, `Office`                                                         |
| Start date                           | `2024.01.01`                                                                                 |
| End date                             | `2024.12.31`                                                                                 |
| Start condition                      | `0.1%` randomly infected individuals                                                         |
| **Population**                       |                                                                                              |
| size                                 | `100,000` individuals                                                                        |
| Average household size               | `3` individuals                                                                              |
| Average school size                  | `100` individuals (everybody 6-18 years assigned); internally handled as `SchoolClass`       |
| Average office size                  | `5` individuals (everybody 18-65 years assigned)                                             |
| **Pathogen**                         |                                                                                              |
| Name                                 | `Covid19`                                                                                    |
| Transmission rate                    | `20%` infection chance for each contact                                                      |
| Symptom onset                        | `3` days after infection (Poisson-distributed)                                              |
| Time to recovery                     | `7` days after symptom onset (Poisson-distributed)                                          |
| Severeness onset                     | `3` days after symptom onset (Poisson-distributed)                                          |
| Infectious offset                     | `1` days before symptom onset (Poisson-distributed)                                         |
| Death rate with mild progression     | `0%`                                                                                         |
| Death rate with severe progression   | `5%`                                                                                         |
| Death rate with critical progression | `20%`                                                                                        |
| Hospitalization rate                 | `30%` with severe- and `100%` with critical progression                                      |
| Time to Hospitalization              | `7` days after symptom onset (Poisson-distributed)                                          |
| Length of (hospital) stay            | `7` days (Poisson-distributed)                                                              |
| Disease progressions                 | `40%` asymptomatic, `45%` mild, `10%` severe, `5%` critical, age-independent                 |
| **Contacts**                         |                                                                                              |
| Household contact rate               | `1` contact per day (poisson distributed), randomly drawn from member list                   |
| School contact rate                  | `1` contact per day (poisson distributed), randomly drawn from member list                   |
| Office contact rate                  | `1` contact per day (poisson distributed), randomly drawn from member list                   |
| *Any other setting*                  | If you load a population model with more setting types, they will have the same parameters   |