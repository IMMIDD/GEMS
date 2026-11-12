# Base Contact Model

GEMS is a discrete time simulation: time advances in ticks, one day by default.
All contacts and infections of one tick are computed before the next tick starts.

In each tick, GEMS goes through every infectious individual and the settings they belong to: those in their activity plan, the containers above those (e.g. the school year and school above a class), and the global setting if there is one.
In each setting, it draws the individual's contacts with that setting type's `contact_sampling_method`, by default uniformly among the setting's members.
Contacts between two non-infectious individuals are not simulated.
For each contact, the pathogen's `transmission_function` gives the infection probability: a fixed rate by default, or a custom function of e.g. `age` or `vaccinations`.

## Absent Members

A dead or removed member leaves the setting: a household of four with one death draws like a household of three.
A hospitalized, homebound or quarantined member, or a member of a closed setting, stays in it, but contacts drawn on them are dropped and they spread nothing there.
Household quarantine and homebound individuals still meet their household.

In a hierarchy, a closed class stays part of its school; its members neither meet nor infect anyone at school level.
`close!(school)` stops only the school-wide contacts, while `close!(school, sim)` also closes every setting below it.

## Contact Scales

A membership's scale is its contacts relative to a regular member (scale 1).
At scale 0.5, someone draws half the contacts of a regular member there and is drawn as a contact half as often; a pair meets at a rate proportional to the product of their two scales.
Someone working half-time in each of two offices has scale 0.5 in each.
In a setting above both offices, such as their department, their scales add up, capped at the larger of 1 and their largest scale, so they count as one regular member there.

## Contact Counts

`contactparameter` is the expected number of contacts drawn per tick, with replacement: someone drawn twice gets two transmission trials.
