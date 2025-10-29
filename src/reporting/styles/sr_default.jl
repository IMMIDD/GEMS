export DefaultSimulationReport

@with_kw mutable struct DefaultSimulationReport <: SimulationReportStyle
    data::ResultData
    title::String = "Simulation Report"
    subtitle::String = "Run ID - $(data |> id)"
    author::String =  "GEMS Team"
    abstract::String = "This document contains a technical and epidemiological report
    of a simulation run carried out using the **G**erman **E**pidemic
    **M**icro-Simulation **S**ystem (GEMS) v$(data |> GEMS_version).
    Code available at: https://gitlab.rlp.net/optim-agent/gems"
    glossary::Bool =  true
    date::String = data |> execution_date_formatted
    sections::Vector = [
        Section(
            title =  "Model Configuration",
            content = "This section reports on input model parameterization.",
            subsections = [
                Section(data, :InputFiles),
                Section(data, :General),
                Section(data, :Pathogens),
                Section(data, :Interventions),
                Section(data, :Settings),
                PlotSection(:SettingSizeDistribution)
            ]
        ),
        Section(
            title = "Model Analysis",
            content = "This section reports on analyses on the input model.
                       It does not cover any results from the actual simulation.",
            subsections = [
                PlotSection(PopulationPyramid()),
                PlotSection(AggregatedSettingAgeContacts(Household)),
                PlotSection(AggregatedSettingAgeContacts(SchoolClass)),
                PlotSection(AggregatedSettingAgeContacts(School)),
                PlotSection(AggregatedSettingAgeContacts(SchoolComplex)),
                PlotSection(AggregatedSettingAgeContacts(Office)),
                PlotSection(AggregatedSettingAgeContacts(Department)),
                PlotSection(AggregatedSettingAgeContacts(Workplace)),
                PlotSection(AggregatedSettingAgeContacts(WorkplaceSite)),
                PlotSection(AggregatedSettingAgeContacts(Municipality))
#                PlotSection(AggregatedSettingAgeContacts(GlobalSetting, 10))
            ]
        ),
        Section(
            title =  "Simulation Results",
            content = "This section reports on data that was generated during the simulation execution.",
            subsections =[
                Section(data, :Overview),
                Section(
                    title = "Epidemic Progression",
                    subsections = [
                        PlotSection(:InfectionMap),   
                        PlotSection(:TickCases),
                        PlotSection(:CumulativeCases),
                        PlotSection(:CompartmentFill),
                        PlotSection(:HouseholdAttackRate),
                        PlotSection(:TickCasesBySetting),
                        PlotSection(:EffectiveReproduction),
                        PlotSection(:Incidence)
                    ]),
                Section(
                    title = "Observed Progression",
                    subsections = [
                        Section(data, :Observations),
                        PlotSection(:DetectedCases),
                        PlotSection(:ObservedReproduction),
                        PlotSection(:ObservedSerialInterval),
                        PlotSection(:ActiveDarkFigure),
                        PlotSection(:TestPositiveRate),
                        PlotSection(:TimeToDetection)
                        
                    ]),
                Section(
                    title = "Disease Progression",
                    subsections = [
                        PlotSection(:CumulativeDiseaseProgressions),
                        PlotSection(:ProgressionCategories),
                        PlotSection(:GenerationTime),
                        PlotSection(:LatencyHistogram),
                        PlotSection(:InfectionDuration),
                        PlotSection(:InfectiousHistogram)
                    ]),
                Section(
                    title = "Intervention Progression",
                    subsections = [
                        PlotSection(:TickTests),
                        PlotSection(:CumulativeIsolations)
                    ])
            ]
        ),
        Section(
            title = "Debug Information",
            subsections = [
                Section(data, :Repo),
                Section(data, :System),
                Section(data, :Processor),
                Section(data, :Memory)
            ]
        )
    ]
end