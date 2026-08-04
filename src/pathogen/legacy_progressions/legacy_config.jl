###
### LEGACY CONFIG NORMALIZATION
###
### Reroutes the reused `Critical` category name in old-format pathogen configs. `Symptomatic` and
### `Hospitalized` keep their names (their legacy types resolve directly via `get_subtype`); only
### `Critical` collides with the modern disease tier and must be rewritten to `LegacyCritical`. The
### reroute keys solely on the `Critical` block's own fields, so a modern `Critical` is never rerouted
### just because the config also uses a legacy name elsewhere (e.g. `Symptomatic` for its mild tier).
###

"""
    _is_legacy_critical(crit)

`true` if a `Critical` progression config table uses the pre-decoupling health format, i.e. carries
`icu_admission_to_death` or `severeness_onset_to_hospital_admission`. A modern `Critical` (new disease
tier, optionally with embedded care) carries neither.
"""
_is_legacy_critical(crit) = crit isa Dict &&
    (haskey(crit, "icu_admission_to_death") || haskey(crit, "severeness_onset_to_hospital_admission"))

"""
    _normalize_legacy_pathogen!(params::Dict)

If a pathogen's `Critical` progression is old-format ([`_is_legacy_critical`](@ref)), rename it to
`LegacyCritical` and rewrite `"Critical"` -> `"LegacyCritical"` in the progression-assignment category
list (keeping the matrix order intact) so the tag lookup still resolves. A modern `Critical` is left
untouched, even when the config uses legacy names (`Symptomatic`/`Hospitalized`) for other tiers.
No-op otherwise.
"""
function _normalize_legacy_pathogen!(params::Dict)
    progs = get(params, "progressions", nothing)
    progs isa Dict || return params
    _is_legacy_critical(get(progs, "Critical", nothing)) || return params

    progs["LegacyCritical"] = pop!(progs, "Critical")

    pa = get(params, "progression_assignment", nothing)
    pa isa Dict || return params
    pars = get(pa, "parameters", nothing)
    pars isa Dict || return params
    cats = get(pars, "progression_categories", nothing)
    cats isa AbstractVector && (pars["progression_categories"] = replace(cats, "Critical" => "LegacyCritical"))

    return params
end
