# this file defines constant global variables used throughout the GEMS package

# !!! for the LookUp Table of Terminal states, see structs/parameters/age_strat.jl !!! #

##################
# DEFAULT VALUES #
##################
const DEFAULT_SETTING_ID = Int32(-1)
const DEFAULT_PATHOGEN_ID = Int8(-1)
const DEFAULT_VACCINE_ID = Int8(-1)
const DEFAULT_TICK = Int16(-1)
const DEFAULT_INFECTION_ID = Int32(-1)
const DEFAULT_AGS = Int32(-1)
const GLOBAL_SETTING_ID = Int32(1)

#################
# DATA ANALYSIS #
#################


# number of contacts to be sampled to form the ageXage-contact matrices
const CONTACT_SAMPLES = 100_000

# time-window in ticks used to filter detected infections
# that inform the (empirical) serial interval estimation function
# e.g. "14" would suggest that the "current" serial interval
# is estimated based on all (detected) infections of the
# last 14 ticks
const SI_ESTIMATION_TIME_WINDOW = 14

# minimum number of infections that is used to estimate
# the current serial interval. If the time window (s. above)
# does not yield enough data points, the time window will be
# broadend with respect to it's start date until at least 
# 50 infections are found (or tick = 1) was reached
const SI_ESTIMATION_CASE_THRESHOLD = 50

# time-window in ticks used to accumulate (detected)
# infections. This is used to calculate the (empirical)
# effective R estimation according to Cori et al. 2013 (RKI method)
const R_ESTIMATION_TIME_WINDOW = 7

# minimum number of infections that must be present in 
# a 7-tick time window in order to calculate R.
# This prevents that R is being calculated with too
# few data points causing irritating (and large)
# fluctuations in the graphs
const R_CALCULATION_THRESHOLD = 10

# number of households that the attack rate
# is calculated for in the post post processor
# (limit for performance reasons)
const HOUSEHOLD_ATTACK_RATE_SAMPLES = 15_000


#################
# LOOKUP VALUES #
#################

# sex
const FEMALE = Int8(1)
const MALE = Int8(2)

# hospital_status
const HOSPITAL_STATUS_NO_HOSPITAL = Int8(0)
const HOSPITAL_STATUS_HOSPITALIZED = Int8(1)
const HOSPITAL_STATUS_VENTILATION = Int8(2)
const HOSPITAL_STATUS_ICU = Int8(3)

# disease_state
const DISEASE_STATE_NOT_INFECTED = Int8(0)
const DISEASE_STATE_PRESYMPTOMATIC = Int8(1)
const DISEASE_STATE_SYMPTOMATIC = Int8(2)
const DISEASE_STATE_SEVERE = Int8(3)
const DISEASE_STATE_CRITICAL = Int8(4)

# SYMPTOM_CATEGORY
const SYMPTOM_CATEGORY_NOT_INFECTED = Int8(0)
const SYMPTOM_CATEGORY_ASYMPTOMATIC = Int8(1)
const SYMPTOM_CATEGORY_MILD = Int8(2)
const SYMPTOM_CATEGORY_SEVERE = Int8(3)
const SYMPTOM_CATEGORY_CRITICAL = Int8(4)

const SYMPTOM_CATEGORIES = Dict(
    0 => "Not Infected",
    1 => "Asymptomatic",
    2 => "Mild",
    3 => "Severe",
    4 => "Critical"
)

# quarantine_status
const QUARANTINE_STATE_NO_QUARANTINE = Int8(0)
const QUARANTINE_STATE_HOUSEHOLD_QUARANTINE = Int8(1)
const QUARANTINE_STATE_HOSPITAL = Int8(2)


##########################
# VISUALIZATION DEFAULTS #
##########################

const MAP_PADDING = 0.05 # Outer spacing added to maps depending on the maximum range of lat/lon values
const MAX_MAP_POINTS = Int64(1_000_000) # maximum points to show on a geographical map

# Total maximum points to show on a geographical map in a video over the full duration
# This does not refer to the points shown simultaneously but rather over the entire video period
const MAX_MAP_POINTS_VIDEO = Int64(2_000_000)

# some plots require a minimum data input to generate an image. The threshold is stored here
const MIN_INFECTIONS_FOR_PLOTS = 5

###################
# SYSTEM DEFAULTS #
###################

const TEMP_FOLDER_PATH = BASE_FOLDER = joinpath(dirname(dirname(pathof(GEMS))), "temp")
const LOCALDATA_PATH = BASE_FOLDER = joinpath(dirname(dirname(pathof(GEMS))), "localdata")

#Default Config File
const DEFAULT_CONFIGFILE::String = "data/DefaultConf.toml"

# remote location of population files (ZIP)
const popurl(identifier::String) = "https://uni-muenster.sciebo.de/s/SoogCFyijz4ctBA/download?path=%2F&files=$identifier.zip"
# local location of population and setting files (JLD2)
const poplocal(identifier::String) = joinpath(LOCALDATA_PATH, identifier)
const peoplelocal(identifier::String) = joinpath(poplocal(identifier), "people_$identifier.jld2")
const settingslocal(identifier::String) = joinpath(poplocal(identifier), "settings_$identifier.jld2")

# local location of shapefile (obtained from here: https://gdz.bkg.bund.de/index.php/default/verwaltungsgebiete-1-250-000-mit-einwohnerzahlen-stand-31-12-vg250-ew-31-12.html) (first download link)
const SHAPEFILE_FOLDER_PATH = joinpath(LOCALDATA_PATH, "shapefiles")
const GERMAN_SHAPEFILE(identifier::String) = joinpath(SHAPEFILE_FOLDER_PATH, "vg250-ew_12-31.gk3.shape.ebenen", "vg250-ew_ebenen_1231", "VG250_$identifier.shp")
const GERMAN_SHAPEFILE_URL = "https://daten.gdz.bkg.bund.de/produkte/vg/vg250-ew_ebenen_1231/aktuell/vg250-ew_12-31.gk3.shape.ebenen.zip"

########################
# PERFORMANCE SETTINGS #
########################

# if "true", post processing steps (e.g. calculating effective R, generating age-age matrices, etc...)
# will be done concurrently rather than sequentially. However, be aware, that these data processing
# operations require substantial amounts of system memory and might overburden the system when done 
# in parallel. If memory is a bottleneck, this will cause dramatic performance issues.
# Please only set this "true" if you are sure to have enough memory available.
PARALLEL_POST_PROCESSING = false

# if "true" the post processor stores result dataframes from individual function
# calls to speed up subsequent steps. However, be aware for large models, these
# intermediate dataframes can be excessive and a severe strain on system memory.
# Please only set this "true" if you are sure to have enough memory available.
POST_PROCESSOR_CACHING = true

# if "true", report sections will be generated in parallel. While this speeds up
# the generation process significantly, it requires more system memory which might
# become a bottleneck. Please only set this "true" if you are sure to have enough
# memory available.
PARALLEL_REPORT_GENERATION = false