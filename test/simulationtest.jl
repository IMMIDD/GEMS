@testset "Simulation" begin

    # global parameters
    BASE_FOLDER = dirname(dirname(pathof(GEMS)))

    @testset "Initialization" begin
        @testset "Basic" begin
            # empty
            sim = Simulation()
            @test tick(sim) == 0
        end

        @testset "Dict Constructor" begin
            # Simulation(params::Dict) splats the dict as keyword arguments;
            # this constructor is the Dict-based entry point tested here.

            # basic: pop_size and seed are forwarded correctly
            sim = Simulation(Dict(:pop_size => 100, :seed => 42))
            @test population(sim) |> size == 100
            @test sim.seed == 42

            # label is forwarded
            sim = Simulation(Dict(:pop_size => 100, :label => "dict_label"))
            @test label(sim) == "dict_label"

            # tickunit is forwarded
            sim = Simulation(Dict(:pop_size => 100, :tickunit => 'd'))
            @test tickunit(sim) == "day"

            # validation still fires: invalid pop_size propagates ArgumentError
            @test_throws ArgumentError Simulation(Dict(:pop_size => -1))

            # validation still fires: invalid seed propagates ArgumentError
            @test_throws ArgumentError Simulation(Dict(:pop_size => 100, :seed => -1))
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
            @test population(sim) |> size >= 300000

            # things that should fail
            @test_throws ArgumentError Simulation(population = "test/not/existing/file.csv")
            @test_throws ArgumentError Simulation(population = "ABC")
        end

        @testset "General Parameters" begin
            # SEED
            # passing
            sim = Simulation(pop_size = 100, seed = 1234)
            @test sim.seed == 1234
            sim1 = Simulation(pop_size = 100)
            sim2 = Simulation(pop_size = 100)
            @test sim1.seed != sim2.seed # different seeds when none is provided
            
            # failing
            @test_throws ArgumentError Simulation(pop_size = 100, seed = "1234")
            @test_throws ArgumentError Simulation(pop_size = 100, seed = -1234)
            
            # TICKUNIT
            # passing
            sim = Simulation(pop_size = 100, tickunit = 'h')
            @test tickunit(sim) == "hour"
            sim = Simulation(pop_size = 100, tickunit = 'd')
            @test tickunit(sim) == "day"
            sim = Simulation(pop_size = 100, tickunit = 'w')
            @test tickunit(sim) == "week"
            # failing
            @test_throws ArgumentError Simulation(pop_size = 100, tickunit = 'g')
            @test_throws ArgumentError Simulation(pop_size = 100, tickunit = "abc")

            # START DATE & END DATE
            # passing
            sim = Simulation(pop_size = 100, start_date = "2020-01-01")
            @test sim.startdate == Date("2020-01-01")
            sim = Simulation(pop_size = 100, start_date = Date("2021-01-01"))
            @test sim.startdate == Date("2021-01-01")
            sim = Simulation(pop_size = 100, end_date = Date("2030-12-31"))
            @test sim.enddate == Date("2030-12-31")
            # failing
            @test_throws ArgumentError Simulation(pop_size = 100, start_date = 20200101)
            @test_throws ArgumentError Simulation(pop_size = 100, start_date = "abc")
            @test_throws ArgumentError Simulation(pop_size = 100, end_date = 20211231)
            @test_throws ArgumentError Simulation(pop_size = 100, end_date = "abc")

            # failing: end date before start date
            @test_throws ArgumentError Simulation(pop_size = 100, end_date = "2020-01-01", start_date = "2021-01-01")

            # LABEL
            # passing
            sim = Simulation(pop_size = 100, label = "test_sim")
            @test label(sim) == "test_sim"
            sim = Simulation(pop_size = 100, label = 123)
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
            sim = Simulation(pop_size = 100)
            @test population(sim) |> size == 100
            # failing
            @test_throws ArgumentError Simulation(pop_size = -100)
            @test_throws ArgumentError Simulation(pop_size = 0)
            @test_throws TypeError Simulation(pop_size = 10.5)
            @test_throws TypeError Simulation(pop_size = "1000")

            # AVG HOUSEHOLD SIZE
            # passing
            sim = Simulation(pop_size = 100, avg_household_size = 4)
            @test size.(households(sim)) |> mean ≈ 4 atol=.5
            # failing
            @test_throws ArgumentError Simulation(pop_size = 100, avg_household_size = -4)
            @test_throws ArgumentError Simulation(pop_size = 100, avg_household_size = 0)
            @test_throws ArgumentError Simulation(pop_size = 100, avg_household_size = 105)

            # AVG OFFICE SIZE
            # passing
            sim = Simulation(pop_size = 100, avg_office_size = 10)
            @test size.(offices(sim)) |> mean ≈ 10 atol=2 # this is quite broad, but the assignment to schools is not very strict and filters out "empty" offices
            # failing
            @test_throws ArgumentError Simulation(pop_size = 100, avg_office_size = -10)
            @test_throws ArgumentError Simulation(pop_size = 100, avg_office_size = 0)
            @test_throws ArgumentError Simulation(pop_size = 100, avg_office_size = 105)

            # AVG SCHOOL SIZE
            # passing
            sim = Simulation(pop_size = 1000, avg_school_size = 20)
            @test size.(schoolclasses(sim)) |> mean ≈ 20 atol=5 # this is quite broad, but the assignment to schools is not very strict and filters out "empty" schools
            # failing
            @test_throws ArgumentError Simulation(pop_size = 100, avg_school_size = -20)
            @test_throws ArgumentError Simulation(pop_size = 100, avg_school_size = 0)
            @test_throws ArgumentError Simulation(pop_size = 100, avg_school_size = 105)

            # GLOBAL SETTING
            # passing
            sim = Simulation(pop_size = 100, global_setting = true)
            @test length(settings(sim, GlobalSetting)) == 1
            sim = Simulation(pop_size = 100, global_setting = false)
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
            @test_throws ArgumentError Simulation(pop_size = 100, household_contacts = -0.1)
            @test_throws ArgumentError Simulation(pop_size = 100, household_contacts = "none")
            @test_throws ArgumentError Simulation(pop_size = 100, office_contacts = -0.1)
            @test_throws ArgumentError Simulation(pop_size = 100, office_contacts = "none")
            @test_throws ArgumentError Simulation(pop_size = 100, department_contacts = -0.1)
            @test_throws ArgumentError Simulation(pop_size = 100, department_contacts = "none")
            @test_throws ArgumentError Simulation(pop_size = 100, workplace_contacts = -0.1)
            @test_throws ArgumentError Simulation(pop_size = 100, workplace_contacts = "none")
            @test_throws ArgumentError Simulation(pop_size = 100, workplace_site_contacts = -0.1)
            @test_throws ArgumentError Simulation(pop_size = 100, workplace_site_contacts = "none")
            @test_throws ArgumentError Simulation(pop_size = 100, school_class_contacts = -0.1)
            @test_throws ArgumentError Simulation(pop_size = 100, school_class_contacts = "none")
            @test_throws ArgumentError Simulation(pop_size = 100, school_year_contacts = -0.1)
            @test_throws ArgumentError Simulation(pop_size = 100, school_year_contacts = "none")
            @test_throws ArgumentError Simulation(pop_size = 100, school_contacts = -0.1)
            @test_throws ArgumentError Simulation(pop_size = 100, school_contacts = "none")
            @test_throws ArgumentError Simulation(pop_size = 100, school_complex_contacts = -0.1)
            @test_throws ArgumentError Simulation(pop_size = 100, school_complex_contacts = "none")
            @test_throws ArgumentError Simulation(pop_size = 100, municipality_contacts = -0.1)
            @test_throws ArgumentError Simulation(pop_size = 100, municipality_contacts = "none")

            # global setting contacts
            @test_throws ArgumentError Simulation(pop_size = 100, global_setting = false, global_setting_contacts = 0.1)
            @test_throws ArgumentError Simulation(pop_size = 100, global_setting_contacts = 0.1)
            @test_throws ArgumentError Simulation(pop_size = 100, global_setting = true, global_setting_contacts = -0.1)
            @test_throws ArgumentError Simulation(pop_size = 100, global_setting = true, global_setting_contacts = "none")
        
        end

        @testset "Start Conditions & Stop Criteria" begin
            # START CONDITION
            # passing
            sim = Simulation(pop_size = 100, start_condition = PatientZero())
            @test count(infected, population(sim)) == 1
            sim = Simulation(pop_size = 100, infected_fraction = 0.11)
            @test count(infected, population(sim)) == 11
            # failing
            @test_throws ArgumentError Simulation(pop_size = 100, start_condition = "none")

            # STOP CONDITION
            # passing
            sim = Simulation(pop_size = 100, stop_criterion = TimesUp(limit = 11))
            run!(sim)
            @test tick(sim) == 11
            # failing
            @test_throws ArgumentError Simulation(pop_size = 100, stop_criterion = "none")
        end

        @testset "Interface Fallbacks" begin
            sim = Simulation(pop_size = 100)

            # Concrete types that DO override limit should return the correct value.
            @test limit(TimesUp(limit = 7)) == 7

            # StopCriterion without a fixed limit (e.g. NoneInfected) returns nothing.
            @test isnothing(limit(NoneInfected()))
        end

        @testset "Pathogen" begin
            # PATHOGEN
            # passing
            p = Pathogen(id=1, name="Test")
            sim = Simulation(pop_size = 100, pathogen = p)
            @test pathogen(sim) === p
            # failing
            @test_throws ArgumentError Simulation(pop_size = 100, pathogen = "none")

            # TRANSMISSION FUNCTION
            # passing
            tf = ConstantTransmissionRate(transmission_rate = 0.5)
            sim = Simulation(pop_size = 100, transmission_function = tf)
            @test transmission_function(pathogen(sim)) === tf
            # failing
            @test_throws ArgumentError Simulation(pop_size = 100, transmission_function = "none")

            # TRANSMISSION RATE
            # passing
            sim = Simulation(pop_size = 100, transmission_rate = 0.111)
            @test transmission_function(pathogen(sim)) isa ConstantTransmissionRate
            @test transmission_function(pathogen(sim)).transmission_rate == 0.111
            # failing
            @test_throws ArgumentError Simulation(pop_size = 100, transmission_rate = -0.1)
            @test_throws ArgumentError Simulation(pop_size = 100, transmission_rate = 1.1)
            @test_throws TypeError Simulation(pop_size = 100, transmission_rate = "0.1")
        end
        @testset "Stepmod" begin
            global cntr = 0
            sim = Simulation(pop_size = 100, stop_criterion = TimesUp(limit = 5),
                stepmod = sim -> (global cntr += 1)) # count five times
            run!(sim)
            @test cntr == 5
        end
        @testset "Reset" begin
            sim = Simulation(pop_size=100)
            
            # Simulate a few steps manually
            increment!(sim)
            increment!(sim)
            @test tick(sim) == 2
            
            # Infect the first individual
            ind = individuals(sim)[1]
            infected!(ind, true)
            
            # Add data to loggers
            log!(deathlogger(sim), Int32(1), Int16(2))
            @test length(deathlogger(sim)) == 1
            
            # Add NPI triggers and strategies
            test_strategy = IStrategy("test strategy", sim)
            add_symptom_trigger!(sim, SymptomTrigger(test_strategy))
            @test length(symptom_triggers(sim)) == 1
            @test length(strategies(sim)) == 1
            
            # Reset keeping interventions
            reset!(sim, reset_interventions=false)
            @test tick(sim) == 0
            @test !isinfected(individuals(sim)[1])
            @test length(deathlogger(sim)) == 0
            @test length(symptom_triggers(sim)) == 1
            @test length(strategies(sim)) == 1

            # Reset clearing interventions
            reset!(sim, reset_interventions=true)
            @test length(symptom_triggers(sim)) == 0
            @test length(strategies(sim)) == 0

            # reinitialize! is an alias for reset! kept for backwards compatibility.
            # It must behave identically to reset! in both modes.
            sim2 = Simulation(pop_size=100)
            increment!(sim2)
            increment!(sim2)
            @test tick(sim2) == 2

            strat2 = IStrategy("reinit_strategy", sim2)
            add_symptom_trigger!(sim2, SymptomTrigger(strat2))
            @test length(symptom_triggers(sim2)) == 1

            # reinitialize! without resetting interventions: tick resets, triggers survive
            reinitialize!(sim2, reset_interventions=false)
            @test tick(sim2) == 0
            @test length(symptom_triggers(sim2)) == 1

            # advance a tick again so we can verify reinitialize! resets it
            increment!(sim2)
            @test tick(sim2) == 1

            # reinitialize! with reset_interventions=true: both tick and triggers reset
            reinitialize!(sim2, reset_interventions=true)
            @test tick(sim2) == 0
            @test length(symptom_triggers(sim2)) == 0
        end

        @testset "Warn Paths" begin
            # determine_start_date: no startdate in config -> warns, defaults to today()
            result = @test_logs (:warn, r"Start date") GEMS.determine_start_date(Dict(), nothing)
            @test result == today()

            # determine_end_date: no enddate in config -> warns, defaults to today()+Year(1)
            result = @test_logs (:warn, r"End date") GEMS.determine_end_date(Dict(), nothing)
            @test result == today() + Year(1)

            # determine_tick_unit: not in config -> warns, defaults to 'd'
            result = @test_logs (:warn, r"Tick unit") GEMS.determine_tick_unit(Dict(), nothing)
            @test result == 'd'

            # determine_global_setting: not in config -> warns, defaults to false
            result = @test_logs (:warn, r"Global setting") GEMS.determine_global_setting(Dict(), nothing)
            @test result == false

            # determine_start_condition: both start_condition and infected_fraction -> warns, uses start_condition
            sc_ref = PatientZero()
            result = @test_logs (:warn, r"infected_fraction will be ignored") GEMS.determine_start_condition(
                Dict("Simulation" => Dict("StartCondition" => Dict("type" => "PatientZero", "parameters" => Dict()))),
                sc_ref, 0.1)
            @test result === sc_ref

            # determine_pathogen: pathogen + transmission_rate -> warns, uses pathogen
            p_ref = Pathogen(id=1, name="TestPathogen")
            result = @test_logs (:warn, r"transmission_rate will be ignored") GEMS.determine_pathogen(Dict(), p_ref, nothing, 0.5)
            @test result === p_ref

            # determine_setting_type_config!: setting type not in config -> warns
            sim_w = Simulation(pop_size=100)
            sc_w = settingscontainer(sim_w)
            @test_logs (:warn, r"settings not found in config file") GEMS.determine_setting_type_config!(sc_w, Household, Dict())

            # determine_setting_type_config!: section present but no contact_sampling_method -> warns
            @test_logs (:warn, r"contact_sampling_method") GEMS.determine_setting_type_config!(sc_w, Household, Dict("Settings" => Dict("Household" => Dict())))

            # determine_pathogen: transmission_function + transmission_rate -> warns, tf wins
            default_config = GEMS.load_configfile(GEMS.configfile_path(""))
            tf_ref2 = ConstantTransmissionRate(transmission_rate=0.3)
            @test_logs (:warn, r"transmission_rate will be ignored") GEMS.determine_pathogen(default_config, nothing, tf_ref2, 0.5)

            # determine_population_and_settings: string path + pop_size -> warns, path wins
            pop_path_warn = joinpath(BASE_FOLDER, "test/testdata/TestPop.csv")
            sim_str = Simulation(population=pop_path_warn, pop_size=999)
            @test population(sim_str) |> size == 100

            # transmission_function + transmission_rate: tf wins, rate ignored
            tf_ref = ConstantTransmissionRate(transmission_rate=0.3)
            sim_tf = Simulation(pop_size=100, transmission_function=tf_ref, transmission_rate=0.9)
            @test transmission_function(pathogen(sim_tf)) === tf_ref

            # Population object + pop_size: object wins, pop_size ignored
            pop_obj = Population(n=200, rng=Xoshiro())
            sim_pop = Simulation(population=pop_obj, pop_size=100)
            @test population(sim_pop) |> size == 200
        end

        @testset "Throw Paths (ConfigfileError)" begin
            @test_throws GEMS.ConfigfileError Simulation(configfile="/nonexistent/path/to/config.toml")

            # load_configfile: existing file that is not a .toml
            @test_throws GEMS.ConfigfileError Simulation(configfile=joinpath(BASE_FOLDER, "test/testdata/TestPop.csv"))

            pop_path = joinpath(BASE_FOLDER, "test/testdata/people_muenster.jld2")
            @test_throws ArgumentError Simulation(population=pop_path, settingsfile="notajld2file.csv")

            @test_throws GEMS.ConfigfileError GEMS.determine_start_condition(Dict(), nothing, nothing)
            @test_throws GEMS.ConfigfileError GEMS.determine_stop_criterion(Dict(), nothing)
            @test_throws GEMS.ConfigfileError GEMS.determine_pathogen(Dict(), nothing, nothing, nothing)

            # determine_start_date: config has unparseable date value
            @test_throws GEMS.ConfigfileError GEMS.determine_start_date(Dict("Simulation" => Dict("startdate" => "date")), nothing)

            # determine_end_date: config has unparseable date value
            @test_throws GEMS.ConfigfileError GEMS.determine_end_date(Dict("Simulation" => Dict("enddate" => "date")), nothing)

            # determine_tick_unit: config has multi-character value (only() throws)
            @test_throws Exception GEMS.determine_tick_unit(Dict("Simulation" => Dict("tickunit" => "abc")), nothing)

            # determine_global_setting: config has non-Bool value
            @test_throws ArgumentError GEMS.determine_global_setting(Dict("Simulation" => Dict("GlobalSetting" => 1)), nothing)

            # determine_seed: config has non-integer seed
            @test_throws ArgumentError GEMS.determine_seed(Dict("Simulation" => Dict("seed" => "abc")), nothing)

            # create_pathogen: bad progressions
            @test_throws GEMS.ConfigfileError GEMS.create_pathogen(
                Dict("progressions" => Dict("Symptomatic" => Dict())),
                "test", Int8(1))

            # create_pathogen: bad progression assignment
            valid_prog = Dict("Symptomatic" => Dict(
                "exposure_to_infectiousness_onset" => 3,
                "infectiousness_onset_to_symptom_onset" => 2,
                "symptom_onset_to_recovery" => 5))
            @test_throws GEMS.ConfigfileError GEMS.create_pathogen(
                Dict(
                    "progressions" => valid_prog,
                    "progression_assignment" => Dict(
                        "type" => "RandomProgressionAssignment",
                        "parameters" => Dict("progression_categories" => []))),
                "test", Int8(1))

            # create_pathogen: bad transmission function
            valid_pa = Dict(
                "type" => "RandomProgressionAssignment",
                "parameters" => Dict("progression_categories" => ["Symptomatic"]))
            @test_throws GEMS.ConfigfileError GEMS.create_pathogen(
                Dict(
                    "progressions" => valid_prog,
                    "progression_assignment" => valid_pa,
                    "transmission_function" => Dict(
                        "type" => "ConstantTransmissionRate",
                        "parameters" => Dict("transmission_rate" => 2.0))),
                "test", Int8(1))

            # determine_start_condition: invalid constructor params
            @test_throws GEMS.ConfigfileError GEMS.determine_start_condition(
                Dict("Simulation" => Dict("StartCondition" => Dict(
                    "type" => "InfectedFraction",
                    "parameters" => Dict("fraction" => 2.0)))),
                nothing, nothing)

            # determine_stop_criterion: invalid constructor params
            @test_throws GEMS.ConfigfileError GEMS.determine_stop_criterion(
                Dict("Simulation" => Dict("StopCriterion" => Dict(
                    "type" => "TimesUp",
                    "parameters" => Dict("limit" => 0)))),
                nothing)
        end

        @testset "Throw Paths (ErrorException)" begin
            # create_progression: missing required fields
            @test_throws ErrorException GEMS.create_progression(Dict(), "Symptomatic")

            # create_progression_assignment: empty categories
            @test_throws ErrorException GEMS.create_progression_assignment(
                Dict("type" => "RandomProgressionAssignment",
                    "parameters" => Dict("progression_categories" => [])))

            # create_transmission_function: rate out of range
            @test_throws ErrorException GEMS.create_transmission_function(
                Dict("type" => "ConstantTransmissionRate",
                    "parameters" => Dict("transmission_rate" => 2.0)))

            # create_start_condition: fraction out of range
            @test_throws ErrorException GEMS.create_start_condition(
                Dict("type" => "InfectedFraction",
                    "parameters" => Dict("fraction" => 2.0)))

            # create_stop_criterion: limit out of range
            @test_throws ErrorException GEMS.create_stop_criterion(
                Dict("type" => "TimesUp",
                    "parameters" => Dict("limit" => 0)))
        end

        @testset "global_setting non-Bool throws" begin
            @test_throws ArgumentError Simulation(pop_size=100, global_setting=1)
            @test_throws ArgumentError Simulation(pop_size=100, global_setting="true")
        end
    end

    @testset "Start Conditions" begin
        # INFECTED FRACTION
        # failing
        @test_throws ArgumentError InfectedFraction(fraction = -0.1)
        @test_throws ArgumentError InfectedFraction(fraction = 1.1)
        # passing
        inff = InfectedFraction(fraction = 0.1)
        @test fraction(inff) == 0.1
        sim = Simulation(pop_size = 100, start_condition = inff)
        @test count(infected, population(sim)) == 10

        # PATIENT ZERO
        pz = PatientZero()
        sim = Simulation(pop_size = 100, start_condition = pz)
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

        # REGIONAL SEEDS
        # failing
        @test_throws ArgumentError RegionalSeeds(seeds = Dict{Int64,Int64}())
        @test_throws ArgumentError RegionalSeeds(seeds = Dict(123 => 1))

        # passing: constructor and accessors
        rs = RegionalSeeds(seeds = Dict(04011000 => 3, 04012000 => 2))
        @test seeds(rs) == Dict(04011000 => 3, 04012000 => 2)
        @test pathogen(rs) == ""
        @test pathogen(RegionalSeeds(pathogen = "flu", seeds = Dict(04011000 => 1))) == "flu"

        # passing: initialize! infects the correct total count
        hb_seeds = Dict(04011000 => 3, 04012000 => 2)
        sim = Simulation(population = "HB", start_condition = RegionalSeeds(seeds = hb_seeds))
        @test count(infected, population(sim)) == 5

        # passing: all infected individuals come from the seeded regions
        @test individuals(sim) |>
            inds -> inds[infected.(inds)] |>
            infs -> (i -> ags(household(i, sim))).(infs) |>
            h_ags -> all(a -> a in AGS.(keys(hb_seeds)), h_ags)

        # passing: seed_sample gives reproducible results
        cond = RegionalSeeds(seeds = Dict(04011000 => 3))
        seed_sim = Simulation(population = "HB")
        initialize!(seed_sim, cond, seed_sample = 42)
        infs_first = copy(individuals(seed_sim)[infected.(individuals(seed_sim))])
        reset!(seed_sim)
        initialize!(seed_sim, cond, seed_sample = 42)
        @test individuals(seed_sim)[infected.(individuals(seed_sim))] == infs_first
    end

    @testset "Parameter Tests" begin

        @testset "AGS Test" begin
            @test_throws ArgumentError AGS(Int(123))
            @test_throws ArgumentError AGS(Int32(123))
            @test_throws ArgumentError AGS("123")

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

    @testset "Calibration" begin
        
        @testset "Error Metrics" begin
            # Test norm calculations used in calibration
            ref_ts = [1.0, 2.0, 3.0]
            sim_ts = [1.1, 1.9, 3.2]
            
            @test GEMS.mae(sim_ts, ref_ts) ≈ (0.1 + 0.1 + 0.2) / 3
            @test GEMS.rmse(sim_ts, ref_ts) ≈ sqrt((0.01 + 0.01 + 0.04) / 3)
        end

        @testset "assign_values_to_parameters!" begin
            sim = Simulation(pop_size=100)
            
            # Provide initial setup
            for s in settings(sim, Household)
                s.contact_sampling_method = GEMS.ContactparameterSampling(0.0)
            end
            
            # Run parameter assignment for a setting
            GEMS.assign_values_to_parameters!(sim, x=[0.15], arg=["households"])
            
            # Assert parameter has successfully changed
            for s in settings(sim, Household)
                @test s.contact_sampling_method.contactparameter == 0.15
            end

            # Ordinary Parameter
            sim.seed = 1 # Reset seed
            GEMS.assign_values_to_parameters!(sim, x=[42], arg=["seed"])
            @test sim.seed == 42
            
            GEMS.assign_values_to_parameters!(sim, x=[0.75], arg=["sim.pathogen.transmission_function.transmission_rate"])
            @test sim.pathogen.transmission_function.transmission_rate == 0.75
        end
        
        using Random # for setting the seed

        @testset "calibrate!" begin
            # Make the stochastic optimizer deterministic for this test
            Random.seed!(42) 
            
            sim = Simulation(pop_size=100)
            
            # dummy reference data
            ref_data = [50.0]
            
            # Use a continuous parameter that exists in your model, like a modifier or rate
            p_args = ["sim.pathogen.transmission_function.transmission_rate"]
            initial_x = [10.0]
            
            # dummy target function: just returns the current value of the parameter
            dummy_target_fn(s) = [s.pathogen.transmission_function.transmission_rate] 
            
            # Call calibrate! 
            res = GEMS.calibrate!(
                sim;
                target = dummy_target_fn,
                loss = GEMS.rmse,
                ref_ts = ref_data,
                arg_x0 = p_args,
                x0 = initial_x,
                lower_limit = [0.0],
                upper_limit = [100.0],
                n = 1,
                maxiters = 5,
                plot_training = false
            )
            
            # Verify that the Optimization returned a valid result object
            @test res !== nothing
            
            # Verify that the optimizer moved `x` towards our target of 50.0
            @test res.u[1] > 10.0 
        end     
    end

    @testset "Helper Functions" begin
        sim = Simulation(pop_size = 100)

        output = @capture_out info(sim)
        @test !isempty(output)

        # info: strategies branch (length > 0)
        sim_with_strategy = Simulation(pop_size=100)
        IStrategy("test_strategy", sim_with_strategy)
        output_with_strategy = @capture_out info(sim_with_strategy)
        @test occursin("test_strategy", output_with_strategy)

        # pathogen! setter
        new_pathogen = deepcopy(pathogen(sim))
        pathogen!(sim, new_pathogen)
        @test pathogen(sim) === new_pathogen
    end

    @testset "stepmod Getter" begin
        sim_default = Simulation(pop_size=100)
        @test stepmod(sim_default) isa Function

        my_fn = s -> nothing
        sim_custom = Simulation(pop_size=100, stepmod=my_fn)
        @test stepmod(sim_custom) === my_fn
    end

    @testset "Base.show" begin
        sim = Simulation(pop_size=100)
        output = @capture_out show(sim)
        @test !isempty(output)
        @test occursin("Simulation", output)
        @test occursin("100", output)
        @test occursin(label(sim), output)
    end

    @testset "DataFrame Access Functions" begin
        sim = Simulation(pop_size=100, start_condition=PatientZero(), stop_criterion=TimesUp(limit=10))
        run!(sim)

        @test infections(sim) isa DataFrame
        @test deaths(sim) isa DataFrame
        @test tests(sim) isa DataFrame
        @test quarantines(sim) isa DataFrame
        @test pooltests(sim) isa DataFrame
        @test seroprevalencetests(sim) isa DataFrame
        @test customlogs(sim) isa DataFrame

        pop_df = populationDF(sim)
        @test pop_df isa DataFrame
        @test nrow(pop_df) == population(sim) |> size

        st_df = states(sim)
        @test st_df isa DataFrame
        @test nrow(st_df) == 10
        @test hasproperty(st_df, :tick)
        @test hasproperty(st_df, :exposed)
        @test hasproperty(st_df, :infectious)
        @test hasproperty(st_df, :quarantined)

        @test infectionlogger(sim) isa InfectionLogger
        @test deathlogger(sim) isa DeathLogger
        @test testlogger(sim) isa GEMS.TestLogger
        @test pooltestlogger(sim) isa PoolTestLogger
        @test seroprevalencelogger(sim) isa SeroprevalenceLogger
        @test quarantinelogger(sim) isa QuarantineLogger
        @test statelogger(sim) isa StateLogger
        @test customlogger(sim) isa CustomLogger
    end

    @testset "Simulation Acceleration (Dormancy)" begin
        @testset "is_dormant evaluation" begin
            sim = Simulation(pop_size = 100)
            
            # tick 0: state logger is empty, so it should not be dormant yet
            @test GEMS.is_dormant(sim) == false
            
            # take one real step to populate the loggers with zeros
            step!(sim)
            @test tick(sim) == 1
            
            # tick 1: 0 infections, 0 quarantines logged, so it should be dormant
            @test GEMS.is_dormant(sim) == true
            
            # inject manual states into the logger to test the macroscopic wake-up logic
            tid = Threads.threadid()
            
            # test Infectious wake-up
            push!(statelogger(sim).infectious, 1)
            @test GEMS.is_dormant(sim) == false
            pop!(statelogger(sim).infectious) # revert
            
            # test Exposed wake-up
            push!(statelogger(sim).exposed, 1)
            @test GEMS.is_dormant(sim) == false
            pop!(statelogger(sim).exposed) # revert
            
            # test Quarantine wake-up
            push!(statelogger(sim).quarantined, 1)
            @test GEMS.is_dormant(sim) == false
            pop!(statelogger(sim).quarantined) # revert
            
            # Ensure it goes back to sleep when all states are 0
            @test GEMS.is_dormant(sim) == true
        end

        @testset "copy_last_log_state" begin
            sim = Simulation(pop_size = 100)
            @test tick(sim) == 0
            
            # populate initial empty state (generates log entry for tick 1)
            step!(sim)
            @test tick(sim) == 1
            
            # manually increment tick to simulate next step loop
            sim.tick += 1
            @test tick(sim) == 2
            
            # trigger the function to copy previous step's state 
            GEMS.copy_last_log_state(sim)
            
            # verify the statelogger
            sl = statelogger(sim)
            df = dataframe(sl)
            
            # total rows should be 2 (tick 1 + tick 2)
            @test nrow(df) == 2 
            
            # the last recorded tick in the logger should be 2 
            @test df.tick[end] == 2
            
            # Verify the states are properly copied and haven't arbitrarily spiked
            @test df.exposed[end] == 0
            @test df.infectious[end] == 0
            @test df.quarantined[end] == 0
        end
    end

    @testset "Simulation Buffers" begin
        sim = Simulation()
        num_threads = Threads.maxthreadid()
        
        @test length(present_buffers(sim)) == num_threads
        @test length(contact_buffers(sim)) == num_threads
        
        # Verify they are actual individual vectors
        @test present_buffers(sim)[1] isa Vector{Individual}

        # rngs returns one Xoshiro RNG per thread, seeded from the simulation seed.
        rng_vec = rngs(sim)
        @test rng_vec isa Vector{Xoshiro}
        @test length(rng_vec) == num_threads

        # Each simulation gets its own independent RNG vector.
        sim2 = Simulation()
        @test rngs(sim2) !== rngs(sim)

        # A simulation constructed with a fixed seed produces a reproducible RNG state.
        simA = Simulation(pop_size=100, seed=999)
        simB = Simulation(pop_size=100, seed=999)
        @test rand(rngs(simA)[1]) == rand(rngs(simB)[1])
    end
end