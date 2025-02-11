export Runinfo
export data

"""
    Runinfo

An immutable struct providing information on a given run (instance) of the simulation.
The main function stores this data into the result output directory (as TOML).
The internal data structure is a Dict to facilitate TOML-conversion.
Currently containing:
  - date
  - configfile
  - populationfile
"""
struct Runinfo
    
    data::Dict

Runinfo(date::DateTime, configfile::String, populationfile::String, settingfile::String) = 
    new(Dict(
        "date" => date,
        "configfile" => configfile,
        "populationfile" => populationfile,
        "settingfile" => settingfile
    ))
end


"""
    data(runinfo)

Returns data Dict from a `Runinfo` object.
"""
function data(runinfo::Runinfo)
    return(runinfo.data)
end