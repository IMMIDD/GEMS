using GEMS
using Profile


function build_sim()
    sim = Simulation(
        population = "HE",
        label = "Benchmark SL"
    )

    rapid_test = TestType("Rapid Test", pathogen(sim), sim;
        sensitivity = 0.85, specificity = 0.97)

    # Follow-up on positive test: isolate for 10 ticks
    isolate_pos = IStrategy("isolate-on-positive", sim)
    add_measure!(isolate_pos, SelfIsolation(Int16(10)))

    # SymptomTrigger: isolate immediately + test after 1 tick
    on_symptoms = IStrategy("symptoms-isolate-and-test", sim)
    add_measure!(on_symptoms, SelfIsolation(Int16(7)))
    add_measure!(on_symptoms, Test("symptom-test", rapid_test;
        positive_followup = isolate_pos), offset = 1)
    add_symptom_trigger!(sim, SymptomTrigger(on_symptoms))

    # ITickTrigger: 5% random surveillance testing every 7 ticks starting at tick 10
    surveillance = IStrategy("surveillance-testing", sim;
        condition = i -> rand() < 0.05)
    add_measure!(surveillance, Test("surveillance", rapid_test;
        positive_followup = isolate_pos))
    add_tick_trigger!(sim, ITickTrigger(surveillance;
        switch_tick = Int16(10), interval = Int16(7)))

    # Household member tracing → 14-tick quarantine
    hh_quarantine = IStrategy("hh-quarantine", sim)
    add_measure!(hh_quarantine, SelfIsolation(Int16(14)))

    # STickTrigger: find adult household members every 14 ticks from tick 5
    find_hh = SStrategy("find-hh-adults", sim)
    add_measure!(find_hh, FindMembers(hh_quarantine;
        selectionfilter = i -> age(i) >= 18))
    add_tick_trigger!(sim, STickTrigger(Household, find_hh;
        switch_tick = Int16(5), interval = Int16(14)))

    # STickTrigger: close all school classes once at tick 30
    close_schools = SStrategy("close-school-classes", sim)
    add_measure!(close_schools, CloseSetting())
    add_tick_trigger!(sim, STickTrigger(SchoolClass, close_schools;
        switch_tick = Int16(30)))

    # STickTrigger: reopen all school classes once at tick 60
    open_schools = SStrategy("reopen-school-classes", sim)
    add_measure!(open_schools, OpenSetting())
    add_tick_trigger!(sim, STickTrigger(SchoolClass, open_schools;
        switch_tick = Int16(60)))

    return sim
end

function build_sim_simple()
    sim = Simulation(
        population = "HE",
    )
    return sim
end

# total number of infections recorded in a finished simulation (atomic counter,
# no ResultData needed)
n_infections(sim) = infectionlogger(sim).infection_counter[]



# JIT warmup pass
@time sim = Simulation(population="HE")
@time run!(sim)
@time ResultData(sim)



@time run!(build_sim())

# Profiled pass
@profview run!(build_sim())


@time run!(build_sim_simple())