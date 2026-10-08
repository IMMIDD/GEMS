# draws its level from the rng it is given, so tests can check that reads stay reproducible
struct NoisyImmunity <: GEMS.ImmunityProfile end
GEMS.calculate_immunity(::NoisyImmunity, s::ImmunityState, i::Individual, t::Int16, r::Xoshiro) =
    GEMS.immunity_active(s, t) ? Int8(rand(r, 1:100)) : Int8(0)

# draw their infectiousness from the rng they are given, once per infection or once per tick
struct NoisyInfectiousness <: GEMS.InfectiousnessProfile end
GEMS.calculate_infectiousness(::NoisyInfectiousness, s::InfectionState, i::Individual, t::Int16, r::Xoshiro) =
    s.infectiousness_onset <= t < s.recovery ? Int8(rand(r, 1:100)) : Int8(0)
struct DailyNoisyInfectiousness <: GEMS.InfectiousnessProfile end
GEMS.calculate_infectiousness(::DailyNoisyInfectiousness, s::InfectionState, i::Individual, t::Int16, r::Xoshiro) =
    s.infectiousness_onset <= t < s.recovery ? Int8(rand(GEMS.infectiousness_rng!(r, s, t), 1:100)) : Int8(0)

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

    @testset "rand_round" begin
        @test rand_round(3.7, Xoshiro(42)) isa Int64
        @test rand_round(3.7, Xoshiro(42)) == rand_round(3.7, Xoshiro(42))

        results = [rand_round(3.7, Xoshiro(42)) for _ in 1:100]
        @test all(3 .<= results .<= 4)
    end

    @testset "Keyed Immunity RNG" begin
        keyed(seed, host, pid) = GEMS._keyed_immunity_rng(seed, Int32(host), Int8(pid))
        key_draws(seed, host, pid) = rand(keyed(seed, host, pid), 4)

        # same key, same draws; any field changes them
        @test key_draws(1, 5, 1) == key_draws(1, 5, 1)
        @test key_draws(1, 5, 1) != key_draws(2, 5, 1)
        @test key_draws(1, 5, 1) != key_draws(1, 6, 1)
        @test key_draws(1, 5, 1) != key_draws(1, 5, 2)
        # no collision when a unit moves between fields
        @test key_draws(1, 6, 1) != key_draws(2, 5, 1)
        # the same on another thread
        @test fetch(Threads.@spawn key_draws(1, 5, 1)) == key_draws(1, 5, 1)

        st = ImmunityState(Int32(0), Int16(3), Int16(7), Int8(1), Int8(1), Int8(2))
        function natural_draws(state, before)
            r = keyed(1, 5, 1)
            before(r)
            immunity_rng!(r, state, :natural)
            return rand(r, 4)
        end
        plain = natural_draws(st, r -> nothing)
        # natural draws depend neither on draws taken before (Gamma below 1 samples by rejection)
        @test natural_draws(st, r -> rand(r, Gamma(0.8, 200.0), 7)) == plain
        # nor on the vaccine part
        @test natural_draws(st, r -> (immunity_rng!(r, st, :vaccine); rand(r, 3))) == plain
        @test natural_draws(ImmunityState(Int32(0), Int16(3), Int16(9), Int8(1), Int8(1), Int8(3)), r -> nothing) == plain
        # but a reinfection redraws them
        @test natural_draws(ImmunityState(Int32(0), Int16(4), Int16(7), Int8(1), Int8(1), Int8(2)), r -> nothing) != plain

        function vaccine_draws(state)
            r = keyed(1, 5, 1)
            immunity_rng!(r, state, :natural)
            rand(r, Gamma(0.8, 200.0), 7)
            immunity_rng!(r, state, :vaccine)
            return rand(r, 4)
        end
        vplain = vaccine_draws(st)
        # a reinfection does not redraw the vaccine part, a new dose does
        @test vaccine_draws(ImmunityState(Int32(0), Int16(30), Int16(7), Int8(1), Int8(1), Int8(2))) == vplain
        @test vaccine_draws(ImmunityState(Int32(0), Int16(3), Int16(7), Int8(1), Int8(1), Int8(3))) != vplain

        # :host goes back to the stream as passed
        base = key_draws(1, 5, 1)
        r = keyed(1, 5, 1)
        immunity_rng!(r, st, :natural)
        rand(r)
        immunity_rng!(r, st, :host)
        @test rand(r, 4) == base

        @test_throws ArgumentError immunity_rng!(r, st, :other)
        # only the rng passed to a profile can be re-keyed
        @test_throws ArgumentError immunity_rng!(Xoshiro(1), st, :host)
        inf_st = InfectionState(Int8(1), Int32(1), DiseaseProgression(exposure = Int16(0), infectiousness_onset = Int16(1), recovery = Int16(5)))
        @test_throws ArgumentError infectiousness_rng!(Xoshiro(1), inf_st, Int16(2))

        # resetting and re-keying allocate nothing
        rekey(state) = (immunity_rng!(keyed(1, 5, 1), state, :vaccine); nothing)
        rekey(st)
        @test (@allocated rekey(st)) == 0

        # a profile drawing from its rng reads the same level every time, leaving the sim's streams alone
        function noisy_sim()
            p = Pathogen(id = 1, name = "Noisy", immunity_profile = NoisyImmunity())
            s = Simulation(pop_size = 100, infected_fraction = 0.0, pathogens = (p,), seed = 7)
            ind = individuals(s)[1]
            GEMS.push_immunity!(GEMS.immunity_registry(s, ind), ind, Int8(1),
                GEMS.IMMUNITY_SOURCE_NATURAL, Int16(0), GEMS.DEFAULT_VACCINE_ID)
            return s, ind
        end
        s, ind = noisy_sim()
        before = copy(rng(s))
        lvl = immunity_level(ind, s, Int8(1), Int16(5))
        @test 1 <= lvl <= 100
        @test immunity_level(ind, s, Int8(1), Int16(5)) == lvl
        @test rng(s) == before
        s2, ind2 = noisy_sim()
        @test immunity_level(ind2, s2, Int8(1), Int16(5)) == lvl
    end

    @testset "Keyed Infectiousness RNG" begin
        # infectiousness of one host over ticks 1-6 of an infection from tick 0, and whether the sim's rng moved
        function infectiousness_path(profile)
            p = Pathogen(id = 1, name = "Noisy", infectiousness_profile = profile,
                progressions = [Asymptomatic(exposure_to_infectiousness_onset = 0, infectiousness_onset_to_recovery = 10)],
                progression_assignment = RandomProgressionAssignment([Asymptomatic]))
            s = Simulation(pop_size = 100, infected_fraction = 0.0, pathogens = (p,), seed = 7)
            ind = individuals(s)[1]
            infect!(ind, Int16(0), p, sim = s, rng = Xoshiro(1))
            GEMS.flush_pending_infections!(s)
            before = copy(rng(s))
            path = map(Int16.(1:6)) do t
                GEMS.update_individual!(ind, t, s)
                infectiousness(ind, s, Int8(1))
            end
            return path, rng(s) == before
        end

        # drawn once per infection: the same every tick, reproducible, and the sim's rng is left alone
        path, untouched = infectiousness_path(NoisyInfectiousness())
        @test all(==(path[1]), path) && 1 <= path[1] <= 100
        @test untouched
        @test infectiousness_path(NoisyInfectiousness())[1] == path

        # re-keyed per tick: varies over the infection, still reproducible
        daily, _ = infectiousness_path(DailyNoisyInfectiousness())
        @test length(unique(daily)) > 1
        @test infectiousness_path(DailyNoisyInfectiousness())[1] == daily
    end
end
