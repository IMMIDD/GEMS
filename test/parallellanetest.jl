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
        @test !GEMS._parallel_safe(FindMembers(lane_followup, sample_size = 1), true)
        @test !GEMS._parallel_safe(FindMembers(lane_followup, selectionfilter = i -> true), true)
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
        add_measure!(lane, SelfIsolation(1), condition = i -> true, delay = i -> 0, parallel = true)
        @test entry_parallel(lane)

        # vouching for its closures does not make an unsafe measure parallel
        closing = SStrategy("closing", lane_sim)
        add_measure!(closing, CloseSetting(), delay = s -> 0, parallel = true)
        @test !entry_parallel(closing)
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
            once = IStrategy("once", sim, condition = i -> !isolated(i), parallel = true)
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

        @testset "Setting Chunks Reach All Members" begin
            (; sim, members, isolated) = round_setup()
            homes = households(sim)[1:slots + 1]
            foreach(h -> GEMS.trigger_strategy(members, h, sim), homes)
            GEMS.process_events!(sim)
            @test all(h -> all(isolated, individuals(h)), homes)
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
