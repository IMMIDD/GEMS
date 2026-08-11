import GEMS: _rand_val, push_infection!, _merge_care, _merge_episode, _combine_outcome, _cap_care, _min_set, _max_set,
    _health_profile_type, _embedded_health_profile, _has_embedded_health_profile,
    create_progression, create_health_progression, create_health_profile,
    determine_health_progression, each_infection, progression_index, get_infection_state,
    calculate_progression, _harvest_legacy_health_progression, _has_legacy_category,
    _is_legacy_critical, _normalize_legacy_pathogen!

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
        @test cc.hospital_to_icu_probability == 0.0
        @test cc.icu_to_ventilation_probability == 0.0
        @test cc.death_probability == 0.0

        @test_throws ArgumentError CriticalHealthProfile(hospital_probability = -0.1)
        @test_throws ArgumentError CriticalHealthProfile(hospital_probability = 1.1)
        @test_throws ArgumentError CriticalHealthProfile(hospital_to_icu_probability = 1.1)
        @test_throws ArgumentError CriticalHealthProfile(icu_to_ventilation_probability = -0.1)
        @test_throws ArgumentError CriticalHealthProfile(death_probability = 1.1)
    end

    @testset "calculate_health_profile per tier" begin
        rng = Xoshiro(1)
        ind = Individual(id = Int32(1), sex = Int8(1), age = Int8(70))

        # severe-peak infection
        dp_sev = DiseaseProgression(exposure = Int16(0), infectiousness_onset = Int16(1),
            symptom_onset = Int16(2), severeness_onset = Int16(5), severeness_offset = Int16(15),
            recovery = Int16(20))
        inf_sev = InfectionState(Int8(1), Int32(-1), dp_sev)
        sc = SevereHealthProfile(hospital_probability = 1.0,
            severeness_onset_to_hospital_admission = 2, hospital_admission_to_hospital_discharge = 10)
        care_sev, outcome_sev = calculate_health_profile(sc, ind, inf_sev, rng)
        @test care_sev.hospital_admission == 7
        @test care_sev.hospital_discharge == 17
        @test care_sev.icu_admission == -1
        @test outcome_sev.death == -1

        # critical-peak infection: guaranteed hospital + ICU + death, ventilation off
        dp_crit = DiseaseProgression(exposure = Int16(0), infectiousness_onset = Int16(1),
            symptom_onset = Int16(2), severeness_onset = Int16(5), critical_onset = Int16(8),
            critical_offset = Int16(15), severeness_offset = Int16(16), recovery = Int16(20))
        inf_crit = InfectionState(Int8(1), Int32(-1), dp_crit)
        # death is set well after the care ladder resolves, so it doesn't cap those ticks
        # (_cap_care caps ongoing care at death; that's covered separately)
        cc = CriticalHealthProfile(hospital_probability = 1.0, critical_onset_to_hospital_admission = 0,
            hospital_to_icu_probability = 1.0, hospital_admission_to_icu_admission = 0,
            icu_admission_to_icu_discharge = 5, icu_discharge_to_hospital_discharge = 3,
            death_probability = 1.0, critical_onset_to_death = 20)
        care2, outcome2 = calculate_health_profile(cc, ind, inf_crit, rng)
        @test care2.hospital_admission == 8
        @test care2.icu_admission == 8
        @test care2.icu_discharge == 13
        @test care2.hospital_discharge == 16
        @test outcome2.death == 28
        @test care2.ventilation_admission == -1

        # full critical ladder: guaranteed ventilation nests inside ICU which nests inside the ward.
        # discharges chain inward-out, so ventilation ends first, then ICU, then hospital.
        cc_vent = CriticalHealthProfile(hospital_probability = 1.0, critical_onset_to_hospital_admission = 0,
            hospital_to_icu_probability = 1.0, hospital_admission_to_icu_admission = 0,
            icu_to_ventilation_probability = 1.0, icu_admission_to_ventilation_admission = 0,
            ventilation_admission_to_ventilation_discharge = 4, ventilation_discharge_to_icu_discharge = 2,
            icu_discharge_to_hospital_discharge = 3)
        care_vent, outcome_vent = calculate_health_profile(cc_vent, ind, inf_crit, rng)
        @test care_vent.ventilation_admission == 8
        @test care_vent.ventilation_discharge == 12
        @test care_vent.icu_discharge == 14        # 2 days of ICU after ventilation ends
        @test care_vent.hospital_discharge == 17   # 3 days of ward after ICU ends
        @test outcome_vent.death == -1             # death is off for this profile

        # cascading-off caveat: hospital_to_icu_probability set without hospital_probability is a no-op,
        # since ICU is gated behind a hospital admission that never happens
        cc2 = CriticalHealthProfile(hospital_to_icu_probability = 1.0, hospital_admission_to_icu_admission = 0,
            icu_admission_to_icu_discharge = 5)
        care3, _ = calculate_health_profile(cc2, ind, inf_crit, rng)
        @test care3.hospital_admission == -1
        @test care3.icu_admission == -1
    end

    @testset "_merge_care / _combine_outcome" begin
        empty_care = CareTimeline()
        empty_outcome = HealthOutcome()

        outcome_a = HealthOutcome(death = 20, death_pathogen_id = 1)
        outcome_b = HealthOutcome(death = 15, death_pathogen_id = 2)

        outcome_c = _combine_outcome(outcome_a, outcome_b)
        @test outcome_c.death == 15              # earliest death
        @test outcome_c.death_pathogen_id == 2   # attributed to whichever infection died first
        @test _combine_outcome(outcome_a, empty_outcome).death == 20

        # union of two contributions: earliest admission, latest discharge
        committed = CareTimeline(hospital_admission = 3, hospital_discharge = 10)
        added = CareTimeline(hospital_admission = 5, hospital_discharge = 12)
        merged = _merge_care(committed, added, Int16(6))
        @test merged.hospital_admission == 3
        @test merged.hospital_discharge == 12

        # merging into an empty committed timeline just takes the contribution
        @test _merge_care(empty_care, added, Int16(0)).hospital_admission == 5
        # ... and a contribution of nothing leaves the committed timeline alone
        @test _merge_care(committed, empty_care, Int16(6)).hospital_admission == 3
    end

    @testset "_cap_care" begin
        care = CareTimeline(hospital_admission = 5, hospital_discharge = 20,
            icu_admission = 8, icu_discharge = 15)

        # no scheduled death -> unchanged
        @test _cap_care(care, HealthOutcome()) == care

        # death after discharge -> no effect
        @test _cap_care(care, HealthOutcome(death = 25)) == care

        # death mid-ICU-stay -> both discharges pulled back to the death tick
        capped = _cap_care(care, HealthOutcome(death = 12))
        @test capped.icu_discharge == 12
        @test capped.hospital_discharge == 12
        @test capped.hospital_admission == 5 # admission itself untouched

        # death at or before admission -> the episode is dropped, not clamped
        dropped = _cap_care(care, HealthOutcome(death = 5))
        @test dropped.hospital_admission == -1
        @test dropped.hospital_discharge == -1
        @test dropped.icu_admission == -1
        @test dropped.icu_discharge == -1
    end

    @testset "show" begin
        # a full care timeline prints every realized part of the ladder
        ct = CareTimeline(hospital_admission = 1, hospital_discharge = 40, icu_admission = 5,
            icu_discharge = 30, ventilation_admission = 8, ventilation_discharge = 20)
        out = @capture_out show(ct)
        @test occursin("hospital_admission", out)
        @test occursin("ventilation_admission", out)
        @test occursin("hospital_discharge", out)

        # an empty timeline prints only the header, no event rows
        empty_out = @capture_out show(CareTimeline())
        @test occursin("Care Timeline", empty_out)
        @test !occursin("hospital_admission", empty_out)

        # the outcome distinguishes a scheduled death from survival
        @test occursin("death", @capture_out show(HealthOutcome(death = 5, death_pathogen_id = 2)))
        @test occursin("alive", @capture_out show(HealthOutcome()))
    end

    @testset "DefaultHealthProgression folds across a host's infections" begin
        rng = Xoshiro(1)
        cc = CriticalHealthProfile(hospital_probability = 1.0, hospital_to_icu_probability = 1.0, death_probability = 1.0,
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
        # each infection folds into the host timeline as it arrives
        s1 = push_infection!(reg, ind, Int8(1), Int32(-1), dp1)
        compute_health!(ind, reg, hp, s1, Int16(0), rng)
        s2 = push_infection!(reg, ind, Int8(2), Int32(-1), dp2)
        compute_health!(ind, reg, hp, s2, Int16(3), rng)

        # earliest admission/death come from pathogen 1's earlier critical_onset (4 vs 20)
        @test ind.hospital_admission == 4
        @test ind.death == 13
        @test ind.killing_pathogen_id == 1
        @test ind.hospital_discharge == 13   # capped at the scheduled death
    end

    @testset "compute_health! preserves the realized past" begin
        ind = Individual(id = Int32(1), sex = Int8(1), age = Int8(70))
        reg = InfectionRegistry()
        cc = CriticalHealthProfile(hospital_probability = 1.0,
            critical_onset_to_hospital_admission = 1,
            hospital_admission_to_hospital_discharge = 20)
        hp = DefaultHealthProgression(critical = cc)

        dp1 = DiseaseProgression(exposure = Int16(0), infectiousness_onset = Int16(1), symptom_onset = Int16(2),
            severeness_onset = Int16(3), critical_onset = Int16(4), critical_offset = Int16(15),
            severeness_offset = Int16(16), recovery = Int16(60))
        s1 = push_infection!(reg, ind, Int8(1), Int32(-1), dp1)
        compute_health!(ind, reg, hp, s1, Int16(4), Xoshiro(1))
        @test ind.hospital_admission == 5    # critical_onset 4 + 1
        @test ind.hospital_discharge == 25

        # a second infection arriving mid-stay must not rewrite the already-realized admission
        dp2 = DiseaseProgression(exposure = Int16(10), infectiousness_onset = Int16(11), symptom_onset = Int16(12),
            severeness_onset = Int16(13), critical_onset = Int16(30), critical_offset = Int16(40),
            severeness_offset = Int16(41), recovery = Int16(70))
        s2 = push_infection!(reg, ind, Int8(2), Int32(-1), dp2)
        compute_health!(ind, reg, hp, s2, Int16(10), Xoshiro(99))
        @test ind.hospital_admission == 5    # realized admission kept
        @test ind.hospital_discharge == 51   # ongoing stay extended to the later discharge (30 + 1 + 20)
    end

    @testset "recompute after a completed episode starts fresh" begin
        cand = CareTimeline(hospital_admission = Int16(105), hospital_discharge = Int16(115))

        # a COMPLETED past episode [10, 20] must not swallow a disjoint later one (re-infection)
        closed = CareTimeline(hospital_admission = Int16(10), hospital_discharge = Int16(20))
        fresh = _merge_care(closed, cand, Int16(100))
        @test fresh.hospital_admission == 105        # new episode scheduled fresh, not merged into [10, ...]
        @test fresh.hospital_discharge == 115

        # an ONGOING episode [10, 200] at tick 100 is still preserved and extended
        open = CareTimeline(hospital_admission = Int16(10), hospital_discharge = Int16(200))
        kept = _merge_care(open, cand, Int16(100))
        @test kept.hospital_admission == 10          # realized admission kept
        @test kept.hospital_discharge == 200         # extended to max(200, 115)
    end

    @testset "Custom HealthProfile static dispatch" begin
        ind = Individual(id = Int32(1), sex = Int8(1), age = Int8(70))
        struct WardOnlyCritical <: GEMS.HealthProfile end
        GEMS.calculate_health_profile(::WardOnlyCritical, individual, infection, rng) =
            CareTimeline(hospital_admission = infection.critical_onset,
                        hospital_discharge = Int16(infection.critical_onset + 5)),
            HealthOutcome(death_pathogen_id = infection.pathogen_id)

        hp = DefaultHealthProgression(critical = WardOnlyCritical())
        @test isconcretetype(typeof(hp)) # the care type is inferred, not an abstract field

        ind = Individual(id = Int32(1), sex = Int8(1), age = Int8(70))
        reg = InfectionRegistry()
        dp = DiseaseProgression(exposure = Int16(0), infectiousness_onset = Int16(1), symptom_onset = Int16(2),
            severeness_onset = Int16(3), critical_onset = Int16(5), critical_offset = Int16(10),
            severeness_offset = Int16(11), recovery = Int16(20))
        s = push_infection!(reg, ind, Int8(1), Int32(-1), dp)
        ctx = HealthContext(CareTimeline(), HealthOutcome(), s, Int16(0))

        rt = Base.return_types(calculate_health_progression, (typeof(ind), typeof(reg), typeof(hp), HealthContext, Xoshiro))[1]
        @test rt == Tuple{CareTimeline, HealthOutcome} # statically inferred even through the custom profile

        care, _ = calculate_health_progression(ind, reg, hp, ctx, Xoshiro(1))
        @test care.hospital_admission == 5
    end

    @testset "Custom HealthProgression policy" begin
        struct AlwaysHospitalize <: GEMS.HealthProgression end
        function GEMS.calculate_health_progression(ind::Individual, infections::InfectionRegistry,
                hp::AlwaysHospitalize, ctx::HealthContext, rng::Xoshiro)
            s = ctx.new_infection
            s.severeness_onset < 0 && return ctx.committed_care, ctx.committed_outcome
            added = CareTimeline(hospital_admission = s.severeness_onset,
                    hospital_discharge = Int16(s.severeness_onset + 7))
            # a custom policy folds its contribution in itself; _merge_care keeps an open episode's
            # already-logged admission, which the forward-plan contract requires
            return _merge_care(ctx.committed_care, added, ctx.tick), ctx.committed_outcome
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

    @testset "a co-infection with no care demand does not change incidence" begin
        # infection A reaches critical; its window (5..15) has long closed by the time B arrives
        dpA = DiseaseProgression(exposure = Int16(0), infectiousness_onset = Int16(1), symptom_onset = Int16(2),
            severeness_onset = Int16(3), critical_onset = Int16(5), critical_offset = Int16(15),
            severeness_offset = Int16(16), recovery = Int16(100))
        # infection B never reaches severe, so select_health_profile returns nothing for it and it
        # demands no care at all -- it must therefore not perturb A's contribution in any way
        dpB = DiseaseProgression(exposure = Int16(40), infectiousness_onset = Int16(41), symptom_onset = Int16(42),
            severeness_onset = Int16(-1), critical_onset = Int16(-1), critical_offset = Int16(-1),
            severeness_offset = Int16(-1), recovery = Int16(80))
        hp = DefaultHealthProgression(critical = CriticalHealthProfile(hospital_probability = 0.4,
            critical_onset_to_hospital_admission = 1, hospital_admission_to_hospital_discharge = 3))

        function stays(n, coinfect::Bool)
            rng = Xoshiro(1234); episodes = 0
            for k in 1:n
                ind = Individual(id = Int32(k), sex = Int8(1), age = Int8(70))
                reg = InfectionRegistry()
                sA = push_infection!(reg, ind, Int8(1), Int32(-1), dpA)
                compute_health!(ind, reg, hp, sA, Int16(0), rng)
                ind.hospital_admission >= 0 && (episodes += 1)
                if coinfect
                    before = ind.hospital_admission
                    sB = push_infection!(reg, ind, Int8(2), Int32(-1), dpB)
                    compute_health!(ind, reg, hp, sB, Int16(40), rng)
                    # a second, distinct stay appearing at/after the recompute tick
                    (ind.hospital_admission >= 40 && ind.hospital_admission != before) && (episodes += 1)
                end
            end
            return episodes / n
        end

        n = 20_000
        solo = stays(n, false)
        @test isapprox(solo, 0.4, atol = 0.02)     # matches the nominal hospital_probability
        # exactly equal, not merely close: the null co-infection draws nothing, so it cannot
        # consume rng or re-decide A. Previously this doubled to ~0.8.
        @test stays(n, true) == solo
    end

    @testset "host health invariants hold over a two-pathogen run" begin
        dkw = (exposure_to_infectiousness_onset = Poisson(1), infectiousness_onset_to_symptom_onset = Poisson(1),
            symptom_onset_to_severeness_onset = Poisson(1), severeness_onset_to_critical_onset = Poisson(2),
            critical_onset_to_critical_offset = Poisson(5), critical_offset_to_severeness_offset = Poisson(3),
            severeness_offset_to_recovery = Poisson(10))
        crit = Critical(; dkw...)
        hp = DefaultHealthProgression(critical = CriticalHealthProfile(
            hospital_probability = 0.4, critical_onset_to_hospital_admission = Poisson(1),
            hospital_admission_to_hospital_discharge = Poisson(8),
            hospital_to_icu_probability = 0.3, hospital_admission_to_icu_admission = Poisson(1),
            icu_admission_to_icu_discharge = Poisson(5), icu_discharge_to_hospital_discharge = Poisson(2),
            death_probability = 0.15, critical_onset_to_death = Poisson(6)))
        pA = Pathogen(id = 1, name = "A", progressions = [crit],
            transmission_function = ConstantTransmissionRate(transmission_rate = 0.15))
        pB = Pathogen(id = 2, name = "B", progressions = [crit],
            transmission_function = ConstantTransmissionRate(transmission_rate = 0.15))
        sim = Simulation(pop_size = 10_000, pathogens = (pA, pB), health_progression = hp,
            infected_fraction = 0.005, seed = 42, tickunit = 'd')
        run!(sim; with_progressbar = false)

        hdf = GEMS._hospital_df(PostProcessor(sim))
        @test sum(hdf.hospital_admissions) > 0            # the scenario actually exercises care
        @test sum(hdf.icu_admissions) > 0

        # every admission is eventually discharged, so occupancy never goes negative. A care event
        # scheduled at the current tick would be written after that tick's logging pass and could
        # never be emitted, leaving its discharge orphaned.
        @test sum(hdf.hospital_admissions) == sum(hdf.hospital_discharges)
        @test sum(hdf.icu_admissions) == sum(hdf.icu_discharges)
        @test minimum(hdf.current_hospitalized) >= 0
        @test minimum(hdf.current_icu) >= 0

        # care never outlives the host, and a death is realized at the tick it was scheduled for
        # (a death drawn into the past would be logged late, on the next update)
        scheduled = Dict{Int32, Int16}()
        n_dead = 0
        care_after_death = 0
        for i in individuals(sim)
            i.death < 0 && continue
            n_dead += 1
            scheduled[id(i)] = i.death
            (i.hospital_discharge > i.death || i.icu_discharge > i.death) && (care_after_death += 1)
        end
        @test n_dead > 0
        @test care_after_death == 0
        dd = dataframe(deathlogger(sim))
        @test all(r -> !haskey(scheduled, r.id) || r.tick == scheduled[r.id], eachrow(dd))
    end

    @testset "the forward-plan contract is enforced" begin
        ind = Individual(id = Int32(1), sex = Int8(1), age = Int8(70))
        reg = InfectionRegistry()
        dp = DiseaseProgression(exposure = Int16(20), infectiousness_onset = Int16(21), symptom_onset = Int16(22),
            severeness_onset = Int16(23), critical_onset = Int16(24), critical_offset = Int16(30),
            severeness_offset = Int16(31), recovery = Int16(60))
        s = push_infection!(reg, ind, Int8(1), Int32(-1), dp)

        # care anchored before the current tick: already logged, cannot be rewritten
        struct PastCare <: GEMS.HealthProgression end
        GEMS.calculate_health_progression(::Individual, ::InfectionRegistry, ::PastCare, ctx::HealthContext, ::Xoshiro) =
            (CareTimeline(hospital_admission = Int16(5), hospital_discharge = Int16(9)), HealthOutcome())
        @test_throws ArgumentError compute_health!(ind, reg, PastCare(), s, Int16(20), Xoshiro(1))

        # a death drawn into the past would kill the host on the next update, not at its latency
        struct PastDeath <: GEMS.HealthProgression end
        GEMS.calculate_health_progression(::Individual, ::InfectionRegistry, ::PastDeath, ctx::HealthContext, ::Xoshiro) =
            (CareTimeline(), HealthOutcome(death = Int16(12), death_pathogen_id = Int8(1)))
        @test_throws ArgumentError compute_health!(ind, reg, PastDeath(), s, Int16(20), Xoshiro(1))

        # dropping an episode the host is still in orphans its already-logged admission
        struct DropsOpenEpisode <: GEMS.HealthProgression end
        GEMS.calculate_health_progression(::Individual, ::InfectionRegistry, ::DropsOpenEpisode, ctx::HealthContext, ::Xoshiro) =
            (CareTimeline(hospital_admission = Int16(50), hospital_discharge = Int16(57)), HealthOutcome())
        ind.hospital_admission = Int16(10); ind.hospital_discharge = Int16(30)   # open at tick 20
        @test_throws ArgumentError compute_health!(ind, reg, DropsOpenEpisode(), s, Int16(20), Xoshiro(1))

        # ... but keeping that admission and extending the discharge is allowed
        struct ExtendsOpenEpisode <: GEMS.HealthProgression end
        GEMS.calculate_health_progression(::Individual, ::InfectionRegistry, ::ExtendsOpenEpisode, ctx::HealthContext, ::Xoshiro) =
            (CareTimeline(hospital_admission = Int16(10), hospital_discharge = Int16(45)), HealthOutcome())
        compute_health!(ind, reg, ExtendsOpenEpisode(), s, Int16(20), Xoshiro(1))
        @test ind.hospital_admission == 10
        @test ind.hospital_discharge == 45
    end

    @testset "Embedded-care router" begin
        dkw = (exposure_to_infectiousness_onset = Poisson(1), infectiousness_onset_to_symptom_onset = Poisson(1),
            symptom_onset_to_severeness_onset = Poisson(1), severeness_onset_to_critical_onset = Poisson(2),
            critical_onset_to_critical_offset = Poisson(7), critical_offset_to_severeness_offset = Poisson(3),
            severeness_offset_to_recovery = Poisson(4))

        # flat kwargs embed a CriticalHealthProfile directly in the disease progression
        crit = Critical(; dkw..., hospital_probability = 0.9, hospital_to_icu_probability = 0.6)
        @test crit.care isa CriticalHealthProfile
        @test crit.care.hospital_probability == 0.9
        @test crit.care.hospital_to_icu_probability == 0.6
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

        # Severe embeds a SevereHealthProfile the same way Critical does
        skw = (exposure_to_infectiousness_onset = Poisson(1), infectiousness_onset_to_symptom_onset = Poisson(1),
            symptom_onset_to_severeness_onset = Poisson(1), severeness_onset_to_severeness_offset = Poisson(7),
            severeness_offset_to_recovery = Poisson(4))

        sev = Severe(; skw..., hospital_probability = 0.3)
        @test sev.care isa SevereHealthProfile
        @test sev.care.hospital_probability == 0.3
        @test _health_profile_type(Severe) == SevereHealthProfile
        @test_throws ArgumentError Severe(; skw..., care = SevereHealthProfile(), hospital_probability = 0.3)
        @test_throws ArgumentError Severe(; skw..., hospital_to_icu_probability = 0.5)  # ICU is critical-tier

        # harvest at Simulation build (single pathogen, explicit `pathogens` argument)
        p = Pathogen(id = 1, name = "Covid19", progressions = [crit])
        sim = Simulation(pop_size = 3000, pathogens = p, seed = 1)
        hp = health_progression(sim)
        @test hp.critical.hospital_probability == 0.9
        @test hp.critical.hospital_to_icu_probability == 0.6

        # error: embedded care conflicts with an explicit health_progression
        @test_throws ArgumentError Simulation(pop_size = 1000,
            pathogens = Pathogen(id = 1, name = "Covid19", progressions = [Critical(; dkw..., hospital_probability = 0.9)]),
            health_progression = DefaultHealthProgression(), seed = 1)

        # error: embedded care is only supported for a single pathogen
        p2 = Pathogen(id = 2, name = "Flu", progressions = [Critical(; dkw..., hospital_probability = 0.9)])
        @test_throws ArgumentError Simulation(pop_size = 1000, pathogens = (p, p2), seed = 1)

        # no embedded care, no explicit policy, no [HealthProgression] section -> the plain default
        @test determine_health_progression(Dict{String, Any}(), nothing,
            ((progressions = [crit_bare],),), true) isa DefaultHealthProgression

        # config-side split (a Dict, as parsed from TOML) produces the same result as the flat-kwarg code path
        cfg = Dict(
            "exposure_to_infectiousness_onset" => Dict("distribution" => "Poisson", "parameters" => [1]),
            "infectiousness_onset_to_symptom_onset" => Dict("distribution" => "Poisson", "parameters" => [1]),
            "symptom_onset_to_severeness_onset" => Dict("distribution" => "Poisson", "parameters" => [1]),
            "severeness_onset_to_critical_onset" => Dict("distribution" => "Poisson", "parameters" => [2]),
            "critical_onset_to_critical_offset" => Dict("distribution" => "Poisson", "parameters" => [7]),
            "critical_offset_to_severeness_offset" => Dict("distribution" => "Poisson", "parameters" => [3]),
            "severeness_offset_to_recovery" => Dict("distribution" => "Poisson", "parameters" => [4]),
            "hospital_probability" => 0.9, "hospital_to_icu_probability" => 0.6)
        crit_cfg = create_progression(cfg, "Critical")
        @test crit_cfg.care.hospital_probability == 0.9
        @test crit_cfg.care.hospital_to_icu_probability == 0.6

        # end-to-end config path: TestConf.toml embeds care on its Severe/Critical progressions,
        # so the harvest runs through the config-side branch (pathogens not passed explicitly)
        conf_path = joinpath(pkgdir(GEMS), "test/testdata/TestConf.toml")
        sim_cfg = Simulation(configfile = conf_path)
        hp_cfg = health_progression(sim_cfg)
        @test hp_cfg isa DefaultHealthProgression
        @test hp_cfg.severe.hospital_probability == 1.0
        @test hp_cfg.critical.hospital_probability == 1.0
        @test hp_cfg.critical.hospital_to_icu_probability == 1.0
        @test hp_cfg.critical.death_probability == 0.3
    end

    @testset "Explicit [HealthProgression] config round-trip" begin
        params = Dict(
            "severe" => Dict(
                "hospital_probability" => 0.1,
                "severeness_onset_to_hospital_admission" => Dict("distribution" => "Poisson", "parameters" => [2]),
                "hospital_admission_to_hospital_discharge" => Dict("distribution" => "Poisson", "parameters" => [10])),
            "critical" => Dict(
                "hospital_probability" => 0.9, "hospital_to_icu_probability" => 0.6, "death_probability" => 0.3,
                "critical_onset_to_hospital_admission" => Dict("distribution" => "Poisson", "parameters" => [1]),
                "hospital_admission_to_hospital_discharge" => Dict("distribution" => "Poisson", "parameters" => [10]),
                "hospital_admission_to_icu_admission" => Dict("distribution" => "Poisson", "parameters" => [1]),
                "icu_admission_to_icu_discharge" => Dict("distribution" => "Poisson", "parameters" => [8]),
                "icu_discharge_to_hospital_discharge" => Dict("distribution" => "Poisson", "parameters" => [5]),
                "critical_onset_to_death" => Dict("distribution" => "Poisson", "parameters" => [7])))
        hp = create_health_progression(Dict("type" => "DefaultHealthProgression", "parameters" => params))
        @test hp isa DefaultHealthProgression
        @test hp.severe.hospital_probability == 0.1
        @test hp.critical.hospital_to_icu_probability == 0.6

        # a failed profile construction is rewrapped as an ErrorException carrying the type name
        @test_throws ErrorException create_health_profile(SevereHealthProfile, Dict("hospital_probability" => 1.5))

        # a non-default HealthProgression is built through the generic (non-Default) branch
        struct ConfigurableHealthProgression <: GEMS.HealthProgression
            death_probability::Float64
            ConfigurableHealthProgression(; death_probability = 0.0) = new(death_probability)
        end
        hp_custom = create_health_progression(Dict("type" => "ConfigurableHealthProgression",
            "parameters" => Dict("death_probability" => 0.2)))
        @test hp_custom isa ConfigurableHealthProgression
        @test hp_custom.death_probability == 0.2

        # an unknown parameter on that same branch is rewrapped as an ErrorException too
        @test_throws ErrorException create_health_progression(Dict("type" => "ConfigurableHealthProgression",
            "parameters" => Dict("bogus" => 1)))
    end

    @testset "Progression tag + select_health_profile" begin
        mild_kw = (exposure_to_infectiousness_onset = Poisson(1),
            infectiousness_onset_to_symptom_onset = Poisson(1), symptom_onset_to_recovery = Poisson(3))
        sev_kw = (exposure_to_infectiousness_onset = Poisson(1), infectiousness_onset_to_symptom_onset = Poisson(1),
            symptom_onset_to_severeness_onset = Poisson(1), severeness_onset_to_severeness_offset = Poisson(3),
            severeness_offset_to_recovery = Poisson(3))

        # progression_index maps a category type to its 1-based slot in the progressions tuple (0 if absent)
        progs = (Mild(; mild_kw...), Severe(; sev_kw...))
        @test progression_index(progs, Mild) == 1
        @test progression_index(progs, Severe) == 2
        @test progression_index(progs, Critical) == 0

        # infection-state timelines for each peak tier
        dp_mild = DiseaseProgression(exposure = Int16(0), infectiousness_onset = Int16(1),
            symptom_onset = Int16(2), recovery = Int16(20))
        dp_sev = DiseaseProgression(exposure = Int16(0), infectiousness_onset = Int16(1), symptom_onset = Int16(2),
            severeness_onset = Int16(5), severeness_offset = Int16(15), recovery = Int16(20))
        dp_crit = DiseaseProgression(exposure = Int16(0), infectiousness_onset = Int16(1), symptom_onset = Int16(2),
            severeness_onset = Int16(5), critical_onset = Int16(8), critical_offset = Int16(15),
            severeness_offset = Int16(16), recovery = Int16(20))

        # the from-DiseaseProgression constructor stamps the tag (default 0)
        @test InfectionState(Int8(1), Int32(-1), dp_sev).progression_id == 0
        @test InfectionState(Int8(1), Int32(-1), dp_sev, Int8(7)).progression_id == 7

        # infect! stamps the assigned category's index end-to-end (Severe is slot 2 here)
        reg = InfectionRegistry()
        ind = Individual(id = 1, sex = 0, age = 31)
        p = Pathogen(name = "TestPathogen", progressions = [Mild(; mild_kw...), Severe(; sev_kw...)],
            progression_assignment = RandomProgressionAssignment([Severe]))
        infect!(ind, Int16(0), p, rng = Xoshiro())
        @test get_infection_state(ind, reg, id(p)).progression_id == 2

        # DefaultHealthProgression routes by peak tier, ignoring the tag
        hp = DefaultHealthProgression()
        @test select_health_profile(hp, InfectionState(Int8(1), Int32(-1), dp_mild)) === nothing
        @test select_health_profile(hp, InfectionState(Int8(1), Int32(-1), dp_sev)) === hp.severe
        @test select_health_profile(hp, InfectionState(Int8(1), Int32(-1), dp_crit)) === hp.critical

        # a custom policy composes over the default, routing one tagged category to its own profile
        struct TaggedHP{D<:DefaultHealthProgression, H<:GEMS.HealthProfile} <: GEMS.HealthProgression
            default::D
            profile::H
            key::NTuple{2,Int8}
        end
        function GEMS.select_health_profile(hp::TaggedHP, infection::InfectionState)
            infection.severeness_onset < 0 && return nothing
            (infection.pathogen_id, infection.progression_id) == hp.key && return hp.profile
            select_health_profile(hp.default, infection)
        end

        custom = SevereHealthProfile(hospital_probability = 1.0)
        thp = TaggedHP(DefaultHealthProgression(), custom, (Int8(1), Int8(2)))
        # the tagged severe-peak infection (pathogen 1, slot 2) gets the custom profile 
        @test select_health_profile(thp, InfectionState(Int8(1), Int32(-1), dp_sev, Int8(2))) === custom
        # a severe-peak infection with a different tag falls through to the default severe tier
        @test select_health_profile(thp, InfectionState(Int8(1), Int32(-1), dp_sev, Int8(9))) === thp.default.severe
        # a critical-peak one (not matching the key) falls through to the default critical tier
        @test select_health_profile(thp, InfectionState(Int8(1), Int32(-1), dp_crit, Int8(9))) === thp.default.critical
    end

    @testset "Legacy backwards-compatibility" begin
        ind = Individual(id = 1, sex = 0, age = 30)

        # Symptomatic delegates to Mild: identical disease progression for the same seed
        mkw = (exposure_to_infectiousness_onset = Poisson(2),
            infectiousness_onset_to_symptom_onset = Poisson(1), symptom_onset_to_recovery = Poisson(5))
        dp_mild = calculate_progression(ind, Int16(0), Mild(; mkw...), Xoshiro(7))
        dp_symp = calculate_progression(ind, Int16(0), Symptomatic(; mkw...), Xoshiro(7))
        @test dp_symp == dp_mild

        # Hospitalized -> severe-shaped disease (no critical tier); constants make it deterministic
        hosp = Hospitalized(exposure_to_infectiousness_onset = 1, infectiousness_onset_to_symptom_onset = 1,
            symptom_onset_to_severeness_onset = 1, severeness_onset_to_hospital_admission = 2,
            hospital_admission_to_hospital_discharge = 8, hospital_discharge_to_severeness_offset = 2,
            severeness_offset_to_recovery = 1)
        dp_h = calculate_progression(ind, Int16(0), hosp, Xoshiro(1))
        @test dp_h.severeness_onset >= 0
        @test dp_h.critical_onset < 0

        # LegacyCritical -> critical-shaped disease
        lc = LegacyCritical(exposure_to_infectiousness_onset = 1, infectiousness_onset_to_symptom_onset = 1,
            symptom_onset_to_severeness_onset = 1, severeness_onset_to_hospital_admission = 2,
            hospital_admission_to_icu_admission = 2, death_probability = 1.0,
            icu_admission_to_icu_discharge = 7, icu_discharge_to_hospital_discharge = 7,
            hospital_discharge_to_severeness_offset = 2, severeness_offset_to_recovery = 1,
            icu_admission_to_death = 10)
        dp_c = calculate_progression(ind, Int16(0), lc, Xoshiro(1))
        @test dp_c.critical_onset >= 0
        @test dp_c.severeness_onset < dp_c.critical_onset < dp_c.critical_offset

        # harvest builds a tag-routing LegacyHealthProgression keyed by (pathogen_id, slot)
        p1 = Pathogen(id = 1, name = "A", progressions = [hosp, lc])   # slot 1 Hospitalized, slot 2 LegacyCritical
        p2 = Pathogen(id = 2, name = "B", progressions = [lc])
        @test _has_legacy_category(p1)
        hp = _harvest_legacy_health_progression((p1, p2))
        @test hp isa LegacyHealthProgression
        @test hp.profiles[(Int8(1), Int8(1))] isa SevereHealthProfile
        @test hp.profiles[(Int8(1), Int8(1))].hospital_probability == 1.0
        @test hp.profiles[(Int8(1), Int8(2))] isa LegacyCriticalHealthProfile
        @test hp.profiles[(Int8(2), Int8(1))] isa LegacyCriticalHealthProfile   # keyed by pathogen 2

        # routing: matching tag -> harvested profile; unmatched severe-peak -> default home tier
        is_h = InfectionState(Int8(1), Int32(-1), dp_h, Int8(1))
        @test select_health_profile(hp, is_h) === hp.profiles[(Int8(1), Int8(1))]
        is_home = InfectionState(Int8(1), Int32(-1), dp_h, Int8(9))
        @test select_health_profile(hp, is_home) === hp.default.severe

        # legacy categories may not be mixed with modern embedded care (loud error, not a silent drop)
        sev_embed = Severe(exposure_to_infectiousness_onset = 1, infectiousness_onset_to_symptom_onset = 1,
            symptom_onset_to_severeness_onset = 1, severeness_onset_to_severeness_offset = 10,
            severeness_offset_to_recovery = 4, hospital_probability = 0.1)
        p_mix = Pathogen(id = 1, name = "Mix", progressions = [hosp, sev_embed])
        @test_throws ArgumentError determine_health_progression(Dict{String,Any}(), nothing, (p_mix,), true)

        # old-format Critical is detected and rerouted to LegacyCritical (assignment list rewritten in place)
        legacy_params = Dict(
            "progressions" => Dict(
                "Symptomatic" => Dict{String,Any}(),
                "Critical" => Dict{String,Any}("icu_admission_to_death" => 10)),
            "progression_assignment" => Dict("parameters" => Dict(
                "progression_categories" => ["Asymptomatic", "Symptomatic", "Critical"])))
        @test _is_legacy_critical(legacy_params["progressions"]["Critical"])
        _normalize_legacy_pathogen!(legacy_params)
        @test haskey(legacy_params["progressions"], "LegacyCritical")
        @test !haskey(legacy_params["progressions"], "Critical")
        @test legacy_params["progression_assignment"]["parameters"]["progression_categories"] ==
            ["Asymptomatic", "Symptomatic", "LegacyCritical"]

        # a modern Critical is NOT rerouted, even when the config uses the old Symptomatic name for its mild tier
        modern_params = Dict(
            "progressions" => Dict(
                "Symptomatic" => Dict{String,Any}(),
                "Critical" => Dict{String,Any}("severeness_onset_to_critical_onset" => 1)),
            "progression_assignment" => Dict("parameters" => Dict(
                "progression_categories" => ["Asymptomatic", "Symptomatic", "Critical"])))
        @test !_is_legacy_critical(modern_params["progressions"]["Critical"])
        _normalize_legacy_pathogen!(modern_params)
        @test haskey(modern_params["progressions"], "Critical")          # modern Critical left intact
        @test !haskey(modern_params["progressions"], "LegacyCritical")
        @test modern_params["progression_assignment"]["parameters"]["progression_categories"] ==
            ["Asymptomatic", "Symptomatic", "Critical"]

        # end-to-end: a pre-decoupling (multipathogen-format) config loads and runs via the compat layer
        BASE_FOLDER = dirname(dirname(pathof(GEMS)))
        sim = Simulation(configfile = joinpath(BASE_FOLDER, "test/testdata/TestConf_old.toml"))
        @test GEMS.health_progression(sim) isa LegacyHealthProgression
        run!(sim; with_progressbar = false)
        he = dataframe(healthlogger(sim))
        n_hosp = count(==(:hospital_admission), he.event)
        n_icu = count(==(:icu_admission), he.event)
        n_vent = count(==(:ventilation_admission), he.event)
        @test n_hosp > 0                 # Hospitalized + LegacyCritical both admit to hospital
        @test n_icu > 0                  # LegacyCritical escalates to ICU
        @test n_hosp >= n_icu >= n_vent  # occupancy ladder holds
        @test n_vent == 0                # legacy categories never ventilate
        @test size(dataframe(deathlogger(sim)), 1) > 0   # some critical deaths
    end
end
