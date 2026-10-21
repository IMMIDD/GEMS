import GEMS: setting_type_index

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
end
