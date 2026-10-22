# [6 - Creating Populations](@id tut_pops)

If you spawn the default scenario like `sim = Simulation()`, GEMS will generate a non-representative population with `100,000` individuals households of average size `3`, schools/school classes of average size `100` and workplaces/offices of average size `5`.
The age distribution and household compositions is similar to the German population (not accurate, not representative).

Beyond that, GEMS has a variety of options to load or generate custom population models.


## Using Parameters

You can change the default parameters mentioned above like this:

```julia
using GEMS
sim = Simulation(pop_size = 50_000, avg_school_size = 20)
```

Available parameter options are: `pop_size`, `avg_household_size`, `avg_office_size`, and `avg_school_size`.


## Using Dataframes

You can generate a custom population from a dataframe.
This dataframe needs to have one row per individual and the columns must be named identical to the fields of the `Individual` struct.
Every individual needs at least an `id`, an `age` and a `sex`.
Therefore, these are the minimal requirements for column in your dataframe.
The example below generates a synthetic population of `100,000` individuals with random ages from `1 to 100` and two individuals per household.
This is achieved via the `household` column as two individuals with the same value will be placed in the same households.
The example assigns each value from `1 to 50_000` to two of the individuals.

```julia
using GEMS, DataFrames
pop_df = DataFrame(
    id = collect(1:100_000),
    age = rand(1:100, 100_000),
    sex = rand(1:2, 100_000),
    household = append!(collect(1:50_000), collect(1:50_000))
)
my_pop = Population(pop_df)
sim = Simulation(population = my_pop)
```

If you want to check whether the generation worked and actually only generated two-person households, you can use the `Plots.jl` package to generate a simple histogram of the household sizes.
The `.` following the `size` function indicates that this function is applied to all elements in a vector separately; in the example to all households of the simulation.

```julia
using Plots
hh_sizes = size.(households(sim))
histogram(hh_sizes, xlims = (0, 10))
```

**Plot**

```@raw html
<p align="center">
    <img src="../assets/tutorials/tut_pops_households.png" width="80%"/>
</p>
``` 


We don't need to run this simulation as there is no setting except households.
Therefore we won't see many infections.

!!! info "Where's the list of columns I can create?"
    Put a `?` into the Julia REPL and call `help?> Individual` to get an overview of fields that are stored for each individual or look up the Individuals section of the API documentation.


## Using Inbuilt Models

GEMS comes with inbuilt population models for each of the German states as well as a full model of Germany (attention: very large; requires 100+GB of system memory to run).
You can load such a model via the state code (e.g. `MV` for the state of Mecklenburg-Vorpommern) like this:

```julia
using GEMS
sim = Simulation(population = "MV")
```

Loading a new population model for the first time will spark a download of the file.
The inbuilt models are geo-referencal, therefore they can be visualized using the `gemsmap()` function (e.g., to take a look at the population density):

```julia
gemsmap(sim, type = :PopDensityMap)
```


**Plot**

```@raw html
<p align="center">
    <img src="../assets/tutorials/tut_pops_popdensity.png" width="80%"/>
</p>
``` 


Geo-referential models are fundamentally the same as all other models but have the AGS-field (german community identification number) set for geo-referenced settings.
Additionally, they can have a `lat`/`lon` value pair stored, which allows to track infection locations.
Putting this data into a model manually requires the use of a settings-file (see section below).

## Using Population Files

Both, CSV- and JLD2-files can be used to load population models from the harddrive.
This way, you can load populations that originate from other projects or tools (like R).

CSV-files must adhere to the same data structure as in the "Using Dataframes" section.
They are basically just an export of the generated dataframe.
Here's an example file:

```csv
id,age,sex,household
1,12,0,1
2,75,1,1
3,35,1,2
4,63,0,2
5,32,1,2
```

The JLD2-variant needs to store a dictionary with one key called `data` that contains a dataframe such as presented above in the "Using Dataframes" section.

To load such a file, simply pass the filepath as the `population` argument to the `Simulation()` function:

```julia
sim = Simulation(population = "path/to/my/population_file.csv")
```

## Using Settings-Files

All of the above examples that create populations manually, rely on input data that link individuals to a specific setting (e.g., putting an individual into a particular `Office`).
However, GEMS also provides the option to consider hierarchical setting structures (e.g., multiple `Office`s forming a `Department`) to not only allow within-setting contacts but also between-setting contacts of a confined pool of subsettings.
A so-called "settings-file" can be passed to superimpose a hierarchical setting structure:

```julia
sim = Simulation(population = "path/to/my/population.jld2", settingsfile = "path/to/my/settings.jld2")
```

Please be aware, that a settings-file usually belongs to a specific population-file as the setting-IDs require an exact matching.
Look up the settings-file section of the API documentation to learn about the internal structure of settings-files.


## Memberships Beyond the Population File

A population's membership columns, such as `household`, give each individual one setting per type: their *primary* setting of that type.
Further memberships, e.g., a second office or a gym, can come from a table or be generated with *setting layers*.
They can add settings of a type an individual already has, or of a type the population has no column for.
Both can be combined, as layers are added on top of the memberships a population already has.

### From a Memberships File

A memberships table has one row per setting:

```csv
id,setting_type,setting_id,scale
1,Household,3,1.0
4,Office,7,0.5
```

Each row adds one membership: the individual with that `id` joins the setting with that `setting_id` of type `setting_type`.
The type can be any setting type that holds individuals directly, including custom ones (see [Custom Setting Types](@ref custom-setting-types)), but not containers such as `Department`.
For a type the population file has a column for, the setting in that column stays the individual's primary one, and the rows of the table follow it in file order.
For a type without a column (e.g. a `Gym`), the first row of an individual becomes their primary setting.

Two optional columns change how a row is read:

- `scale`: the contact scale of this membership relative to a regular member, e.g. `0.5` for someone who spends half the usual time there. A row that names the same setting as the population file only changes the scale of that membership.
- `primary` (`true`/`false`): makes the row the individual's primary setting of its type. This only works if the population file doesn't name one for that type.

GEMS checks the table when it loads it and throws an error for an individual or type that doesn't exist, for a setting given to the same individual twice, and for a second primary setting of one type.

The settings file doesn't change memberships.
It adds the settings' attributes (e.g. their location) and their containers, matched by setting ID, also for settings that only the memberships table names.
A setting whose ID isn't in the settings file has no container.

Pass the table alongside a CSV population file, the same way as a settings file:

```julia
sim = Simulation(population = "path/to/my/population_file.csv", membershipsfile = "path/to/my/memberships.csv")
```

A JLD2 population file can instead store the table under the key `memberships`, which GEMS reads automatically.
For a population built from a dataframe, pass the table as a dataframe: `Population(pop_df; memberships = memberships_df)`.
`memberships(population)` returns the table as a dataframe, and `save(population, path; membershipsfile = ...)` writes both files.
Saving a population writes every membership that doesn't fit into its columns, including scaled ones, so loading both files rebuilds the same population.

### [Generated with Setting Layers](@id setting-layers)

Membership columns and tables require you to know who goes where.
Often, you only know what a setting looks like on average, e.g., that 30% of all adults visit a gym with about 20 members.
A *setting layer* turns such a description into settings and members.
Each layer adds settings of one type to the individuals' activity plans before the simulation builds its settings.

This layer gives 10% of all workers a second office:

```julia
using GEMS
second_jobs = SettingLayer(Office;
    assignment = JoinExisting(),
    holding = Office,
    participation = 0.1)
sim = Simulation(setting_layers = second_jobs)
```

`holding = Office` restricts the layer to individuals who already have an office, and `JoinExisting()` picks each second office among the existing ones, in proportion to their number of members.
The first office stays the individual's primary office, so functions like `office(individual, sim)` still return it.
As the second job takes time away from the first, `rescale = Office => 0.7` lowers the participants' contacts in the offices they already had to 70%.
`participation` can also be a function of the individual, e.g. `participation = ind -> age(ind) < 30 ? 0.2 : 0.1`.
Layers can also be written into the config file; the [`layer`](@ref config-layer) section of the config file documentation shows how, using the gyms from the start of this section.

The assignment decides whether a layer creates new settings or adds individuals to existing ones:

- `PackedSettings`, `RandomSettings`, `GroupedSettings`, `AgeSortedSettings`, and `SpatialSettings` create new settings of a given `size`, e.g. `PackedSettings(size = 20)`.
- `JoinExisting`, `JoinNearby`, and `JoinVia` add individuals to settings that already exist. `JoinVia` picks a setting someone else in the individual's household (or another `via` setting) already belongs to, e.g. the gym of a household member.

With `participation_unit = Household`, the members of a household decide together whether they take part, e.g. to let whole families join a sports club.

`SpatialSettings` and `JoinNearby` put individuals into settings near their home, based on the household coordinates of the settings file.
Their `spread` is the distance in km by which a home is moved before GEMS looks for settings nearby.
A small `spread` keeps settings local, while a distribution with a long tail (e.g. `Exponential(5.0)`) sends a few individuals far away.
If no setting lies within reach of the moved home, or the household has no coordinates, `JoinNearby` picks any setting of the type.

You can also apply layers to a population yourself before passing it to the simulation:

```julia
pop = Population("path/to/my/population.jld2")
add_setting_layers!(pop, second_jobs; seed = 1)
sim = Simulation(population = pop)
```

Layers passed to `Simulation` are not applied to a `Population` object, so this is the only way to add layers to one.
For `SpatialSettings` and `JoinNearby`, pass the household coordinates via `household_coordinates` (a dataframe with the columns `id`, `lon`, and `lat`).

The layers' draws are seeded from the `layer_seed` (which defaults to the simulation's seed) and each layer's name.
The same seed gives the same layers, regardless of the number of threads.
As a result, every simulation in a batch gets new layers, unless you fix `layer_seed`.
Calibration keeps the layers, as it reuses the population.
`params(population)["setting_layers"]` lists the layers that were applied to a population, with the IDs of the settings they created.

!!! warning "Layers add contacts"
    A layer adds settings on top of the ones an individual already has, so it raises the number of contacts and, with it, the reproduction number.
    Lower other contact rates, use `rescale` for the settings a layer takes time away from, or recalibrate after adding layers.

!!! warning "Don't apply layers twice"
    If you save a population after adding layers, run it with a config file without those layers.
    Otherwise, GEMS applies them a second time.
    GEMS warns you about this only for layers of declared setting types that create new settings.

There are a few more things to keep in mind:

- Layers are created once, before the simulation starts. Use `add_member!` and `remove_member!` to change memberships during a run.
- An individual who gets their first office from a layer counts as working (`is_working`).
- Household quarantine and severe illness keep individuals out of all settings except their `Household`, including settings created by layers.
- New offices and school classes that a layer creates belong to no workplace or school; settings that a layer only adds individuals to keep theirs.
- An individual who holds two settings of one type (e.g. with `entries = 2`, or from a `JoinExisting` layer) makes the simulation look up their settings a bit more slowly.
- A layer that creates settings for all of Germany (83 million individuals, one setting each) needs about 2.5 GB of memory to keep and about 5 GB more while it is being added.


## Adjusting Populations

In some cases, you might want to manually adjust populations after they have been loaded (e.g., to manually set a certain vaccination status for each individual).
This can be done using the `each!(...)` function that applies a given function on each individual in a provided `Population`.
Here's an example where we decide whether an individual has been vaccinated once with increasing probability, depending on their age.
We exclude everybody below the age of 18.
The `sample_vacc!` function that we define does just that for an individual. We then call `each!` to apply this function to all individuals in the population.
After that, we build up a dataframe with ages and numbers of vaccinations for all individuals, group them by age, and visualize the fraction of vaccinated individuals per by age.

```julia
using GEMS, Plots, DataFrames
sim = Simulation()
pop = population(sim)

# function to adjust individual
function sample_vaccs!(i)
    if age(i) >= 18 && rand(1:100) < age(i)
        i.number_of_vaccinations = 1
    end
end

# apply function to each individual
each!(sample_vaccs!, pop)

# plot to verify that everything worked
inds = individuals(pop)
df = DataFrame(age = age.(inds), vaccinations = number_of_vaccinations.(inds))
df_grouped = groupby(df, :age)
df_combined = combine(df_grouped, :vaccinations => (v -> sum(v) / length(v)) => :vacc_fraction)
plot(df_combined.age, df_combined.vacc_fraction,
    xlabel = "Age",
    ylabel = "Vaccination Coverage",
    legend = false)
```

**Plot**

```@raw html
<p align="center">
    <img src="../assets/tutorials/tut_pops_adjusting.png" width="80%"/>
</p>
```