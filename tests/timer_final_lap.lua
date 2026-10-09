package.path='./?.lua;'..package.path
ui={time=function() return 1 end}
local sim={currentSessionIndex=0,isLive=true,sessionTimeLeft=1000}
local session={type=1,isTimedRace=true,hasAdditionalLap=false}
local player={index=0,lapCount=2,splinePosition=0.5,racePosition=2}
local rival={index=1,lapCount=3,splinePosition=0.8,racePosition=1}
local cars={player,rival}
ac={SessionType={Race=1},FlagType={OneLapLeft=14,Finished=13},
 getSim=function() return sim end,getSession=function() return session end,
 getCar=function(i) return cars[i+1] end,iterateCars=function() return ipairs(cars) end,
 getTrackFullID=function() return 'test' end,getTrackName=function() return 'test' end}
local State=require('modules/timer/src/state')
local function new(extra)
 sim.sessionTimeLeft=1000; sim.currentSessionIndex=0; sim.raceFlagType=nil
 sim.isReplayActive=false; sim.isSessionFinished=false; sim.replayCurrentFrame=nil
 sim.leaderLastLap=nil; sim.timeRaceLastLap=nil; sim.raceSessionType=nil; sim.isTimedRace=nil
 session.isTimedRace=true; session.hasAdditionalLap=extra; session.laps=nil
 player.lapCount=2; player.racePosition=2; player.splinePosition=0.5
 rival.lapCount=3; rival.racePosition=1; rival.splinePosition=0.8
 local state=State.new({freezeDuration=3}); assert(state:update()); return state
end
local function final(state,expected,message)
 assert(state:update()); assert(state:snapshot().finalLap==expected,message)
end
local timer=new(false)
final(timer,false,'positive milliseconds must not imply expiration')
sim.sessionTimeLeft=0; final(timer,true,'zero must start final lap without an extra lap')
sim.sessionTimeLeft=-1; sim.raceFlagType=1; final(timer,true,'last lap must remain latched')
sim.sessionTimeLeft=nil; final(timer,true,'missing countdown must not clear the latch')
sim.raceFlagType=13; final(timer,false,'finish clears the notice')

timer=new(true)
sim.sessionTimeLeft=0; final(timer,false,'extra lap must wait for the leader crossing')
player.lapCount=3; player.splinePosition=0.01
final(timer,false,'player crossing is not the overall leader crossing')
rival.splinePosition=0.01
final(timer,true,'spline crossing starts extra final lap before counter update')
rival.lapCount=4; final(timer,true,'later counter update must retain the notice')
sim.raceFlagType=1; sim.sessionTimeLeft=-10000; final(timer,true,'negative countdown keeps final lap')
sim.isSessionFinished=true; final(timer,false,'session completion clears final lap')

timer=new(true)
sim.sessionTimeLeft=-1; final(timer,false)
sim.sessionTimeLeft=nil; rival.lapCount=4; final(timer,true,'expiry survives a missing countdown at the crossing')

-- A delayed counter for a crossing before expiry must not start the extra lap.
timer=new(true)
rival.splinePosition=0.01; final(timer,false)
sim.sessionTimeLeft=0; rival.lapCount=4
final(timer,false,'delayed counter must not count the earlier spline crossing twice')
rival.splinePosition=0.9; final(timer,false)
rival.splinePosition=0.01; final(timer,true)
-- Likewise, a delayed spline for a counter crossing before expiry is one crossing.
timer=new(true)
rival.lapCount=4; final(timer,false)
sim.sessionTimeLeft=0; rival.splinePosition=0.01
final(timer,false,'delayed spline must not duplicate the earlier counter crossing')
rival.splinePosition=0.9; final(timer,false)
rival.lapCount=5; rival.splinePosition=0.01; final(timer,true)

timer=new(true)
sim.raceFlagType=14; final(timer,true,'official flag takes precedence with positive time and extra lap')
sim.raceFlagType=nil; final(timer,true,'official last lap remains latched')
sim.currentSessionIndex=1; final(timer,false,'new session clears final lap')

timer=new(true)
sim.sessionTimeLeft=-1000; final(timer,false)
player.racePosition=1; rival.racePosition=2
final(timer,false,'leader changes must not invent a crossing from another car counter')
player.lapCount=3; final(timer,true,'new overall leader crossing must start final lap')
player.lapCount=0; sim.sessionTimeLeft=60000
final(timer,false,'same-index restart clears the latch')

timer=new(false)
sim.isReplayActive=true; sim.isLive=false; sim.replayCurrentFrame=100
sim.sessionTimeLeft=0; final(timer,true)
sim.replayCurrentFrame=99; sim.sessionTimeLeft=1000
final(timer,false,'rewinding a replay within the same lap must clear final lap')

timer=new(true)
session.isTimedRace=false; session.laps=3
final(timer,true,'fixed lap races retain their detection')
sim.raceFlagType=13; final(timer,false)
timer=new(true)
sim.raceFlagType=1; sim.leaderLastLap=true
final(timer,true,'native leaderLastLap overrides green flag and additional-lap fallback')
sim.leaderLastLap=false; final(timer,true,'native last-lap notice stays latched')
sim.raceFlagType=13; final(timer,false,'finish clears a native last-lap notice')

timer=new(true)
sim.raceFlagType=2; sim.timeRaceLastLap=true
final(timer,true,'native timeRaceLastLap must show during a caution with time remaining')

timer=new(true)
local getSession=ac.getSession
ac.getSession=function() return nil end
sim.raceSessionType=ac.SessionType.Race; sim.isTimedRace=true; sim.timeRaceLastLap=true
final(timer,true,'native race state works without session metadata')
ac.getSession=getSession
print('Timer final lap: timed/fixed races, native AC last-lap signals, official flags, zero/negative time, extra laps, leaders, finish, restart and replay rewind passed')
