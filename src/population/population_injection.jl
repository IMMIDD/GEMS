"""
    PopulationInjection

Port of the DynamicPopulationLog package, renamed to the GEMS injection vocabulary:
an `Injector` holds *staged population changes* (schema + events) which a `Simulation`
injects into the live population tick by tick (see `population_injection_methods.jl`).

Provides schema-based encoding of population changes, staging events
(`stage_event!`, `stage_new_individual!`, `stage_new_individuals!`), snapshot
reconstruction, and JLD2 persistence (`save` / `Injector(path)`).
"""
module PopulationInjection

using DataFrames
using JLD2
using Statistics

# Define the Event struct with a type parameter for the encoded value
"""
    Event{T}

Represents a staged event in the injector with encoded values for efficiency.

# Fields
- `ind_id::Int32`: The individual id the event applies to (equals the row number of the base population table)
- `field::Int8`: The field index of the event (0-indexed)
- `new_value::T`: The encoded value of the event
- `timestamp::Int16`: The timestamp of the event (day of the staged-changes timeline)
"""
struct Event{T}
    ind_id::Int32
    field::Int8
    new_value::T
    timestamp::Int16
end

# Define the column schema struct
"""
    ColumnSchema{T}

Schema information for a column including encoding mappings and type information.

# Fields
- `forward_map::Dict{T, Int}`: Mapping from original values to encoded integers
- `reverse_map::Dict{Int, T}`: Mapping from encoded integers back to original values
- `min_type::DataType`: The minimal integer type used for encoding
- `original_type::DataType`: The original data type of the column
"""
struct ColumnSchema{T}
    forward_map::Dict{T,Int}
    reverse_map::Dict{Int,T}
    min_type::DataType
    original_type::DataType
    hash::UInt64
end

# Define the injector schema struct as mutable
"""
    InjectorSchema

Schema information for the entire injector including metadata and column mappings.

# Fields
- `meta::Dict{Symbol, Any}`: Metadata about the injector
- `columns::Dict{Symbol, ColumnSchema}`: Column-specific schema information
- `field_to_index::Dict{Symbol, Int8}`: Mapping from field symbols to indices
- `index_to_field::Vector{Symbol}`: Mapping from indices to field symbols
"""
mutable struct InjectorSchema
    meta::Dict{Symbol,Any}
    columns::Dict{Symbol,ColumnSchema}
    field_to_index::Dict{Symbol,Int8}
    index_to_field::Vector{Symbol}
end

# Define the injector struct - make it mutable
"""
    Injector

Main injector structure that holds the schema and the staged events.

# Fields
- `schema::InjectorSchema`: The schema defining the injector structure
- `events::Vector{Event}`: The collection of staged events
- `warned::Set{Symbol}`: Fields for which the "not stored on the population" warning has
  already been emitted (warn-once bookkeeping, see `population_injection_methods.jl`)
"""
mutable struct Injector
    schema::InjectorSchema
    events::Vector{Event}
    warned::Set{Symbol}
end

"""
    Injector(schema::InjectorSchema)

Constructs a new Injector with the given schema.

# Arguments
- `schema::InjectorSchema`: The schema to use for this injector
"""
function Injector(schema::InjectorSchema)
    return Injector(schema, Event[], Set{Symbol}())
end

"""
    determine_minimal_type(max_value::Int)

Determines the minimal integer type needed to represent the given maximum value.

# Arguments
- `max_value::Int`: The maximum value to be represented

# Returns
- `DataType`: The minimal integer type (Int8, Int16, Int32, or Int64)
"""
function determine_minimal_type(max_value::Int)
    if max_value <= 255
        return Int8   # Use signed 8-bit integer
    elseif max_value <= 65535
        return Int16  # Use signed 16-bit integer
    elseif max_value <= 4294967295
        return Int32  # Use signed 32-bit integer
    else
        return Int64  # Use signed 64-bit integer
    end
end


"""
    determine_minimal_float_type(vec::AbstractVector{<:AbstractFloat}, tol::Real)

Checks the lowest precision float type (`Float16` -> `Float32` -> `Float64`)
that keeps the conversion inaccuracy below the given `tol`.
Returns the type, or a message if even Float64 is too imprecise.
"""
function determine_minimal_float_type(vec::AbstractVector{<:AbstractFloat}, tol::Real)
    types_to_check = [Float16, Float32, Float64]

    for T in types_to_check
        # Convert to target type
        converted_vec = T.(vec)

        # Check if max absolute error is within tolerance
        # atol is used to check for maximum absolute difference
        if isapprox(vec, converted_vec, atol=tol)
            return T
        end
    end

    return error("Required precision higher than Float64")
end

"""
    determine_ind_id_type(n_individuals::Int)

Determines the minimal integer type needed for individual id indexing with 10% buffer.

# Arguments
- `n_individuals::Int`: The number of individuals in the base population

# Returns
- `DataType`: The minimal integer type for individual id indexing
"""
function determine_ind_id_type(n_individuals::Int)
    # Add 10% buffer as requested
    max_ids = Int(ceil(n_individuals * 1.1))
    if max_ids <= 255
        return Int8
    elseif max_ids <= 65535
        return Int16
    elseif max_ids <= 4294967295
        return Int32
    else
        return Int64
    end
end

"""
    minimal_encoding(data)

Computes the minimal encoding for a column's data.

# Arguments
- `data`: The data to encode

# Returns
- `Dict{Any, Int}`: Forward mapping from original values to encoded integers
- `Dict{Int, Any}`: Reverse mapping from encoded integers to original values
- `DataType`: The minimal integer type used for encoding
"""
function minimal_encoding(data, float_tol::Real)
    if isempty(data)
        return Dict{Any,Int}(), Dict{Int,Any}(), Int
    end

    original_type = eltype(data)
    unique_vals = unique(data)
    max_index = length(unique_vals)


    # For floating point types, we don't encode them
    if original_type <: AbstractFloat
        min_type = determine_minimal_float_type(data, float_tol)
        # Return the original type for floats (no encoding) hence empty Dicts.

        forward_map = Dict{original_type,min_type}()
        reverse_map = Dict{min_type,original_type}()
        return forward_map, reverse_map, min_type
    end

    min_type = determine_minimal_type(max_index)

    # For Int8 and Bool, use identity mapping but still convert to min_type
    if original_type <: Int8 || original_type <: Bool
        forward_map = Dict{original_type,min_type}()
        reverse_map = Dict{min_type,original_type}()
        for val in unique_vals
            converted_val = convert(min_type, val)
            forward_map[val] = converted_val
            reverse_map[converted_val] = val
        end
        return forward_map, reverse_map, min_type
    else
        # Original encoding logic for other types
        forward_map = Dict{eltype(data),min_type}()
        reverse_map = Dict{min_type,eltype(data)}()
        typmin = typemin(min_type)
        for (i, val) in enumerate(unique_vals)
            forward_map[val] = convert(min_type, typmin + i)
            reverse_map[convert(min_type, typmin + i)] = val
        end
        return forward_map, reverse_map, min_type
    end
end


# `id`, `age`, `sex` and the setting columns (the keys of `setting_fieldmap()`, e.g.
# `:household`) are *identity-mapped*: their value set is open and growing (new ages, new
# setting ids, …) rather than a closed categorical code table, so a staged value is stored
# as-is in the column's own element type — it needs no `update_schema!` pre-registration and
# encodes/decodes to itself. Every other column keeps the closed-set encoding above.
function identity_fields()
    return Set([:id, :age, :sex] ∪ Set(keys(Main.GEMS.setting_fieldmap())))
end

is_identity_field(field::Symbol) = field in identity_fields()

# Identity encoding: forward and reverse maps are the identity over the base values and the
# stored type is the column's own element type (the value set stays open).
function identity_encoding(data)
    T = eltype(data)
    forward_map = Dict{T,T}()
    reverse_map = Dict{T,T}()
    for v in unique(data)
        forward_map[v] = v
        reverse_map[v] = v
    end
    return forward_map, reverse_map, T
end

# Convert a staged value into an identity column's type; an out-of-range value is an
# `ErrorException` (matching the closed-set path's error type) naming the column.
function _encode_identity!(min_type, value, field)
    return try
        convert(min_type, value)
    catch e
        if e isa InexactError
            throw(ErrorException("Value $value is out of range for the identity-mapped $(field) column (type $(min_type))"))
        end
        rethrow()
    end
end

# The required `Individual` fields the base table must carry as columns — their types are
# read from the `Individual` struct itself, the single source of truth. The setting
# columns (the keys of `setting_fieldmap()`, e.g. `:household`) are optional: they
# default to `DEFAULT_SETTING_ID` (`-1`) on `Individual`, so an individual without a
# setting is valid and no column is needed — but when present they must keep the
# `Individual` field type.
const REQUIRED_BASE_FIELDS = (:id, :age, :sex)

"""
    _check_required_base_columns!(df)

Rejects a base table that lacks a required `Individual` field column or carries one with
the wrong element type (`Population(df)` requires `id`/`age`/`sex`, and the `Simulation`
hash-checks the live population against this table — the hash is dtype-sensitive, so a
mistyped column would fail later with an opaque hash mismatch). Setting columns are
optional, but a present one must keep the `Individual` field type.
"""
function _check_required_base_columns!(df)
    G = Main.GEMS
    required = [(c, fieldtype(G.Individual, c)) for c in REQUIRED_BASE_FIELDS]
    optional = [(c, fieldtype(G.Individual, c)) for c in keys(G.setting_fieldmap())]
    missing = [c for (c, _) in required if !(c in propertynames(df))]
    mistyped = [(c, eltype(df[!, c]), T) for (c, T) in vcat(required, optional)
                if c in propertynames(df) && eltype(df[!, c]) !== T]
    if isempty(missing) && isempty(mistyped)
        return nothing
    end
    problems = String[]
    !isempty(missing) &&
        push!(problems, "missing required column(s): $(join([":$(c)" for c in missing], ", "))")
    !isempty(mistyped) &&
        push!(problems, join([":$(c) is $(T) but must be $(want) to match Individual.$(c)"
            for (c, T, want) in mistyped], "; "))
    throw(ArgumentError(
        "population injection: create_column_schema requires the base DataFrame to carry the " *
        "required Individual fields with their exact types ($(join([":$(c)::$(T)" for (c, T) in required], ", "))). " *
        "Setting columns ($(join([":$(c)" for (c, _) in optional], ", "))) are optional — they default to " *
        "GEMS.DEFAULT_SETTING_ID on Individual — but when present they must keep the Individual field " *
        "type ($(join([":$(c)::$(T)" for (c, T) in optional], ", "))). " *
        "$(join(problems, "; ")). " *
        "Add the missing columns (e.g. base[!, :age] = fill(Int8(0), nrow(base))) and convert " *
        "mistyped ones (e.g. base[!, :id] = Int32.(base[:, :id])), or build the base with " *
        "GEMS' dataframe(population) / new_injector(population)."
    ))
end

"""
    create_column_schema(df::DataFrame)

Creates a schema for all columns in a DataFrame.

The base table must carry the required `Individual` fields as columns with their exact
types — `:id` (`Int32`), `:age` (`Int8`), `:sex` (`Int8`) — because `Population(df)`
requires them and the `Simulation` hash-checks the live population against this table
(the hash is dtype-sensitive). Missing or mistyped required columns are an
`ArgumentError` naming each column, its required type, and the conversion to take.
Setting columns (`:household`, `:office`, …) are optional, but a present one must keep
the `Individual` field type or is rejected the same way.

# Arguments
- `df::DataFrame`: The base population table to create the schema for

# Returns
- `InjectorSchema`: The created schema
"""
function create_column_schema(df::DataFrame, float_tol=1e-6)
    _check_required_base_columns!(df)
    num_individuals = nrow(df)
    # Determine individual id type based on number of individuals + 10% buffer
    ind_id_type = determine_ind_id_type(num_individuals)

    schema = InjectorSchema(
        Dict{Symbol,Any}(),
        Dict{Symbol,ColumnSchema}(),
        Dict{Symbol,Int8}(),
        Symbol[]
    )

    # Store individual id type in meta information
    schema.meta[:ind_id_type] = ind_id_type
    schema.meta[:num_individuals] = num_individuals
    schema.meta[:current_individuals] = num_individuals
    schema.meta[:hash] = Dict{Symbol,UInt64}()


    # Create field mappings
    field_names = names(df)
    schema.index_to_field = Symbol[]
    schema.field_to_index = Dict{Symbol,Int8}()

    for (i, col_name) in enumerate(field_names)
        # Convert string to symbol properly
        field_symbol = Symbol(col_name)
        schema.field_to_index[field_symbol] = Int8(i - 1)
        push!(schema.index_to_field, field_symbol)
    end

    # Process each column
    for col_name in field_names
        col_data = df[:, col_name]
        if is_identity_field(Symbol(col_name))
            forward_map, reverse_map, min_type = identity_encoding(col_data)
        else
            forward_map, reverse_map, min_type = minimal_encoding(col_data, float_tol)
        end
        # Compute stable hash for the column data
        col_hash = stable_hash(col_data)
        # Store hash in meta information per column
        schema.meta[:hash][Symbol(col_name)] = col_hash
        # Use symbol as key in columns dictionary
        schema.columns[Symbol(col_name)] = ColumnSchema{eltype(col_data)}(
            forward_map,
            reverse_map,
            min_type,
            eltype(col_data),
            col_hash
        )
    end

    # Base id count of the setting columns (the columns of `setting_fieldmap()`): the number of
    # distinct non-default base values. GEMS indexes settings by id without gaps (ids 1:N), so
    # staging may only add ids that extend this range one at a time (`_check_staged_setting_id!`).
    # (Access via `Main.GEMS`: a plain `GEMS` name does not reliably resolve from this submodule
    # in the precompile context; `Main.GEMS` is a runtime field access, always bound at call time.)
    fieldmap = Main.GEMS.setting_fieldmap()
    setting_counts = Dict{Symbol, Int}()
    for col_name in field_names
        f = Symbol(col_name)
        haskey(fieldmap, f) || continue
        vals = unique(Int32.(df[!, f]))
        setting_counts[f] = count(v -> v != Main.GEMS.DEFAULT_SETTING_ID, vals)
    end
    !isempty(setting_counts) && (schema.meta[:setting_base_count] = setting_counts)
    # running maximum of the new setting ids staged per setting column (updated by
    # `_check_staged_setting_id!`); lets the staging check stay O(1) instead of scanning
    # and decoding every staged event
    !isempty(setting_counts) && (schema.meta[:setting_max_new] = Dict{Symbol, Int32}())
    return schema
end

"""
    encode_value(injector::Injector, field::Symbol, value)

Encodes a value using the injector's schema.

# Arguments
- `injector::Injector`: The injector containing the schema
- `field::Symbol`: The field to encode for
- `value`: The value to encode

# Returns
- `Any`: The encoded value

# Throws
- `ErrorException`: for a closed-set column, if the value is not in the encoding (register
  it via `update_schema!` first); for an identity-mapped column (`id`/`age`/`sex`/settings),
  if the value is out of range for the column's element type
"""
function encode_value(injector::Injector, field::Symbol, value)
    schema_entry = injector.schema.columns[field]
    if is_identity_field(field)
        return _encode_identity!(schema_entry.min_type, value, field)
    end
    forward_map = schema_entry.forward_map
    if injector.schema.columns[field].min_type <: AbstractFloat
        return convert(injector.schema.columns[field].min_type, value)
    elseif !haskey(forward_map, value)
        error("Value $value not found in the encoding for field $field. Please adjust the schema ex ante, to include all allowed values. Available values: $(keys(forward_map))")
    else
        min_type = schema_entry.min_type
        encoded_value = forward_map[value]
        return convert(min_type, encoded_value)
    end
end


"""
    update_schema!(schema::InjectorSchema, field::Symbol, new_values)

Updates the schema for a specific field with new values.

# Arguments
- `schema::InjectorSchema`: The schema to update
- `field::Symbol`: The field to update
- `new_values`: The new values to add to the field's encoding

# Returns
- `Nothing`: Updates the schema in place
"""
function update_schema!(schema::InjectorSchema, field::Symbol, new_values)
    # Identity-mapped columns (id/age/sex/settings) have an open value set — staging new
    # values is already legal, so there is nothing to register.
    is_identity_field(field) && return nothing
    # Check if field exists in schema
    if !haskey(schema.columns, field)
        error("Field $field not found in schema")
    end

    # Get the existing column schema
    existing_schema = schema.columns[field]

    # Get current unique values
    current_unique = collect(keys(existing_schema.forward_map))
    new_unique = unique(new_values)
    all_unique = union(current_unique, new_unique)

    # Determine new minimal type for this specific column
    new_max_index = length(all_unique) - 1
    new_min_type = determine_minimal_type(new_max_index)

    # Create new mappings for this column
    new_forward_map = Dict{eltype(new_values),new_min_type}()
    new_reverse_map = Dict{new_min_type,eltype(new_values)}()

    # Set up the mapping
    typmin = typemin(new_min_type)
    for (i, val) in enumerate(all_unique)
        encoded_val = convert(new_min_type, typmin + i)
        new_forward_map[val] = encoded_val
        new_reverse_map[encoded_val] = val
    end

    # Update the schema for this specific field only
    schema.columns[field] = ColumnSchema{eltype(new_values)}(
        new_forward_map,
        new_reverse_map,
        new_min_type,
        eltype(new_values),
        schema.columns[field].hash
    )
end


"""
    _check_staged_setting_id!(injector, field, value)

Enforces GEMS' contiguous setting-id rule at staging: the settings container indexes settings
by id without gaps (ids 1:N), so a staged value for a setting column (`household`, `office`,
`schoolclass`, `municipality`) that is neither one of the base ids nor the default id
("no setting") must be either one of the new ids already staged (e.g. another individual
joining a setting that was created by an earlier event) or the next free id
(`max(base ids, staged ids) + 1`). Anything else is a staging error.

The running maximum of the staged new ids is kept in `schema.meta[:setting_max_new]`
(updated on every successful staging), so the check is O(1) per staged event; the
full-event scan only runs once as a fallback for injectors saved before the cache existed.
"""
function _check_staged_setting_id!(injector::Injector, field::Symbol, value)
    base_counts = get(injector.schema.meta, :setting_base_count, nothing)
    (isnothing(base_counts) || !haskey(base_counts, field)) && return nothing
    n_base = base_counts[field]
    v = convert(Int32, value)
    v in 1:n_base && return nothing                       # existing setting (ids 1:N after GEMS' normalization)
    v == Main.GEMS.DEFAULT_SETTING_ID && return nothing   # "no setting" — always allowed
    # the new ids already staged for this field (each of them was validated when staged,
    # so the range stays gap-free): only the maximum matters. Any of them may be
    # referenced again by later events, and the next new id is max + 1. The running max is
    # cached in the schema meta (updated below on every successful staging); the event
    # scan is only the fallback for injectors saved before the cache existed.
    cached = get(injector.schema.meta, :setting_max_new, nothing)
    max_new = cached === nothing ? 0 : get(cached, field, 0)
    if cached === nothing
        fidx = injector.schema.field_to_index[field]
        for ev in injector.events
            ev.field == fidx || continue
            val = Int32(get_original_value(injector, ev))
            val > n_base && (max_new = max(max_new, val))
        end
    end
    next = (max_new == 0 ? Int32(n_base) : Int32(max_new)) + Int32(1)
    n_base < v <= next || throw(ArgumentError(
        "population injection: staged $(field) id $v is not a valid new setting id. GEMS indexes " *
        "settings by id without gaps (the base has $n_base $(field) setting(s), $(max_new == 0 ? 0 : max_new - n_base) " *
        "new id(s) already staged), so every id up to the maximum must be set: a staged new id must be " *
        "one of the already staged new ids (< $next) or the next new id ($next)."
    ))
    # cache the new running maximum for the subsequent staging checks
    if cached === nothing
        cached = Dict{Symbol, Int32}()
        injector.schema.meta[:setting_max_new] = cached
    end
    cached[field] = max(Int32(max_new), v)
    return nothing
end


"""
    _check_staged_death_reason!(reason)

Rejects positive death-reason codes: they are reserved for simulation-caused (pathogen)
deads, so the injector may only stage non-infection codes (<= 0, cf. GEMS'
`Individual.death_reason`, e.g. `GEMS.DEATH_REASON_NATURAL`) or `GEMS.DEFAULT_DEATH_REASON`.
"""
function _check_staged_death_reason!(reason)
    Int32(reason) <= 0 && return nothing
    throw(ArgumentError(
        "population injection: staged death_reason $(reason) is not allowed — positive codes are " *
        "reserved for simulation-caused (pathogen) deaths. Stage a non-infection code (<= 0) such as " *
        "GEMS.DEATH_REASON_NATURAL, or GEMS.DEFAULT_DEATH_REASON when unspecified."
    ))
end

"""
    _staged_death_is_alive(new_value)

Whether a staged `:death` value is the *alive* default rather than an explicit death.
The `:death` column's default state is "no death scheduled" (`GEMS.DEFAULT_TICK`, -1,
mirrored by `INJECTION_ALIVE_DEATH_TICK`); tables that carry this default verbatim
(e.g. rows passed to `stage_new_individuals!`) must not turn into deaths. `missing` and
`false` are treated as alive as well; any other value (a death day, or the constant
passed by `stage_death!`) means death.
"""
function _staged_death_is_alive(new_value)::Bool
    ismissing(new_value) && return true
    new_value isa Bool && return !new_value
    return new_value isa Real && new_value == INJECTION_ALIVE_DEATH_TICK
end

"""
    stage_event!(injector::Injector, ind_id::Int, field::Symbol, new_value, timestamp::Int16)

Stages a field change as an event in the injector.

Deaths are staged via `stage_death!` instead — staging `:death` or `:death_reason` here
is rejected (with a hint pointing to `stage_death!`), keeping `stage_event!` the single
path for regular field changes.

For setting columns (`household`, `office`, `schoolclass`, `municipality`) a value that is
not one of the base ids is a *new setting*: it must be either an already-staged new id
(e.g. another individual joining the same newly created setting) or the next free id
(`max(base ids, staged ids) + 1`, keeping the contiguous id range gap-free); otherwise an
`ArgumentError` is thrown at staging.

For `:death_reason` events, positive values are rejected at staging: they are reserved
for simulation-caused (pathogen) deaths — stage a non-infection code (<= 0) such as
`GEMS.DEATH_REASON_NATURAL`, or `GEMS.DEFAULT_DEATH_REASON` when unspecified.

# Arguments
- `injector::Injector`: The injector to stage the event in
- `ind_id::Int`: The individual id the event applies to
- `field::Symbol`: The field being updated
- `new_value`: The new value
- `timestamp::Int16`: The timestamp (day) of the event

# Returns
- `Event`: The created event
"""
# timestamp is untyped on purpose: values that are not exact Int16 days (out of range,
# fractional, missing, strings) must reach the descriptive staging error in _stage_event!
# rather than dying in an unhelpful MethodError at dispatch.
function stage_event!(injector::Injector, ind_id::Integer, field::Symbol, new_value, timestamp)
    # deaths and their reasons have a dedicated entry point (stage_death!); the manual
    # stage_event! path for them is closed on purpose, with a hint to the correct call
    if field === :death || field === :death_reason
        throw(ArgumentError(
            "population injection: $(field) cannot be staged via stage_event!. Stage deaths with " *
            "PI.stage_death!(injector, ind_id, reason, timestamp) instead, e.g. " *
            "PI.stage_death!(inj, $(ind_id), GEMS.DEATH_REASON_NATURAL, Int16($(timestamp))) — " *
            "reason may be nothing for a death without a reason."
        ))
    end
    return _stage_event!(injector, ind_id, field, new_value, timestamp)
end


"""
    _stage_event!(injector, ind_id, field, new_value, timestamp)

Internal staging without the death-field guard — used by `stage_death!` and
`stage_new_individuals!`. A `:death` event is always recorded; its value only
distinguishes alive from dead: alive values (`DEFAULT_TICK`, `missing`, `false`) are
stored as the alive marker `INJECTION_ALIVE_DEATH_TICK` (the engine skips them — new
individuals are alive by default), any other value as the dead `INJECTION_DEATH_FLAG`
(the timestamp is the day of death). `:death_reason` values must be non-infection codes
(<= 0).
"""
function _stage_event!(injector::Injector, ind_id::Integer, field::Symbol, new_value, timestamp)
    # Get types from schema meta information
    ind_id_type = injector.schema.meta[:ind_id_type]

    # Convert the individual id to the appropriate type with warning if conversion is needed
    converted_id = convert(ind_id_type, ind_id)
    if converted_id != ind_id
        @warn "Individual id $ind_id was converted to $converted_id to fit within the individual id type $ind_id_type"
    end

    # The staged timestamp must be an exact Int16 day: reject it with a descriptive staging
    # error instead of the raw InexactError/MethodError from convert() (an exact conversion
    # always equals the input, so there is nothing to warn about — it either fits or fails)
    converted_timestamp = try
        convert(Int16, timestamp)
    catch
        throw(ArgumentError(
            "population injection: timestamp $(timestamp) is not an exact Int16 value " *
            "($(typemin(Int16)):$(typemax(Int16))) — stage whole days that fit Int16."
        ))
    end

    # Check if the field exists
    if !haskey(injector.schema.field_to_index, field)
        error("Field $field not found in injector schema")
    end

    # death reasons: only non-infection codes may be staged (positive codes are reserved
    # for simulation-caused pathogen deaths)
    field === :death_reason && _check_staged_death_reason!(new_value)

    # death events: the staged value only tells "alive" from "dead" and is stored as a
    # marker, never as a raw value — alive values (the default state carried verbatim by
    # rows staged via stage_new_individuals!) are recorded as INJECTION_ALIVE_DEATH_TICK
    # so the event stream mirrors the rows, while real deaths carry INJECTION_DEATH_FLAG
    # (the timestamp is the day of death). Both bypass the column's closed value set — no
    # schema entry or update_schema! is needed; the engine realizes a death only for the flag.
    if field in (:death,)
        death_value = _staged_death_is_alive(new_value) ? INJECTION_ALIVE_DEATH_TICK : INJECTION_DEATH_FLAG
        event = Event{Int8}(converted_id, Int8(injector.schema.field_to_index[field]), death_value, converted_timestamp)
        push!(injector.events, event)
        return event
    end

    # Get the field index
    field_index = injector.schema.field_to_index[field]

    # Identity-mapped columns (id/age/sex/settings) have an open value set: the staged value
    # is stored as-is in the column's own type — no closed value set to check, no
    # `update_schema!` needed. Setting columns keep their contiguity rule.
    if is_identity_field(field)
        converted_value = _encode_identity!(injector.schema.columns[field].min_type, new_value, field)
        if converted_value != new_value
            @warn "Value $new_value was converted to $converted_value for encoding"
        end
        _check_staged_setting_id!(injector, field, converted_value)
        event = Event{injector.schema.columns[field].min_type}(converted_id, field_index, converted_value, converted_timestamp)
        push!(injector.events, event)
        return event
    end

    # if it is a float in the schema as well as in new_value then just create the event, as no encoding is needed.
    if injector.schema.columns[field].min_type <: AbstractFloat
        converted_value = convert(injector.schema.columns[field].min_type, new_value)
        if converted_value != new_value
            @warn "Value $new_value was converted to $converted_value for encoding"
        end

        event = Event{injector.schema.columns[field].min_type}(converted_id, field_index, converted_value, converted_timestamp)
        push!(injector.events, event)
        return event
    else

        # Attempt to encode the value
        schema_entry = injector.schema.columns[field]
        forward_map = schema_entry.forward_map

        # Try to find the value in the forward map directly
        if !haskey(injector.schema.columns[field].forward_map, new_value)
            # Try to convert to the original type (only the conversion is guarded — the
            # "could not be encoded" error below must not be swallowed by this catch)
            try
                converted_value = convert(injector.schema.columns[field].original_type, new_value)
            catch
                error("Value $new_value could not be converted to a valid type for field $field")
            end
            if !haskey(injector.schema.columns[field].forward_map, converted_value)
                error("Value $new_value could not be encoded for field $field")
            end
            if converted_value != new_value
                @warn "Value $new_value was converted to $converted_value for encoding"
                new_value = converted_value
            end
        end
        _check_staged_setting_id!(injector, field, new_value)
        encoded_value = injector.schema.columns[field].forward_map[new_value]

        # Get the encoded value


        # Create event with the specific type and explicit timestamp
        event = Event{injector.schema.columns[field].min_type}(converted_id, field_index, encoded_value, converted_timestamp)
        push!(injector.events, event)

        return event
    end
end


# Value stored for death events that state a death (`stage_death!`, or `stage_event!` on
# the `:death` column with a death value) — a constant marker (the timestamp is the day
# of death), so the event bypasses the schema's closed value set. Alive values are
# recorded as `INJECTION_ALIVE_DEATH_TICK` instead; the engine realizes a death only for
# this flag and skips the alive marker.
const INJECTION_DEATH_FLAG = Int8(1)

# The `:death` column's alive sentinel — the value that means "no death scheduled"
# (mirrors GEMS' `DEFAULT_TICK`). Staging `:death` with an alive value (see
# `_staged_death_is_alive`) records an event carrying this marker: the event stream
# mirrors the staged rows, but the engine marks nobody dead from it. Used both as the
# event value and as the alive fill for snapshot rows padded for new individuals.
const INJECTION_ALIVE_DEATH_TICK = Int8(-1)


"""
    _pad_alive_death_columns!(extra_rows::DataFrame, snapshot_df::DataFrame)

Fill the death columns of rows a snapshot padded in for new individuals with their alive
defaults instead of `missing`: alive is a known state (the `Individual` field defaults),
not an open question — `:death` gets the alive sentinel (`INJECTION_ALIVE_DEATH_TICK`,
mirroring GEMS' `DEFAULT_TICK`), `:death_reason` -1 (mirroring GEMS'
`DEFAULT_DEATH_REASON`), each in the base column's element type. Columns the base table
does not declare are skipped.
"""
function _pad_alive_death_columns!(extra_rows::DataFrame, snapshot_df::DataFrame)
    for (col, alive) in ((:death, INJECTION_ALIVE_DEATH_TICK), (:death_reason, Int8(-1)))
        hasproperty(snapshot_df, col) || continue
        col_type = nonmissingtype(eltype(snapshot_df[!, col]))
        extra_rows[!, col] = fill(convert(col_type, alive), nrow(extra_rows))
    end
    return extra_rows
end


"""
    stage_death!(injector, ind_id, reason, timestamp)

Stages the death of individual `ind_id` at `timestamp` (the day of death, same argument
order as `stage_event!`): the `:death` event — whose value is a constant flag and needs
no schema entry — and, when `reason` is not `nothing`, a `:death_reason` event with the
same timestamp.

`reason` must be a non-infection death code (<= 0; positive codes are reserved for
simulation-caused pathogen deaths and are rejected), e.g.
`GEMS.DEATH_REASON_NATURAL` or `GEMS.DEFAULT_DEATH_REASON`; `nothing` stages the death
without a reason.

The base population must declare a `:death` column, and a `:death_reason` column when a
reason is staged — both with their default state for the alive population (e.g.
`fill(GEMS.DEFAULT_TICK, n)` and `fill(Int8(GEMS.DEFAULT_DEATH_REASON), n)`) — so the
schema knows them. A missing column is an `ArgumentError` pointing at adding the column
and its default values to the base population and rebuilding the schema with
`create_column_schema`. An already-declared `:death_reason` column keeps its closed value
set (extend it via `update_schema!` for codes beyond the base values).

# Arguments
- `injector::Injector`: The injector to stage the event in
- `ind_id::Int`: The id of the individual who dies
- `reason::Union{Int8,Nothing}`: The death reason code, or `nothing` for none
- `timestamp::Int16`: The day of death

# Returns

- `Event`: The staged `:death` event (the `:death_reason` event, if any, follows it)
"""
function stage_death!(injector::Injector, ind_id::Integer, reason::Union{Int8,Nothing}, timestamp)
    # validate before staging anything, so an invalid reason leaves no partial state
    reason !== nothing && _check_staged_death_reason!(reason)
    # the death columns must be declared in the base population (with their default state),
    # so the schema knows them — the injector does not add columns on its own
    if !haskey(injector.schema.field_to_index, :death)
        throw(ArgumentError(
            "population injection: the injector schema has no :death column, so stage_death! cannot be " *
            "used. Add a :death column to the base population DataFrame — default state: everyone alive, " *
            "e.g. base[!, :death] = fill(GEMS.DEFAULT_TICK, nrow(base)) — and build the schema with " *
            "PI.create_column_schema(base)."
        ))
    end
    if reason !== nothing && !haskey(injector.schema.field_to_index, :death_reason)
        throw(ArgumentError(
            "population injection: the injector schema has no :death_reason column, so stage_death! with a " *
            "reason cannot be used. Add a :death_reason column to the base population DataFrame — default " *
            "state: GEMS.DEFAULT_DEATH_REASON, " *
            "e.g. base[!, :death_reason] = fill(Int8(GEMS.DEFAULT_DEATH_REASON), nrow(base)) — and build the " *
            "schema with PI.create_column_schema(base); or stage the death without a reason."
        ))
    end
    ev = _stage_event!(injector, ind_id, :death, 1, timestamp)
    reason === nothing && return ev
    _stage_event!(injector, ind_id, :death_reason, reason, timestamp)
    return ev
end

"""
    decode_value(injector::Injector, field::Symbol, encoded_value)

Decodes an encoded value back to its original form.

# Arguments
- `injector::Injector`: The injector containing the schema
- `field::Symbol`: The field to decode for
- `encoded_value`: The encoded value to decode

# Returns
- `Any`: The original value
"""
function decode_value(injector::Injector, field::Symbol, encoded_value)
    if is_identity_field(field)
        return convert(injector.schema.columns[field].original_type, encoded_value)
    end
    if injector.schema.columns[field].min_type <: AbstractFloat
        return convert(injector.schema.columns[field].original_type, encoded_value)
    else
        schema_entry = injector.schema.columns[field]
        reverse_map = schema_entry.reverse_map
        return reverse_map[encoded_value]
    end
end

"""
    get_original_value(injector::Injector, event::Event)

Gets the original value from a staged event.

# Arguments
- `injector::Injector`: The injector containing the schema
- `event::Event`: The event to extract the value from

# Returns
- `Any`: The original value of the event
"""
function get_original_value(injector::Injector, event::Event)
    # Get field symbol from index
    field_symbol = injector.schema.index_to_field[event.field+1]  # +1 because Int8 is 0-indexed
    return decode_value(injector, field_symbol, event.new_value)
end

# Verify that the columns of the provided base population table match the hashes stored in
# the injector's schema meta (i.e. it is the day-0 table the injector was staged from)
function verify_base_population_hashes(injector::Injector, base_population::DataFrame)
    for field in names(base_population)
        field_symbol = Symbol(field)
        computed_hash = stable_hash(base_population[:, field])

        if !haskey(injector.schema.meta[:hash], field_symbol)
            error("No hash stored for column $field_symbol")
        end

        stored_hash = injector.schema.meta[:hash][field_symbol]
        if computed_hash != stored_hash
            error("Hash mismatch for column $field_symbol: computed=$computed_hash, stored=$stored_hash")
        end
    end
    return nothing
end

"""
    snapshot(injector::Injector, base_population::DataFrame, timestamp::Int16)

Reconstructs the population table at a given day of the staged-changes timeline.

# Arguments
- `injector::Injector`: The injector containing the staged events
- `base_population::DataFrame`: The base population table (day 0) to start from
- `timestamp::Int16`: The day to create the snapshot for

# Returns
- `DataFrame`: The population table at the given day (new individuals are appended as rows).
  Death events (cf. `stage_event!`) are written into the death column as their marker
  (`1` dead, `-1` alive); appended rows carry the death columns' alive defaults (`-1`),
  never `missing` — a newborn without a death event is alive.
"""
function snapshot(injector::Injector, base_population::DataFrame, timestamp::Int16)
    verify_base_population_hashes(injector, base_population)

    # Create a copy of the base population to avoid modifying it
    snapshot_df = deepcopy(base_population)

    # Find all events that occurred before or at the given timestamp
    relevant_events = filter(event -> event.timestamp <= timestamp, injector.events)

    if isempty(relevant_events)
        return snapshot_df
    end

    # Process events in chronological order
    sorted_events = sort(relevant_events, by=event -> event.timestamp)

    # Find the maximum individual id we need to support
    max_ind_id = maximum(event.ind_id for event in sorted_events)

    # Expand the DataFrame if new individuals are needed beyond the base population
    current_num_rows = nrow(snapshot_df)

    if max_ind_id > current_num_rows
        allowmissing!(snapshot_df)
        # Calculate how many additional rows we need
        num_new_individuals = max_ind_id - current_num_rows
        extra_rows = DataFrame(fill(missing, num_new_individuals, ncol(snapshot_df)), names(snapshot_df))
        # add individual IDs for units to be added
        extra_rows.id = collect((current_num_rows+1):max_ind_id)
        # padded rows are individuals added by the staged timeline: their death columns
        # carry the alive defaults (a known state), not `missing`
        _pad_alive_death_columns!(extra_rows, snapshot_df)
        append!(snapshot_df, extra_rows)
    end

    # Now process all events
    for event in sorted_events
        # Get the individual id and field from the event
        ind_id = Int(event.ind_id)  # row index into the snapshot DataFrame
        field_index = event.field
        field_symbol = injector.schema.index_to_field[field_index+1]

        # Death events carry no value to decode (the timestamp was the day of death) — write
        # the event's alive/dead marker into the column (created alive if the base table has
        # none); a missing :death_reason column is created the same way, filled with the
        # alive default.
        if field_symbol in (:death, :death_reason)
            if !hasproperty(snapshot_df, field_symbol)
                snapshot_df[!, field_symbol] .= Int8(-1)
            end
            new_value = field_symbol === :death ? event.new_value : decode_value(injector, field_symbol, event.new_value)
            snapshot_df[ind_id, field_symbol] = new_value
            continue
        end

        # Decode the value from the event
        original_value = decode_value(injector, field_symbol, event.new_value)

        # Update the snapshot dataframe (now guaranteed to have enough rows)
        snapshot_df[ind_id, field_symbol] = original_value
    end
    # revert columns to original type from Union(missing, type). Columns that are in snapshot_df but not in the injector will be returned
    # as Union(missing, type)!
    disallowmissing!(snapshot_df, error = false)
    return snapshot_df
end

"""
    snapshot(injector::Injector, ind_id::Integer, base_population::DataFrame, timestamp::Int16)

Reconstructs the table for a specified individual at a given day of the staged-changes timeline.

# Arguments
- `injector::Injector`: The injector containing the staged events
- `ind_id::Int`: The individual id the snapshot applies to
- `base_population::DataFrame`: The base population table (day 0) to start from
- `timestamp::Int16`: The day to create the snapshot for

# Returns
- `DataFrame`: The population table at the given day for an individual
"""
function snapshot(injector::Injector, ind_id::Integer, base_population::DataFrame, timestamp::Int16)
    verify_base_population_hashes(injector, base_population)

    # Create a copy of the base individual to avoid modifying it.
    # Must be a 1-row DataFrame (not a DataFrameRow) so a missing death column can be added.
    snapshot_df = DataFrame(deepcopy(base_population[ind_id, :]))

    # Find all events for the individual that occurred before or at the given timestamp
    relevant_events = filter(event -> event.ind_id == ind_id && event.timestamp <= timestamp, injector.events)

    if isempty(relevant_events)
        return snapshot_df
    end

    # Process events in chronological order
    sorted_events = sort(relevant_events, by=event -> event.timestamp)

    # Now process all events
    for event in sorted_events
        # Get field from the event
        field_index = event.field
        field_symbol = injector.schema.index_to_field[field_index+1]

        # Death events carry no value to decode (the timestamp was the day of death) — write
        # the event's alive/dead marker (into the column, created alive if the base table has
        # none); a missing :death_reason column is created the same way, filled with the
        # alive default.
        if field_symbol in (:death, :death_reason)
            if !hasproperty(snapshot_df, field_symbol)
                snapshot_df[!, field_symbol] .= Int8(-1)
            end
            new_value = field_symbol === :death ? event.new_value : decode_value(injector, field_symbol, event.new_value)
            snapshot_df[1, field_symbol] = new_value
            continue
        end

        # Decode the value from the event
        original_value = decode_value(injector, field_symbol, event.new_value)

        # Update the snapshot dataframe
        snapshot_df[1, field_symbol] = original_value
    end

    return snapshot_df
end

"""
    snapshot(injector::Injector, ind_id::AbstractVector{<:Integer}, base_population::DataFrame, timestamp::Int16)

Reconstructs the table for the specified individuals at a given day of the staged-changes timeline.

# Arguments
- `injector::Injector`: The injector containing the staged events
- `ind_id::AbstractVector{<:Integer}`: The vector of individual ids the snapshot applies to
- `base_population::DataFrame`: The base population table (day 0) to start from
- `timestamp::Int16`: The day to create the snapshot for

# Returns
- `DataFrame`: The population table at the given day for an individual
"""
function snapshot(injector::Injector, ind_id::AbstractVector{<:Integer}, base_population::DataFrame, timestamp::Int16)
    verify_base_population_hashes(injector, base_population)

    # Create a copy of the base individuals to avoid modifying it
    snapshot_df = deepcopy(base_population[ind_id, :])
    # The subframe is compact (rows 1..n), so map each individual id to its row position within it
    ind_to_row = Dict(Int(i) => j for (j, i) in enumerate(ind_id))

    # Find all events for the individuals that occurred before or at the given timestamp
    relevant_events = filter(event -> event.ind_id ∈ ind_id && event.timestamp <= timestamp, injector.events)

    if isempty(relevant_events)
        return snapshot_df
    end

    # Process events in chronological order
    sorted_events = sort(relevant_events, by=event -> event.timestamp)

    # Now process all events
    for event in sorted_events
        # Get field and row position from the event (the id must be mapped into the compact subframe)
        row = ind_to_row[Int(event.ind_id)]
        field_index = event.field
        field_symbol = injector.schema.index_to_field[field_index+1]

        # Death events carry no value to decode (the timestamp was the day of death) — write
        # the event's alive/dead marker into the column (created alive if the base table has
        # none); a missing :death_reason column is created the same way, filled with the
        # alive default.
        if field_symbol in (:death, :death_reason)
            if !hasproperty(snapshot_df, field_symbol)
                snapshot_df[!, field_symbol] .= Int8(-1)
            end
            new_value = field_symbol === :death ? event.new_value : decode_value(injector, field_symbol, event.new_value)
            snapshot_df[row, field_symbol] = new_value
            continue
        end

        # Decode the value from the event
        original_value = decode_value(injector, field_symbol, event.new_value)

        # Update the snapshot dataframe
        snapshot_df[row, field_symbol] = original_value
    end

    return snapshot_df
end

"""
    get_change_history(injector::Injector, ind_id::Integer, base_population::DataFrame)

Reconstructs the table for the specified individuals at each changepoint.

# Arguments
- `injector::Injector`: The injector containing the staged events
- `ind_id::Int`: The individual id for which the change history should be constructed
- `base_population::DataFrame`: The base population table (day 0) to start from

# Returns
- `DataFrame`: The individual table with a row for each time point of change
"""
function get_change_history(injector::Injector, ind_id::Integer, base_population::DataFrame)
    verify_base_population_hashes(injector, base_population)

    # Create a copy of the base individual to avoid modifying it. Must be DataFrame() otherwise cannot add column
    # newly added are not in original dataframe and separately handled
    original_ind =  ind_id ∈ base_population.id
    if original_ind
        snapshot_df = DataFrame(deepcopy(base_population[ind_id, :]))
        insertcols!(snapshot_df, 1, :timestamp => 0) # add timestamp column in first position
    end

    # Find all events that occurred before or at the given timestamp
    relevant_events = filter(event -> event.ind_id == ind_id, injector.events)

    if isempty(relevant_events) & original_ind
        return snapshot_df
    elseif isempty(relevant_events)
        @warn "No individual with specified ID contained in logger."
        return
    end

    # Process events in chronological order
    sorted_events = sort(relevant_events, by=event -> event.timestamp)

    # if not in original dataframe, must be newly added (newborn or immigration)
    if !original_ind
        creation = DataFrame(sorted_events)
        creation_date = minimum(creation.timestamp)
        creation_id = findall(creation.timestamp .== creation_date)

        snapshot_df = DataFrame(
            timestamp = creation_date,
            id = creation.ind_id[1]
        )
    
        # loop over staged events
        for event in sorted_events[creation_id]
            # Get field from the event
            field_index = event.field
            field_symbol = injector.schema.index_to_field[field_index+1]

            if field_symbol in (:death, :death_reason)
                if !hasproperty(snapshot_df, field_symbol)
                    snapshot_df[!, field_symbol] .= Int8(-1)
                end
                snapshot_df[!, field_symbol] .= field_symbol === :death ? event.new_value : decode_value(injector, field_symbol, event.new_value)
                snapshot_df.timestamp .= event.timestamp
                continue
            end

            # Decode the value from the event
            original_value = decode_value(injector, field_symbol, event.new_value)

            # Update the snapshot dataframe
            snapshot_df[!, field_symbol] .= original_value
        end
        sorted_events = sorted_events[Not(creation_id)]
    end

    # should always update latest row. Initiate with original row
    tmp_df = copy(snapshot_df)

    # loop over days, since we return only integer timestamps
    for events_this_day in groupby(DataFrame(sorted_events), :timestamp)

        tmp_df.timestamp .= events_this_day.timestamp[1]

        # Now process all events
        for event in eachrow(events_this_day)
            # Get field from the event
            field_index = event.field
            field_symbol = injector.schema.index_to_field[field_index+1]

            if field_symbol in (:death, :death_reason)
                if !hasproperty(snapshot_df, field_symbol)
                    snapshot_df[!, field_symbol] .= Int8(-1)
                end
                if !hasproperty(tmp_df, field_symbol)
                    tmp_df[!, field_symbol] .= Int8(-1)
                end
                tmp_df[!, field_symbol] .= field_symbol === :death ? event.new_value : decode_value(injector, field_symbol, event.new_value)
            else
                # Decode the value from the event
                original_value = decode_value(injector, field_symbol, event.new_value)
                # Update the snapshot dataframe
                tmp_df[!, field_symbol] .= original_value
            end
        end
        append!(snapshot_df, tmp_df)
    end
    return snapshot_df
end
"""
    save(injector, path)

Saves the staged changes (schema + events) to a `.jld2` file at `path`
(mirrors GEMS' `save(population, path)`).
"""
function save(injector::Injector, path::AbstractString)
    @save path schema = injector.schema events = injector.events
end

"""
    Injector(path::AbstractString)

Loads a previously saved injector from a `.jld2` file at `path` (mirrors GEMS' `Population(path)`).
"""
function Injector(path::AbstractString)
    @load path schema events
    inj = Injector(schema)
    inj.events = events
    return inj
end

"""
    stage_new_individuals!(injector, new_individuals::DataFrame, timestamp)

Stages one or more new individuals in the injector: each DataFrame row corresponds to
one individual (same convention as GEMS' `Population(df)`). The injector assigns the
new individuals' ids (continuing its individual counter); an `id` column in
`new_individuals` is ignored. All other columns are staged as events at `timestamp`.
`:sex` and `:age` are **required** — a table without them (or with `missing` values
there) throws an `ArgumentError` before anything is staged. `timestamp` must be an
exact Int16 day; anything else throws an `ArgumentError` at staging.

New individuals are **alive by default**: a `death` column carrying the alive sentinel
(`GEMS.DEFAULT_TICK`, i.e. -1) or `missing` is recorded as an alive-marker event that
realizes no death — only an explicit death value makes a (born-)dead individual.
Likewise, a `death_reason` of `GEMS.DEFAULT_DEATH_REASON` keeps the alive default.

# Returns

- `Vector{Int}`: the assigned individual ids
"""
function stage_new_individuals!(injector::Injector, new_individuals::DataFrame, timestamp)
    # Validate before recording anything: new individuals require :sex and :age (the same
    # requirement apply_injection_events! enforces at application — failing here keeps a
    # malformed row from half-staging and surfacing mid-run)
    for req in (:sex, :age)
        if !hasproperty(new_individuals, req) || any(ismissing, new_individuals[!, req])
            throw(ArgumentError(
                "population injection: stage_new_individuals! requires a non-missing :$(req) " *
                "column for every new individual (checked before staging, so nothing was " *
                "recorded). Add :$(req) to the new-individuals table."
            ))
        end
    end

    # Get types from schema meta information
    ind_id_type = injector.schema.meta[:ind_id_type]
    current_individuals = injector.schema.meta[:current_individuals]
    num_individuals = injector.schema.meta[:num_individuals]

    new_ids = collect(current_individuals .+ Base.OneTo(nrow(new_individuals)))
    # Convert the generated individual id to appropriate type with warning if conversion is needed
    converted_id = convert(ind_id_type, maximum(new_ids))
    if converted_id != maximum(new_ids)
        @warn "Individual id $(maximum(new_ids)) was converted to $converted_id to fit within the individual id type $ind_id_type"
    end

    # The staged timestamp must be an exact Int16 day (same descriptive error as _stage_event!)
    converted_timestamp = try
        convert(Int16, timestamp)
    catch
        throw(ArgumentError(
            "population injection: timestamp $(timestamp) is not an exact Int16 value " *
            "($(typemin(Int16)):$(typemax(Int16))) — stage whole days that fit Int16."
        ))
    end

    foreach(enumerate(eachrow(new_individuals))) do (n, row)
        i = convert(ind_id_type, new_ids[n])
        for (field, value) in pairs(row)
            field === :id && continue  # identity is assigned by the injector; an input id column is ignored
            _stage_event!(injector, i, field, value, converted_timestamp)   # internal: alive death values are no-ops; explicit ones keep born-dead newborns working
        end
    end

    # Update schema metadata with new individual count
    injector.schema.meta[:current_individuals] = maximum(new_ids)

    # Return the generated ids which serve as the individuals' ids in the population
    return new_ids
end

"""
    stage_new_individual!(injector, props, timestamp)

Stages a single new individual in the injector. `props` provides the individual's
attributes as a `Dict`, `NamedTuple`, or `DataFrameRow` (same input style as GEMS'
`Individual(properties)`); `sex` and `age` must be present. The individual's id is
assigned by the injector (continuing its individual counter).

# Returns

- `Int`: the assigned individual id
"""
function stage_new_individual!(injector::Injector, props, timestamp)::Int
    df = DataFrame([String(k) => Any[v] for (k, v) in pairs(props)]...)
    return Int(first(stage_new_individuals!(injector, df, timestamp)))
end

using Base.Threads

# ------------------------------------------------------------------
# Constants and mixing function
# ------------------------------------------------------------------
const HASH_SEED = UInt64(0x9e3779b97f4a7c15)

@inline function mix(h::UInt64, x::UInt64)
    # deterministic mixing of two UInt64 values
    h ⊻= x
    h *= 0xbf58476d1ce4e5b9
    h ⊻= h >> 31
    return h
end

# ------------------------------------------------------------------
# Zero-copy hashing for isbits vectors (single vector)
# ------------------------------------------------------------------
function hash_isbits_vector(v::AbstractVector{T}) where {T}
    # process the vector 8 bytes at a time
    nbytes = sizeof(T) * length(v)
    nchunks = fld(nbytes, 8)
    rem = nbytes % 8

    ptr = Ptr{UInt64}(pointer(v))
    h = HASH_SEED

    # hash full 8-byte chunks
    @inbounds for i in 1:nchunks
        h = mix(h, unsafe_load(ptr, i))
    end

    # hash remaining bytes if any
    if rem > 0
        p = Ptr{UInt8}(pointer(v)) + nchunks * 8
        tail = UInt64(0)
        @inbounds for i in 0:(rem-1)
            tail |= UInt64(unsafe_load(p + i)) << (8 * i)
        end
        h = mix(h, tail)
    end

    return h ⊻ UInt64(length(v))
end

# ------------------------------------------------------------------
# Stable hash for vectors (multi-level nested)
# ------------------------------------------------------------------
function stable_hash(v::AbstractVector{T}) where {T}
    if isbitstype(T)
        # fast path for numeric arrays
        return hash_isbits_vector(v)
    elseif all(x -> isa(x, AbstractVector), v)
        # outer vector is "columns": hash each column in parallel
        ncols = length(v)
        partials = Vector{UInt64}(undef, ncols)

        @threads for j in 1:ncols
            partials[j] = stable_hash(v[j])  # recursively hash each column
        end

        # combine column hashes deterministically
        h = HASH_SEED
        @inbounds for x in partials
            h = mix(h, x)
        end

        return h ⊻ UInt64(ncols)
    else
        # fallback: hash element by element
        h = HASH_SEED
        @inbounds for x in v
            h = mix(h, stable_hash(x))
        end
        return h ⊻ UInt64(length(v))
    end
end

# ------------------------------------------------------------------
# Scalars
# ------------------------------------------------------------------
stable_hash(x::Integer) = mix(HASH_SEED, UInt64(x))
stable_hash(x::AbstractFloat) = mix(HASH_SEED, reinterpret(UInt64, x))

# ------------------------------------------------------------------
# Strings
# ------------------------------------------------------------------
function stable_hash(s::AbstractString)
    bytes = codeunits(s)
    return hash_isbits_vector(bytes)
end

# Export all public functions and types
export Event, ColumnSchema, InjectorSchema, Injector
export create_column_schema, stage_event!, stage_death!, stage_new_individual!, stage_new_individuals!
export encode_value, decode_value, get_original_value, snapshot
export save, minimal_encoding, update_schema!
end # module PopulationInjection


###
### INJECTION STATE (flat GEMS namespace)
###
### Defined at top level (outside the module) because `simulation/simulation.jl` — which is
### included before `population/population_injection_methods.jl` — needs the type when it
### declares the `Simulation.population_injection` field.
###

"""
    PopulationInjectionState

Per-Simulation bookkeeping for population injection.

- `injector`: the attached `PopulationInjection.Injector`
- `order`: stable (MergeSort) permutation of `1:length(injector.events)` sorted by timestamp
- `cursor`: events `1:cursor` have been applied already
- `initial_cursor`: the baked-in (pre-snapshot) prefix length; restored by `reset!`
- `offset`: snapshot day; an event is due when `timestamp <= tick + offset`
"""
mutable struct PopulationInjectionState
    injector::PopulationInjection.Injector
    order::Vector{Int}
    cursor::Int
    initial_cursor::Int
    offset::Int16
end
