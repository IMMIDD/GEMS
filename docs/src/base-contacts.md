# Base Contact Model

GEMS is a discrete time simulation which means that time is explicitly modeled in timesteps (so-called ticks).
A tick, in the default configuration, has the duration of one day.
All contacts and the following infections that happen during one tick are calculated before incrementing to the next timestep.
The figure below illustrates what the GEMS engine does during **one** timestep.

```@raw html
<p align="center">
    <img src="../assets/base-contacts.png" width="80%"/>
</p>
```

We go through all *active* settings which are the ones that hold an infectious agent (explanation [here](@ref pop-layers)).
In each of the settings, we draw contacts *just* for the infected individuals as we are only interested in potentially infectious interactions.
Contacts between two non-infectious individuals are not being simulated.
The contacts for the individuals are drawn using the `contact_sampling_method` that was defined for the respective setting type.
In the default model, contacts are drawn randomly from the list of setting members.
After a contact was drawn, the pathogen's `transmission_function` will determine the probability of infection.
In the default model, this is a fixed rate for each contact.
However, a custom function can be used to reflect varying transmission probabilities based on agent characteristics (e.g., `age` or `vaccinations`).
Please look up the tutorials on [advanced parameterization](@ref advanced) to learn about the available options.