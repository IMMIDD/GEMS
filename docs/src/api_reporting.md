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
description!(::ReportPlot, ::String)
description(::ReportPlot)
dpi
dpi!(::Report, ::Int64)
filename!(::ReportPlot, ::String)
filename(::ReportPlot)
fontfamily!
fontfamily
generate(::Report, ::AbstractString)
glossary!
glossary
plotpackage(::PlotSection)
plt
reportdata(::Report)
savepath(::String)
sections(::Report)
subsections(::Section)
subtitle!(::Report, ::String)
subtitle(::Report)
title!
title
```