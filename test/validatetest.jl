@testset "Input Validation" begin
    basefolder = dirname(dirname(pathof(GEMS)))

    popfile = "test/testdata/TestPop.csv"
    populationpath = joinpath(basefolder, popfile)

    confile = "test/testdata/TestConf.toml"
    configpath = joinpath(basefolder, confile)

    @testset "Valid Files" begin
        # the following files should run through without problems
        @test validate_toml_file(configpath)
        @test validate_popfile(populationpath)
    end

    @testset "Validate Dictionaries For Generation" begin
       
        @testset "StartCondition" begin
            properties = Dict(
                "type" => "InfectedFraction",
                "fraction" => 0.05,
                "pathogen" => "Test" 
            )
            @test validate(properties, StartCondition)

            properties["type"] = "NoStartCondition_lol"
            @test !validate(properties, StartCondition)

            properties["type"] = "InfectedFraction"
            properties["fraction"] = -2
            @test !validate(properties, StartCondition)

            properties = Dict(
                "type" => "InfectedFraction",
                "fraction" => 0.05
            )
            @test !validate(properties, StartCondition)

            properties = Dict(
                "type" => "InfectedFraction",
                "pathogen" => "Test" 
            )
            @test !validate(properties, StartCondition)
        end

        @testset "StopCriterion" begin
            properties = Dict(
                "type" => "TimesUp",
                "limit" => 120
            )

            @test validate(properties, StopCriterion)

            properties["type"] = "NoStopCriterion_lol"
            @test !validate(properties, StopCriterion)

            properties["type"] = "InfectedFraction"
            properties["limit"] = -2
            @test !validate(properties, StopCriterion)

            properties = Dict(
                "type" => "InfectedFraction",
            )
            @test !validate(properties, StopCriterion)
        end
        
        @testset "Pathogens" begin
            # As we only test for all given distributions to be valid, 
            # we will do that exemplarily here
            properties = Dict(
                "length_of_stay" => Dict(
                    "distribution" => "Poisson",
                    "parameters" => [3]
                )
            )
            @test validate(properties, Pathogen)
            @testset "Transmission Function" begin
                # Test the transmission function
                properties = Dict(
                    "transmission_function" => Dict(
                        "type" => "ConstantTransmissionRate",
                        "parameters" => Dict(
                            "transmission_rate" => 0.5
                        )
                    )
                )

                @test validate(properties, Pathogen)

                # Test wrong type of parameter
                properties = Dict(
                    "transmission_function" => Dict(
                        "type" => "ConstantTransmissionRate",
                        "parameters" => Dict(
                            "transmission_rate" => [0.5]
                        )
                    )
                )
                @test !validate(properties, Pathogen)

                # Test wrong name of type
                properties = Dict(
                    "transmission_function" => Dict(
                        "type" => "ConstantTransmissionRates",
                        "parameters" => Dict(
                            "transmission_rate" => 0.5
                        )
                    )
                )
                @test !validate(properties, Pathogen)

                # Test wrong name of parameter
                properties = Dict(
                    "transmission_function" => Dict(
                        "type" => "ConstantTransmissionRate",
                        "parameters" => Dict(
                            "transmission_rates" => 0.5
                        )
                    )
                )
                @test !validate(properties, Pathogen)
            end
            @testset "Disease Progression" begin
                # Same with DiseaseProgressionStrat
                properties = Dict(
                    "dpr" => Dict(
                        "age_groups" => ["0-40", "40-50", "50-60", "60-70", "70-80", "80+"],
                        "disease_compartments" => ["Asymptomatic", "Mild", "Severe", "Critical"],
                        "stratification_matrix" => [[0.006, 0.846, 0.144, 0.004],
                                                [0.006, 0.842, 0.144, 0.008],
                                                [0.006, 0.826, 0.141, 0.027],
                                                [0.006, 0.787, 0.134, 0.073],
                                                [0.005, 0.711, 0.121, 0.163],
                                                [0.004, 0.593, 0.101, 0.302]]
                    )
                )
                @test validate(properties, Pathogen)

                properties = Dict(
                    "dpr" => Dict(
                        "age_groups" => ["0-40", "40-50", "50-60", "60-70", "70-80", "80+"],
                        "disease_compartments" => ["Asymptomatic", "Mild", "Severe", "Critical"],
                        "stratification_matrix" => [[0.006, 0.846, 0.144, 0.004]]
                    )
                )
                @test !validate(properties, Pathogen)

                # Overlapping ages 
                properties = Dict(
                    "dpr" => Dict(
                        "age_groups" => ["0-40", "39-50", "50-60", "60-70", "70-80", "80+"],
                        "disease_compartments" => ["Asymptomatic", "Mild", "Severe", "Critical"],
                        "stratification_matrix" => [[0.006, 0.846, 0.144, 0.004],
                                                [0.006, 0.842, 0.144, 0.008],
                                                [0.006, 0.826, 0.141, 0.027],
                                                [0.006, 0.787, 0.134, 0.073],
                                                [0.005, 0.711, 0.121, 0.163],
                                                [0.004, 0.593, 0.101, 0.302]]
                    )
                )
                @test !validate(properties, Pathogen)
                # Sum of rows larger than 1
                properties = Dict(
                    "dpr" => Dict(
                        "age_groups" => ["0-40", "40-50", "50-60", "60-70", "70-80", "80+"],
                        "disease_compartments" => ["Asymptomatic", "Mild", "Severe", "Critical"],
                        "stratification_matrix" => [[0.6, 0.846, 0.144, 0.004],
                                                [0.006, 0.842, 0.144, 0.008],
                                                [0.006, 0.826, 0.141, 0.027],
                                                [0.006, 0.787, 0.134, 0.073],
                                                [0.005, 0.711, 0.121, 0.163],
                                                [0.004, 0.593, 0.101, 0.302]]
                    )
                )
                @test !validate(properties, Pathogen)
            end
        end

        @testset "Distributions" begin
            @test isvalidDistribution([1], Poisson)
            @test !isvalidDistribution([1,2], Poisson)
            @test isvalidDistribution([], Poisson)

            @test isvalidDistribution([1,2], Uniform)
            @test !isvalidDistribution([1,2,3], Uniform)
            @test !isvalidDistribution([3,1], Uniform)
            @test !isvalidDistribution([1], Uniform)
        end

        @testset "DiseaseProgressionStrat" begin
            properties = Dict(
                "age_groups" => ["0-40", "40-50", "50-60", "60-70", "70-80", "80+"],
                "disease_compartments" => ["Asymptomatic", "Mild", "Severe", "Critical"],
                "stratification_matrix" => [[0.006, 0.846, 0.144, 0.004],
                                        [0.006, 0.842, 0.144, 0.008],
                                        [0.006, 0.826, 0.141, 0.027],
                                        [0.006, 0.787, 0.134, 0.073],
                                        [0.005, 0.711, 0.121, 0.163],
                                        [0.004, 0.593, 0.101, 0.302]]
            )
            @test validate(properties, DiseaseProgressionStrat)

            # too few rows
            properties = Dict(
                "age_groups" => ["0-40", "40-50", "50-60", "60-70", "70-80", "80+"],
                "disease_compartments" => ["Asymptomatic", "Mild", "Severe", "Critical"],
                "stratification_matrix" => [[0.006, 0.846, 0.144, 0.004]]
            )
            @test !validate(properties, DiseaseProgressionStrat)

            # too few age groups
            properties = Dict(
                "age_groups" => ["0-40", "40-50", "50-60", "60-70"],
                "disease_compartments" => ["Asymptomatic", "Mild", "Severe", "Critical"],
                "stratification_matrix" => [[0.006, 0.846, 0.144, 0.004],
                                        [0.006, 0.842, 0.144, 0.008],
                                        [0.006, 0.826, 0.141, 0.027],
                                        [0.006, 0.787, 0.134, 0.073],
                                        [0.005, 0.711, 0.121, 0.163],
                                        [0.004, 0.593, 0.101, 0.302]]
            )
            @test !validate(properties, DiseaseProgressionStrat)
            
            # too few columns
            properties = Dict(
                "age_groups" => ["0-40", "40-50", "50-60", "60-70", "70-80", "80+"],
                "disease_compartments" => ["Asymptomatic", "Mild", "Severe", "Critical"],
                "stratification_matrix" => [[0.006, 0.846, 0.144],
                                        [0.006, 0.842, 0.144],
                                        [0.006, 0.826, 0.141],
                                        [0.006, 0.787, 0.134],
                                        [0.005, 0.711, 0.121],
                                        [0.004, 0.593, 0.101]]
            )
            @test !validate(properties, DiseaseProgressionStrat)

            # too few disease_compartments
            properties = Dict(
                "age_groups" => ["0-40", "40-50", "50-60", "60-70", "70-80", "80+"],
                "disease_compartments" => ["Asymptomatic", "Mild", "Severe"],
                "stratification_matrix" => [[0.006, 0.846, 0.144, 0.004],
                                        [0.006, 0.842, 0.144, 0.008],
                                        [0.006, 0.826, 0.141, 0.027],
                                        [0.006, 0.787, 0.134, 0.073],
                                        [0.005, 0.711, 0.121, 0.163],
                                        [0.004, 0.593, 0.101, 0.302]]
            )
            @test !validate(properties, DiseaseProgressionStrat)

            # disease_compartments missing completely
            properties = Dict(
                "age_groups" => ["0-40", "40-50", "50-60", "60-70", "70-80", "80+"],
                "stratification_matrix" => [[0.006, 0.846, 0.144, 0.004],
                                        [0.006, 0.842, 0.144, 0.008],
                                        [0.006, 0.826, 0.141, 0.027],
                                        [0.006, 0.787, 0.134, 0.073],
                                        [0.005, 0.711, 0.121, 0.163],
                                        [0.004, 0.593, 0.101, 0.302]]
            )
            @test !validate(properties, DiseaseProgressionStrat)

            # stratification_matrix missing completely
            properties = Dict(
                "age_groups" => ["0-40", "40-50", "50-60", "60-70", "70-80", "80+"],
                "disease_compartments" => ["Asymptomatic", "Mild", "Severe", "Critical"]
            )
            @test !validate(properties, DiseaseProgressionStrat)

            # age groups missing completely
            properties = Dict(
                "disease_compartments" => ["Asymptomatic", "Mild", "Severe", "Critical"],
                "stratification_matrix" => [[0.006, 0.846, 0.144, 0.004],
                                        [0.006, 0.842, 0.144, 0.008],
                                        [0.006, 0.826, 0.141, 0.027],
                                        [0.006, 0.787, 0.134, 0.073],
                                        [0.005, 0.711, 0.121, 0.163],
                                        [0.004, 0.593, 0.101, 0.302]]
            )
            @test !validate(properties, DiseaseProgressionStrat)

            # not open ended regarding ages
            properties = Dict(
                "age_groups" => ["0-40", "40-50", "50-60", "60-70", "70-80", "80-90"],
                "disease_compartments" => ["Asymptomatic", "Mild", "Severe", "Critical"],
                "stratification_matrix" => [[0.006, 0.846, 0.144, 0.004],
                                        [0.006, 0.842, 0.144, 0.008],
                                        [0.006, 0.826, 0.141, 0.027],
                                        [0.006, 0.787, 0.134, 0.073],
                                        [0.005, 0.711, 0.121, 0.163],
                                        [0.004, 0.593, 0.101, 0.302]]
            )
            @test !validate(properties, DiseaseProgressionStrat)

            # not starting at age 0
            properties = Dict(
                "age_groups" => ["2-40", "40-50", "50-60", "60-70", "70-80", "80+"],
                "disease_compartments" => ["Asymptomatic", "Mild", "Severe", "Critical"],
                "stratification_matrix" => [[0.006, 0.846, 0.144, 0.004],
                                        [0.006, 0.842, 0.144, 0.008],
                                        [0.006, 0.826, 0.141, 0.027],
                                        [0.006, 0.787, 0.134, 0.073],
                                        [0.005, 0.711, 0.121, 0.163],
                                        [0.004, 0.593, 0.101, 0.302]]
            )
            @test !validate(properties, DiseaseProgressionStrat)

            # wrong age groups
            properties = Dict(
                "age_groups" => ["0-40", "4s0-50", "50-60", "60-70", "70-80", "80+"],
                "disease_compartments" => ["Asymptomatic", "Mild", "Severe", "Critical"],
                "stratification_matrix" => [[0.006, 0.846, 0.144, 0.004],
                                        [0.006, 0.842, 0.144, 0.008],
                                        [0.006, 0.826, 0.141, 0.027],
                                        [0.006, 0.787, 0.134, 0.073],
                                        [0.005, 0.711, 0.121, 0.163],
                                        [0.004, 0.593, 0.101, 0.302]]
            )
            @test !validate(properties, DiseaseProgressionStrat)
            properties = Dict(
                "age_groups" => ["0-40", "40-50", "50-60", "60-70", "70-80", "80+12"],
                "disease_compartments" => ["Asymptomatic", "Mild", "Severe", "Critical"],
                "stratification_matrix" => [[0.006, 0.846, 0.144, 0.004],
                                        [0.006, 0.842, 0.144, 0.008],
                                        [0.006, 0.826, 0.141, 0.027],
                                        [0.006, 0.787, 0.134, 0.073],
                                        [0.005, 0.711, 0.121, 0.163],
                                        [0.004, 0.593, 0.101, 0.302]]
            )
            @test !validate(properties, DiseaseProgressionStrat)
            properties = Dict(
                "age_groups" => ["0-40", "40-50", "50-60", "60-70", "70-80", "12-80+"],
                "disease_compartments" => ["Asymptomatic", "Mild", "Severe", "Critical"],
                "stratification_matrix" => [[0.006, 0.846, 0.144, 0.004],
                                        [0.006, 0.842, 0.144, 0.008],
                                        [0.006, 0.826, 0.141, 0.027],
                                        [0.006, 0.787, 0.134, 0.073],
                                        [0.005, 0.711, 0.121, 0.163],
                                        [0.004, 0.593, 0.101, 0.302]]
            )
            @test !validate(properties, DiseaseProgressionStrat)
        end

        @testset "Vaccines" begin
            properties = Dict(
                "strategy" => Dict(
                    "type" => "DailyDoseStrategy",
                    "available_from" => 5,
                    "dose" => 4000
                ),
                "waning" => Dict(
                    "parameters" => [7, 90],
                    "waning" => "DiscreteWaning"
                )
            )
            @test validate(properties, Vaccine)

            properties = Dict(
                "strategy" => Dict(
                    "type" => "DailyDoseStrategy",
                    "available_from" => 5
                ),
                "waning" => Dict(
                    "waning" => "DiscreteWaning"
                )
            )
            @test !validate(properties, Vaccine)
        end

        @testset "Waning" begin
            @testset "DiscreteWaning" begin
                properties = Dict(
                    "parameters" => [7,90]
                )
                @test validate(properties, DiscreteWaning)

                properties = Dict()
                @test !validate(properties, DiscreteWaning)

                properties = Dict(
                    "parameters" => [7]
                )
                @test !validate(properties, DiscreteWaning)

                properties = Dict(
                    "parameters" => [7, 90, 12]
                )
                @test !validate(properties, DiscreteWaning)

                properties = Dict(
                    "parameters" => [-1,2]
                )
                @test !validate(properties, DiscreteWaning)

                properties = Dict(
                    "parameters" => [1,-2]
                )
                @test !validate(properties, DiscreteWaning)
            end
        end

        @testset "VaccinationStrategy" begin
           @testset "DailyDoseStrategy" begin
                properties = Dict(
                    "available_from" => 5,
                    "dose" => 4000
                )
                @test validate(properties, DailyDoseStrategy)

                # no available_from
                properties = Dict(
                    "dose" => 4000
                )
                @test !validate(properties, DailyDoseStrategy)

                # no dose
                properties = Dict(
                    "available_from" => 5
                )
                @test !validate(properties, DailyDoseStrategy)

                # negative available_from
                properties = Dict(
                    "available_from" => -5,
                    "dose" => 4000
                )
                @test !validate(properties, DailyDoseStrategy)

                # negative dose
                properties = Dict(
                    "available_from" => 5,
                    "dose" => -12
                )
                @test !validate(properties, DailyDoseStrategy)

                # dose of 0
                properties = Dict(
                    "available_from" => 5,
                    "dose" => 0
                )
                @test !validate(properties, DailyDoseStrategy)
           end 
        end

        @testset "Settings" begin
            @testset "Household" begin
                # correct input
                properties = Dict(
                    "contact_sampling_method" => Dict(
                        "type" => "TestSampling",
                        "parameters" => Dict(
                            "attr1" => 123,
                            "attr2" => "correct"
                        )
                    )
                )
                @test validate(properties, Household)

                # wrong type of contact_sampling_method ("s" has to be capital in "Randomsampling")
                properties = Dict(
                    "contact_sampling_method" => Dict(
                        "type" => "Randomsampling"
                    )
                )
                @test !validate(properties, Household)

                # wrong type of "attr1"
                properties = Dict(
                    "contact_sampling_method" => Dict(
                        "type" => "TestSampling",
                        "parameters" => Dict(
                            "attr1" => "123",
                            "attr2" => "correct"
                        )
                    )
                )
                @test !validate(properties, Household)
                
                # correct dict to create a "ContactparameterSampling" object
                properties = Dict(
                    "contact_sampling_method" => Dict(
                        "type" => "ContactparameterSampling",
                        "parameters" => Dict(
                            "contactparameter" => 12.0
                        )
                    )
                )
                @test validate(properties, Household)
                
                # wrong dict to create a "ContactparameterSampling" object
                properties = Dict(
                    "contact_sampling_method" => Dict(
                        "type" => "ContactparameterSampling",
                        "parameters" => Dict(
                            "contactparameter" => -12.0
                        )
                    )
                )
                @test !validate(properties, Household)

            end
        end

        @testset "PostProcessing" begin
            config = TOML.parsefile(configpath)
            config["PostProcessing"]=Dict("style" => "QWERT")
            @test !validate_config_dict(config)
            config["PostProcessing"]=Dict("style" => "DefaultResultData")
            @test validate_config_dict(config)
            
        end

        @testset "Reporting" begin
            config = TOML.parsefile(configpath)
            config["Reporting"]=Dict("style" => "DefaultSimsulationReport")
            @test !validate_config_dict(config)
            config["Reporting"]=Dict("style" => "DefaultSimulationReport")
            @test validate_config_dict(config)
        end
    end
       
    @testset "BatchValidation" begin
        basefolder = dirname(dirname(pathof(GEMS)))

        popfile = "test/testdata/TestPop.csv"
        populationpath = joinpath(basefolder, popfile)
    
        confile = "test/testdata/TestBatchConf.toml"
        configpath = joinpath(basefolder, confile)

        @testset "Working Batch Config" begin
            @test validate_toml_file(configpath, nothing)
        end

        @testset "Custom Batch Config" begin
            confile = "test/testdata/TestConf.toml"
            configpath = joinpath(basefolder, confile)
            batch_conf::Dict{String, Any} = Dict("BatchParameters" => Dict())
            @test !validate_batch_config_dict(batch_conf)
            @testset "Basic Batch Parameters" begin
                batch_conf["BatchParameters"]["repetitions"] = 1
                @test !validate_batch_config_dict(batch_conf)
                @testset "Base Config File" begin
                    # Try filepath
                    batch_conf["BatchParameters"]["base_config_file"] = joinpath(basefolder, "test", "testdata", "TestConf.toml")
                    @test validate_batch_config_dict(batch_conf)
                    # Try dictionary
                    batch_conf["BatchParameters"]["base_config_file"] = TOML.parsefile(joinpath(basefolder, "test", "testdata", "TestConf.toml"))
                    @test validate_batch_config_dict(batch_conf)
                    # Try providing it directly
                    delete!(batch_conf["BatchParameters"], "base_config_file")
                    @test validate_batch_config_dict(batch_conf, TOML.parsefile(configpath))
                    # Try multi line string
                    io = IOBuffer()
                    TOML.print(io, TOML.parsefile(joinpath(basefolder, "test", "testdata", "TestConf.toml")))
                    batch_conf["BatchParameters"]["base_config_file"] = String(take!(io))
                    @test validate_batch_config_dict(batch_conf)
                end
                # Try wrong repetitions
                batch_conf["BatchParameters"]["repetitions"] = -1
                @test !validate_batch_config_dict(batch_conf)
                batch_conf["BatchParameters"]["repetitions"] = 1
                # Try seed
                batch_conf["BatchParameters"]["seed"] = -1
                @test !validate_batch_config_dict(batch_conf)
                batch_conf["BatchParameters"]["seed"] = 1
                @test validate_batch_config_dict(batch_conf)
            end
            @testset "Parameter Variation" begin
                batch_conf["BatchParameters"]["VariedParameters"] = []
                @test validate_batch_config_dict(batch_conf)
                batch_conf["BatchParameters"]["VariedParameters"] = [Dict("number" => 5, "bounds" => [0.1,0.5])]
                @test !validate_batch_config_dict(batch_conf)
                # Working function
                batch_conf["BatchParameters"]["VariedParameters"] = [Dict("key" => "Pathogens.Test.mild_death_rate.parameters", 
                                                                                        "number" => 5, 
                                                                                        "bounds" => [0.1,0.5],
                                                                                        "function" => "x -> [x, x + 0.1]")]
                @test validate_batch_config_dict(batch_conf)
                # Not working function
                batch_conf["BatchParameters"]["VariedParameters"]= [Dict("key" => "Pathogens.Test.mild_death_rate.parameters", 
                                                                                        "number" => 5, 
                                                                                        "bounds" => [0.1,0.5],
                                                                                        "function" => "x -> y")]
                @test !validate_batch_config_dict(batch_conf)
                # Function leading to different data type
                batch_conf["BatchParameters"]["VariedParameters"] = [Dict("key" => "Pathogens.Test.mild_death_rate.parameters", 
                                                                                        "number" => 5, 
                                                                                        "bounds" => [0.1,0.5],
                                                                                        "function" => "x -> \"hello\"")]
                @test !validate_batch_config_dict(batch_conf)

                # Varied parameters as a list of values
                batch_conf["BatchParameters"]["VariedParameters"] = [Dict("key" => "Pathogens.Test.mild_death_rate.parameters", 
                                                                                        "values" => [[0.2, 0.3], [0.2, 0.5]])]
                @test validate_batch_config_dict(batch_conf)
                batch_conf["BatchParameters"]["VariedParameters"] = [Dict("key" => "Pathogens.Test.mild_death_rate.parameters", 
                                                                                        "values" => 0.1)]
                @test !validate_batch_config_dict(batch_conf)
                batch_conf["BatchParameters"]["VariedParameters"] = [Dict("key" => "Pathogens.Test.mild_death_rate.parameters", 
                                                                                        "values" => ["Hello"])]
                @test !validate_batch_config_dict(batch_conf)
                batch_conf["BatchParameters"]["VariedParameters"] = [Dict("key" => "Pathogens.Test.mild_death_rate.parameters", 
                                                                                        "values" => [[0.1, 0.2, 0.3], [0.1, 0.5, 0.8]])]
                @test !validate_batch_config_dict(batch_conf)
                batch_conf["BatchParameters"]["VariedParameters"] = []
            end
            @testset "Batch Processing Validation" begin
                batch_conf["BatchProcessing"]= Dict()
                @test validate_batch_config_dict(batch_conf)
                batch_conf["BatchProcessing"]= Dict("style" => "DefaultBatchData")
                @test validate_batch_config_dict(batch_conf)
                batch_conf["BatchProcessing"]= Dict("style" => "DefaultsBatchData")
                @test !validate_batch_config_dict(batch_conf)
            end
            @testset "Batch Reporting Validation" begin
                batch_conf["BatchProcessing"]= Dict()
                batch_conf["Reporting"]= Dict()
                @test validate_batch_config_dict(batch_conf)
                batch_conf["Reporting"]= Dict("style" => "DefaultBatchReport")
                @test validate_batch_config_dict(batch_conf)
                batch_conf["Reporting"]= Dict("style" => "DefaultsBatchData")
                @test !validate_batch_config_dict(batch_conf)
            end
        end
    end
end
