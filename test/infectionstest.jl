import GEMS: try_to_infect!, spread_infections!, update_individual!, get_containers!, dead!,
    push_infection!, push_immunity!, _EndedInfection

# a setting type GEMS does not ship, for the infectious-first loop's fallback lookup
@with_kw mutable struct SpreadTestSetting <: IndividualSetting
    id::Int32
    individuals::Vector{Individual} = Individual[]
    contact_sampling_method::GEMS.ContactSamplingMethod = ContactparameterSampling(0)
    ags::AGS = AGS()
    isopen::Bool = true
end

@testset "Infections" begin
    @testset "Agent-Level" begin

        @testset "Disease Progression" begin
            dp = DiseaseProgression(
                exposure = Int16(1),
                infectiousness_onset = Int16(2),
                symptom_onset = Int16(3),
                severeness_onset = Int16(4),
                critical_onset = Int16(5),
                critical_offset = Int16(8),
                severeness_offset = Int16(11),
                recovery = Int16(12),
            )

            pid = Int8(1)
            reg = InfectionRegistry()
            i = Individual(id = 1, sex = 0, age = 31)
            set_progression!(i, dp, pid)

            # check if everything was set correctly
            @test exposure(i, reg, pid) == 1
            @test infectiousness_onset(i, reg, pid) == 2
            @test symptom_onset(i, reg, pid) == 3
            @test severeness_onset(i, reg, pid) == 4
            @test critical_onset(i, reg, pid) == 5
            @test critical_offset(i, reg, pid) == 8
            @test severeness_offset(i, reg, pid) == 11
            @test recovery(i, reg, pid) == 12
            # death is host-level, not per-pathogen-registry
            @test i.death == GEMS.DEFAULT_TICK

            # check state functions
            # infected
            @test !infected(i, reg, pid, Int16(0)) # before
            @test infected(i, reg, pid, Int16(3)) # during
            @test !infected(i, reg, pid, Int16(13)) # after

            # infectious
            @test !infectious(i, reg, pid, Int16(1)) # before
            @test infectious(i, reg, pid, Int16(3)) # during
            @test !infectious(i, reg, pid, Int16(12)) # after

            # exposed
            @test !exposed(i, reg, pid, Int16(0)) # before
            @test exposed(i, reg, pid, Int16(1)) # during
            @test !exposed(i, reg, pid, Int16(2)) # after

            #presymptomatic
            @test !presymptomatic(i, reg, pid, Int16(0)) # before
            @test presymptomatic(i, reg, pid, Int16(2)) # during
            @test !presymptomatic(i, reg, pid, Int16(3)) # after

            # symptomatic
            @test !symptomatic(i, reg, pid, Int16(2)) # before
            @test symptomatic(i, reg, pid, Int16(4)) # during
            @test symptomatic(i, reg, pid, Int16(6)) # during
            @test symptomatic(i, reg, pid, Int16(8)) # during
            @test symptomatic(i, reg, pid, Int16(10)) # during
            @test !symptomatic(i, reg, pid, Int16(13)) # after

            # asymptomatic
            @test !asymptomatic(i, reg, pid, Int16(0)) # before
            @test !asymptomatic(i, reg, pid, Int16(4)) # during
            @test !asymptomatic(i, reg, pid, Int16(12)) # after

            # severe
            @test !severe(i, reg, pid, Int16(3)) # before
            @test severe(i, reg, pid, Int16(5)) # during
            @test !severe(i, reg, pid, Int16(12)) # after

            # mild
            @test !mild(i, reg, pid, Int16(2)) # before
            @test mild(i, reg, pid, Int16(3)) # during
            @test !mild(i, reg, pid, Int16(4)) # after
            @test mild(i, reg, pid, Int16(11)) # after severeness offset
            @test !mild(i, reg, pid, Int16(12)) # after recovery

            # critical
            @test !critical(i, reg, pid, Int16(4)) # before
            @test critical(i, reg, pid, Int16(6)) # during
            @test !critical(i, reg, pid, Int16(8)) # after

            # recovered
            @test !recovered(i, reg, pid, Int16(0)) # before infection
            @test !recovered(i, reg, pid, Int16(11)) # before
            @test recovered(i, reg, pid, Int16(12)) # at recovery
            @test recovered(i, reg, pid, Int16(13)) # after

            # dead (host-level flag, not tick-parameterized)
            @test !is_dead(i)
            @test i.death == GEMS.DEFAULT_TICK

            # death (host-level; set directly, not via DiseaseProgression)
            j = Individual(id = 2, sex = 0, age = 31)
            j.death = Int16(5)
            @test !is_dead(j) # flag not yet set by dead!
            dead!(j, true)
            @test is_dead(j)
            @test j.death == Int16(5)

            # asymptomatic progression
            dp_asymp = DiseaseProgression(
                exposure = Int16(1),
                infectiousness_onset = Int16(2),
                recovery = Int16(7),
            )
            k = Individual(id = 3, sex = 0, age = 31)
            set_progression!(k, dp_asymp, pid)
            @test !asymptomatic(k, reg, pid, Int16(0)) # before
            @test asymptomatic(k, reg, pid, Int16(3)) # during
            @test !asymptomatic(k, reg, pid, Int16(8)) # after

            @testset "progress_disease! Overflow" begin
                # With INFECTIONS_CACHE_SIZE = 1, a second simultaneous infection goes into the
                # registry linked list.  progress_disease! must process those overflow nodes too.
                p1 = Pathogen(id=1, name="P1")
                p2 = Pathogen(id=2, name="P2")
                pths = (p1, p2)

                # active path: both infections active in the overflow window
                reg_a = InfectionRegistry()
                i_a = Individual(id=10, sex=0, age=30)
                push_infection!(reg_a, i_a, Int8(1), Int32(1),
                    DiseaseProgression(exposure=Int16(1), infectiousness_onset=Int16(2), recovery=Int16(20)))
                push_infection!(reg_a, i_a, Int8(2), Int32(2),
                    DiseaseProgression(exposure=Int16(1), infectiousness_onset=Int16(2), recovery=Int16(20)))
                buf_a = _EndedInfection[]
                progress_disease!(i_a, reg_a, pths, buf_a, Int16(5), 1)
                @test isinfected(i_a)
                @test isinfectious(i_a)

                # recovery path: overflow infection reaches its recovery tick
                reg_r = InfectionRegistry()
                i_r = Individual(id=11, sex=0, age=30)
                push_infection!(reg_r, i_r, Int8(1), Int32(3),
                    DiseaseProgression(exposure=Int16(1), infectiousness_onset=Int16(2), recovery=Int16(5)))
                push_infection!(reg_r, i_r, Int8(2), Int32(4),
                    DiseaseProgression(exposure=Int16(1), infectiousness_onset=Int16(2), recovery=Int16(5)))
                buf_r = _EndedInfection[]
                progress_disease!(i_r, reg_r, pths, buf_r, Int16(10), 1)
                @test !isinfected(i_r)
                @test !isempty(buf_r) # overflow node staged for removal

                # death path: overflow infection triggers death (covers _process_death! overflow)
                # death is host-level now, so it's set directly rather than via DiseaseProgression
                reg_d = InfectionRegistry()
                i_d = Individual(id=12, sex=0, age=30)
                push_infection!(reg_d, i_d, Int8(1), Int32(5),
                    DiseaseProgression(exposure=Int16(1), infectiousness_onset=Int16(2), recovery=Int16(30)))
                push_infection!(reg_d, i_d, Int8(2), Int32(6),
                    DiseaseProgression(exposure=Int16(1), infectiousness_onset=Int16(2), recovery=Int16(30)))
                i_d.death = Int16(5)
                i_d.killing_pathogen_id = Int8(2)
                buf_d = _EndedInfection[]
                progress_disease!(i_d, reg_d, pths, buf_d, Int16(10), 1)
                @test isdead(i_d)
                @test !isempty(buf_d) # both cache and overflow nodes staged for removal
            end

            @testset "Immunity Overflow" begin
                # With IMMUNITY_CACHE_SIZE = 1, a second immunity state spills into the registry.
                s_imm = Simulation(pop_size = 100, infected_fraction = 0.0,
                    pathogens = (Pathogen(id=1, name="P1"), Pathogen(id=2, name="P2")))
                i_imm = individuals(s_imm)[1]
                ireg = GEMS.immunity_registry(s_imm, i_imm)
                push_immunity!(ireg, i_imm, Int8(1), GEMS.IMMUNITY_SOURCE_NATURAL, Int16(0), Int8(0))
                push_immunity!(ireg, i_imm, Int8(2), GEMS.IMMUNITY_SOURCE_NATURAL, Int16(0), Int8(0))

                # the overflow record is reached and its level computed when read (FullImmunity)
                @test immunity_level(i_imm, s_imm, Int8(1), Int16(10)) == Int8(100)
                @test immunity_level(i_imm, s_imm, Int8(2), Int16(10)) == Int8(100)
            end
        end

        @testset "Basic Infection" begin
            # per-infection disease-progression scheduling only; host-level care/death
            # (hospital/icu/ventilation/death) is a HealthProgression concern, covered in
            # healthprogressiontest.jl
            reg = InfectionRegistry()

            # ASYMPTOMATIC PROGRESSION
            i = Individual(id = 1, sex = 0, age = 31)
            p = Pathogen(
                name = "TestPathogen",
                progressions = [Asymptomatic(
                    exposure_to_infectiousness_onset = Poisson(3),
                    infectiousness_onset_to_recovery = Poisson(7)
            )])
            infect!(i, Int16(0), p, rng = Xoshiro())
            pid_p = id(p)

            @test -1 < exposure(i, reg, pid_p) <= infectiousness_onset(i, reg, pid_p) <= recovery(i, reg, pid_p)
            # everything else should be -1
            @test symptom_onset(i, reg, pid_p) == GEMS.DEFAULT_TICK
            @test severeness_onset(i, reg, pid_p) == GEMS.DEFAULT_TICK
            @test infected(i) # should be infected
            @test !infectious(i) # but not infectious yet

            # MILD PROGRESSION
            i = Individual(id = 1, sex = 0, age = 31)
            p = Pathogen(
                name = "TestPathogen",
                progressions = [Mild(
                    exposure_to_infectiousness_onset = Poisson(3),
                    infectiousness_onset_to_symptom_onset = Poisson(2),
                    symptom_onset_to_recovery = Poisson(7)
            )])
            infect!(i, Int16(0), p, rng = Xoshiro())
            pid_p = id(p)

            @test -1 < exposure(i, reg, pid_p) <= infectiousness_onset(i, reg, pid_p) <= symptom_onset(i, reg, pid_p) <= recovery(i, reg, pid_p)
            # everything else should be -1
            @test severeness_onset(i, reg, pid_p) == GEMS.DEFAULT_TICK
            @test infected(i) # should be infected
            @test !infectious(i) # but not infectious yet

            # SEVERE PROGRESSION
            i = Individual(id = 1, sex = 0, age = 31)
            p = Pathogen(
                name = "TestPathogen",
                progressions = [Severe(
                    exposure_to_infectiousness_onset = Poisson(3),
                    infectiousness_onset_to_symptom_onset = Poisson(1),
                    symptom_onset_to_severeness_onset = Poisson(1),
                    severeness_onset_to_severeness_offset = Poisson(7),
                    severeness_offset_to_recovery = Poisson(4)
            )])
            infect!(i, Int16(0), p, rng = Xoshiro())
            pid_p = id(p)
            @test -1 < exposure(i, reg, pid_p) <= infectiousness_onset(i, reg, pid_p) <= symptom_onset(i, reg, pid_p) <= severeness_onset(i, reg, pid_p) <= severeness_offset(i, reg, pid_p) <= recovery(i, reg, pid_p)
            # everything else should be -1
            @test critical_onset(i, reg, pid_p) == GEMS.DEFAULT_TICK
            @test critical_offset(i, reg, pid_p) == GEMS.DEFAULT_TICK
            @test infected(i) # should be infected
            @test !infectious(i) # but not infectious yet

            # CRITICAL PROGRESSION
            i = Individual(id = 1, sex = 0, age = 31)
            p = Pathogen(
                name = "TestPathogen",
                progressions = [Critical(
                    exposure_to_infectiousness_onset = Poisson(3),
                    infectiousness_onset_to_symptom_onset = Poisson(1),
                    symptom_onset_to_severeness_onset = Poisson(1),
                    severeness_onset_to_critical_onset = Poisson(2),
                    critical_onset_to_critical_offset = Poisson(7),
                    critical_offset_to_severeness_offset = Poisson(3),
                    severeness_offset_to_recovery = Poisson(4)
            )])
            infect!(i, Int16(0), p, rng = Xoshiro())
            pid_p = id(p)
            @test -1 < exposure(i, reg, pid_p) <= infectiousness_onset(i, reg, pid_p) <= symptom_onset(i, reg, pid_p) <= severeness_onset(i, reg, pid_p) <= critical_onset(i, reg, pid_p) <= critical_offset(i, reg, pid_p) <= severeness_offset(i, reg, pid_p) <= recovery(i, reg, pid_p)
            @test infected(i) # should be infected
            @test !infectious(i) # but not infectious yet
        end

    end

    @testset "Natural Immunity at Recovery" begin
        # natural immunity is granted when an infection ends, not when it is scheduled, so an
        # earlier acquisition keeps waning for the whole infection instead of reading 0.

        asymp7 = Asymptomatic(exposure_to_infectiousness_onset = 0, infectiousness_onset_to_recovery = 7)
        mkpath_im(pid, nm, prof) = Pathogen(id = pid, name = nm, progressions = [asymp7],
            progression_assignment = RandomProgressionAssignment([Asymptomatic]),
            immunity_profile = prof,
            transmission_function = ConstantTransmissionRate(transmission_rate = 0.0))

        # replicates the phase order of `step!`: progression, then the ended-infection drain
        function run_tick!(s, ind)
            update_individual!(ind, GEMS.tick(s), s)
            GEMS.flush_ended_infections!(s)
            GEMS.increment!(s)
        end

        function infect_now!(s, ind)
            infect!(ind, GEMS.tick(s), GEMS.first_pathogen(s), sim = s, rng = Xoshiro(1))
            GEMS.flush_pending_infections!(s)
        end

        @testset "prior immunity wanes through a reinfection" begin
            s = Simulation(pop_size = 300, infected_fraction = 0.0,
                pathogens = (mkpath_im(1, "P1", ExponentialWaning(halflife = 60.0)),))
            ind = individuals(s)[1]
            push_immunity!(GEMS.immunity_registry(s, ind), ind, Int8(1),
                GEMS.IMMUNITY_SOURCE_NATURAL, Int16(0), GEMS.DEFAULT_VACCINE_ID)

            levels = Dict{Int,Int}()
            while GEMS.tick(s) <= Int16(60)
                GEMS.tick(s) == Int16(40) && infect_now!(s, ind)
                t = Int(GEMS.tick(s))
                run_tick!(s, ind)
                levels[t] = Int(immunity_level(ind, s, Int8(1), Int16(t)))
            end

            during = [levels[t] for t in 40:47]   # recovery lands at 48
            @test minimum(during) > 0             # never drops to 0
            @test during[1] > during[end]         # and keeps waning
            @test levels[48] == 100               # fresh immunity on the recovery tick itself
            @test levels[49] < 100                # then wanes again

            st = GEMS.get_immunity_state(ind, GEMS.immunity_registry(s, ind), Int8(1))
            @test st.natural_acquired_tick == Int16(48)

            # waning immunity alone does not keep the recovered host in the per-tick update
            @test !GEMS._stays_active(ind)
        end

        @testset "first infection is unchanged" begin
            s = Simulation(pop_size = 300, infected_fraction = 0.0,
                pathogens = (mkpath_im(1, "P1", ExponentialWaning(halflife = 60.0)),))
            ind = individuals(s)[2]

            levels = Dict{Int,Int}()
            while GEMS.tick(s) <= Int16(69)
                GEMS.tick(s) == Int16(1) && infect_now!(s, ind)
                t = Int(GEMS.tick(s))
                run_tick!(s, ind)
                levels[t] = Int(immunity_level(ind, s, Int8(1), Int16(t)))
            end

            @test all(t -> levels[t] == 0, 0:8)   # nothing to carry, so 0 while infected
            @test levels[9] == 100                # and full immunity on its recovery tick
            @test levels[10] < 100                # wanes from the next tick on
            @test levels[69] == 50                # exactly one half-life after acquisition
        end

        @testset "a host who dies acquires nothing" begin
            s = Simulation(pop_size = 300, infected_fraction = 0.0,
                pathogens = (mkpath_im(1, "P1", ExponentialWaning(halflife = 60.0)),))
            ind = individuals(s)[3]

            while GEMS.tick(s) <= Int16(12)
                if GEMS.tick(s) == Int16(1)
                    infect_now!(s, ind)
                    ind.death = Int16(5)
                    ind.killing_pathogen_id = Int8(1)
                end
                run_tick!(s, ind)
            end

            @test isdead(ind)
            st = GEMS.get_immunity_state(ind, GEMS.immunity_registry(s, ind), Int8(1))
            @test st.natural_acquired_tick == GEMS.DEFAULT_TICK
        end

        @testset "cross-immunity survives an active infection" begin
            pA = mkpath_im(1, "PA", ExponentialWaning(halflife = 60.0))
            pB = Pathogen(id = 2, name = "PB", progressions = [asymp7],
                progression_assignment = RandomProgressionAssignment([Asymptomatic]),
                transmission_function = CompositeTransmissionRate(
                    ConstantTransmissionRate(transmission_rate = 0.5),
                    CrossImmunityModifier(cross_immunities = [("PA", 1.0)])))
            s = Simulation(pop_size = 300, pathogens = (pA, pB), infected_fraction = 0.0)
            host = individuals(s)[1]
            push_immunity!(GEMS.immunity_registry(s, host), host, Int8(1),
                GEMS.IMMUNITY_SOURCE_NATURAL, Int16(0), GEMS.DEFAULT_VACCINE_ID)

            factor() = GEMS.transmission_factor(pB.transmission_function.modifiers[1], Int8(2),
                individuals(s)[2], host, households(s)[1], GEMS.tick(s), s, Xoshiro())

            before = 0.0
            while GEMS.tick(s) <= Int16(41)
                if GEMS.tick(s) == Int16(40)
                    before = factor()
                    infect!(host, GEMS.tick(s), pA, sim = s, rng = Xoshiro(1))
                    GEMS.flush_pending_infections!(s)
                end
                run_tick!(s, host)
            end

            # cross-protection is still substantial while PA is active, not switched off
            @test before < 0.5
            @test isapprox(factor(), before, atol = 0.05)
        end
    end

    @testset "Infection Dynamics" begin

        @testset "Try to Infect" begin
            # helper function to spawn a custom test simulation
            function custom_test_sim()
                # create test population with two individuals in the same household
                pop = DataFrame(
                    id = [1,2],
                    sex = [0,0],
                    age = [31,32],
                    household = [1,1]
                )

                # create a pathogen with an asymptomatic progression
                # that has concrete time steps and a definite infection probability
                p = Pathogen(
                    id = 1,
                    name = "TestPathogen",
                    progressions = [Asymptomatic(
                        exposure_to_infectiousness_onset = 0, # infectiousness_onset = tick+1+0 = 1
                        infectiousness_onset_to_recovery = 7)],
                    transmission_function = ConstantTransmissionRate(transmission_rate = 1.0) # definite infection
                )

                return Simulation(population = Population(pop), pathogens = (p,), infected_fraction = 0.0)
            end
            
            # TRY TO INFECT INFECTER-INFECTEE (should work)
            # prepare test sim (infected + susceptible in same household)
            sim = custom_test_sim()
            infecter = individuals(sim)[1]
            infectee = individuals(sim)[2]
            infect!(infecter, Int16(0), first_pathogen(sim), rng = Xoshiro())
            GEMS.update_individual!(infecter, Int16(1), sim)

            @test try_to_infect!(infecter, infectee, sim, first_pathogen(sim), households(sim)[1])
            # the infection is only staged; its flags land on the host at the flush
            GEMS.flush_pending_infections!(sim)

            # TRY TO INFECT INFECTER-INFECTEE (should NOT work - infectee already infected)
            @test !try_to_infect!(infecter, infectee, sim, first_pathogen(sim), households(sim)[1])
        
            # TRY TO INFECT INFECTER-INFECTEE (should NOT work - infectee dead)
            # prepare test sim (infected + susceptible in same household)
            sim = custom_test_sim()
            infecter = individuals(sim)[1]
            infectee = individuals(sim)[2]
            dead!(infectee, true)
            infect!(infecter, Int16(0), first_pathogen(sim), rng = Xoshiro())
            GEMS.update_individual!(infecter, Int16(1), sim)
            @test !try_to_infect!(infecter, infectee, sim, first_pathogen(sim), households(sim)[1])

            # TRY TO INFECT INFECTER-INFECTEE (should NOT work - infectee hospitalized)
            # prepare test sim (infected + susceptible in same household)
            sim = custom_test_sim()
            infecter = individuals(sim)[1]
            infectee = individuals(sim)[2]
            infectee.hospital_demands = Int16(1)
            infect!(infecter, Int16(0), first_pathogen(sim), rng = Xoshiro())
            GEMS.update_individual!(infecter, Int16(1), sim)
            @test !try_to_infect!(infecter, infectee, sim, first_pathogen(sim), households(sim)[1])

            # TRY TO INFECT INFECTER-INFECTEE (should NOT work - infecter dead)
            # prepare test sim (infected + susceptible in same household)
            sim = custom_test_sim()
            infecter = individuals(sim)[1]
            infectee = individuals(sim)[2]
            infect!(infecter, Int16(0), first_pathogen(sim), rng = Xoshiro())
            dead!(infecter, true)
            step!(sim)
            @test !try_to_infect!(infecter, infectee, sim, first_pathogen(sim), households(sim)[1])

            # TRY TO INFECT INFECTER-INFECTEE (should NOT work - infecter hospitalized)
            # prepare test sim (infected + susceptible in same household)
            sim = custom_test_sim()
            infecter = individuals(sim)[1]
            infectee = individuals(sim)[2]
            infect!(infecter, Int16(0), first_pathogen(sim), rng = Xoshiro())
            GEMS.update_individual!(infecter, Int16(1), sim)
            infecter.hospital_demands = Int16(1)
            @test !try_to_infect!(infecter, infectee, sim, first_pathogen(sim), households(sim)[1])

            # TRY TO INFECT INFECTER-INFECTEE (should NOT work - infecter not infected
            # prepare test sim (susceptible + susceptible in same household)
            sim = custom_test_sim()
            infecter = individuals(sim)[1]
            infectee = individuals(sim)[2]
            @test_throws ArgumentError !try_to_infect!(infecter, infectee, sim, first_pathogen(sim), households(sim)[1])

            # TRY TO INFECT INFECTER-INFECTEE (should NOT work - pathogen with zero transmission function)
            # prepare test sim (infected + susceptible in same household)
            sim = custom_test_sim()
            first_pathogen(sim).transmission_function = ConstantTransmissionRate(transmission_rate = 0.0)
            infecter = individuals(sim)[1]
            infectee = individuals(sim)[2]
            infect!(infecter, Int16(0), first_pathogen(sim), rng = Xoshiro())
            GEMS.update_individual!(infecter, Int16(1), sim)
            @test !try_to_infect!(infecter, infectee, sim, first_pathogen(sim), households(sim)[1])
        end

        @testset "Household Only Infections" begin
            sim_base = Simulation(pop_size = 1000,
                infected_fraction = 0.1,
                seed = 1234)

            run!(sim_base)
            rd_base = ResultData(sim_base)

            # in a base simulation, infections should occur also in non-household settings
            @test infections(rd_base).setting_type |> unique |> length > 1

            
            sim = Simulation(pop_size = 1000,
                seed = 1234,
                infected_fraction = 0.1,
                household_contacts = 3.0,
                office_contacts = 0.0,
                school_class_contacts = 0.0)
            run!(sim)
            rd = ResultData(sim)

            # only household infections should have occurred
            @test infections(rd) |>
                df -> df[df.setting_type .!= 'h' .&& df.tick .> 0, :] |> nrow == 0
        end

        @testset "No Severe Out-Household Infections" begin
            sim = Simulation(pop_size = 10_000)
            run!(sim)
            rd = ResultData(sim)

            # no severe infections should have occurred in non-household settings

            # get all infections that became severe at some point
            sev_ifns = infections(rd) |>
                df -> df[df.severeness_onset .>= 0, :]

            # get all infections that occurred outside the household
            out_hh_infs = infections(rd) |>
                df -> df[df.setting_type .!= 'h', :]

            # get infections that were caused by a person who had severe symptoms at some point in time
            @test innerjoin(
                select(sev_ifns, :infection_id, :severeness_onset, :severeness_offset),
                select(out_hh_infs, :source_infection_id, :tick),
                on = (:infection_id => :source_infection_id)
            ) |>
            # filter for infections that occured while the source infection was severe (should be none)
            df -> df[df.severeness_onset .<= df.tick .< df.severeness_offset, :] |>
            nrow == 0

        
        end
        @testset "No Hospital Infections" begin
            # all infections should immediately lead to hospitalization
            # no infections should occur in the population, as all infected are hospitalized
            p = Pathogen(
                name = "TestPathogen",
                progressions = [Severe(
                    exposure_to_infectiousness_onset = 0,
                    infectiousness_onset_to_symptom_onset = 0,
                    symptom_onset_to_severeness_onset = 0,
                    severeness_onset_to_severeness_offset = 7,
                    severeness_offset_to_recovery = 0,
                    hospital_probability = 1.0,
                    severeness_onset_to_hospital_admission = 0,
                    hospital_admission_to_hospital_discharge = 7
            )])

            sim = Simulation(pop_size = 1000, pathogen = p, infected_fraction = 0.1)
            run!(sim)
            rd = ResultData(sim)

            # no infections should have occurred in the population
            @test infections(rd) |>
                df -> df[df.tick .> 0, :] |> nrow == 0
        end

        @testset "Quarantine Effect on Infections" begin
            
            sim = Simulation(
                pop_size = 10_000,
                infected_fraction = 0.01,
                transmission_rate = 1.0)

            # put all infected in quarantine
            for i in individuals(sim)
                if infected(i)
                    i.quarantine_tick = sim.tick
                    i.quarantine_release_tick = sim.tick + 1000
                    i.quarantine_status = GEMS.QUARANTINE_STATE_HOUSEHOLD_QUARANTINE
                end
            end

            run!(sim)
            rd = ResultData(sim)

            # the initial infected should only infect household members
            @test infections(rd) |>
                df -> df[df.source_infection_id .<= 0, :] |>
                df -> select(df, :infection_id)  |>
                df -> innerjoin(df, select(infections(rd), :source_infection_id, :setting_type), on = (:infection_id => :source_infection_id)) |>
                df -> df[(df.setting_type .!= 'h'), :] |> nrow == 0

        end

        @testset "Deferred Write Dedup" begin
            # Two attempts on the same host and pathogen in one tick, staged out of canonical
            # order. The flush must keep the one the sequential loop would have reached first:
            # Household is walked before Office, whatever order the buffers arrive in.
            sim = Simulation(pop_size = 100, infected_fraction = 0.0)
            host = individuals(sim)[1]
            pid = id(first_pathogen(sim))
            t = tick(sim)
            dp = DiseaseProgression(exposure = t, infectiousness_onset = t + Int16(2),
                recovery = t + Int16(10))

            stage(rank, char, sid) = GEMS._PendingInfection(
                host, id(host), Int32(7), GEMS.DEFAULT_INFECTION_ID, Int32(sid),
                Int32(1), char, t, pid, Int8(1), rank, dp)

            office = GEMS.setting_type_index(Office)
            household = GEMS.setting_type_index(Household)
            @test household < office

            # push the office attempt first, so buffer order and canonical order disagree
            buf = sim.infection_buffers[Threads.threadid(), GEMS._owner_shard(id(host))]
            push!(buf, stage(office, 'o', 20))
            push!(buf, stage(household, 'h', 10))

            GEMS.flush_pending_infections!(sim)

            df = infections(sim)
            @test nrow(df) == 1
            @test df.setting_type[1] == 'h'
            @test df.setting_id[1] == 10
            @test infected(host, pid)
            @test number_of_infections(host) == 1
        end

        @testset "Infectious-first loop" begin
            # The loop reaches settings from each infectious individual's plan. A walk over every
            # setting's present members must find exactly the same (individual, setting type,
            # setting id, position, scale) combinations.
            Visit = Tuple{Int32, UInt8, Int32, Int, Float32}

            function setting_first(sim)
                cntnr = GEMS.settingscontainer(sim)
                plans = GEMS.activity_plans(sim)
                t = tick(sim)
                found = Visit[]
                GEMS.foreach_setting_vector(cntnr) do stngs
                    for s in stngs, (k, ind) in enumerate(GEMS.present_members(s, cntnr))
                        (GEMS.infectious(ind) && GEMS.can_infect(ind, s, t)) || continue
                        scale = GEMS._membership_scale(plans, ind, s, cntnr)
                        scale > 0 && push!(found, (id(ind), GEMS.setting_type_index(typeof(s)), id(s), k, scale))
                    end
                end
                return sort!(found)
            end

            # what the loop visits, and how many visits name a position holding someone else
            function individual_first(sim)
                cntnr = GEMS.settingscontainer(sim)
                t = tick(sim)
                found = Visit[]
                misplaced = Ref(0)
                for ind in individuals(sim)
                    GEMS.infectious(ind) || continue
                    GEMS._foreach_spread_setting(ind, sim, GEMS._draw_at_visit) do s, pos, scale, drawn
                        (scale > 0 && GEMS.can_infect(ind, s, t)) || return
                        GEMS.present_members(s, cntnr)[pos] === ind || (misplaced[] += 1)
                        push!(found, (id(ind), GEMS.setting_type_index(typeof(s)), id(s), pos, scale))
                    end
                end
                return sort!(found), misplaced[]
            end

            function agrees(sim)
                expected = setting_first(sim)
                visited, misplaced = individual_first(sim)
                @test !isempty(expected)
                @test visited == expected
                @test misplaced == 0
            end

            BASE_FOLDER = dirname(dirname(pathof(GEMS)))
            sim = Simulation(population = joinpath(BASE_FOLDER, "test/testdata/people_muenster.jld2"),
                settingsfile = joinpath(BASE_FOLDER, "test/testdata/settings_muenster.jld2"),
                global_setting = true, infected_fraction = 0.0, seed = 1)
            @test length(settings(sim, GlobalSetting)) == 1
            foreach(i -> GEMS.infectious!(i, true), individuals(sim))
            agrees(sim)

            # repeated members: a second class in the same year, and one in another year of the same
            # school, scaled; and one member removed
            pop = population(sim)
            cntnr = GEMS.settingscontainer(sim)
            classes, years, schools = settings(sim, SchoolClass), settings(sim, SchoolYear), settings(sim, School)
            join!(m, c) = any(x -> x === m, individuals(c)) || add_member!(c, m, pop; scale = 0.5)
            for y in years[1:50]
                length(y.contains) > 1 || continue
                c1, c2 = classes[y.contains[1]], classes[y.contains[2]]
                isempty(individuals(c1)) || join!(individuals(c1)[1], c2)
            end
            for s in schools[1:50]
                length(s.contains) > 1 || continue
                y1, y2 = years[s.contains[1]], years[s.contains[2]]
                (isempty(y1.contains) || isempty(y2.contains)) && continue
                c1, c2 = classes[y1.contains[1]], classes[y2.contains[1]]
                isempty(individuals(c1)) || join!(individuals(c1)[end], c2)
            end
            leaver = first(c for c in classes if length(individuals(c)) > 2)
            remove_member!(leaver, individuals(leaver)[2], pop)
            GEMS.repack_dirty_pools!(cntnr)
            @test pop.activity_plans isa ActivityPlanStore && cntnr.pools[SchoolClass].repeats > 0
            agrees(sim)

            # closures at every level, and entries that do not apply
            rng = Xoshiro(3)
            foreach(close!, randsubseq(rng, classes, 0.05))
            foreach(close!, randsubseq(rng, years, 0.02))
            close!(schools[2])
            foreach(close!, randsubseq(rng, settings(sim, Office), 0.05))
            GEMS.repack_dirty_pools!(cntnr)
            plans = GEMS.activity_plans(sim)
            for ind in individuals(sim), slot in GEMS.plan_slots(plans, ind)
                rand(rng) < 0.02 && entry_active!(plans, ind, slot, false)
            end
            agrees(sim)

            # a setting type GEMS does not ship, never registered by hand, is reached through the
            # runtime lookup
            df = DataFrame(id = Int32.(1:4), age = Int8.(fill(30, 4)), sex = Int8.(ones(4)),
                           household = Int32[1, 1, 2, 2])
            custom_pop = Population(df)
            foreach(ind -> assign_settings!(custom_pop, ind, SpreadTestSetting => 1), individuals(custom_pop))
            custom = Simulation(population = custom_pop, infected_fraction = 0.0)
            @test length(settings(custom, SpreadTestSetting)) == 1
            foreach(i -> GEMS.infectious!(i, true), individuals(custom))
            agrees(custom)
            @test count(v -> v[2] == GEMS.setting_type_index(SpreadTestSetting), first(individual_first(custom))) == 4

            # the sweep collects exactly the individuals who are infectious
            sim = Simulation(pop_size = 2000, seed = 5)
            seen = 0
            for _ in 1:15
                step!(sim)
                collected = sort(id.(reduce(vcat, sim.infectious_individuals)))
                @test collected == sort(id.(filter(GEMS.infectious, individuals(sim))))
                seen += length(collected)
            end
            @test seen > 0
        end
    end

    @testset "Joint transmission draw" begin
        # the probability of an outcome when each pathogen transmits independently
        indep(ps, mask) = prod(mask[i] ? ps[i] : 1 - ps[i] for i in eachindex(ps))
        outcomes(N) = [ntuple(i -> (k >> (i - 1)) & 1 == 1, N) for k in 0:(2^N - 1)]
        # whether every outcome's frequency over `n` draws is within 5 standard errors of `expected`
        function matches(draw, expected, N, n)
            counts = Dict(m => 0 for m in outcomes(N))
            for _ in 1:n
                counts[draw()] += 1
            end
            return all(outcomes(N)) do m
                q = expected(m)
                abs(counts[m] / n - q) <= 5 * sqrt(max(q * (1 - q), 0.0) / n) + 1 / n
            end
        end

        rng = Xoshiro(42)
        n = 200_000
        # rounded up to Float32, as spreading does
        roundup(x) = (t = Float32(x); t < x ? nextfloat(t) : t)
        # probabilities, with bounds that are tight, loose, 0 or 1
        cases = [((0.3, 0.3), (0.3, 0.3)), ((0.3, 0.3), (0.5, 0.4)), ((0.1, 0.6), (0.1, 0.6)),
                 ((0.05, 0.9, 0.2), (0.1, 0.95, 0.5)), ((0.0, 0.4), (0.2, 0.4)), ((0.0, 0.0, 0.2), (0.0, 0.0, 0.2)),
                 ((1e-6, 1e-6), (0.5, 0.5)), ((0.5, 0.5), (1.0, 0.5)), ((0.7,), (0.7,)), ((0.2,), (0.9,))]
        for (ps, bounds) in cases
            N = length(ps)
            any_bound = 1 - prod(1 .- bounds)
            nothing_ = ntuple(_ -> false, N)
            # kept by thinning with at least the probability that any draw falls below its bound, the outcomes are the independent ones
            for thin in (roundup(any_bound), roundup((any_bound + 1) / 2), 1.0f0)
                thinned = () -> gems_rand(rng) < thin ? GEMS._draw_transmissions(ps, bounds, thin, rng) : nothing_
                @test matches(thinned, m -> indep(ps, m), N, n)
            end
        end
        @test @inferred(GEMS._draw_transmissions((0.1, 0.6), (0.2, 0.6), 0.68f0, rng)) isa NTuple{2, Bool}

        # thinning by the largest bound and accepting each pathogen on its own inflates co-transmission
        ps = (0.3, 0.3)
        naive = () -> gems_rand(rng) < 0.3 ? ntuple(i -> gems_rand(rng) < ps[i] / 0.3, 2) : (false, false)
        @test !matches(naive, m -> indep(ps, m), 2, n)
    end

    @testset "Transmission prethinning" begin
        n = 4000
        asymp = Asymptomatic(exposure_to_infectiousness_onset = 0, infectiousness_onset_to_recovery = 7)
        pathogen(pid, name, tf) = Pathogen(id = pid, name = name, progressions = [asymp], transmission_function = tf)
        rate(r) = ConstantTransmissionRate(transmission_rate = r)

        # the pathogens each second household member caught at home on the first infectious tick,
        # with every first member infected with every pathogen
        function caught(ps; prethinning, csm = RandomSampling(), host_scale = 1.0, ages = fill(30, n), setup! = sim -> nothing)
            df = DataFrame(id = Int32.(1:2n), sex = Int8.(zeros(2n)), age = Int8.(vec(permutedims(hcat(fill(30, n), ages)))),
                           household = Int32.(repeat(1:n, inner = 2)))
            table = DataFrame(id = Int32.(1:2:2n), setting_type = fill("Household", n), setting_id = Int32.(1:n),
                              scale = fill(host_scale, n))
            pop = host_scale == 1 ? Population(df) : Population(df; memberships = table)
            sim = Simulation(population = pop, pathogens = ps, infected_fraction = 0.0, household_contacts = csm,
                seed = 42, transmission_prethinning = prethinning)
            setup!(sim)
            for k in 1:2:2n, p in GEMS.pathogens(sim)
                infect!(individuals(sim)[k], tick(sim), p; sim = sim, rng = rng(sim))
            end
            GEMS.flush_pending_infections!(sim)
            step!(sim)
            step!(sim)
            got = Dict{Int32, Set{Int8}}()
            for r in eachrow(infections(sim))
                iseven(r.id_b) && r.tick == 1 && r.setting_type == 'h' || continue
                push!(get!(got, r.id_b, Set{Int8}()), r.pathogen_id)
            end
            return got
        end
        share(got, set) = count(==(set), values(got)) / n
        A, B, AB = Set(Int8[1]), Set(Int8[2]), Set(Int8[1, 2])

        # co-infection over one contact per tick: each pathogen transmits on its own
        for on in (true, false), (a, b) in ((0.3, 0.3), (0.1, 0.6))
            got = caught((pathogen(1, "A", rate(a)), pathogen(2, "B", rate(b))); prethinning = on)
            @test isapprox(share(got, A), a * (1 - b); atol = 0.02)
            @test isapprox(share(got, B), (1 - a) * b; atol = 0.02)
            @test isapprox(share(got, AB), a * b; atol = 0.02)
        end

        # co-infection over Poisson(2) contacts, drawn by the sampler or by a host at scale 2
        no_a, no_b, neither = exp(-0.6), exp(-0.6), exp(-2 * (1 - 0.7^2))
        both = 1 - no_a - no_b + neither
        for on in (true, false), (csm, scale) in ((ContactparameterSampling(2.0), 1.0), (ContactparameterSampling(1.0), 2.0))
            got = caught((pathogen(1, "A", rate(0.3)), pathogen(2, "B", rate(0.3))); prethinning = on, csm = csm, host_scale = scale)
            @test isapprox(share(got, A), 1 - no_a - both; atol = 0.02)
            @test isapprox(share(got, B), 1 - no_b - both; atol = 0.02)
            @test isapprox(share(got, AB), both; atol = 0.02)
        end

        # a loose bound: housemates of 10 and 60 are caught at 0.1 and 0.5, immune ones never
        function immunize!(sim)
            for h in 4:4:n
                ind = individuals(sim)[2h]
                push_immunity!(immunity_registry(sim, ind), ind, Int8(1), GEMS.IMMUNITY_SOURCE_NATURAL, Int16(0), GEMS.DEFAULT_VACCINE_ID)
            end
        end
        adtr = AgeDependentTransmissionRate(age_groups = ["0-19", "20-"], transmission_rates = [0.1, 0.5])
        for on in (true, false)
            got = caught((pathogen(1, "A", adtr),); prethinning = on, ages = repeat([10, 60], n ÷ 2), setup! = immunize!)
            caught_share(hs) = count(h -> haskey(got, Int32(2h)), hs) / length(hs)
            @test isapprox(caught_share(1:2:n), 0.1; atol = 0.03)
            @test isapprox(caught_share(2:4:n), 0.5; atol = 0.05)
            @test caught_share(4:4:n) == 0
        end

        # a modifier above 1: at its peak, seasonality raises 0.4 to 0.6
        seasonal = SinusoidalSeasonalTransmissionRate(transmission_rate = 0.4, amplitude = 0.5, peak_day = 2)
        for on in (true, false)
            @test isapprox(length(caught((pathogen(1, "A", seasonal),); prethinning = on)) / n, 0.6; atol = 0.025)
        end

        # housemates carrying B cannot catch it again, and its interference cuts A from 0.5 to 0.2
        interfered = CompositeTransmissionRate(rate(0.5), ViralInterferenceModifier(interferences = [("B", 0.4)]))
        carry_b! = sim -> foreach(h -> infect!(individuals(sim)[2h], tick(sim), GEMS.pathogens(sim)[2]; sim = sim, rng = rng(sim)), 1:n)
        for on in (true, false)
            got = caught((pathogen(1, "A", interfered), pathogen(2, "B", rate(0.3))); prethinning = on, setup! = carry_b!)
            @test isapprox(share(got, A), 0.2; atol = 0.02)
            @test share(got, B) == 0 && share(got, AB) == 0
        end

        # a bound below the probability is an error, not a silent bias
        struct UnderboundRate <: GEMS.TransmissionFunction end
        GEMS.transmission_probability(::UnderboundRate, pathogen_id::Int8, infecter::Individual, infectee::Individual,
            setting::Setting, tick::Int16, sim::GEMS.Simulation, rng::Xoshiro) = 0.5
        GEMS.max_transmission_probability(::UnderboundRate, pathogen_id::Int8, infecter::Individual, setting::Setting,
            tick::Int16, sim::GEMS.Simulation) = 0.1
        err = try
            caught((pathogen(1, "A", UnderboundRate()),); prethinning = true)
            nothing
        catch e
            e
        end
        @test err !== nothing && occursin("UnderboundRate", sprint(showerror, err))
    end

    @testset "Pre-drawn contacts" begin
        # Drawing each visit's contact count from its type's bound before loading the setting must
        # leave the law of the spread phase unchanged. Both walks run it many times on one frozen
        # tick, and the infections they stage are compared per infecter, setting type and pathogen.
        BASE_FOLDER = dirname(dirname(pathof(GEMS)))
        asymp = Asymptomatic(exposure_to_infectiousness_onset = 0, infectiousness_onset_to_recovery = 30)
        factors = Dict("Household" => 2.0, "SchoolClass" => 1.5, "Office" => 0.5)
        pa = Pathogen(id = 1, name = "DrawnA", progressions = [asymp],
            transmission_function = SettingTransmissionRate(transmission_rate = 0.05, factors = factors, default_factor = 1.0))
        pb = Pathogen(id = 2, name = "DrawnB", progressions = [asymp],
            transmission_function = ConstantTransmissionRate(transmission_rate = 0.03))
        sim = Simulation(population = joinpath(BASE_FOLDER, "test/testdata/people_muenster.jld2"),
            settingsfile = joinpath(BASE_FOLDER, "test/testdata/settings_muenster.jld2"),
            pathogens = (pa, pb), infected_fraction = 0.0, global_setting = true, seed = 11)
        cntnr = GEMS.settingscontainer(sim)
        plans = GEMS.activity_plans(sim)
        setup = Xoshiro(5)

        # about 2000 hosts, shedding A, B or both, infectious after two ticks
        hosts = randsubseq(setup, individuals(sim), 2000 / length(individuals(sim)))
        for (k, h) in enumerate(hosts)
            k % 3 != 2 && infect!(h, tick(sim), pa; sim = sim, rng = rng(sim))
            k % 3 != 1 && infect!(h, tick(sim), pb; sim = sim, rng = rng(sim))
        end
        GEMS.flush_pending_infections!(sim)
        step!(sim)
        step!(sim)
        infectious = reduce(vcat, sim.infectious_individuals)
        @test length(infectious) > 1500

        # scaled entries, hosts in a second class of their year, busier households, age-based
        # municipalities and closed classes
        for (k, h) in enumerate(infectious)
            k % 5 == 0 && set_scale!(sim, h, Household, household_id(h, plans), (0.0, 0.5, 2.0, 3.0)[k % 4 + 1])
        end
        classes, years = settings(sim, SchoolClass), settings(sim, SchoolYear)
        for h in infectious
            cid = class_id(h, plans)
            cid == GEMS.DEFAULT_SETTING_ID && continue
            y = years[classes[cid].contained]
            other = findfirst(c -> c != cid, y.contains)
            other === nothing && continue
            c2 = classes[y.contains[other]]
            any(x -> x === h, individuals(c2)) || add_member!(c2, h, sim; scale = 0.5)
        end
        for hh in randsubseq(setup, households(sim), 0.05)
            contact_sampling_method!(sim, hh, ContactparameterSampling(3.0))
        end
        abcs = AgeBasedContactSampling(contactparameter = 1.5, interval = 5,
            contact_matrix_file = joinpath(BASE_FOLDER, "test/testdata/contact_matrix.txt"))
        foreach(m -> contact_sampling_method!(sim, m, abcs), settings(sim, Municipality))
        foreach(close!, randsubseq(setup, classes, 0.1))
        GEMS.repack_dirty_pools!(cntnr)
        @test count(isfinite, cntnr.rate_bounds) >= 10

        # summed counts and squares per (infecter, setting type, pathogen), and per (type, pathogen)
        function staged(sim, reps)
            cells = Dict{Tuple{Int32, Char, Int8}, Vector{Float64}}()
            totals = Dict{Tuple{Char, Int8}, Vector{Float64}}()
            for _ in 1:reps
                GEMS.spread_infections!(sim)
                rep = Dict{Tuple{Int32, Char, Int8}, Int}()
                for buf in sim.infection_buffers, p in buf
                    key = (p.infecter_id, p.setting_type, p.pathogen_id)
                    rep[key] = get(rep, key, 0) + 1
                end
                foreach(empty!, sim.infection_buffers)
                per_type = Dict{Tuple{Char, Int8}, Int}()
                for (key, v) in rep
                    acc = get!(() -> [0.0, 0.0], cells, key)
                    acc .+= (v, v^2)
                    per_type[(key[2], key[3])] = get(per_type, (key[2], key[3]), 0) + v
                end
                for (key, v) in per_type
                    acc = get!(() -> [0.0, 0.0], totals, key)
                    acc .+= (v, v^2)
                end
            end
            return cells, totals
        end
        reps = 200
        new_cells, new_totals = staged(sim, reps)
        drawn_bounds = copy(cntnr.rate_bounds)
        fill!(cntnr.rate_bounds, Inf)
        old_cells, old_totals = staged(sim, reps)
        copyto!(cntnr.rate_bounds, drawn_bounds)

        moments(acc) = (m = acc[1] / reps; (m, max(acc[2] / reps - m^2, 0.0)))
        z(a, b) = ((ma, va) = moments(a); (mb, vb) = moments(b); (ma - mb) / sqrt(max((va + vb) / reps, 1e-12)))
        nothing_yet = [0.0, 0.0]

        # every type that spreads in both walks, and each one's total agrees
        @test length(new_totals) >= 10
        @test keys(new_totals) == keys(old_totals)
        @test all(k -> abs(z(new_totals[k], old_totals[k])) < 4, keys(old_totals))

        # each infecter's counts per type agree too, as a whole
        stat = 0.0
        df = 0
        for k in union(keys(new_cells), keys(old_cells))
            a, b = get(new_cells, k, nothing_yet), get(old_cells, k, nothing_yet)
            a[1] + b[1] >= 20 || continue
            stat += z(a, b)^2
            df += 1
        end
        @test df > 500
        @test (stat - df) / sqrt(2df) < 4

        # every visit's contact rate is within the bound its level drew at, not just on average
        t = tick(sim)
        each_level = (S, h, slot, sim) -> GEMS._ContactDraw(1, GEMS._contact_draw(S, h, slot, sim).rate_bound)
        checked = Ref(0)
        exceeded = Ref(0)
        for h in infectious
            GEMS._foreach_spread_setting(h, sim, each_level) do s, pos, scale, drawn
                isinf(drawn.rate_bound) && return
                present = GEMS.present_members(s, cntnr)
                (scale > 0 && GEMS.can_infect(h, s, t) && length(present) > 1) || return
                _, thin = GEMS._transmission_bounds(h, s, t, sim)
                rate = GEMS._visit_rate(GEMS.contact_rate(s.contact_sampling_method, s, pos, present, t),
                    scale, GEMS._scale_bound(s), thin)
                checked[] += 1
                rate <= drawn.rate_bound || (exceeded[] += 1)
            end
        end
        @test checked[] > 1000
        @test exceeded[] == 0

        # a type bound below a setting's rate is an error, not a bias
        hh = GEMS.setting_type_index(Household)
        cntnr.rate_bounds[hh] = 0.1
        err = try
            GEMS.spread_infections!(sim)
            nothing
        catch e
            e
        end
        cntnr.rate_bounds[hh] = drawn_bounds[hh]
        foreach(empty!, sim.infection_buffers)
        @test err !== nothing && occursin("exceeds the bound", sprint(showerror, err))

        # once compiled, walking with draws allocates nothing, and each level's draw is concretely typed
        walk_bytes(h) = @allocated GEMS._foreach_spread_setting((s, pos, scale, drawn) -> nothing, h, sim, GEMS._contact_draw)
        foreach(walk_bytes, infectious)
        @test all(h -> walk_bytes(h) == 0, infectious)
        h = first(infectious)
        @test @inferred(GEMS._level_draws(GEMS._contact_draw, SchoolClass, h, first(GEMS.plan_slots(plans, h)), sim)) isa
            NTuple{4, GEMS._ContactDraw}
    end
end