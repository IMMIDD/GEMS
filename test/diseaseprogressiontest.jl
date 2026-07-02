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

        # severe progression
        DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            severeness_offset = 40,
            recovery = 45
        )

        # critical progression
        DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            critical_onset = 35,
            critical_offset = 50,
            severeness_offset = 51,
            recovery = 55
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

        # severeness onset without severeness offset
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            recovery = 34
        )

        # critical onset before severeness onset
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            critical_onset = 29,
            critical_offset = 50,
            severeness_offset = 51,
            recovery = 55
        )

        # critical onset without severeness onset
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            critical_onset = 35,
            critical_offset = 50,
            recovery = 55
        )

        # critical offset before critical onset
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            critical_onset = 35,
            critical_offset = 34,
            severeness_offset = 51,
            recovery = 55
        )

        # critical onset without critical offset
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            critical_onset = 35,
            severeness_offset = 51,
            recovery = 55
        )

        # symptom onset after recovery
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 27,
            recovery = 26,
        )

        # severeness onset after recovery
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 28,
            severeness_offset = 29,
            recovery = 27,
        )

        # critical offset after recovery
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 28,
            critical_onset = 30,
            critical_offset = 39,
            severeness_offset = 35,
            recovery = 38,
        )
    end

    @testset "show" begin
        dp = DiseaseProgression(exposure = 1, infectiousness_onset = 2, symptom_onset = 3, recovery = 10)
        @test !isempty(@capture_out show(dp))
    end

    @testset "Getter & Setter" begin
        dp = DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            critical_onset = 35,
            critical_offset = 50,
            severeness_offset = 51,
            recovery = 55
        )

        @test exposure(dp) == 23
        @test infectiousness_onset(dp) == 25
        @test symptom_onset(dp) == 26
        @test severeness_onset(dp) == 30
        @test critical_onset(dp) == 35
        @test critical_offset(dp) == 50
        @test severeness_offset(dp) == 51
        @test recovery(dp) == 55
    end

    @testset "States" begin
        dp = DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 27,
            severeness_onset = 30,
            critical_onset = 35,
            critical_offset = 50,
            severeness_offset = 51,
            recovery = 55
        )

        a_dp = DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            recovery = 31
        )

        # infected
        @test infected(dp, Int16(25)) == true
        @test infected(dp, Int16(22)) == false # before
        @test infected(dp, Int16(56)) == false # after

        # infectious
        @test infectious(dp, Int16(27)) == true
        @test infectious(dp, Int16(24)) == false # before
        @test infectious(dp, Int16(56)) == false # after

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

        @test presymptomatic(a_dp, Int16(24)) == false # asymptomatic can never be presymptomatic

        # symptomatic
        @test symptomatic(dp, Int16(28)) == true
        @test symptomatic(dp, Int16(32)) == true # also true with severe/critical symptoms
        @test symptomatic(dp, Int16(22)) == false # before
        @test symptomatic(dp, Int16(56)) == false # after

        @test symptomatic(a_dp, Int16(26)) == false # asymptomatic can never be symptomatic

        # mild
        @test mild(dp, Int16(28)) == true
        @test mild(dp, Int16(31)) == false # with severe symptoms
        @test mild(dp, Int16(25)) == false # before

        @test mild(a_dp, Int16(26)) == false # asymptomatic can never be mild

        # severe
        @test severe(dp, Int16(31)) == true
        @test severe(dp, Int16(29)) == false # before
        @test severe(dp, Int16(52)) == false # after

        @test severe(a_dp, Int16(26)) == false # asymptomatic can never be severe

        # critical
        @test critical(dp, Int16(36)) == true
        @test critical(dp, Int16(34)) == false # before
        @test critical(dp, Int16(51)) == false # after

        @test critical(a_dp, Int16(26)) == false # asymptomatic can never be critical

        # recovered
        @test recovered(dp, Int16(56)) == true
        @test recovered(dp, Int16(54)) == false # before

        @test recovered(a_dp, Int16(32)) == true
        @test recovered(a_dp, Int16(30)) == false # before
    end
end
