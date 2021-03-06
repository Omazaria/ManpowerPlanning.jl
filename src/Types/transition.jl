# This file defines the Transition type. This type defines a transition between
#   states that a personnel member can make.

# The Tansition type requires the State type.
requiredTypes = [ "state" ]

for reqType in requiredTypes
    if !isdefined( Symbol( uppercase( string( reqType[ 1 ] ) ) * reqType[ 2:end ] ) )
        include( joinpath( typePath, reqType * ".jl" ) )
    end  # if !isdefined( Symbol( ...
end  # for reqType in requiredTypes


export Transition
"""
This type defines a transition between two states that a personnel member can
perform, along with all the necessary information  about the conditions of the
transition.

The type contains the following fields:
* `name::string`: the name of the transition.
* `startState::State`: the state that the personnel member is currently in.
* `endState::State`: the state that the personnel member can attain.
* `freq::Float64`: the time between two checks in the transition's schedule.
* `offset::Float64`: the offset of the transition's schedule with respect to the
  start of the simulation.
* `extraConditions::Vector{Condition}`: the extra conditions that must be
  satisfied before the transition can take place.
* `extraChanges::Vector{PersonnelAttribute}`: the extra changes to attributes
  that happen during the transition.
* `probabilityList::Vector{Float64}`: the list of probabilities for this
  transition to occur.
* `maxAttempts::Int`: the maximum number of tries a personnel member has to
  undergo the transition.
* `timeBetweenAttempts::Float64`: the minimum time between two successive
  attempts.
* `isFiredOnFail::Bool`: a flag indicating that the personnel member gets fired
  if he fails to make the transition in the provided number of attempts.
* `maxFlux::Int`: the maximum number of people that can undergo the transition
  at the same time.
* `hasPriority::Bool`: a flag indicating that this transition can override the
  target population of the transition's target state. If the flag is `true`, it
  means that if the max flux of the state is 15, and only 10 spots are available
  in the target state, 15 people will undergo the transition nonetheless. If the
  flag is `false`, 10 persons would.
* `transPriority::Int`: the priority in the simulation on which the transition
  gets executed. This priority will be 0 for transitions with the `hasPriority`
  flag set to `true`, and < 0 otherwise. A priority == 1 means it needs to be
  determined first.
"""
type Transition

    name::String
    startState::State
    endState::State
    freq::Float64
    offset::Float64
    extraConditions::Vector{Condition}
    extraChanges::Vector{PersonnelAttribute}
    probabilityList::Vector{Float64}
    maxAttempts::Int
    timeBetweenAttempts::Float64
    isFiredOnFail::Bool
    maxFlux::Int
    hasPriority::Bool
    transPriority::Int

    # Basic constructor.
    function Transition( name::String, startState::State, endState::State;
        freq::T1 = 1.0, offset::T2 = 0.0, minTime::T3 = 1.0,
        maxAttempts::T4 = 1, maxFlux::T5 = -1, isFiredOnFail::Bool = false ) where T1 <: Real where T2 <: Real where T3 <: Real where T4 <: Integer where T5 <: Integer

        if freq <= 0.0
            error( "Time between two transition checks must be > 0.0" )
        end  # if freq <= 0.0

        if minTime <= 0.0
            error( "Time that personnel member must have initial state must be > 0.0" )
        end  # if minTime <= 0.0

        if maxAttempts < -1
            error( "Maximum number of attempts must be => -1, where -1 stands for infinite" )
        end  # if maxAttempts < -1

        if maxFlux < -1
            error( "Maximum flux must be => -1, where -1 stands for infinite" )
        end

        newTrans = new()
        newTrans.name = name
        newTrans.startState = startState
        newTrans.endState = endState
        newTrans.freq = freq
        newTrans.offset = offset % freq + ( offset < 0.0 ? freq : 0.0 )
        newTrans.extraConditions = Vector{Condition}()
        newTrans.extraChanges = Vector{PersonnelAttribute}()
        newTrans.probabilityList = [ 1.0 ]
        newTrans.maxAttempts = maxAttempts
        newTrans.timeBetweenAttempts = 0.0
        newTrans.isFiredOnFail = isFiredOnFail
        newTrans.maxFlux = -1
        newTrans.hasPriority = false
        newTrans.transPriority = 1
        return newTrans

    end  # Transition( name, startState, endState; freq, offset, minTime )

end  # type Transition
