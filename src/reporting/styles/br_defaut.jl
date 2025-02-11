export DefaultBatchReport

@with_kw mutable struct DefaultBatchReport <: BatchReportStyle
    data::BatchData
    title::String = "Batch Simulation Report"
    subtitle::String = "Batch Run ID - $(data |> id)"
    author::String =  "GEMS Team"
    abstract::String = "This document contains a technical and epidemiological report
    of a batch run carried out using the **G**erman **E**pidemic
    **M**icro-Simulation **S**ystem (GEMS) v$(data |> GEMS_version).
    Code available at: https://gitlab.rlp.net/optim-agent/gems"
    glossary::Bool =  true
    date::String = data |> execution_date
    sections::Vector = [
        Section(data, :BatchInfo),
        Section(
            title =  "Simulation Results",
            content = "This section reports on data that was generated during the simulation execution.",
            subsections =[
                Section(data, :Overview),
                PlotSection(:TickCases),
                PlotSection(:EffectiveReproduction),
                PlotSection(:TotalTests)
            ]
        ),
        Section(data, :Debug)
    ]
end
