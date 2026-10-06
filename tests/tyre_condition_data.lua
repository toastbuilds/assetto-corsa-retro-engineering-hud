package.path = './?.lua;./?/init.lua;' .. package.path
local sim={currentSessionIndex=0,trackLengthM=5000,isPaused=false,time=0}
local car={index=0,compoundIndex=0,lapCount=0,splinePosition=0.3,distanceDrivenSessionKm=0,
  resetCounter=0,isInPitlane=false,wheels={}}
for i=0,3 do car.wheels[i]={tyrePressure=27,tyreWear=0,tyreVirtualKM=0,
  tyreCoreTemperature=80,tyreInsideTemperature=75,tyreMiddleTemperature=80,tyreOutsideTemperature=85} end
ac={getSim=function() return sim end,getCar=function() return car end,
  getCarID=function() return 'test_gt3' end,getTyresLongName=function() return 'Medium' end,
  INIConfig={carData=function() return {
    get=function(_,section,key,default)
      if key=='PRESSURE_IDEAL' then
        if section=='FRONT' then return 26 elseif section=='REAR' then return 27 end
      end
      return default
    end,
    tryGetLut=function() return nil end
  } end}}
local Telemetry=require('src/telemetry')
local state=Telemetry.new()
local settings={speedUnit='km/h',fallbackRpm=8000,rpmWarningFraction=0.8,rpmRedlineFraction=0.95}
local function update(dt)
  sim.time=sim.time+dt*1000
  Telemetry.update(state,dt,settings)
end
update(1/60)
assert(state.condition.wheels[1].pressure==27 and state.condition.wheels[1].idealPressure==26
  and state.condition.wheels[4].idealPressure==27)
assert(state.condition.compound=='Medium' and state.condition.isGT3)
car.isInPitlane=true
update(1)
assert(state.condition.detailOpen and state.condition.detailAfterPit==10)
car.isInPitlane=false
update(1)
assert(state.condition.detailOpen and state.condition.detailAfterPit==9)
sim.isPaused=true
update(5)
assert(state.condition.detailAfterPit==9, 'pause must not consume the pit detail timeout')
sim.isPaused=false
update(9)
assert(not state.condition.detailOpen, 'pit detail closes ten simulated seconds after exit')
car.compoundIndex=1
update(1/60)
assert(state.condition.wheels[1].idealPressure==nil, 'new compound must clear the previous ideal pressure')
car.wheels[0].tyrePressure=0/0
update(1/60)
assert(state.condition.wheels[1].pressure==nil, 'invalid measurement must clear stale pressure')
car.wheels[1]=nil
update(1/60)
assert(state.condition.wheels[2].pressure==nil and state.condition.wheels[2].idealPressure==nil)
ac.getCar=function() return nil end
update(1/60)
assert(not state.condition.available and state.condition.stint==nil
  and state.condition.wheels[4].pressure==nil and not state.condition.detailOpen)
print('Condition telemetry: per-axle pressure references, compound invalidation, pit timers, pause and disconnect passed')
