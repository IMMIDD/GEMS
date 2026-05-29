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
            
            # Modify health status
            infected!(i, true)
            infectious!(i, true)
            symptomatic!(i, true)
            severe!(i, true)
            hospitalized!(i, true)
            icu!(i, true)
            ventilated!(i, true)
            dead!(i, true)
            detected!(i, true)
            
            # Modify infection status
            i.pathogen_id = 1
            i.infection_id = 123
            i.infectiousness = 50
            i.number_of_infections = 2
            
            # Modify natural disease history
            exposure!(i, Int16(5))
            infectiousness_onset!(i, Int16(6))
            symptom_onset!(i, Int16(7))
            severeness_onset!(i, Int16(8))
            hospital_admission!(i, Int16(9))
            icu_admission!(i, Int16(10))
            icu_discharge!(i, Int16(11))
            ventilation_admission!(i, Int16(12))
            ventilation_discharge!(i, Int16(13))
            hospital_discharge!(i, Int16(14))
            severeness_offset!(i, Int16(15))
            recovery!(i, Int16(16))
            death!(i, Int16(17))
            
            # Modify Testing
            last_test!(i, Int16(10))
            last_test_result!(i, true)
            last_reported_at!(i, Int16(11))
            
            # Modify Vaccination
            i.vaccine_id = 2
            i.number_of_vaccinations = 1
            i.vaccination_tick = Int16(1)
            
            # Modify Interventions
            home_quarantine!(i)
            quarantine_tick!(i, Int16(5))
            quarantine_release_tick!(i, Int16(15))
            
            # Call the reset! function
            GEMS.reset!(i)
            
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
            
            # Assert infection status
            @test pathogen_id(i) == GEMS.DEFAULT_PATHOGEN_ID
            @test i.infection_id == GEMS.DEFAULT_INFECTION_ID
            @test i.infectiousness == 0
            @test i.number_of_infections == 0
            
            # Assert disease progression
            @test exposure(i) == GEMS.DEFAULT_TICK
            @test infectiousness_onset(i) == GEMS.DEFAULT_TICK
            @test symptom_onset(i) == GEMS.DEFAULT_TICK
            @test severeness_onset(i) == GEMS.DEFAULT_TICK
            @test hospital_admission(i) == GEMS.DEFAULT_TICK
            @test icu_admission(i) == GEMS.DEFAULT_TICK
            @test icu_discharge(i) == GEMS.DEFAULT_TICK
            @test ventilation_admission(i) == GEMS.DEFAULT_TICK
            @test ventilation_discharge(i) == GEMS.DEFAULT_TICK
            @test hospital_discharge(i) == GEMS.DEFAULT_TICK
            @test severeness_offset(i) == GEMS.DEFAULT_TICK
            @test recovery(i) == GEMS.DEFAULT_TICK
            @test death(i) == GEMS.DEFAULT_TICK
            
            # Assert testing & vaccines
            @test last_test(i) == GEMS.DEFAULT_TICK
            @test last_test_result(i) == false
            @test last_reported_at(i) == GEMS.DEFAULT_TICK
            @test i.vaccine_id == GEMS.DEFAULT_VACCINE_ID
            @test i.number_of_vaccinations == 0
            @test i.vaccination_tick == GEMS.DEFAULT_TICK
            
            # Assert Interventions
            @test quarantine_status(i) == GEMS.QUARANTINE_STATE_NO_QUARANTINE
            @test quarantine_tick(i) == GEMS.DEFAULT_TICK
            @test quarantine_release_tick(i) == GEMS.DEFAULT_TICK
        end

        @testset "Disease Progression & Hospitalization" begin
            @testset "Times Setter & Getter" begin
                i = Individual(id = 1, sex = 0, age = 31)
                # testing default ticks in disease progression
                getter = [  exposure,
                            infectiousness_onset,
                            symptom_onset,
                            severeness_onset,
                            hospital_admission,
                            icu_admission,
                            icu_discharge,
                            ventilation_admission,
                            ventilation_discharge,
                            hospital_discharge,
                            severeness_offset,
                            recovery,
                            death
                        ]
                for g in getter
                    # test default
                    @test g(i) == GEMS.DEFAULT_TICK
                end

                # test if setter for the ticks do work
                for f in getter
                    setter = getfield(GEMS, Symbol(string(f)*"!"))
                    setter(i, Int16(42))
                    for g in getter
                        if g==f
                            @test g(i) == 42
                        else
                            @test g(i) == GEMS.DEFAULT_TICK
                        end
                    end
                    setter(i, Int16(GEMS.DEFAULT_TICK)) # reset the time for the tests
                end
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
            i = Individual(id=1, sex=1, age=30)
            exposure!(i, Int16(5))
            infectiousness_onset!(i, Int16(7))
            symptom_onset!(i, Int16(10))
            severeness_onset!(i, Int16(15))
            severeness_offset!(i, Int16(20))
            hospital_admission!(i, Int16(15))
            hospital_discharge!(i, Int16(25))
            icu_admission!(i, Int16(15))
            icu_discharge!(i, Int16(18))
            ventilation_admission!(i, Int16(15))
            ventilation_discharge!(i, Int16(17))
            recovery!(i, Int16(30))
            last_reported_at!(i, Int16(12))

            # is_infected / isinfected / infected
            @test !is_infected(i, Int16(4))
            @test is_infected(i, Int16(5))
            @test is_infected(i, Int16(20))
            @test !is_infected(i, Int16(30))
            @test isinfected(i, Int16(10)) == is_infected(i, Int16(10))
            @test infected(i, Int16(10)) == is_infected(i, Int16(10))

            # is_exposed / isexposed / exposed
            @test !is_exposed(i, Int16(4))
            @test is_exposed(i, Int16(5))
            @test is_exposed(i, Int16(6))
            @test !is_exposed(i, Int16(7))
            @test isexposed(i, Int16(5)) == is_exposed(i, Int16(5))
            @test exposed(i, Int16(5)) == is_exposed(i, Int16(5))

            # is_infectious / isinfectious / infectious
            @test !is_infectious(i, Int16(6))
            @test is_infectious(i, Int16(7))
            @test is_infectious(i, Int16(15))
            @test !is_infectious(i, Int16(30))
            @test isinfectious(i, Int16(7)) == is_infectious(i, Int16(7))
            @test infectious(i, Int16(7)) == is_infectious(i, Int16(7))

            # is_presymptomatic / ispresymptomatic / presymptomatic
            @test is_presymptomatic(i, Int16(7))
            @test is_presymptomatic(i, Int16(9))
            @test !is_presymptomatic(i, Int16(10))
            @test !is_presymptomatic(i, Int16(4))
            @test ispresymptomatic(i, Int16(7)) == is_presymptomatic(i, Int16(7))
            @test presymptomatic(i, Int16(7)) == is_presymptomatic(i, Int16(7))

            # is_symptomatic / issymptomatic / symptomatic
            @test !is_symptomatic(i, Int16(9))
            @test is_symptomatic(i, Int16(10))
            @test is_symptomatic(i, Int16(25))
            @test !is_symptomatic(i, Int16(30))
            @test issymptomatic(i, Int16(10)) == is_symptomatic(i, Int16(10))
            @test symptomatic(i, Int16(10)) == is_symptomatic(i, Int16(10))

            # is_severe / issevere / severe
            @test !is_severe(i, Int16(14))
            @test is_severe(i, Int16(15))
            @test is_severe(i, Int16(19))
            @test !is_severe(i, Int16(20))
            @test issevere(i, Int16(15)) == is_severe(i, Int16(15))
            @test severe(i, Int16(15)) == is_severe(i, Int16(15))

            # is_mild / ismild / mild
            @test is_mild(i, Int16(12))
            @test !is_mild(i, Int16(15))
            @test ismild(i, Int16(12)) == is_mild(i, Int16(12))
            @test mild(i, Int16(12)) == is_mild(i, Int16(12))

            # is_hospitalized / ishospitalized / hospitalized
            @test !is_hospitalized(i, Int16(14))
            @test is_hospitalized(i, Int16(15))
            @test is_hospitalized(i, Int16(24))
            @test !is_hospitalized(i, Int16(25))
            @test ishospitalized(i, Int16(15)) == is_hospitalized(i, Int16(15))
            @test hospitalized(i, Int16(15)) == is_hospitalized(i, Int16(15))

            # is_icu / isicu / icu
            @test !is_icu(i, Int16(14))
            @test is_icu(i, Int16(15))
            @test is_icu(i, Int16(17))
            @test !is_icu(i, Int16(18))
            @test isicu(i, Int16(15)) == is_icu(i, Int16(15))
            @test icu(i, Int16(15)) == is_icu(i, Int16(15))

            # is_ventilated / isventilated / ventilated
            @test !is_ventilated(i, Int16(14))
            @test is_ventilated(i, Int16(15))
            @test is_ventilated(i, Int16(16))
            @test !is_ventilated(i, Int16(17))
            @test isventilated(i, Int16(15)) == is_ventilated(i, Int16(15))
            @test ventilated(i, Int16(15)) == is_ventilated(i, Int16(15))

            # is_recovered / isrecovered / recovered
            @test !is_recovered(i, Int16(29))
            @test is_recovered(i, Int16(30))
            @test is_recovered(i, Int16(50))
            @test isrecovered(i, Int16(30)) == is_recovered(i, Int16(30))
            @test recovered(i, Int16(30)) == is_recovered(i, Int16(30))

            # is_detected / isdetected / detected
            @test is_detected(i, Int16(12))
            @test isdetected(i, Int16(12)) == is_detected(i, Int16(12))
            @test detected(i, Int16(12)) == is_detected(i, Int16(12))
            i_undetected = Individual(id=99, sex=0, age=20)
            exposure!(i_undetected, Int16(5))
            recovery!(i_undetected, Int16(20))
            @test !is_detected(i_undetected, Int16(10))

            # is_dead / isdead / dead
            i_dead = Individual(id=2, sex=2, age=60)
            exposure!(i_dead, Int16(5))
            death!(i_dead, Int16(15))
            @test !is_dead(i_dead, Int16(14))
            @test is_dead(i_dead, Int16(15))
            @test isdead(i_dead, Int16(15)) == is_dead(i_dead, Int16(15))
            @test dead(i_dead, Int16(15)) == is_dead(i_dead, Int16(15))

            # is_asymptomatic / isasymptomatic / asymptomatic
            i_asymp = Individual(id=3, sex=0, age=25)
            exposure!(i_asymp, Int16(5))
            recovery!(i_asymp, Int16(20))
            @test is_asymptomatic(i_asymp, Int16(10))
            @test isasymptomatic(i_asymp, Int16(10)) == is_asymptomatic(i_asymp, Int16(10))
            @test asymptomatic(i_asymp, Int16(10)) == is_asymptomatic(i_asymp, Int16(10))
            @test !is_asymptomatic(i, Int16(15))

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
        @test typeof(i) == Individual{Nothing}
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
    end

    @testset "Individual Extensions" begin

        # Helper extension struct used across sub-tests
        mutable struct TestExt
            score::Float32
            label::Int8
        end

        @testset "Explicit mutable struct extension" begin
            ind = Individual{TestExt}(id=Int32(1), sex=Int8(0), age=Int8(30),
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
            ind = Individual{typeof(ae)}(id=Int32(2), sex=Int8(1), age=Int8(25),
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

        @testset "Individual{Nothing} unaffected" begin
            ind = Individual(id=Int32(1), sex=Int8(0), age=Int8(20))
            @test typeof(ind) == Individual{Nothing}
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