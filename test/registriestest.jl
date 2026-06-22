import GEMS: push_infection!, remove_infection!, remove_infections!,
    push_immunity!, remove_immunities!,
    set_test_state!, _test_key,
    _SlotRemoval

@testset "Registries" begin

    ###
    ### InfectionRegistry
    ###
    @testset "InfectionRegistry" begin

        @testset "push_infection! cache path" begin
            reg = InfectionRegistry()
            i = Individual(id=1, sex=0, age=30)
            dp = DiseaseProgression(exposure=Int16(1), infectiousness_onset=Int16(3), recovery=Int16(10))

            # first push fills the only cache slot (INFECTIONS_CACHE_SIZE = 1)
            push_infection!(reg, i, Int8(1), Int32(1), dp)
            @test i.infection_cache[1].active
            @test i.infection_cache[1].pathogen_id == Int8(1)
            @test i.infection_head == Int32(0)   # no overflow yet
            @test isempty(reg.states)
        end

        @testset "push_infection! overflow path" begin
            reg = InfectionRegistry()
            i = Individual(id=1, sex=0, age=30)
            dp1 = DiseaseProgression(exposure=Int16(1), infectiousness_onset=Int16(3), recovery=Int16(10))
            dp2 = DiseaseProgression(exposure=Int16(2), infectiousness_onset=Int16(4), recovery=Int16(15))

            push_infection!(reg, i, Int8(1), Int32(1), dp1)  # cache slot
            push_infection!(reg, i, Int8(2), Int32(2), dp2)  # overflow

            @test length(reg.states) == 1
            @test i.infection_head == Int32(1)
            @test reg.states[1].pathogen_id == Int8(2)
        end

        @testset "remove_infection! cache removal promotes overflow to cache" begin
            reg = InfectionRegistry()
            i = Individual(id=1, sex=0, age=30)
            dp1 = DiseaseProgression(exposure=Int16(1), infectiousness_onset=Int16(2), recovery=Int16(10))
            dp2 = DiseaseProgression(exposure=Int16(1), infectiousness_onset=Int16(2), recovery=Int16(15))

            push_infection!(reg, i, Int8(1), Int32(1), dp1)  # cache slot 1
            push_infection!(reg, i, Int8(2), Int32(2), dp2)  # overflow node 1

            # remove cache slot 1; should promote overflow node into cache
            remove_infection!(reg, i, _SlotRemoval(i.id, false, Int32(1)))
            @test i.infection_cache[1].pathogen_id == Int8(2)
            @test i.infection_head == Int32(0)
            @test length(reg.free_slots) == 1  # freed overflow slot returned to pool
        end

        @testset "remove_infection! overflow removal" begin
            reg = InfectionRegistry()
            i = Individual(id=1, sex=0, age=30)
            dp1 = DiseaseProgression(exposure=Int16(1), infectiousness_onset=Int16(2), recovery=Int16(10))
            dp2 = DiseaseProgression(exposure=Int16(1), infectiousness_onset=Int16(2), recovery=Int16(15))

            push_infection!(reg, i, Int8(1), Int32(1), dp1)
            push_infection!(reg, i, Int8(2), Int32(2), dp2)

            # remove the overflow node (index 1 in reg.states)
            remove_infection!(reg, i, _SlotRemoval(i.id, true, Int32(1)))
            @test i.infection_head == Int32(0)
            @test !isempty(reg.free_slots)  # slot returned to pool
        end

        @testset "remove_infection! non-head overflow removal" begin
            # three infections: cache=pid1, head is pid3(node2) which points to pid2(node1)
            # removing node1 (pid2, non-head) exercises the prev!=0 branch
            reg = InfectionRegistry()
            i = Individual(id=1, sex=0, age=30)
            dp = DiseaseProgression(exposure=Int16(1), infectiousness_onset=Int16(2), recovery=Int16(10))

            push_infection!(reg, i, Int8(1), Int32(1), dp)  # cache
            push_infection!(reg, i, Int8(2), Int32(2), dp)  # overflow node 1
            push_infection!(reg, i, Int8(3), Int32(3), dp)  # overflow node 2 (new head)

            remove_infection!(reg, i, _SlotRemoval(i.id, true, Int32(1)))  # remove non-head node (pid2)
            @test i.infection_head == Int32(2)   # head still points to pid3's node
            @test length(reg.free_slots) == 1
        end

        @testset "free slot reuse" begin
            reg = InfectionRegistry()
            i = Individual(id=1, sex=0, age=30)
            dp = DiseaseProgression(exposure=Int16(1), infectiousness_onset=Int16(2), recovery=Int16(10))

            push_infection!(reg, i, Int8(1), Int32(1), dp)
            push_infection!(reg, i, Int8(2), Int32(2), dp)
            remove_infection!(reg, i, _SlotRemoval(i.id, true, Int32(1)))  # free overflow slot 1
            push_infection!(reg, i, Int8(3), Int32(3), dp)  # should reuse slot 1

            @test length(reg.states) == 1  # no new allocation, reused existing slot
            @test reg.free_slots |> isempty
        end

        @testset "remove_infections! clears all overflow" begin
            reg = InfectionRegistry()
            i = Individual(id=1, sex=0, age=30)
            dp = DiseaseProgression(exposure=Int16(1), infectiousness_onset=Int16(2), recovery=Int16(10))

            push_infection!(reg, i, Int8(1), Int32(1), dp)
            push_infection!(reg, i, Int8(2), Int32(2), dp)

            remove_infections!(reg, i)
            @test i.infection_head == Int32(0)
            @test length(reg.free_slots) == 1  # overflow slot returned
        end

    end


    ###
    ### ImmunityRegistry
    ###
    @testset "ImmunityRegistry" begin

        @testset "push_immunity! cache path" begin
            reg = ImmunityRegistry()
            i = Individual(id=1, sex=0, age=30)

            push_immunity!(reg, i, Int8(1), GEMS.IMMUNITY_SOURCE_NATURAL, Int16(5), Int8(0))
            @test GEMS._is_active_immunity(i.immunity_cache[1])
            @test i.immunity_cache[1].pathogen_id == Int8(1)
            @test i.immunity_head == Int32(0)
        end

        @testset "push_immunity! updates existing cache entry" begin
            reg = ImmunityRegistry()
            i = Individual(id=1, sex=0, age=30)

            push_immunity!(reg, i, Int8(1), GEMS.IMMUNITY_SOURCE_NATURAL, Int16(5), Int8(0))
            push_immunity!(reg, i, Int8(1), GEMS.IMMUNITY_SOURCE_NATURAL, Int16(10), Int8(0))

            # same pathogen_id: updates in place, no overflow
            @test i.immunity_head == Int32(0)
            @test i.immunity_cache[1].natural_acquired_tick == Int16(10)
        end

        @testset "push_immunity! overflow path (new node)" begin
            reg = ImmunityRegistry()
            i = Individual(id=1, sex=0, age=30)

            push_immunity!(reg, i, Int8(1), GEMS.IMMUNITY_SOURCE_NATURAL, Int16(5), Int8(0))   # cache slot
            push_immunity!(reg, i, Int8(2), GEMS.IMMUNITY_SOURCE_NATURAL, Int16(6), Int8(0))   # overflow

            @test i.immunity_head == Int32(1)
            @test reg.states[1].pathogen_id == Int8(2)
        end

        @testset "push_immunity! updates existing overflow node" begin
            reg = ImmunityRegistry()
            i = Individual(id=1, sex=0, age=30)

            push_immunity!(reg, i, Int8(1), GEMS.IMMUNITY_SOURCE_NATURAL, Int16(5), Int8(0))
            push_immunity!(reg, i, Int8(2), GEMS.IMMUNITY_SOURCE_NATURAL, Int16(6), Int8(0))   # overflow node
            push_immunity!(reg, i, Int8(2), GEMS.IMMUNITY_SOURCE_NATURAL, Int16(9), Int8(0))   # update overflow node

            @test length(reg.states) == 1  # no second node allocated
            @test reg.states[1].natural_acquired_tick == Int16(9)
        end

        @testset "ImmunityRegistry free slot reuse" begin
            reg = ImmunityRegistry()
            i = Individual(id=1, sex=0, age=30)

            push_immunity!(reg, i, Int8(1), GEMS.IMMUNITY_SOURCE_NATURAL, Int16(5), Int8(0))
            push_immunity!(reg, i, Int8(2), GEMS.IMMUNITY_SOURCE_NATURAL, Int16(6), Int8(0))
            remove_immunities!(reg, i)  # frees overflow slot 1
            push_immunity!(reg, i, Int8(2), GEMS.IMMUNITY_SOURCE_NATURAL, Int16(7), Int8(0))  # reuses slot 1

            @test length(reg.states) == 1   # no new allocation
            @test reg.free_slots |> isempty
        end

        @testset "push_immunity! overflow traversal (advance past non-matching node)" begin
            # with two overflow nodes, searching for a third pathogen traverses node = s.next
            reg = ImmunityRegistry()
            i = Individual(id=1, sex=0, age=30)

            push_immunity!(reg, i, Int8(1), GEMS.IMMUNITY_SOURCE_NATURAL, Int16(5), Int8(0))  # cache
            push_immunity!(reg, i, Int8(2), GEMS.IMMUNITY_SOURCE_NATURAL, Int16(6), Int8(0))  # overflow node 1
            push_immunity!(reg, i, Int8(3), GEMS.IMMUNITY_SOURCE_NATURAL, Int16(7), Int8(0))  # must traverse past pid2

            @test length(reg.states) == 2  # both pid2 and pid3 have overflow nodes
            @test reg.states[2].pathogen_id == Int8(3)
        end

        @testset "remove_immunities! clears all overflow" begin
            reg = ImmunityRegistry()
            i = Individual(id=1, sex=0, age=30)

            push_immunity!(reg, i, Int8(1), GEMS.IMMUNITY_SOURCE_NATURAL, Int16(5), Int8(0))
            push_immunity!(reg, i, Int8(2), GEMS.IMMUNITY_SOURCE_NATURAL, Int16(6), Int8(0))

            remove_immunities!(reg, i)
            @test i.immunity_head == Int32(0)
            @test length(reg.free_slots) == 1
        end

    end


    ###
    ### TestRegistry
    ###
    @testset "TestRegistry" begin

        @testset "set_test_state!" begin
            reg = TestRegistry()
            ind_id = Int32(1)
            pid = Int8(1)

            # insert new entry
            set_test_state!(reg, ind_id, pid, Int16(3), true, true)
            state = get(reg.states, _test_key(ind_id, pid), TestState())
            @test state.last_test == Int16(3)
            @test state.last_test_result == true
            @test state.was_reported == true

            # update: was_reported is monotone — once true it stays true
            set_test_state!(reg, ind_id, pid, Int16(7), false, false)
            state2 = get(reg.states, _test_key(ind_id, pid), TestState())
            @test state2.last_test == Int16(7)
            @test state2.last_test_result == false
            @test state2.was_reported == true   # not cleared by false
        end

    end


    ###
    ### InfectionIterator
    ###
    @testset "InfectionIterator" begin

        @testset "empty individual yields nothing" begin
            reg = InfectionRegistry()
            i = Individual(id=1, sex=0, age=30)
            @test collect(each_infection(i, reg)) == InfectionState[]
        end

        @testset "one active cache infection" begin
            reg = InfectionRegistry()
            i = Individual(id=1, sex=0, age=30)
            push_infection!(reg, i, Int8(1), Int32(1),
                DiseaseProgression(exposure=Int16(1), infectiousness_onset=Int16(2), recovery=Int16(10)))
            states = collect(each_infection(i, reg))
            @test length(states) == 1
            @test states[1].pathogen_id == Int8(1)
        end

        @testset "inactive cache slot is skipped (covers i += 1 path)" begin
            # INFECTIONS_CACHE_SIZE = 1; individual with no active infections has
            # infection_cache[1].active == false, so the iterator must increment i past it
            reg = InfectionRegistry()
            i = Individual(id=1, sex=0, age=30)
            @test collect(each_infection(i, reg)) == InfectionState[]  # skips inactive slot
        end

        @testset "overflow node is yielded after cache exhaustion" begin
            reg = InfectionRegistry()
            i = Individual(id=1, sex=0, age=30)
            dp = DiseaseProgression(exposure=Int16(1), infectiousness_onset=Int16(2), recovery=Int16(10))
            push_infection!(reg, i, Int8(1), Int32(1), dp)  # cache slot
            push_infection!(reg, i, Int8(2), Int32(2), dp)  # overflow node
            pids = [s.pathogen_id for s in each_infection(i, reg)]
            @test sort(pids) == [Int8(1), Int8(2)]
        end

    end


    ###
    ### ImmunityIterator
    ###
    @testset "ImmunityIterator" begin

        @testset "empty individual yields nothing" begin
            reg = ImmunityRegistry()
            i = Individual(id=1, sex=0, age=30)
            @test collect(each_immunity(i, reg)) == ImmunityState[]
        end

        @testset "one active cache immunity" begin
            reg = ImmunityRegistry()
            i = Individual(id=1, sex=0, age=30)
            push_immunity!(reg, i, Int8(1), GEMS.IMMUNITY_SOURCE_NATURAL, Int16(0), Int8(0))
            states = collect(each_immunity(i, reg))
            @test length(states) == 1
            @test states[1].pathogen_id == Int8(1)
        end

        @testset "overflow immunity node is yielded" begin
            reg = ImmunityRegistry()
            i = Individual(id=1, sex=0, age=30)
            push_immunity!(reg, i, Int8(1), GEMS.IMMUNITY_SOURCE_NATURAL, Int16(0), Int8(0))
            push_immunity!(reg, i, Int8(2), GEMS.IMMUNITY_SOURCE_NATURAL, Int16(0), Int8(0))
            pids = [s.pathogen_id for s in each_immunity(i, reg)]
            @test sort(pids) == [Int8(1), Int8(2)]
        end

    end

end
