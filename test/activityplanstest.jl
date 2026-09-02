import GEMS: PlanEntry, ActivityPlanStore, plan_slot, plan_add!, plan_remove!, plan_entries,
    plan_length, plan_set_setting_id!, plan_set_member_index!, build_plans!, assign_settings!,
    assign_member_indices!, validate_plans, container_frame_index, membership_column,
    setting_type_index, setting_type_from_index, register_setting_type!, activity_plans,
    member_index, setting_type_of, weight

# a registered and an unregistered setting type, for the type-index tests
struct PlanTestSettingA <: IndividualSetting end
struct PlanTestSettingB <: IndividualSetting end

@testset "Activity Plans" begin

    @testset "PlanEntry" begin
        e = PlanEntry(Office, Int32(7), Int32(3), 0.25)
        @test setting_id(e) == Int32(7)
        @test member_index(e) == Int32(3)
        @test setting_type_of(e) == setting_type_index(Office)
        @test weight(e) == Float16(0.25)
        # the weight defaults to a full day
        @test weight(PlanEntry(Household, Int32(1), Int32(1))) == Float16(1.0)
    end

    @testset "Setting type index" begin
        builtins = [Household, SchoolClass, SchoolYear, School, SchoolComplex,
                    Office, Department, Workplace, WorkplaceSite, Municipality, GlobalSetting]
        idxs = setting_type_index.(builtins)
        @test length(unique(idxs)) == length(builtins)
        @test all(t -> setting_type_from_index(setting_type_index(t)) === t, builtins)
        # Household leads the tuple, so it is always the first entry of a sorted plan
        @test setting_type_index(Household) == 0x01

        # user types are numbered past the built-ins, and registration is idempotent
        a = register_setting_type!(PlanTestSettingA)
        @test a > maximum(idxs)
        @test register_setting_type!(PlanTestSettingA) == a
        @test setting_type_from_index(a) === PlanTestSettingA
        # registering a built-in returns its generated index rather than a new one
        @test register_setting_type!(Household) == setting_type_index(Household)

        # an unregistered type has no index
        @test_throws ErrorException setting_type_index(PlanTestSettingB)
        # add_type! registers
        cntnr = SettingsContainer()
        add_type!(cntnr, PlanTestSettingB)
        @test setting_type_index(PlanTestSettingB) > maximum(idxs)
    end

    @testset "Entries stay sorted by type" begin
        store = ActivityPlanStore()
        i = Individual(id = 1, sex = 0, age = 30)
        # inserted out of type order on purpose
        for (T, sid) in ((Municipality, 40), (Household, 10), (Office, 20), (SchoolClass, 30))
            plan_add!(store, i, PlanEntry(T, Int32(sid), Int32(1)))
        end

        types = [setting_type_of(e) for e in plan_entries(store, i)]
        @test issorted(types)
        @test plan_length(i) == 4
        @test length(plan_entries(store, i)) == 4
        # Household sorts first, so it sits at the block start
        @test setting_id(first(plan_entries(store, i))) == Int32(10)
    end

    @testset "Membership mask" begin
        store = ActivityPlanStore()
        i = Individual(id = 1, sex = 0, age = 30)
        @test i.membership_mask == 0
        @test plan_slot(store, i, Household) == 0

        plan_add!(store, i, PlanEntry(Office, Int32(20), Int32(1)))
        plan_add!(store, i, PlanEntry(Household, Int32(10), Int32(1)))

        @test i.membership_mask ==
              (UInt16(1) << (setting_type_index(Household) - 1)) |
              (UInt16(1) << (setting_type_index(Office) - 1))

        # every slot the mask claims resolves to an entry of that type
        for T in (Household, Office)
            slot = plan_slot(store, i, T)
            @test slot != 0
            @test setting_type_of(store.entries[slot]) == setting_type_index(T)
        end
        @test plan_slot(store, i, SchoolClass) == 0

        # the id-qualified form only matches the setting it names
        @test plan_slot(store, i, Household, Int32(10)) == plan_slot(store, i, Household)
        @test plan_slot(store, i, Household, Int32(99)) == 0
    end

    @testset "plan_remove!" begin
        store = ActivityPlanStore()
        i = Individual(id = 1, sex = 0, age = 30)
        for (T, sid) in ((Household, 10), (SchoolClass, 30), (Office, 20), (Municipality, 40))
            plan_add!(store, i, PlanEntry(T, Int32(sid), Int32(1)))
        end

        @test plan_remove!(store, i, plan_slot(store, i, Office))
        @test plan_length(i) == 3
        @test plan_slot(store, i, Office) == 0
        @test i.membership_mask & (UInt16(1) << (setting_type_index(Office) - 1)) == 0
        # the survivors are untouched and still sorted
        @test issorted([setting_type_of(e) for e in plan_entries(store, i)])
        for (T, sid) in ((Household, 10), (SchoolClass, 30), (Municipality, 40))
            @test setting_id(store.entries[plan_slot(store, i, T)]) == Int32(sid)
        end

        # removing the last entry empties the plan
        for T in (Household, SchoolClass, Municipality)
            plan_remove!(store, i, plan_slot(store, i, T))
        end
        @test plan_length(i) == 0
        @test i.membership_mask == 0
        @test isempty(plan_entries(store, i))

        # a slot outside the individual's block is rejected
        j = Individual(id = 2, sex = 0, age = 30)
        plan_add!(store, j, PlanEntry(Household, Int32(1), Int32(1)))
        @test !plan_remove!(store, j, plan_slot(store, j, Household) + 5)
    end

    @testset "Freed blocks are reused" begin
        store = ActivityPlanStore()
        i = Individual(id = 1, sex = 0, age = 30)
        plan_add!(store, i, PlanEntry(Household, Int32(1), Int32(1)))
        plan_add!(store, i, PlanEntry(Office, Int32(2), Int32(1)))
        grown = length(store)

        # shrinking back to one entry must reuse the size-1 block the second add freed
        plan_remove!(store, i, plan_slot(store, i, Office))
        @test length(store) == grown

        # and growing again reuses the size-2 block that remove freed
        plan_add!(store, i, PlanEntry(Office, Int32(2), Int32(1)))
        @test length(store) == grown
    end

    @testset "plan_set_setting_id!" begin
        store = ActivityPlanStore()
        i = Individual(id = 1, sex = 0, age = 30)
        plan_add!(store, i, PlanEntry(Household, Int32(7), Int32(2)))
        slot = plan_slot(store, i, Household)
        plan_set_setting_id!(store, slot, Int32(3))
        @test setting_id(store.entries[slot]) == Int32(3)
        # the member index survives a renumbering
        @test member_index(store.entries[slot]) == Int32(2)
    end

    @testset "build_plans!" begin
        df = DataFrame(id = Int32.(1:3), age = Int8.(20:22), sex = Int8.(ones(3)),
                       household = Int32[1, 1, 2],
                       office = Int32[5, -1, 5],
                       municipality = Int32[9, 9, 9])
        pop = Population(df)
        plans = activity_plans(pop)
        inds = individuals(pop)

        @test membership_column(Household) == :household
        # every entry block is sorted, and DEFAULT_SETTING_ID contributes none
        for ind in inds
            @test issorted([setting_type_of(e) for e in plan_entries(plans, ind)])
        end
        @test plan_length(inds[1]) == 3
        @test plan_length(inds[2]) == 2   # no office
        @test setting_id(plans.entries[plan_slot(plans, inds[2], Household)]) == Int32(1)
        @test plan_slot(plans, inds[2], Office) == 0
        # a column the file does not carry yields no entries at all
        @test all(ind -> plan_slot(plans, ind, SchoolClass) == 0, inds)

        # member indices are not known until the settings exist
        @test_throws ErrorException member_index(inds[1], Household, plans)
    end

    @testset "Population round-trip" begin
        df = DataFrame(id = Int32.(1:4), age = Int8.(20:23), sex = Int8.(ones(4)),
                       household = Int32[1, 1, 2, 2],
                       office = Int32[3, 3, -1, 4],
                       municipality = Int32[7, 7, 7, 7])
        pop = Population(df)
        back = Population(dataframe(pop))

        for T in (Household, Office, Municipality)
            before = [setting_id(i, T, activity_plans(pop)) for i in individuals(pop)]
            after = [setting_id(i, T, activity_plans(back)) for i in individuals(back)]
            @test before == after
        end
    end

    @testset "assign_member_indices! and validate_plans" begin
        sim = Simulation(pop_size = 500, seed = 1234)
        pop = population(sim)
        plans = activity_plans(pop)

        @test plans.indexed
        @test validate_plans(pop, GEMS.settingscontainer(sim))

        # every entry points back at its own individual in the named setting
        for T in (Household, Office, SchoolClass)
            for s in GEMS.settings(GEMS.settingscontainer(sim), T)
                for (k, ind) in enumerate(individuals(s))
                    @test member_index(ind, T, plans) == k
                    @test setting_id(ind, T, plans) == id(s)
                end
            end
        end

        # a corrupted index is caught
        slot = plan_slot(plans, individuals(pop)[1], Household)
        original = member_index(plans.entries[slot])
        plan_set_member_index!(plans, slot, original + 1000)
        @test_throws ErrorException validate_plans(pop, GEMS.settingscontainer(sim))
        plan_set_member_index!(plans, slot, original)
    end

    @testset "container_frame_index" begin
        cntnr = SettingsContainer()
        add_types!(cntnr, [SchoolClass, SchoolYear])
        inds = [Individual(id = Int32(j), age = 10, sex = 1) for j in 1:9]
        cs = [SchoolClass(id = Int32(1), individuals = inds[1:3], contained = Int32(1)),
              SchoolClass(id = Int32(2), individuals = inds[4:6], contained = Int32(1)),
              SchoolClass(id = Int32(3), individuals = inds[7:9], contained = Int32(1))]
        sy = SchoolYear(id = Int32(1), contains = Int32[1, 2, 3])
        for x in vcat(cs, [sy]); GEMS.add!(cntnr, x); end
        GEMS.build_pools!(cntnr)

        # the derived index must agree with the member's actual position in the frame
        function check_all()
            frame = GEMS.present_members(sy, cntnr)
            for c in cs, (k, ind) in enumerate(individuals(c))
                idx = container_frame_index(cntnr, sy, c, k)
                if GEMS.is_open(c)
                    @test idx != GEMS.DEFAULT_MEMBER_INDEX
                    @test frame[idx] === ind
                else
                    @test idx == GEMS.DEFAULT_MEMBER_INDEX
                end
            end
        end

        check_all()                              # nothing closed: one unbroken span
        close!(cs[1]); check_all()               # a closed edge leaves one run
        open!(cs[1]); close!(cs[2]); check_all() # a closed middle leaves two
        open!(cs[2])

        # a closed container holds nobody
        close!(sy)
        @test container_frame_index(cntnr, sy, cs[1], 1) == GEMS.DEFAULT_MEMBER_INDEX
        open!(sy)
    end
end
