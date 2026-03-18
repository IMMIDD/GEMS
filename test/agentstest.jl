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
            @test comorbidities(i) == Bool[]
            @test household_id(i) == GEMS.DEFAULT_SETTING_ID
            @test office_id(i) == GEMS.DEFAULT_SETTING_ID
            @test class_id(i) == GEMS.DEFAULT_SETTING_ID
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
    i = Individual(id=1, household=10, office=20, schoolclass=30, municipality=40)
    res = settings_tuple(i)
    
    @test res isa Tuple
    @test length(res) == 4
    @test res[1] == (Household, Int32(10))
    @test res[2] == (Office, Int32(20))
    @test res[3] == (SchoolClass, Int32(30))
    @test res[4] == (Municipality, Int32(40))

    # Test default/undefined settings
    i_default = Individual(id=2)
    @test all(pair -> pair[2] == GEMS.DEFAULT_SETTING_ID, settings_tuple(i_default))
end
end