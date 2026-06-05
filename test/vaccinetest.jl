@testset "Vaccines" begin

    v = Vaccine(id=1, name="Antitest", target_pathogen_id=Int8(1))

    @testset "Getter" begin
        @test id(v) == 1
        @test name(v) == "Antitest"
        @test typeof(logger(v)) == VaccinationLogger
    end

    @testset "Vaccinate Individuals" begin
        i = Individual(id = 1, sex = 0, age = 31, household=1)
        reg = ImmunityRegistry()
        pid = target_pathogen_id(v)

        @test number_of_vaccinations(i, reg, pid) == 0
        @test !isvaccinated(i, reg, pid)
        vaccinate!(i, reg, v, Int16(42))
        @test isvaccinated(i, reg, pid)
        @test vaccine_id(i, reg, pid) == 1
        @test vaccination_tick(i, reg, pid) == Int16(42)
        @test number_of_vaccinations(i, reg, pid) == 1

        # sim wrappers route to the correct ImmunityRegistry shard
        sim_v = Simulation()
        i_v = Individual(id=1, sex=0, age=30)
        vaccinate!(i_v, sim_v, v, Int16(10))
        @test isvaccinated(i_v, sim_v, pid)
        @test vaccine_id(i_v, sim_v, pid) == 1
        @test vaccination_tick(i_v, sim_v, pid) == Int16(10)
        @test number_of_vaccinations(i_v, sim_v, pid) == 1
    end

end
