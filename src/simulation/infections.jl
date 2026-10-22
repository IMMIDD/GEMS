export infect!


###
### SPREADING
### Spreads each infectious individual's infections in the settings they belong to
###

"""
    spread_infections!(sim::Simulation)

Spreads each infectious individual's infections in their plan entries' settings, the containers above
those, and the GlobalSetting.
"""
function spread_infections!(sim::Simulation)
    Threads.@threads :static for _ in 1:Threads.nthreads()
        hosts = sim.infectious_individuals[Threads.threadid()]
        for k in eachindex(hosts)
            # hosts are scattered in memory, so fetch the next ones early
            _prefetch_listed_ahead(j -> @inbounds(hosts[j]), length(hosts), k, activity_plans(sim))
            ind = hosts[k]
            _foreach_spread_setting(ind, sim, _contact_draw) do setting, frame_pos, drawn
                _spread_in!(setting, frame_pos, ind, sim, drawn)
            end
        end
    end
    return nothing
end

# Calls `visit(setting, frame_pos, drawn)` for each setting `ind` spreads in. Each level's `draw` runs before
# its setting is loaded, and a level that drew nobody is skipped; `_draw_at_visit` skips none.
function _foreach_spread_setting(visit::V, ind::Individual, sim::Simulation, draw::D) where {V, D}
    plans = activity_plans(sim)
    for slot in plan_slots(plans, ind)
        e = @inbounds plans.entries[slot]
        _with_entry_settings(leaves -> _visit_entry(visit, leaves, e, slot, ind, sim, draw), settingscontainer(sim), e)
    end
    _visit_global(visit, ind, sim, draw)
    return nothing
end

# Draws every level of one plan entry, then loads and visits the levels that need it.
function _visit_entry(visit::V, leaves::AbstractVector{S}, e::PlanEntry, slot::Int, ind::Individual, sim::Simulation,
                      draw::D) where {V, S<:IndividualSetting, D}
    # one per level, leaf first
    draws = _level_draws(draw, S, ind, slot, sim)
    any(_needs_visit, draws) || return nothing
    leaf = leaves[setting_id(e)]
    leaf_index = member_index(e)
    # the dead are not in `present_members`
    _is_deceased(leaf, leaf_index) && return nothing
    _visit_up(visit, leaf, leaf_index, leaf, leaf_index, draws, settingscontainer(sim))
    return nothing
end

# One `draw` per level, from `S` up to the top of its hierarchy.
@inline _level_draws(draw::D, ::Type{Nothing}, ind::Individual, slot::Int, sim::Simulation) where {D} = ()
@inline _level_draws(draw::D, ::Type{S}, ind::Individual, slot::Int, sim::Simulation) where {D, S<:Setting} =
    (draw(S, ind, slot, sim), _level_draws(draw, _parent_type(S), ind, slot, sim)...)

# Visits `s` with `first(draws)` and the containers above it with the rest. A container lists a member of
# two of its leaves under one only; from the other, `frame_pos` is `DEFAULT_MEMBER_INDEX` and it is skipped.
function _visit_up(visit::V, s::S, frame_pos::Int32, leaf::IndividualSetting, leaf_index::Int32, draws::Tuple,
                   cntnr::SettingsContainer) where {V, S<:Setting}
    drawn = first(draws)
    _needs_visit(drawn) && frame_pos != DEFAULT_MEMBER_INDEX && visit(s, Int(frame_pos), drawn)
    above = Base.tail(draws)
    # stop before loading containers nobody visits
    (_has_container(s) && any(_needs_visit, above)) || return nothing
    c = settings(cntnr, contained_type(S))[s.contained]
    _visit_up(visit, c, container_frame_index(cntnr, c, leaf, leaf_index), leaf, leaf_index, above, cntnr)
    return nothing
end

# Calls `visit` for the GlobalSetting, which has no plan entry, so its draw gets slot 0.
function _visit_global(visit::V, ind::Individual, sim::Simulation, draw::D) where {V, D}
    drawn = draw(GlobalSetting, ind, 0, sim)
    _needs_visit(drawn) || return nothing
    frame_pos = _global_position(ind, sim)
    frame_pos == 0 || visit(@inbounds(settings(sim, GlobalSetting)[1]), frame_pos, drawn)
    return nothing
end

# `ind`'s position in the GlobalSetting, which equals its population index. 0 without a GlobalSetting
# or for someone added to the population after it was built.
function _global_position(ind::Individual, sim::Simulation)::Int
    # not `settings(sim, GlobalSetting)`, which allocates when there is none
    gs = get(settingscontainer(sim).settings, GlobalSetting, nothing)
    (gs === nothing || isempty(gs)) && return 0
    k = _individual_index(population(sim), id(ind))
    return k <= length(individuals(@inbounds (gs::Vector{GlobalSetting})[1])) ? k : 0
end

# Samples `ind`'s contacts in `setting` and tries each pathogen they shed on them. `frame_pos` is `ind`'s
# index in `present_members`, `drawn` the contacts drawn before the visit (see `_contact_draw`).
function _spread_in!(setting::Setting, frame_pos::Int, ind::Individual, sim::Simulation, drawn)
    current_tick = tick(sim)
    can_infect(ind, setting, current_tick) || return nothing
    cntnr = settingscontainer(sim)
    plans = activity_plans(sim)
    s_host = _membership_scale(plans, ind, setting, cntnr)
    s_host == 0 && return nothing
    bounds, thin = _transmission_bounds(ind, setting, current_tick, sim)
    # no pathogen can transmit here
    thin == 0 && return nothing

    contacts = sim.contact_buffers[Threads.threadid()]
    _with_sampling_method(setting.contact_sampling_method) do csm
        sample_scaled_contacts!(contacts, sim.draw_buffers[Threads.threadid()], csm, setting, frame_pos,
            present_members(setting, cntnr), current_tick, true, rng(sim), plans, cntnr,
            s_host, _scale_bound(setting); thin = thin, drawn = drawn)
    end

    # every contact passed `can_be_contacted` when it was sampled
    type_rank = setting_type_index(typeof(setting))
    for c in contacts
        _try_to_infect!(ind, c, sim, setting, bounds, thin, Int32(frame_pos), type_rank)
    end
    return nothing
end


###
### CONTACT DRAWS
### Contact counts drawn from per-type rate bounds, before the setting is loaded
###

# `n` contacts drawn at `rate_bound`, which is at least the visit's rate. `rate_bound = Inf` means
# nothing was drawn and the visit samples its own count.
struct _ContactDraw
    n::Int
    rate_bound::Float64
end

const DEFAULT_CONTACT_DRAW = _ContactDraw(0, Inf)

# whether the visit thins `n` instead of sampling its own count
@inline _drawn_ahead(drawn::_ContactDraw) = isfinite(drawn.rate_bound)

# Draws `ind`'s contact count at a rate that bounds every setting of type `S` reached from its entry at
# `slot` (0 for the GlobalSetting).
function _contact_draw(::Type{S}, ind::Individual, slot::Int, sim::Simulation) where {S<:Setting}
    type_rate = _rate_bound(settingscontainer(sim), setting_type_index(S))
    # no rate bound: the visit samples
    isinf(type_rate) && return DEFAULT_CONTACT_DRAW
    _can_infect(ind, S) || return _ContactDraw(0, 0.0)
    plans = activity_plans(sim)
    s_host = _membership_scale_bound(plans, ind, S, slot)
    scale_bound = _type_scale_bound(plans, setting_type_index(_leaf_type(S)))
    thin = _transmission_type_thin(ind, S, tick(sim), sim)
    rate_bound = _visit_rate(type_rate, s_host, scale_bound, thin)
    return _ContactDraw(gems_rand(rng(sim), Poisson(rate_bound)), rate_bound)
end

# A `draw` that draws nothing ahead, so every level is visited and samples its own count
@inline _draw_at_visit(::Type{S}, ::Individual, ::Int, ::Simulation) where {S<:Setting} = DEFAULT_CONTACT_DRAW

# whether a level samples at the visit or drew someone
@inline _needs_visit(drawn::_ContactDraw) = !_drawn_ahead(drawn) || drawn.n > 0


###
### TRANSMISSION BOUNDS
### Upper bounds on each pathogen's transmission probability, and the contact thinning they allow
###

# Each pathogen's bound on its transmission probability in `setting` (0 if not shed), and `thin`, the
# chance to keep a contact. Without pre-thinning, a shed pathogen's bound is 1.
@inline function _transmission_bounds(ind::Individual, setting::Setting, t::Int16, sim::Simulation)
    bounds = _pathogen_bounds((tf, pid) -> max_effective_transmission_probability(tf, pid, ind, setting, t, sim), ind, sim)
    return bounds, _thin(bounds)
end

# `_transmission_bounds`' `thin`, from bounds that hold in every setting of type `S`.
@inline _transmission_type_thin(ind::Individual, ::Type{S}, t::Int16, sim::Simulation) where {S<:Setting} =
    _thin(_pathogen_bounds((tf, pid) -> max_effective_transmission_probability_in_type(tf, pid, ind, S, t, sim), ind, sim))

# `max_probability(transmission_function, pathogen_id)` per pathogen; without pre-thinning, 1 if shed, else 0
@inline function _pathogen_bounds(max_probability::F, ind::Individual, sim::Simulation) where {F}
    ps = pathogens(sim)
    return sim.prethinning ?
        map(p -> max_probability(transmission_function(p), id(p)), ps) :
        map(p -> infectiousness(ind, sim, id(p)) == 0 ? 0.0 : 1.0, ps)
end

# The chance to keep a contact: that at least one pathogen passes its bound
@inline function _thin(bounds)::Float32
    any_bound = 1.0 - prod(b -> 1.0 - b, bounds)
    # round up; an extra kept contact transmits nothing
    thin = Float32(any_bound)
    return thin < any_bound ? nextfloat(thin) : thin
end


###
### ELIGIBILITY
###

"""
    can_infect(ind::Individual, setting::Setting, tick::Int16)::Bool

Whether `ind` can infect others in `setting`: infectious, not hospitalized, the setting open, and kept
home neither by severe symptoms nor by household quarantine.
"""
function can_infect(ind::Individual, setting::Setting, tick::Int16)::Bool
    return _can_infect(ind, typeof(setting)) && is_open(setting)
end

# `can_infect` without the open check, which needs only the setting's type.
function _can_infect(ind::Individual, setting_type::Type{S})::Bool where {S<:Setting}
    if !infectious(ind)
        return false
    end

    if is_hospitalized(ind)
        return false
    end

    # severe symptoms keep the host home
    if is_severe(ind) && (setting_type !== Household)
        return false
    end

    if isquarantined(ind)
        if quarantine_status(ind) == QUARANTINE_STATE_HOUSEHOLD_QUARANTINE && (setting_type !== Household)
            return false
        end
    end

    return true
end

"""
    can_be_contacted(ind::Individual, setting::Setting)::Bool

Whether `ind` can be contacted, and so infected, in `setting`: alive, not hospitalized, and not kept
home by household quarantine.
"""
function can_be_contacted(ind::Individual, setting::Setting)::Bool
    if dead(ind)
        return false
    end

    if is_hospitalized(ind)
        return false
    end

    if isquarantined(ind)
        if quarantine_status(ind) == QUARANTINE_STATE_HOUSEHOLD_QUARANTINE && (typeof(setting) != Household)
            return false
        end
    end

    return true
end


###
### TRANSMISSION
### Decides which pathogens transmit on one contact
###

"""
    try_to_infect!(infctr::Individual, infctd::Individual, sim::Simulation, pathogen::Pathogen, setting::Setting;
        infecter_position::Int32 = Int32(0), type_rank::UInt8 = UInt8(0))

Tries to infect `infctd` with `pathogen` from `infctr` in `setting` at `tick(sim)`. Returns whether it transmitted.
`infecter_position` and `type_rank` are passed on to `infect!`.
"""
function try_to_infect!(infctr::Individual,
        infctd::Individual,
        sim::Simulation,
        pathogen::Pathogen,
        setting::Setting;
        infecter_position::Int32 = Int32(0),
        type_rank::UInt8 = UInt8(0))::Bool

    # only `pathogen` is tried, and the contact is always kept
    bounds = map(p -> id(p) == id(pathogen) ? 1.0 : 0.0, pathogens(sim))
    return _try_to_infect!(infctr, infctd, sim, setting, bounds, 1.0f0, infecter_position, type_rank)
end

# Tries each pathogen with a bound above 0 on a contact kept with probability `thin`. Returns whether
# any transmitted. A pathogen's probability must not exceed its bound.
function _try_to_infect!(infecter::Individual,
        infectee::Individual,
        sim::Simulation,
        setting::Setting,
        bounds::NTuple{N, Float64},
        thin::Float32,
        infecter_position::Int32,
        type_rank::UInt8)::Bool where {N}

    if dead(infecter) || dead(infectee)
        return false
    end

    if hospitalized(infecter) || hospitalized(infectee)
        return false
    end

    infection_probabilities = map((pathogen, bound) -> _infection_probability(infecter, infectee, sim, pathogen, setting, bound),
        pathogens(sim), bounds)

    transmits = _draw_transmissions(infection_probabilities, bounds, thin, rng(sim))
    any(transmits) || return false
    for (pathogen, transmitted) in zip(pathogens(sim), transmits)
        transmitted || continue
        infect!(infectee,
            tick(sim),
            pathogen,
            sim,
            rng(sim),
            id(infecter),
            id(setting),
            settingchar(setting),
            infection_id(infecter, sim, id(pathogen)),
            infecter_position,
            type_rank)
    end
    return true
end

# The probability that `infecter` infects `infectee` with `pathogen`, at most `bound`. 0 if `pathogen`
# is not shed or `infectee` already has it.
function _infection_probability(infecter::Individual, infectee::Individual, sim::Simulation,
        pathogen::Pathogen, setting::Setting, bound::Float64)::Float64
    (bound == 0 || infected(infectee, id(pathogen))) && return 0.0

    infection_probability = min(1.0, effective_transmission_probability(
        pathogen |> transmission_function,
        pathogen |> id,
        infecter, infectee,
        setting, sim |> tick,
        sim,
        rng(sim)
    ))
    infection_probability > bound * (1 + 1e-9) &&
        error("the transmission bound of $(typeof(transmission_function(pathogen))) is $bound, below its probability $infection_probability")
    return infection_probability
end

# Decides which pathogens transmit on a contact kept with probability `thin`. Each transmits with its own
# probability, independently of the others, as if the contact had not been thinned.
function _draw_transmissions(probabilities::NTuple{N, Float64}, bounds::NTuple{N, Float64}, thin::Float32,
        rng::Xoshiro)::NTuple{N, Bool} where {N}
    # one draw picks the first pathogen to pass its bound; it transmits with probability over bound,
    # the ones after it with their probability, the ones before it not at all
    none_below = accumulate(*, map(b -> 1.0 - b, bounds))
    u = 1.0 - gems_rand(rng) * thin
    picked = something(findfirst(<(u), none_below), 0)
    return ntuple(Val(N)) do i
        # no draw for a zero probability
        (picked > 0 && i >= picked && probabilities[i] > 0) || return false
        return gems_rand(rng) < probabilities[i] / (i == picked ? bounds[i] : 1.0)
    end
end


###
### INFECTION
###

"""
    infect!(infectee::Individual,
        tick::Int16,
        pathogen::Pathogen,
        sim::Union{Simulation, Nothing},
        rng::Xoshiro,
        infecter_id::Int32,
        setting_id::Int32 ,
        setting_type::Char,
        source_infection_id::Int32,
        infecter_position::Int32,
        type_rank::UInt8)

Infects `infectee` with `pathogen` at `tick` and draws its disease progression. With a `sim`, the infection
is staged for `flush_pending_infections!`, which assigns its id and logs it; returns `DEFAULT_INFECTION_ID`.

# Parameters

- `infectee::Individual`: Individual to infect
- `tick::Int16`: Infection tick
- `pathogen::Pathogen`: Pathogen to infect the individual with
- `sim::Union{Simulation, Nothing}`: Simulation the infection is staged in; `nothing` stores it in the individual's cache
- `rng::Xoshiro`: RNG for the disease progression
- `infecter_id::Int32`: Infecting individual
- `setting_id::Int32`: ID of the setting the infection happens in
- `setting_type::Char`: Setting type as char (e.g. 'h' for `Household`)
- `source_infection_id::Int32`: Current infection ID of the infecting individual
- `infecter_position::Int32`: Infecting individual's index in the setting's `present_members`
- `type_rank::UInt8`: Index of the setting's type. With the setting id and `infecter_position`, it picks
  which infection is kept when an individual is infected twice in one tick
"""
function infect!(infectee::Individual,
        tick::Int16,
        pathogen::Pathogen,
        sim::Union{Simulation, Nothing},
        rng::Xoshiro,
        infecter_id::Int32,
        setting_id::Int32,
        setting_type::Char,
        source_infection_id::Int32,
        infecter_position::Int32,
        type_rank::UInt8)

    # at most one active infection per pathogen
    if infected(infectee, id(pathogen))
        @warn "infect!: individual $(id(infectee)) is already infected with pathogen $(id(pathogen)); skipping to preserve the one-active-infection-per-pathogen invariant."
        return DEFAULT_INFECTION_ID
    end

    # calculate disease progression
    paf = progression_assignment(pathogen)
    pc = assign(infectee, paf, sim, id(pathogen), tick, rng)

    prog = get_progression(pathogen.progressions, pc)
    tag = progression_index(pathogen.progressions, pc)
    dp = calculate_progression(infectee, tick, prog, sim, id(pathogen), rng)::DiseaseProgression

    if isnothing(sim)
        # without a sim, the infection lives in the individual's cache, which needs a free slot
        any(i -> !infectee.infection_cache[i].active, 1:INFECTIONS_CACHE_SIZE) ||
            throw(ArgumentError("infect! without a Simulation cannot store more than $INFECTIONS_CACHE_SIZE concurrent infection(s) per individual; pass `sim=...`."))
        state = push_infection!(InfectionRegistry(), infectee, id(pathogen), DEFAULT_INFECTION_ID, dp, tag)
        # a throwaway schedule: nothing drains it without a sim, and an empty profile index draws no care
        compute_health!(infectee, InfectionRegistry(), DefaultHealthProgression(), HealthProfileIndex(), state, tick, rng, HealthSchedule())
        _mark_infected!(infectee, id(pathogen))
    else
        # stage for the serial flush, which dedups, logs and sets the host's flags
        shard_id = _owner_shard(id(infectee))
        push!(sim.infection_buffers[Threads.threadid(), shard_id],
            _PendingInfection(infectee, id(infectee), infecter_id, source_infection_id, setting_id,
                infecter_position, setting_type, tick, id(pathogen), tag, type_rank, dp))
    end

    return DEFAULT_INFECTION_ID
end

"""
    infect!(infectee::Individual,
        tick::Int16,
        pathogen::Pathogen;
        sim::Union{Simulation, Nothing} = nothing,
        rng::Xoshiro = Xoshiro(),
        infecter_id::Int32 = Int32(-1),
        setting_id::Int32 = Int32(-1),
        setting_type::Char = '?',
        source_infection_id::Int32 = DEFAULT_INFECTION_ID,
        infecter_position::Int32 = Int32(0),
        type_rank::UInt8 = UInt8(0))

Keyword form of `infect!`; see the positional method for the arguments.
"""
function infect!(infectee::Individual,
        tick::Int16,
        pathogen::Pathogen;
        sim::Union{Simulation, Nothing} = nothing,
        rng::Xoshiro = Xoshiro(),
        infecter_id::Int32 = Int32(-1),
        setting_id::Int32 = Int32(-1),
        setting_type::Char = '?',
        source_infection_id::Int32 = DEFAULT_INFECTION_ID,
        infecter_position::Int32 = Int32(0),
        type_rank::UInt8 = UInt8(0))

        infect!(infectee, tick, pathogen, sim, rng, infecter_id, setting_id, setting_type,
            source_infection_id, infecter_position, type_rank)
end

"""
    infect!(infectee::Individual, sim::Simulation)

Infects `infectee` with the simulation's first pathogen at the current tick.
"""
infect!(infectee::Individual, sim::Simulation) = infect!(infectee, tick(sim), first_pathogen(sim); sim = sim, rng = rng(sim))
