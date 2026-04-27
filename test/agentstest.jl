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