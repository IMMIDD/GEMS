export AGS
export state, district, county, municipality, is_state, is_district, is_county, in_state, in_district, in_county, id, isunset

"""
    AGS

Struct to represent Germany's Community Identification Number (Amtlicher Gemeindeschlüssel).

Taken from Wikipedia (https://en.wikipedia.org/wiki/Community\\_Identification\\_Number):

The municipality key consists of eight digits, which are generated as follows:
The **first two digits** designate the individual German state. The **third digit** designates
the government district (in areas without government districts a zero is used instead).
The **fourth and fifth digits** designate the number of the urban area (in a district-free city)
or the district (in a city with districts). In GEMS they are called 'counties'.
The **sixth, seventh, and eighth digits** indicate the municipality or the number of the unincorporated area.

# Example

```
münster = AGS("05515000")
```

The above code generates the community identification number for the city of Münster.
- The first two digits identify the state of North Rhine-Westphalia (05)
- The third digit identifies the government district Münster (5)
- The fourth and fifth digit identify the district-free city of Münster (15)

Being a district-free city, Münster does not have a municipality code.
Examples for municipalities are: Emsdetten (05566008), Warendorf (05570052), or 
Steinfurt (05566084).

There are multiple helper functions to navigate through the hierarchical
AGS structure such as: `state`, `district`, `county`, or `municiaplity`
which each return the `AGS` of the respective geographic level. The
`is_state`, `is_district`, and `is_county` return true, if the provided
`AGS` is on the respective geographic level. Moreover, `in_state`, 
`in_district`, and `in_county` verify whether a provided `AGS` is
contained in a parent region.

`AGS` are directly comparable (`==`) and broadcastable (`.==`).

# Note:
There is no `is_municiaplity` function as this could be confused as a 
check wether the AGS is on the lowest geographic level. However, as there
are district-free cities which are technically municipalities but without
the last three digits given, this check could only be done with context
information on the actual region. Based purely on the number, we do not
know which county has contains municipalites and which conty is a 
district-free city.

"""
struct AGS
    id::Int32

    function AGS(ags_int::Int)
        if !(0 < ags_int ÷ 10^6 <= 16)
            throw("The state (first two digits) must be between 1 and 16")
        else
            return new(Int32(ags_int))
        end
    end

    function AGS(ags_int::Int32)
        if !(0 < ags_int ÷ 10^6 <= 16)
            throw("The state (first two digits) must be between 1 and 16")
        else
            return new(ags_int)
        end
    end

    function AGS(ags_string::String)
        if !occursin(r"^\d{8}$", ags_string)
            throw("The AGS (Amtlicher Gemeindeschlüssel, eng: Community Identification Number) must consist of exactly 8 digits")
        else
            return AGS(parse(Int, ags_string))
        end
    end

    function AGS()
        return new(DEFAULT_AGS)
    end
end


"""
    id(ags::AGS)

Retuns the `AGS`s internal number (int).
"""
function id(ags::AGS)
    return ags.id
end

"""
    state(ags::AGS) 

Returns the parent state's Community Identification Number (AGS) of the provided `AGS`.
"""
function state(ags::AGS) 
    AGS(ags.id ÷ 10^6 * 10^6)
end

"""
    district(ags::AGS) 

Returns the parent district's Community Identification Number (AGS) of the provided `AGS`.
"""
function district(ags::AGS) 
    return AGS(ags.id ÷ 10^5 * 10^5) 
end

"""
    county(ags::AGS) 

Returns the parent county's Community Identification Number (AGS) of the provided `AGS`.
"""
function county(ags::AGS) 
    return AGS(ags.id ÷ 10^3 * 10^3)
end

"""
    municipality(ags::AGS) 

Returns the Community Identification Number (AGS) regardless of its geographic level.
"""
function municipality(ags::AGS) 
    return ags
end

"""
    is_state(ags::AGS) 

Returns true if the Community Identification Number (AGS) belongs to a state.
_First two digits given, everything else being 0s._
"""
function is_state(ags::AGS) 
    return ags.id % 10^6 == 0
end

"""
    is_district(ags::AGS) 

Returns true if the Community Identification Number (AGS) belongs to a governmental district.
_First three digits given, everything else being 0s._
"""
function is_district(ags::AGS)
    return ags.id % 10^5 == 0 && ags.id ÷ 10^5 % 10^1 != 0
end

"""
    is_district(ags::AGS) 

Returns true if the Community Identification Number (AGS) belongs to a conty.
_First five digits given, last three being 0s._
"""
function is_county(ags::AGS)
    return ags.id % 10^3 == 0 && ags.id ÷ 10^3 % 10^2 != 0
end

"""
    in_state(ags::AGS, parent::AGS) 

Returns true if the *state*-section of both
Community Identification Numbers (AGS) match. 
Both AGSs are in the same state.
"""
function in_state(ags::AGS, parent::AGS) 
    return state(ags) == state(parent)
end

"""
    in_district(ags::AGS, parent::AGS) 

Returns true if the *district*-section of both
Community Identification Numbers (AGS) match.
Both AGSs are in the same district. 
"""
function in_district(ags::AGS, parent::AGS)
    return district(ags) == district(parent)
end

"""
    in_county(ags::AGS, parent::AGS) 

Returns true if the *county*-section of both
Community Identification Numbers (AGS) match.
Both AGSs are in the same county. 
"""
function in_county(ags::AGS, parent::AGS) 
    return county(ags) == county(parent)
end

"""
    isunset(ags::AGS)

Returns `true` if the `AGS` is the "empty" default and does not 
actually belongs to a any geographic region.
"""
isunset(ags::AGS) = ags.id == DEFAULT_AGS

# making AGS comparison broadcastable
Base.:(==)(ags1::AGS, ags2::AGS) = ags1.id == ags2.id
Base.broadcastable(ags::AGS) = Ref(ags)

###
### PRINTING
###

function Base.show(io::IO, ags::AGS)
    print(io,"AGS{$(repeat("0", 8 - (ags.id |> string |> length)))$(ags.id)}")
end