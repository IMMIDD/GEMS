@testset "Vaccines" begin

    v = Vaccine(id=1, name="Antitest", target_pathogen_id=Int8(1))

    @testset "Getter" begin
        @test id(v) == 1
        @test name(v) == "Antitest"
        @test typeof(logger(v)) == VaccinationLogger
        @test peak(v) == Int8(100)
        @test severity_peak(v) == Int8(100)
        @test isnothing(buildup_duration(v))
    end

    @testset "Peaks and buildup" begin
        # defaults: full peaks, the pathogen's buildup
        @test v.peak == Int8(100) && v.severity_peak == Int8(100) && isnothing(v.buildup_duration)
        # severity_peak defaults to peak
        partial = Vaccine(id=2, name="Partial", target_pathogen_id=Int8(1), peak=50)
        @test partial.peak == Int8(50) && partial.severity_peak == Int8(50)
        flu = Vaccine(id=3, name="Flu", target_pathogen_id=Int8(1), peak=50, severity_peak=85, buildup_duration=14)
        @test flu.severity_peak == Int8(85) && flu.buildup_duration === Int16(14)

        @test_throws ArgumentError Vaccine(id=4, name="X", target_pathogen_id=Int8(1), peak=-1)
        @test_throws ArgumentError Vaccine(id=4, name="X", target_pathogen_id=Int8(1), peak=101)
        @test_throws ArgumentError Vaccine(id=4, name="X", target_pathogen_id=Int8(1), severity_peak=101)
        @test_throws ArgumentError Vaccine(id=4, name="X", target_pathogen_id=Int8(1), buildup_duration=-1)
        # only severity_peak set: the defaulted peak of 100 exceeds it, and the message says so
        err = try
            Vaccine(id=4, name="X", target_pathogen_id=Int8(1), severity_peak=85)
        catch e
            e
        end
        @test err isa ArgumentError && occursin("default 100", err.msg)

        # the old positional form keeps working and converts
        old = Vaccine(1, "Old", 1, VaccinationLogger())
        @test old.id === Int8(1) && old.peak == Int8(100) && isnothing(old.buildup_duration)
    end

    @testset "Vaccinate Individuals" begin
        i = Individual(id = 1, sex = 0, age = 31, household=1)
        reg = ImmunityRegistry()
        pid = target_pathogen_id(v)

        @test number_of_vaccinations(i, reg, pid) == 0
        @test !isvaccinated(i, reg, pid)
        GEMS._vaccinate!(i, reg, v, Int16(42))
        @test isvaccinated(i, reg, pid)
        @test vaccine_id(i, reg, pid) == 1
        @test vaccination_tick(i, reg, pid) == Int16(42)
        @test number_of_vaccinations(i, reg, pid) == 1

        # the deprecated registry variant still vaccinates, but warns
        @test_logs (:warn, r"deprecated") vaccinate!(i, reg, v, Int16(43))
        @test number_of_vaccinations(i, reg, pid) == 2

        # sim wrappers route to the correct ImmunityRegistry shard
        sim_v = Simulation()
        i_v = Individual(id=1, sex=0, age=30)
        vaccinate!(i_v, sim_v, v, Int16(10))
        @test isvaccinated(i_v, sim_v, pid)
        @test vaccine_id(i_v, sim_v, pid) == 1
        @test vaccination_tick(i_v, sim_v, pid) == Int16(10)
        @test number_of_vaccinations(i_v, sim_v, pid) == 1

        # vaccination does not flag for the disease update; the level is computed on read
        k = findfirst(!, sim_v.active_individuals)
        member = individuals(sim_v)[k]
        vaccinate!(member, sim_v, v, Int16(10))
        @test !sim_v.active_individuals[k]
        @test immunity_level(member, sim_v, pid, Int16(10)) == Int8(100)
    end

    @testset "Registration" begin
        s = Simulation(pop_size = 100)
        ind = individuals(s)[1]
        pid = Int8(1)
        registered(sim, p, vid) = sim.vaccine_registered[p] & (UInt128(1) << (vid - 1)) != 0

        # the record: defaults, built from a vaccine, checked
        @test GEMS.VaccineProtection() == GEMS.VaccineProtection(100, 100, -1)
        @test GEMS.VaccineProtection(Vaccine(id=1, name="B", target_pathogen_id=pid, buildup_duration=14)).buildup_duration == Int16(14)
        @test_throws ArgumentError GEMS.VaccineProtection(90, 80, -1)
        @test_throws ArgumentError GEMS.VaccineProtection(100, 100, -2)

        # the first dose registers the vaccine; an identical vaccine object passes
        v1 = Vaccine(id=1, name="V1", target_pathogen_id=pid)
        vaccinate!(ind, s, v1, Int16(0))
        @test registered(s, pid, 1)
        @test s.vaccine_protection[1, pid] == GEMS.VaccineProtection()
        vaccinate!(ind, s, Vaccine(id=1, name="V1 again", target_pathogen_id=pid), Int16(1))
        # another vaccine under a registered id conflicts instead of overwriting
        @test_throws ArgumentError vaccinate!(ind, s, Vaccine(id=1, name="V1b", target_pathogen_id=pid, peak=60), Int16(2))
        @test s.vaccine_protection[1, pid] == GEMS.VaccineProtection()
        # values are frozen at the first dose, and a mutated vaccine is checked again
        v1.peak = Int8(80)
        @test_throws ArgumentError vaccinate!(ind, s, v1, Int16(3))
        bad = Vaccine(id=2, name="Bad", target_pathogen_id=pid)
        bad.severity_peak = Int8(50)
        @test_throws ArgumentError vaccinate!(ind, s, bad, Int16(3))
        @test !registered(s, pid, 2)
        # ids must be at least 1 and target a pathogen of the simulation
        @test_throws ArgumentError vaccinate!(ind, s, Vaccine(id=0, name="Zero", target_pathogen_id=pid), Int16(0))
        @test_throws ArgumentError vaccinate!(ind, s, Vaccine(id=3, name="Elsewhere", target_pathogen_id=Int8(5)), Int16(0))

        # registration doesn't log, whatever the vaccine sets
        @test_logs vaccinate!(ind, s, Vaccine(id=4, name="Flu", target_pathogen_id=pid, peak=50, buildup_duration=14), Int16(0))

        # the same vaccine id for two pathogens with non-contiguous ids
        a = Pathogen(id = 3, name = "A", immunity_profile = NoImmunity())
        b = Pathogen(id = 7, name = "B", immunity_profile = NoImmunity())
        s3 = Simulation(pop_size = 100, pathogens = (a, b), start_condition = InfectedFraction(fraction = 0.01, pathogen = "all"))
        ind3 = individuals(s3)[1]
        vaccinate!(ind3, s3, Vaccine(id=1, name="ForA", target_pathogen_id=Int8(3), peak=60), Int16(0))
        vaccinate!(ind3, s3, Vaccine(id=1, name="ForB", target_pathogen_id=Int8(7), peak=80), Int16(0))
        @test s3.vaccine_protection[1, 3].peak == Int8(60)
        @test s3.vaccine_protection[1, 7].peak == Int8(80)

        # the deprecated path registers nothing and warns once per vaccine about ignored peaks
        reg = ImmunityRegistry()
        i_dep = Individual(id=1, sex=0, age=30)
        dep = Vaccine(id=9, name="Dep", target_pathogen_id=pid, peak=70)
        @test_logs (:warn, r"deprecated") (:warn, r"ignores the peaks") begin
            vaccinate!(i_dep, reg, dep, Int16(0))
            vaccinate!(i_dep, reg, dep, Int16(1))
        end
        @test_logs (:warn, r"deprecated") vaccinate!(i_dep, reg, Vaccine(id=0, name="Zero", target_pathogen_id=pid), Int16(2))

        # reset! clears the registrations, so a sweep can reuse an id with other values
        reset!(s)
        @test all(==(UInt128(0)), s.vaccine_registered)
        @test all(==(GEMS.VaccineProtection()), s.vaccine_protection)
        vaccinate!(individuals(s)[1], s, Vaccine(id=1, name="Sweep", target_pathogen_id=pid, peak=40), Int16(0))
        @test s.vaccine_protection[1, pid].peak == Int8(40)
    end

    @testset "Peaks" begin
        pid = Int8(1)
        sim_with(profile) = Simulation(pop_size = 100, infected_fraction = 0.0,
            pathogens = (Pathogen(id = 1, name = "P", immunity_profile = profile),))
        level(sim, ind, t) = immunity_level(ind, sim, pid, Int16(t))

        # FullImmunity: default vaccines give 100 from the dose; a partial one ramps and stays at its peak
        s = sim_with(FullImmunity())
        a, b = individuals(s)[1:2]
        vaccinate!(a, s, Vaccine(id=1, name="Full", target_pathogen_id=pid), Int16(0))
        @test level(s, a, 0) == Int8(100)
        partial = Vaccine(id=2, name="Partial", target_pathogen_id=pid, peak=60, buildup_duration=10)
        vaccinate!(b, s, partial, Int16(0))
        @test level(s, b, 5) == Int8(30)
        @test all(t -> level(s, b, t) == Int8(60), 10:400)
        # a booster keeps the level during its buildup
        vaccinate!(b, s, partial, Int16(100))
        @test all(t -> level(s, b, t) == Int8(60), 100:120)

        # waning profiles: natural immunity starts at natural_peak, each product at its own peak
        for profile in (ExponentialWaning(halflife = 180.0, natural_peak = 80), SigmoidalWaning(halflife = 180.0, natural_peak = 80))
            s = sim_with(profile)
            a, b, c = individuals(s)[1:3]
            GEMS.push_immunity!(immunity_registry(s, a), a, pid, GEMS.IMMUNITY_SOURCE_NATURAL, Int16(0), GEMS.DEFAULT_VACCINE_ID)
            vaccinate!(b, s, Vaccine(id=1, name="Strong", target_pathogen_id=pid, peak=90), Int16(0))
            vaccinate!(c, s, Vaccine(id=2, name="Weak", target_pathogen_id=pid, peak=50), Int16(0))
            @test (level(s, a, 0), level(s, b, 0), level(s, c, 0)) == (80, 90, 50)
            @test (level(s, a, 180), level(s, b, 180), level(s, c, 180)) == (40, 45, 25)
        end

        # product switches: the previous dose is read with the current product's peak
        s = sim_with(ExponentialWaning(halflife = 180.0, vaccine_buildup_duration = 14))
        a, b = individuals(s)[1:2]
        # weak -> strong: dose 2 (peak 70) on day 21 skips its buildup at ~70 * w(7)
        vaccinate!(a, s, Vaccine(id=1, name="Dose 1", target_pathogen_id=pid, peak=30), Int16(0))
        vaccinate!(a, s, Vaccine(id=2, name="Dose 2", target_pathogen_id=pid, peak=70), Int16(21))
        @test level(s, a, 21) == Int8(68)
        # strong -> weak: a booster below the remaining protection lowers it at the dose
        vaccinate!(b, s, Vaccine(id=3, name="Strong", target_pathogen_id=pid, peak=90), Int16(0))
        before = level(s, b, 180)
        vaccinate!(b, s, Vaccine(id=4, name="Weak", target_pathogen_id=pid, peak=40), Int16(180))
        @test level(s, b, 180) < before
        @test level(s, b, 194) == Int8(40)
    end

end
