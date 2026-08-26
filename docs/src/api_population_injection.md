# Population Injection

## Overview Structs
```@index
Pages   = ["api_population_injection.md"]
Order   = [:type]
```
## Overview Functions
```@index
Pages   = ["api_population_injection.md"]
Order   = [:function]
```

## The Injector (`GEMS.PopulationInjection`)

### Types
```@docs
PopulationInjection.Injector
PopulationInjection.InjectorSchema
PopulationInjection.Event
PopulationInjection.ColumnSchema
```

### Constructors
```@docs
PopulationInjection.Injector(::PopulationInjection.InjectorSchema)
PopulationInjection.Injector(::AbstractString)
```

### Schema & encoding
```@docs
PopulationInjection.create_column_schema
PopulationInjection.update_schema!
PopulationInjection.encode_value
PopulationInjection.decode_value
PopulationInjection.get_original_value
```

### Staging population changes
```@docs
PopulationInjection.stage_event!
PopulationInjection.stage_new_individual!
PopulationInjection.stage_new_individuals!
```

### Snapshots & persistence
```@docs
PopulationInjection.snapshot
PopulationInjection.save
```

## Injection engine

### Types
```@docs
PopulationInjectionState
```

### Functions
```@docs
new_injector
population_injection
setting_fieldmap
apply_injection_events!
inject_population_changes!
validate_injection_base!
reset_injection!
```
