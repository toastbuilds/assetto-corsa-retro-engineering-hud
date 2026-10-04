package.path = './?.lua;' .. package.path
ac = { SessionType = {Race=1} }
local Session = require('modules/leaderboard/src/session')
local session = {type=1,isTimedRace=true,hasAdditionalLap=false}
local sim = {sessionTimeLeft=90000}
local leader = {lapCount=3,bestLapTimeMs=90000}
local localRow = {lapCount=2}
assert(Session.lapHeader(session,sim,leader,60000,true)=='LAPS: ~4')
leader.bestLapTimeMs=45000
assert(Session.lapHeader(session,sim,leader,60000,true)=='LAPS: ~5')
leader.bestLapTimeMs=0
assert(Session.lapHeader(session,sim,leader,60000,true)=='LAPS: --')
assert(Session.lapsRemaining(session,sim,localRow,leader,60000)==nil)
leader.bestLapTimeMs=90000
for _,ms in ipairs({90000,1000,0,-1000,7200000}) do
  assert(Session.timeLeftSeconds({sessionTimeLeft=ms},nil)==ms/1000)
end
session.hasAdditionalLap=true
assert(Session.lapsRemaining(session,sim,localRow,leader,60000)==2)
session.isTimedRace=false; session.laps=10
assert(Session.lapsRemaining(session,sim,localRow,leader,60000)==8)
assert(Session.lapHeader(session,sim,leader,nil,true)=='LAPS: 10')
local Fuel = require('modules/leaderboard/src/fuel')
ui = {time=function() return 1 end}
local car = {fuel=30,maxFuel=100,lapCount=0,isLastLapValid=true,previousLapTimeMs=90000}
ac.getCar=function() return car end
local state = Fuel.new()
local snap = {sim={currentSessionIndex=0},lapsRemaining=2}
Fuel.update(state,snap,{fuelReserve=1})
car.fuel=27; Fuel.update(state,snap,{fuelReserve=1})
car.lapCount=1; Fuel.update(state,snap,{fuelReserve=1})
assert(state.average==3 and state.fuelNeeded==7)
snap.lapsRemaining=nil; Fuel.update(state,snap,{fuelReserve=1})
assert(not state.finishAvailable and state.finishText=='--')
car.lapCount=0; Fuel.update(state,snap,{fuelReserve=1})
assert(state.average==nil, "same-session rewind must clear fuel samples")
snap.sim.currentSessionIndex=1; Fuel.update(state,snap,{fuelReserve=1})
assert(state.average==nil)
-- Reuse the instrument drawing doubles for the real leaderboard header.
dofile('tests/runtime_smoke.lua')
local Display = require('modules/leaderboard/ui/leaderboard')
local Theme = require('modules/leaderboard/src/theme')
ui.pushClipRect=function() end
ui.popClipRect=function() end
local texts={}
ui.dwriteDrawText=function(value,size,pos) texts[#texts+1]={value=value,size=size,pos=pos} end
ui.measureDWriteText=function(value,size) return vec2(#value*size*0.6,size*1.35) end
for _,theme in ipairs({'dark','light'}) do
 for _,scale in ipairs({0.55,1.25}) do
  ui.windowWidth=function() return 1040*scale end
  ui.windowHeight=function() return 470*scale end
  for _,flags in ipairs({false,true}) do
   texts={}
   Display.draw({header={lapsText='LAPS: ~123',timeText='12:34'},shownRows={},enteredAt=0,
    fuel={available=true,fuelText='123.4 L',averageText='12.3 L/LAP',estimatedLapsText='123 LAPS'}},
    {hudScale=scale,showFlags=flags},{palette=Theme.get(theme),instrumentOpacity=0.7})
   local values=0
   for _,t in ipairs(texts) do
    assert(not t.value:find('AIR') and not t.value:find('TARMAC'))
    local m=ui.measureDWriteText(t.value,t.size)
    assert(t.pos.x>=0 and t.pos.x+m.x<=1040*scale+0.01)
    if t.value=='123.4 L' or t.value=='12.3 L/LAP' or t.value=='123 LAPS' then
     assert(t.size==24*scale); values=values+1
    end
   end
   assert(values==3)
  end
 end
end
print('Leaderboard: leader references, missing times, countdown, fuel, reset and 8 header drawings passed')
