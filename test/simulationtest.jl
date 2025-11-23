@testset "Simulation" begin

    # global parameters
    BASE_FOLDER = dirname(dirname(pathof(GEMS)))

    @testset "Initialization" begin
        @testset "Basic" begin
            # empty
            sim = Simulation()
            @test tick(sim) == 0
        end

        @testset "From Disk" begin
            # from CSV population file
            path = joinpath(BASE_FOLDER, "test/testdata/TestPop.csv")
            sim = Simulation(population = path)
            @test population(sim).params["populationfile"] == path
            @test population(sim) |> size == 100

            # from JLD2 population file
            path = joinpath(BASE_FOLDER, "test/testdata/people_muenster.jld2")
            sim = Simulation(population = path)
            @test !(Workplace in settings(sim) |> keys |> collect) # workplaces should not be available 

            # from JLD2 population & settings file
            pop_path = joinpath(BASE_FOLDER, "test/testdata/people_muenster.jld2")
            set_path = joinpath(BASE_FOLDER, "test/testdata/settings_muenster.jld2")
            sim = Simulation(population = pop_path, settingsfile = set_path)
            @test Workplace in settings(sim) |> keys |> collect # workplaces should only be available through settings file

            # from custom config file
            path = joinpath(BASE_FOLDER, "test/testdata/TestConf.toml")
            sim = Simulation(configfile = path)
            @test configfile(sim) == path
            @test population(sim) |> size == 1_000

            # from custom config file and population file
            con_path = joinpath(BASE_FOLDER, "test/testdata/TestConf.toml")
            pop_path = joinpath(BASE_FOLDER, "test/testdata/TestPop.csv")
            sim = Simulation(configfile = con_path, population = pop_path)
            @test population(sim) |> size == 100

            # from custom config file and additonal arguments
            con_path = joinpath(BASE_FOLDER, "test/testdata/TestConf.toml")
            sim = Simulation(configfile = con_path, label = "test_sim")
            @test label(sim) == "test_sim"

            # from remote population
            sim = Simulation(population = "HB")
            @test population(sim) |> size == 676255

            # things that should fail
            @test_throws ArgumentError Simulation(population = "test/not/existing/file.csv")
            @test_throws ArgumentError Simulation(population = "ABC")
        end

        @testset "General Parameters" begin
            # SEED
            # passing
            sim = Simulation(pop_size = 1_000, seed = 1234)
            @test sim.seed == 1234
            sim1 = Simulation(pop_size = 1_000)
            sim2 = Simulation(pop_size = 1_000)
            @test sim1.seed != sim2.seed # different seeds when none is provided
            
            # failing
            @test_throws ArgumentError Simulation(pop_size = 1_000, seed = "1234")
            @test_throws ArgumentError Simulation(pop_size = 1_000, seed = -1234)
            
            # TICKUNIT
            # passing
            sim = Simulation(pop_size = 1_000, tickunit = 'h')
            @test tickunit(sim) == "hour"
            sim = Simulation(pop_size = 1_000, tickunit = 'd')
            @test tickunit(sim) == "day"
            sim = Simulation(pop_size = 1_000, tickunit = 'w')
            @test tickunit(sim) == "week"
            # failing
            @test_throws ArgumentError Simulation(pop_size = 1_000, tickunit = 'g')
            @test_throws ArgumentError Simulation(pop_size = 1_000, tickunit = "abc")

            # START DATE & END DATE
            # passing
            sim = Simulation(pop_size = 1_000, start_date = "2020-01-01")
            @test sim.startdate == Date("2020-01-01")
            sim = Simulation(pop_size = 1_000, start_date = Date("2021-01-01"))
            @test sim.startdate == Date("2021-01-01")
            sim = Simulation(pop_size = 1_000, end_date = Date("2030-12-31"))
            @test sim.enddate == Date("2030-12-31")
            # failing
            @test_throws ArgumentError Simulation(pop_size = 1_000, start_date = 20200101)
            @test_throws ArgumentError Simulation(pop_size = 1_000, start_date = "abc")
            @test_throws ArgumentError Simulation(pop_size = 1_000, end_date = 20211231)
            @test_throws ArgumentError Simulation(pop_size = 1_000, end_date = "abc")

            # failing: end date before start date
            @test_throws ArgumentError Simulation(pop_size = 1_000, end_date = "2020-01-01", start_date = "2021-01-01")

            # LABEL
            # passing
            sim = Simulation(pop_size = 1_000, label = "test_sim")
            @test label(sim) == "test_sim"
            sim = Simulation(pop_size = 1_000, label = 123)
            @test label(sim) == "123"
        end

        @testset "Population & Settings" begin
            # POPULATION
            # passing
            sim = Simulation(population = Population(n = 500, rng = Xoshiro()))
            @test population(sim) |> size == 500
            # other population initializations are testesd in "From Disk" above

            # failing
            @test_throws ArgumentError Simulation(population = 123)

            # POP SIZE
            # passing
            sim = Simulation(pop_size = 1_000)
            @test population(sim) |> size == 1_000
            # failing
            @test_throws ArgumentError Simulation(pop_size = -100)
            @test_throws ArgumentError Simulation(pop_size = 0)
            @test_throws TypeError Simulation(pop_size = 10.5)
            @test_throws TypeError Simulation(pop_size = "1000")

            # AVG HOUSEHOLD SIZE
            # passing
            sim = Simulation(pop_size = 1_000, avg_household_size = 4)
            @test size.(households(sim)) |> mean ≈ 4 atol=.5
            # failing
            @test_throws ArgumentError Simulation(pop_size = 1_000, avg_household_size = -4)
            @test_throws ArgumentError Simulation(pop_size = 1_000, avg_household_size = 0)
            @test_throws ArgumentError Simulation(pop_size = 100, avg_household_size = 105)

            # AVG OFFICE SIZE
            # passing
            sim = Simulation(pop_size = 1_000, avg_office_size = 10)
            @test size.(offices(sim)) |> mean ≈ 10 atol=2 # this is quite broad, but the assignment to schools is not very strict and filters out "empty" offices
            # failing
            @test_throws ArgumentError Simulation(pop_size = 1_000, avg_office_size = -10)
            @test_throws ArgumentError Simulation(pop_size = 1_000, avg_office_size = 0)
            @test_throws ArgumentError Simulation(pop_size = 100, avg_office_size = 105)

            # AVG SCHOOL SIZE
            # passing
            sim = Simulation(pop_size = 1_000, avg_school_size = 20)
            @test size.(schoolclasses(sim)) |> mean ≈ 20 atol=5 # this is quite broad, but the assignment to schools is not very strict and filters out "empty" schools
            # failing
            @test_throws ArgumentError Simulation(pop_size = 1_000, avg_school_size = -20)
            @test_throws ArgumentError Simulation(pop_size = 1_000, avg_school_size = 0)
            @test_throws ArgumentError Simulation(pop_size = 100, avg_school_size = 105)

            # GLOBAL SETTING
            # passing
            sim = Simulation(pop_size = 1_000, global_setting = true)
            @test length(settings(sim, GlobalSetting)) == 1
            sim = Simulation(pop_size = 1_000, global_setting = false)
            @test !haskey(settings(sim), GlobalSetting)
        end

        @testset "Contacts" begin
            # reference object
            sim = Simulation(population = "HB",
                global_setting = true, # needs to be true to set global_setting_contacts
                household_contacts = 0.111,
                office_contacts = 0.222,
                department_contacts = 0.333,
                workplace_contacts = 0.444,
                workplace_site_contacts = 0.555,
                school_class_contacts = 0.666,
                school_year_contacts = 0.777,
                school_contacts = 0.888,
                school_complex_contacts = 0.999,
                municipality_contacts = 1.111,
                global_setting_contacts = 1.222)

            #passing with numerical values
            @test households(sim)[1].contact_sampling_method.contactparameter == 0.111
            @test offices(sim)[1].contact_sampling_method.contactparameter == 0.222
            @test departments(sim)[1].contact_sampling_method.contactparameter == 0.333
            @test workplaces(sim)[1].contact_sampling_method.contactparameter == 0.444
            @test workplacesites(sim)[1].contact_sampling_method.contactparameter == 0.555
            @test schoolclasses(sim)[1].contact_sampling_method.contactparameter == 0.666
            @test schoolyears(sim)[1].contact_sampling_method.contactparameter == 0.777
            @test schools(sim)[1].contact_sampling_method.contactparameter == 0.888
            @test schoolcomplexes(sim)[1].contact_sampling_method.contactparameter == 0.999
            @test municipalities(sim)[1].contact_sampling_method.contactparameter == 1.111
            @test settings(sim, GlobalSetting)[1].contact_sampling_method.contactparameter == 1.222

            # passing with ContactparameterSampling objects
            hh_cps = ContactparameterSampling(0.5)
            of_cps = ContactparameterSampling(0.5)
            dp_cps = ContactparameterSampling(0.5)
            wp_cps = ContactparameterSampling(0.5)
            ws_cps = ContactparameterSampling(0.5)
            sc_cps = ContactparameterSampling(0.5)
            sy_cps = ContactparameterSampling(0.5)
            sh_cps = ContactparameterSampling(0.5)
            sx_cps = ContactparameterSampling(0.5)
            mu_cps = ContactparameterSampling(0.5)
            gs_cps = ContactparameterSampling(0.5)
            
            sim = Simulation(population = "HB",
                global_setting = true, # needs to be true to set global_setting_contacts
                household_contacts = hh_cps,
                office_contacts = of_cps,
                department_contacts = dp_cps,
                workplace_contacts = wp_cps,
                workplace_site_contacts = ws_cps,
                school_class_contacts = sc_cps,
                school_year_contacts = sy_cps,
                school_contacts = sh_cps,
                school_complex_contacts = sx_cps,
                municipality_contacts = mu_cps,
                global_setting_contacts = gs_cps)

            @test households(sim)[1].contact_sampling_method === hh_cps
            @test offices(sim)[1].contact_sampling_method === of_cps
            @test departments(sim)[1].contact_sampling_method === dp_cps
            @test workplaces(sim)[1].contact_sampling_method === wp_cps
            @test workplacesites(sim)[1].contact_sampling_method === ws_cps
            @test schoolclasses(sim)[1].contact_sampling_method === sc_cps
            @test schoolyears(sim)[1].contact_sampling_method === sy_cps
            @test schools(sim)[1].contact_sampling_method === sh_cps
            @test schoolcomplexes(sim)[1].contact_sampling_method === sx_cps
            @test municipalities(sim)[1].contact_sampling_method === mu_cps
            @test settings(sim, GlobalSetting)[1].contact_sampling_method === gs_cps
            

            # failing
            @test_throws ArgumentError Simulation(pop_size = 1_000, household_contacts = -0.1)
            @test_throws ArgumentError Simulation(pop_size = 1_000, household_contacts = "none")
            @test_throws ArgumentError Simulation(pop_size = 1_000, office_contacts = -0.1)
            @test_throws ArgumentError Simulation(pop_size = 1_000, office_contacts = "none")
            @test_throws ArgumentError Simulation(pop_size = 1_000, department_contacts = -0.1)
            @test_throws ArgumentError Simulation(pop_size = 1_000, department_contacts = "none")
            @test_throws ArgumentError Simulation(pop_size = 1_000, workplace_contacts = -0.1)
            @test_throws ArgumentError Simulation(pop_size = 1_000, workplace_contacts = "none")
            @test_throws ArgumentError Simulation(pop_size = 1_000, workplace_site_contacts = -0.1)
            @test_throws ArgumentError Simulation(pop_size = 1_000, workplace_site_contacts = "none")
            @test_throws ArgumentError Simulation(pop_size = 1_000, school_class_contacts = -0.1)
            @test_throws ArgumentError Simulation(pop_size = 1_000, school_class_contacts = "none")
            @test_throws ArgumentError Simulation(pop_size = 1_000, school_year_contacts = -0.1)
            @test_throws ArgumentError Simulation(pop_size = 1_000, school_year_contacts = "none")
            @test_throws ArgumentError Simulation(pop_size = 1_000, school_contacts = -0.1)
            @test_throws ArgumentError Simulation(pop_size = 1_000, school_contacts = "none")
            @test_throws ArgumentError Simulation(pop_size = 1_000, school_complex_contacts = -0.1)
            @test_throws ArgumentError Simulation(pop_size = 1_000, school_complex_contacts = "none")
            @test_throws ArgumentError Simulation(pop_size = 1_000, municipality_contacts = -0.1)
            @test_throws ArgumentError Simulation(pop_size = 1_000, municipality_contacts = "none")

            # global setting contacts
            @test_throws ArgumentError Simulation(pop_size = 1_000, global_setting = false, global_setting_contacts = 0.1)
            @test_throws ArgumentError Simulation(pop_size = 1_000, global_setting_contacts = 0.1)
            @test_throws ArgumentError Simulation(pop_size = 1_000, global_setting = true, global_setting_contacts = -0.1)
            @test_throws ArgumentError Simulation(pop_size = 1_000, global_setting = true, global_setting_contacts = "none")
        
        end

        @testset "Start Conditions & Stop Criteria" begin
            # START CONDITION
            # passing
            sim = Simulation(pop_size = 1_000, start_condition = PatientZero())
            @test count(infected, population(sim)) == 1
            sim = Simulation(pop_size = 1_000, infected_fraction = 0.011)
            @test count(infected, population(sim)) == 11
            # failing
            @test_throws ArgumentError Simulation(pop_size = 1_000, start_condition = "none")

            # STOP CONDITION
            # passing
            sim = Simulation(pop_size = 1_000, stop_criterion = TimesUp(limit = 11))
            run!(sim)
            @test tick(sim) == 11
            # failing
            @test_throws ArgumentError Simulation(pop_size = 1_000, stop_criterion = "none")
        end

        @testset "Pathogen" begin
            # PATHOGEN
            # passing
            p = Pathogen(id=1, name="Test")
            sim = Simulation(pop_size = 1_000, pathogen = p)
            @test pathogen(sim) === p
            # failing
            @test_throws ArgumentError Simulation(pop_size = 1_000, pathogen = "none")

            # TRANSMISSION FUNCTION
            # passing
            tf = ConstantTransmissionRate(transmission_rate = 0.5)
            sim = Simulation(pop_size = 1_000, transmission_function = tf)
            @test transmission_function(pathogen(sim)) === tf
            # failing
            @test_throws ArgumentError Simulation(pop_size = 1_000, transmission_function = "none")

            # TRANSMISSION RATE
            # passing
            sim = Simulation(pop_size = 1_000, transmission_rate = 0.111)
            @test transmission_function(pathogen(sim)) isa ConstantTransmissionRate
            @test transmission_function(pathogen(sim)).transmission_rate == 0.111
            # failing
            @test_throws ArgumentError Simulation(pop_size = 1_000, transmission_rate = -0.1)
            @test_throws ArgumentError Simulation(pop_size = 1_000, transmission_rate = 1.1)
            @test_throws TypeError Simulation(pop_size = 1_000, transmission_rate = "0.1")
        end
        @testset "Stepmod" begin
            global cntr = 0
            sim = Simulation(pop_size = 1_000, stop_criterion = TimesUp(limit = 5),
                stepmod = sim -> (global cntr += 1)) # count five times
            run!(sim)
            @test cntr == 5
        end
    
    end

    @testset "Start Conditions" begin
        # INFECTED FRACTION
        # failing
        @test_throws ArgumentError InfectedFraction(fraction = -0.1)
        @test_throws ArgumentError InfectedFraction(fraction = 1.1)
        # passing
        inff = InfectedFraction(fraction = 0.01)
        @test fraction(inff) == 0.01
        sim = Simulation(pop_size = 1_000, start_condition = inff)
        @test count(infected, population(sim)) == 10

        # PATIENT ZERO
        pz = PatientZero()
        sim = Simulation(pop_size = 1_000, start_condition = pz)
        @test count(infected, population(sim)) == 1

        # PATIENT ZEROS
        # failing
        @test_throws ArgumentError PatientZeros(ags = Int64[])
        # passing
        test_ags = [04011000, 04012000]
        pzs = PatientZeros(ags = test_ags)
        sim = Simulation(population = "HB", start_condition = pzs)
        @test count(infected, population(sim)) == 2
        @test individuals(sim) |>
            inds -> inds[infected.(inds)] |>
            infs -> (i -> household(i, sim)).(infs) |>
            hhlds -> ags.(hhlds) |>
            h_ags -> Set(h_ags) == Set(AGS.(test_ags))
    end

    @testset "Parameter Tests" begin

        @testset "AGS Test" begin
            @test_throws "The state (first two digits) must be between 1 and 16" AGS(Int(123))
            @test_throws "The state (first two digits) must be between 1 and 16" AGS(Int32(123))
            @test_throws "The AGS (Amtlicher Gemeindeschlüssel, eng: Community Identification Number) must consist of exactly 8 digits" AGS("123")

            münster = AGS("05515000")
            @test state(münster) == AGS("05000000")
            @test district(münster) == AGS("05500000")
            @test county(münster) == AGS("05515000")
            @test municipality(münster) == AGS("05515000")
            @test !is_state(münster)
            @test !is_district(münster)
            @test is_county(münster)
            nrw = AGS("05000000")
            regierungsbezirks_ms = AGS("05500000")
            @test in_state(münster, nrw)
            @test in_district(münster, regierungsbezirks_ms)
            @test in_county(münster, münster)
            @test !isunset(münster)
        end

        @testset "contact parameter sampling tests" begin
            @test_throws ArgumentError("'contactparameter' is -1.0, but the 'contactparameter' has to be non-negative!") ContactparameterSampling(-1.0)
            @test_throws ArgumentError("'contactparameter' is -1, but the 'contactparameter' has to be non-negative!") ContactparameterSampling(-1)
        end
    end

    @testset "Helper Functions" begin
        sim = Simulation(pop_size = 1_000)
        
        output = @capture_out info(sim)

        # test if someting is written to the console
        @test !isempty(output)
    end

end