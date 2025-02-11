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
                getter = [  exposed_tick,
                            infectious_tick,
                            onset_of_symptoms,
                            onset_of_severeness,
                            hospitalized_tick,
                            ventilation_tick,
                            icu_tick,
                            death_tick,
                            removed_tick
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
            @testset "Disease Setter & Getter" begin
                i = Individual(id = 1, sex = 0, age = 31)
                # defaults
                getter = [symptomatic, presymptomatic, severe, critical]
                for g in getter
                    @test g(i) == false
                end

                @test exposed(i) == false
                p = Pathogen(id = 1, name = "COVID")
                infect!(i, Int16(0), p)
                @test exposed(i) == true

                # setters should be exclusive to each other
                for f in getter
                    setter = getfield(GEMS, Symbol(string(f)*"!"))
                    setter(i)
                    for g in getter
                        if g==f
                            @test g(i) == true
                        else
                            @test g(i) == false
                        end
                    end
                end
            end
        end 
        @testset "Quarantine" begin
            i = Individual(id=0, sex=1, age=42)

            @testset quarantine_tick(i) == GEMS.DEFAULT_TICK
            @testset quarantine_release_tick(i) == GEMS.DEFAULT_TICK
            @testset !isquarantined(i)
            @testset quarantine_status(i) == GEMS.QUARANTINE_STATE_NO_QUARANTINE

            quarantine_release_tick!(i, Int16(42))
            @test quarantine_release_tick(i) == 42

            quarantine_tick!(i, Int16(42))
            @test quarantine_tick(i) == 42

            home_quarantine!(i)
            @testset isquarantined(i)
            @testset quarantine_status(i) == GEMS.QUARANTINE_STATE_HOUSEHOLD_QUARANTINE

            end_quarantine!(i)
            @testset !isquarantined(i)
            @testset quarantine_status(i) == GEMS.QUARANTINE_STATE_NO_QUARANTINE

            hospitalize!(i)
            @testset isquarantined(i)
            @testset quarantine_status(i) == GEMS.QUARANTINE_STATE_HOSPITAL
        end
    end
end