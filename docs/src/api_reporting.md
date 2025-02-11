# Reporting

## Overview Structs
```@index
Pages   = ["api_reporting.md"]
Order   = [:type]
```
## Overview Functions
```@index
Pages   = ["api_reporting.md"]
Order   = [:function]
```

## Structs
```@docs
AbstractSection
BatchReport
PlotSection
Report
ReportPlot
Section
SectionBuilder
SimulationReport
```

## Functions
```@docs
abstract
abstract!
addsection!
addtimer!
author!
author
buildreport
content!
content
date!
date
debugrep(::ResultData)
description!(::ReportPlot, ::String)
description(::ReportPlot)
dpi
dpi!(::Report, ::Int64)
filename!(::ReportPlot, ::String)
filename(::ReportPlot)
fontfamily!
fontfamily
generalrep
generate
glossary!
glossary
inputfilesrep
memory_sec
modelconfigrep
observationsummaryrep(::ResultData)
pathogensrep
plotpackage(::PlotSection)
plt
population_pyramid_rep(::BatchData)
population_pyramid_sec(::BatchData)
processor_sec(::ResultData)
reportdata(::Report)
repository_sec(::ResultData)
resourcesrep(::BatchData)
runtime_sec(::BatchData)
savepath(::String)
sections(::Report)
setting_age_contacts_rep
setting_age_contacts_sec
settingrep
simoverviewrep
subsections(::Section)
subtitle!(::Report, ::String)
subtitle(::Report)
sysinformationsec
sys_information_sec
title!
title
vaccinationrep(::ResultData)
varied_parameters_sec
```