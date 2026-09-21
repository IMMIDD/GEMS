#=
THIS FILE HANDLES INFECTIONS ON DIFFERENT LEVELS
This means, that the functionality to directly infect someone and spread a disease
is contained here.
=#
export infect!, sample_contacts


"""
    infect!(infectee::Individual,
        tick::Int16,
        pathogen::Pathogen,
        sim::Union{Simulation, Nothing},
        rng::Xoshiro,
        infecter_id::Int32,
        setting_id::Int32 ,
        lon::Float32,
        lat::Float32,
        setting_type::Char,
        ags::Int32,
        source_infection_id::Int32)

Infect `infectee` with the specified `pathogen` and calculate time to infectiousness
and time to recovery. Optional arguments `infecter_id`. `setting_id`, and `setting_type`
can be passed for logging. It's not required to calulate the infection. The infection
can only be logged, if `Simulation` object is passed (as this object holds the logger).

# Parameters

- `infectee::Individual`: Individual to infect
- `tick::Int16`: Infection tick
- `pathogen::Pathogen`: Pathogen to infect the individual with
- `sim::Union{Simulation, Nothing}` = Simulation object (used to get logger)
- `rng::Xoshiro`: RNG to use for stochastic parts
- `infecter_id::Int32`: Infecting individual
- `setting_id::Int32`: ID of setting this infection happens in
- `lon::Float32`: Longitude of the infection infection location (setting)
- `lat::Float32`: Latitude of the infection infection location (setting)
- `setting_type::Char`: Setting type as char (e.g. "h" for `Household`)
- `ags::Int32`*: Amtlicher Gemeindeschlüssel (community identification number) of the region this infection happened in as Integer value
- `source_infection_id::Int32`: Current infection ID of the infecting individual

# Returns

- `Int32`: always `DEFAULT_INFECTION_ID`. Infection ids are assigned by
  `flush_pending_infections!`, which logs the staged infections.

"""
function infect!(infectee::Individual,
        tick::Int16,
        pathogen::Pathogen,
        sim::Union{Simulation, Nothing},
        rng::Xoshiro,
        infecter_id::Int32,
        setting_id::Int32,
        lon::Float32,
        lat::Float32,
        setting_type::Char,
        ags::Int32 ,
        source_infection_id::Int32,
        infecter_position::Int32,
        type_rank::UInt8)

    # an individual can hold at most one active infection per pathogen 
    if infected(infectee, id(pathogen))
        @warn "infect!: individual $(id(infectee)) is already infected with pathogen $(id(pathogen)); skipping to preserve the one-active-infection-per-pathogen invariant."
        return DEFAULT_INFECTION_ID
    end

    # calculate disease progression
    paf = progression_assignment(pathogen)
    immunities = isnothing(sim) ? ImmunityRegistry() : immunity_registry(sim, infectee)
    pc = assign(infectee, paf, immunities, id(pathogen), rng)

    prog = get_progression(pathogen.progressions, pc)
    tag = progression_index(pathogen.progressions, pc)
    dp = calculate_progression(infectee, tick, prog, immunities, id(pathogen), rng)::DiseaseProgression

    if isnothing(sim)
        # no simulation context — store InfectionState directly in the individual's cache.
        # without a persistent registry, an overflow would dangle, so require a free cache slot
        any(i -> !infectee.infection_cache[i].active, 1:INFECTIONS_CACHE_SIZE) ||
            throw(ArgumentError("infect! without a Simulation cannot store more than $INFECTIONS_CACHE_SIZE concurrent infection(s) per individual; pass `sim=...`."))
        new_infection_id = DEFAULT_INFECTION_ID
        state = push_infection!(InfectionRegistry(), infectee, id(pathogen), new_infection_id, dp, tag)
        # throwaway schedule: with no tick loop nothing would drain it, and with an
        # empty profile index no care is drawn anyway
        compute_health!(infectee, InfectionRegistry(), DefaultHealthProgression(), HealthProfileIndex(), state, tick, rng, HealthSchedule())
        _mark_infected!(infectee, id(pathogen))
    else
        # stage for the serial flush, which dedups, logs and sets the host's flags
        new_infection_id = DEFAULT_INFECTION_ID
        shard_id = _owner_shard(id(infectee))
        push!(sim.infection_buffers[Threads.threadid(), shard_id],
            _PendingInfection(id(infectee), infecter_id, source_infection_id, setting_id, ags,
                infecter_position, lat, lon, setting_type, tick, id(pathogen), tag, type_rank, dp))
    end

    return new_infection_id
end

"""
    infect!(infectee::Individual,
        tick::Int16,
        pathogen::Pathogen;
        sim::Union{Simulation, Nothing} = nothing,
        rng::Xoshiro = default_gems_rng(),
        infecter_id::Int32 = Int32(-1),
        setting_id::Int32 = Int32(-1),
        lon::Float32 = NaN32,
        lat::Float32 = NaN32,
        setting_type::Char = '?',
        ags::Int32 = Int32(-1),
        source_infection_id::Int32 = DEFAULT_INFECTION_ID)

Infect `infectee` with the pathogen of the simulation at the current tick of the simulation. Wrapper for optional keyword arguments

# Parameters

- `infectee::Individual`: Individual to infect
- `tick::Int16`: Infection tick
- `pathogen::Pathogen`: Pathogen to infect the individual with
- `sim::Union{Simulation, Nothing} = nothing` *(optional)* = Simulation object (used to get logger)
- `rng::Xoshiro = default_gems_rng()` *(optional)*: RNG to use for stochastic parts
- `infecter_id::Int32 = Int32(-1)` *(optional)*: Infecting individual
- `setting_id::Int32 = Int32(-1)` *(optional)*: ID of setting this infection happens in
- `lon::Float32 = NaN32` *(optional)*: Longitude of the infection infection location (setting)
- `lat::Float32 = NaN32` *(optional)*: Latitude of the infection infection location (setting)
- `setting_type::Char = '?'` *(optional)*: Setting type as char (e.g. "h" for `Household`)
- `ags::Int32 = Int32(-1)` *(optional)*: Amtlicher Gemeindeschlüssel (community identification number) of the region this infection happened in as Integer value
- `source_infection_id::Int32 = DEFAULT_INFECTION_ID` *(optional)*: Current infection ID of the infecting individual

# Returns

- `Int32`: always `DEFAULT_INFECTION_ID`. Infection ids are assigned by
  `flush_pending_infections!`, which logs the staged infections.

"""
function infect!(infectee::Individual,
        tick::Int16,
        pathogen::Pathogen;
        # optional keyword arguments (mainly needed for logging)
        sim::Union{Simulation, Nothing} = nothing,
        rng::Xoshiro = default_gems_rng(),
        infecter_id::Int32 = Int32(-1),
        setting_id::Int32 = Int32(-1),
        lon::Float32 = NaN32,
        lat::Float32 = NaN32,
        setting_type::Char = '?',
        ags::Int32 = Int32(-1),
        source_infection_id::Int32 = DEFAULT_INFECTION_ID,
        infecter_position::Int32 = Int32(0),
        type_rank::UInt8 = UInt8(0))

        infect!(infectee, tick, pathogen, sim, rng, infecter_id, setting_id, lon, lat, setting_type, ags,
            source_infection_id, infecter_position, type_rank)
end
"""
    infect!(infectee::Individual, sim::Simulation)

Infect `infectee` with the pathogen of the simulation at the current tick of the simulation.
Mainly a convenience wrapper around `infect!` with less parameters.
Used for example in test cases.
"""
infect!(infectee::Individual, sim::Simulation) = infect!(infectee, tick(sim), first_pathogen(sim); sim = sim, rng = rng(sim))

"""
    try_to_infect!(infctr::Individual, infctd::Individual, sim::Simulation, pathogen::Pathogen, setting::Setting;
        infecter_position::Int32 = Int32(0), type_rank::UInt8 = UInt8(0))

Tries to infect the `infctd` with the given `pathogen` transmitted by `infctr `at time `tick(sim)` with `sim`
being the simulation. Success depends on whether the agent is alive, not already infected
an whether an infection event was sampled using the provided distribution or probability.
Returns `true` if infection was successful.

# Parameters

- `infctr::Individual`: Infecting individual
- `infctd::Individual`: Individual to infect
- `sim::Simulation`: Simulation object
- `pathogen::Pathogen`: Pathogen to infect the individual with
- `setting::Setting`: Setting this infection happens in

# Returns

- `Bool`: True if infection was successful, false otherwise

"""
function try_to_infect!(infctr::Individual,
        infctd::Individual,
        sim::Simulation,
        pathogen::Pathogen,
        setting::Setting;
        infecter_position::Int32 = Int32(0),
        type_rank::UInt8 = UInt8(0))::Bool

    # only `pathogen` is tried, on a contact that is kept
    bounds = map(p -> id(p) == id(pathogen) ? 1.0 : 0.0, pathogens(sim))
    return _try_to_infect!(infctr, infctd, sim, setting, bounds, 1.0f0, infecter_position, type_rank)
end

# Tries to infect `infctd` with each pathogen whose entry of `bounds` is above 0, on a contact kept
# with `thin`. A pathogen's probability must not exceed its bound.
function _try_to_infect!(infctr::Individual,
        infctd::Individual,
        sim::Simulation,
        setting::Setting,
        bounds::NTuple{N, Float64},
        thin::Float32,
        infecter_position::Int32,
        type_rank::UInt8)::Bool where {N}

    # if one of both is dead
    if dead(infctr) || dead(infctd)
        return false
    end

    # if one of both is hospitalized
    if hospitalized(infctr) || hospitalized(infctd)
        return false
    end

    # calculate infection probabilities
    infection_probabilities = map((pathogen, bound) -> _infection_probability(infctr, infctd, sim, pathogen, setting, bound),
        pathogens(sim), bounds)

    # try to infect
    transmits = _draw_transmissions(infection_probabilities, bounds, thin, rng(sim))
    any(transmits) || return false
    hh = settings(sim, Household)[household_id(infctd, activity_plans(sim))]::Household
    for (pathogen, transmitted) in zip(pathogens(sim), transmits)
        transmitted || continue
        infect!(infctd,
            tick(sim),
            pathogen,
            sim,
            rng(sim),
            id(infctr),
            id(setting),
            lon(hh),
            lat(hh),
            settingchar(setting),
            ags(setting) |> id,
            infection_id(infctr, sim, id(pathogen)),
            infecter_position,
            type_rank)
    end
    return true
end

# The probability that `infctr` infects `infctd` with `pathogen`, which must not exceed `bound`.
# 0 if `pathogen` is not shed or `infctd` already has it.
function _infection_probability(infctr::Individual, infctd::Individual, sim::Simulation,
        pathogen::Pathogen, setting::Setting, bound::Float64)::Float64
    (bound == 0 || infected(infctd, id(pathogen))) && return 0.0

    infection_probability = min(1.0, effective_transmission_probability(
        pathogen |> transmission_function,
        pathogen |> id,
        infctr, infctd,
        setting, sim |> tick,
        sim,
        rng(sim)
    ))
    infection_probability > bound * (1 + 1e-9) &&
        error("the transmission bound of $(typeof(transmission_function(pathogen))) is $bound, below its probability $infection_probability")
    return infection_probability
end

# Draws which pathogens transmit on a contact kept with `thin`, each independently with its probability.
# Picks the first pathogen whose draw is below its bound: it transmits with its probability over its
# bound, later ones with their probability, earlier ones not.
function _draw_transmissions(probabilities::NTuple{N, Float64}, bounds::NTuple{N, Float64}, thin::Float32,
        rng::Xoshiro)::NTuple{N, Bool} where {N}
    # pathogen i is picked if none_below[i] < u <= none_below[i-1], none if u <= none_below[N]
    none_below = accumulate(*, map(b -> 1.0 - b, bounds))
    u = 1.0 - gems_rand(rng) * thin
    picked = something(findfirst(<(u), none_below), 0)
    return ntuple(Val(N)) do i
        # a zero probability never transmits, so it draws nothing
        (picked > 0 && i >= picked && probabilities[i] > 0) || return false
        return gems_rand(rng) < probabilities[i] / (i == picked ? bounds[i] : 1.0)
    end
end


"""
    can_infect(ind::Individual, setting::Setting)::Bool

Determines whether the individual can infect others in the given setting.
Checks for infectiousness, setting openness, and quarantine status.

# Parameters
- `ind::Individual`: Individual to check
- `setting::Setting`: Setting to check

# Returns
- `Bool`: True if the individual can infect others in the setting, false otherwise
"""
function can_infect(ind::Individual, setting::Setting, tick::Int16)::Bool
    # if individual is not infectious
    if !infectious(ind)
        return false
    end

    # if individual is hospitalized
    if is_hospitalized(ind)
        return false
    end

    # if setting is closed
    if !is_open(setting)
        return false
    end

    # severe symptoms prevent infecting others outside the household
    if is_severe(ind) && (typeof(setting) != Household)
        return false
    end

    # if individual is quarantined
    if isquarantined(ind)
        # if individual is in household quarantine and setting is not Household
        if quarantine_status(ind) == QUARANTINE_STATE_HOUSEHOLD_QUARANTINE && (typeof(setting) != Household)
            return false
        end
    end

    return true
end

"""
    can_be_contacted(ind::Individual, setting::Setting)::Bool

Determines whether the individual can be contacted (and thus infected) in the given setting.
Checks for death, hospitalization and quarantine status.

# Parameters
- `ind::Individual`: Individual to check
- `setting::Setting`: Setting to check

# Returns
- `Bool`: True if the individual can be contacted in the setting, false otherwise
"""
function can_be_contacted(ind::Individual, setting::Setting)::Bool
    # if individual is dead
    if dead(ind)
        return false
    end

    # if individual is hospitalized
    if is_hospitalized(ind)
        return false
    end

    # if individual is quarantined
    if isquarantined(ind)
        # if individual is in household quarantine and setting is not Household
        if quarantine_status(ind) == QUARANTINE_STATE_HOUSEHOLD_QUARANTINE && (typeof(setting) != Household)
            return false
        end
    end

    return true
end


"""
    spread_infections!(sim::Simulation)

Spreads the infections of each infectious individual into each setting they belong to: the
setting of each plan entry, each container above it, and the GlobalSetting.

# Parameters

- `sim::Simulation`: Simulation object

"""
function spread_infections!(sim::Simulation)
    Threads.@threads :static for _ in 1:Threads.nthreads()
        for ind in sim.infectious_individuals[Threads.threadid()]
            spread_here = (setting, pos, scale) -> _spread_in!(setting, pos, scale, ind, sim)
            _foreach_spread_setting(spread_here, ind, sim)
        end
    end
    return nothing
end

# Spreading starts from each infectious individual and reaches every setting they spread in: the
# setting of each plan entry, each container above it, and the GlobalSetting. For each one it
# calls `visit(setting, position, scale)`, which decides what happens there, so a test can list
# the visits without spreading. `position` is the individual's index among the setting's present
# members, which the deduplication key orders infecters by.
function _foreach_spread_setting(visit::V, ind::Individual, sim::Simulation) where {V}
    plans = activity_plans(sim)
    cntnr = settingscontainer(sim)
    for e in plan_entries(plans, ind)
        idx = member_index(e)
        _with_entry_setting(sim, e) do setting
            # deceased, so absent from its frames
            _is_deceased(setting, idx) && return nothing
            # the entry's own setting
            visit(setting, Int(idx), _membership_scale(plans, ind, setting, cntnr))
            # each container above it that holds this individual's copy. An inactive entry climbs
            # too: its setting may hold the copy a container kept
            _foreach_container_above(setting, idx, cntnr) do container, pos
                visit(container, pos, _membership_scale(plans, ind, container, cntnr))
            end
        end
    end
    # everyone is in the GlobalSetting
    pos = _global_position(ind, sim)
    pos == 0 || visit(@inbounds(settings(sim, GlobalSetting)[1]), pos, 1.0f0)
    return nothing
end

# Calls `use` with the entry's setting as its concrete type, found by unrolling over the
# membership types so each comparison is against a constant index.
@inline _with_entry_setting(use::U, sim::Simulation, e::PlanEntry) where {U} =
    _unroll_entry_setting(use, sim, e, membership_setting_types(Individual)...)

@inline function _unroll_entry_setting(use::U, sim::Simulation, e::PlanEntry, ::Type{T}, rest...) where {U, T<:IndividualSetting}
    setting_type_of(e) == setting_type_index(T) || return _unroll_entry_setting(use, sim, e, rest...)
    return use(settings(sim, T)[setting_id(e)])
end

# no membership type matched: a setting type GEMS does not ship, looked up at runtime
@inline _unroll_entry_setting(use::U, sim::Simulation, e::PlanEntry) where {U} =
    use(settings(sim, setting_type_from_index(setting_type_of(e)))[setting_id(e)])

# Calls `visit(container, position)` for each container above `leaf` that holds the member at
# `idx`. A member in two leaves below one container is among its members once, and the other copy
# has no position there, so each container is reached once.
@inline _foreach_container_above(visit::V, leaf::IndividualSetting, idx::Int32, cntnr::SettingsContainer) where {V} =
    _foreach_container_above(visit, leaf, leaf, idx, cntnr)

function _foreach_container_above(visit::V, s::S, leaf::IndividualSetting, idx::Int32,
                                  cntnr::SettingsContainer) where {V, S<:Setting}
    (hasfield(S, :contained) && s.contained != DEFAULT_SETTING_ID) || return nothing
    c = settings(cntnr, contained_type(S))[s.contained]
    pos = container_frame_index(cntnr, c, leaf, idx)
    pos == DEFAULT_MEMBER_INDEX || visit(c, Int(pos))
    return _foreach_container_above(visit, c, leaf, idx, cntnr)
end

# The individual's position in the GlobalSetting, which copied the population in its order when it
# was built. 0 when there is no GlobalSetting, or the individual joined the population later.
function _global_position(ind::Individual, sim::Simulation)::Int
    # not `settings(sim, GlobalSetting)`, which builds an empty vector per call when there is none
    gs = get(settingscontainer(sim).settings, GlobalSetting, nothing)
    (gs === nothing || isempty(gs)) && return 0
    members = (@inbounds (gs::Vector{GlobalSetting})[1]).individuals
    pop = population(sim)
    i = id(ind) - pop.minid + 1
    k = 1 <= i <= length(pop.id_map) ? Int(pop.id_map[i]) : 0
    1 <= k <= length(members) || return 0
    @inbounds members[k] === ind || error(
        "the GlobalSetting no longer holds the population in its order: individual $(id(ind)) " *
        "is not at position $k")
    return k
end

# One setting's part of a host's spreading: its contacts there, and each shedding pathogen tried on them.
function _spread_in!(setting::Setting, pos::Int, s_host::Float32, ind::Individual, sim::Simulation)
    # at scale 0 the host meets nobody here
    s_host == 0 && return nothing
    can_infect(ind, setting, tick(sim)) || return nothing
    csm = setting.contact_sampling_method
    # union splitting on csm
    if csm isa ContactparameterSampling
        _spread_with!(csm, setting, pos, s_host, ind, sim)
    elseif csm isa RandomSampling
        _spread_with!(csm, setting, pos, s_host, ind, sim)
    elseif csm isa AgeBasedContactSampling
        _spread_with!(csm, setting, pos, s_host, ind, sim)
    else
        _spread_with!(csm, setting, pos, s_host, ind, sim)
    end
    return nothing
end

function _spread_with!(csm, setting, pos::Int, s_host::Float32, ind::Individual, sim::Simulation)
    cntnr = settingscontainer(sim)
    c_buffer = sim.contact_buffers[Threads.threadid()]
    current_tick = tick(sim)
    bounds, thin = _transmission_bounds(ind, setting, current_tick, sim)
    # no shedding pathogen can infect anyone here
    thin == 0 && return nothing
    sample_scaled_contacts!(c_buffer, sim.draw_buffers[Threads.threadid()], csm, setting, pos,
        present_members(setting, cntnr), current_tick, true, rng(sim), activity_plans(sim), cntnr,
        s_host, _scale_bound(setting); thin = thin)

    type_rank = setting_type_index(typeof(setting))
    _spread_to_contacts!(ind, c_buffer, sim, setting, bounds, thin, Int32(pos), type_rank)
    return nothing
end

# Each pathogen's bound on transmitting from `ind` to anyone in `setting`, 0 if it is not shed, and
# the share of contacts to keep. Without pre-thinning a shed pathogen's bound is 1, so every contact is kept.
@inline function _transmission_bounds(ind::Individual, setting::Setting, t::Int16, sim::Simulation)
    ps = pathogens(sim)
    # an unshed pathogen's bound is 0 either way
    bounds = sim.prethinning ?
        map(p -> effective_transmission_bound(transmission_function(p), id(p), ind, setting, t, sim), ps) :
        map(p -> infectiousness(ind, sim, id(p)) == 0 ? 0.0 : 1.0, ps)
    any_bound = 1.0 - prod(b -> 1.0 - b, bounds)
    # rounded up, so no contact is thinned harder than its acceptance makes up for
    thin = Float32(any_bound)
    return bounds, thin < any_bound ? nextfloat(thin) : thin
end

# every contact in the buffer passed `can_be_contacted` when it was sampled
function _spread_to_contacts!(ind, c_buffer, sim, setting, bounds, thin::Float32,
        infecter_position::Int32, type_rank::UInt8)
    for c in c_buffer
        _try_to_infect!(ind, c, sim, setting, bounds, thin, infecter_position, type_rank)
    end
end
