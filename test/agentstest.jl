@testset "Agents" begin
    @testset "Individuals" begin
        @testset "Attributes" begin
            i = Individual(id = 1, sex = 0, age = 31)

            # testing initial values
            @test id(i) == 1
            @test sex(i) == 0
            @test age(i) == 31

            # testing default values ("-1" for "undefined")
            @test education(i) == -1
            @test occupation(i) == -1
            @test social_factor(i) == 0
            @test mandate_compliance(i) == 0
            @test comorbidities(i) == 0
            @test household_id(i) == GEMS.DEFAULT_SETTING_ID
            @test office_id(i) == GEMS.DEFAULT_SETTING_ID
            @test class_id(i) == GEMS.DEFAULT_SETTING_ID
        end

        @testset "Behaviour Setters" begin
            i = Individual(id=1, sex=0, age=30)

            social_factor!(i, Float32(0.5))
            @test social_factor(i) == Float32(0.5)

            social_factor!(i, 0.75)
            @test social_factor(i) == Float32(0.75)

            social_factor!(i, Float32(-0.3))
            @test social_factor(i) == Float32(-0.3)

            mandate_compliance!(i, Float32(0.3))
            @test mandate_compliance(i) == Float32(0.3)

            mandate_compliance!(i, 0.9)
            @test mandate_compliance(i) == Float32(0.9)

            mandate_compliance!(i, Float32(-1.0))
            @test mandate_compliance(i) == Float32(-1.0)
        end


        @testset "Setting Membership Predicates" begin
            i = Individual(id=1, sex=0, age=25)
            @test !is_working(i)
            @test !is_student(i)
            @test !has_municipality(i)

            @test is_working(Individual(id=2, sex=0, age=25, office=Int32(5)))
            @test is_student(Individual(id=3, sex=0, age=10, schoolclass=Int32(7)))
            @test has_municipality(Individual(id=4, sex=0, age=40, municipality=Int32(3)))

            # setting_id! covers Office and Municipality branches
            i_set = Individual(id=5, sex=0, age=30)
            setting_id!(i_set, Office, Int32(7))
            @test i_set.office == Int32(7)
            setting_id!(i_set, Municipality, Int32(3))
            @test i_set.municipality == Int32(3)

            # setting_id for unknown type returns DEFAULT_SETTING_ID
            @test setting_id(Individual(id=6, sex=0, age=20), WorkplaceSite) == GEMS.DEFAULT_SETTING_ID

            # detected!(ind, pathogen_id, false) clears the per-pathogen bit
            i_det = Individual(id=7, sex=0, age=30)
            detected!(i_det, Int8(1), true)
            @test isdetected(i_det, Int8(1))
            detected!(i_det, Int8(1), false)
            @test !isdetected(i_det, Int8(1))
        end

        @testset "Comorbidities" begin
            # Test default Individual (no comorbidities)
            i_default = Individual(id = 1, sex = 0, age = 31)
            @test !has_comorbidity(i_default, Int16(1))
            @test !has_comorbidity(i_default, Int16(16))
            
            # Test with specific comorbidities set
            # UInt16(5) is binary 0000000000000101, meaning the 1st and 3rd bits are 1
            i_comorbid = Individual(id = 2, sex = 0, age = 31, comorbidities = UInt16(5))
            
            @test has_comorbidity(i_comorbid, Int16(1))  # 1st bit is 1
            @test !has_comorbidity(i_comorbid, Int16(2)) # 2nd bit is 0
            @test has_comorbidity(i_comorbid, Int16(3))  # 3rd bit is 1
            @test !has_comorbidity(i_comorbid, Int16(4)) # 4th bit is 0
            
            # Test boundaries for the Int16 index
            @test_throws ArgumentError has_comorbidity(i_comorbid, Int16(0))
            @test_throws ArgumentError has_comorbidity(i_comorbid, Int16(17))
        end

        @testset "Reset" begin
            i = Individual(id=1, sex=1, age=30)

            # Modify health status flags
            infected!(i, true)
            infectious!(i, true)
            symptomatic!(i, true)
            severe!(i, true)
            hospitalized!(i, true)
            icu!(i, true)
            ventilated!(i, true)
            dead!(i, true)
            detected!(i, true)

            # Modify infection count
            inc_number_of_infections!(i)
            inc_number_of_infections!(i)
            @test i.number_of_infections == 2
            @test number_of_infections(i) == 2

            # Modify interventions
            home_quarantine!(i)
            quarantine_tick!(i, Int16(5))
            quarantine_release_tick!(i, Int16(15))

            # Call reset! with empty registries (no overflow state to clean up)
            GEMS.reset!(i, InfectionRegistry(), ImmunityRegistry())

            # Assert health status is clean
            @test !isinfected(i)
            @test !isinfectious(i)
            @test !issymptomatic(i)
            @test !issevere(i)
            @test !ishospitalized(i)
            @test !isicu(i)
            @test !isventilated(i)
            @test !isdead(i)
            @test !isdetected(i)

            # Assert infection count and masks cleared
            @test i.number_of_infections == 0
            @test i.active_pathogens_mask == 0
            @test i.detected_mask == 0

            # Assert interventions cleared
            @test quarantine_status(i) == GEMS.QUARANTINE_STATE_NO_QUARANTINE
            @test quarantine_tick(i) == GEMS.DEFAULT_TICK
            @test quarantine_release_tick(i) == GEMS.DEFAULT_TICK
        end

        @testset "Disease Progression & Hospitalization" begin
            @testset "Times Setter & Getter" begin
                pid = Int8(1)
                reg = InfectionRegistry()

                # default: individual with no infection → all timeline fields return DEFAULT_TICK
                i = Individual(id = 1, sex = 0, age = 31)
                @test exposure(i, reg, pid) == GEMS.DEFAULT_TICK
                @test infectiousness_onset(i, reg, pid) == GEMS.DEFAULT_TICK
                @test recovery(i, reg, pid) == GEMS.DEFAULT_TICK
                @test death(i, reg, pid) == GEMS.DEFAULT_TICK

                # after set_progression! the DiseaseProgression values are readable
                dp = DiseaseProgression(
                    exposure = Int16(1),
                    infectiousness_onset = Int16(3),
                    symptom_onset = Int16(5),
                    recovery = Int16(15),
                )
                set_progression!(i, dp, pid)
                @test exposure(i, reg, pid) == 1
                @test infectiousness_onset(i, reg, pid) == 3
                @test symptom_onset(i, reg, pid) == 5
                @test recovery(i, reg, pid) == 15
                @test severeness_onset(i, reg, pid) == GEMS.DEFAULT_TICK
                @test hospital_admission(i, reg, pid) == GEMS.DEFAULT_TICK
                @test death(i, reg, pid) == GEMS.DEFAULT_TICK
            end

            @testset "Registry Overflow" begin
                # With INFECTIONS_CACHE_SIZE = 1, a second simultaneous infection spills into
                # the registry linked list. All per-pathogen accessors must traverse that list.
                reg = InfectionRegistry()
                i = Individual(id=1, sex=0, age=30)
                pid1 = Int8(1)
                pid2 = Int8(2)
                push_infection!(reg, i, pid1, Int32(1),
                    DiseaseProgression(exposure=Int16(1), infectiousness_onset=Int16(3), recovery=Int16(20)))
                push_infection!(reg, i, pid2, Int32(2),
                    DiseaseProgression(exposure=Int16(2), infectiousness_onset=Int16(4), recovery=Int16(25)))

                # overflow node is accessible via get_infection_state
                @test get_infection_state(i, reg, pid2).pathogen_id == pid2

                # infection_id looks up the overflow node
                @test infection_id(i, pid2, reg) == Int32(2)

                # infectiousness returns 0 before infectiousness_onset
                @test infectiousness(i, pid2, reg) == Int8(0)

                # infected(ind, pid, reg) — current-tick variant
                @test infected(i, pid1, reg)
                @test infected(i, pid2, reg)
                @test !infected(i, Int8(3), reg)

                # get_active_pathogens returns cache-slot pathogen IDs (0 for inactive slots)
                active = get_active_pathogens(i)
                @test pid1 in active

                # multi-node overflow: traverse past a non-matching head node (covers node = s.next)
                pid3 = Int8(3)
                push_infection!(reg, i, pid3, Int32(3),
                    DiseaseProgression(exposure=Int16(3), infectiousness_onset=Int16(5), recovery=Int16(30)))
                # list after 3 pushes: cache=pid1, head points to pid3 which points to pid2
                @test get_infection_state(i, reg, pid2).pathogen_id == pid2  # traverses past pid3
                @test infection_id(i, pid2, reg) == Int32(2)
                @test infectiousness(i, pid2, reg) == Int8(0)
                # pathogen not in list at all returns defaults
                @test infectiousness(i, Int8(4), reg) == Int8(0)
                @test infection_id(i, Int8(4), reg) == GEMS.DEFAULT_INFECTION_ID

                # immunity overflow (IMMUNITY_CACHE_SIZE = 1, second pathogen overflows)
                ireg = ImmunityRegistry()
                push_immunity!(ireg, i, pid1, GEMS.IMMUNITY_SOURCE_NATURAL, Int16(0), Int8(0))
                push_immunity!(ireg, i, pid2, GEMS.IMMUNITY_SOURCE_NATURAL, Int16(0), Int8(0))
                @test get_immunity_state(i, ireg, pid2).pathogen_id == pid2
                @test immunity_level(i, pid2, ireg) == Int8(0)

                # multi-node immunity overflow: traverse past head to find second node
                push_immunity!(ireg, i, pid3, GEMS.IMMUNITY_SOURCE_NATURAL, Int16(0), Int8(0))
                # head points to pid3 which points to pid2
                @test get_immunity_state(i, ireg, pid2).pathogen_id == pid2  # traverses past pid3
                @test immunity_level(i, pid2, ireg) == Int8(0)
                @test immunity_level(i, Int8(4), ireg) == Int8(0)  # not found returns 0
            end

            @testset "Sim Wrappers" begin
                # one-liner wrappers that route to the correct registry shard via the sim
                sim_sw = Simulation()
                pid_sw = id(first_pathogen(sim_sw))
                i_sw = Individual(id=1, sex=0, age=30)
                push_infection!(infection_registry(sim_sw, i_sw), i_sw, pid_sw, Int32(1),
                    DiseaseProgression(exposure=Int16(1), infectiousness_onset=Int16(3), recovery=Int16(20)))

                @test infected(i_sw, pid_sw, sim_sw)
                @test infectiousness(i_sw, pid_sw, sim_sw) == Int8(0)
                @test earliest_infectiousness_onset(i_sw, sim_sw) == Int16(3)

                push_immunity!(immunity_registry(sim_sw, i_sw), i_sw, pid_sw, GEMS.IMMUNITY_SOURCE_NATURAL, Int16(0), Int8(0))
                @test immunity_level(i_sw, pid_sw, sim_sw) == Int8(0)
            end

        end

        @testset "Health Status Aliases (Current-State)" begin
            i = Individual(id=1, sex=1, age=30)

            @test !isinfected(i)
            @test !infected(i)
            @test !isinfectious(i)
            @test !infectious(i)
            @test !isexposed(i)
            @test !exposed(i)
            @test !issymptomatic(i)
            @test !symptomatic(i)
            @test !issevere(i)
            @test !severe(i)
            @test !ishospitalized(i)
            @test !hospitalized(i)
            @test !isicu(i)
            @test !icu(i)
            @test !isventilated(i)
            @test !ventilated(i)
            @test !isdead(i)
            @test !dead(i)
            @test !isdetected(i)
            @test !detected(i)
            @test !quarantined(i)

            infected!(i, true)
            @test isinfected(i)
            @test infected(i)
            @test isexposed(i)
            @test exposed(i)

            infectious!(i, true)
            @test isinfectious(i)
            @test infectious(i)
            @test !isexposed(i)
            @test !exposed(i)

            symptomatic!(i, true)
            @test issymptomatic(i)
            @test symptomatic(i)

            severe!(i, true)
            @test issevere(i)
            @test severe(i)

            hospitalized!(i, true)
            @test ishospitalized(i)
            @test hospitalized(i)

            icu!(i, true)
            @test isicu(i)
            @test icu(i)

            ventilated!(i, true)
            @test isventilated(i)
            @test ventilated(i)

            dead!(i, true)
            @test isdead(i)
            @test dead(i)

            detected!(i, true)
            @test isdetected(i)
            @test detected(i)

            home_quarantine!(i)
            @test quarantined(i)

            end_quarantine!(i)
            @test !quarantined(i)

            quarantined!(i, true)
            @test is_quarantined(i)
            quarantined!(i, false)
            @test !is_quarantined(i)
        end


        @testset "Time-Parameterized Disease Status" begin
            pid = Int8(1)
            reg = InfectionRegistry()
            i = Individual(id=1, sex=1, age=30)
            dp_i = DiseaseProgression(
                exposure = Int16(5),
                infectiousness_onset = Int16(7),
                symptom_onset = Int16(10),
                severeness_onset = Int16(15),
                hospital_admission = Int16(15),
                icu_admission = Int16(15),
                icu_discharge = Int16(18),
                ventilation_admission = Int16(15),
                ventilation_discharge = Int16(17),
                hospital_discharge = Int16(25),
                severeness_offset = Int16(26),
                recovery = Int16(30),
            )
            set_progression!(i, dp_i, pid)
            detected!(i, Int8(1), true) # mark as detected for pathogen 1

            # is_infected / isinfected / infected
            @test !is_infected(i, reg, pid, Int16(4))
            @test is_infected(i, reg, pid, Int16(5))
            @test is_infected(i, reg, pid, Int16(20))
            @test !is_infected(i, reg, pid, Int16(30))
            @test isinfected(i, reg, pid, Int16(10)) == is_infected(i, reg, pid, Int16(10))
            @test infected(i, reg, pid, Int16(10)) == is_infected(i, reg, pid, Int16(10))

            # is_exposed / isexposed / exposed
            @test !is_exposed(i, reg, pid, Int16(4))
            @test is_exposed(i, reg, pid, Int16(5))
            @test is_exposed(i, reg, pid, Int16(6))
            @test !is_exposed(i, reg, pid, Int16(7))
            @test isexposed(i, reg, pid, Int16(5)) == is_exposed(i, reg, pid, Int16(5))
            @test exposed(i, reg, pid, Int16(5)) == is_exposed(i, reg, pid, Int16(5))

            # is_infectious / isinfectious / infectious
            @test !is_infectious(i, reg, pid, Int16(6))
            @test is_infectious(i, reg, pid, Int16(7))
            @test is_infectious(i, reg, pid, Int16(15))
            @test !is_infectious(i, reg, pid, Int16(30))
            @test isinfectious(i, reg, pid, Int16(7)) == is_infectious(i, reg, pid, Int16(7))
            @test infectious(i, reg, pid, Int16(7)) == is_infectious(i, reg, pid, Int16(7))

            # is_presymptomatic / ispresymptomatic / presymptomatic
            @test is_presymptomatic(i, reg, pid, Int16(7))
            @test is_presymptomatic(i, reg, pid, Int16(9))
            @test !is_presymptomatic(i, reg, pid, Int16(10))
            @test !is_presymptomatic(i, reg, pid, Int16(4))
            @test ispresymptomatic(i, reg, pid, Int16(7)) == is_presymptomatic(i, reg, pid, Int16(7))
            @test presymptomatic(i, reg, pid, Int16(7)) == is_presymptomatic(i, reg, pid, Int16(7))

            # is_symptomatic / issymptomatic / symptomatic
            @test !is_symptomatic(i, reg, pid, Int16(9))
            @test is_symptomatic(i, reg, pid, Int16(10))
            @test is_symptomatic(i, reg, pid, Int16(25))
            @test !is_symptomatic(i, reg, pid, Int16(30))
            @test issymptomatic(i, reg, pid, Int16(10)) == is_symptomatic(i, reg, pid, Int16(10))
            @test symptomatic(i, reg, pid, Int16(10)) == is_symptomatic(i, reg, pid, Int16(10))

            # is_severe / issevere / severe
            @test !is_severe(i, reg, pid, Int16(14))
            @test is_severe(i, reg, pid, Int16(15))
            @test is_severe(i, reg, pid, Int16(25))
            @test !is_severe(i, reg, pid, Int16(26))
            @test issevere(i, reg, pid, Int16(15)) == is_severe(i, reg, pid, Int16(15))
            @test severe(i, reg, pid, Int16(15)) == is_severe(i, reg, pid, Int16(15))

            # is_mild / ismild / mild
            @test is_mild(i, reg, pid, Int16(12))
            @test !is_mild(i, reg, pid, Int16(15))
            @test ismild(i, reg, pid, Int16(12)) == is_mild(i, reg, pid, Int16(12))
            @test mild(i, reg, pid, Int16(12)) == is_mild(i, reg, pid, Int16(12))

            # is_hospitalized / ishospitalized / hospitalized
            @test !is_hospitalized(i, reg, pid, Int16(14))
            @test is_hospitalized(i, reg, pid, Int16(15))
            @test is_hospitalized(i, reg, pid, Int16(24))
            @test !is_hospitalized(i, reg, pid, Int16(25))
            @test ishospitalized(i, reg, pid, Int16(15)) == is_hospitalized(i, reg, pid, Int16(15))
            @test hospitalized(i, reg, pid, Int16(15)) == is_hospitalized(i, reg, pid, Int16(15))

            # is_icu / isicu / icu
            @test !is_icu(i, reg, pid, Int16(14))
            @test is_icu(i, reg, pid, Int16(15))
            @test is_icu(i, reg, pid, Int16(17))
            @test !is_icu(i, reg, pid, Int16(18))
            @test isicu(i, reg, pid, Int16(15)) == is_icu(i, reg, pid, Int16(15))
            @test icu(i, reg, pid, Int16(15)) == is_icu(i, reg, pid, Int16(15))

            # is_ventilated / isventilated / ventilated
            @test !is_ventilated(i, reg, pid, Int16(14))
            @test is_ventilated(i, reg, pid, Int16(15))
            @test is_ventilated(i, reg, pid, Int16(16))
            @test !is_ventilated(i, reg, pid, Int16(17))
            @test isventilated(i, reg, pid, Int16(15)) == is_ventilated(i, reg, pid, Int16(15))
            @test ventilated(i, reg, pid, Int16(15)) == is_ventilated(i, reg, pid, Int16(15))

            # is_recovered / isrecovered / recovered
            @test !is_recovered(i, reg, pid, Int16(29))
            @test is_recovered(i, reg, pid, Int16(30))
            @test is_recovered(i, reg, pid, Int16(50))
            @test isrecovered(i, reg, pid, Int16(30)) == is_recovered(i, reg, pid, Int16(30))
            @test recovered(i, reg, pid, Int16(30)) == is_recovered(i, reg, pid, Int16(30))

            # is_detected / isdetected / detected
            @test is_detected(i, reg, pid, Int16(12))
            @test isdetected(i, reg, pid, Int16(12)) == is_detected(i, reg, pid, Int16(12))
            @test detected(i, reg, pid, Int16(12)) == is_detected(i, reg, pid, Int16(12))
            i_undetected = Individual(id=99, sex=0, age=20)
            set_progression!(i_undetected, DiseaseProgression(exposure=Int16(5), infectiousness_onset=Int16(6), recovery=Int16(20)), pid)
            @test !is_detected(i_undetected, reg, pid, Int16(10))

            # is_dead / isdead / dead
            i_dead = Individual(id=2, sex=2, age=60)
            set_progression!(i_dead, DiseaseProgression(exposure=Int16(5), infectiousness_onset=Int16(6), symptom_onset=Int16(7), death=Int16(15)), pid)
            @test !is_dead(i_dead, reg, pid, Int16(14))
            @test is_dead(i_dead, reg, pid, Int16(15))
            @test isdead(i_dead, reg, pid, Int16(15)) == is_dead(i_dead, reg, pid, Int16(15))
            @test dead(i_dead, reg, pid, Int16(15)) == is_dead(i_dead, reg, pid, Int16(15))

            # is_asymptomatic / isasymptomatic / asymptomatic
            i_asymp = Individual(id=3, sex=0, age=25)
            set_progression!(i_asymp, DiseaseProgression(exposure=Int16(5), infectiousness_onset=Int16(6), recovery=Int16(20)), pid)
            @test is_asymptomatic(i_asymp, reg, pid, Int16(10))
            @test isasymptomatic(i_asymp, reg, pid, Int16(10)) == is_asymptomatic(i_asymp, reg, pid, Int16(10))
            @test asymptomatic(i_asymp, reg, pid, Int16(10)) == is_asymptomatic(i_asymp, reg, pid, Int16(10))
            @test !is_asymptomatic(i, reg, pid, Int16(15))

            # is_quarantined / isquarantined / quarantined (with tick)
            i_quar = Individual(id=4, sex=1, age=40)
            quarantine_tick!(i_quar, Int16(5))
            quarantine_release_tick!(i_quar, Int16(10))
            @test !is_quarantined(i_quar, Int16(4))
            @test is_quarantined(i_quar, Int16(5))
            @test is_quarantined(i_quar, Int16(9))
            @test !is_quarantined(i_quar, Int16(10))
            @test isquarantined(i_quar, Int16(5)) == is_quarantined(i_quar, Int16(5))
            @test quarantined(i_quar, Int16(5)) == is_quarantined(i_quar, Int16(5))
        end

        @testset "Testing Registry" begin
            treg = TestRegistry()
            i_tr = Individual(id=1, sex=0, age=30)
            pid_tr = Int8(1)

            # defaults before any test
            @test last_test(i_tr, treg, pid_tr) == GEMS.DEFAULT_TICK
            @test last_test_result(i_tr, treg, pid_tr) == false
            @test !GEMS.was_reported(i_tr, treg, pid_tr)

            # positive reportable test sets last_test, last_test_result, was_reported and detected_mask
            record_test!(i_tr, treg, pid_tr, Int16(5), true, true)
            @test last_test(i_tr, treg, pid_tr) == Int16(5)
            @test last_test_result(i_tr, treg, pid_tr) == true
            @test was_reported(i_tr, treg, pid_tr)
            @test isdetected(i_tr, pid_tr)

            # sim wrappers route to the correct TestRegistry shard
            sim_tr = Simulation()
            i_tr2 = Individual(id=2, sex=0, age=30)
            record_test!(i_tr2, sim_tr, pid_tr, Int16(7), false, false)
            @test last_test(i_tr2, pid_tr, sim_tr) == Int16(7)
            @test last_test_result(i_tr2, pid_tr, sim_tr) == false
            @test !was_reported(i_tr2, pid_tr, sim_tr)
        end

        @testset "Quarantine" begin
            i = Individual(id=0, sex=1, age=42)

            @test quarantine_tick(i) == GEMS.DEFAULT_TICK
            @test quarantine_release_tick(i) == GEMS.DEFAULT_TICK
            @test !isquarantined(i)
            @test quarantine_status(i) == GEMS.QUARANTINE_STATE_NO_QUARANTINE

            quarantine_release_tick!(i, Int16(42))
            @test quarantine_release_tick(i) == 42

            quarantine_tick!(i, Int16(42))
            @test quarantine_tick(i) == 42

            home_quarantine!(i)
            @test isquarantined(i)
            @test quarantine_status(i) == GEMS.QUARANTINE_STATE_HOUSEHOLD_QUARANTINE

            end_quarantine!(i)
            @test !isquarantined(i)
            @test quarantine_status(i) == GEMS.QUARANTINE_STATE_NO_QUARANTINE

            hospitalized!(i, true)
            @test ishospitalized(i)
        end
    end
    
    @testset "Dict Constructor" begin
        # minimum required keys
        i = Individual(Dict("id" => 1, "sex" => 0, "age" => 25))
        @test id(i) == 1
        @test sex(i) == 0
        @test age(i) == 25

        # optional fields are applied when present
        i2 = Individual(Dict("id" => 2, "sex" => 1, "age" => 40, "education" => Int8(3), "occupation" => Int8(2)))
        @test education(i2) == 3
        @test occupation(i2) == 2

        # fields absent from dict keep their defaults
        @test education(i) == -1
        @test occupation(i) == -1
    end

    @testset "DataFrameRow Constructor" begin
        df = DataFrame(id = Int32[1, 2], age = Int8[25, 40], sex = Int8[0, 1],
                       education = Int8[3, -1], occupation = Int8[-1, 2])

        # minimum required fields
        i = Individual(df[1, :])
        @test typeof(i) == Individual
        @test id(i) == Int32(1)
        @test age(i) == Int8(25)
        @test sex(i) == Int8(0)

        # optional fields are set from the row when present
        @test education(i) == Int8(3)

        # second row
        i2 = Individual(df[2, :])
        @test id(i2) == Int32(2)
        @test occupation(i2) == Int8(2)
    end

    @testset "show" begin
        inds = [Individual(id=j, age=20, sex=0) for j in 1:3]
        @test !isempty(@capture_out show(inds))

        inds_large = [Individual(id=j, age=20, sex=0) for j in 1:51]
        output = @capture_out show(inds_large)
        @test !isempty(output)
        @test occursin("⋮", output)

        # single Individual show
        i_show = Individual(id=42, sex=2, age=35)
        output_single = @capture_out show(i_show)
        @test occursin("Individual", output_single)
        @test occursin("42", output_single)
        @test occursin("female", @capture_out show(Individual(id=1, sex=1, age=25)))
        @test occursin("male", @capture_out show(Individual(id=2, sex=2, age=30)))
        @test occursin("diverse", @capture_out show(Individual(id=3, sex=3, age=20)))
        @test occursin("n/a", @capture_out show(Individual(id=10, sex=0, age=18)))

        # extension fields appear in show output
        ae = AutoExtension((; my_score = 0.7f0))
        ind_ext = Individual(id=Int32(1), sex=Int8(0), age=Int8(30), extensions=ae)
        output_ext = @capture_out show(ind_ext)
        @test occursin("my_score", output_ext)
        @test occursin("0.7", output_ext)
    end

    @testset "Individual Extensions" begin

        mutable struct TestExt
            score::Float32
            label::Int8
        end

        @testset "Explicit mutable struct extension" begin
            ind = Individual(id=Int32(1), sex=Int8(0), age=Int8(30),
                             extensions=TestExt(0.8f0, Int8(2)))

            # transparent read access
            @test ind.score == 0.8f0
            @test ind.label == Int8(2)

            # base fields still work
            @test age(ind) == 30
            @test id(ind) == Int32(1)

            # transparent write access (in-place setfield!)
            ind.score = 0.5f0
            @test ind.score == 0.5f0

            ind.label = Int8(9)
            @test ind.label == Int8(9)

            # base field mutation still works
            ind.age = Int8(40)
            @test age(ind) == 40
        end

        @testset "AutoExtension from NamedTuple" begin
            nt = (score = 0.7f0, label = Int8(3))
            ae = AutoExtension(NamedTuple(nt))
            ind = Individual(id=Int32(2), sex=Int8(1), age=Int8(25),
                             extensions=ae)

            # transparent read
            @test ind.score == 0.7f0
            @test ind.label == Int8(3)

            # transparent write (replaces inner NT via merge)
            ind.score = 0.2f0
            @test ind.score == 0.2f0

            # other extension field unchanged after write
            @test ind.label == Int8(3)

            # base fields unaffected
            @test age(ind) == 25
        end

        @testset "Individual without extensions unaffected" begin
            ind = Individual(id=Int32(1), sex=Int8(0), age=Int8(20))
            @test typeof(ind) == Individual
            @test ind.extensions === nothing
        end
    end

    @testset "Settings Tuple" begin
    # Test individual with specific setting assignments
    i = Individual(id = 1, sex = 0, age = 1, household=10, office=20, schoolclass=30, municipality=40)
    res = settings_tuple(i)
    
    @test res isa Tuple
    @test length(res) == 4
    @test res[1] == (Household, Int32(10))
    @test res[2] == (Office, Int32(20))
    @test res[3] == (SchoolClass, Int32(30))
    @test res[4] == (Municipality, Int32(40))

    # Test default/undefined settings
    i_default = Individual(id=2, sex = 0, age = 1)
    @test all(pair -> pair[2] == GEMS.DEFAULT_SETTING_ID, settings_tuple(i_default))
    end
end