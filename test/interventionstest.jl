import GEMS: MeasureEntry, EventQueue, enqueue!, dequeue!, stage!, flush_staging!, peek, peektick

@testset "Interventions" begin
    #setup of the simulation object:
    sim = Simulation()

    #setup of the strategies
    condition = (_) -> true
    i_strategy = IStrategy("i_strategy", sim, condition=condition)
    s_strategy = SStrategy("s_strategy", sim, condition=condition)

    @test length(sim.strategies) == 2

    #define Individuals and settings
    i = Individual(id=1, sex=0, age=31, household=1)
    i2 = Individual(id=4, age=10, sex=1)
    indis = [Individual(id=j, age=18, sex=1) for j in range(0, 3)]
    indis2 = [Individual(id=j, age=18, sex=1) for j in range(0, 3)]
    rs = RandomSampling()
    gs = GlobalSetting(individuals=indis, contact_sampling_method=rs)
    gs2 = GlobalSetting(individuals=indis2, contact_sampling_method=rs)

    #setup trigger
    symptom_trigger = SymptomTrigger(i_strategy)
    add_symptom_trigger!(sim, symptom_trigger)

    hospitalization_trigger = HospitalizationTrigger(i_strategy)
    add_hospitalization_trigger!(sim, hospitalization_trigger)

    i_tick_trigger = ITickTrigger(i_strategy)
    add_tick_trigger!(sim, i_tick_trigger)

    s_tick_trigger = STickTrigger(School, s_strategy)
    add_tick_trigger!(sim, s_tick_trigger)

    @testset "IStrategy" begin
        @test typeof(i_strategy) === IStrategy
        @test name(i_strategy) === "i_strategy"
        @test measures(i_strategy) == MeasureEntry[]
        @test GEMS.condition(i_strategy) isa GEMS.IPredicate
        @test GEMS.condition(i_strategy)(i) == true
        add_strategy!(sim, i_strategy)
        @test strategies(sim)[1] === i_strategy
    end

    @testset "SStrategy" begin
        @test typeof(s_strategy) === SStrategy
        @test name(s_strategy) === "s_strategy"
        @test measures(s_strategy) == MeasureEntry[]
        @test GEMS.condition(s_strategy) isa GEMS.SPredicate
        @test GEMS.condition(s_strategy)(gs) == true
        add_strategy!(sim, s_strategy)
        @test strategies(sim)[2] === s_strategy
    end

    @testset "Strategy Condition Getter and Base.show" begin
        sim_show = Simulation()

        # GEMS.condition(str::Strategy) is shadowed throughout this testset by the
        # local variable `condition = (_) -> true` defined at the top — the qualified
        # name must be used here to actually exercise the getter method.

        # default condition is x -> true: the stored function returns true for any input
        default_str = IStrategy("show_default", sim_show)
        @test GEMS.condition(default_str) isa GEMS.IPredicate
        @test GEMS.condition(default_str)(i) == true

        # non-trivial condition: the stored function preserves the predicate's logic
        age_str = IStrategy("show_age", sim_show, condition = i -> age(i) > 65)
        young = Individual(id=1, age=30, sex=1)
        elder = Individual(id=2, age=70, sex=1)
        @test GEMS.condition(age_str)(young) == false
        @test GEMS.condition(age_str)(elder) == true

        # same for SStrategy
        s_default_str = SStrategy("show_s_default", sim_show)
        @test GEMS.condition(s_default_str) isa GEMS.SPredicate
        @test GEMS.condition(s_default_str)(gs) == true

        # Base.show with no measures: output contains type name and strategy name
        output_empty = @capture_out show(default_str)
        @test occursin("IStrategy", output_empty)
        @test occursin("show_default", output_empty)

        # Base.show with measures: each measure appears with its offset
        add_measure!(default_str, SelfIsolation(7))
        add_measure!(default_str, SelfIsolation(14), offset = 2)
        output_measures = @capture_out show(default_str)
        @test occursin("IStrategy", output_measures)
        @test occursin("SelfIsolation", output_measures)
        @test occursin("0:", output_measures)
        @test occursin("2:", output_measures)
    end

    @testset "SelfIsolation Measure" begin
        self_isolation = SelfIsolation(14)
        add_measure!(i_strategy, self_isolation)

        @test i_strategy.measures[1].measure === self_isolation
        @test duration(self_isolation) == 14

        process_measure(sim, i, self_isolation)
        #@test isquarantined(i) == true TODO
    end

    @testset "Cancel SelfIsolation Measure" begin
        cancel_self_isolation = CancelSelfIsolation()
        add_measure!(i_strategy, cancel_self_isolation)

        @test length(i_strategy.measures) == 2
        @test i_strategy.measures[2].measure === cancel_self_isolation

        process_measure(sim, i, cancel_self_isolation)
        @test isquarantined(i) == false
    end

    @testset "Find Setting" begin

        find_setting = FindSetting(Household, s_strategy)
        add_measure!(i_strategy, find_setting)

        @test settingtype(find_setting) === Household
        @test follow_up(find_setting) === s_strategy

        #test processing find_setting measure:
        result = process_measure(sim, i, find_setting)

        @test typeof(result.focal_objects[1]) === Household
        @test result.follow_up === s_strategy

    end

    @testset "Find Setting Members" begin
        find_setting_members = FindSettingMembers(Household, i_strategy)
        find_setting_members2 = FindSettingMembers(Household, i_strategy, nonself=true)
        add_measure!(i_strategy, find_setting_members)

        @test length(i_strategy.measures) == 4
        @test i_strategy.measures[4].measure === find_setting_members

        @test settingtype(find_setting_members) === Household
        @test follow_up(find_setting_members) === i_strategy
        @test find_setting_members.nonself == false
        @test GEMS.nonself(find_setting_members) == false
        @test find_setting_members2.nonself == true

        #setup to test process measure
        pop = Population(n=5, avg_household_size=5, avg_school_size=1, rng = Xoshiro())
        sim2 = Simulation(population=pop)
        i_strategy2 = IStrategy("i_strategy2", sim2)
        find_setting_members3 = FindSettingMembers(Household, i_strategy2)

        #test process measure
        individuals_from_sim = individuals(sim2)
        result = process_measure(sim2, first(individuals_from_sim), find_setting_members3)

        @test individuals_from_sim == result.focal_objects
        for i in eachindex(result.focal_objects)
            @test result.focal_objects[i] === individuals_from_sim[i]
        end
        @test result.follow_up === i_strategy2
    end

    @testset "Testing" begin

        test = TestType("Test", pathogen(sim), sim)
        test_measure = GEMS.Test("test", test)
        add_measure!(i_strategy, test_measure)
        add_testtype!(sim, test)
        @test testtypes(sim)[1] === test

        @test_throws ArgumentError TestType("Test", pathogen(sim), sim, sensitivity=2.0)
        @test_throws ArgumentError TestType("Test", pathogen(sim), sim, specificity=2.0)

        #Testtype Tests
        @test name(test) === "Test"
        @test pathogen(test) === pathogen(sim)
        @test sensitivity(test) == 1.0
        @test GEMS.specificity(test) == 1.0

        #Measure Tests
        @test length(i_strategy.measures) == 5
        @test i_strategy.measures[5].measure === test_measure

        @test name(test_measure) === "test"
        @test type(test_measure) === test
        @test positive_followup(test_measure) === nothing
        @test negative_followup(test_measure) === nothing
        @test GEMS.reportable(test_measure) == true

        #test with follow_up strategies
        test_measure2 = GEMS.Test("test", test, i_strategy, nothing, reportable=false)
        test_measure3 = GEMS.Test("test", test, nothing, i_strategy)
        test_measure4 = GEMS.Test("test", test, i_strategy, i_strategy)

        @test positive_followup(test_measure2) === i_strategy
        @test negative_followup(test_measure2) === nothing
        @test GEMS.reportable(test_measure2) === false
        @test positive_followup(test_measure3) === nothing
        @test negative_followup(test_measure3) === i_strategy
        @test positive_followup(test_measure4) === i_strategy
        @test negative_followup(test_measure4) === i_strategy

        #test with no input
        @test_throws ArgumentError begin
            test_measure5 = GEMS.Test()
        end

        #test processing measure
        result = process_measure(sim, i, test_measure3)
        follow_up_strategy = result.follow_up

        @test follow_up_strategy === i_strategy

        infect!(i, Int16(0), pathogen(sim), rng = Xoshiro())
        result2 = process_measure(sim, i, test_measure2)
        follow_up_strategy2 = result2.follow_up

        @test follow_up_strategy2 === i_strategy
    end

    @testset "Seroprevalence Testing" begin

        s_test = SeroprevalenceTestType("Sero Test", pathogen(sim), sim)
        s_test_measure = GEMS.Test("test", s_test)
        add_measure!(i_strategy, s_test_measure)
        add_testtype!(sim, s_test)
        @test testtypes(sim)[3] == s_test
        println(testtypes(sim))

        @test_throws ArgumentError SeroprevalenceTestType("Test", pathogen(sim), sim, sensitivity=2.0)
        @test_throws ArgumentError SeroprevalenceTestType("Test", pathogen(sim), sim, specificity=2.0)

        #Testtype Tests
        @test name(s_test) == "Sero Test"
        @test pathogen(s_test) == pathogen(sim)
        @test sensitivity(s_test) == 1.0
        @test GEMS.specificity(s_test) == 1.0

        #Measure Tests
        @test length(i_strategy.measures) == 6
        @test i_strategy.measures[6].measure === s_test_measure

        @test name(s_test_measure) === "test"
        @test type(s_test_measure) === s_test
        @test positive_followup(s_test_measure) === nothing
        @test negative_followup(s_test_measure) === nothing
        @test GEMS.reportable(s_test_measure) == true

        #test with follow_up strategies
        s_test_measure2 = GEMS.Test("test", s_test, i_strategy, nothing, reportable=false)
        s_test_measure3 = GEMS.Test("test", s_test, nothing, i_strategy)
        s_test_measure4 = GEMS.Test("test", s_test, i_strategy, i_strategy)

        @test positive_followup(s_test_measure2) === i_strategy
        @test negative_followup(s_test_measure2) === nothing
        @test GEMS.reportable(s_test_measure2) === false
        @test positive_followup(s_test_measure3) === nothing
        @test negative_followup(s_test_measure3) === i_strategy
        @test positive_followup(s_test_measure4) === i_strategy
        @test negative_followup(s_test_measure4) === i_strategy

        #test with no input
        @test_throws ArgumentError begin
            s_test_measure5 = GEMS.Test()
        end

        #test processing measure
        infect!(i, Int16(0), pathogen(sim), rng = Xoshiro())
        result = process_measure(sim, i, s_test_measure2)
        follow_up_strategy = result.follow_up

        @test follow_up_strategy === i_strategy

    end

    @testset "Trace Infectious Contacts" begin
        trace_infectious = TraceInfectiousContacts(i_strategy)
        add_measure!(i_strategy, trace_infectious)

        @test length(i_strategy.measures) == 7
        @test i_strategy.measures[7].measure === trace_infectious

        @test success_rate(trace_infectious) == 1.0
        @test follow_up(trace_infectious) === i_strategy

        @test process_measure(sim, i, trace_infectious) === nothing

        @test_throws ArgumentError TraceInfectiousContacts(i_strategy, success_rate=2.0)

        pop = Population(n=2, avg_household_size=2, avg_school_size=2, avg_office_size=2, rng = Xoshiro())
        sim3 = Simulation(population=pop, transmission_rate=1.0, household_contacts=1.0)
        i_strategy3 = IStrategy("i_strategy3", sim3)
        trace_infectious2 = TraceInfectiousContacts(i_strategy3, success_rate=1.0)
        ind1 = first(individuals(sim3))
        ind2 = individuals(sim3)[2]
        infect!(ind1, Int16(0), pathogen(sim3), rng = Xoshiro())
        ind1.infectiousness_onset = Int16(0)
        infect!(ind2, Int16(0), pathogen(sim3), sim = sim3, infecter_id = id(ind1), rng = Xoshiro())
        contacts = process_measure(sim3, ind1, trace_infectious2)
        @test contacts !== nothing
        @test length(contacts.focal_objects) == 1
        @test contacts.focal_objects[1] === ind2
    end

    @testset "Custom I Measure" begin
        measure_function = (i, sim) -> i.mandate_compliance = 0.7
        custom_i_measure = CustomIMeasure(measure_function)

        @test typeof(custom_i_measure.measure_logic) == typeof(measure_function)
        @test GEMS.measure_logic(custom_i_measure) === measure_function

        #test process_measure
        process_measure(sim, i, custom_i_measure)
        @test i.mandate_compliance == 0.7f0
    end

    @testset "Find Members" begin

        find_members = FindMembers(i_strategy)
        add_measure!(s_strategy, find_members)

        @test length(s_strategy.measures) == 1
        @test s_strategy.measures[1].measure === find_members

        @test follow_up(find_members) === i_strategy
        @test sample_size(find_members) == -1
        @test sample_fraction(find_members) == 1.0
        @test find_members.selectionfilter(i) == true

        #test optional arguments: 
        find_members2 = FindMembers(i_strategy, sample_size=2, selectionfilter=x -> x.age > 18)
        find_members3 = FindMembers(i_strategy, sample_fraction=0.5, selectionfilter=x -> x.age > 18)

        @test sample_size(find_members2) == 2
        @test find_members2.selectionfilter(i) == true
        @test find_members2.selectionfilter(i2) == false
        @test sample_fraction(find_members3) == 0.5

        #test processing measure:
        result = process_measure(sim, gs, find_members)

        for i in eachindex(indis)
            @test result.focal_objects[i] === indis[i]
        end
        @test result.follow_up === i_strategy

        result2 = process_measure(sim, gs, find_members2)

        @test typeof(result2) == Handover

        individuals = result2.focal_objects
        strategy = result2.follow_up

        @test typeof(individuals) <: AbstractVector{<:Individual}
        @test length(individuals) == 0

        @test typeof(strategy) <: IStrategy

        expected_strategies = [
            "SelfIsolation",
            "CancelSelfIsolation",
            "FindSetting",
            "FindSettingMembers",
            "GEMS.Test",
            "TraceInfectiousContacts",
            "GEMS.Test"
        ]

        strategy_names = map(x -> string(typeof(measure(x))), getfield(strategy, :measures))
        @test length(strategy_names) == length(expected_strategies)
        @test all(name in strategy_names for name in expected_strategies)

        result3 = process_measure(sim, gs, find_members3)

        @test typeof(result3) == Handover

        individuals = result3.focal_objects
        strategy = result3.follow_up

        @test typeof(individuals) <: AbstractVector{<:Individual}
        @test length(individuals) == 0

        @test typeof(strategy) <: IStrategy

        expected_strategies = [
            "SelfIsolation",
            "CancelSelfIsolation",
            "FindSetting",
            "FindSettingMembers",
            "GEMS.Test",
            "TraceInfectiousContacts",
            "GEMS.Test"
        ]

        strategy_names = map(x -> string(typeof(measure(x))), getfield(strategy, :measures))
        @test length(strategy_names) == length(expected_strategies)
        @test all(name in strategy_names for name in expected_strategies)

        #test errors thrown
        @test_throws ArgumentError begin
            find_members_false_sample_size = FindMembers(i_strategy, sample_size=-2)
        end
        @test_throws ArgumentError begin
            find_members_false_sample_fraction = FindMembers(i_strategy, sample_fraction=2.0)
        end
        @test_throws ArgumentError begin
            find_members_sample_size_and_sample_fraction = FindMembers(i_strategy, sample_size=1, sample_fraction=0.5)
        end
    end

    @testset "Change Contact Method Measure" begin
        contact_parameter_sampling = ContactparameterSampling(5)
        change_contact_method = ChangeContactMethod(contact_parameter_sampling)
        add_measure!(s_strategy, change_contact_method)

        @test length(s_strategy.measures) == 2
        @test s_strategy.measures[2].measure === change_contact_method

        @test sampling_method(change_contact_method) === contact_parameter_sampling

        @test contact_sampling_method(gs) === rs
        process_measure(sim, gs, change_contact_method)
        @test contact_sampling_method(gs) isa ContactparameterSampling
        @test contact_sampling_method(gs).contactparameter == 5.0
    end

    @testset "Close and Open Setting Measure" begin
        close_setting = CloseSetting()
        add_measure!(s_strategy, close_setting)

        @test length(s_strategy.measures) == 3
        @test s_strategy.measures[3].measure === close_setting

        @test gs.isopen == true
        process_measure(sim, gs, close_setting)
        @test gs.isopen == false

        open_setting = OpenSetting()
        add_measure!(s_strategy, open_setting)

        @test length(s_strategy.measures) == 4
        @test s_strategy.measures[4].measure === open_setting

        process_measure(sim, gs, open_setting)
        @test gs.isopen == true
    end

    @testset "Is Open Measure" begin
        is_open = IsOpen(positive_followup=s_strategy)
        s_strategy2 = SStrategy("SStrategy", sim)
        is_open2 = IsOpen(positive_followup=s_strategy2, negative_followup=s_strategy)
        is_open3 = IsOpen(negative_followup=s_strategy)
        add_measure!(s_strategy, is_open)

        @test length(s_strategy.measures) == 5
        @test s_strategy.measures[5].measure === is_open

        @test negative_followup(is_open) === nothing
        @test positive_followup(is_open) === s_strategy
        @test negative_followup(is_open2) === s_strategy
        @test positive_followup(is_open2) === s_strategy2
        @test negative_followup(is_open3) === s_strategy
        @test positive_followup(is_open3) === nothing

        #test processing measure
        result = process_measure(sim, gs, is_open)
        @test result.focal_objects[1] === gs
        @test result.follow_up === s_strategy

        close_setting = CloseSetting()
        process_measure(sim, gs, close_setting)
        result2 = process_measure(sim, gs, is_open)
        @test result2.follow_up === nothing
    end

    @testset "Pool Test Measure" begin
        test = TestType("Test", pathogen(sim), sim)
        pool_test = PoolTest("Pool Test", test)
        add_measure!(s_strategy, pool_test)

        @test length(s_strategy.measures) == 6
        @test s_strategy.measures[6].measure === pool_test

        @test name(pool_test) == "Pool Test"
        @test type(pool_test) === test
        @test positive_followup(pool_test) === nothing
        @test negative_followup(pool_test) === nothing

        #tests with follow_up strategies:
        pool_test2 = PoolTest("Pool Test", test, s_strategy, nothing)
        pool_test3 = PoolTest("Pool Test", test, nothing, s_strategy)
        pool_test4 = PoolTest("Pool Test", test, s_strategy, s_strategy)

        @test positive_followup(pool_test2) === s_strategy
        @test negative_followup(pool_test2) === nothing
        @test positive_followup(pool_test3) === nothing
        @test negative_followup(pool_test3) === s_strategy
        @test positive_followup(pool_test4) === s_strategy
        @test negative_followup(pool_test4) === s_strategy

        #test with no input
        @test_throws ArgumentError begin
            pool_test5 = PoolTest()
        end

        #test processing measure:
        result = process_measure(sim, gs, pool_test3)
        follow_up_strategy = result.follow_up

        @test follow_up_strategy === s_strategy

        for ind in indis
            infect!(ind, Int16(0), pathogen(sim), rng = Xoshiro())
        end
        result2 = process_measure(sim, gs, pool_test2)
        follow_up_strategy2 = result2.follow_up

        @test follow_up_strategy2 === s_strategy
    end

    @testset "Vaccinate Measure" begin
        vacc_sim = Simulation()
        fu_strategy = IStrategy("i_strategy", vacc_sim)
        my_vaccine = Vaccine(id = Int8(1), name = "TestVax")
 
        # struct and accessors
        vacc_measure = Vaccinate(my_vaccine)
        vacc_with_followup = Vaccinate(my_vaccine, follow_up = fu_strategy)
 
        @test vaccine(vacc_measure) === my_vaccine
        @test follow_up(vacc_measure) === nothing
        @test follow_up(vacc_with_followup) === fu_strategy
 
        # vaccinate an individual
        ind_a = Individual(id = 10, sex = 0, age = 30)
        result = process_measure(vacc_sim, ind_a, vacc_measure)
 
        @test isvaccinated(ind_a) == true
        @test vaccine_id(ind_a) == id(my_vaccine)
        @test vaccination_tick(ind_a) == tick(vacc_sim)
        @test number_of_vaccinations(ind_a) == 1
        @test result.focal_objects[1] === ind_a
        @test result.follow_up === nothing
 
        # follow_up strategy is forwarded
        ind_b = Individual(id = 11, sex = 1, age = 25)
        result_b = process_measure(vacc_sim, ind_b, vacc_with_followup)
 
        @test isvaccinated(ind_b) == true
        @test result_b.focal_objects[1] === ind_b
        @test result_b.follow_up === fu_strategy
 
        # re-vaccination increments dose count
        result_booster = process_measure(vacc_sim, ind_a, vacc_measure)
 
        @test number_of_vaccinations(ind_a) == 2
        @test result_booster.focal_objects[1] === ind_a
 
        # measure round-trips through add_measure!
        vacc_strategy = IStrategy("vaccinate", vacc_sim)
        add_measure!(vacc_strategy, Vaccinate(my_vaccine))
 
        @test length(vacc_strategy.measures) == 1
        @test vacc_strategy.measures[1].measure isa Vaccinate
        @test vaccine(vacc_strategy.measures[1].measure) === my_vaccine
    end




    @testset "Test All Measure" begin
        test = TestType("Test", pathogen(sim), sim)
        test_all = TestAll("Test All", test)
        add_measure!(s_strategy, test_all)

        @test length(s_strategy.measures) == 7
        @test s_strategy.measures[7].measure === test_all

        @test name(test_all) == "Test All"
        @test type(test_all) === test
        @test positive_followup(test_all) === nothing
        @test negative_followup(test_all) === nothing
        @test GEMS.reportable(test_all) == true

        #tests with follow_up strategies:
        test_all2 = TestAll("Test All", test, s_strategy, nothing)
        test_all3 = TestAll("Test All", test, nothing, s_strategy)
        test_all4 = TestAll("Test All", test, s_strategy, s_strategy, reportable=false)

        @test positive_followup(test_all2) === s_strategy
        @test negative_followup(test_all2) === nothing
        @test positive_followup(test_all3) === nothing
        @test negative_followup(test_all3) === s_strategy
        @test positive_followup(test_all4) === s_strategy
        @test negative_followup(test_all4) === s_strategy
        @test GEMS.reportable(test_all4) === false

        #test with no input
        @test_throws ArgumentError begin
            test_all5 = TestAll()
        end

        #test processing measure:
        result = process_measure(sim, gs2, test_all3)
        follow_up_strategy = result.follow_up

        @test follow_up_strategy === s_strategy

        for ind in indis2
            infect!(ind, Int16(0), pathogen(sim), rng = Xoshiro())
        end
        result2 = process_measure(sim, gs2, test_all2)
        follow_up_strategy2 = result2.follow_up

        @test follow_up_strategy2 === s_strategy
    end

    @testset "Custom S Measure" begin
        measure_function = (s, simobj) -> (size(s) < 5 ? open!(s) : nothing)
        custom_s_measure = CustomSMeasure(measure_function)
        @test typeof(custom_s_measure.measure_logic) == typeof(measure_function)
        @test GEMS.measure_logic(custom_s_measure) === measure_function

        #test process_measure
        @test gs.isopen == false
        process_measure(sim, gs, custom_s_measure)
        @test gs.isopen == true
    end

    @testset "Triggers" begin

        @test length(sim.symptom_triggers) == 1
        @test sim.symptom_triggers[1] === symptom_trigger
        @test length(sim.hospitalization_triggers) == 1
        @test sim.hospitalization_triggers[1] === hospitalization_trigger
        @test length(sim.tick_triggers) == 2
        @test sim.tick_triggers[1] === i_tick_trigger
        @test sim.tick_triggers[2] === s_tick_trigger

        @test strategy(symptom_trigger) === i_strategy
        @test strategy(hospitalization_trigger) === i_strategy
        @test strategy(i_tick_trigger) === i_strategy
        @test strategy(s_tick_trigger) === s_strategy

        @test switch_tick(i_tick_trigger) == -1
        @test interval(i_tick_trigger) == -1

        @test settingtype(s_tick_trigger) === School
        @test switch_tick(s_tick_trigger) == -1
        @test interval(s_tick_trigger) == -1

        #test different configurations of the tick trigger
        i_tick_trigger2 = ITickTrigger(i_strategy, switch_tick=Int16(20), interval=Int16(10))
        s_tick_trigger2 = STickTrigger(Office, s_strategy, switch_tick=Int16(20), interval=Int16(7))

        @test switch_tick(i_tick_trigger2) == 20
        @test interval(i_tick_trigger2) == 10

        @test settingtype(s_tick_trigger2) === Office
        @test switch_tick(s_tick_trigger2) == 20
        @test interval(s_tick_trigger2) == 7

        #test errors
        @test_throws ArgumentError ITickTrigger(i_strategy, switch_tick=Int16(-2))
        @test_throws ArgumentError ITickTrigger(i_strategy, interval=Int16(-2))

        @test_throws ArgumentError STickTrigger(DataType, s_strategy)
        @test_throws ArgumentError STickTrigger(Office, s_strategy, switch_tick=Int16(-2))
        @test_throws ArgumentError STickTrigger(Office, s_strategy, interval=Int16(-2))

        #test trigger function
        sim = Simulation()
        i = Individual(id=1, age=10, sex=1)
        i_measure_function = (i, sim) -> i.mandate_compliance = 0.4
        custom_i_measure = CustomIMeasure(i_measure_function)
        custom_i_strategy = IStrategy("custom i strategy", sim)
        add_measure!(custom_i_strategy, custom_i_measure)
        symptom_trigger = SymptomTrigger(custom_i_strategy)
        add_symptom_trigger!(sim, symptom_trigger)
        GEMS.trigger(symptom_trigger, i, sim)
        step!(sim)
        @test i.mandate_compliance == 0.4f0

        i.mandate_compliance = 0.5

        hospitalization_trigger = HospitalizationTrigger(custom_i_strategy)
        add_hospitalization_trigger!(sim, hospitalization_trigger)
        GEMS.trigger(hospitalization_trigger, i, sim)
        step!(sim)
        @test i.mandate_compliance == 0.4f0

        i_tick_trigger = ITickTrigger(custom_i_strategy)
        add_tick_trigger!(sim, i_tick_trigger)
        GEMS.trigger(i_tick_trigger, sim)
        step!(sim)
        for individual in individuals(sim)
            @test individual.mandate_compliance == 0.4f0
        end

        s_measure_function = (s, simobj) -> (size(s) > 5 ? close!(s) : nothing)
        custom_s_measure = CustomSMeasure(s_measure_function)
        custom_s_strategy = SStrategy("custom s strategy", sim)
        add_measure!(custom_s_strategy, custom_s_measure)
        s_tick_trigger = STickTrigger(Office, custom_s_strategy)
        add_tick_trigger!(sim, s_tick_trigger)
        GEMS.trigger(s_tick_trigger, sim)
        sim_settings = offices(sim)
        step!(sim)
        @test all(h -> (length(h.individuals) <= 5 || !h.isopen), sim_settings)

        #test other return cases of trigger function        
        sim = Simulation()
        i = Individual(id=1, age=10, sex=1)
        i_measure_function = (i, sim) -> i.mandate_compliance = 0.4
        custom_i_measure = CustomIMeasure(i_measure_function)
        custom_i_strategy = IStrategy("custom i strategy", sim, condition=(_) -> false)
        add_measure!(custom_i_strategy, custom_i_measure)
        symptom_trigger = SymptomTrigger(custom_i_strategy)
        add_symptom_trigger!(sim, symptom_trigger)
        GEMS.trigger(symptom_trigger, i, sim)
        step!(sim)
        @test i.mandate_compliance == 0.0f0

        i.mandate_compliance = 0.5

        hospitalization_trigger = HospitalizationTrigger(custom_i_strategy)
        add_hospitalization_trigger!(sim, hospitalization_trigger)
        GEMS.trigger(hospitalization_trigger, i, sim)
        step!(sim)
        @test i.mandate_compliance == 0.5f0

        i_tick_trigger = ITickTrigger(custom_i_strategy)
        add_tick_trigger!(sim, i_tick_trigger)
        GEMS.trigger(i_tick_trigger, sim)
        step!(sim)
        for individual in individuals(sim)
            @test individual.mandate_compliance == 0.0f0
        end

        container = settingscontainer(sim)
        for setting_list in values(container.settings)
            for setting in setting_list
                if size(setting) >= 5
                    open!(setting)
                end
            end
        end
        s_measure_function = (s, simobj) -> (size(s) > 5 ? close!(s) : nothing)
        custom_s_measure = CustomSMeasure(s_measure_function)
        custom_s_strategy = SStrategy("custom s strategy", sim, condition=(_) -> false)
        add_measure!(custom_s_strategy, custom_s_measure)
        s_tick_trigger = STickTrigger(Office, custom_s_strategy)
        add_tick_trigger!(sim, s_tick_trigger)
        GEMS.trigger(s_tick_trigger, sim)
        sim_settings = offices(sim)
        step!(sim)
        @test all(h -> (length(h.individuals) <= 5 || h.isopen), sim_settings)

        sim = Simulation()
        i = Individual(id=1, age=10, sex=1)
        i_measure_function = (i, sim) -> i.mandate_compliance = 0.4
        custom_i_measure = CustomIMeasure(i_measure_function)
        custom_i_strategy = IStrategy("custom i strategy", sim, condition=(_) -> nothing)
        add_measure!(custom_i_strategy, custom_i_measure)
        symptom_trigger = SymptomTrigger(custom_i_strategy)
        add_symptom_trigger!(sim, symptom_trigger)
        @test_throws ErrorException GEMS.trigger(symptom_trigger, i, sim)

        s_measure_function = (s, simobj) -> (size(s) > 5 ? close!(s) : nothing)
        custom_s_measure = CustomSMeasure(s_measure_function)
        custom_s_strategy = SStrategy("custom s strategy", sim, condition=(_) -> nothing)
        add_measure!(custom_s_strategy, custom_s_measure)
        s_tick_trigger = STickTrigger(Office, custom_s_strategy)
        add_tick_trigger!(sim, s_tick_trigger)
        @test_throws ErrorException GEMS.trigger(s_tick_trigger, sim)

        #test should_fire function
        @testset "Testing should_fire" begin
            sim = Simulation()
            strategy = IStrategy("i_strategy", sim)

            # Test 1: `tick < switch_tick(trigger)` → should return false
            trigger1 = ITickTrigger(strategy, switch_tick=Int16(10))
            @test should_fire(trigger1, Int16(5)) == false

            # Test 2: `switch_tick(trigger) == interval(trigger) == -1` → should return true
            trigger2 = ITickTrigger(strategy)
            @test should_fire(trigger2, Int16(5)) == true

            # Test 3: `switch_tick(trigger) == tick && interval(trigger) == -1` → should return true
            trigger3 = ITickTrigger(strategy, switch_tick=Int16(10))
            @test should_fire(trigger3, Int16(10)) == true

            # Test 4: `interval(trigger) > 0 && (tick - max(switch_tick(trigger), 0)) % interval(trigger) == 0` → should return true
            trigger4 = ITickTrigger(strategy, switch_tick=Int16(11), interval=Int16(12))
            @test should_fire(trigger4, Int16(11)) == true  # 11 - 11%12 = 11 - 11 = 0

            # Test 5: Default return → should return false
            trigger5 = ITickTrigger(strategy, switch_tick=Int16(1), interval=Int16(5))
            @test should_fire(trigger5, Int16(7)) == false  # 7 is not a multiple of 5 (interval)
        end
    end

    @testset "Test Measure Events" begin
        sim = Simulation()
        i = Individual(id=1, sex=0, age=31, household=1)
        indis = [Individual(id=j, age=18, sex=1) for j in range(0, 3)]
        rs = RandomSampling()
        gs = GlobalSetting(individuals=indis, contact_sampling_method=rs)
        close!(gs)

        i_measure_function = (i, sim) -> i.mandate_compliance = 0.4
        custom_i_measure = CustomIMeasure(i_measure_function)
        custom_i_strategy = IStrategy("custom i strategy", sim)
        add_measure!(custom_i_strategy, custom_i_measure)

        s_measure_function = (s, simobj) -> (size(s) < 5 ? open!(s) : nothing)
        custom_s_measure = CustomSMeasure(s_measure_function)
        custom_s_strategy = SStrategy("custom s strategy", sim)
        add_measure!(custom_s_strategy, custom_s_measure)

        test = TestType("Test", pathogen(sim), sim)
        test_measure = GEMS.Test("test", test, negative_followup=custom_i_strategy)
        test_all_measure = TestAll("test", test, negative_followup=custom_s_strategy)

        condition = (_) -> true

        i_measure_event = IMeasureEvent(i, test_measure, condition)
        s_measure_event = SMeasureEvent(gs, test_all_measure, condition)

        @test i_measure_event.individual === i
        @test i_measure_event.measure === test_measure
        @test i_measure_event.condition isa GEMS.IPredicate
        @test i_measure_event.condition(i) == true

        @test s_measure_event.setting === gs
        @test s_measure_event.measure === test_all_measure
        @test s_measure_event.condition isa GEMS.SPredicate
        @test s_measure_event.condition(gs) == true

        #test process_event
        GEMS.process_event(i_measure_event, sim)
        step!(sim)
        @test i.mandate_compliance == 0.4f0

        GEMS.process_event(s_measure_event, sim)
        step!(sim)
        @test gs.isopen === true

        #test different inputs
        condition2 = (_) -> false

        i_measure_event2 = IMeasureEvent(i, test_measure, condition2)
        s_measure_event2 = SMeasureEvent(gs, test_all_measure, condition2)

        @test GEMS.process_event(i_measure_event2, sim) === nothing
        @test GEMS.process_event(s_measure_event2, sim) === nothing


        i_measure_function2 = (i, sim) -> i.mandate_compliance = 0.5
        custom_i_measure2 = CustomIMeasure(i_measure_function2)

        s_measure_function2 = (s, simobj) -> (size(s) < 5 ? close!(s) : nothing)
        custom_s_measure2 = CustomSMeasure(s_measure_function2)

        i_measure_event3 = IMeasureEvent(i, custom_i_measure2, condition)
        s_measure_event3 = SMeasureEvent(gs, custom_s_measure2, condition)

        @test GEMS.process_event(i_measure_event3, sim) === nothing
        @test i.mandate_compliance == 0.5f0

        @test GEMS.process_event(s_measure_event3, sim) === nothing
        @test gs.isopen === false

        #test event queue
        @testset "Event Queue" begin
            eq = EventQueue()
            @test length(eq) == 0
            @test isempty(eq) === true

            # enqueue events at different ticks
            enqueue!(eq, s_measure_event, Int16(3))
            enqueue!(eq, i_measure_event, Int16(5))
            @test length(eq) == 2
            @test isempty(eq) === false

            # peek returns the next (earliest-tick) event without removing it
            @test peektick(eq) == Int16(3)
            @test peek(eq) === s_measure_event
            @test length(eq) == 2
            # peek is non-destructive and points at whatever dequeue! removes next
            @test peek(eq) === dequeue!(eq)
            @test length(eq) == 1

            # within a single tick bucket, peek matches the next dequeue! (LIFO order)
            enqueue!(eq, s_measure_event, Int16(5))
            @test peektick(eq) == Int16(5)
            @test peek(eq) === dequeue!(eq)

            # empty! removes all remaining events but keeps the queue reusable
            empty!(eq)
            @test length(eq) == 0
            @test isempty(eq) === true

            # queue still works after empty!: head resets and new events enqueue normally
            enqueue!(eq, i_measure_event, Int16(7))
            @test length(eq) == 1
            @test peektick(eq) == Int16(7)
            @test peek(eq) === i_measure_event

            # staged events are not visible until flush_staging! merges them in
            empty!(eq)
            stage!(eq, s_measure_event, Int16(4))
            stage!(eq, i_measure_event, Int16(2))
            @test length(eq) == 0
            @test isempty(eq) === true

            flush_staging!(eq)
            @test length(eq) == 2
            @test peektick(eq) == Int16(2)
            @test peek(eq) === i_measure_event

            # flush clears the staging buffers: a second flush adds nothing
            flush_staging!(eq)
            @test length(eq) == 2

            # empty! also clears any staged-but-unflushed events
            stage!(eq, i_measure_event, Int16(9))
            empty!(eq)
            flush_staging!(eq)
            @test length(eq) == 0
        end
    end

    @testset "Scenarios" begin
        @testset "Self-Isolation" begin
            # everyone is symptomatic and should therefore self-isolate
            # for 14 days. With 10 initial infections and no transmission,
            # 10*14 total quarantine days should be recorded
            p = Pathogen(
                name = "COVID19",
                progressions = [Symptomatic(
                    exposure_to_infectiousness_onset = 1,
                    infectiousness_onset_to_symptom_onset = 0,
                    symptom_onset_to_recovery = 7
                )],
                transmission_function = ConstantTransmissionRate(transmission_rate = 0.0) # no transmission
            )
            sim = Simulation(
                pop_size = 1000,
                pathogen = p,
                infected_fraction = 0.01) # 10 people infected at start
            
            # self-isolation strategy
            i_strategy = IStrategy("Self-Isolation Strategy", sim)
            add_measure!(i_strategy,  SelfIsolation(14))
            symptom_trigger = SymptomTrigger(i_strategy)
            add_symptom_trigger!(sim, symptom_trigger)
            
            run!(sim)
            rd = ResultData(sim)
            @test total_quarantines(rd) == 10*14
        end
    end
end