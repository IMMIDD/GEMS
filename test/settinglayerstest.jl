import GEMS: setting_type_index, setting_type_from_index, plan_slot, plan_slots, plan_add!,
    plan_remove!, setting_type_of, setting_id, entry_active, entry_active!, entry_scale,
    declare_setting_type!, DeclaredSetting, DEFAULT_SETTING_ID, DEFAULT_MEMBER_INDEX, NewSettingsAssignment, JoinAssignment,
    _membership_bit, _mask_slot, _type_scale_bound, _name_key,
    _LayerStreams, _layer_entry_counts, _check_room, _draw_entries, _draw_scale, _draw_size,
    _PlanAdditions, _merge_additions!, _max_setting_id, _setting_id,
    setting_ids, validate_plans, settingscontainer, settings

# `n` individuals, two per household; the first half work, three to an office
function layer_pop(n = 12)
    df = DataFrame(id = Int32.(1:n), age = Int8.(mod.(5 .* (1:n), 90)), sex = Int8.(ones(n)),
                   household = Int32.(cld.(1:n, 2)),
                   office = Int32[i <= n ÷ 2 ? cld(i, 3) : -1 for i in 1:n])
    return Population(df)
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
        @test _draw_scale(rng, 2.0) === Float16(2)
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
        layered(layers...; seed = 1) = add_setting_layers!(layer_pop(1000), layers...; seed = seed)
        gym_ids(pop) = [setting_id(i, LayerGym, activity_plans(pop)) for i in individuals(pop)]
        held_ids(pop) = [setting_ids(i, LayerGym, activity_plans(pop)) for i in individuals(pop)]

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
