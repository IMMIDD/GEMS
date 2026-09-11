import GEMS: PlanEntry, ActivityPlanStore, plan_slot, plan_add!, plan_remove!, plan_entries,
    plan_length, plan_set_setting_id!, plan_set_member_index!, build_plans!, assign_settings!,
    assign_member_indices!, validate_plans, container_frame_index, membership_column,
    setting_type_index, setting_type_from_index, register_setting_type!, activity_plans,
    member_index, setting_type_of, weight, entry_active, entry_active!, plan_slots

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

    @testset "Repeated setting types" begin
        store = ActivityPlanStore()
        i = Individual(id = 1, sex = 0, age = 30)
        # two entries of one type make count_ones(mask) fall short of plan_count, so
        # every lookup drops off the bit-counting fast path onto the scan
        plan_add!(store, i, PlanEntry(Household, Int32(10), Int32(1)))
        plan_add!(store, i, PlanEntry(Household, Int32(11), Int32(2)))
        plan_add!(store, i, PlanEntry(Municipality, Int32(40), Int32(1)))
        plan_add!(store, i, PlanEntry(Office, Int32(20), Int32(1)))

        @test plan_length(i) == 4
        @test count_ones(i.membership_mask) < plan_length(i)

        # the block stays sorted and the repeat groups with its own kind
        types = [setting_type_of(e) for e in plan_entries(store, i)]
        @test issorted(types)
        @test types[1] == types[2] == setting_type_index(Household)

        # a higher-indexed type resolves to its own entry rather than being misrouted
        # by a bit count the repeat has invalidated
        @test setting_id(store.entries[plan_slot(store, i, Office)]) == Int32(20)
        @test setting_id(store.entries[plan_slot(store, i, Municipality)]) == Int32(40)
        # a repeated type answers with the first of its entries
        first_hh = setting_id(store.entries[plan_slot(store, i, Household)])
        @test first_hh in (Int32(10), Int32(11))

        # removing one of a repeated type must not clear the type's bit
        kept = first_hh == Int32(10) ? Int32(11) : Int32(10)
        @test plan_remove!(store, i, plan_slot(store, i, Household))
        @test plan_slot(store, i, Household) != 0
        @test setting_id(store.entries[plan_slot(store, i, Household)]) == kept
        @test i.membership_mask & (UInt16(1) << (setting_type_index(Household) - 1)) != 0

        # with the repeat gone the fast path comes back, and it is only correct over a
        # block the scan-path inserts left sorted
        @test count_ones(i.membership_mask) == plan_length(i)
        @test issorted([setting_type_of(e) for e in plan_entries(store, i)])
        for (T, sid) in ((Household, kept), (Office, Int32(20)), (Municipality, Int32(40)))
            @test setting_id(store.entries[plan_slot(store, i, T)]) == sid
        end

        # the last entry of the type clears the bit
        @test plan_remove!(store, i, plan_slot(store, i, Household))
        @test plan_slot(store, i, Household) == 0
        @test i.membership_mask & (UInt16(1) << (setting_type_index(Household) - 1)) == 0
    end

    @testset "Active flags survive a repeated type" begin
        store = ActivityPlanStore()
        i = Individual(id = 1, sex = 0, age = 30)
        plan_add!(store, i, PlanEntry(Household, Int32(10), Int32(1)))
        plan_add!(store, i, PlanEntry(Household, Int32(11), Int32(2)))

        entry_active!(store, Int(i.plan_offset), false)
        # an insert relocates the block, so the cleared flag has to travel with its entry
        plan_add!(store, i, PlanEntry(Office, Int32(20), Int32(1)))
        off = Int(i.plan_offset)
        flags = [entry_active(store, off + k) for k in 0:(plan_length(i) - 1)]
        @test count(!, flags) == 1
        @test length(store.active) == length(store.entries)
    end

    @testset "Id-qualified lookup" begin
        store = ActivityPlanStore()
        i = Individual(id = 1, sex = 0, age = 30)
        plan_add!(store, i, PlanEntry(Household, Int32(10), Int32(1)))
        plan_add!(store, i, PlanEntry(Household, Int32(11), Int32(2)))
        plan_add!(store, i, PlanEntry(Office, Int32(20), Int32(1)))

        # searching the whole run, not just its first entry. add_member!/remove_member! and
        # _assign_member_indices! are built on this, and silently desynced without it
        for sid in (Int32(10), Int32(11))
            slot = plan_slot(store, i, Household, sid)
            @test slot != 0
            @test setting_id(store.entries[slot]) == sid
        end
        @test plan_slot(store, i, Household, Int32(99)) == 0
        # a neighbouring type is not swept into the run
        @test plan_slot(store, i, Office, Int32(11)) == 0
        @test setting_id(store.entries[plan_slot(store, i, Office, Int32(20))]) == Int32(20)

        # a repeat joins its own kind in insertion order, so the block stays sorted
        @test [setting_id(e) for e in plan_entries(store, i)] ==
              Int32[10, 11, 20]
    end

    @testset "plan_slots" begin
        store = ActivityPlanStore()
        i = Individual(id = 1, sex = 0, age = 30)
        plan_add!(store, i, PlanEntry(Household, Int32(10), Int32(1)))
        plan_add!(store, i, PlanEntry(Household, Int32(11), Int32(2)))
        plan_add!(store, i, PlanEntry(Office, Int32(20), Int32(1)))

        hh = plan_slots(store, i, Household)
        @test length(hh) == 2
        @test [setting_id(store.entries[s]) for s in hh] == Int32[10, 11]
        # the run stops at the type boundary
        @test [setting_id(store.entries[s]) for s in plan_slots(store, i, Office)] == Int32[20]
        # and agrees with the single-slot form
        @test first(hh) == plan_slot(store, i, Household)

        # a type the individual holds none of gives an empty range, not an error
        @test isempty(plan_slots(store, i, SchoolClass))
        @test isempty(plan_slots(store, Individual(id = 2, sex = 0, age = 30), Household))
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

    @testset "Active flags" begin
        store = ActivityPlanStore()
        i = Individual(id = 1, sex = 0, age = 30)
        plan_add!(store, i, PlanEntry(Household, Int32(1), Int32(1)))
        plan_add!(store, i, PlanEntry(Office, Int32(2), Int32(1)))

        @test length(store.active) == length(store.entries)
        # an entry applies until something gates it
        @test all(entry_active(store, plan_slot(store, i, T)) for T in (Household, Office))

        # a cleared flag follows its entry when the block is relocated by an add
        entry_active!(store, plan_slot(store, i, Household), false)
        plan_add!(store, i, PlanEntry(SchoolClass, Int32(3), Int32(1)))
        @test !entry_active(store, plan_slot(store, i, Household))
        @test entry_active(store, plan_slot(store, i, Office))
        @test entry_active(store, plan_slot(store, i, SchoolClass))

        # and when a remove relocates it
        plan_remove!(store, i, plan_slot(store, i, SchoolClass))
        @test !entry_active(store, plan_slot(store, i, Household))
        @test entry_active(store, plan_slot(store, i, Office))
        @test length(store.active) == length(store.entries)

        # build_plans! leaves every entry applying
        df = DataFrame(id = Int32.(1:3), age = Int8.(20:22), sex = Int8.(ones(3)),
                       household = Int32[1, 1, 2])
        pop = Population(df)
        plans = activity_plans(pop)
        @test length(plans.active) == length(plans.entries)
        @test all(plans.active)
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

    @testset "Several settings of one type" begin
        df = DataFrame(id = Int32.(1:4), age = Int8.(30:33), sex = Int8.(ones(4)),
                       household = Int32[1, 1, 2, 2],
                       office = Int32[1, 1, 2, 2])
        pop = Population(df)
        a, b = individuals(pop)[1], individuals(pop)[2]
        # a also works in the office of household 2, b in an office nobody else names
        assign_settings!(pop, a, Office => 2)
        assign_settings!(pop, b, Office => 3)
        sim = Simulation(population = pop)
        cntnr = GEMS.settingscontainer(sim)
        plans = activity_plans(pop)
        offices = GEMS.settings(cntnr, Office)

        # every entry reached a member list, including a setting only a second entry names
        @test validate_plans(pop, cntnr)
        @test length(offices) == 3
        @test a in individuals(offices[1]) && a in individuals(offices[2])
        @test individuals(offices[3]) == [b]
        # the first entry of the type is the primary
        @test setting_id(a, Office, plans) == Int32(1)

        # activation reaches every setting the plan names
        foreach(deactivate!, offices)
        GEMS.activate_memberships!(a, sim)
        @test isactive(offices[1]) && isactive(offices[2])

        # once the settings exist, an entry needs its setting edited too
        @test_throws ArgumentError assign_settings!(pop, a, Office => 3)
    end

    @testset "The same setting twice is refused" begin
        store = ActivityPlanStore()
        i = Individual(id = 1, sex = 0, age = 30)
        plan_add!(store, i, PlanEntry(Office, Int32(5), Int32(1)))
        @test_throws ArgumentError plan_add!(store, i, PlanEntry(Office, Int32(5), Int32(2)))
        @test plan_length(i) == 1
        # the same id under another type is another setting
        plan_add!(store, i, PlanEntry(Household, Int32(5), Int32(1)))
        @test plan_length(i) == 2
    end

    @testset "Primary entries" begin
        store = ActivityPlanStore()
        i = Individual(id = 1, sex = 0, age = 30)
        # a household first, so the office run does not start at the block start
        plan_add!(store, i, PlanEntry(Household, Int32(10), Int32(1)))
        plan_add!(store, i, PlanEntry(Office, Int32(20), Int32(1)))
        plan_add!(store, i, PlanEntry(Office, Int32(21), Int32(2)))

        # a repeat joins behind the primary, unless it is added as the primary
        @test setting_id(i, Office, store) == Int32(20)
        plan_add!(store, i, PlanEntry(Office, Int32(22), Int32(3)); primary = true)
        @test setting_ids(i, Office, store) == Int32[22, 20, 21]

        # set_primary! moves an entry to the front, its active bit and member index with it
        entry_active!(store, plan_slot(store, i, Office, Int32(21)), false)
        set_primary!(store, i, Office, 21)
        @test setting_ids(i, Office, store) == Int32[21, 22, 20]
        @test !entry_active(store, plan_slot(store, i, Office))
        @test member_index(store.entries[plan_slot(store, i, Office)]) == Int32(2)
        @test issorted([setting_type_of(e) for e in plan_entries(store, i)])
        @test setting_id(i, Household, store) == Int32(10)
        @test_throws ArgumentError set_primary!(store, i, Office, 99)

        # removing the primary promotes the next
        plan_remove!(store, i, plan_slot(store, i, Office))
        @test setting_id(i, Office, store) == Int32(22)
    end

    @testset "Primary through the population" begin
        df = DataFrame(id = Int32.(1:3), age = Int8.(30:32), sex = Int8.(ones(3)),
                       household = Int32[1, 2, 2])
        pop = Population(df)
        a, b = individuals(pop)[1], individuals(pop)[2]
        plans = activity_plans(pop)
        # a also lives in household 2 and makes it their primary
        assign_settings!(pop, a, Household => 2; primary = true)
        @test household_id(a, plans) == Int32(2)
        @test setting_ids(a, Household, plans) == Int32[2, 1]

        sim = Simulation(population = pop)
        @test validate_plans(pop, GEMS.settingscontainer(sim))
        # once built, add_member! and set_primary! do the same through the settings
        add_member!(households(sim)[1], b, sim; primary = true)
        @test household_id(b, plans) == Int32(1)
        set_primary!(sim, b, Household, 2)
        @test setting_ids(b, Household, plans) == Int32[2, 1]
        @test validate_plans(pop, GEMS.settingscontainer(sim))
    end

    @testset "Membership table" begin
        df = DataFrame(id = Int32.(1:3), age = Int8.(30:32), sex = Int8.(ones(3)),
                       household = Int32[1, 1, 2],
                       office = Int32[5, -1, 6])
        table = DataFrame(id = Int32[1, 1, 2, 2],
                          setting_type = ["Office", "Household", "Office", "Office"],
                          setting_id = Int32[7, 2, 8, 9],
                          primary = [false, false, false, true])
        pop = Population(df; memberships = table)
        plans = activity_plans(pop)
        a, b, c = individuals(pop)

        # the population row holds the primary, and the table's rows follow it in file order
        @test setting_ids(a, Office, plans) == Int32[5, 7]
        @test setting_ids(a, Household, plans) == Int32[1, 2]
        # with no office in its row, b's primary is the row that says so
        @test setting_ids(b, Office, plans) == Int32[9, 8]
        @test setting_ids(c, Office, plans) == Int32[6]
        for ind in (a, b, c)
            @test issorted([setting_type_of(e) for e in plan_entries(plans, ind)])
        end
        @test all(plans.active)
        @test a.membership_mask == (UInt16(1) << (setting_type_index(Household) - 1)) |
                                   (UInt16(1) << (setting_type_index(Office) - 1))

        # both tables together rebuild the same plans
        @test nrow(memberships(pop)) == 3
        @test nrow(memberships(Population(df))) == 0
        back = Population(dataframe(pop); memberships = memberships(pop))
        for T in (Household, Office)
            @test [setting_ids(i, T, activity_plans(back)) for i in individuals(back)] ==
                  [setting_ids(i, T, plans) for i in individuals(pop)]
        end

        # and the settings they name get built
        sim = Simulation(population = pop)
        @test validate_plans(pop, GEMS.settingscontainer(sim))
    end

    @testset "Membership table errors" begin
        df = DataFrame(id = Int32.(1:2), age = Int8.(30:31), sex = Int8.(ones(2)),
                       household = Int32[1, 2], office = Int32[5, -1])
        rows(ids, types, sids; kw...) =
            DataFrame(; id = Int32.(ids), setting_type = types, setting_id = Int32.(sids), kw...)

        # an individual the population does not hold
        @test_throws ArgumentError Population(df; memberships = rows([3], ["Office"], [7]))
        # a type nobody registered, and one the tables do not carry yet
        @test_throws ArgumentError Population(df; memberships = rows([1], ["Bakery"], [7]))
        @test_throws ArgumentError Population(df; memberships = rows([1], ["Department"], [7]))
        # ids start at 1
        @test_throws ArgumentError Population(df; memberships = rows([1], ["Office"], [0]))
        # the same setting twice, against the population row or within the table
        @test_throws ArgumentError Population(df; memberships = rows([1], ["Office"], [5]))
        @test_throws ArgumentError Population(df; memberships = rows([2, 2], ["Office", "Office"], [7, 7]))
        # a primary where the population row already names one, and two primaries
        @test_throws ArgumentError Population(df; memberships = rows([1], ["Office"], [7]; primary = [true]))
        @test_throws ArgumentError Population(df;
            memberships = rows([2, 2], ["Office", "Office"], [7, 8]; primary = [true, true]))
        # a missing column
        @test_throws ArgumentError Population(df; memberships = DataFrame(id = Int32[1], setting_id = Int32[7]))
    end

    @testset "Membership table survives the ind_extension rebuild" begin
        df = DataFrame(id = Int32.(1:3), age = Int8.(30:32), sex = Int8.(ones(3)),
                       household = Int32[1, 1, 2])
        extra = DataFrame(id = Int32[1], setting_type = ["Household"], setting_id = Int32[2])
        pop = Population(df; memberships = extra)
        # an extension on a ready population goes through a rebuild of it
        sim = Simulation(population = pop,
            ind_extension = DataFrame(id = Int32.(1:3), score = Float32[1, 2, 3]))
        a = individuals(population(sim))[1]
        @test setting_ids(a, Household, sim) == Int32[1, 2]
        @test a.score == 1.0f0
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

    @testset "container_frame_index with a repeat" begin
        cntnr = SettingsContainer()
        add_types!(cntnr, [SchoolClass, SchoolYear])
        inds = [Individual(id = Int32(j), age = 10, sex = 1) for j in 1:9]
        cs = [SchoolClass(id = Int32(1), individuals = inds[1:3], contained = Int32(1)),
              SchoolClass(id = Int32(2), individuals = inds[4:6], contained = Int32(1)),
              SchoolClass(id = Int32(3), individuals = inds[7:9], contained = Int32(1))]
        sy = SchoolYear(id = Int32(1), contains = Int32[1, 2, 3])
        for x in vcat(cs, [sy]); GEMS.add!(cntnr, x); end
        GEMS.build_pools!(cntnr)
        pop = Population(inds)
        # every member holds an entry for its class, which is what `validate_plans` requires and
        # what `add_member!` reads to decide whether the newcomer is already in the hierarchy
        plans = GEMS.activity_plans(pop)
        for (k, ind) in enumerate(inds)
            assign_settings!(pop, ind, SchoolClass => div(k - 1, 3) + 1)
            GEMS.plan_set_member_index!(plans, Int(ind.plan_offset), mod(k - 1, 3) + 1)
        end
        plans.indexed = true

        # inds[4] now sits in cs[1] and cs[2], so the year holds one of the two copies
        add_member!(cs[1], inds[4], pop)
        GEMS.repack_dirty_pools!(cntnr)
        frame = GEMS.present_members(sy, cntnr)

        kept = container_frame_index(cntnr, sy, cs[1], 4)
        @test kept != GEMS.DEFAULT_MEMBER_INDEX
        @test frame[kept] === inds[4]
        # the dropped copy has no position, which is what gives it one turn and not two
        @test container_frame_index(cntnr, sy, cs[2], 1) == GEMS.DEFAULT_MEMBER_INDEX

        # closing the class the kept copy is in hands the position to the other
        close!(cs[1])
        frame = GEMS.present_members(sy, cntnr)
        promoted = container_frame_index(cntnr, sy, cs[2], 1)
        @test promoted != GEMS.DEFAULT_MEMBER_INDEX
        @test frame[promoted] === inds[4]
        @test container_frame_index(cntnr, sy, cs[1], 4) == GEMS.DEFAULT_MEMBER_INDEX
        open!(cs[1])
    end

    @testset "Gate: a second office transmits" begin
        # two individuals who share nothing but the infecter's second office
        df = DataFrame(id = Int32[1, 2], sex = Int8[0, 0], age = Int8[31, 32],
                       household = Int32[1, 2], office = Int32[1, 2])
        # infectious from tick 1, and every contact infects
        p = Pathogen(id = 1, name = "TestPathogen",
            progressions = [Asymptomatic(
                exposure_to_infectiousness_onset = 0,
                infectiousness_onset_to_recovery = 7)],
            transmission_function = ConstantTransmissionRate(transmission_rate = 1.0))

        function gate_run(second_office::Bool)
            pop = Population(df)
            second_office && assign_settings!(pop, individuals(pop)[1], Office => 2)
            # one contact per infectious member, which in a two-person office is the other one
            sim = Simulation(population = pop, pathogens = (p,), infected_fraction = 0.0,
                office_contacts = RandomSampling())
            # the flush logs the infection and activates the infecter's settings from its plan
            infect!(individuals(sim)[1], sim)
            GEMS.flush_pending_infections!(sim)
            step!(sim)
            step!(sim)
            return sim
        end

        sim = gate_run(true)
        @test validate_plans(population(sim), GEMS.settingscontainer(sim))
        caught = filter(r -> r.id_b == 2, infections(sim))
        @test nrow(caught) == 1
        @test caught.id_a[1] == 1
        @test caught.tick[1] == 1
        @test caught.setting_type[1] == 'o'
        @test caught.setting_id[1] == 2

        # without the second office there is no path between them
        sim = gate_run(false)
        @test !infected(individuals(sim)[2])
        @test nrow(filter(r -> r.id_b == 2, infections(sim))) == 0
    end
end
