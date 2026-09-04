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

get_element_type(::ColumnSchema{T}) where {T} = T
get_element_type(::Event{T}) where {T} = T

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

"""
    create_column_schema(df::DataFrame)

Creates a schema for all columns in a DataFrame.

# Arguments
- `df::DataFrame`: The base population table to create the schema for

# Returns
- `InjectorSchema`: The created schema
"""
function create_column_schema(df::DataFrame, float_tol=1e-6)
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
        forward_map, reverse_map, min_type = minimal_encoding(col_data, float_tol)
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
- `Error`: If the value is not found in the encoding
"""
function encode_value(injector::Injector, field::Symbol, value)
    schema_entry = injector.schema.columns[field]
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
("no setting") must extend the range one at a time — every id up to the maximum must be set,
and every new id must be `max(id) + 1`. Anything else is a staging error.
"""
function _check_staged_setting_id!(injector::Injector, field::Symbol, value)
    base_counts = get(injector.schema.meta, :setting_base_count, nothing)
    (isnothing(base_counts) || !haskey(base_counts, field)) && return nothing
    n_base = base_counts[field]
    v = convert(Int32, value)
    v in 1:n_base && return nothing                       # existing setting (ids 1:N after GEMS' normalization)
    v == Main.GEMS.DEFAULT_SETTING_ID && return nothing   # "no setting" — always allowed
    # the new ids already staged for this field (each of them was validated when staged,
    # so the range stays gap-free): only the maximum matters
    fidx = injector.schema.field_to_index[field]
    max_new = 0
    for ev in injector.events
        ev.field == fidx || continue
        val = Int32(get_original_value(injector, ev))
        val > n_base && (max_new = max(max_new, val))
    end
    next = (max_new == 0 ? Int32(n_base) : Int32(max_new)) + Int32(1)
    v == next || throw(ArgumentError(
        "population injection: staged $(field) id $v is not a valid new setting id. GEMS indexes " *
        "settings by id without gaps (the base has $n_base $(field) setting(s), $(max_new == 0 ? 0 : max_new - n_base) " *
        "new id(s) already staged), so every id up to the maximum must be set and every new id must " *
        "be max(id) + 1; the next valid new id is $next."
    ))
    return nothing
end


"""
    stage_event!(injector::Injector, ind_id::Int, field::Symbol, new_value, timestamp::Int16)

Stages an event in the injector.

For setting columns (`household`, `office`, `schoolclass`, `municipality`) a value that is
not one of the base ids is a *new setting* and must extend the contiguous id range one at a
time (the next valid new id is `max(base ids, staged ids) + 1`); otherwise an `ArgumentError`
is thrown at staging.

# Arguments
- `injector::Injector`: The injector to stage the event in
- `ind_id::Int`: The individual id the event applies to
- `field::Symbol`: The field being updated
- `new_value`: The new value
- `timestamp::Int16`: The timestamp (day) of the event

# Returns
- `Event`: The created event
"""
function stage_event!(injector::Injector, ind_id::Integer, field::Symbol, new_value, timestamp::Integer)
    # Get types from schema meta information
    ind_id_type = injector.schema.meta[:ind_id_type]

    # Convert the individual id to the appropriate type with warning if conversion is needed
    converted_id = convert(ind_id_type, ind_id)
    if converted_id != ind_id
        @warn "Individual id $ind_id was converted to $converted_id to fit within the individual id type $ind_id_type"
    end

    # Convert timestamp to Int16 with warning if conversion is needed
    converted_timestamp = convert(Int16, timestamp)
    if converted_timestamp != timestamp
        @warn "Timestamp $timestamp was converted to $converted_timestamp to fit within Int16"
    end

    # Check if the field exists
    if !haskey(injector.schema.field_to_index, field)
        error("Field $field not found in injector schema")
    end

    # Get the field index
    field_index = injector.schema.field_to_index[field]

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
            # Try to convert to the original type
            try
                converted_value = convert(injector.schema.columns[field].original_type, new_value)
                if !haskey(injector.schema.columns[field].forward_map, converted_value)
                    error("Value $new_value could not be encoded for field $field")
                end
                if converted_value != new_value
                    @warn "Value $new_value was converted to $converted_value for encoding"
                    new_value = converted_value
                end
            catch
                error("Value $new_value could not be converted to a valid type for field $field")
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

"""
    snapshot(injector::Injector, base_population::DataFrame, timestamp::Int16)

Reconstructs the population table at a given day of the staged-changes timeline.

# Arguments
- `injector::Injector`: The injector containing the staged events
- `base_population::DataFrame`: The base population table (day 0) to start from
- `timestamp::Int16`: The day to create the snapshot for

# Returns
- `DataFrame`: The population table at the given day (new individuals are appended as rows)
"""
function snapshot(injector::Injector, base_population::DataFrame, timestamp::Int16)
    # Verify that the hash of the provided dataframe coincides with the one stored in meta.schema
    for field in names(base_population)
        field_symbol = Symbol(field)
        col_data = base_population[:, field]
        computed_hash = stable_hash(col_data)

        if !haskey(injector.schema.meta[:hash], field_symbol)
            error("No hash stored for column $field_symbol")
        end

        stored_hash = injector.schema.meta[:hash][field_symbol]
        if computed_hash != stored_hash
            error("Hash mismatch for column $field_symbol: computed=$computed_hash, stored=$stored_hash")
        end
    end

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
        append!(snapshot_df, extra_rows)
    end

    # Now process all events
    for event in sorted_events
        # Get the individual id and field from the event
        ind_id = Int(event.ind_id)  # row index into the snapshot DataFrame
        field_index = event.field
        field_symbol = injector.schema.index_to_field[field_index+1]

        # Decode the value from the event
        original_value = decode_value(injector, field_symbol, event.new_value)

        # Update the snapshot dataframe (now guaranteed to have enough rows)
        snapshot_df[ind_id, field_symbol] = original_value
    end

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
    # Verify that the hash of the provided dataframe coincides with the one stored in meta.schema
    for field in names(base_population)
        field_symbol = Symbol(field)
        col_data = base_population[:, field]
        computed_hash = stable_hash(col_data)

        if !haskey(injector.schema.meta[:hash], field_symbol)
            error("No hash stored for column $field_symbol")
        end

        stored_hash = injector.schema.meta[:hash][field_symbol]
        if computed_hash != stored_hash
            error("Hash mismatch for column $field_symbol: computed=$computed_hash, stored=$stored_hash")
        end
    end

    # Create a copy of the base individual to avoid modifying it
    snapshot_df = deepcopy(base_population[ind_id, :])

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

        # Decode the value from the event
        original_value = decode_value(injector, field_symbol, event.new_value)

        # Update the snapshot dataframe
        snapshot_df[field_symbol] = original_value
    end

    return snapshot_df
end

"""
    snapshot(injector::Injector, ind_id::Vector{Integer}, base_population::DataFrame, timestamp::Int16)

Reconstructs the table for the specified individuals at a given day of the staged-changes timeline.

# Arguments
- `injector::Injector`: The injector containing the staged events
- `ind_id::Vector{Int}`: The vector of individual ids the snapshot applies to
- `base_population::DataFrame`: The base population table (day 0) to start from
- `timestamp::Int16`: The day to create the snapshot for

# Returns
- `DataFrame`: The population table at the given day for an individual
"""
function snapshot(injector::Injector, ind_id::Vector{Integer}, base_population::DataFrame, timestamp::Int16)
    # Verify that the hash of the provided dataframe coincides with the one stored in meta.schema
    for field in names(base_population)
        field_symbol = Symbol(field)
        col_data = base_population[:, field]
        computed_hash = stable_hash(col_data)

        if !haskey(injector.schema.meta[:hash], field_symbol)
            error("No hash stored for column $field_symbol")
        end

        stored_hash = injector.schema.meta[:hash][field_symbol]
        if computed_hash != stored_hash
            error("Hash mismatch for column $field_symbol: computed=$computed_hash, stored=$stored_hash")
        end
    end

    # Create a copy of the base individuals to avoid modifying it
    snapshot_df = deepcopy(base_population[ind_id, :])

    # Find all events for the individuals that occurred before or at the given timestamp
    relevant_events = filter(event -> event.ind_id ∈ ind_id && event.timestamp <= timestamp, injector.events)

    if isempty(relevant_events)
        return snapshot_df
    end

    # Process events in chronological order
    sorted_events = sort(relevant_events, by=event -> event.timestamp)

    # Now process all events
    for event in sorted_events
        # Get field and index from the event
        ind_id = Int(event.ind_id)
        field_index = event.field
        field_symbol = injector.schema.index_to_field[field_index+1]

        # Decode the value from the event
        original_value = decode_value(injector, field_symbol, event.new_value)

        # Update the snapshot dataframe
        snapshot_df[ind_id, field_symbol] = original_value
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
    # Verify that the hash of the provided dataframe coincides with the one stored in meta.schema
    for field in names(base_population)
        field_symbol = Symbol(field)
        col_data = base_population[:, field]
        computed_hash = stable_hash(col_data)

        if !haskey(injector.schema.meta[:hash], field_symbol)
            error("No hash stored for column $field_symbol")
        end

        stored_hash = injector.schema.meta[:hash][field_symbol]
        if computed_hash != stored_hash
            error("Hash mismatch for column $field_symbol: computed=$computed_hash, stored=$stored_hash")
        end
    end

    # Create a copy of the base individual to avoid modifying it. Must be DataFrame() otherwise cannot add column
    snapshot_df = DataFrame(deepcopy(base_population[ind_id, :]))
    insertcols!(snapshot_df, 1, :timestamp => 0) #add timestamp column in first position

    # Find all events that occurred before or at the given timestamp
    relevant_events = filter(event -> event.ind_id == ind_id, injector.events)

    if isempty(relevant_events)
        return snapshot_df
    end

    # Process events in chronological order
    sorted_events = sort(relevant_events, by=event -> event.timestamp)

    # should always update latest row. Initiate with original row
    tmp_df = copy(snapshot_df)

    # Now process all events
    for event in sorted_events
        # Get field from the event
        field_index = event.field
        field_symbol = injector.schema.index_to_field[field_index+1]

        # Decode the value from the event
        original_value = decode_value(injector, field_symbol, event.new_value)

       # Update the snapshot dataframe
        tmp_df[!, field_symbol] .= original_value
        tmp_df.timestamp .= event.timestamp
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

# Returns

- `Vector{Int}`: the assigned individual ids
"""
function stage_new_individuals!(injector::Injector, new_individuals::DataFrame, timestamp::Integer)
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

    # Convert timestamp to Int16 with warning if conversion is needed
    converted_timestamp = convert(Int16, timestamp)
    if converted_timestamp != timestamp
        @warn "Timestamp $timestamp was converted to $converted_timestamp to fit within Int16"
    end

    foreach(enumerate(eachrow(new_individuals))) do (n, row)
        i = convert(ind_id_type, new_ids[n])
        for (field, value) in pairs(row)
            field === :id && continue  # identity is assigned by the injector; an input id column is ignored
            stage_event!(injector, i, field, value, converted_timestamp)
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
function stage_new_individual!(injector::Injector, props, timestamp::Integer)::Int
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
export create_column_schema, stage_event!, stage_new_individual!, stage_new_individuals!
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
