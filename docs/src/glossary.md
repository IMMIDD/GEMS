# Glossary

| Term | Definition |
| :--- | :--------- |
| Asymptomatic | A symptom category. An individual will not develop any symptoms. Its terminal state is "Presymptomatic". |
| Critical (State) | A state in the natural disease progression. An individual is in a critical condition with the need of hospitalization and possible need of ventilation or ICU.  |
| Critical (Symptom Category) | A symptom category. The individual will get into a critical condition during its disease progression with the need of hospitalization and possible need of ventilation. |
| Critical Death Rate | The probability of individuals with critical condition to die at the end of the natural disease progression. |
| Disease Progression | An individual's course through the disease states from initial exposure to recovery or death.|
| Disease Status | The status of an individual in the natural disease progression. Holds information about infectiousness and symptoms.|
| Exposed | The individual is infected, but is not yet infectious. |
| Exposure | Exposure to a pathogen is regarded as an infection event and marks the inception of a disease progression. |
| Generation Time | The time interval between the infections of the infector and infectee, two immediate successors in an infection chain. |
| Hospitalization Status | States if an individual is hospitalized and if additional measures have to be applied (ventilation, ICU). |
| Hospitalization Rate | The probability of an individual with severe symptoms to need hospitalization. |
| ICU | Short for Intensive Care Unit. An hospitalization state. Individuals are in the hospital and in the ICU. |
| ICU Rate | The probability of an individual in critical condition to need ICU. |
| Individual | The representation of a person. It has different attributes and can become infected inside settings. |
| Infection Rate | Basic risk of getting infected upon infectious contact |
| Infectious Offset | An offset from the onset of symptoms. Determines if an individual becomes infectious before becoming symptomatic. Is also used for asymptomatic cases to determine the start of infectiousness. |
| Infectious | The individual is infectious, if it can infect other individuals. | 
| Infectiousness | Measurement of how infectious an individual is. Reminiscent of viral load. |
| (Intervention) Measure | A single intervention-related activity changing one distinct state variable in the simulation model (e.g. closing a particular school). |
| (Intervention) Strategy | A collection of intervention measures which are executed in chronological order. |
| (Intervention) Trigger | An event that causes an intervention strategy to be executed (e.g. an individual starting to experience symptoms). |
| Isolation | As of now defined as "household isolation". An individual staying in its household while still being able to have contacts to other household members. |
| Length of Stay | The time an individual will spend inside the hospital. |
| Mild | An individual will only develop mild symptoms. Its terminal state is "Symptomatic". |
| Mild Death Rate | The probability of individuals with mild symptoms to die at the end of the natural disease progression. |
| Onset of Symptoms | The time when symptoms start. Is generally calculated and given as an increment to the tick, when an infection happened. |
| Onset of Severeness | The time when symptoms become severe as an increment to the onset of symptoms. |
| Pathogen | An enclosure to collect disease-related parameters such as infection rates or the delay until the onset of symptoms. |
| Presymptomatic | A state in the natural disease progression. The individual is infected but does not experience symptoms yet. |
| Removed | The state of an individual being recovered or dead |
| Setting | Some sort of context in which contacts can happen. Those can be Households or Offices or more abstract settings like social networks. |
| Severe (State) | A state in the natural disease progression. The individual has severe symptoms with the potential need to be hospitalized. |
| Severe (Symptom Category) | A symptom category. An individual will develop severe symptoms and has possibly the need to be hospitalized. Its terminal state is "Severe". |
| Severe Death Rate | The probability of individuals with severe symptoms to die at the end of the natural disease progression. |
| Symptom Category | Categorization of the disease progression regarding the occurring symptoms. |
| Symptomatic | A state in the natural disease progression. The individual has symptoms, but they aren't severe. |
| Terminal State | The last state reached by an individual in the disease progression before being removed |
| TestType | Parameterizing a certain type of test (e.g. PCR or Antigen). |
| Test Sensitivity | A test's ability to positively identify an infected individual. |
| Time to Hospitalization | If an individual will need hospitalization eventually, this defines the time between the onset of symptoms and hospitalization. |
| Time to ICU | If an individual will need ICU eventually, this defines the time between the time to hospitalization and the delivery into ICU. |
| Time to Recovery | The time it takes an individual to recover from an infection as an increment from the onset of symptoms. If an individual will die at the end of the natural disease progression, this will (also) define the time of death. |
| Ventilated | An hospitalization state. Individuals are in the hospital, in the ICU and receive ventilation. |
| Ventilation Rate | The probability of an individual in the ICU to need ventilation. |