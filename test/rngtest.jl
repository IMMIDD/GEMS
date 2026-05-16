@testset "RNG" begin

    @testset "set_global_seed" begin
        set_global_seed(42)
        r1 = rand()
        set_global_seed(42)
        r2 = rand()
        @test r1 == r2
    end

    @testset "gems_rand" begin
        @test gems_rand(Xoshiro(42)) isa Float64
        @test gems_rand(Xoshiro(42)) == gems_rand(Xoshiro(42))
        @test gems_rand(Xoshiro(42), 1:10) in 1:10

        sim = Simulation(pop_size = 100, seed = 42)
        @test gems_rand(sim) isa Float64
        @test gems_rand(sim, 1:10) in 1:10

        @test_throws ArgumentError gems_rand(GEMS.default_gems_rng())
        @test_logs (:warn,) gems_rand()
    end

    @testset "gems_sample" begin
        v = collect(1:5)
        @test gems_sample(Xoshiro(42), v) in v
        @test gems_sample(Xoshiro(42), v) == gems_sample(Xoshiro(42), v)

        sim = Simulation(pop_size = 100, seed = 42)
        @test gems_sample(sim, v) in v

        @test_throws ArgumentError gems_sample(GEMS.default_gems_rng(), v)
        @test_logs (:warn,) gems_sample(v)
    end

    @testset "gems_sample!" begin
        v = collect(1:5)
        buf = zeros(Int, 2)

        gems_sample!(Xoshiro(42), v, buf)
        @test all(x -> x in v, buf)

        buf1 = zeros(Int, 2); gems_sample!(Xoshiro(42), v, buf1)
        buf2 = zeros(Int, 2); gems_sample!(Xoshiro(42), v, buf2)
        @test buf1 == buf2

        sim = Simulation(pop_size = 100, seed = 42)
        gems_sample!(sim, v, buf)
        @test all(x -> x in v, buf)

        @test_throws ArgumentError gems_sample!(GEMS.default_gems_rng(), v, buf)
        @test_logs (:warn,) gems_sample!(v, zeros(Int, 2))
    end

    @testset "gems_shuffle!" begin
        v = collect(1:5)

        v1 = copy(v); gems_shuffle!(Xoshiro(42), v1)
        @test Set(v1) == Set(v)

        v2 = copy(v); gems_shuffle!(Xoshiro(42), v2)
        @test v1 == v2

        sim = Simulation(pop_size = 100, seed = 42)
        v_copy = copy(v)
        gems_shuffle!(sim, v_copy)
        @test Set(v_copy) == Set(v)

        @test_throws ArgumentError gems_shuffle!(GEMS.default_gems_rng(), copy(v))
        @test_logs (:warn,) gems_shuffle!(copy(v))
    end

    @testset "gems_shuffle" begin
        v = collect(1:5)
        @test gems_shuffle(Xoshiro(42), v) isa Vector{Int}
        @test Set(gems_shuffle(Xoshiro(42), v)) == Set(v)
        @test gems_shuffle(Xoshiro(42), v) == gems_shuffle(Xoshiro(42), v)

        sim = Simulation(pop_size = 100, seed = 42)
        @test Set(gems_shuffle(sim, v)) == Set(v)

        @test_throws ArgumentError gems_shuffle(GEMS.default_gems_rng(), v)
        @test_logs (:warn,) gems_shuffle(v)
    end

    @testset "gems_randn" begin
        @test gems_randn(Xoshiro(42)) isa Float64
        @test gems_randn(Xoshiro(42)) == gems_randn(Xoshiro(42))

        sim = Simulation(pop_size = 100, seed = 42)
        @test gems_randn(sim) isa Float64

        @test_throws ArgumentError gems_randn(GEMS.default_gems_rng())
        @test_logs (:warn,) gems_randn()
    end

end
