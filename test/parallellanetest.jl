# a measure that hands over to the next target, so that a chain crosses the shards
struct HopMeasure <: GEMS.IMeasure
    targets::Vector{Individual}
    visited::Vector{Int32}
    follow_up::Base.RefValue{IStrategy}
end
GEMS._parallel_safe(::HopMeasure, ::Bool) = true
function GEMS.process_measure(sim::Simulation, ind::Individual, m::HopMeasure)
    push!(m.visited, id(ind))
    k = length(m.visited)
    k < length(m.targets) && GEMS.trigger_strategy(m.follow_up[], m.targets[k + 1], sim)
    return nothing
end

@testset "Parallel Lane" begin
    @testset "Classification" begin
        lane_sim = Simulation(pop_size = 100, seed = 7)
        lane_type = TestType("lane", pathogen(lane_sim), lane_sim)
        lane_followup = IStrategy("follow up", lane_sim)
        @test GEMS._parallel_safe(GEMS.Test("lane", lane_type), false)
        @test GEMS._parallel_safe(SelfIsolation(1), false)
        @test GEMS._parallel_safe(CancelSelfIsolation(), false)
        @test GEMS._parallel_safe(FindMembers(lane_followup), false)
        lane_setting_followup = SStrategy("setting follow up", lane_sim)
        @test GEMS._parallel_safe(FindSetting(Household, lane_setting_followup), false)
        @test GEMS._parallel_safe(FindSettings(Household, lane_setting_followup), false)
        @test GEMS._parallel_safe(FindSettingMembers(Household, lane_followup), false)
        @test GEMS._parallel_safe(PoolTest("lane", lane_type), false)
        @test GEMS._parallel_safe(IsOpen(positive_followup = lane_setting_followup), false)
        @test GEMS._parallel_safe(Vaccinate(Vaccine(id = 1, name = "lane", target_pathogen_id = id(pathogen(lane_sim)))), false)
        @test GEMS._parallel_safe(FindMembers(lane_followup, sample_size = 1), false)
        @test !GEMS._parallel_safe(FindMembers(lane_followup, selectionfilter = i -> true), false)
        @test GEMS._parallel_safe(FindMembers(lane_followup, selectionfilter = i -> true), true)
        @test !GEMS._parallel_safe(CloseSetting(), true)
        @test !GEMS._parallel_safe(CustomIMeasure((i, s) -> nothing), true)

        entry_parallel(str) = last(measures(str)).parallel
        lane = IStrategy("lane", lane_sim)
        add_measure!(lane, SelfIsolation(1))
        @test entry_parallel(lane)
        add_measure!(lane, SelfIsolation(1), condition = i -> true)
        @test !entry_parallel(lane)
        add_measure!(lane, SelfIsolation(1), delay = i -> 0)
        @test !entry_parallel(lane)
        add_measure!(lane, SelfIsolation(1), condition = i -> true, delay = i -> 0, threadsafe = true)
        @test entry_parallel(lane)

        # vouching for its closures does not make an unsafe measure parallel
        closing = SStrategy("closing", lane_sim)
        add_measure!(closing, CloseSetting(), delay = s -> 0, threadsafe = true)
        @test !entry_parallel(closing)
    end

    @testset "Threadsafe Marks" begin
        mark_sim = Simulation(pop_size = 100, seed = 7)
        # a mark without a closure to cover changes nothing
        no_closures = IStrategy("no closures", mark_sim, threadsafe = true)
        add_measure!(no_closures, SelfIsolation(1), threadsafe = true)
        @test GEMS._parallel_strategy(no_closures)
        # a mark on one call does not cover the closures of another
        marked = IStrategy("marked", mark_sim, condition = i -> true, threadsafe = true)
        add_measure!(marked, SelfIsolation(1), condition = i -> true)
        @test !GEMS._parallel_strategy(marked)
    end

    # the hint needs threads to promise a gain
    if Threads.nthreads() > 1
        @testset "Threadsafe Hint" begin
            hint_sim(pop_size = GEMS.TICK_TRIGGER_THREADING_MIN + 1000) = Simulation(pop_size = pop_size, seed = 7)
            hint_logged(sim) = (logger = Test.TestLogger(min_level = Logging.Info);
                Logging.with_logger(() -> GEMS._hint_threadsafe_option(sim), logger); [l.message for l in logger.logs])

            # an unmarked closure on a strategy that could run in the lane is named
            sim = hint_sim()
            held_back = IStrategy("held back", sim, condition = i -> true)
            add_measure!(held_back, SelfIsolation(1))
            add_tick_trigger!(sim, ITickTrigger(held_back))
            messages = hint_logged(sim)
            @test length(messages) == 1
            @test occursin("held back", messages[1]) && occursin("threadsafe = true", messages[1])
            @test !occursin('\n', messages[1]) && occursin("events run (like", messages[1])

            # marked closures, and strategies without closures, are not
            sim = hint_sim()
            marked = IStrategy("marked", sim, condition = i -> true, threadsafe = true)
            add_measure!(marked, SelfIsolation(1), condition = i -> true, threadsafe = true)
            plain = IStrategy("plain", sim)
            add_measure!(plain, SelfIsolation(1))
            add_tick_trigger!(sim, ITickTrigger(marked))
            @test isempty(hint_logged(sim))

            # a measure that stays serial cannot gain from a mark on an individual strategy
            sim = hint_sim()
            unsafe = IStrategy("unsafe", sim, condition = i -> true)
            add_measure!(unsafe, CustomIMeasure((i, s) -> nothing))
            add_tick_trigger!(sim, ITickTrigger(unsafe))
            @test isempty(hint_logged(sim))

            # but a setting strategy's condition still gains on its threaded tick trigger
            sim = hint_sim()
            closing = SStrategy("closing", sim, condition = s -> true)
            add_measure!(closing, CloseSetting())
            add_tick_trigger!(sim, STickTrigger(Household, closing))
            @test occursin("closing", only(hint_logged(sim)))

            # an unmarked filter is named too
            sim = hint_sim()
            filtered = SStrategy("filtered", sim)
            add_measure!(filtered, FindMembers(IStrategy("found", sim), selectionfilter = i -> true))
            add_tick_trigger!(sim, STickTrigger(Household, filtered))
            @test occursin("filtered", only(hint_logged(sim)))

            # no tick trigger, or a small population: nothing to gain
            sim = hint_sim()
            no_trigger = IStrategy("no trigger", sim, condition = i -> true)
            add_measure!(no_trigger, SelfIsolation(1))
            @test isempty(hint_logged(sim))
            sim = hint_sim(100)
            small = IStrategy("small", sim, condition = i -> true)
            add_measure!(small, SelfIsolation(1))
            add_tick_trigger!(sim, ITickTrigger(small))
            @test isempty(hint_logged(sim))
        end
    end

    @testset "Rounds" begin
        slots = Threads.maxthreadid()
        shard(i) = Int(GEMS._owner_shard(id(i)))

        # a small simulation with one strategy per way of routing
        function round_setup()
            round_sim = Simulation(pop_size = 1000, seed = 11)
            isolate = IStrategy("isolate", round_sim)
            add_measure!(isolate, SelfIsolation(2))
            custom = IStrategy("custom", round_sim)
            add_measure!(custom, CustomIMeasure((i, s) -> nothing))
            members = SStrategy("members", round_sim)
            add_measure!(members, FindMembers(isolate))
            return (sim = round_sim, inds = individuals(round_sim), parallel_lane = GEMS._parallel_lane(round_sim),
                isolate = isolate, custom = custom, members = members,
                isolated = i -> isquarantined(i, tick(round_sim)))
        end

        @testset "Serial Code Queues Directly" begin
            (; inds, isolate, sim, custom, members) = round_setup()
            target = inds[1]
            GEMS.trigger_strategy(isolate, target, sim)
            @test length(GEMS._owner_queue(sim, shard(target))) == 1
            @test isempty(GEMS.event_queue(sim))
            GEMS.trigger_strategy(custom, target, sim)
            @test length(GEMS.event_queue(sim)) == 1
            GEMS.trigger_strategy(members, households(sim)[1], sim)
            @test length(GEMS._setting_queue(sim)) == 1
        end

        @testset "Requests Reach The Owner In Order" begin
            (; inds, sim, isolate, parallel_lane, isolated) = round_setup()
            targets = inds[1:20]
            GEMS._with_slot(sim, slots) do
                foreach(i -> GEMS.trigger_strategy(isolate, i, sim), targets)
            end
            for owner in 1:slots
                @test [r.individual for r in parallel_lane.owner_requests[slots, owner]] == filter(i -> shard(i) == owner, targets)
            end
            @test isempty(queued_events(sim))
            @test GEMS._owner_requests_pending(sim)
            @test !isolated(targets[1])
            GEMS.process_events!(sim)
            @test all(isolated, targets)
            @test all(isempty, parallel_lane.owner_requests)
            @test !GEMS._owner_requests_pending(sim)
        end

        # needs a second shard
        if slots > 1
            @testset "Owner Phase Runs Its Own People Inline" begin
                (; inds, sim, isolate, parallel_lane) = round_setup()
                own = inds[1]
                other = inds[findfirst(i -> shard(i) != shard(own), inds)]
                GEMS._with_slot(sim, shard(own), owner_phase = true) do
                    GEMS.trigger_strategy(isolate, own, sim)
                    GEMS.trigger_strategy(isolate, other, sim)
                end
                @test length(GEMS._owner_queue(sim, shard(own))) == 1
                @test [r.individual for r in parallel_lane.next_owner_requests[shard(own), shard(other)]] == [other]
                @test isempty(parallel_lane.owner_requests[shard(own), shard(other)])
            end
        end

        @testset "Serial Entries And Setting Strategies Go Through Serial Code" begin
            (; inds, sim, custom, members, parallel_lane) = round_setup()
            target, household = inds[1], households(sim)[1]
            GEMS._with_slot(sim, shard(target), owner_phase = true) do
                GEMS.trigger_strategy(custom, target, sim)
                GEMS.trigger_strategy(members, household, sim)
            end
            @test [r.individual for r in parallel_lane.serial_individual_requests[shard(target)]] == [target]
            @test [r.setting for r in parallel_lane.serial_setting_requests[shard(target)]] == [household]
            @test isempty(queued_events(sim))
            GEMS._run_serial_requests!(sim)
            @test all(isempty, parallel_lane.serial_individual_requests)
            @test all(isempty, parallel_lane.serial_setting_requests)
            @test length(GEMS.event_queue(sim)) == 1
            @test length(GEMS._setting_queue(sim)) == 1
        end

        @testset "A Second Request Sees The First" begin
            (; sim, isolated, isolate, inds) = round_setup()
            always_positive = TestType("rounds", pathogen(sim), sim, sensitivity = 1.0, specificity = 0.0)
            once = IStrategy("once", sim, condition = i -> !isolated(i), threadsafe = true)
            add_measure!(once, GEMS.Test("once", always_positive, positive_followup = isolate))
            target = inds[1]
            GEMS._with_slot(sim, 1) do
                GEMS.trigger_strategy(once, target, sim)
                GEMS.trigger_strategy(once, target, sim)
            end
            GEMS.process_events!(sim)
            @test isolated(target)
            @test count(==(id(target)), dataframe(testlogger(sim)).id) == 1
        end

        @testset "A Chain Across Shards Finishes In The Tick" begin
            (; inds, sim) = round_setup()
            hops = inds[1:6]
            hop = IStrategy("hop", sim)
            hop_measure = HopMeasure(hops, Int32[], Ref{IStrategy}(hop))
            add_measure!(hop, hop_measure)
            @test GEMS._parallel_strategy(hop)
            GEMS.trigger_strategy(hop, hops[1], sim)
            GEMS.process_events!(sim)
            @test hop_measure.visited == id.(hops)
            @test isempty(queued_events(sim))
            @test !GEMS._owner_requests_pending(sim)
        end

        # needs a household spread over two shards
        if slots > 1
            @testset "Member Lookups Reach Other Shards In The Tick" begin
                (; sim, isolate, isolated) = round_setup()
                lookup = IStrategy("lookup", sim)
                add_measure!(lookup, FindSettingMembers(Household, isolate))
                @test GEMS._parallel_strategy(lookup)
                home = households(sim)[findfirst(h -> length(unique(shard.(individuals(h)))) > 1, households(sim))]
                GEMS.trigger_strategy(lookup, first(individuals(home)), sim)
                @test isempty(GEMS.event_queue(sim))
                GEMS.process_events!(sim)
                @test all(isolated, individuals(home))
                @test isempty(queued_events(sim))
                @test !GEMS._owner_requests_pending(sim)
            end
        end

        @testset "Doses On Every Shard Register Each Vaccine Once" begin
            (; sim, inds) = round_setup()
            pid = id(pathogen(sim))
            dose = IStrategy("dose", sim)
            add_measure!(dose, Vaccinate(Vaccine(id = 1, name = "first", target_pathogen_id = pid, peak = 70)))
            add_measure!(dose, Vaccinate(Vaccine(id = 2, name = "second", target_pathogen_id = pid, peak = 60)))
            @test GEMS._parallel_strategy(dose)
            foreach(i -> GEMS.trigger_strategy(dose, i, sim), inds)
            @test isempty(GEMS.event_queue(sim))
            GEMS.process_events!(sim)
            @test sim.vaccine_table.registered[pid][] == 0b11
            @test [sim.vaccine_table.protection[v, pid].peak for v in 1:2] == [70, 60]
            @test nrow(dataframe(vaccinationlogger(sim))) == 2 * length(inds)
        end

        @testset "Conflicting First Doses In One Phase Throw" begin
            (; sim, inds) = round_setup()
            pid = id(pathogen(sim))
            dose = IStrategy("dose", sim)
            add_measure!(dose, Vaccinate(Vaccine(id = 1, name = "one", target_pathogen_id = pid, peak = 70)))
            add_measure!(dose, Vaccinate(Vaccine(id = 1, name = "other", target_pathogen_id = pid, peak = 60)))
            foreach(i -> GEMS.trigger_strategy(dose, i, sim), inds)
            failure = try GEMS.process_events!(sim); nothing catch e; e end
            @test occursin("registered with other peaks", sprint(showerror, failure))
        end

        @testset "Setting Lookups Return Through Serial Code In The Tick" begin
            (; inds, sim, members, isolated) = round_setup()
            lookup = IStrategy("lookup", sim)
            add_measure!(lookup, FindSetting(Household, members))
            target = inds[1]
            GEMS.trigger_strategy(lookup, target, sim)
            @test isempty(GEMS.event_queue(sim))
            GEMS.process_events!(sim)
            @test all(isolated, individuals(household(target, sim)))
            @test isempty(queued_events(sim))
        end

        @testset "Setting Chunks Reach All Members" begin
            (; sim, members, isolated) = round_setup()
            homes = households(sim)[1:slots + 1]
            foreach(h -> GEMS.trigger_strategy(members, h, sim), homes)
            GEMS.process_events!(sim)
            @test all(h -> all(isolated, individuals(h)), homes)
        end

        @testset "Sampled And Marked Filtered Members Run In The Setting Phase" begin
            (; sim, isolate, isolated) = round_setup()
            sample = SStrategy("sample", sim)
            add_measure!(sample, FindMembers(isolate, sample_size = 1, selectionfilter = i -> true), threadsafe = true)
            homes = households(sim)[1:slots + 1]
            foreach(h -> GEMS.trigger_strategy(sample, h, sim), homes)
            @test isempty(GEMS.event_queue(sim))
            GEMS.process_events!(sim)
            @test all(h -> count(isolated, individuals(h)) == 1, homes)
        end

        @testset "Pool Tests Log Every Setting" begin
            (; sim) = round_setup()
            pool = SStrategy("pool", sim)
            add_measure!(pool, PoolTest("pool", TestType("pool", pathogen(sim), sim)))
            homes = households(sim)[1:slots + 1]
            foreach(h -> GEMS.trigger_strategy(pool, h, sim), homes)
            @test isempty(GEMS.event_queue(sim))
            GEMS.process_events!(sim)
            @test sort(dataframe(pooltestlogger(sim)).setting_id) == id.(homes)
        end

        @testset "An Open Check Sees The Close Listed Before It" begin
            (; sim, members, isolated) = round_setup()
            check = SStrategy("check", sim)
            add_measure!(check, CloseSetting())
            add_measure!(check, IsOpen(negative_followup = members))
            home = households(sim)[1]
            GEMS.trigger_strategy(check, home, sim)
            GEMS.process_events!(sim)
            @test all(isolated, individuals(home))
        end

        @testset "is_dormant Wakes For The Parallel Lane" begin
            dormant_sim = Simulation(pop_size = 100)
            step!(dormant_sim)
            @test GEMS.is_dormant(dormant_sim)
            dormant_isolate = IStrategy("isolate", dormant_sim)
            add_measure!(dormant_isolate, SelfIsolation(1))
            GEMS.trigger_strategy(dormant_isolate, individuals(dormant_sim)[1], dormant_sim)
            @test !GEMS.is_dormant(dormant_sim)
            empty!(queued_events(dormant_sim))
            dormant_members = SStrategy("members", dormant_sim)
            add_measure!(dormant_members, FindMembers(dormant_isolate))
            GEMS.trigger_strategy(dormant_members, households(dormant_sim)[1], dormant_sim)
            @test !GEMS.is_dormant(dormant_sim)
            empty!(queued_events(dormant_sim))
            # also for requests left by code that runs after the events of a tick
            GEMS._with_slot(dormant_sim, 1) do
                GEMS.trigger_strategy(dormant_isolate, individuals(dormant_sim)[1], dormant_sim)
            end
            @test isempty(queued_events(dormant_sim))
            @test !GEMS.is_dormant(dormant_sim)
            GEMS.process_events!(dormant_sim)
        end

        @testset "reset! Empties The Queues And Requests" begin
            (; isolate, inds, sim, members, custom) = round_setup()
            GEMS.trigger_strategy(isolate, inds[1], sim)
            GEMS.trigger_strategy(members, households(sim)[1], sim)
            GEMS._with_slot(sim, 1) do
                GEMS.trigger_strategy(isolate, inds[2], sim)
                GEMS.trigger_strategy(custom, inds[2], sim)
                GEMS.trigger_strategy(members, households(sim)[1], sim)
            end
            GEMS.reset!(sim)
            lane_state = GEMS._parallel_lane(sim)
            @test isempty(queued_events(sim))
            @test all(isempty, lane_state.owner_requests)
            @test all(isempty, lane_state.serial_individual_requests)
            @test all(isempty, lane_state.serial_setting_requests)
            @test all(isempty, lane_state.staged_setting_events)
            @test !GEMS._owner_requests_pending(sim)
        end

        @testset "The Order Of The Slots Makes No Difference" begin
            function run_lane()
                lane_sim = Simulation(pop_size = GEMS.TICK_TRIGGER_THREADING_MIN + 1000, seed = 11)
                lane_type = TestType("lane", pathogen(lane_sim), lane_sim, sensitivity = 0.9, specificity = 0.9)
                lane_isolate = IStrategy("isolate", lane_sim)
                add_measure!(lane_isolate, SelfIsolation(3))
                screen = IStrategy("screen", lane_sim)
                add_measure!(screen, GEMS.Test("screen", lane_type, positive_followup = lane_isolate))
                lane_members = SStrategy("members", lane_sim)
                add_measure!(lane_members, FindMembers(screen))
                add_tick_trigger!(lane_sim, ITickTrigger(screen, interval = Int16(5)))
                add_tick_trigger!(lane_sim, STickTrigger(Household, lane_members, switch_tick = Int16(2), interval = Int16(5)))
                for _ in 1:15
                    step!(lane_sim)
                end
                return dataframe(testlogger(lane_sim))
            end
            in_order = run_lane()
            @test nrow(in_order) > 0
            @test in_order == with_shuffled_slots(run_lane)
        end
    end
end
