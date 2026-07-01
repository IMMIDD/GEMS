import GEMS: _rand_val, push_infection!, _combine_independent, _min_set, _max_set,
    _health_profile_type, _embedded_health_profile, _has_embedded_health_profile,
    create_progression, create_health_progression, each_infection

@testset "Health Progression" begin

    @testset "SevereHealthProfile" begin
        # no-arg defaults: everything off
        sc = SevereHealthProfile()
        @test sc.hospital_probability == 0.0
        @test sc.severeness_onset_to_hospital_admission == 0
        @test sc.hospital_admission_to_hospital_discharge == 0

        @test_throws ArgumentError SevereHealthProfile(hospital_probability = -0.1)
        @test_throws ArgumentError SevereHealthProfile(hospital_probability = 1.1)

        sc2 = SevereHealthProfile(hospital_probability = 0.2,
            severeness_onset_to_hospital_admission = Poisson(2),
            hospital_admission_to_hospital_discharge = Poisson(10))
        @test sc2.hospital_probability == 0.2
    end

    @testset "CriticalHealthProfile" begin
        # no-arg defaults: everything off
        cc = CriticalHealthProfile()
        @test cc.hospital_probability == 0.0
        @test cc.icu_probability == 0.0
        @test cc.ventilation_probability == 0.0
        @test cc.death_probability == 0.0

        @test_throws ArgumentError CriticalHealthProfile(hospital_probability = -0.1)
        @test_throws ArgumentError CriticalHealthProfile(hospital_probability = 1.1)
        @test_throws ArgumentError CriticalHealthProfile(icu_probability = 1.1)
        @test_throws ArgumentError CriticalHealthProfile(ventilation_probability = -0.1)
        @test_throws ArgumentError CriticalHealthProfile(death_probability = 1.1)
    end

    @testset "calculate_health_profile per tier" begin
        rng = Xoshiro(1)

        # severe-peak infection
        dp_sev = DiseaseProgression(exposure = Int16(0), infectiousness_onset = Int16(1),
            symptom_onset = Int16(2), severeness_onset = Int16(5), severeness_offset = Int16(15),
            recovery = Int16(20))
        inf_sev = InfectionState(Int8(1), Int32(-1), dp_sev)
        sc = SevereHealthProfile(hospital_probability = 1.0,
            severeness_onset_to_hospital_admission = 2, hospital_admission_to_hospital_discharge = 10)
        tl = calculate_health_profile(sc, inf_sev, rng)
        @test tl.hospital_admission == 7  # severeness_onset(5) + 2
        @test tl.hospital_discharge == 17 # + 10
        @test tl.icu_admission == -1
        @test tl.death == -1

        # critical-peak infection: guaranteed hospital + ICU + death, ventilation off
        dp_crit = DiseaseProgression(exposure = Int16(0), infectiousness_onset = Int16(1),
            symptom_onset = Int16(2), severeness_onset = Int16(5), critical_onset = Int16(8),
            critical_offset = Int16(15), severeness_offset = Int16(16), recovery = Int16(20))
        inf_crit = InfectionState(Int8(1), Int32(-1), dp_crit)
        # death is set well after the care ladder resolves, so it doesn't cap those ticks
        # (HealthTimeline's constructor caps ongoing care at death; that's covered separately)
        cc = CriticalHealthProfile(hospital_probability = 1.0, critical_onset_to_hospital_admission = 0,
            icu_probability = 1.0, hospital_admission_to_icu_admission = 0,
            icu_admission_to_icu_discharge = 5, icu_discharge_to_hospital_discharge = 3,
            death_probability = 1.0, critical_onset_to_death = 20)
        tl2 = calculate_health_profile(cc, inf_crit, rng)
        @test tl2.hospital_admission == 8
        @test tl2.icu_admission == 8
        @test tl2.icu_discharge == 13      # icu_admission(8) + 5
        @test tl2.hospital_discharge == 16 # icu_discharge(13) + 3
        @test tl2.death == 28              # critical_onset(8) + 20
        @test tl2.ventilation_admission == -1

        # cascading-off caveat: icu_probability set without hospital_probability is a no-op,
        # since ICU is gated behind a hospital admission that never happens
        cc2 = CriticalHealthProfile(icu_probability = 1.0, hospital_admission_to_icu_admission = 0,
            icu_admission_to_icu_discharge = 5)
        tl3 = calculate_health_profile(cc2, inf_crit, rng)
        @test tl3.hospital_admission == -1
        @test tl3.icu_admission == -1
    end

    @testset "_combine_independent" begin
        empty_tl = HealthTimeline()
        a = HealthTimeline(hospital_admission = 3, hospital_discharge = 10, death = 20, death_pathogen_id = 1)
        b = HealthTimeline(hospital_admission = 5, hospital_discharge = 12, death = 15, death_pathogen_id = 2)

        c = _combine_independent(a, b)
        @test c.hospital_admission == 3  # earliest admission
        @test c.hospital_discharge == 12 # latest discharge
        @test c.death == 15              # earliest death
        @test c.death_pathogen_id == 2   # attributed to whichever infection died first

        # combining with the empty timeline leaves the other side unchanged
        @test _combine_independent(empty_tl, a).hospital_admission == 3
        @test _combine_independent(a, empty_tl).death == 20
    end

    @testset "DefaultHealthProgression folds across a host's infections" begin
        rng = Xoshiro(1)
        cc = CriticalHealthProfile(hospital_probability = 1.0, icu_probability = 1.0, death_probability = 1.0,
            critical_onset_to_hospital_admission = 0, hospital_admission_to_icu_admission = 0,
            icu_admission_to_icu_discharge = 5, icu_discharge_to_hospital_discharge = 3,
            critical_onset_to_death = 9)
        hp = DefaultHealthProgression(critical = cc)

        ind = Individual(id = Int32(1), sex = Int8(1), age = Int8(70))
        reg = InfectionRegistry()
        dp1 = DiseaseProgression(exposure = Int16(0), infectiousness_onset = Int16(1), symptom_onset = Int16(2),
            severeness_onset = Int16(3), critical_onset = Int16(4), critical_offset = Int16(10),
            severeness_offset = Int16(11), recovery = Int16(20))
        dp2 = DiseaseProgression(exposure = Int16(3), infectiousness_onset = Int16(4), symptom_onset = Int16(5),
            severeness_onset = Int16(6), critical_onset = Int16(20), critical_offset = Int16(25),
            severeness_offset = Int16(26), recovery = Int16(30))
        push_infection!(reg, ind, Int8(1), Int32(-1), dp1)
        push_infection!(reg, ind, Int8(2), Int32(-1), dp2)

        tl = calculate_health_progression(ind, reg, hp, Int16(0), rng)
        # earliest admission/death come from pathogen 1's earlier critical_onset (4 vs 20)
        @test tl.hospital_admission == 4
        @test tl.death == 13 # critical_onset(4) + 9
        @test tl.death_pathogen_id == 1
    end

    @testset "compute_health! preserves the realized past" begin
        ind = Individual(id = Int32(1), sex = Int8(1), age = Int8(70))
        reg = InfectionRegistry()
        dp = DiseaseProgression(exposure = Int16(0), infectiousness_onset = Int16(1), symptom_onset = Int16(2),
            severeness_onset = Int16(3), critical_onset = Int16(4), critical_offset = Int16(15),
            severeness_offset = Int16(16), recovery = Int16(20))
        push_infection!(reg, ind, Int8(1), Int32(-1), dp)
        cc = CriticalHealthProfile(hospital_probability = 1.0,
            critical_onset_to_hospital_admission = Poisson(5),
            hospital_admission_to_hospital_discharge = Poisson(20))
        hp = DefaultHealthProgression(critical = cc)

        compute_health!(ind, reg, hp, Int16(4), Xoshiro(1))
        realized_admission = ind.hospital_admission
        @test realized_admission >= 4

        # a later recompute (different rng draw) must not rewrite the already-realized admission
        compute_health!(ind, reg, hp, realized_admission, Xoshiro(99))
        @test ind.hospital_admission == realized_admission
    end

    @testset "Custom HealthProfile static dispatch" begin
        struct WardOnlyCritical <: GEMS.HealthProfile end
        GEMS.calculate_health_profile(::WardOnlyCritical, infection, rng) =
            HealthTimeline(hospital_admission = infection.critical_onset,
                           hospital_discharge = Int16(infection.critical_onset + 5),
                           death_pathogen_id = infection.pathogen_id)

        hp = DefaultHealthProgression(critical = WardOnlyCritical())
        @test isconcretetype(typeof(hp)) # the care type is inferred, not an abstract field

        ind = Individual(id = Int32(1), sex = Int8(1), age = Int8(70))
        reg = InfectionRegistry()
        dp = DiseaseProgression(exposure = Int16(0), infectiousness_onset = Int16(1), symptom_onset = Int16(2),
            severeness_onset = Int16(3), critical_onset = Int16(5), critical_offset = Int16(10),
            severeness_offset = Int16(11), recovery = Int16(20))
        push_infection!(reg, ind, Int8(1), Int32(-1), dp)

        rt = Base.return_types(calculate_health_progression, (typeof(ind), typeof(reg), typeof(hp), Int16, Xoshiro))[1]
        @test rt == HealthTimeline # statically inferred even through the custom Care

        tl = calculate_health_progression(ind, reg, hp, Int16(0), Xoshiro(1))
        @test tl.hospital_admission == 5
    end

    @testset "Custom HealthProgression policy" begin
        struct AlwaysHospitalize <: GEMS.HealthProgression end
        function GEMS.calculate_health_progression(ind, infections, hp::AlwaysHospitalize, tick, rng)
            for s in each_infection(ind, infections)
                s.severeness_onset >= 0 && return HealthTimeline(
                    hospital_admission = s.severeness_onset,
                    hospital_discharge = Int16(s.severeness_onset + 7),
                    death_pathogen_id = s.pathogen_id)
            end
            return HealthTimeline()
        end

        crit = Critical(exposure_to_infectiousness_onset = Poisson(1), infectiousness_onset_to_symptom_onset = Poisson(1),
            symptom_onset_to_severeness_onset = Poisson(1), severeness_onset_to_critical_onset = Poisson(1),
            critical_onset_to_critical_offset = Poisson(3), critical_offset_to_severeness_offset = Poisson(2),
            severeness_offset_to_recovery = Poisson(3))
        p = Pathogen(id = 1, name = "Covid19", progressions = [crit])
        sim = Simulation(pop_size = 3000, pathogens = p, health_progression = AlwaysHospitalize(), seed = 5)
        run!(sim; with_progressbar = false)
        he = dataframe(healthlogger(sim))
        @test count(==(:hospital_admission), he.event) > 0
        @test count(==(:icu_admission), he.event) == 0 # the custom policy never schedules ICU
    end

    @testset "Embedded-care router" begin
        dkw = (exposure_to_infectiousness_onset = Poisson(1), infectiousness_onset_to_symptom_onset = Poisson(1),
            symptom_onset_to_severeness_onset = Poisson(1), severeness_onset_to_critical_onset = Poisson(2),
            critical_onset_to_critical_offset = Poisson(7), critical_offset_to_severeness_offset = Poisson(3),
            severeness_offset_to_recovery = Poisson(4))

        # flat kwargs embed a CriticalHealthProfile directly in the disease progression
        crit = Critical(; dkw..., hospital_probability = 0.9, icu_probability = 0.6)
        @test crit.care isa CriticalHealthProfile
        @test crit.care.hospital_probability == 0.9
        @test crit.care.icu_probability == 0.6
        @test _health_profile_type(Critical) == CriticalHealthProfile
        @test _embedded_health_profile(crit) === crit.care

        # care= object works too, and the two forms are mutually exclusive
        crit_obj = Critical(; dkw..., care = CriticalHealthProfile(hospital_probability = 0.5))
        @test crit_obj.care.hospital_probability == 0.5
        @test_throws ArgumentError Critical(; dkw..., care = CriticalHealthProfile(), hospital_probability = 0.5)

        # unknown embedded parameter errors
        @test_throws ArgumentError Critical(; dkw..., bogus_param = 3)

        # no embedded care at all -> care stays nothing, not silently harvested
        crit_bare = Critical(; dkw...)
        @test isnothing(crit_bare.care)
        @test !_has_embedded_health_profile((progressions = [crit_bare],))
        @test _has_embedded_health_profile((progressions = [crit],))

        # harvest at Simulation build (single pathogen, explicit `pathogens` argument)
        p = Pathogen(id = 1, name = "Covid19", progressions = [crit])
        sim = Simulation(pop_size = 3000, pathogens = p, seed = 1)
        hp = health_progression(sim)
        @test hp.critical.hospital_probability == 0.9
        @test hp.critical.icu_probability == 0.6

        # error: embedded care conflicts with an explicit health_progression
        @test_throws ArgumentError Simulation(pop_size = 1000,
            pathogens = Pathogen(id = 1, name = "Covid19", progressions = [Critical(; dkw..., hospital_probability = 0.9)]),
            health_progression = DefaultHealthProgression(), seed = 1)

        # error: embedded care is only supported for a single pathogen
        p2 = Pathogen(id = 2, name = "Flu", progressions = [Critical(; dkw..., hospital_probability = 0.9)])
        @test_throws ArgumentError Simulation(pop_size = 1000, pathogens = (p, p2), seed = 1)

        # config-side split (a Dict, as parsed from TOML) produces the same result as the flat-kwarg code path
        cfg = Dict(
            "exposure_to_infectiousness_onset" => Dict("distribution" => "Poisson", "parameters" => [1]),
            "infectiousness_onset_to_symptom_onset" => Dict("distribution" => "Poisson", "parameters" => [1]),
            "symptom_onset_to_severeness_onset" => Dict("distribution" => "Poisson", "parameters" => [1]),
            "severeness_onset_to_critical_onset" => Dict("distribution" => "Poisson", "parameters" => [2]),
            "critical_onset_to_critical_offset" => Dict("distribution" => "Poisson", "parameters" => [7]),
            "critical_offset_to_severeness_offset" => Dict("distribution" => "Poisson", "parameters" => [3]),
            "severeness_offset_to_recovery" => Dict("distribution" => "Poisson", "parameters" => [4]),
            "hospital_probability" => 0.9, "icu_probability" => 0.6)
        crit_cfg = create_progression(cfg, "Critical")
        @test crit_cfg.care.hospital_probability == 0.9
        @test crit_cfg.care.icu_probability == 0.6
    end

    @testset "Explicit [HealthProgression] config round-trip" begin
        params = Dict(
            "severe" => Dict(
                "hospital_probability" => 0.1,
                "severeness_onset_to_hospital_admission" => Dict("distribution" => "Poisson", "parameters" => [2]),
                "hospital_admission_to_hospital_discharge" => Dict("distribution" => "Poisson", "parameters" => [10])),
            "critical" => Dict(
                "hospital_probability" => 0.9, "icu_probability" => 0.6, "death_probability" => 0.3,
                "critical_onset_to_hospital_admission" => Dict("distribution" => "Poisson", "parameters" => [1]),
                "hospital_admission_to_hospital_discharge" => Dict("distribution" => "Poisson", "parameters" => [10]),
                "hospital_admission_to_icu_admission" => Dict("distribution" => "Poisson", "parameters" => [1]),
                "icu_admission_to_icu_discharge" => Dict("distribution" => "Poisson", "parameters" => [8]),
                "icu_discharge_to_hospital_discharge" => Dict("distribution" => "Poisson", "parameters" => [5]),
                "critical_onset_to_death" => Dict("distribution" => "Poisson", "parameters" => [7])))
        hp = create_health_progression(Dict("type" => "DefaultHealthProgression", "parameters" => params))
        @test hp isa DefaultHealthProgression
        @test hp.severe.hospital_probability == 0.1
        @test hp.critical.icu_probability == 0.6
    end
end
