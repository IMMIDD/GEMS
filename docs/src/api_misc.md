# Misc

## Overview Structs

```@index
Pages   = ["api_misc.md"]
Order   = [:type]
```
## Overview Functions

```@index
Pages   = ["api_misc.md"]
Order   = [:function]
```


## AGS

### Constructors

```@docs
AGS
```

### Functions

```@docs
county(::AGS)
district(::AGS)
id(::AGS)
in_county(::AGS, ::AGS)
in_district(::AGS, ::AGS)
in_state(::AGS, ::AGS)
is_county(::AGS)
is_district(::AGS)
is_state(::AGS)
isunset(::AGS)
municipality(::AGS)
state(::AGS)
```

## Age Group

### Constructors

```@docs
AgeGroup
```

### Functions

```@docs
in_group
check_continuity
```

## Random Number Generation

```@docs
set_global_seed
gems_rand
gems_sample
gems_sample!
gems_shuffle
gems_shuffle!
gems_randn
```

## Exceptions

```@docs
ConfigfileError
```

## Utils

```@docs
_int
aggregate_df
aggregate_dfs
aggregate_dfs_multcol
foldercount(::AbstractString)
group_by_age(::DataFrame)
prepare_kw_args
print_aggregates
printinfo(::String)
remove_kw
subinfo(::String)
```