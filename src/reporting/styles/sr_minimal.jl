export MinimalSimulationReport

@with_kw mutable struct MinimalSimulationReport <: SimulationReportStyle
    data::ResultData
    title::String = "Minimal Simulation Report"
    subtitle::String = "Run ID - $(data |> id)"
    author::String =  "GEMS Team"
    abstract::String = "This document contains minimal information about the simulation."
    glossary::Bool =  true
    date::String = data |> execution_date
    sections::Vector = [
        Section(
            title =  "Model Configuration",
            content = "This section includes various subsections concerning the model configuration.",
            subsections = [
                Section(data, :InputFiles),
                Section(data, :General)
            ]
        ),
        Section(
            title =  "Simulation Results",
            subsections =[
                PlotSection(TickCases()),
                PlotSection(CumulativeCases()),
                PlotSection(CompartmentFill()),
                PlotSection(HospitalOccupancy()),
                PlotSection(EffectiveReproduction()),
                PlotSection(Incidence())
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
