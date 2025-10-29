"""
    ConfigfileError <: Exception

An exception type for errors related to configfile loading and parsing.
"""
struct ConfigfileError <: Exception
    msg::String
    cause::String

    ConfigfileError(msg::String) = new(msg, "")
    ConfigfileError(msg::String, cause::Exception) = new(msg, sprint(showerror, cause))
    ConfigfileError(msg::String, cause::String) = new(msg, cause)

end

Base.showerror(io::IO, e::ConfigfileError) =
    e.cause == "" ? print(io, "ConfigfileError: $(e.msg)") : print(io, "ConfigfileError: $(e.msg) $(e.cause)")