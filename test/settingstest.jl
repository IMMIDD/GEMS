@testset "Settings" begin
    rs = RandomSampling()
    test_rng = Xoshiro()

    @testset "GlobalSetting" begin

        @testset "Creation and Management" begin
            indis = [Individual(id=j, age=18, sex=1) for j in range(0, 3)]
            i = Individual(id=42, age=21, sex=0)

            gs = GlobalSetting(individuals=indis, contact_sampling_method=rs)

            @test Set(individuals(gs)) == Set(indis)
            @test !isactive(gs)

            add!(gs, i)
            @test Set(individuals(gs)) == Set(push!(indis, i))
            @test !isactive(gs)

            activate!(gs)
            @test isactive(gs)

            deactivate!(gs)
            @test !isactive(gs)
        end
    end

    @testset "Settingfile" begin
        @testset "Correct Settingfile" begin
            sydf = DataFrame(id=[1, 2], contains=[[1, 2], [3, 4]])
            scdf = DataFrame(id=[1, 2, 3, 4], contained=Int32.([1, 1, 2, 2]))
            settingsfile = Dict(
                :SchoolYear => sydf,
                :SchoolClass => scdf
            )

            sc = SettingsContainer()
            add_types!(sc, [SchoolYear, SchoolClass])
            for i in 1:4
                add!(sc, SchoolClass(id=i, individuals=[Individual(id=i, age=1, sex=1)], contact_sampling_method=rs))
            end

            JLD2.save("temp.jld2", "data", settingsfile)

            settings_from_jld2!("temp.jld2", sc)

            sim = Simulation()
            sim.settings = sc

            for i in 1:4
                @test individuals(settings(sc, SchoolClass)[i]) |> Base.first |> id == i
            end
            @test id.(individuals(settings(sc, SchoolYear)[1], sim)) == [1, 2]
            @test id.(individuals(settings(sc, SchoolYear)[2], sim)) == [3, 4]

            # Delete the file
            rm("temp.jld2")
        end
        @testset "Faulty Settingfile: Empty Container" begin
            scdf = DataFrame(id=[1, 2, 3, 4], contained=Int32.([1, 1, 2, 2]))
            sydf = DataFrame(id=[1, 2], contains=[[1, 2], [3, 4]], contained=Int32.([2, 2]))
            sdf = DataFrame(id=[2, 3], contains=[[1, 2], []])
            settingsfile = Dict(
                :SchoolYear => sydf,
                :SchoolClass => scdf,
                :School => sdf
            )

            sc = SettingsContainer()

            add_types!(sc, [SchoolYear, SchoolClass, School])

            for i in 1:4
                add!(sc, SchoolClass(id=i, individuals=[Individual(id=i, age=1, sex=1)], contact_sampling_method=rs))
            end

            JLD2.save("temp.jld2", "data", settingsfile)

            settings_from_jld2!("temp.jld2", sc)

            sim = Simulation()
            sim.settings = sc

            for i in 1:4
                @test individuals(settings(sc, SchoolClass)[i]) |> Base.first |> id == i
            end
            @test id.(individuals(settings(sc, SchoolYear)[1], sim)) == [1, 2]
            @test id.(individuals(settings(sc, SchoolYear)[2], sim)) == [3, 4]
            @test id.(individuals(settings(sc, School)[1], sim)) == [1, 2, 3, 4]

            # Test the empty school
            @test individuals(settings(sc, School)[2], sim) == []
            @test id(settings(sc, School)[2]) == 2

            # Test if empty school is appropriately removed
            remove_empty_settings!(sim)
            @test length(settings(sc, School)) == 1

            # Delete the file
            rm("temp.jld2")
        end
        @testset "Faulty Settingfile: ID Transformation" begin
            scdf = DataFrame(id=[2, 3, 4, 5, 6, 7, 8, 9], contained=Int32.([1, 1, 2, 2, 3, 3, 3, 3]))
            sydf = DataFrame(id=[1, 2], contains=[[2, 3], [4, 5]], contained=Int32.([2, 2]))
            sdf = DataFrame(id=[2, 3], contains=[[1, 2], []])
            settingsfile = Dict(
                :SchoolYear => sydf,
                :SchoolClass => scdf,
                :School => sdf
            )

            sc = SettingsContainer()

            add_types!(sc, [SchoolYear, SchoolClass, School])

            inds = [Individual(id=i, age=1, sex=1, schoolclass=i + 1) for i in 1:4]
            pop = Population(inds)

            sc, rnm = settings_from_population(pop)

            renaming = Dict(5 => 4, 4 => 3, 3 => 2, 2 => 1)

            # Test correct renaming
            @test rnm[SchoolClass] == renaming

            JLD2.save("temp.jld2", "data", settingsfile)

            settings_from_jld2!("temp.jld2", sc, rnm)

            sim = Simulation()
            sim.settings = sc
            sim.population = pop

            for i in 1:4
                @test individuals(settings(sc, SchoolClass)[i]) |> Base.first |> id == i
            end

            @test id.(individuals(settings(sc, SchoolYear)[1], sim)) == [1, 2]
            @test id.(individuals(settings(sc, SchoolYear)[2], sim)) == [3, 4]
            @test id.(individuals(settings(sc, School)[1], sim)) == [1, 2, 3, 4]

            # Test the empty school
            @test individuals(settings(sc, School)[2], sim) == []
            @test id(settings(sc, School)[2]) == 2

            # Test if empty school is appropriately removed
            remove_empty_settings!(sim)
            @test length(settings(sc, School)) == 1

            # Delete the file
            rm("temp.jld2")
        end
    end

    @testset "Households" begin

        @testset "Creation and Management" begin
            rs = RandomSampling()
            indis = [Individual(id=j, age=18, sex=1, household=1) for j in range(0, 3)]
            i = Individual(id=42, age=21, sex=0, household=1)

            h = Household(id=1, individuals=indis, contact_sampling_method=rs)

            @test Set(individuals(h)) == Set(indis)
            @test !isactive(h)

            add!(h, i)
            @test Set(individuals(h)) == Set(push!(indis, i))
            @test !isactive(h)

            activate!(h)
            @test isactive(h)

            deactivate!(h)
            @test !isactive(h)
        end

        @testset "Settings from Population" begin
            Random.seed!(test_rng, 42)

            num_agents = 15
            size_household = 3
            size_office = 5
            indivs = [Individual(id=i, sex=rand(test_rng, [1, 2]), age=42) for i in range(1, num_agents)]

            #=  
                Distribute everyone to an household
                not shuffeling the individual means, that the first ones should be together
                in a household and a office 
            =#
            hh_partitions = Iterators.partition(indivs, size_household)
            i = 1
            for individuals in hh_partitions
                for ind in individuals
                    ind.household = i
                end
                i += 1
            end

            # Distribute everyone to a office
            wp_partitions = Iterators.partition(indivs, size_office)
            i = 1
            for individuals in wp_partitions
                for ind in individuals
                    ind.office = i
                end
                i += 1
            end

            #= 
                shuffle the population now means that the original setting ids
                wont match the position in the SettingsContainer. As the function
                settings_from_population should rename the ids, we will force it
                thus to do so.
                But because Partitions are Iterators, we have to collect them first!
            =#
            hh_partitions = [collect(part) for part in hh_partitions]
            wp_partitions = [collect(part) for part in wp_partitions]

            shuffle!(test_rng, indivs)

            pop = Population(indivs)
            stngs, rnm = settings_from_population(pop)

            # test if ids of individuals and offices still match as well as assignment 
            for hh in get(stngs, Household)
                # take one individual, find the og partition and look if everyone is there
                i = individuals(hh)[1]
                part = [part for part in hh_partitions if i in part][1]
                for indiv in part
                    @test indiv in individuals(hh)
                end
                @test length(individuals(hh)) == length(part)
                break
            end

            # # same for offices
            for wp in get(stngs, Office)
                # take one individual, find the og partition and look if everyone is there
                i = individuals(wp)[1]
                part = [part for part in wp_partitions if i in part][1]
                for indiv in part
                    @test indiv in individuals(wp)
                end
                @test length(individuals(wp)) == length(part)
            end

            # test IDs of all settings
            for type in settingtypes(stngs)
                for (idx, stng) in enumerate(get(stngs, type))
                    @test stng.id == idx
                end
            end
        end

    end

    @testset "SettingsContainer" begin
        rs = RandomSampling()
        stngs = SettingsContainer()
        add_types!(stngs, [GlobalSetting, Household, Office])
        # preallocate empty vectors per setting type
        @test stngs.settings[GlobalSetting] == []
        @test stngs.settings[Household] == []
        @test stngs.settings[Office] == []

        @test settings(stngs) == stngs.settings
        @test get(stngs, Household) == stngs.settings[Household]

        @test get(stngs, GlobalSetting) == []
        gs = GlobalSetting(contact_sampling_method=rs)
        add!(stngs, gs)
        @test get(stngs, GlobalSetting) == [gs]
    end

    @testset "Open and Closing" begin
        rs = RandomSampling()

        sim = Simulation()

        inds = [Individual(id=i, sex=1, age=i) for i in 1:20]

        sc1 = SchoolClass(id=1, individuals=inds[1:5], contained=1, contact_sampling_method=rs)
        sc2 = SchoolClass(id=2, individuals=inds[6:10], contained=1, contact_sampling_method=rs)
        sc3 = SchoolClass(id=3, individuals=inds[11:15], contained=2, contact_sampling_method=rs)
        sc4 = SchoolClass(id=4, individuals=inds[16:20], contained=2, contact_sampling_method=rs)

        sy1 = SchoolYear(id=1, contains=[1, 2], contained=1, contact_sampling_method=rs)
        sy2 = SchoolYear(id=2, contains=[3, 4], contained=1, contact_sampling_method=rs)

        sc = School(id=1, contains=[1, 2], contact_sampling_method=rs)

        stngs = SettingsContainer()

        add_types!(stngs, [SchoolClass, SchoolYear, School])

        add!(stngs, sc1)
        add!(stngs, sc2)
        add!(stngs, sc3)
        add!(stngs, sc4)
        add!(stngs, sy1)
        add!(stngs, sy2)
        add!(stngs, sc)
        pop = Population(inds)
        sim.population = pop
        sim.settings = stngs



        close!(sc1)
        @test individuals(sc1, sim) |> x -> id.(x) == Int32.([1, 2, 3, 4, 5])
        @test individuals(sc, sim) |> x -> id.(x) |> x -> filter(x -> !(x in [1, 2, 3, 4, 5]), x) == present_individuals(sc, sim) |> x -> id.(x)
        close!(sy2, sim)
        @test individuals(sc, sim) |> x -> id.(x) |> x -> filter(x -> !(x in [1, 2, 3, 4, 5, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]), x) == present_individuals(sc, sim) |> x -> id.(x)
        open!(sc1)
        @test individuals(sc, sim) |> x -> id.(x) |> x -> filter(x -> !(x in [11, 12, 13, 14, 15, 16, 17, 18, 19, 20]), x) == present_individuals(sc, sim) |> x -> id.(x)
        open!(sy2)

        # Check if closing containers closes all contained settings
        close!(sc, sim)
        @test is_open(sc1) == false
        @test is_open(sc2) == false
        @test is_open(sc3) == false
        @test is_open(sc4) == false
        @test is_open(sy1) == false
        @test is_open(sy2) == false
        @test is_open(sc) == false
        @test present_individuals(sc, sim) == []
        @test present_individuals(sc1, sim) == []
        @test present_individuals(sc2, sim) == []
        @test present_individuals(sc3, sim) == []
        @test present_individuals(sc4, sim) == []
        @test present_individuals(sy1, sim) == []
        @test present_individuals(sy2, sim) == []

        open!(sc, sim)
        @test is_open(sc1) == true
        @test is_open(sy2) == true

        close!(sy1, sim)
        @test is_open(sc1) == false
        @test is_open(sc2) == false
        @test is_open(sc3) == true
        @test is_open(sc4) == true
        @test is_open(sy2) == true

    end

    @testset "Setting Identification" begin
        rs = RandomSampling()
        h = Household(id=1, contact_sampling_method=rs)
        gs = GlobalSetting(contact_sampling_method=rs)
        wp = Office(id=1, contact_sampling_method=rs)
        m = Municipality(id = 1)
        s = School(id = 1)
        w = Workplace(id = 1)
        sc = SchoolComplex(id = 1)
        sy = SchoolYear(id = 1)
        d = Department(id = 1)
        ws = WorkplaceSite(id = 1)

        struct newSetting <: Setting end
        ns = newSetting()        

        @test '?' == settingchar(ns)
        @test 'h' == settingchar(h)
        @test 'g' == settingchar(gs)
        @test 'o' == settingchar(wp)
        @test 'm' == settingchar(m)
        @test 's' == settingchar(s)
        @test 'x' == settingchar(sc)
        @test 'y' == settingchar(sy)
        @test 'd' == settingchar(d)
        @test 'p' == settingchar(ws)
        @test 'w' == settingchar(w)

        @test settingstring('h') == "Household"
        @test settingstring('s') == "School"
        @test settingstring('c') == "Schoolclass"
        @test settingstring('x') == "Schoolcomplex"
        @test settingstring('y') == "Schoolyear"
        @test settingstring('w') == "Workplace"
        @test settingstring('p') == "WorkplaceSite"
        @test settingstring('d') == "Department"
        @test settingstring('o') == "Office"
        @test settingstring('m') == "Municipality"
        @test settingstring('g') == "GlobalSetting"
        @test settingstring('a') == "Unknown"

        @test contact_sampling_method(h) === rs
        rs2 = RandomSampling()
        contact_sampling_method!(h, rs2) 
        @test contact_sampling_method(h) === rs2
        
        @test contained(w) == -1
        @test contained_type(w) == WorkplaceSite
 
    end



    @testset "Setting Creation with Real Settingfile" begin

        # global parameters
        BASE_FOLDER = dirname(dirname(pathof(GEMS)))

        # Infected Fraction
        p = Pathogen(id=1, name="COVID")
        inf = InfectedFraction(0.01, p)
        pop = Population(BASE_FOLDER * "/test/testdata/people_muenster.jld2")
        stngs, renaming = settings_from_population(pop)
        settings_from_jld2!(BASE_FOLDER * "/test/testdata/settings_muenster.jld2", stngs, renaming)

        containers = JLD2.load(BASE_FOLDER * "/test/testdata/settings_muenster.jld2", "data")
        contained_stngs_exist = true
        contains_stngs_exist = true
        properties_correct = true
        contains_correctly_loaded = true
        contained_correctly_loaded = true
        ids_correct = true
        # Check that all settings are correctly loaded
        for (type, list) in settings(stngs)
            for stng in list
                # Test if linked contained settings exist
                if hasproperty(stng, :contained)
                    contained_stngs_exist = contained_stngs_exist & isa(settings(stngs, stng.contained_type)[stng.contained], stng.contained_type)
                end
                # Test if linked contains settings exist
                if hasproperty(stng, :contains)
                    for idx in stng.contains
                        contains_stngs_exist = contains_stngs_exist & isa(settings(stngs, stng.contains_type)[idx], stng.contains_type)
                    end
                end
                if Symbol(type) in keys(containers)
                    ids_correct = ids_correct & (id(stng) == containers[Symbol(type)].id[id(stng)])
                    # Test if contains are correctly loaded
                    if hasproperty(stng, :contains)
                        contains_correctly_loaded = contains_correctly_loaded & (stng.contains == containers[Symbol(type)].contains[id(stng)])
                    end
                    # Test if contained are correctly loaded
                    if hasproperty(stng, :contained)
                        contained_correctly_loaded = contained_correctly_loaded & (stng.contained == containers[Symbol(type)].contained[id(stng)])
                    end
                    # Test if location and ags are correctly loaded
                    if type in [SchoolClass, Office, Household]
                        properties_correct = properties_correct & (geolocation(stng)[1] == containers[Symbol(type)].lon[id(stng)])
                        properties_correct = properties_correct & (geolocation(stng)[2] == containers[Symbol(type)].lat[id(stng)])
                        properties_correct = properties_correct & (id(ags(stng)) == containers[Symbol(type)].ags[id(stng)])
                    end
                end

            end
        end

        @test contained_stngs_exist
        @test contains_stngs_exist
        @test properties_correct
        @test contains_correctly_loaded
        @test contained_correctly_loaded
        @test ids_correct
    end

    @testset "Office, Schoolclass and Municipality" begin
        my_pop = DataFrame(
            id = [1,2,3],
            sex = [1,2,1],
            age = [10, 34, 25],
            household = [1,1,2],
            office = [2,2,1],
            municipality = [1,1,1])
        
        sim = Simulation(population = Population(my_pop))
        inds = individuals(sim)
        @test GEMS.office(inds[1], sim) === offices(sim)[2]
        @test GEMS.office(inds[2], sim) === offices(sim)[2]
        @test GEMS.office(inds[3], sim) === offices(sim)[1]
        @test_throws "Individual $(id(inds[1])) is not assigned to a School Class" GEMS.schoolclass(inds[1], sim)

        my_pop = DataFrame(
            id = [1,2,3],
            sex = [1,2,1],
            age = [10, 34, 25],
            household = [1,1,2],
            schoolclass = [2,2,1],
            municipality = [1,1,1])
        
        sim = Simulation(population = Population(my_pop))
        inds = individuals(sim)
        @test GEMS.schoolclass(inds[1], sim) === schoolclasses(sim)[2]
        @test GEMS.schoolclass(inds[2], sim) === schoolclasses(sim)[2]
        @test GEMS.schoolclass(inds[3], sim) === schoolclasses(sim)[1]
        @test_throws "Individual $(id(inds[1])) is not assigned to an Office" GEMS.office(inds[1], sim)

        for ind in inds
           @test GEMS.municipality(ind, sim) === municipalities(sim)[1]
        end
    end

    @testset "get_open_contained and other tests" begin

        sim = Simulation()

        # Create settings
        workplace1 = Workplace(id=1, isopen=true)

        department1 = Department(id=4, isopen=true)

        municipality1 = Municipality(id=6, isopen=true)

        # Define dictionary to collect results
        dct = Dict{DataType,Vector{Int32}}()

        # Run the function
        get_open_contained!(workplace1, dct, sim)
        get_open_contained!(municipality1, dct, sim)

        # Check expected results
        @test haskey(dct, Workplace)
        @test haskey(dct, Municipality)

        @test dct[Workplace] == [1]
        @test dct[Municipality] == [6]

        ags_muenster = AGS("05515000")
        municipality1.ags = ags_muenster
        @test ags(municipality1, sim) === ags_muenster
        @test ags(workplace1,sim) == AGS()

        sim = Simulation(pop_size = 100)
        inds = individuals(workplace1, sim)
        @test sample_individuals(inds, 200)==inds

        @test avg_individuals(Setting[], sim) === nothing

        @test min_max_avg_individuals(Setting[], sim) === (nothing, nothing, nothing)

        # test size function for containersettings
        sc = SettingsContainer()
        add_types!(sc, [Department, Office])

        inds = [Individual(id=j, age=1, sex=1) for j in 1:15]

        index = 1
        for i in 1:5
            add!(sc, Office(id=i, individuals=inds[index:(index + i - 1)]))
            index += i  
        end

        department = Department(id = 1, contains = 1:5)
        add!(sc, department)
        
        sim = Simulation()
        sim.settings = sc
        
        department = settings(sc, Department)[1]
        @test size(department, sim) == 15
    end

    @testset "Geolocated tests" begin
        o1 = Office(id = 1, lat = 40.5f0, lon = -74.0f0)
        @test lat(o1) == 40.5f0
        @test lon(o1) == -74.0f0

        o2 = Office(id = 2)
        @test all(isnan, geolocation(o2))
        sim = Simulation()
        @test all(isnan, geolocation(o2, sim))
        
        d1 = Department(id = 1, contains = [1])
     
        #TODO test function geolocation(stng::ContainerSetting, sim::Simulation)
        #a (small) settingsfile is needed, where you have geolocated settings, e.g. offices
        
    end

end