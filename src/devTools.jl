export test_sim, test_sim_r, report_test, plot_test, test_all, test_state, batch_test, intervention_test, geolocated_sim, geolocated_test, settingfile_sim, settingfile_test
export getundocumented

"""
    test_sim()

Returns a simulation object with test data.
"""
function test_sim()

    BASE_FOLDER = dirname(dirname(pathof(GEMS)))
    return Simulation(BASE_FOLDER * "/data/TestConf.toml", BASE_FOLDER * "/data/DE_03_KLLand.csv")

end

"""
    test_sim_r()

Returns a simulation object with test data using the predefined (remote) population models.
"""
function test_sim_r(popidentifier::String)

    BASE_FOLDER = dirname(dirname(pathof(GEMS)))
    return Simulation(config_file = BASE_FOLDER * "/data/TestConf.toml", remote = true, popidentifier = popidentifier)

end

function test_sim(rel_path::String, conf::String="data/TestConf.toml")

    BASE_FOLDER = dirname(dirname(pathof(GEMS)))
    Simulation(joinpath(BASE_FOLDER, conf), joinpath(BASE_FOLDER, rel_path))

end


function report_test()
    BASE_FOLDER = dirname(dirname(pathof(GEMS)))

    sim = test_sim()
    run!(sim)

    pp = PostProcessor(sim)

    rd = ResultData(pp)

    rep = buildreport(rd)

    generate(rep, BASE_FOLDER * "/results")
end


function test_all()
    BASE_FOLDER = dirname(dirname(pathof(GEMS)))
    return(
        main([BASE_FOLDER * "/data/TestConf.toml", BASE_FOLDER * "/data/DE_03_KLLand.csv", BASE_FOLDER * "/results"])
    )
end

function test_all(rel_path::String, config::String = "data/TestConf.toml")
    BASE_FOLDER = dirname(dirname(pathof(GEMS)))
    return(
        main([joinpath(BASE_FOLDER, config), joinpath(BASE_FOLDER, rel_path), BASE_FOLDER * "/results"])
    )
end

"""
    test_state(state::String)

Runs a simulation for the German state specified in `state`.
Requires a folder in the project root called "localdata" which
contains a subfolder with the `state` abbreviation and two
containing files: `people_\$state.jld2"` and settings_\$state.jld2.
"""
function test_state(state::String)
    BASE_FOLDER = dirname(dirname(pathof(GEMS)))
    return(
        main(
            BASE_FOLDER * "/data/TestConf.toml",
            BASE_FOLDER * "/localdata/$state/people_$state.jld2",
            BASE_FOLDER * "/results/$(Dates.format(now(), "yyyy-mm-dd_HH-MM-SS_sss"))_$state",
            settingfile = BASE_FOLDER * "/localdata/$state/settings_$state.jld2",
            report = true)
    )
end


function batch_test(;report = true)
    BASE_FOLDER = dirname(dirname(pathof(GEMS)))
    return batch(
        BASE_FOLDER * "/data/TestBatchConf.toml",
        BASE_FOLDER * "/data/DE_03_KLLand.csv",
        BASE_FOLDER * "/results",
        report = report,
        with_progressbar = false
    )
end

function batch_test(rel_path::String)
    BASE_FOLDER = dirname(dirname(pathof(GEMS)))
    return(
        batch([
            BASE_FOLDER * "/data/TestBatchConf.toml",
            BASE_FOLDER * "/" * rel_path,
            BASE_FOLDER * "/results"
        ], with_progressbar = false)
    )
end


function intervention_test()

    BASE_FOLDER = dirname(dirname(pathof(GEMS)))
    timestamp = now()

    return(
        main(
            BASE_FOLDER * "/data/TestConf.toml",
            BASE_FOLDER * "/data/DE_03_KLLand.csv",
            BASE_FOLDER * "/results/" * Dates.format(timestamp, "yyyy-mm-dd_HH-MM-SS_sss"),

            report = true,    
            mod! = function(sim::Simulation)
                
                nicer_test = TestType("Nicer Test", pathogen(sim), sim)

                cancel_isolation = IStrategy("cancel isolation", sim)
                    add_measure!(cancel_isolation, CancelSelfIsolation())

                test_only = IStrategy("test_only", sim)
                    add_measure!(test_only, Test(
                        "symptoms test 2",
                        nicer_test,
                        nothing,
                        nothing
                    ))

                symptoms_isolation_and_test = IStrategy("symptoms isolation and test", sim)
                    add_measure!(symptoms_isolation_and_test, SelfIsolation(10))
                    add_measure!(symptoms_isolation_and_test, Test(
                        "symptoms test",
                        nicer_test,
                        nothing,
                        test_only
                    ), offset = 2)

                s_trigger = SymptomTrigger(symptoms_isolation_and_test)

                add_symptom_trigger!(sim, s_trigger)        
            end
        )
    )
end

# adds geo-coordinates to a simulation object randomly sampled
# from population data (from Pablo's data repository)
add_geo_coords! = function(sim::Simulation)
                
    # use mod function to add geolocations
    lat_file_path = "localdata/P_Lat.jld2"
    lon_file_path = "localdata/P_Lon.jld2"

    # load locations
    lats = JLD2.load(lat_file_path)["data"]
    lons = JLD2.load(lon_file_path)["data"]

    # sample a location for all setting types in the simulation
    for st in settingtypes(settingscontainer(sim))
        for s in settings(sim, st)
            if typeof(s) <: Geolocated
                pos = gems_rand(sim.main_rng, 1:length(lats))
                lat = lats[pos]
                lon = lons[pos]
                s.lat = lat
                s.lon = lon
            end
        end
    end
end



function geolocated_sim()
    BASE_FOLDER = dirname(dirname(pathof(GEMS)))
    sim = Simulation(BASE_FOLDER * "/data/TestConf.toml", BASE_FOLDER * "/data/test_pop_100k_2hh_50wp.jld2")
    add_geo_coords!(sim)
    return(sim)
end


function geolocated_test()

    BASE_FOLDER = dirname(dirname(pathof(GEMS)))
    timestamp = now()

    return(
        main(
            BASE_FOLDER * "/data/TestConf.toml",
            BASE_FOLDER * "/data/test_pop_1m_2hh_50wp.jld2",
            BASE_FOLDER * "/results/geo_" * Dates.format(timestamp, "yyyy-mm-dd_HH-MM-SS_sss"),

            report = true,    
            mod! = add_geo_coords!
        )
    )
end



"""
    settingfile_sim()

Returns a simulation object with data from the full population file and settingfile from Münster.

"""
function settingfile_sim()
    BASE_FOLDER = dirname(dirname(pathof(GEMS)))
    sim = Simulation(BASE_FOLDER * "/data/TestConfAllSettings.toml", BASE_FOLDER * "/data/people_muenster.jld2", settingfile = BASE_FOLDER * "/data/settings_muenster.jld2")
    return(sim)
end

"""
    settingfile_test()

Runs a simulation with the population file and settingfile from Münster incl. the post-processing 
and report generation and returns the resultdata object.

"""
function settingfile_test()
    BASE_FOLDER = dirname(dirname(pathof(GEMS)))
    timestamp = now()
    return(
        main(
            BASE_FOLDER * "/data/TestConfAllSettings.toml",
            BASE_FOLDER * "/data/people_muenster.jld2",
            BASE_FOLDER * "/results/geo_" * Dates.format(timestamp, "yyyy-mm-dd_HH-MM-SS_sss"),
            settingfile = BASE_FOLDER * "/data/settings_muenster.jld2",
            report = true
        )
    )
end

"""
    getundocumented()

Returns a dataframe of all Functions and/or structs without a docstring.
"""
function getundocumented()
    hasdoc(mod::Module, sym::Symbol) = haskey(Base.Docs.meta(mod), Base.Docs.Binding(mod, sym));
    
    undocumented = DataFrame(name = [], sig = [])
    for name in names(GEMS, all=true, imported=true)
        # Get only functions and variables (exclude modules, etc.)
        if isdefined(GEMS, name) && typeof(getfield(GEMS, name)) <: Function
            funcs = methods(getfield(GEMS, name))
            for f in funcs
                if !hasdoc(GEMS, name)
                    push!(undocumented, (name, f.sig))
                end
            end
        end
    end
    return undocumented
end
