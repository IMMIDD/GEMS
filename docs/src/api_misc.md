# Misc
everything else

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

## Structs
```@docs
Entity
```

## Functions
```@docs
GEMS_version
_int
agegroup(::String, ::Individual)
aggregate_data
aggregate_df
aggregate_dfs
aggregate_dfs_multcol
create_config_files(::Any, ::Any, ::Any)
data(::Runinfo)
escape_markdown(::String)
foldercount(::AbstractString)
free_mem_size
func_from_string(::String)
generate_combinations(parameters_dict)
germanshapes(::Int64)
get_nested_value
getundocumented
git_branch
git_commit
git_repo
is_toml_file
isvalidDistribution
initialize_seed 
kernel
markdown
print_aggregates
printinfo(::String)
process_funcs(::Dict)
remove_kw
set_nested!
subinfo(::String)
```

# AGS
## Structs
```@docs
AGS
```

## Functions
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

### to be assigned
```@docs
aggregation_interval_steps
find_alpha
focal_objects(::Handover)
```