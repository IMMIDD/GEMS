# [3a - Dynamic Populations (Injections)](@id tut_population_injection)

So far, the population was fixed before the run started. With **population injection**, the population can also *change during the run*: individuals can change attributes (e.g., their job), new individuals are born, and individuals die — all from a schedule you create before the run.

The schedule is held by an **injector** (`GEMS.PopulationInjection.Injector`): staging a change into the injector is called **staging**, and the simulation **injects** the staged changes into the live population tick by tick. This page is the tutorial and reference for the feature; the docstrings of its API are collected on the [Population Injection](@id api_population_injection) page.

In the example below, the population carries an extra column `income` of type `Float32` that GEMS itself does not store. We stage changes at several different days, inspect the resulting state without running, and then run the *same injector* twice — with `population_snapshot = 0` and `population_snapshot = 5` — to see how the staged timeline re-bases onto the simulation clock.

!!! note "Injectors are not loggers"
    GEMS' loggers (`DeathLogger`, `InfectionLogger`, …) *record what happens* during a run. An injector *supplies what shall happen* to the population. The only overlap: injected deaths are also recorded in the `DeathLogger`, like any other death.

## Vocabulary

| Term | Meaning |
| :--- | :--- |
| **stage** | record a population change in the `Injector` (collecting the payload) — `stage_event!`, `stage_new_individual!`, `stage_new_individuals!` |
| **inject** | apply staged changes to the live population during the run |
| **staged changes** | the set of recorded population changes held by the `Injector` (and a `.jld2` file saved with `save`) |
| **saved injector** | a `.jld2` file written by `save(injector, path)`, readable via `Injector(path)` |
| **day `t`** | a timestamp on the staged-changes timeline (day `0` = the base population) |

## Semantics

| Aspect | Rule |
| :--- | :--- |
| Staged-changes timeline | Day `0` is the base population; events carry a `timestamp` (in days, `Int16`). |
| No snapshot | An event staged at day `t` is applied during simulation tick `t`. |
| `population_snapshot = t0` | All events with `timestamp <= t0` are **baked into the initial population at construction**. An event at day `t > t0` is applied at simulation tick `t - t0` (timeline rebasing). |
| Simulation clock | Always starts at tick `0`; progress bar and start conditions are unchanged. |
| `Event.ind_id` | The individual id the event applies to (not an array position). |
| New individuals | `:sex` and `:age` are required; all other fields keep GEMS default values unless staged. The `Injector` assigns the new ids (continuing its individual counter). |
| Setting moves | A staged change of `:household`/`:office`/`:schoolclass`/`:municipality` moves the membership in the settings container (GEMS' `add!`/`remove!`); a value that is not in the base is a new setting and must be the next free id (staging otherwise throws). Staging the default id means "no setting" (membership is removed). |
| Death | An event on the death column (`:death`) marks the individual dead from the event's timestamp. The staged value is **not** interpreted as a tick — only the timestamp is. |
| Dead individuals | They **remain** in `population(individuals)` (GEMS' flag-based model) but are excluded from transmission and seeding. |
| `reset!` / re-runs | The baked-in prefix is re-applied idempotently (no duplicate births; deaths are re-marked). Attribute changes persist across `reset!` (only disease state is reset). |
| Validation | The provided population is hash-checked against the staged base population **at construction, before any bake-in**; a mismatch throws an `ArgumentError`. |


## Setting up the base population and the injector

As in the [3 - Creating Populations](@id tut_pops) tutorial, we generate a synthetic population from a dataframe — 100 individuals, two per household:

```julia
using GEMS, DataFrames
const PI = GEMS.PopulationInjection

pop_df = DataFrame(
    id         = Int32.(1:100),
    age        = Int8.(18 .+ (1:100) .% 60),
    sex        = Int8.(1 .+ (1:100) .% 2),
    occupation = Int16.(1 .+ (1:100) .% 6),
    household  = Int32.(repeat(1:50, inner = 2)),
)
pop = Population(pop_df)

# the base table the injector's schema is derived from: GEMS' canonical dataframe
# (the one the base is validated against) plus the `income` column, stored as Float32
base = dataframe(pop)
base[!, :income] = Float32.(1000.25 .* (1:100))

schema = PI.create_column_schema(base)
inj = PI.Injector(schema)
```

!!! note "Why not `new_injector(pop)` here?"
    `new_injector(pop)` builds the schema from `dataframe(population)` — that table only contains columns with a matching `Individual` field. `income` is *not* a field of `Individual`, so it is not in that table and there would be no `:income` column to stage. Whenever the staged changes use columns beyond `Individual`'s fields, build the schema manually: the canonical `dataframe(population)` plus your extra columns, passed to `PI.create_column_schema`.

## Float columns in the schema

For integer columns, `PI.create_column_schema` encodes the distinct values into a compact integer map — a *closed* set of values that must be registered before staging.

Float columns behave differently: they are not value-encoded. The schema stores the minimal float type that keeps the base values accurate (`Float16` → `Float32` → `Float64`; here the values need `Float32`), and the value map stays empty. Such a column is initially *open*: staging accepts any float value, converted to that minimal type.

`PI.update_schema!` switches a float column over to the same closed, registered-values encoding as integer columns. From then on, only the registered values can be staged (anything else is rejected), and decoding always yields the original `Float32` values back. So: register *every* income value you plan to stage — including the newborn's — in a single call, before staging:

```julia
# every value that will be staged later must be in the schema beforehand
PI.update_schema!(inj.schema, :occupation, Int16[20])   # the new job (day 6 + the newborn)
PI.update_schema!(inj.schema, :age, Int8[0])            # the newborn's age
PI.update_schema!(inj.schema, :income, Float32[         # all the income values to be staged
    4200.0, 1500.75, 2600.75, 2800.25, 3100.5, 2050.25])
```

!!! note "Staging after `update_schema!`"
    Once the `:income` column is switched to registered-values mode, staging an unregistered value fails, e.g. `PI.stage_event!(inj, 2, :income, 9999.0, Int16(3)` throws `Value 9999.0 could not be converted to a valid type for field income`. If you do *not* call `PI.update_schema!` on the float column at all, any float is accepted (open mode) — register only when you want the closed set.

## Storing `income` on the population (extension column)

If you want GEMS itself to carry `income` per individual, declare it as an **extension column** where the dataframe enters GEMS, via the `ind_extension` keyword. This example is self-contained — the `*_ext` variables don't interfere with the flow above, which keeps using the non-stored variant:

```julia
pop_df_ext = DataFrame(
    id         = Int32.(1:100),
    age        = Int8.(18 .+ (1:100) .% 60),
    sex        = Int8.(1 .+ (1:100) .% 2),
    occupation = Int16.(1 .+ (1:100) .% 6),
    household  = Int32.(repeat(1:50, inner = 2)),
    income     = Float32.(1000.25 .* (1:100)),   # not an Individual field
)

# option A: store it when building the population
pop_ext = Population(pop_df_ext, ind_extension = [:income])
inj_ext = new_injector(pop_ext)    # works directly: dataframe(pop_ext) includes `income`
PI.stage_event!(inj_ext, 1, :income, Float32(4200.0), Int16(2))    # no update_schema! needed: open float column
sim_ext = Simulation(population = pop_ext, population_injection = inj_ext, stop_criterion = TimesUp(limit = 4))
for _ in 1:3; step!(sim_ext); end
getproperty(get_individual_by_id(population(sim_ext), Int32(1)), :income)   # 4200.0f0 — injected into the extension

# option B: declare it in the Simulation call (population as dataframe)
sim_ext2 = Simulation(population = pop_df_ext, ind_extension = [:income],
                      population_injection = inj_ext, stop_criterion = TimesUp(limit = 4))
for _ in 1:3; step!(sim_ext2); end
getproperty(get_individual_by_id(population(sim_ext2), Int32(1)), :income)  # 4200.0f0
```

With `income` stored as an extension, staged changes on it are **injected into each individual's extension** (readable as `ind.income`) instead of being skipped — including newborns, which receive the staged value on a zero-filled default extension. Note that `ind_extension = [:income]` needs the original dataframe: it must be given at `Population(df, ...)` or `Simulation(population = df, ...)`, not next to an already-built `Population`.

## Staging the changes

The staged timeline (days are `Int16`):

| day | change |
|---|---|
| 2 | `income` of individual `1` → `4200.0` |
| 4 | `income` of individual `7` → `1500.75` |
| 5 | `income` of individual `9` → `2600.75` |
| 6 | `occupation` of individual `1` → `20` (job change) |
| 8 | `income` of individual `3` → `2800.25` |
| 10 | newborn with `occupation 20`, `income 3100.5` (id assigned by the injector: `101`) |
| 12 | `income` of individual `5` → `2050.25` |

```julia
PI.stage_event!(inj, 1, :income, Float32(4200.0), Int16(2))
PI.stage_event!(inj, 7, :income, Float32(1500.75), Int16(4))
PI.stage_event!(inj, 9, :income, Float32(2600.75), Int16(5))
PI.stage_event!(inj, 1, :occupation, Int16(20), Int16(6))
PI.stage_event!(inj, 3, :income, Float32(2800.25), Int16(8))
newids = PI.stage_new_individuals!(inj, DataFrame(       # the injector assigns the id (101)
    sex = Int8[1], age = Int8[0], occupation = Int16[20],
    household = Int32[1], income = Float32[3100.5]), Int16(10))
PI.stage_event!(inj, 5, :income, Float32(2050.25), Int16(12))
```

!!! note "`income` is tracked by the injector, not by GEMS — unless you store it as an extension"
    This population was created without an extension, so `income` is not stored per individual — it is neither an `Individual` field nor an `ind_extension` column. When the injector reaches one of these events, the change is applied to the injector's timeline only, and GEMS logs — once per field, not once per event — that `field :income is not stored on this population; the staged change is skipped`. The staged income values are fully preserved in the injector — read them back with `PI.snapshot(inj, base, day)` (below); the observable effects in the live population are the `occupation` change and the newborn. If `income` were stored as an extension column — e.g. `Population(pop_df, ind_extension = [:income])` — the staged changes would instead be injected into each individual's extension.

## Inspecting the staged state without running

`PI.snapshot` reconstructs the population table at any day of the staged-changes timeline — starting from the base table, applying every staged change up to and including that day, appending new individuals as rows:

```julia
s5 = PI.snapshot(inj, base, Int16(5))
s5[1, :income]    # 4200.0f0
s5[7, :income]    # 1500.75f0
s5[9, :income]    # 2600.75f0 — staged at day 5, and day 5 is the snapshot day: included
nrow(s5)          # 100 — the newborn (day 10) is not born yet

s10 = PI.snapshot(inj, base, Int16(10))
nrow(s10)             # 101 — the newborn is appended as a new row
s10[101, :income]     # 3100.5f0
s10[101, :occupation] # 20
```

The snapshot is also the ground truth for what a simulation with `population_snapshot = 5` starts from — you can cross-check the two.

## Running with the injector (snapshot 0)

```julia
simA = Simulation(population = pop, population_injection = inj, stop_criterion = TimesUp(limit = 14))

tick(simA)                                            # 0
length(individuals(simA))                             # 100
occupation(get_individual_by_id(population(simA), Int32(1)))   # 2 — still the old job

for _ in 1:7; step!(simA); end
occupation(get_individual_by_id(population(simA), Int32(1)))   # 20 — the day-6 change is in effect
length(individuals(simA))                             # 100 — the newborn (day 10) is not due yet

for _ in 1:4; step!(simA); end                        # 11 steps in total
length(individuals(simA))                             # 101 — the newborn has arrived

PI.snapshot(inj, base, Int16(12))[5, :income]         # 2050.25f0 — the income state comes from the injector
```

!!! info "When is a staged change in effect?"
    `step!` checks the staged changes *before* advancing the clock, and the clock starts at `0` (`tick(sim) == 0` right after construction). So during step `#1` the clock still reads `0`, during step `#2` it reads `1`, and so on. A change staged at day `t` is therefore injected during step `t + 1` when `population_snapshot = 0` — it is visible after `t + 1` calls of `step!`. With `population_snapshot = t0`, a change staged at day `t > t0` is injected during step `t - t0 + 1`.

## Starting from day 5 (`population_snapshot = 5`)

Now run the *same injector* starting from day 5 of the staged timeline. Everything staged up to and including day 5 is baked into the initial population; the simulation clock starts at `tick 0 == day 5`, and the remaining changes re-base onto it:

```julia
popB = Population(pop_df)     # a fresh population — the simulation modifies the one it is given
simB = Simulation(population = popB, population_injection = inj,
                  population_snapshot = 5, stop_criterion = TimesUp(limit = 14))

tick(simB)                    # 0 — simulation tick 0 == day 5 of the staged changes
length(individuals(simB))     # 100 — days 2, 4, 5 are baked in; the newborn (day 10) is not born yet
occupation(get_individual_by_id(population(simB), Int32(1)))   # 2 — the day-6 change is not due yet

for _ in 1:2; step!(simB); end
occupation(get_individual_by_id(population(simB), Int32(1)))   # 20 — in effect after 6 - 5 + 1 = 2 steps

for _ in 1:4; step!(simB); end
length(individuals(simB))     # 101 — the newborn is in effect after 10 - 5 + 1 = 6 steps
```

The re-based timeline of the two runs:

| staged change | day | run A (`population_snapshot = 0`): in effect after | run B (`population_snapshot = 5`) |
|---|---|---|---|
| `income`(1) → `4200.0` | 2 | 3 steps | baked in |
| `income`(7) → `1500.75` | 4 | 5 steps | baked in |
| `income`(9) → `2600.75` | 5 | 6 steps | baked in (boundary: *up to and including* day 5) |
| `occupation`(1) → `20` | 6 | 7 steps | 2 steps |
| `income`(3) → `2800.25` | 8 | 9 steps | 4 steps |
| newborn (id `101`) | 10 | 11 steps | 6 steps |
| `income`(5) → `2050.25` | 12 | 13 steps | 8 steps |

!!! tip "Sanity check"
    For run B, the baked-in state *is* `PI.snapshot(inj, base, Int16(5))` (day `5` inclusive): the income changes of days 2, 4 and 5 are part of the initial population, the day-6 job change is not, and the population has 100 individuals. After 6 steps, the observable state matches `PI.snapshot(inj, base, Int16(10))` — 101 individuals, the newborn with `occupation 20` and `income 3100.5f0`.

## Using it with a Simulation

The `Simulation` constructor accepts two additional keyword arguments (see the `Simulation` docstring):

- `population_injection`: an `Injector`, or a path to a `.jld2` file saved with `PopulationInjection.save`.
- `population_snapshot`: the day of the staged changes baked into the initial population (default `0`; must be `>= 0`, fit in `Int16`, and requires `population_injection` to be set).

Injectors are plain data and can be shared across simulations or saved for later: `PI.save(inj, "injector.jld2")` writes the staged changes to a file, and `PI.Injector("injector.jld2")` reads them back.

## Deaths in detail

- A staged event on the death column `:death` marks the individual **dead from the event's timestamp** (the staged value — flag or day — is not interpreted as a tick).
- The engine mirrors GEMS' native death state: `ind.death` is set to the application tick (`0` when baked in), the `FLAG_DEAD` flag is set, and the infection masks are cleared — so the state is consistent even on dormant ticks. `killing_pathogen_id` stays at the default.
- Run-time deaths are recorded **exactly once** in the `DeathLogger`, attributed to `DEFAULT_PATHOGEN_ID` (no pathogen). Baked-in (pre-run) deaths are initial state and are **not** logged.
- Dead individuals remain in the population and are excluded from transmission and seeding, exactly like simulation-caused deaths.
- **Base-file requirement:** if the base population file used with `create_column_schema` has a death column, it must use GEMS' `Individual.death` tick semantics: alive = `-1` (`DEFAULT_TICK`), dead = the tick of death. A 0/1 "is dead" flag column would be misread (`0` = "died at tick 0" → everyone dies at tick 0). Convert such files before building the schema.

## Constraints

- **Schema values are closed:** a new value must be in the schema's forward map — extend it with `update_schema!` *before* staging.
- **Element types are part of the hash:** the hash is dtype-sensitive (Int32 vs Int64 differ). Build the schema from the canonical `dataframe(population)` — `new_injector(pop)` does this automatically.
- **Setting moves:** updating `:household`/`:office`/`:schoolclass`/`:municipality` also moves the membership in the settings container (GEMS' `add!`/`remove!`), creating the target setting when the id is the next free one — GEMS indexes settings by id without gaps, so a staged new setting id must be `max(id) + 1` (staging any other new id is an error). Container hierarchies (`School`, `Workplace`, …) and their `contains`/`contained` links are not touched. A column is treated as a setting column only if its name matches an `Individual` field that GEMS maps to a setting type — the type-level `setting_id!` dispatch is the source of truth and the column name is only the join key (per the `dataframe(population)` convention of one column per field, same name); `setting_fieldmap()` exposes the mapping.
- **Int16 bounds:** ticks, timestamps, and the snapshot are `Int16`-bounded.

The docstrings of all the types and functions are collected on the [Population Injection](@id api_population_injection) page.
