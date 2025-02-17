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

## Utils

```@docs
_int
aggregate_df
aggregate_dfs
aggregate_dfs_multcol
foldercount(::AbstractString)
func_from_string(::String)
get_nested_value
group_by_age(::DataFrame)
print_aggregates
printinfo(::String)
remove_kw
subinfo(::String)
```