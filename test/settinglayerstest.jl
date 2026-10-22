import GEMS: setting_type_index, setting_type_from_index, plan_slot, plan_slots, plan_add!,
    plan_remove!, setting_type_of, setting_id, entry_active, entry_active!, entry_scale,
    setting_ids, declare_setting_type!, DeclaredSetting, DEFAULT_SETTING_ID, DEFAULT_MEMBER_INDEX,
    NewSettingsAssignment, JoinAssignment, validate_plans, settingscontainer, settings,
    _membership_bit, _mask_slot, _type_scale_bound, _name_key,
    _LayerStreams, _layer_entry_counts, _check_room, _draw_entries, _draw_scale, _draw_size,
    _PlanAdditions, _merge_additions!, _max_setting_id, _setting_id,
    _JoinCandidates, _draw_unheld, _layer_description, _addition_offsets, _label_ids

# `n` individuals, two per household; the first half work, three to an office
function layer_pop(n = 12)
    df = DataFrame(id = Int32.(1:n), age = Int8.(mod.(5 .* (1:n), 90)), sex = Int8.(ones(n)),
                   household = Int32.(cld.(1:n, 2)),
                   office = Int32[i <= n ÷ 2 ? cld(i, 3) : -1 for i in 1:n])
    return Population(df)
end

# where `layer_pop(1000)`'s household h sits on a grid 25 wide, from 0: the workers' households
# (1-250) and the others' alternate, so both spread over the whole grid
layer_place(h) = h <= 250 ? 2h - 2 : 2(h - 250) - 1

# coordinates for households 1..n, about 0.7 km apart east-west and 1.1 km north-south
layer_coords(n = 500) = DataFrame(id = Int32.(1:n), lon = Float32.(mod.(layer_place.(1:n), 25) .* 0.01),
                                  lat = Float32.(50 .+ div.(layer_place.(1:n), 25) .* 0.01))

# the home of `layer_pop`'s individual `i` in km, as `layer_coords` places its household; the
# km per degree at 50° are rounded, which is fine as the tests only compare distances
layer_home(i) = (q = layer_place(cld(i, 2)); (mod(q, 25) * 0.01 * 71.47, div(q, 25) * 0.01 * 111.19))

# the mean distance of the members of the settings in `ids` to their setting's centroid
function layer_spread(ids, members = eachindex(ids))
    by_setting = Dict{Int32, Vector{Int}}()
    foreach(i -> push!(get!(by_setting, ids[i], Int[]), i), members)
    return mean(values(by_setting)) do group
        homes = layer_home.(group)
        c = (mean(first.(homes)), mean(last.(homes)))
        mean(h -> hypot(h[1] - c[1], h[2] - c[2]), homes)
    end
end

# a declared setting type for the layers; its default char would clash with other test types
const LayerGym = declare_setting_type!("LayerTestGym"; char = 'γ')

# every block sorted by type, its mask the bits of the slotted types it holds, and no dead entries
function plans_well_formed(pop)
    store = activity_plans(pop)
    length(store) == sum(plan_length, individuals(pop)) || return false
    return all(individuals(pop)) do ind
        types = [setting_type_of(store.entries[k]) for k in plan_slots(store, ind)]
        mask = reduce(|, (_membership_bit(t) for t in types if _mask_slot(t) != 0); init = UInt16(0))
        issorted(types) && ind.membership_mask == mask
    end
end

# additions giving the individual at position `i` the setting ids `rows[i]` of type `T`
function hand_additions(T, rows; scales = nothing)
    offsets = Int32.(cumsum([1; length.(rows)]))
    sids = Int32.(reduce(vcat, rows; init = Int32[]))
    return _PlanAdditions(setting_type_index(T), offsets, sids, scales === nothing ? nothing : Float16.(scales))
end

merge_into!(pop, additions; kwargs...) = _merge_additions!(activity_plans(pop), individuals(pop), additions; kwargs...)

# assignment types written outside GEMS, through the assignment contract: everyone in one new
# setting per round, and joining the lowest-id setting not yet held
struct OneSettingTest <: NewSettingsAssignment end
GEMS._partition(::OneSettingTest, members, ctx, rng) = ones(Int32, length(members))
struct LowestIdTest <: JoinAssignment end
GEMS._join_state(::LowestIdTest, ctx) = _JoinCandidates(ctx.store, ctx.inds, ctx.tidx).ids
function GEMS._choose(::LowestIdTest, i, held, ids, ctx, rng)
    k = findfirst(!in(held), ids)
    return k === nothing ? Int32(0) : ids[k]
end

# a population of 1000 with the layers added, and each individual's primary or every gym id
layered(layers...; seed = 1) = add_setting_layers!(layer_pop(1000), layers...; seed = seed)
gym_ids(pop) = [setting_id(i, LayerGym, activity_plans(pop)) for i in individuals(pop)]
held_ids(pop) = [setting_ids(i, LayerGym, activity_plans(pop)) for i in individuals(pop)]

@testset "Setting Layers" begin

    @testset "Assignment types" begin
        @test PackedSettings(size = 10).size === 10.0
        @test RandomSettings(size = 2.5).size === 2.5
        @test AgeSortedSettings(size = Poisson(8)).size isa Poisson
        @test GroupedSettings(size = 4).by == setting_type_index(Household)
        @test GroupedSettings(size = 4, by = Office).by == setting_type_index(Office)
        spatial = SpatialSettings(size = 10, spread = 2)
        @test spatial.size === 10.0 && spatial.spread === 2.0
        @test JoinNearby(spread = Exponential(3)).spread isa Exponential
        @test JoinExisting() isa JoinAssignment
        @test spatial isa NewSettingsAssignment

        # keywords another assignment type has fail
        @test_throws UndefKeywordError PackedSettings()
        @test_throws MethodError PackedSettings(size = 10, spread = 2.0)
        @test_throws MethodError JoinExisting(size = 10)

        # `by` must be a type individuals hold entries of
        @test_throws ArgumentError GroupedSettings(size = 4, by = Workplace)
        @test_throws ArgumentError GroupedSettings(size = 4, by = GlobalSetting)
        @test_throws ArgumentError GroupedSettings(size = 4, by = 1)
    end

    @testset "Layer defaults and types" begin
        packed = PackedSettings(size = 10)
        layer = SettingLayer(Office; assignment = packed)
        @test layer isa SettingLayer{Office}
        @test layer.name === nothing
        @test layer.participation === 1.0
        @test layer.entries === 1
        @test layer.scale === 1.0
        @test isempty(layer.holding) && isempty(layer.not_holding)
        @test SettingLayer(Office; assignment = packed, name = :second_job).name == "second_job"

        # one type or a collection, without repeats
        office, class = setting_type_index(Office), setting_type_index(SchoolClass)
        @test SettingLayer(Office; assignment = JoinExisting(), holding = Office).holding == [office]
        @test SettingLayer(Office; assignment = packed, not_holding = (Office, SchoolClass, Office)).not_holding == [office, class]
        # or by name, as a config file gives them
        @test SettingLayer(Office; assignment = packed, holding = "Office").holding == [office]
        @test SettingLayer(Office; assignment = packed, not_holding = ["Office", "SchoolClass"]).not_holding == [office, class]
        @test GroupedSettings(size = 4, by = "Office").by == office
        @test_throws ArgumentError SettingLayer(Office; assignment = packed, holding = "NoSuchType")

        # declared and distribution-valued layers
        gym_layer = SettingLayer(LayerGym; assignment = packed, entries = Poisson(2), scale = Exponential(1))
        @test gym_layer isa SettingLayer{LayerGym}
        @test gym_layer.entries isa Poisson && gym_layer.scale isa Exponential
        @test SettingLayer(LayerGym; assignment = packed, entries = DiscreteUniform(0, 127)).entries isa DiscreteUniform
        @test SettingLayer(LayerGym; assignment = packed, entries = 0, scale = 0).entries === 0
    end

    @testset "Layer validation" begin
        packed = PackedSettings(size = 10)
        layer(T = Office; kwargs...) = SettingLayer(T; assignment = packed, kwargs...)

        # setting types
        @test_throws ArgumentError layer(Workplace)
        @test_throws ArgumentError layer(GlobalSetting)
        @test_throws ArgumentError layer(DeclaredSetting)
        @test_throws ArgumentError layer(1)
        @test_throws ArgumentError layer(holding = School)
        @test_throws ArgumentError layer(not_holding = GlobalSetting)
        @test_throws ArgumentError layer(holding = Office, not_holding = (SchoolClass, Office))

        # participation
        @test_throws ArgumentError layer(participation = -0.1)
        @test_throws ArgumentError layer(participation = 1.1)
        @test_throws ArgumentError layer(participation = NaN)

        # entries
        @test_throws ArgumentError layer(entries = -1)
        @test_throws ArgumentError layer(entries = 128)
        @test_throws TypeError layer(entries = 1.5)
        @test_throws TypeError layer(entries = Normal(2, 1))
        @test_throws ArgumentError layer(entries = DiscreteUniform(-1, 3))
        @test_throws ArgumentError layer(entries = DiscreteUniform(0, 128))

        # scale
        @test_throws ArgumentError layer(scale = -1)
        @test_throws ArgumentError layer(scale = 2 * floatmax(Float16))
        @test_throws ArgumentError layer(scale = Normal(1, 1))
        @test_throws TypeError layer(scale = "one")

        # assignment
        @test_throws UndefKeywordError SettingLayer(Office)
        @test_throws TypeError SettingLayer(Office; assignment = :packed)
        for size in (0, -1, Inf, NaN, Normal(10, 1), Poisson(0), Levy(0, 1), "ten")
            @test_throws ArgumentError SettingLayer(Office; assignment = PackedSettings(size = size))
        end
        for spread in (0, -2, Inf, Normal(0, 1), "far")
            @test_throws ArgumentError SettingLayer(Office; assignment = SpatialSettings(size = 10, spread = spread))
            @test_throws ArgumentError SettingLayer(Office; assignment = JoinNearby(spread = spread))
        end
        @test_throws ArgumentError SettingLayer(Office; assignment = GroupedSettings(size = 0))
        @test SettingLayer(Office; assignment = SpatialSettings(size = Poisson(10), spread = Exponential(2))) isa SettingLayer
    end

    @testset "Streams and draws" begin
        draws(s) = [gems_rand(getfield(s, k)) for k in 1:fieldcount(typeof(s))]
        d = draws(_LayerStreams(1, "Office[1]"))
        @test d == draws(_LayerStreams(1, "Office[1]"))
        @test allunique(d)
        @test d != draws(_LayerStreams(2, "Office[1]"))
        @test d != draws(_LayerStreams(1, "Office[2]"))
        @test _name_key("Gym") == _name_key("Gym") != _name_key("Gyn")

        rng = Xoshiro(1)
        @test _draw_entries(rng, 3) == 3
        @test_throws ArgumentError _draw_scale(rng, Dirac(1e6))
        # a number is the mean size; every setting has a member
        sizes = [_draw_size(rng, 2.5) for _ in 1:10_000]
        @test Set(sizes) == Set([2, 3]) && isapprox(mean(sizes), 2.5; atol = 0.05)
        @test all(_draw_size(rng, 0.2) == 1 for _ in 1:100)
        @test _draw_size(rng, Dirac(4.0)) == 4
    end

    @testset "Participants" begin
        pop = layer_pop(1000)
        store, inds = activity_plans(pop), individuals(pop)
        works = [plan_slot(store, i, Office) != 0 for i in inds]
        entry_counts(; kwargs...) = _layer_entry_counts(
            SettingLayer(Office; assignment = PackedSettings(size = 10), kwargs...), pop, _LayerStreams(7, "L"))

        @test all(==(1), entry_counts())
        @test all(==(3), entry_counts(entries = 3))
        @test (entry_counts(holding = Office) .> 0) == works
        @test (entry_counts(not_holding = Office) .> 0) == .!works
        @test (entry_counts(eligible = i -> age(i) >= 18) .> 0) == (age.(inds) .>= 18)
        @test isapprox(mean(entry_counts(entries = Poisson(2))), 2; atol = 0.2)

        # participants nest as participation or eligibility widen, and keep their entry counts
        few, more = entry_counts(participation = 0.3, entries = Poisson(3)), entry_counts(participation = 0.6, entries = Poisson(3))
        @test all(more[few .> 0] .> 0) && count(>(0), more) > count(>(0), few)
        @test more[few .> 0] == few[few .> 0]
        older = entry_counts(participation = 0.5, eligible = i -> age(i) >= 40)
        adults = entry_counts(participation = 0.5, eligible = i -> age(i) >= 20)
        @test all(adults[older .> 0] .> 0) && count(>(0), adults) > count(>(0), older)
        workers = entry_counts(participation = 0.5, holding = Office)
        everyone = entry_counts(participation = 0.5)
        @test all(everyone[workers .> 0] .> 0) && count(>(0), everyone) > count(>(0), workers)

        # draws past the cap are clamped, then refused by the room check
        many = entry_counts(entries = Poisson(1000))
        @test all(==(255), many)
        @test_throws ArgumentError _check_room(many, inds)
    end

    @testset "Room under the cap" begin
        inds = individuals(layer_pop())
        room = UInt8.(127 .- plan_length.(inds))
        @test _check_room(room, inds) === nothing
        room[end] += 1
        @test_throws ArgumentError _check_room(room, inds)
    end

    @testset "Merging additions" begin
        pop = layer_pop()
        store, inds = activity_plans(pop), individuals(pop)
        office = setting_type_index(Office)
        primaries = [_setting_id(i, office, store) for i in inds]
        # workers (1-6) get a second office, 7 and 8 their first ones, the rest none
        rows = [i <= 6 ? [10 + i] : [-1] for i in 1:12]
        rows[7], rows[8] = [20], [21, 22]
        bytes = merge_into!(pop, hand_additions(Office, rows))
        @test bytes >= sizeof(store.entries)
        @test plans_well_formed(pop)
        @test [_setting_id(i, office, store) for i in inds[1:6]] == primaries[1:6]
        @test all(plan_slot(store, inds[i], Office, Int32(10 + i)) != 0 for i in 1:6)
        @test all(plan_length(inds[i]) == 3 for i in 1:6)
        @test _setting_id(inds[7], office, store) == 20
        @test _setting_id(inds[8], office, store) == 21 && plan_length(inds[8]) == 3
        @test all(plan_length(inds[i]) == 1 for i in 9:12)
        @test _setting_id(inds[9], office, store) == DEFAULT_SETTING_ID
        @test all(store.active) && isempty(store.free)
        @test !any(i -> i.plan_scaled, inds)
        @test _max_setting_id(store, inds, office) == 22

        # the chunking does not change the result
        a, b = layer_pop(), layer_pop()
        add = hand_additions(Office, [[40 + i, 60 + i] for i in 1:12])
        merge_into!(a, add)
        merge_into!(b, add; chunks = [1:12])
        @test activity_plans(a).entries == activity_plans(b).entries

        # a held type with others behind it: the new entries go between them
        hh = hand_additions(Household, [[100 + i] for i in 1:12])
        merge_into!(pop, hh)
        @test plans_well_formed(pop)
        block_types(ind) = [setting_type_from_index(setting_type_of(store.entries[k])) for k in plan_slots(store, ind)]
        @test block_types(inds[1]) == [Household, Household, Office, Office]
        @test _setting_id(inds[1], setting_type_index(Household), store) == 1

        # once the settings are built, entries can't be merged
        store.indexed = true
        @test_throws ArgumentError merge_into!(pop, hh)
    end

    @testset "Merged scales and flags" begin
        pop = layer_pop()
        store, inds = activity_plans(pop), individuals(pop)
        # an inactive entry keeps its flag through the merge; SchoolClass's type index sorts
        # between Household's and Office's, so workers get it mid-block
        entry_active!(store, inds[1], plan_slot(store, inds[1], Household), false)
        scales = [i == 2 ? 3.0 : 1.0 for i in 1:12]
        merge_into!(pop, hand_additions(SchoolClass, [[30 + i] for i in 1:12]; scales = scales))
        @test plans_well_formed(pop)
        @test _type_scale_bound(store, setting_type_index(SchoolClass)) == 3.0f0
        @test !entry_active(store, plan_slot(store, inds[1], Household))
        @test entry_active(store, plan_slot(store, inds[1], SchoolClass))
        @test count(!, store.active) == 1
        # scaled: the inactive entry's holder and the one with scale 3
        @test inds[1].plan_scaled && inds[2].plan_scaled
        @test !any(i -> i.plan_scaled, inds[3:end])
        @test entry_scale(store.entries[plan_slot(store, inds[2], SchoolClass)]) == Float16(3)
    end

    @testset "Merging drops freed blocks" begin
        pop = layer_pop()
        store, inds = activity_plans(pop), individuals(pop)
        office = setting_type_index(Office)
        # the block holding office 99 is freed but keeps the entry
        plan_add!(store, inds[1], PlanEntry(Office, 99, DEFAULT_MEMBER_INDEX))
        plan_remove!(store, inds[1], plan_slot(store, inds[1], Office, Int32(99)))
        @test !isempty(store.free) && any(e -> setting_id(e) == 99, store.entries)
        @test _max_setting_id(store, inds, office) == 2
        merge_into!(pop, hand_additions(Office, [Int32[] for _ in 1:12]))
        @test isempty(store.free) && plans_well_formed(pop)
        @test !any(e -> setting_id(e) == 99, store.entries)
    end

    @testset "Packed layers" begin
        packed(size; kwargs...) = SettingLayer(LayerGym; assignment = PackedSettings(size = size), kwargs...)

        # sizes as drawn, ids from 1
        pop = layered(packed(10))
        @test plans_well_formed(pop)
        @test sort(unique(gym_ids(pop))) == 1:100
        @test all(==(10), values(countmap(gym_ids(pop))))
        sizes = collect(values(countmap(gym_ids(layered(packed(2.5))))))
        @test issubset(sizes[sizes .> 1], [2, 3]) && isapprox(mean(sizes), 2.5; atol = 0.1)
        @test isapprox(mean(values(countmap(gym_ids(layered(packed(Poisson(5))))))), 5; atol = 0.5)

        # a second entry is a different setting; each round numbers its own
        pop = layered(packed(10; entries = 2))
        @test all(h -> length(h) == 2 && h[1] in 1:100 && h[2] in 101:200, held_ids(pop))
        @test plans_well_formed(pop)

        # only participants get entries; the same seed gives the same plans
        pop = layered(packed(10; participation = 0.5))
        joined = gym_ids(pop) .!= DEFAULT_SETTING_ID
        works = [plan_slot(activity_plans(pop), i, Office) != 0 for i in individuals(pop)]
        @test 400 < count(joined) < 600
        @test plan_length.(individuals(pop)) == 1 .+ works .+ joined
        @test activity_plans(pop).entries == activity_plans(layered(packed(10; participation = 0.5))).entries
        @test activity_plans(pop).entries != activity_plans(layered(packed(10; participation = 0.5); seed = 2)).entries

        # two layers of one type get disjoint ids; names must differ
        @test all(h -> h[1] in 1:100 && h[2] in 101:200, held_ids(layered(packed(10), packed(10))))
        @test_throws ArgumentError add_setting_layers!(layer_pop(), packed(10; name = "a"), packed(10; name = "a"); seed = 1)

        # not once the settings are built
        pop = layer_pop()
        activity_plans(pop).indexed = true
        @test_throws ArgumentError add_setting_layers!(pop, packed(10); seed = 1)
    end

    @testset "Other new settings" begin
        gym(a; kwargs...) = SettingLayer(LayerGym; assignment = a, kwargs...)

        # a second entry is a different setting for every type, and ids stay compact
        for a in (RandomSettings(size = 10), GroupedSettings(size = 4), AgeSortedSettings(size = 10))
            pop = layered(gym(a; entries = 2))
            held = held_ids(pop)
            @test all(h -> length(h) == 2 && h[1] != h[2], held)
            ids = unique(reduce(vcat, held))
            @test sort(ids) == 1:length(ids)
            @test plans_well_formed(pop)
        end

        # grouped: households stay whole, filling settings of 5 with two households each
        ids = gym_ids(layered(gym(GroupedSettings(size = 5))))
        @test ids[1:2:end] == ids[2:2:end]
        @test all(==(4), values(countmap(ids)))
        # offices stay whole; members without one are groups of one, so no setting overfills
        ids = gym_ids(layered(gym(GroupedSettings(size = 6, by = Office))))
        @test all(k -> allequal(ids[(3k - 2):3k]), 1:166)
        @test all(<=(6), values(countmap(ids)))

        # age-sorted: settings in id order cover consecutive age bands
        pop = layered(gym(AgeSortedSettings(size = 10)))
        ids, ages = gym_ids(pop), age.(individuals(pop))
        @test all(s -> maximum(ages[ids .== s]) <= minimum(ages[ids .== s + 1]), 1:99)

        # random: one pool across rounds, so some setting holds first and second entries
        held = held_ids(layered(gym(RandomSettings(size = 10); entries = 2)))
        pool = unique(reduce(vcat, held))
        @test 150 < length(pool) <= 200
        @test !isdisjoint(first.(held), last.(held))
        # more entries than the pool has settings
        @test_throws ArgumentError add_setting_layers!(layer_pop(), gym(RandomSettings(size = 36); entries = 3); seed = 1)

        # a different size keeps every round's order: settings of 5 halve those of 10
        tens = held_ids(layered(gym(PackedSettings(size = 10); entries = 2)))
        fives = held_ids(layered(gym(PackedSettings(size = 5); entries = 2)))
        @test all(cld.(f .- [0, 200], 2) == t .- [0, 100] for (t, f) in zip(tens, fives))
    end

    @testset "Joining existing settings" begin
        # second job: a tenth of the workers join a second office, keeping their own as primary
        pop = layer_pop(3000)
        store, inds = activity_plans(pop), individuals(pop)
        primaries = [setting_id(i, Office, store) for i in inds]
        second_job = SettingLayer(Office; assignment = JoinExisting(), holding = Office, participation = 0.1)
        add_setting_layers!(pop, second_job; seed = 4)
        held = [setting_ids(i, Office, store) for i in inds]
        second = length.(held) .== 2
        @test 100 < count(second) < 200 && !any(second[1501:end])
        @test [setting_id(i, Office, store) for i in inds] == primaries
        @test all(allunique, held) && maximum(reduce(vcat, held)) == 500
        @test plans_well_formed(pop)
        cntnr = settingscontainer(Simulation(population = pop, infected_fraction = 0.0))
        @test validate_plans(pop, cntnr)
        @test sum(s -> length(individuals(s)), settings(cntnr, Office)) == 1500 + count(second)

        # draws ∝ member count: of offices with 1 and 9 members, the small one gets about a tenth
        df = DataFrame(id = Int32.(1:1010), age = Int8.(fill(30, 1010)), sex = Int8.(ones(1010)),
                       household = Int32.(1:1010), office = Int32[i == 1 ? 1 : i <= 10 ? 2 : -1 for i in 1:1010])
        pop = Population(df)
        add_setting_layers!(pop, SettingLayer(Office; assignment = JoinExisting(), not_holding = Office); seed = 5)
        joined = [setting_id(i, Office, activity_plans(pop)) for i in individuals(pop)[11:end]]
        @test all(in((1, 2)), joined) && 50 < count(==(1), joined) < 150

        # with two offices, a worker's third entry finds none it does not hold
        pop = layer_pop()
        third = SettingLayer(Office; assignment = JoinExisting(), holding = Office, entries = 3)
        @test_logs (:warn, r"^Setting layer \"Office\[1\]\" left out 12 entries") (:info,) add_setting_layers!(pop, third; seed = 1)
        @test pop.params["setting_layers"][1]["shortfall"] == 12
        @test !haskey(pop.params["setting_layers"][1], "first_id")
        @test all(i -> sort(setting_ids(i, Office, activity_plans(pop))) == [1, 2], individuals(pop)[1:6])

        # the exact draw steps past held settings and keeps the others' proportions
        c = _JoinCandidates(Int32[1, 2, 3], [1, 10, 12])
        rng = Xoshiro(1)
        draws = [_draw_unheld(c, Int32[2], rng) for _ in 1:3000]
        @test Set(draws) == Set(Int32[1, 3]) && isapprox(count(==(3), draws) / 3000, 2 / 3; atol = 0.05)
        @test all(_draw_unheld(c, Int32[3], rng) in (1, 2) for _ in 1:100)
        @test _draw_unheld(c, Int32[1, 2, 3], rng) == 0
    end

    @testset "Spatial layers" begin
        near(a; kwargs...) = SettingLayer(LayerGym; assignment = a, kwargs...)
        spatial(a, coords = layer_coords(); seed = 1) =
            add_setting_layers!(layer_pop(1000), a; seed = seed, household_coordinates = coords)

        # new settings: smaller spread, closer co-members; exact sizes
        nearby = gym_ids(spatial(near(SpatialSettings(size = 10, spread = 0.2))))
        far = gym_ids(spatial(near(SpatialSettings(size = 10, spread = 20))))
        @test all(==(10), values(countmap(nearby)))
        @test layer_spread(nearby) < layer_spread(far) / 2

        # a second round has other co-members
        held = held_ids(spatial(near(SpatialSettings(size = 10, spread = 1); entries = 2)))
        members = Dict{Int32, Set{Int}}()
        foreach(i -> foreach(s -> push!(get!(members, s, Set{Int}()), i), held[i]), eachindex(held))
        @test count(h -> members[h[1]] != members[h[2]], held) > 900

        # members whose household has no coordinates are packed among themselves
        # (sizes of 7 don't divide the 500 located members, so the last setting can't fill up exactly)
        ids = gym_ids(spatial(near(SpatialSettings(size = 7, spread = 1)), layer_coords(250)))
        @test isdisjoint(ids[1:500], ids[501:end]) && all(!=(DEFAULT_SETTING_ID), ids)

        # without coordinates, spatial layers are refused
        @test_throws ArgumentError add_setting_layers!(layer_pop(), near(SpatialSettings(size = 10, spread = 1)); seed = 1)
        @test_throws ArgumentError add_setting_layers!(layer_pop(), near(JoinNearby(spread = 1)); seed = 1)

        # joining: non-workers join offices nearer their home as the spread falls
        office_at(pop) = [setting_id(i, Office, activity_plans(pop)) for i in individuals(pop)[501:end]]
        office_home(k) = (homes = layer_home.(filter(<=(500), (3k - 2):3k)); (mean(first.(homes)), mean(last.(homes))))
        distance(offices) = mean(hypot((layer_home(500 + n) .- office_home(k))...) for (n, k) in enumerate(offices))
        joined_offices(spread, coords = layer_coords()) =
            office_at(spatial(SettingLayer(Office; assignment = JoinNearby(spread = spread), not_holding = Office), coords))
        @test distance(joined_offices(0.2)) < distance(joined_offices(20)) / 2
        # past the ring cap, and without coordinates, the draw falls back to all offices
        @test all(in(1:167), joined_offices(1e5)) && length(unique(joined_offices(1e5))) > 100
        @test all(in(1:167), joined_offices(1, layer_coords(250))) && length(unique(joined_offices(1, layer_coords(250)))) > 100
        # settings already held are skipped: four more offices for every worker, all different
        pop = spatial(SettingLayer(Office; assignment = JoinNearby(spread = 0.1), holding = Office, entries = 4))
        @test all(h -> length(h) == 5 && allunique(h), [setting_ids(i, Office, activity_plans(pop)) for i in individuals(pop)[1:500]])
    end

    @testset "Scales, limits and merge checks" begin
        office, gym = setting_type_index(Office), setting_type_index(LayerGym)
        layer_scale(pop, T) = [Float32(entry_scale(activity_plans(pop).entries[plan_slot(activity_plans(pop), i, T)]))
                               for i in individuals(pop) if plan_slot(activity_plans(pop), i, T) != 0]

        # a number as the scale: every new entry has it, and only its holders are scaled
        pop = add_setting_layers!(layer_pop(1000),
            SettingLayer(Office; assignment = PackedSettings(size = 5), not_holding = Office, scale = 2.0); seed = 1)
        inds = individuals(pop)
        @test all(==(2.0f0), layer_scale(pop, Office)[501:end]) && _type_scale_bound(activity_plans(pop), office) == 2.0f0
        @test all(i -> i.plan_scaled, inds[501:end]) && !any(i -> i.plan_scaled, inds[1:500])
        # a distribution: drawn per entry, the type's bound the largest one written
        pop = add_setting_layers!(layer_pop(1000), SettingLayer(LayerGym; assignment = PackedSettings(size = 5), scale = Exponential(2)); seed = 1)
        scales = layer_scale(pop, LayerGym)
        @test length(unique(scales)) > 100 && _type_scale_bound(activity_plans(pop), gym) == maximum(scales)
        # a drawn scale above the range is refused when the layer is applied
        @test_throws ArgumentError add_setting_layers!(layer_pop(), SettingLayer(LayerGym; assignment = PackedSettings(size = 5), scale = Dirac(1e6)); seed = 1)

        # a layer that adds nothing leaves the plans as they are, but is recorded
        pop = layer_pop()
        entries = activity_plans(pop).entries
        add_setting_layers!(pop, SettingLayer(LayerGym; assignment = PackedSettings(size = 5), participation = 0.0); seed = 1)
        @test activity_plans(pop).entries === entries && pop.params["setting_layers"][1]["entries"] == 0

        # the merge refuses, before writing, a setting held twice and more entries than the cap
        pop = layer_pop()
        to_first(ids) = hand_additions(Office, vcat([ids], [Int32[] for _ in 2:12]))
        @test_throws ArgumentError merge_into!(pop, to_first([1]))
        @test_throws ArgumentError merge_into!(pop, to_first([5, 5]))
        @test_throws ArgumentError merge_into!(pop, to_first(collect(100:226)))
        @test plans_well_formed(pop) && all(i -> plan_length(i) <= 2, individuals(pop))

        # offsets and ids stay within Int32
        @test_throws ArgumentError _addition_offsets(fill(UInt8(255), cld(Int(typemax(Int32)), 255) + 1))
        @test _label_ids(Int32[1], Int(typemax(Int32))) == (Int32[typemax(Int32)], Int(typemax(Int32)) + 1)
        @test_throws ArgumentError _label_ids(Int32[1, 2], Int(typemax(Int32)))
    end

    @testset "Names and records" begin
        packed = SettingLayer(LayerGym; assignment = PackedSettings(size = 10))

        # each call's layers are recorded, default names counting the recorded ones
        pop = layer_pop(1000)
        @test_logs (:info, r"^Setting layers added 1000 plan entries") add_setting_layers!(pop, packed; seed = 1)
        add_setting_layers!(pop, packed; seed = 1)
        records = pop.params["setting_layers"]
        @test [r["name"] for r in records] == ["LayerTestGym[1]", "LayerTestGym[2]"]
        @test (records[1]["first_id"], records[1]["last_id"], records[2]["first_id"]) == (1, 100, 101)
        @test records[1]["entries"] == 1000 && records[1]["shortfall"] == 0 && records[1]["seed"] == 1
        @test records[1]["description"] == "PackedSettings(size = 10.0), participation = 1.0, entries = 1, scale = 1.0"
        # so the second layer draws differently
        @test [h[2] - 100 for h in held_ids(pop)] != [h[1] for h in held_ids(pop)]
        # a name the population already records is refused
        named = SettingLayer(LayerGym; assignment = PackedSettings(size = 10), name = "LayerTestGym[1]")
        @test_throws ArgumentError add_setting_layers!(pop, named; seed = 1)
        @test !haskey(add_setting_layers!(layer_pop(); seed = 1).params, "setting_layers")

        # types by name in the description
        grouped = SettingLayer(LayerGym; assignment = GroupedSettings(size = 4), holding = Office)
        @test _layer_description(grouped) ==
            "GroupedSettings(size = 4.0, by = Household), holding = [Office], participation = 1.0, entries = 1, scale = 1.0"
        @test occursin("eligible = custom", _layer_description(SettingLayer(LayerGym; assignment = JoinExisting(), eligible = i -> true)))

        # default names count the named layers of the type too
        pop = layer_pop()
        named = SettingLayer(LayerGym; assignment = PackedSettings(size = 10), name = "weekly")
        add_setting_layers!(pop, named, packed, packed; seed = 1)
        @test [r["name"] for r in pop.params["setting_layers"]] == ["weekly", "LayerTestGym[2]", "LayerTestGym[3]"]

        # a failing layer leaves the ones before it applied and recorded
        pop = layer_pop()
        too_many = SettingLayer(LayerGym; assignment = RandomSettings(size = 36), entries = 3)
        @test_throws ArgumentError add_setting_layers!(pop, packed, too_many; seed = 1)
        @test length(pop.params["setting_layers"]) == 1 && all(i -> setting_id(i, LayerGym, activity_plans(pop)) > 0, individuals(pop))

        # a layer's draws do not depend on another type's layer before it
        offices(size) = SettingLayer(Office; assignment = PackedSettings(size = size), not_holding = Office)
        @test gym_ids(layered(offices(5), packed)) == gym_ids(layered(offices(7), packed))
    end

    @testset "Assignment types from outside GEMS" begin
        @test all(==([1, 2]), held_ids(layered(SettingLayer(LayerGym; assignment = OneSettingTest(), entries = 2))))
        pop = layered(SettingLayer(Office; assignment = LowestIdTest(), not_holding = Office, entries = 2))
        @test all(i -> setting_ids(i, Office, activity_plans(pop)) == [1, 2], individuals(pop)[501:end])
        @test plans_well_formed(pop)
    end

    @testset "Empty layers" begin
        # nobody taking part leaves the plans as they are, for every kind of assignment
        assignments = (PackedSettings(size = 5), RandomSettings(size = 5), GroupedSettings(size = 5),
            AgeSortedSettings(size = 5), SpatialSettings(size = 5, spread = 1), JoinExisting(), JoinNearby(spread = 1))
        for a in assignments
            pop = layer_pop(1000)
            entries = activity_plans(pop).entries
            add_setting_layers!(pop, SettingLayer(Office; assignment = a, participation = 0.0); seed = 1,
                household_coordinates = layer_coords())
            @test activity_plans(pop).entries === entries && pop.params["setting_layers"][1]["entries"] == 0
        end
        # joining a type nobody holds leaves every entry out, with one warning
        @test_logs (:warn, r"left out 1000 entries") (:info,) add_setting_layers!(layer_pop(1000),
            SettingLayer(LayerGym; assignment = JoinExisting()); seed = 1)
    end

    @testset "Hilbert order and coordinates" begin
        # the curve visits every cell of a 64 × 64 block first, each next to the one before
        cells = sort([(x, y) for x in 0:63 for y in 0:63]; by = c -> GEMS._hilbert(c...))
        @test [GEMS._hilbert(c...) for c in cells] == 0:4095
        @test all(sum(abs.(cells[k + 1] .- cells[k])) == 1 for k in 1:4095)

        # rows with a missing or non-finite value, or no valid id, give households without coordinates
        table = DataFrame(id = Union{Missing, Int}[1, 2, 3, 0, missing], lon = Union{Missing, Float64}[7.6, missing, 7.6, 7.6, 7.6],
                          lat = [51.9, 51.9, NaN, 51.9, 51.9])
        coords = GEMS._HomeCoordinates(table)
        @test length(coords.x) == 1 && isfinite(coords.x[1])
        @test_throws ArgumentError GEMS._HomeCoordinates(table[2:end, :])
    end

    @testset "Layers from a config file" begin
        office, gym = setting_type_index(Office), DeclaredSetting{:LayerConfGym}
        gym_section(layers) = Dict("char" => "λ", "layer" => layers, "contact_sampling_method" =>
            Dict("type" => "ContactparameterSampling", "parameters" => Dict("contactparameter" => 2.0)))
        packed = Dict("type" => "PackedSettings", "size" => 10)

        # one section with an array of layers, one with a single table; sections in sorted order
        config = Dict("Settings" => Dict(
            "LayerConfGym" => gym_section([
                Dict("ages" => [18, 65], "participation" => 0.5, "assignment" => packed,
                     "entries" => Dict("distribution" => "Poisson", "parameters" => [2])),
                Dict("name" => "weekend", "holding" => "Office", "assignment" => Dict("type" => "JoinExisting"))]),
            "Office" => Dict("layer" => Dict("holding" => ["Office"], "participation" => 0.1,
                "assignment" => Dict("type" => "JoinNearby", "spread" => Dict("distribution" => "Exponential", "parameters" => [2.0]))))))
        @test GEMS.determine_setting_types!(config) == [gym]
        layers = GEMS.create_setting_layers(config)
        @test length(layers) == 3 && layers[1] isa SettingLayer{gym} && layers[3] isa SettingLayer{Office}
        eligible = layers[1].eligible
        @test eligible isa GEMS._Criteria && (eligible.lo, eligible.hi) == (18, 65)
        @test isempty(eligible.sex) && isempty(eligible.occupation) && isempty(eligible.education) && layers[1].entries isa Poisson
        @test layers[1].assignment == PackedSettings(size = 10) && occursin("eligible = ages 18-65", _layer_description(layers[1]))
        @test layers[2].name == "weekend" && layers[2].holding == [office] && layers[2].assignment == JoinExisting()
        @test layers[3].assignment.spread isa Exponential && layers[3].holding == [office]

        # what a layer table can't hold
        bad(layer) = GEMS.create_setting_layers(Dict("Settings" => Dict("LayerConfGym" => Dict("layer" => layer))))
        @test_throws ArgumentError bad(Dict("assignment" => packed, "colour" => "red"))
        @test_throws ArgumentError bad(Dict("participation" => 0.5))
        @test_throws ArgumentError bad(Dict("assignment" => Dict("type" => "Packed", "size" => 10)))
        @test_throws ArgumentError bad(Dict("assignment" => Dict("type" => "PackedSettings", "size" => 10, "spread" => 1)))
        @test_throws ArgumentError bad(Dict("ages" => [65, 18], "assignment" => packed))

        # layers passed in replace the config's; the layer seed defaults to the simulation's
        one_layer = SettingLayer(gym; assignment = PackedSettings(size = 10))
        @test GEMS.determine_setting_layers(config, one_layer) == (one_layer,)
        @test GEMS.determine_setting_layers(config, [one_layer, one_layer]) == (one_layer, one_layer)
        @test length(GEMS.determine_setting_layers(config, nothing)) == 3
        @test_throws ArgumentError GEMS.determine_setting_layers(config, [1])
        with_seed = Dict("Simulation" => Dict("layer_seed" => 3))
        @test GEMS.determine_layer_seed(Dict(), nothing, 7) == 7
        @test GEMS.determine_layer_seed(with_seed, nothing, 7) == 3 && GEMS.determine_layer_seed(with_seed, 5, 7) == 5
        @test_throws ArgumentError GEMS.determine_layer_seed(Dict(), 1.5, 7)

        # end to end: adults go to the gym, which shows in the results; an empty declared type warns
        cfg = TOML.parsefile(joinpath(pkgdir(GEMS), "data", "DefaultConf.toml"))
        cfg["Settings"]["LayerConfGym"] = gym_section(Dict("ages" => [18, 65], "assignment" => packed))
        cfg["Settings"]["LayerConfUnused"] = Dict("char" => "μ")
        mktempdir() do dir
            path = joinpath(dir, "config.toml")
            open(io -> TOML.print(io, cfg), path, "w")
            sim = @test_logs (:warn, r"LayerConfUnused") match_mode = :any Simulation(configfile = path, pop_size = 2000, seed = 1, infected_fraction = 0.05)
            adults = count(i -> 18 <= age(i) <= 65, individuals(sim))
            @test sum(s -> length(individuals(s)), settings(sim, gym)) == adults
            @test population(sim).params["setting_layers"][1]["seed"] == 1
            run!(sim)
            rd = ResultData(sim)
            @test "LayerConfGym" in setting_data(rd).setting_type
            @test 'λ' in tick_cases_per_setting(rd).setting_type

            # on one population, a fixed layer seed gives the same layers in every run, the default a new draw
            people = DataFrame(id = Int32.(1:500), age = Int8.(mod.(1:500, 90)), sex = Int8.(ones(500)), household = Int32.(cld.(1:500, 2)))
            gyms(seed; kwargs...) = (s = Simulation(configfile = path, population = people, seed = seed, infected_fraction = 0.0; kwargs...);
                [setting_id(i, gym, activity_plans(s)) for i in individuals(s)])
            @test gyms(1; layer_seed = 9) == gyms(2; layer_seed = 9)
            @test gyms(1) != gyms(2)
        end

        # a passed population keeps its plans; a DataFrame gets the layers
        pop = layer_pop()
        @test_logs (:warn, r"setting layers will be ignored") match_mode = :any Simulation(population = pop, setting_layers = one_layer, infected_fraction = 0.0)
        @test !haskey(pop.params, "setting_layers")
        df = DataFrame(id = Int32.(1:12), age = Int8.(fill(30, 12)), sex = Int8.(ones(12)), household = Int32.(1:12))
        @test length(settings(Simulation(population = df, setting_layers = one_layer, infected_fraction = 0.0), gym)) == 2

        # a population that already holds the type a layer creates is likely applied twice
        pop = add_setting_layers!(layer_pop(), one_layer; seed = 1)
        @test_logs (:warn, r"already holds") match_mode = :any GEMS._settings_from_layered_population(pop, false, (one_layer,), 2)

        # renumbered ids move the records along; floors keep new ids above the settings file's
        df = DataFrame(id = Int32.(1:12), age = Int8.(fill(30, 12)), sex = Int8.(ones(12)), household = Int32.(1:12),
                       office = Int32[101, 101, 102, 102, 103, 103, -1, -1, -1, -1, -1, -1])
        pop = Population(df)
        new_offices = SettingLayer(Office; assignment = PackedSettings(size = 3), not_holding = Office)
        GEMS._settings_from_layered_population(pop, false, (new_offices,), 1)
        @test (pop.params["setting_layers"][1]["first_id"], pop.params["setting_layers"][1]["last_id"]) == (4, 5)
        pop = add_setting_layers!(layer_pop(), one_layer; seed = 1, id_floors = Dict(gym => 50))
        @test minimum(i -> setting_id(i, gym, activity_plans(pop)), individuals(pop)) == 51
        file = Dict(:Office => DataFrame(id = [1, 7, 3]), :Household => DataFrame(id = [1, 2]), :NoSuchType => DataFrame(id = [9]))
        @test GEMS._settings_file_max_ids(file) == Dict(Office => 7, Household => 2)
    end

    @testset "Eligibility and participation by attribute" begin
        n = 3000
        df = DataFrame(id = Int32.(1:n), age = Int8.(mod.(1:n, 90)), sex = Int8.(mod.(1:n, 2) .+ 1),
                       occupation = Int16.(mod.(1:n, 5)), education = Int8.(mod.(1:n, 7)), household = Int32.(cld.(1:n, 2)))
        inds = individuals(Population(df))
        ages = age.(inds)
        packed = Dict("type" => "PackedSettings", "size" => 10)
        gym(; kwargs...) = SettingLayer(LayerGym; assignment = PackedSettings(size = 10), kwargs...)
        from_config(layer) = only(GEMS.create_setting_layers(Dict("Settings" => Dict("LayerTestGym" => Dict("layer" => layer)))))
        joined(layer) = (p = add_setting_layers!(Population(df), layer; seed = 1);
            [setting_id(i, LayerGym, activity_plans(p)) != DEFAULT_SETTING_ID for i in individuals(p)])

        # attributes in a layer table pick out who may take part
        layer = from_config(Dict("ages" => [20, 60], "sex" => 2, "occupation" => [1, 3], "education" => 4, "assignment" => packed))
        expected = [20 <= age(i) <= 60 && sex(i) == 2 && occupation(i) in (1, 3) && education(i) == 4 for i in inds]
        @test count(expected) > 0 && joined(layer) == expected
        @test occursin("eligible = ages 20-60 sex 2 occupation 1/3 education 4", _layer_description(layer))

        # participation by age band; the first matching row counts, and no row means no participation
        rows = [Dict("ages" => [0, 17], "p" => 0.2), Dict("ages" => [18, 64], "p" => 0.6), Dict("ages" => [10, 99], "p" => 1.0)]
        layer = from_config(Dict("participation" => rows[1:2], "assignment" => packed))
        took_part = joined(layer)
        share(band) = count(took_part .& band) / count(band)
        @test isapprox(share(ages .<= 17), 0.2; atol = 0.05) && isapprox(share(18 .<= ages .<= 64), 0.6; atol = 0.05)
        @test !any(took_part[ages .>= 65])
        @test _layer_description(layer) == "PackedSettings(size = 10.0), participation = [ages 0-17: 0.2; ages 18-64: 0.6], entries = 1, scale = 1.0"
        # a third row catches everyone up to 99, but rows before it come first
        with_third = joined(from_config(Dict("participation" => rows, "assignment" => packed)))
        @test with_third[ages .< 65] == took_part[ages .< 65] && all(with_third[ages .>= 65])
        # a row without criteria matches everyone
        @test all(joined(from_config(Dict("participation" => [Dict("p" => 1.0)], "assignment" => packed))))

        # each row is the same as eligibility for its band with its probability
        for (lo, hi, p) in ((0, 17, 0.2), (18, 64, 0.6))
            in_band = lo .<= ages .<= hi
            @test took_part[in_band] == joined(gym(eligible = GEMS._Criteria(ages = (lo, hi)), participation = p))[in_band]
        end
        # and participants nest as one row's probability rises
        raised = joined(from_config(Dict("participation" => [rows[1], Dict("ages" => [18, 64], "p" => 0.9)], "assignment" => packed)))
        @test all(raised[took_part]) && count(raised) > count(took_part)

        # one table in single brackets is one row
        @test from_config(Dict("participation" => Dict("ages" => [18, 64], "p" => 0.6), "assignment" => packed)).participation.p == [0.6]

        # a function of the individual gives the probability, checked as it is drawn, only for those eligible
        @test joined(gym(participation = i -> age(i) >= 40 ? 1.0 : 0.0)) == (ages .>= 40)
        @test occursin("participation = custom", _layer_description(gym(participation = i -> 0.5)))
        @test_throws ArgumentError add_setting_layers!(Population(df), gym(participation = i -> 1.5); seed = 1)
        adults_only(i) = age(i) >= 18 ? 0.5 : error("asked about a child")
        @test !any(joined(gym(eligible = GEMS._Criteria(ages = (18, 99)), participation = adults_only))[ages .< 18])

        # what is refused
        band = GEMS._Criteria(ages = (18, 64))
        @test_throws ArgumentError gym(participation = GEMS._ParticipationTable([band], [1.5]))
        @test_throws ArgumentError gym(participation = GEMS._ParticipationTable([band], [0.5, 0.5]))
        @test_throws ArgumentError gym(participation = Poisson(1))
        @test_throws ArgumentError from_config(Dict("participation" => [], "assignment" => packed))
        @test_throws ArgumentError from_config(Dict("participation" => [Dict("ages" => [0, 17])], "assignment" => packed))
        @test_throws ArgumentError from_config(Dict("participation" => [Dict("colour" => "red", "p" => 0.5)], "assignment" => packed))
        @test_throws ArgumentError from_config(Dict("sex" => "female", "assignment" => packed))
        @test_throws ArgumentError from_config(Dict("sex" => 200, "assignment" => packed))
        @test_throws ArgumentError from_config(Dict("occupation" => [], "assignment" => packed))
    end

    @testset "Joining via another setting" begin
        # 300 households of two adults; households 1-100 have one child, 101-200 two in different classes
        rows = NamedTuple[]
        for h in 1:300, k in 1:(2 + (h <= 100) + 2 * (100 < h <= 200))
            child = k > 2
            class = child ? Int32(k == 3 ? mod(h, 20) + 1 : mod(h + 7, 20) + 1) : Int32(-1)
            push!(rows, (age = Int8(child ? 8 : 35), household = Int32(h), schoolclass = class))
        end
        df = DataFrame(rows)
        df.id = Int32.(1:nrow(df))
        df.sex = Int8.(ones(nrow(df)))
        adults(pop) = filter(i -> age(i) >= 18, individuals(pop))
        classes(pop, i) = setting_ids(i, SchoolClass, activity_plans(pop))
        children_classes(pop, h) = [classes(pop, c)[1] for c in individuals(pop) if age(c) < 18 && household_id(c, activity_plans(pop)) == h]
        parents = SettingLayer(SchoolClass; assignment = JoinVia(via = Household), eligible = i -> age(i) >= 18)

        # parents join a class one of their children is in; parents without a child get none
        pop = Population(df)
        @test_logs (:warn, r"left out 200 entries") (:info,) add_setting_layers!(pop, parents; seed = 1)
        @test plans_well_formed(pop)
        for i in adults(pop)
            h = household_id(i, activity_plans(pop))
            @test h > 200 ? isempty(classes(pop, i)) : (length(classes(pop, i)) == 1 && classes(pop, i)[1] in children_classes(pop, h))
        end
        # with two children, both classes come up
        first_class = count(i -> 100 < household_id(i, activity_plans(pop)) <= 200 &&
            classes(pop, i)[1] == children_classes(pop, household_id(i, activity_plans(pop)))[1], adults(pop))
        @test 60 < first_class < 140
        # a second entry takes the other child's class, and finds none with one child
        pop = Population(df)
        add_setting_layers!(pop, SettingLayer(SchoolClass; assignment = JoinVia(via = Household), eligible = i -> age(i) >= 18, entries = 2); seed = 1)
        @test all(i -> sort(classes(pop, i)) == sort(children_classes(pop, household_id(i, activity_plans(pop)))),
            filter(i -> household_id(i, activity_plans(pop)) <= 200, adults(pop)))
        @test occursin("JoinVia(via = Household)", _layer_description(parents))
        @test GEMS.create_layer_assignment(Dict("type" => "JoinVia", "via" => "Household"), "X") == JoinVia()
        @test_throws ArgumentError JoinVia(via = Workplace)

        # a household decides together: both members or neither, also as participation rises
        family(p; unit = Household) = SettingLayer(LayerGym; assignment = PackedSettings(size = 10), participation = p,
            participation_unit = unit)
        joined(layer) = (pop = layered(layer); gym_ids(pop) .!= DEFAULT_SETTING_ID)
        half = joined(family(0.5))
        @test half[1:2:end] == half[2:2:end] && 400 < count(half) < 600
        @test all(joined(family(0.8))[half]) && count(joined(family(0.8))) > count(half)
        # with different probabilities, the more likely member joins whenever the other does
        uneven = joined(family(i -> isodd(id(i)) ? 0.8 : 0.4))
        @test all(uneven[1:2:end][uneven[2:2:end]]) && count(uneven[1:2:end]) > count(uneven[2:2:end])
        # individuals outside every unit draw alone: offices decide together, non-workers each on their own
        by_office = joined(family(0.5; unit = Office))
        @test all(k -> allequal(by_office[(3k - 2):3k]), 1:166)
        @test !all(k -> by_office[500 + 2k - 1] == by_office[500 + 2k], 1:250)
        from_config = GEMS.create_setting_layer(LayerGym, Dict("participation_unit" => "Household",
            "assignment" => Dict("type" => "PackedSettings", "size" => 10)), "LayerTestGym")
        @test from_config.participation_unit == setting_type_index(Household)
        @test occursin("participation_unit = Household", _layer_description(family(0.5)))
    end

    @testset "Rescaling another entry" begin
        office = setting_type_index(Office)
        primary_scale(pop, i) = Float64(entry_scale(activity_plans(pop).entries[plan_slot(activity_plans(pop), i, Office)]))
        second_job(factor; participation = 0.5, kwargs...) = SettingLayer(Office; assignment = JoinExisting(), holding = Office,
            participation = participation, rescale = Office => factor, kwargs...)

        # the primary office of each participant is scaled once, below or above 1; nobody else's
        for factor in (0.7, 1.5)
            pop = layered(second_job(factor))
            inds = individuals(pop)
            second = [length(setting_ids(i, Office, activity_plans(pop))) == 2 for i in inds]
            @test count(second) > 100
            @test all(primary_scale(pop, i) == Float64(Float16(factor)) for i in inds[second])
            @test all(primary_scale(pop, i) == 1 for i in inds[1:500][.!second[1:500]])
            @test all(i -> i.plan_scaled, inds[second])
            @test _type_scale_bound(activity_plans(pop), office) == max(1.0f0, Float32(Float16(factor)))
            # the settings take the new scales into their bounds
            @test validate_plans(pop, settingscontainer(Simulation(population = pop, infected_fraction = 0.0)))
        end
        # once per participant, even with several entries; not for participants who get none
        pop = layer_pop()
        add_setting_layers!(pop, SettingLayer(Office; assignment = JoinExisting(), holding = Office, entries = 3,
            rescale = Office => 0.5); seed = 1)
        @test all(primary_scale(pop, i) == 0.5 for i in individuals(pop)[1:6])
        no_entries = layered(second_job(0.5; entries = 0))
        @test all(primary_scale(no_entries, i) == 1 for i in individuals(no_entries)[1:500])
        # every office held before the layer, not the one it adds
        pop = layered(second_job(1.0; participation = 1.0, name = "second"), second_job(0.5; name = "third"))
        store = activity_plans(pop)
        office_scales(i) = (r = GEMS._plan_type_run(store, i, office);
            [Float64(entry_scale(store.entries[Int(i.plan_offset) + r[1] + k])) for k in 0:(r[2] - 1)])
        third = filter(i -> length(setting_ids(i, Office, store)) == 3, individuals(pop))
        @test length(third) > 100
        @test all(office_scales(i) == [0.5, 0.5, 1.0] for i in third)

        # a result above the scale range is refused, and nothing is rescaled
        pop = layer_pop()
        workers = individuals(pop)[1:6]
        foreach(i -> set_scale!(pop, i, Office, setting_id(i, Office, activity_plans(pop)), 60000), workers)
        @test_throws ArgumentError add_setting_layers!(pop, second_job(2.0; participation = 1.0); seed = 1)
        @test all(primary_scale(pop, i) == 60000 for i in workers)

        # what is refused, and how it reads from a config file
        @test_throws ArgumentError SettingLayer(Office; assignment = JoinExisting(), rescale = Office => 0.5)
        @test_throws ArgumentError second_job(-0.5)
        @test_throws ArgumentError second_job("half")
        @test_throws ArgumentError SettingLayer(Office; assignment = JoinExisting(), holding = Office,
            rescale = (Office => 0.5, "Office" => 0.7))
        from_config = GEMS.create_setting_layer(Office, Dict("holding" => "Office", "rescale" => Dict("Office" => 0.7),
            "assignment" => Dict("type" => "JoinExisting")), "Office")
        @test from_config.rescale == [(office, 0.7)]
        @test occursin("rescale = [Office => 0.7]", _layer_description(from_config))
    end

    @testset "Layers on a loaded population" begin
        # the settings file gives a spatial layer its coordinates
        data = joinpath(pkgdir(GEMS), "test", "testdata")
        layer = SettingLayer(LayerGym; assignment = SpatialSettings(size = 20, spread = 1.0), participation = 0.2)
        sim = Simulation(population = joinpath(data, "people_muenster.jld2"), settingsfile = joinpath(data, "settings_muenster.jld2"),
                         setting_layers = layer, infected_fraction = 0.0, seed = 1)
        @test validate_plans(population(sim), settingscontainer(sim))
        @test 0.15 < sum(s -> length(individuals(s)), settings(sim, LayerGym)) / length(individuals(sim)) < 0.25
    end

    @testset "Packed layer through a simulation" begin
        # non-workers get offices of five, numbered after the existing ones
        pop = layer_pop(300)
        store, inds = activity_plans(pop), individuals(pop)
        before = [setting_id(i, Office, store) for i in inds]
        add_setting_layers!(pop, SettingLayer(Office; assignment = PackedSettings(size = 5), not_holding = Office); seed = 3)
        after = [setting_id(i, Office, store) for i in inds]
        @test after[1:150] == before[1:150]
        @test sort(unique(after[151:end])) == 51:80

        sim = Simulation(population = pop, infected_fraction = 0.0)
        cntnr = settingscontainer(sim)
        @test validate_plans(pop, cntnr)
        offices = settings(cntnr, Office)
        @test length(offices) == 80
        @test all(length(individuals(offices[k])) == 5 for k in 51:80)
        @test all(length(individuals(offices[k])) == 3 for k in 1:50)
    end
end
