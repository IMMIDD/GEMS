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
        end

        @testset "General Parameters" begin
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
            sim = Simulation(pop_size = 1_000, start_date = "2020.01.01")


        end
        
        @testset "Stepmod" begin
            
        end
    
    end

    

    # ### OLD TESTS ON SIMULATION OBJECT CHARACTERISTICS ###
    # # global parameters
    # BASE_FOLDER = dirname(dirname(pathof(GEMS)))

    # # Infected Fraction
    # p = Pathogen(id=1, name="COVID")
    # inf = InfectedFraction(0.01, p)

    # @testset "Start Conditions" begin
    #     @test fraction(inf) == 0.01
    #     @test pathogen(inf) == p
    # end

    # # TimesUp
    # tu = TimesUp(10)

    # @testset "Stop Criteria" begin
    #     @test limit(tu) == 10
    # end



    # # load population to fill Simulation object
    # popul = Population(BASE_FOLDER * "/test/testdata/TestPop.csv")
    # stngs, rnm = settings_from_population(popul)
    # households = get(stngs, Household)

    # # simulation struct
    # s = Simulation(
    #     "",
    #     inf,
    #     tu,
    #     popul,
    #     stngs,
    #     "test_label"
    # )

    # @testset "Simulation Creation and Management" begin

    #     @test tick(s) == 0
    #     @test start_condition(s) == inf
    #     @test stop_criterion(s) == tu
    #     @test population(s) == popul
    #     @test settings(s, Household) == get(s.settings, Household)

    #     # test if scheduler is empty TODO vaccination still testing?
    #     # @test typeof(vaccination_schedule(s)) == VaccinationScheduler
    #     # @test length(ticks(vaccination_schedule(s))) == 0

    #     # Evaluate TimesUp criterion / simulation should not have exceeded target tick
    #     @test evaluate(s, tu) == false

    #     increment!(s)
    #     @test tick(s) == 1

    #     reset!(s)
    #     @test tick(s) == 0

    #     # population Properties
    #     @test min_individuals(households, s) == 2
    #     @test max_individuals(households, s) == 10
    #     @test avg_individuals(households, s) == 5

    # end


    # @testset "Simulation Execution" begin

    #     # initialize model with 1% infections
    #     initialize!(s)
    #     noi = num_of_infected(population(s))
    #     # check whether number of infected individuals is about the same (1 individual tolerance)
    #     @test abs(fraction(inf) * length(individuals(population(s))) - noi) <= 1

    #     # test simulation run with criterion TimesUp after 10 ticks
    #     s = run!(s, with_progressbar=false)
    #     @test tick(s) == 10

    #     # simulation should have exceeded target tick
    #     @test evaluate(s, tu) == true
    # end


    # @testset "Initialization Old" begin
    #     basefolder = dirname(dirname(pathof(GEMS)))

    #     popfile = "test/testdata/TestPop.csv"
    #     populationpath = joinpath(basefolder, popfile)

    #     confile = "test/testdata/TestConf.toml"
    #     configpath = joinpath(basefolder, confile)

    #     sim = Simulation(configpath, populationpath)

    #     @test tick(sim) == 0
    #     @test cmp(configfile(sim), configpath) == 0
    #     @test cmp(populationfile(sim), populationpath) == 0
    #     @test haskey(sim.settings.settings, GlobalSetting)
    #     start = start_condition(sim)
    #     stop = stop_criterion(sim)

    #     @test typeof(start) == InfectedFraction
    #     @test fraction(start) == 0.05
    #     @test name(pathogen(start)) == "Test"
    #     @test id(pathogen(start)) == 1
    #     @test typeof(pathogen(start).infection_rate) == Uniform{Float64}
    #     @test typeof(pathogen(start).time_to_recovery) == Poisson{Float64}
    #     @test typeof(pathogen(start).mild_death_rate) == Uniform{Float64}
    #     @test length(disease_progression_strat(pathogen(start)).stratification_matrix) == 3
    #     @test length(disease_progression_strat(pathogen(start)).stratification_matrix[1]) == 4
    #     @test typeof(stop) == TimesUp
    #     @test limit(stop) == 240

    #     # Population to compare
    #     test_pop = Population(populationpath)
    #     ids_test = Set([id(individual) for individual in individuals(test_pop)])
    #     ids_sim = Set([id(individual) for individual in individuals(population(sim))])
    #     @test ids_test == ids_sim
    #     # check whether number of infected individuals is about the same (1 individual tolerance)
    #     @test abs(0.05 * length(individuals(population(sim))) - num_of_infected(population(sim))) <= 1

    #     test_settings, rnm = settings_from_population(test_pop)
    #     @test Set([id(s) for s in settings(sim, Household)]) == Set([id(s) for s in get(test_settings, Household)])
    # end

    # @testset "Sim-Constructor-Initialization" begin
    #     basefolder = dirname(dirname(pathof(GEMS)))

    #     popfile = "test/testdata/TestPop.csv"
    #     populationpath = joinpath(basefolder, popfile)

    #     confile = "test/testdata/TestConf.toml"
    #     configpath = joinpath(basefolder, confile)

    #     # testing default
    #     sim = Simulation()
    #     run!(sim)
    #     rd = ResultData(sim)

    #     # testing Configfile Constructors
    #     sim = Simulation(configfile=configpath)
    #     @test sim |> pathogen |> transmission_function |> parameters |>
    #           x -> x["parameters"]["transmission_rate"] == 0.04
    #     @test sim.configfile == configpath

    #     my_arguments = Dict(
    #         :label => "test",
    #         :configfile => configpath
    #     )
    #     sim = Simulation(my_arguments)
    #     @test sim |> pathogen |> transmission_function |> parameters |>
    #           x -> x["parameters"]["transmission_rate"] == 0.04
    #     @test sim.configfile == configpath
    #     @test sim |> label == "test"

    #     sim = Simulation(configpath, populationpath)
    #     @test sim |> pathogen |> transmission_function |> parameters |>
    #           x -> x["parameters"]["transmission_rate"] == 0.04
    #     @test sim |> population |> size == 100
    #     @test sim.configfile == configpath

    #     settingspath = joinpath(basefolder, "test/testdata/settings_muenster.jld2")
    #     pop_path = joinpath(basefolder, "test/testdata/people_muenster.jld2")
    #     sim = Simulation(configpath, pop_path, settingspath, label="test")
    #     @test sim |> label == "test"
    #     @test sim |> population |> size == 315305
    #     @test get(sim.settings, Household) |> length == 82152
    #     contact_rate = get(sim.settings, Household)[1].contact_sampling_method.contactparameter
    #     @test contact_rate == 1
    #     @test sim |> pathogen |> transmission_function |> parameters |>
    #           x -> x["parameters"]["transmission_rate"] == 0.04

    #     sim = Simulation(configpath, label="test")
    #     @test sim.configfile == configpath
    #     @test sim |> label == "test"

    #     sim = Simulation(configpath, populationpath, label="test")
    #     @test sim.configfile == configpath
    #     @test sim |> label == "test"


    #     # testing parameter constructor
    #     sim = Simulation(population=populationpath)
    #     test_pop = Population(populationpath)
    #     ids_test = Set([id(individual) for individual in individuals(test_pop)])
    #     ids_sim = Set([id(individual) for individual in individuals(population(sim))])
    #     @test ids_test == ids_sim

    #     sim = Simulation(population=Population(n=1000))
    #     @test sim |> population |> size == 1000

    #     sim = Simulation(population="HB")
    #     @test sim |> population |> size == 676255

    #     sim = Simulation(population=joinpath(basefolder, "test/testdata/TestPop.csv"))
    #     @test sim |> population |> size == 100

    #     settingspath = joinpath(basefolder, "test/testdata/settings_muenster.jld2")
    #     pop_path = joinpath(basefolder, "test/testdata/people_muenster.jld2")
    #     sim = Simulation(settingsfile=settingspath, population=pop_path)
    #     popul = Population(pop_path)
    #     stngs, rnm = settings_from_population(popul)
    #     households = get(stngs, Household)
    #     @test settings(sim, Household) == get(sim.settings, Household)
    #     # For other cases generate population with 1000 individuals

    #     sim = Simulation(Population(n=1000), label="test")
    #     @test sim |> label == "test"

    #     global testing_stepmod = 0
    #     function test_stepmod(sim)
    #         global testing_stepmod += 1
    #     end
    #     sim = Simulation(Population(n=1000), stepmod=test_stepmod)
    #     run!(sim)
    #     @test testing_stepmod == 365
    #     @test stepmod(sim) === test_stepmod

    #     # sim = Simulation(Population(n = 1000), seed = 1111)
    #     # TODO find test case

    #     sim = Simulation(Population(n=1000), global_setting=true)
    #     @test settings(sim, GlobalSetting) |> length == 1

    #     # TODO adapt next two when reworking dates
    #     sim = Simulation(Population(n=1000), startdate="2021.03.01")
    #     @test sim.startdate == Date("2021.03.01", dateformat"y.m.d")

    #     #sim = Simulation(Population(n=1000), enddate="2025.03.01")
    #     #@test sim.enddate == Date("2025.03.01", dateformat"y.m.d")

    #     sim = Simulation(Population(n=1000), infected_fraction = 0.05)
    #     @test sim |> start_condition |> fraction == 0.05

    #     sim = Simulation(Population(n=1000), transmission_rate = 0.8)
    #     @test sim |> pathogen |> transmission_function |> parameters |>
    #           x -> x["parameters"]["transmission_rate"] == 0.8

    #     sim = Simulation(Population(n=1000), onset_of_symptoms=0.3)
    #     @test sim |> pathogen |> onset_of_symptoms |> parameters |>
    #           x -> x["mean"] == 0.3

    #     sim = Simulation(Population(n=1000), onset_of_severeness=0.3)
    #     @test sim |> pathogen |> onset_of_severeness |> parameters |>
    #           x -> x["mean"] == 0.3

    #     sim = Simulation(Population(n=1000), infectious_offset=0.3)
    #     @test sim |> pathogen |> infectious_offset |> parameters |>
    #           x -> x["mean"] == 0.3

    #     sim = Simulation(Population(n=1000), mild_death_rate=0.2)
    #     @test sim |> pathogen |> mild_death_rate |> parameters |>
    #           x -> x["mean"] == 0.2

    #     sim = Simulation(Population(n=1000), severe_death_rate=0.5)
    #     @test sim |> pathogen |> severe_death_rate |> parameters |>
    #         x -> x["mean"] == 0.5
      

    #     sim = Simulation(Population(n=1000), critical_death_rate=0.2)
    #     @test sim |> pathogen |> critical_death_rate |> parameters |>
    #           x -> x["mean"] == 0.2

    #     sim = Simulation(Population(n=1000), hospitalization_rate=0.2)
    #     @test sim |> pathogen |> hospitalization_rate |> parameters |>
    #           x -> x["mean"] == 0.2

    #     sim = Simulation(Population(n=1000), ventilation_rate=0.2)
    #     @test sim |> pathogen |> ventilation_rate |> parameters |>
    #           x -> x["mean"] == 0.2

    #     sim = Simulation(Population(n=1000), icu_rate=0.2)
    #     @test sim |> pathogen |> icu_rate |> parameters |>
    #           x -> x["mean"] == 0.2

    #     sim = Simulation(Population(n=1000), time_to_recovery=0.3)
    #     @test sim |> pathogen |> time_to_recovery |> parameters |>
    #           x -> x["mean"] == 0.3

    #     sim = Simulation(Population(n=1000), time_to_hospitalization=0.3)
    #     @test sim |> pathogen |> time_to_hospitalization |> parameters |>
    #           x -> x["mean"] == 0.3

    #     sim = Simulation(Population(n=1000), time_to_icu=0.3)
    #     @test sim |> pathogen |> time_to_icu |> parameters |>
    #           x -> x["mean"] == 0.3

    #     sim = Simulation(Population(n=1000), length_of_stay=0.3)
    #     @test sim |> pathogen |> length_of_stay |> parameters |>
    #           x -> x["mean"] == 0.3

    #     sim = Simulation(Population(n=1000), progression_categories=[0.4, 0.3, 0.2, 0.1])
    #     @test (sim |> pathogen |> disease_progression_strat).stratification_matrix == [[0.4, 0.3, 0.2, 0.1]]

    #     sim = Simulation(Population(n=1000), household_contact_rate=0.3)
    #     contact_rate = get(sim.settings, Household)[1].contact_sampling_method.contactparameter
    #     @test contact_rate == 0.3

    #     sim = Simulation(Population(n=1000), office_contact_rate=0.3)
    #     contact_rate = get(sim.settings, Office)[1].contact_sampling_method.contactparameter
    #     @test contact_rate == 0.3

    #     sim = Simulation(population="HB", school_contact_rate=0.3,
    #         school_year_contact_rate=0.3,
    #         school_complex_contact_rate=0.3,
    #         workplace_site_contact_rate=0.3,
    #         workplace_contact_rate=0.3,
    #         department_contact_rate=0.3,
    #         municipality_contact_rate=0.3)
    #     contact_rate = get(sim.settings, School)[1].contact_sampling_method.contactparameter
    #     @test contact_rate == 0.3
    #     contact_rate = get(sim.settings, Municipality)[1].contact_sampling_method.contactparameter
    #     @test contact_rate == 0.3
    #     contact_rate = get(sim.settings, Department)[1].contact_sampling_method.contactparameter
    #     @test contact_rate == 0.3
    #     contact_rate = get(sim.settings, WorkplaceSite)[1].contact_sampling_method.contactparameter
    #     @test contact_rate == 0.3
    #     contact_rate = get(sim.settings, Workplace)[1].contact_sampling_method.contactparameter
    #     @test contact_rate == 0.3
    #     contact_rate = get(sim.settings, SchoolComplex)[1].contact_sampling_method.contactparameter
    #     @test contact_rate == 0.3
    #     contact_rate = get(sim.settings, SchoolYear)[1].contact_sampling_method.contactparameter
    #     @test contact_rate == 0.3

    #     sim = Simulation(Population(n=1000), school_class_contact_rate=0.3)
    #     contact_rate = get(sim.settings, SchoolClass)[1].contact_sampling_method.contactparameter
    #     @test contact_rate == 0.3

    #     sim = Simulation(Population(n=1000), global_contact_rate=0.3, global_setting=true)
    #     contact_rate = get(sim.settings, GlobalSetting)[1].contact_sampling_method.contactparameter
    #     @test contact_rate == 0.3

    #     sim = Simulation(pop_size=1000)
    #     @test sim |> population |> size == 1000

    #     n = 1_000
    #     sim = Simulation(pop_size=n, avg_household_size=10)
    #     num_households = get(sim.settings, Household) |> length
    #     @test round(Int, (n / num_households)) == 10

    #     sim = Simulation(pop_size=n, avg_office_size=10)
    #     num_offices1 = get(sim.settings, Office) |> length
    #     sim = Simulation(pop_size=n, avg_office_size=15)
    #     num_offices2 = get(sim.settings, Office) |> length
    #     @test num_offices1 > num_offices2

    #     sim = Simulation(pop_size=n, avg_school_size=10)
    #     num_schools1 = get(sim.settings, SchoolClass) |> length
    #     sim = Simulation(pop_size=n, avg_school_size=20)
    #     num_schools2 = get(sim.settings, SchoolClass) |> length
    #     @test num_schools1 > num_schools2

    #     # testing combinations (does overwriting work?)
    #     sim = Simulation(population=Population(n=1000), n=10_000)
    #     @test sim |> population |> size == 1000


    #     # Testing other constructors

    #     sim = Simulation(configpath, pop_path, settingspath)
    #     @test sim.configfile == configpath

    #     sim = Simulation(configfile=configpath, label="test")
    #     @test sim.configfile == configpath
    #     @test sim |> label == "test"

    #     sim = Simulation(populationpath, label="test")
    #     @test sim |> population |> size == 100
    #     @test sim |> label == "test"


    #     sim = Simulation(Population(n=1000), label="test")
    #     @test sim.configfile == joinpath(basefolder, GEMS.DEFAULT_CONFIGFILE)
    #     @test sim |> population |> size == 1000
    #     @test sim |> label == "test"

    #     my_arguments = Dict(
    #         :label => "test",
    #         :pop_size => 1000
    #     )
    #     sim = Simulation(my_arguments)
    #     @test sim |> population |> size == 1000
    #     @test sim |> label == "test"
    # end

    # #test false inputs
    # @testset "Error Tests" begin
    #     basefolder = dirname(dirname(pathof(GEMS)))
    #     confile = "test/testdata/TestConf.toml"
    #     configpath = joinpath(basefolder, confile)
    #     @test_throws TypeError Simulation(progression_categories=2.0)
    #     try
    #         Simulation(progression_categories=[[1.0]])
    #         @test false
    #     catch e
    #         @test e == "Please submit a vector with 4 entries for the default disease progressuion. If you want to have a complex disease progression please provide a custom conig file."
    #     end
    #     try
    #         Simulation(progression_categories=[2.0])
    #         @test false
    #     catch e
    #         @test e == "The entries of the progression_categories must add up to one."
    #     end
    #     try
    #         Simulation(progression_categories=[1, 0, 1.0, -1.0])
    #         @test false
    #     catch e
    #         @test e == "All entries in the progression_categories need to be between 0 and 1 (including)"
    #     end
    #     try
    #         Simulation(pop_size=0)
    #         @test false
    #     catch e
    #         @test e == "The population must have at least one individual"
    #     end
    #     try
    #         Simulation(transmission_rate=2.0)
    #         @test false
    #     catch e
    #         @test e == "The transmission rate needs to be between and including 0 and 1"
    #     end
    #     try
    #         Simulation(configpath, transmission_rate=1.0)
    #         @test false
    #     catch e
    #         expected_message = "Warning: Unhandled arguments provided - Base.Pairs(:transmission_rate => 1.0). You cannot overwrite parameters in a provided config file"
    #         @test occursin(expected_message, string(e))
    #     end
    #     try
    #         Simulation("test.toml", "")
    #         @test false
    #     catch e
    #         @test occursin("Please make sure that the path provided to the configfile exists", string(e))
    #     end
    #     try
    #         Simulation("test", "")
    #         @test false
    #     catch e
    #         @test e == "Please provide a valid .toml file as config file! Refer to the documentation for explanation on the config file structure"
    #     end
    #     try
    #         Simulation("", "")
    #         @test false
    #     catch e
    #         @test e == "No Config file provided"
    #     end
    #     try
    #         Simulation(configpath, "population", settingsfile="settings")
    #         @test false
    #     catch e
    #         @test e == "The remote download attempted to overwrite the settingsfile you provided. You need to define the populationfile you want to use locally."
    #     end
    #     #try
    #     #    Simulation(startdate="2020.01.01", enddate="2020.01.01")
    #     #    @test false
    #     #catch e
    #     #    @test occursin("Start date (2020-01-01) of the simulation is after or at the end date (2020-01-01). Please provide valid start and end dates in the format yyyy.mm.dd", string(e))
    #     #end
    #     #try
    #     #    Simulation(startdate="2025.01.01", enddate="2020.01.01")
    #     #    @test false
    #     #catch e
    #     #    @test occursin("Start date (2025-01-01) of the simulation is after or at the end date (2020-01-01). Please provide valid start and end dates in the format yyyy.mm.dd", string(e))
    #     #end
    #     try
    #         Simulation(startdate="2020/01/01")
    #         @test false
    #     catch e
    #         @test occursin("Please provide valid start and end dates in the format yyyy.mm.dd", string(e))
    #     end
    #     try
    #         Simulation("")
    #         @test false
    #     catch e
    #         @test e == "The file you provided does not match any type recognised by this simulation. Please provide a .toml, .csv, or .jdl2 file!"
    #     end

    #     properties_with_multiple_pathogens = Dict(
    #         "Pathogens" => Dict("PathogenA" => 1, "PathogenB" => 2),
    #         "Simulation" => Dict("StartCondition" => Dict("pathogen" => "PathogenC"))
    #     )

    #     properties_with_single_pathogen = Dict(
    #         "Pathogens" => Dict("PathogenA" => 1),
    #         "Simulation" => Dict("StartCondition" => Dict("pathogen" => "PathogenA"))
    #     )

    #     properties_with_mismatched_start_condition = Dict(
    #         "Pathogens" => Dict("PathogenA" => 1),
    #         "Simulation" => Dict("StartCondition" => Dict("pathogen" => "PathogenB"))
    #     )

    #     @testset "validate_pathogens Tests" begin
    #         # Test for multiple unique pathogens (inconsistent names)
    #         @test_throws String GEMS.validate_pathogens(properties_with_multiple_pathogens, 1)

    #         # Test for mismatched StartCondition pathogen
    #         try
    #             GEMS.validate_pathogens(properties_with_mismatched_start_condition, 1)
    #         catch e
    #             @test occursin(
    #                 "Pathogen in StartCondition ('PathogenB') does not match the pathogens in the Pathogens section: [\"PathogenA\"]",
    #                 string(e)
    #             )
    #         end
    #     end
    #     try
    #         Simulation(configpath, "population")
    #         @test false
    #     catch e
    #         @test e == "Attempted to download remote population `population`. Data could not be downloaded. Are you sure the data is available at https://uni-muenster.sciebo.de/s/SoogCFyijz4ctBA/download?path=%2F&files=population.zip?"
    #     end

    #     # Test for invalid waning type
    #     invalid_waning_type = "InvalidWaningType"
    #     params = [1.0, 2.0]
    #     try
    #         GEMS.create_waning(params, invalid_waning_type)
    #         @test false
    #     catch e
    #         @test typeof(e) == ErrorException
    #         @test occursin("The waning type $invalid_waning_type provided in the configfile is not known!", string(e))
    #     end

    #     start_condition_dict = Dict("type" => "InfectedFraction", "pathogen" => "NonExistentPathogen", "fraction" => 0.1)
    #     sim = Simulation()
    #     p = pathogen(sim)

    #     try
    #         GEMS.load_start_condition(start_condition_dict, [p])
    #         @test false
    #     catch e
    #         @test typeof(e) == ErrorException
    #         expected_message = "The Pathogen of name NonExistentPathogen could not be found for the starting condition"
    #         @test occursin(expected_message, string(e))
    #     end

    #     start_condition_dict = Dict("type" => "PatientZero", "pathogen" => "NonExistentPathogen", "fraction" => 0.1)
    #     sim = Simulation()
    #     p = pathogen(sim)

    #     try
    #         GEMS.load_start_condition(start_condition_dict, [p])
    #         @test false
    #     catch e
    #         @test typeof(e) == ErrorException
    #         expected_message = "The Pathogen of name NonExistentPathogen could not be found for the starting condition"
    #         @test occursin(expected_message, string(e))
    #     end

    #     start_condition_dict = Dict("type" => "PatientZeros", "pathogen" => "NonExistentPathogen", "fraction" => 0.1)
    #     sim = Simulation()
    #     p = pathogen(sim)

    #     try
    #         GEMS.load_start_condition(start_condition_dict, [p])
    #         @test false
    #     catch e
    #         @test typeof(e) == ErrorException
    #         expected_message = "The Pathogen of name NonExistentPathogen could not be found for the starting condition"
    #         @test occursin(expected_message, string(e))
    #     end

    #     start_condition_dict = Dict("type" => "xxx", "pathogen" => "NonExistentPathogen", "fraction" => 0.1)
    #     sim = Simulation()
    #     p = pathogen(sim)

    #     try
    #         GEMS.load_start_condition(start_condition_dict, [p])
    #         @test false
    #     catch e
    #         @test typeof(e) == ErrorException
    #         expected_message = "StartCondition xxx is not implemented!"
    #         @test occursin(expected_message, string(e))
    #     end

    #     stop_criterion_dict = Dict("type" => "xxx")
    #     try
    #         GEMS.load_stop_criterion(stop_criterion_dict)
    #         @test false
    #     catch e
    #         @test typeof(e) == ErrorException
    #         expected_message = "StopCriterion xxx is not implemented!"
    #         @test occursin(expected_message, string(e))
    #     end

    #     sim = Simulation()
    #     struct NewCondition <: StartCondition
    #     end
    #     condition = NewCondition()
    #     try
    #         GEMS.initialize!(sim, condition)
    #         @test false
    #     catch e
    #         @test typeof(e) == ErrorException
    #         expected_message = "`initialize!` not implemented for start condition "
    #         @test occursin(expected_message, string(e))
    #     end

    #     sim = Simulation()
    #     struct NewCriterion <: StopCriterion
    #     end
    #     criterion = NewCriterion()
    #     try
    #         GEMS.evaluate(sim, criterion)
    #         @test false
    #     catch e
    #         @test typeof(e) == ErrorException
    #         expected_message = "`evaluate` not implemented for stop criterion "
    #         @test occursin(expected_message, string(e))
    #     end
    # end

    # @testset "Variations on start conditions and stop criterion" begin
    #     covid = Pathogen(id=1, name="COVID19")
    #     p0 = GEMS.PatientZero(covid)
    #     ps0 = GEMS.PatientZeros(covid, [-1])
    #     sim1 = Simulation()
    #     sim2 = Simulation()
    #     sim1.start_condition = p0
    #     sim2.start_condition = ps0
    #     @test sim1.start_condition === p0
    #     @test sim2.start_condition === ps0
    #     @test pathogen(p0) === covid
    #     @test pathogen(ps0) === covid

    #     #TODO test initialize function

    #     initialize!(sim1, p0)
    #     initialize!(sim2, ps0)

    #     ni = NoneInfected()
    #     sim1.stop_criterion = ni
    #     @test sim1.stop_criterion === ni
    #     @test GEMS.parameters(ni) == Dict("type" => "NoneInfected")
    #     @test GEMS.load_stop_criterion(Dict("type" => "NoneInfected")) == ni

    #     @test GEMS.load_start_condition(Dict("type" => "PatientZero", "pathogen" => "COVID19"), [covid]) == p0
    #     @test GEMS.load_start_condition(Dict("type" => "PatientZeros", "pathogen" => "COVID19", "ags" => ags(sim2.start_condition)), [covid]) == ps0

    #     struct NewCondition1 <: StartCondition
    #     end
    #     nc = NewCondition1()
    #     @test parameters(nc) == Dict()
    #     @test parameters(p0) == Dict("pathogen" => "COVID19", "pathogen_id" => 1)
    #     @test parameters(ps0) == Dict("pathogen" => "COVID19", "pathogen_id" => 1, "ags" => [-1])
    #     inffr = InfectedFraction(1, covid)
    #     @test parameters(inffr) == Dict("pathogen" => "COVID19", "pathogen_id" => 1, "fraction" => 1.0)

    #     struct NewCriterion1 <: StopCriterion
    #     end
    #     sc = NewCriterion1()
    #     @test parameters(sc) == Dict("type" => "NewCriterion1")

    #     tu = TimesUp(2)
    #     @test parameters(tu) == Dict("type" => "TimesUp", "limit" => 2)

    #     @test !evaluate(sim2, ni)

    # end

    # @testset "function tickunit" begin
    #     sim1 = Simulation(tickunit="y")
    #     @test tickunit(sim1) == "year"
    #     sim2 = Simulation(tickunit="m")
    #     @test tickunit(sim2) == "month"
    #     sim3 = Simulation(tickunit="d")
    #     @test tickunit(sim3) == "day"
    #     sim4 = Simulation(tickunit="w")
    #     @test tickunit(sim4) == "week"
    #     sim5 = Simulation(tickunit="h")
    #     @test tickunit(sim5) == "hour"
    #     sim6 = Simulation(tickunit="M")
    #     @test tickunit(sim6) == "minute"
    #     sim7 = Simulation(tickunit="S")
    #     @test tickunit(sim7) == "second"
    #     sim8 = Simulation(tickunit="t")
    #     @test tickunit(sim8) == "tick"
    # end

    # #=
    # @testset "Test All Arguments indiviually" begin
    #     BASE_FOLDER = dirname(dirname(pathof(GEMS)))        
    #     #popfile = joinpath(BASE_FOLDER, "test/testdata/people_muenster.jld2")
    #     #sim = Simulation(population=popfile)
    #     #@test populationfile(sim.population) == popfile
    #     popstruct = Population()
    #     sim = Simulation(population=popstruct)
    #     @test sim.population === popstruct
    #     #settingsfilepath = joinpath(BASE_FOLDER, "test/testdata/settings_muenster.jld2")
    #     #sim = Simulation(settingsfile=settingsfilepath, population=popfile)
    #     sim = Simulation(tickunit="w", pop_size=100)
    #     @test sim.tickunit == 'w'
    #     test_stepmod = x -> 2 * x
    #     sim = Simulation(stepmod=test_stepmod, pop_size=100)
    #     @test sim.stepmod == test_stepmod
    #     sim = Simulation(label="test", pop_size=100)
    #     @test sim.label == "test"
    #     sim = Simulation(startdate="2020.01.01", pop_size=100)
    #     @test sim.startdate == Date(2020, 1, 1)
    #     sim = Simulation(enddate="2025.01.01", pop_size=100)
    #     @test sim.enddate == Date(2025, 1, 1)
    #     sim = Simulation(transmission_rate=0.4, pop_size=100)
    #     @test (sim |> pathogen |> transmission_function).transmission_rate == 0.4
    #     sim = Simulation(onset_of_symptoms=0.4, pop_size=100)
    #     @test sim |> pathogen |> onset_of_symptoms == Distributions.Poisson(0.4)
    #     sim = Simulation(onset_of_severeness=0.4, pop_size=100)
    #     @test sim |> pathogen |> onset_of_severeness == Distributions.Poisson(0.4)
    #     sim = Simulation(infectious_offset=0.4, pop_size=100)
    #     @test sim |> pathogen |> infectious_offset == Distributions.Poisson(0.4)
    #     sim = Simulation(mild_death_rate=0.5, pop_size=100)
    #     @test sim |> pathogen |> mild_death_rate == Distributions.Binomial(1,0.5)
    #     sim = Simulation(severe_death_rate=0.5, pop_size=100)
    #     @test sim |> pathogen |> severe_death_rate == Distributions.Binomial(1,0.5)
    #     sim = Simulation(critical_death_rate=0.5, pop_size=100)
    #     @test sim |> pathogen |> critical_death_rate == Distributions.Binomial(1,0.5)
    #     sim = Simulation(hospitalization_rate=0.5, pop_size=100)
    #     @test sim |> pathogen |> hospitalization_rate == Distributions.Binomial(1,0.5)
    #     sim = Simulation(ventilation_rate=0.5, pop_size=100)
    #     @test sim |> pathogen |> ventilation_rate == Distributions.Binomial(1,0.5)
    #     sim = Simulation(icu_rate=0.5, pop_size=100)
    #     @test sim |> pathogen |> icu_rate == Distributions.Binomial(1,0.5)
    #     sim = Simulation(time_to_recovery=2.0, pop_size=100)
    #     @test sim |> pathogen |> time_to_recovery == Distributions.Poisson(2.0) 
    #     sim = Simulation(time_to_hospitalization=2.0, pop_size=100)
    #     @test sim |> pathogen |> time_to_hospitalization == Distributions.Poisson(2.0)
    #     sim = Simulation(time_to_icu=2.0, pop_size=100)
    #     @test sim |> pathogen |> time_to_icu == Distributions.Poisson(2.0) 
    #     sim = Simulation(length_of_stay=2.0, pop_size=100)
    #     @test sim |> pathogen |> length_of_stay == Distributions.Poisson(2.0) 
    #     sim = Simulation(progression_categories=[0.4, 0.25, 0.25, 0.1], pop_size=100)
    #     @test (sim |> pathogen |> disease_progression_strat).stratification_matrix == [[0.4, 0.25, 0.25, 0.1]]
    #     sim = Simulation(household_contact_rate=1.0, pop_size=100)
    #     contact_rate = get(sim.settings, Household)[1].contact_sampling_method.contactparameter
    #     @test contact_rate == 1.0
    #     sim = Simulation(office_contact_rate=1.0, pop_size=100)
    #     contact_rate = get(sim.settings, Office)[1].contact_sampling_method.contactparameter
    #     @test contact_rate == 1.0
    #     sim = Simulation(pop_size=100)
    #     @test sim |> population |> size == 100
    # end
    # =#


    # @testset "test incidence function" begin
    #     population = Population(n=100)
    #     sim = Simulation(population)
    #     for ind in individuals(sim.population)
    #         infect!(ind, Int16(0), pathogen(sim))
    #         ind.quarantine_status = Int8(1)
    #     end
    #     #test quarantines logger:
    #     GEMS.log_quarantines(sim)
    #     # Check the logger values
    #     @test length(sim.quarantinelogger.quarantined) == 1  # Only one tick logged
    #     @test length(sim.quarantinelogger.students) == 1
    #     @test length(sim.quarantinelogger.workers) == 1

    #     # Get the logged data for the first (and only) tick
    #     quarantined_count = sim.quarantinelogger.quarantined[end]
    #     students_count = sim.quarantinelogger.students[end]
    #     workers_count = sim.quarantinelogger.workers[end]

    #     inds = individuals(sim)
    #     working_individuals = [ind for ind in inds if is_working(ind)]
    #     student_individuals = [ind for ind in inds if is_student(ind)]

    #     @test quarantined_count == 100
    #     @test students_count == length(student_individuals)
    #     @test workers_count == length(working_individuals)

    #     #test indence function: TODO
    #     @test GEMS.incidence(sim, 100) == 0.0 #?
    # end

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

end