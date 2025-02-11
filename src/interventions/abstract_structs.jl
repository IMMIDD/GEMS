export AbstractTestType
export Maesure, IMeasure, SMeasure, CMeasure
export Strategy
export InterventionTrigger, ITrigger, STrigger
export Event

###
### TESTING
###

abstract type AbstractTestType end

###
### MEASURES
###

abstract type Measure end

abstract type IMeasure <: Measure end

abstract type SMeasure <: Measure end

abstract type CMeasure <: Measure end

###
### STRATEGIES
###

abstract type Strategy end

###
### TRIGGERS
###

abstract type InterventionTrigger end

# abstract tick trigger type
abstract type TickTrigger <: InterventionTrigger end

# abstract individual trigger
abstract type ITrigger <: InterventionTrigger end

# abstract setting trigger
abstract type STrigger <: InterventionTrigger end

###
### EVENTS
###

abstract type Event end