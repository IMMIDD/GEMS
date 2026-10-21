import GEMS: setting_type_index, plan_slot, _LayerStreams, _layer_entry_counts, _check_room,
    _draw_entries, _draw_scale, _draw_size

# `n` individuals, two per household; the first half work, three to an office
function layer_pop(n = 12)
    df = DataFrame(id = Int32.(1:n), age = Int8.(mod.(5 .* (1:n), 90)), sex = Int8.(ones(n)),
                   household = Int32.(cld.(1:n, 2)),
                   office = Int32[i <= n ÷ 2 ? cld(i, 3) : -1 for i in 1:n])
    return Population(df)
end

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
        @test JoinExisting() isa GEMS.JoinAssignment
        @test spatial isa GEMS.NewSettingsAssignment

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
        gym = GEMS.declare_setting_type!("LayerTestGym"; char = 'γ')
        gym_layer = SettingLayer(gym; assignment = packed, entries = Poisson(2), scale = Exponential(1))
        @test gym_layer isa SettingLayer{gym}
        @test gym_layer.entries isa Poisson && gym_layer.scale isa Exponential
        @test SettingLayer(gym; assignment = packed, entries = DiscreteUniform(0, 127)).entries isa DiscreteUniform
        @test SettingLayer(gym; assignment = packed, entries = 0, scale = 0).entries === 0
    end

    @testset "Layer validation" begin
        packed = PackedSettings(size = 10)
        layer(T = Office; kwargs...) = SettingLayer(T; assignment = packed, kwargs...)

        # setting types
        @test_throws ArgumentError layer(Workplace)
        @test_throws ArgumentError layer(GlobalSetting)
        @test_throws ArgumentError layer(GEMS.DeclaredSetting)
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
        @test GEMS._name_key("Gym") == GEMS._name_key("Gym") != GEMS._name_key("Gyn")

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
end
