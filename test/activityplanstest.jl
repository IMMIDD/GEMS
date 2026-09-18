import GEMS: PlanEntry, ActivityPlanStore, plan_slot, plan_add!, plan_remove!, plan_entries,
    plan_length, plan_set_setting_id!, plan_set_member_index!, build_plans!, assign_settings!,
    assign_member_indices!, validate_plans, container_frame_index, membership_column,
    setting_type_index, setting_type_from_index, register_setting_type!, activity_plans,
    member_index, setting_type_of, entry_scale, entry_active, entry_active!, plan_slots, set_scale!

# a registered and an unregistered setting type, for the type-index tests
struct PlanTestSettingA <: IndividualSetting end
struct PlanTestSettingB <: IndividualSetting end

# a setting that counts how often a member's scale is read
struct ScaleReadSetting <: IndividualSetting end
register_setting_type!(ScaleReadSetting)
const SCALE_READS = Ref(0)
GEMS._membership_scale(::ActivityPlanStore, ::Individual, ::ScaleReadSetting, ::GEMS.SettingsContainer) = (SCALE_READS[] += 1; 1.0f0)

@testset "Activity Plans" begin

    @testset "PlanEntry" begin
        e = PlanEntry(Office, Int32(7), Int32(3), 0.25)
        @test setting_id(e) == Int32(7)
        @test member_index(e) == Int32(3)
        @test setting_type_of(e) == setting_type_index(Office)
        @test entry_scale(e) == Float16(0.25)
        # a normal member by default
        @test entry_scale(PlanEntry(Household, Int32(1), Int32(1))) == Float16(1.0)
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

        entry_active!(store, i, Int(i.plan_offset), false)
        # an insert relocates the block, so the cleared flag has to travel with its entry
        plan_add!(store, i, PlanEntry(Office, Int32(20), Int32(1)))
        flags = [entry_active(store, k) for k in plan_slots(store, i)]
        @test count(!, flags) == 1
        @test length(store.active) == length(store.entries)
    end

    @testset "Inactive entries count as scaled" begin
        store = ActivityPlanStore()
        i = Individual(id = 1, sex = 0, age = 30)
        plan_add!(store, i, PlanEntry(Household, Int32(1), Int32(1)))
        plan_add!(store, i, PlanEntry(Office, Int32(2), Int32(1)))
        @test !i.plan_scaled

        # an inactive entry has scale 0, so the unscaled fast path no longer applies
        entry_active!(store, i, plan_slot(store, i, Office), false)
        @test i.plan_scaled
        # removing it leaves only the unscaled household
        plan_remove!(store, i, plan_slot(store, i, Office))
        @test !i.plan_scaled

        # a slot outside the individual's block is refused
        j = Individual(id = 2, sex = 0, age = 30)
        plan_add!(store, j, PlanEntry(Household, Int32(3), Int32(1)))
        @test_throws ArgumentError entry_active!(store, i, plan_slot(store, j, Household), false)
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
        entry_active!(store, i, plan_slot(store, i, Household), false)
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

        # spreading from a reaches every office the plan names, the second one included
        reached = Int32[]
        GEMS._foreach_spread_setting(a, sim) do setting, pos, scale
            setting isa Office && push!(reached, id(setting))
        end
        @test reached == Int32[1, 2]

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
        entry_active!(store, i, plan_slot(store, i, Office, Int32(21)), false)
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

    @testset "Membership table through the pool" begin
        # the file path a real second membership takes: table -> plans -> settings -> pool.
        # `repeats` is counted when the pool is built and never recounted, so it has to be
        # right here or the department's frame silently holds the member twice.
        df = DataFrame(id = Int32[1, 2, 3], sex = Int8[0, 0, 0], age = Int8[30, 31, 32],
                       household = Int32[1, 1, 1], office = Int32[1, 2, 2])
        mktempdir() do dir
            path = joinpath(dir, "pop.csv")
            mpath = joinpath(dir, "extra.csv")
            spath = joinpath(dir, "settings.jld2")
            CSV.write(path, df)
            CSV.write(mpath, DataFrame(id = Int32[1], setting_type = ["Office"], setting_id = Int32[2]))
            # both offices in one department, so the repeat lands inside one block
            jldsave(spath; data = Dict(
                :Office => DataFrame(id = Int32[1, 2], contained = Int32[1, 1]),
                :Department => DataFrame(id = Int32[1], contains = [Int32[1, 2]])))

            sim = Simulation(population = path, membershipsfile = mpath, settingsfile = spath)
            cntnr = GEMS.settingscontainer(sim)
            ind = individuals(sim)[1]

            @test setting_ids(ind, Office, GEMS.activity_plans(sim)) == Int32[1, 2]
            @test cntnr.pools[Office].repeats == 1

            # the department spans both offices; the second copy is dropped from its frame
            dept = settings(sim, Department)[1]
            @test count(m -> m === ind, present_members(dept, cntnr)) == 1
            @test length(present_members(dept, cntnr)) == 3

            @test validate_plans(population(sim), cntnr)
            step!(sim)
        end
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

        # nothing closed: one unbroken span
        check_all()
        # a closed edge leaves one run; like a member edit, it shows after the repack
        close!(cs[1]); GEMS.repack_dirty_pools!(cntnr)
        check_all()
        # a closed middle leaves two
        open!(cs[1]); close!(cs[2]); GEMS.repack_dirty_pools!(cntnr)
        check_all()
        open!(cs[2]); GEMS.repack_dirty_pools!(cntnr)

        # a closed container holds nobody
        close!(sy); GEMS.repack_dirty_pools!(cntnr)
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
        close!(cs[1]); GEMS.repack_dirty_pools!(cntnr)
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
            # the flush commits the infection, so the next sweep finds the infecter infectious
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

    @testset "Scale flag follows the entries" begin
        store = ActivityPlanStore()
        i = Individual(id = 1, sex = 0, age = 30)
        plan_add!(store, i, PlanEntry(Household, Int32(10), Int32(1)))
        @test !i.plan_scaled
        plan_add!(store, i, PlanEntry(Household, Int32(11), Int32(2), 0.5))
        @test i.plan_scaled
        set_scale!(store, i, Household, 11, 1.0)
        @test !i.plan_scaled
        set_scale!(store, i, Household, 10, 3.0)
        @test i.plan_scaled
        @test_throws ArgumentError set_scale!(store, i, Household, 99, 0.5)

        # removing the only scaled entry clears the flag
        plan_remove!(store, i, plan_slot(store, i, Household, Int32(10)))
        @test !i.plan_scaled
        # derived, so a population file cannot set it
        @test !(:plan_scaled in GEMS.individual_base_fieldnames())
        # once the settings are built, only the simulation may change a scale
        store.indexed = true
        @test_throws ArgumentError set_scale!(store, i, Household, 11, 2.0)
    end

    @testset "Membership table scales" begin
        df = DataFrame(id = Int32.(1:2), age = Int8.(30:31), sex = Int8.(ones(2)),
                       household = Int32[1, 2], office = Int32[5, -1])
        rows(ids, types, sids, scales) = DataFrame(id = Int32.(ids), setting_type = types,
            setting_id = Int32.(sids), scale = scales)

        # a row naming the population row's own setting only scales it; the others are new entries
        pop = Population(df; memberships = rows([1, 1, 1], ["Household", "Household", "Office"], [1, 2, 7], [0.5, 0.5, 2.5]))
        plans = activity_plans(pop)
        a, b = individuals(pop)
        @test setting_ids(a, Household, plans) == Int32[1, 2]
        @test [entry_scale(plans.entries[k]) for k in plan_slots(plans, a, Household)] == Float16[0.5, 0.5]
        @test [entry_scale(plans.entries[k]) for k in plan_slots(plans, a, Office)] == Float16[1.0, 2.5]
        @test a.plan_scaled && !b.plan_scaled

        # both tables together rebuild the same plans, the primary's scale included
        back = Population(dataframe(pop); memberships = memberships(pop))
        @test [entry_scale(e) for e in plan_entries(activity_plans(back), individuals(back)[1])] ==
              [entry_scale(e) for e in plan_entries(plans, a)]

        # out of range, and one entry scaled twice
        @test_throws ArgumentError Population(df; memberships = rows([1], ["Office"], [7], [-0.5]))
        @test_throws ArgumentError Population(df; memberships = rows([1], ["Office"], [7], [70000.0]))
        @test_throws ArgumentError Population(df; memberships = rows([1], ["Office"], [7], [NaN]))
        @test_throws ArgumentError Population(df;
            memberships = rows([1, 1], ["Office", "Office"], [5, 5], [0.5, 0.5]))

        # once the settings exist, each carries a bound on its members' scales
        sim = Simulation(population = pop)
        @test validate_plans(pop, GEMS.settingscontainer(sim))
        k = last(plan_slots(plans, a, Office))
        sid = setting_id(plans.entries[k])
        @test GEMS._scale_bound(settings(sim, Office)[sid]) == 2.5f0
        # and the simulation changes scales together with the bound
        @test_throws ArgumentError set_scale!(pop, a, Office, sid, 1.0)
        set_scale!(sim, a, Office, sid, 1.0)
        @test GEMS._scale_bound(settings(sim, Office)[sid]) == 1.0f0
        set_scale!(sim, a, Office, sid, 4.0)
        @test GEMS._scale_bound(settings(sim, Office)[sid]) == 4.0f0
        @test validate_plans(pop, GEMS.settingscontainer(sim))

        # Float16 stores 2.3 as 2.3007812, so a raised bound has to cover that, not 2.3
        set_scale!(sim, a, Office, sid, 1.0)
        set_scale!(sim, a, Office, sid, 2.3)
        @test validate_plans(pop, GEMS.settingscontainer(sim))
        set_scale!(sim, a, Office, sid, 1.0)
        add_member!(settings(sim, Office)[sid], b, sim; scale = 2.3)
        @test validate_plans(pop, GEMS.settingscontainer(sim))

        # an inactive entry keeps its scale and its setting's bound, so the plans still validate
        entry_active!(plans, b, plan_slot(plans, b, Office, sid), false)
        @test b.plan_scaled
        @test validate_plans(pop, GEMS.settingscontainer(sim))
    end

    @testset "Membership scales" begin
        cntnr = SettingsContainer()
        add_types!(cntnr, [SchoolClass, SchoolYear, School])
        inds = [Individual(id = Int32(j), age = 10, sex = 1) for j in 1:11]
        x, y, z, w, v = inds[7], inds[8], inds[9], inds[10], inds[11]
        # school 1: year 1 holds classes 1 and 2, year 2 holds class 3. school 2: year 3 holds class 4
        cs = [SchoolClass(id = Int32(1), individuals = [inds[1], inds[2], x, y, v], contained = Int32(1)),
              SchoolClass(id = Int32(2), individuals = [inds[3], x, v], contained = Int32(1)),
              SchoolClass(id = Int32(3), individuals = [inds[4], y, z], contained = Int32(2)),
              SchoolClass(id = Int32(4), individuals = [inds[5], inds[6], z, w], contained = Int32(3))]
        ys = [SchoolYear(id = Int32(1), contains = Int32[1, 2], contained = Int32(1)),
              SchoolYear(id = Int32(2), contains = Int32[3], contained = Int32(1)),
              SchoolYear(id = Int32(3), contains = Int32[4], contained = Int32(2))]
        ss = [School(id = Int32(1), contains = Int32[1, 2]), School(id = Int32(2), contains = Int32[3])]
        for s in vcat(cs, ys, ss); GEMS.add!(cntnr, s); end
        GEMS.build_pools!(cntnr)

        pop = Population(inds)
        for (k, c) in enumerate(cs), m in individuals(c)
            m in (x, y, z, w, v) || assign_settings!(pop, m, SchoolClass => k)
        end
        for (ind, cid, s) in ((x, 1, 0.5), (x, 2, 0.5), (y, 1, 0.7), (y, 3, 0.7), (z, 3, 0.3), (z, 4, 0.4),
                              (w, 4, 0.25), (v, 1, 2.0), (v, 2, 0.5))
            assign_settings!(pop, ind, SchoolClass => cid; scale = s)
        end
        plans = activity_plans(pop)
        ms(ind, s) = GEMS._membership_scale(plans, ind, s, cntnr)

        # a leaf reads its own entry, and the global setting has none
        @test ms(x, cs[1]) == 0.5f0
        @test ms(inds[1], cs[1]) == 1.0f0
        @test GEMS._membership_scale(plans, x, GlobalSetting(contact_sampling_method = RandomSampling()), cntnr) == 1.0f0
        # a lone leaf entry is taken as it is
        @test ms(inds[1], ys[1]) == 1.0f0
        @test ms(w, ss[2]) == 0.25f0
        # leaves under one container add up, capped at the larger of 1 and the largest
        @test ms(x, ys[1]) == 1.0f0
        @test isapprox(ms(y, ys[1]), 0.7; atol = 1e-3)
        @test ms(y, ss[1]) == 1.0f0
        @test ms(v, ys[1]) == 2.0f0
        @test ms(v, ss[1]) == 2.0f0
        # a leaf under another container does not count
        @test isapprox(ms(z, ss[1]), 0.3; atol = 1e-3)
        @test isapprox(ms(z, ss[2]), 0.4; atol = 1e-3)

        # closed leaves, and leaves below a closed container, drop out
        close!(cs[2])
        @test ms(x, ys[1]) == 0.5f0
        open!(cs[2])
        close!(ys[2])
        @test isapprox(ms(y, ss[1]), 0.7; atol = 1e-3)
        @test ms(z, ss[1]) == 0.0f0
        open!(ys[2])

        # an inactive entry counts as scale 0, at its leaf and in every container above it
        x1 = plan_slot(plans, x, SchoolClass, Int32(1))
        x2 = plan_slot(plans, x, SchoolClass, Int32(2))
        entry_active!(plans, x, x1, false)
        @test ms(x, cs[1]) == 0.0f0
        @test ms(x, cs[2]) == 0.5f0
        @test ms(x, ys[1]) == 0.5f0
        # with every leaf below inactive, the container gives 0 too
        entry_active!(plans, x, x2, false)
        @test ms(x, ys[1]) == 0.0f0
        @test ms(x, ss[1]) == 0.0f0
        # a lone leaf entry is taken as it is, inactive included
        w4 = plan_slot(plans, w, SchoolClass, Int32(4))
        entry_active!(plans, w, w4, false)
        @test ms(w, ss[2]) == 0.0f0
        # an unscaled member switched off leaves the fast path, and returns to it when switched on
        i1 = inds[1]
        @test !i1.plan_scaled
        entry_active!(plans, i1, plan_slot(plans, i1, SchoolClass), false)
        @test i1.plan_scaled
        @test ms(i1, cs[1]) == 0.0f0
        @test ms(i1, ys[1]) == 0.0f0
        entry_active!(plans, i1, plan_slot(plans, i1, SchoolClass), true)
        @test !i1.plan_scaled
        @test ms(i1, cs[1]) == 1.0f0
        # everything applies again for what follows
        entry_active!(plans, x, x1, true)
        entry_active!(plans, x, x2, true)
        entry_active!(plans, w, w4, true)

        # the leaf range agrees with climbing `contained`, for every leaf and container
        function ancestor(s, C)
            while !(s isa C)
                s = GEMS.settings(cntnr, GEMS.contained_type(typeof(s)))[s.contained]
            end
            return s
        end
        for c in cs, C in (SchoolYear, School), p in GEMS.settings(cntnr, C)
            @test (c.pool_leaf in GEMS._leaf_range(p)) == (ancestor(c, C) === p)
        end

        # once indexed, a leaf above 1 bounds itself and every container above it
        assign_member_indices!(pop, cntnr)
        @test GEMS._scale_bound(cs[1]) == 2.0f0
        @test GEMS._scale_bound(ys[1]) == 2.0f0
        @test GEMS._scale_bound(ss[1]) == 2.0f0
        @test GEMS._scale_bound(cs[3]) == 1.0f0
        @test GEMS._scale_bound(ss[2]) == 1.0f0
        # a member edit moves its leaf's bound at once, and the containers' at the next repack
        add_member!(cs[4], inds[1], pop; scale = 3.0)
        @test GEMS._scale_bound(cs[4]) == 3.0f0
        GEMS.repack_dirty_pools!(cntnr)
        @test GEMS._scale_bound(ys[3]) == 3.0f0
        @test GEMS._scale_bound(ss[2]) == 3.0f0
        remove_member!(cs[4], inds[1], pop)
        GEMS.repack_dirty_pools!(cntnr)
        @test GEMS._scale_bound(cs[4]) == 1.0f0
        @test GEMS._scale_bound(ss[2]) == 1.0f0
    end

    @testset "Scaled contact sampling" begin
        cntnr = SettingsContainer()
        plans = ActivityPlanStore()
        csm = ContactparameterSampling(20.0)
        hh = Household(id = Int32(1), contact_sampling_method = csm,
                       individuals = [Individual(id = Int32(j), age = 30, sex = 1) for j in 1:10])
        present = GEMS.present_members(hh, cntnr)
        draws = Individual[]
        sampled(s, p, rng, s_host, bound; replace = true, oversample = 1) = GEMS.sample_scaled_contacts!(Individual[], draws,
            contact_sampling_method(s), s, 1, p, Int16(1), replace, rng, plans, cntnr, Float32(s_host), Float32(bound);
            oversample = Float32(oversample))

        # unscaled, it is the plain draw with no extra randomness
        r1 = Xoshiro(7); r2 = copy(r1)
        plain = Individual[]
        sample_contacts!(plain, csm, hh, 1, present, Int16(1), true, r1)
        @test sampled(hh, present, r2, 1, 1) == plain
        @test r1 == r2
        @test isempty(sampled(hh, present, Xoshiro(7), 0, 1))

        # the host's scale and the bound set how much is drawn; unscaled contacts are thinned against the bound
        rng = Xoshiro(11)
        n = 4000
        mean_contacts(s, p, s_host, bound) = sum(_ -> length(sampled(s, p, rng, s_host, bound)), 1:n) / n
        @test isapprox(mean_contacts(hh, present, 0.5, 1), 10.0; atol = 0.3)
        @test isapprox(mean_contacts(hh, present, 2.5, 1), 50.0; atol = 0.8)
        @test isapprox(mean_contacts(hh, present, 1, 2.5), 20.0; atol = 0.5)

        # in a pair the other member is the only candidate, so its own scale shows directly
        pair = [Individual(id = Int32(11), age = 30, sex = 1), Individual(id = Int32(12), age = 30, sex = 1)]
        hh2 = Household(id = Int32(2), contact_sampling_method = RandomSampling(), individuals = pair)
        p2 = GEMS.present_members(hh2, cntnr)
        plan_add!(plans, pair[2], PlanEntry(Household, Int32(2), Int32(2), 0.5))
        @test isapprox(mean_contacts(hh2, p2, 1, 1), 0.5; atol = 0.03)
        @test isapprox(mean_contacts(hh2, p2, 0.5, 1), 0.25; atol = 0.03)
        set_scale!(plans, pair[2], Household, 2, 2.5)
        @test isapprox(mean_contacts(hh2, p2, 1, 2.5), 2.5; atol = 0.08)

        # without replacement several draws merge: nobody twice, and a pair at scale <= 1 meets at its scaled rate
        hh4 = Household(id = Int32(4), contact_sampling_method = ContactparameterSampling(3.0),
                        individuals = [Individual(id = Int32(20 + j), age = 30, sex = 1) for j in 1:10])
        p4 = GEMS.present_members(hh4, cntnr)
        target = p4[2]
        plan_add!(plans, target, PlanEntry(Household, Int32(4), Int32(2), 0.5))
        hits = 0
        repeats = 0
        for _ in 1:n
            cs = sampled(hh4, p4, rng, 1.5, 1.5; replace = false)
            repeats += !allunique(cs)
            hits += target in cs
        end
        @test repeats == 0
        # one call meets a given member with probability 3/9; 1.5 * 0.5 of that
        @test isapprox(hits / n, 0.75 * 3 / 9; atol = 0.02)

        # a pair above 1 caps when drawn repeatedly, and oversampling shrinks that bias
        hh5 = Household(id = Int32(5), contact_sampling_method = RandomSampling(),
                        individuals = [Individual(id = Int32(40 + j), age = 30, sex = 1) for j in 1:4])
        p5 = GEMS.present_members(hh5, cntnr)
        plan_add!(plans, p5[2], PlanEntry(Household, Int32(5), Int32(2), 1.2))
        meets(oversample) = count(_ -> p5[2] in sampled(hh5, p5, rng, 2, 2; replace = false, oversample = oversample), 1:n) / n
        # four calls draw it m ~ Binomial(4, 1/3) times, each worth 0.6 and capped at 1
        @test isapprox(meets(1), (0.6 * 32 + 33) / 81; atol = 0.025)
        @test isapprox(meets(50), 2 * 1.2 / 3; atol = 0.025)

        # a lone member could only meet itself, so no sampler is asked, not even one that would throw
        alone = Individual(id = Int32(13), age = 30, sex = 1)
        hh3 = Household(id = Int32(3), contact_sampling_method = RandomSampling(), individuals = [alone])
        p3 = GEMS.present_members(hh3, cntnr)
        @test_throws ArgumentError sample_contacts!(Individual[], RandomSampling(), hh3, 1, p3, Int16(1), true, Xoshiro(1))
        r3 = Xoshiro(5); r3_before = copy(r3)
        @test isempty(sampled(hh3, p3, r3, 1, 1))
        @test r3 == r3_before
    end

    @testset "Thinned contact sampling" begin
        # two scaled classes in one year, with members 5 and 6 in both and member 3 at scale 0
        cntnr = SettingsContainer()
        add_types!(cntnr, [SchoolClass, SchoolYear])
        inds = [Individual(id = Int32(j), age = 30, sex = 1) for j in 1:10]
        cs = [SchoolClass(id = Int32(1), individuals = inds[1:6], contained = Int32(1)),
              SchoolClass(id = Int32(2), individuals = inds[5:10], contained = Int32(1))]
        yr = SchoolYear(id = Int32(1), contains = Int32[1, 2])
        for s in vcat(cs, [yr]); GEMS.add!(cntnr, s); end
        GEMS.build_pools!(cntnr)
        pop = Population(inds)
        for (k, c) in enumerate(cs), m in individuals(c)
            assign_settings!(pop, m, SchoolClass => k; scale = id(m) == 3 ? 0.0 : 0.25 * id(m))
        end
        assign_member_indices!(pop, cntnr)
        plans = activity_plans(pop)

        # with thin = 1 both keeps decide and draw exactly as the unthinned keep
        function unthinned_keep(c, f, bound, s, rng)
            p = f * GEMS._membership_scale(plans, c, s, cntnr) / bound
            return p >= 1 || gems_rand(rng) < p
        end
        r1 = Xoshiro(3); r2 = copy(r1)
        same = true
        for s in (cs[1], cs[2], yr), c in GEMS.present_members(s, cntnr), _ in 1:20
            sc = GEMS._membership_scale(plans, c, s, cntnr)
            # the setting's bound, and a bound equal to the contact's own scale
            for bound in unique((GEMS._scale_bound(s), sc))
                bound > 0 || continue
                for f in Float32[0, 1f-3, 0.3, 0.5, prevfloat(1.0f0), 1, 1.7]
                    same &= GEMS._keep_contact(c, f, 1.0f0, bound, plans, s, cntnr, r1) == unthinned_keep(c, f, bound, s, r2)
                end
                for w in Float32[0.2, 1, 1.5, 3]
                    same &= GEMS._keep_unique_contact(c, w, 1.0f0, bound, plans, s, cntnr, r1) == unthinned_keep(c, w, bound, s, r2)
                end
            end
        end
        @test same
        @test r1 == r2

        # a contact's scale is read only for the draws thinning keeps
        SCALE_READS[] = 0
        rr = Xoshiro(5)
        kept = count(_ -> GEMS._keep_contact(inds[1], 1.0f0, 0.1f0, 1.0f0, plans, ScaleReadSetting(), cntnr, rr), 1:10_000)
        @test SCALE_READS[] == kept
        @test isapprox(kept / 10_000, 0.1; atol = 0.015)

        plain = ActivityPlanStore()
        scaled = ActivityPlanStore()
        empty_cntnr = SettingsContainer()
        draws = Individual[]
        rng = Xoshiro(11)
        sampled(s, p, s_host, bound, thin; replace = true, store = plain) = GEMS.sample_scaled_contacts!(Individual[], draws,
            contact_sampling_method(s), s, 1, p, Int16(1), replace, rng, store, empty_cntnr, Float32(s_host), Float32(bound);
            thin = Float32(thin))

        # contacts thin by `thin` whether the host draws once, several times, or against a raised bound
        hh = Household(id = Int32(1), contact_sampling_method = ContactparameterSampling(20.0),
                       individuals = [Individual(id = Int32(20 + j), age = 30, sex = 1) for j in 1:10])
        present = GEMS.present_members(hh, empty_cntnr)
        n = 4000
        mean_contacts(args...) = sum(_ -> length(sampled(args...)), 1:n) / n
        @test isapprox(mean_contacts(hh, present, 0.5, 1, 0.3), 3.0; atol = 0.15)
        @test isapprox(mean_contacts(hh, present, 2.5, 1, 0.3), 15.0; atol = 0.4)
        @test isapprox(mean_contacts(hh, present, 1, 2.5, 0.3), 6.0; atol = 0.25)

        # thinning acts per draw: five single draws give Binomial(5, 0.2), not one thinned call
        hh_r = Household(id = Int32(2), contact_sampling_method = RandomSampling(),
                         individuals = [Individual(id = Int32(40 + j), age = 30, sex = 1) for j in 1:10])
        p_r = GEMS.present_members(hh_r, empty_cntnr)
        counts = [length(sampled(hh_r, p_r, 5, 1, 0.2)) for _ in 1:20_000]
        @test isapprox(mean(counts), 1.0; atol = 0.03)
        @test isapprox(var(counts), 0.8; atol = 0.05)
        @test isapprox(count(==(0), counts) / length(counts), 0.8^5; atol = 0.015)

        # without replacement, uncapped: the meeting rate thins by `thin`
        n = 20_000
        hh4 = Household(id = Int32(4), contact_sampling_method = ContactparameterSampling(3.0),
                        individuals = [Individual(id = Int32(60 + j), age = 30, sex = 1) for j in 1:10])
        p4 = GEMS.present_members(hh4, empty_cntnr)
        plan_add!(scaled, p4[2], PlanEntry(Household, Int32(4), Int32(2), 0.5))
        hits = count(_ -> p4[2] in sampled(hh4, p4, 1.5, 1.5, 0.4; replace = false, store = scaled), 1:n)
        @test isapprox(hits / n, 0.4 * 0.75 * 3 / 9; atol = 0.012)

        # capped: four calls draw it m ~ Binomial(4, 1/3) times at 0.6 each, capped at 1, then thinned
        hh5 = Household(id = Int32(5), contact_sampling_method = RandomSampling(),
                        individuals = [Individual(id = Int32(80 + j), age = 30, sex = 1) for j in 1:4])
        p5 = GEMS.present_members(hh5, empty_cntnr)
        plan_add!(scaled, p5[2], PlanEntry(Household, Int32(5), Int32(2), 1.2))
        meets = count(_ -> p5[2] in sampled(hh5, p5, 2, 2, 0.5; replace = false, store = scaled), 1:n)
        @test isapprox(meets / n, 0.5 * (0.6 * 32 + 33) / 81; atol = 0.02)

        # every scale a host spreads with stays within its setting's bound, with random scales and inactive entries
        BASE_FOLDER = dirname(dirname(pathof(GEMS)))
        sim = Simulation(population = joinpath(BASE_FOLDER, "test/testdata/people_muenster.jld2"),
            settingsfile = joinpath(BASE_FOLDER, "test/testdata/settings_muenster.jld2"),
            global_setting = true, infected_fraction = 0.0, seed = 1)
        mplans = activity_plans(sim)
        srng = Xoshiro(17)
        for ind in individuals(sim)[1:3:end], k in plan_slots(mplans, ind)
            e = mplans.entries[k]
            set_scale!(sim, ind, setting_type_from_index(setting_type_of(e)), GEMS.setting_id(e), 3 * rand(srng))
            rand(srng) < 0.1 && entry_active!(mplans, ind, k, false)
        end
        GEMS.repack_dirty_pools!(GEMS.settingscontainer(sim))
        within = true
        for ind in individuals(sim)
            GEMS._foreach_spread_setting((s, pos, sc) -> (within &= sc <= GEMS._scale_bound(s)), ind, sim)
        end
        @test within
    end

    @testset "Contact survey of one-person settings" begin
        n = 20
        df = DataFrame(id = Int32.(1:n), sex = Int8.(zeros(n)), age = Int8.(fill(30, n)),
                       household = Int32.(1:n))
        sim = Simulation(population = Population(df), household_contacts = RandomSampling(), seed = 1)
        # nobody has anyone to meet, which must give no contacts rather than a sampler error
        @test nrow(GEMS.contact_samples(sim, Household, false)) == 0
        @test all(==(-1), GEMS.contact_samples(sim, Household, true).b_id)
    end

    @testset "Gate: scales act on both ends" begin
        n = 1000
        df = DataFrame(id = Int32.(1:2n), sex = Int8.(zeros(2n)), age = Int8.(fill(30, 2n)),
                       household = Int32.(repeat(1:n, inner = 2)))

        # share of second members caught at home on the first infectious tick, with the first
        # (`:host`) or the second (`:contact`) member of every household at scale `s`
        function caught(scaled::Symbol, s::Float64, rate::Float64, csm)
            p = Pathogen(id = 1, name = "TestPathogen",
                progressions = [Asymptomatic(
                    exposure_to_infectiousness_onset = 0,
                    infectiousness_onset_to_recovery = 7)],
                transmission_function = ConstantTransmissionRate(transmission_rate = rate))
            ids = scaled === :host ? Int32.(1:2:2n) : Int32.(2:2:2n)
            table = DataFrame(id = ids, setting_type = fill("Household", n),
                              setting_id = Int32.(div.(ids .+ 1, 2)), scale = fill(s, n))
            sim = Simulation(population = Population(df; memberships = table), pathogens = (p,),
                infected_fraction = 0.0, household_contacts = csm, seed = 42)
            for k in 1:2:2n
                infect!(individuals(sim)[k], sim)
            end
            GEMS.flush_pending_infections!(sim)
            step!(sim)
            step!(sim)
            return nrow(filter(r -> iseven(r.id_b) && r.tick == 1 && r.setting_type == 'h', infections(sim))) / n
        end

        # one contact per tick and every contact infects, so the scale is the share caught
        @test caught(:contact, 1.0, 1.0, RandomSampling()) == 1.0
        @test isapprox(caught(:contact, 0.5, 1.0, RandomSampling()), 0.5; atol = 0.06)
        @test isapprox(caught(:host, 0.5, 1.0, RandomSampling()), 0.5; atol = 0.06)
        # above 1: Poisson(2) attempts on the one housemate, each infecting with 0.3
        @test isapprox(caught(:contact, 2.0, 0.3, ContactparameterSampling(1.0)), 1 - exp(-0.6); atol = 0.05)
        @test isapprox(caught(:host, 2.0, 0.3, ContactparameterSampling(1.0)), 1 - exp(-0.6); atol = 0.05)
    end
end
