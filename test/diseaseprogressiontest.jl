@testset "Disease Progression" begin

    @testset "Internal Logic" begin
        # THINGS THAT SHOULD WORK
        
        # asymptomatic progression
        DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            recovery = 31
        )

        # mild symptomatic progression
        DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            recovery = 34
        )

        # severe symptomatic progression
        DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            severeness_offset = 40,
            recovery = 45
        )

        # hospitalized progression
        DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            hospital_admission = 35,
            hospital_discharge = 50,
            severeness_offset = 51,
            recovery = 55
        )

        # icu'd progression
        DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            hospital_admission = 35,
            icu_admission = 40,
            icu_discharge = 60,
            hospital_discharge = 65,
            severeness_offset = 66,
            recovery = 70
        )

        # ventilated progression
        DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            hospital_admission = 35,
            icu_admission = 40,
            ventilation_admission = 45,
            ventilation_discharge = 70,
            icu_discharge = 75,
            hospital_discharge = 80,
            severeness_offset = 81,
            recovery = 85
        )

        # death
        DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            death = 70,
            severeness_offset = 70
        )

        # death in ICU
        DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            hospital_admission = 35,
            icu_admission = 40,
            death = 70,
            severeness_offset = 70,
            icu_discharge = 70,
            hospital_discharge = 70
        )

        # ventilation throughout ICU
        DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            hospital_admission = 35,
            ventilation_admission = 40,
            icu_admission = 45,
            icu_discharge = 60,
            ventilation_discharge = 65,
            hospital_discharge = 70,
            severeness_offset = 71,
            recovery = 75
        )

        # THINGS THAT SHOULD NOT WORK
        @test_throws ArgumentError DiseaseProgression()

        # no exposure
        @test_throws ArgumentError DiseaseProgression(
            infectiousness_onset = 25,
            recovery = 31
        )
        # no recovery
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25
        )

        # no infectiousness onset
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            recovery = 31
        )

        # recovery before infectiousness onset
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            recovery = 24
        )

        # severeness onset before symptom onset
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 24,
            severeness_offset = 32,
            recovery = 34
        )

        # severeness offset before severeness onset
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            severeness_offset = 29,
            recovery = 34
        )

        # hospital admission before severeness onset
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            hospital_admission = 29,
            hospital_discharge = 50,
            severeness_offset = 51,
            recovery = 55
        )

        # hospital discharge before hospital admission
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            hospital_admission = 35,
            hospital_discharge = 34,
            severeness_offset = 51,
            recovery = 55
        )

        # icu admission before hospital admission
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            hospital_admission = 35,
            icu_admission = 34,
            icu_discharge = 60,
            hospital_discharge = 65,
            severeness_offset = 66,
            recovery = 70
        )

        # icu discharge before icu admission
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            hospital_admission = 35,
            icu_admission = 40,
            icu_discharge = 39,
            hospital_discharge = 65,
            severeness_offset = 66,
            recovery = 70
        )

        # death without symptoms
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            death = 29,
        )

        # symptom onset after death or recovery
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 27,
            death = 26,
        )
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 27,
            recovery = 26,
        )

        # severeness onset after death or recovery
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 28,
            death = 27,
        )
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 28,
            recovery = 27,
        )

        # hospital admission after death or recovery
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            hospital_admission = 36,
            death = 35,
        )
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            hospital_admission = 36,
            recovery = 35,
        )

        # icu admission after death or recovery
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            hospital_admission = 35,
            icu_admission = 41,
            death = 40,
        )
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            hospital_admission = 35,
            icu_admission = 41,
            recovery = 40,
        )

        # ventilation admission after death or recovery
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            hospital_admission = 35,
            icu_admission = 40,
            ventilation_admission = 46,
            death = 45,
        )
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            hospital_admission = 35,
            icu_admission = 40,
            ventilation_admission = 46,
            recovery = 45,
        )
        
    end

    @testset "Getter & Setter" begin
        dp = DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            hospital_admission = 35,
            icu_admission = 40,
            ventilation_admission = 45,
            ventilation_discharge = 70,
            icu_discharge = 75,
            hospital_discharge = 80,
            severeness_offset = 81,
            recovery = 85
        )

        @test exposure(dp) == 23
        @test infectiousness_onset(dp) == 25
        @test symptom_onset(dp) == 26
        @test severeness_onset(dp) == 30
        @test hospital_admission(dp) == 35
        @test icu_admission(dp) == 40
        @test ventilation_admission(dp) == 45
        @test ventilation_discharge(dp) == 70
        @test icu_discharge(dp) == 75
        @test hospital_discharge(dp) == 80
        @test severeness_offset(dp) == 81
        @test recovery(dp) == 85

        dp = DiseaseProgression(
            exposure = 10,
            infectiousness_onset = 12,
            symptom_onset = 13,
            death = 20,
        )

        @test death(dp) == 20
    end

    @testset "States" begin
        dp = DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 27,
            severeness_onset = 30,
            hospital_admission = 35,
            icu_admission = 40,
            ventilation_admission = 45,
            ventilation_discharge = 70,
            icu_discharge = 75,
            hospital_discharge = 80,
            severeness_offset = 81,
            recovery = 85
        )

        a_dp = DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            recovery = 31
        )

        d_dp = DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            death = 70,
        )
        

        # infected
        @test infected(dp, Int16(25)) == true
        @test infected(dp, Int16(22)) == false # before
        @test infected(dp, Int16(86)) == false # after

        # infectious
        @test infectious(dp, Int16(27)) == true
        @test infectious(dp, Int16(24)) == false # before
        @test infectious(dp, Int16(86)) == false # after

        # asymptomatic
        @test asymptomatic(dp, Int16(24)) == false
        @test asymptomatic(dp, Int16(28)) == false

        @test asymptomatic(a_dp, Int16(26)) == true
        @test asymptomatic(a_dp, Int16(22)) == false # before
        @test asymptomatic(a_dp, Int16(32)) == false # after


        # pre-symptomatic
        @test presymptomatic(dp, Int16(26)) == true
        @test presymptomatic(dp, Int16(22)) == false # before
        @test presymptomatic(dp, Int16(28)) == false # after

        @test presymptomatic(a_dp, Int16(24)) == false # asympptomatic can never be presymptomatic

        # symptomatic
        @test symptomatic(dp, Int16(28)) == true
        @test symptomatic(dp, Int16(32)) == true # also true with severe symptoms
        @test symptomatic(dp, Int16(22)) == false # before
        @test symptomatic(dp, Int16(86)) == false # after

        @test symptomatic(a_dp, Int16(26)) == false # asymptomatic can never be symptomatic

        # mild
        @test mild(dp, Int16(28)) == true
        @test mild(dp, Int16(31)) == false # with severe symptoms
        @test mild(dp, Int16(25)) == false # before

        @test mild(a_dp, Int16(26)) == false # asymptomatic can never be mild

        # severe
        @test severe(dp, Int16(31)) == true
        @test severe(dp, Int16(29)) == false # before
        @test severe(dp, Int16(82)) == false # after

        @test severe(a_dp, Int16(26)) == false # asymptomatic can never be severe

        # hospitalized
        @test hospitalized(dp, Int16(36)) == true
        @test hospitalized(dp, Int16(34)) == false # before
        @test hospitalized(dp, Int16(81)) == false # after

        @test hospitalized(a_dp, Int16(26)) == false # asymptomatic can never be hospitalized

        # icu
        @test icu(dp, Int16(41)) == true
        @test icu(dp, Int16(39)) == false # before
        @test icu(dp, Int16(76)) == false # after

        @test icu(a_dp, Int16(26)) == false # asymptomatic can never be in icu

        # ventilated
        @test ventilated(dp, Int16(46)) == true
        @test ventilated(dp, Int16(44)) == false # before
        @test ventilated(dp, Int16(71)) == false # after

        @test ventilated(a_dp, Int16(26)) == false # asymptomatic can never be ventilated

        # recovered
        @test recovered(dp, Int16(86)) == true
        @test recovered(dp, Int16(84)) == false # before

        @test recovered(a_dp, Int16(32)) == true
        @test recovered(a_dp, Int16(30)) == false # before

        # dead
        @test dead(dp, Int16(86)) == false
        @test dead(dp, Int16(84)) == false # before

        @test dead(d_dp, Int16(71)) == true
        @test dead(d_dp, Int16(69)) == false # before
    end
end