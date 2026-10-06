package.path = './?.lua;' .. package.path
local loads, id = 0, 'car_a'
local function lut(slope)
 return {get=function(_,distance) return 100-distance*slope end,
  getPointInput=function(_,i) return i*100 end,
  getPointOutput=function(_,i) return 100-i*100*slope end}
end
local data={FRONT=lut(0.1),REAR=lut(0.2),FRONT_1=lut(0.05)}
ac={getCarID=function() return id end,INIConfig={carData=function()
 loads=loads+1
 return {tryGetLut=function(_,section,key) assert(key=='WEAR_CURVE'); return data[section] end}
end}}
local Grip=require('src/tyre_grip')
local car={index=0,compoundIndex=0,wheels={}}
for i=0,3 do car.wheels[i]={tyreVirtualKM=i+1,tyreWear=0} end
assert(math.abs(Grip.average(car)-95.75)<0.001,'mean must evaluate each axle at CMRT virtual distance')
local profile=assert(Grip.snapshot(car,{tyreConsumptionRate=1,trackLengthM=5000}))
assert(profile.details[1].km==0 and profile.details[1].laps==0, 'the 100% grip point must retain the zero-distance curve origin')
Grip.average(car); assert(loads==1)
car.wheels[3].tyreVirtualKM=nil
assert(Grip.average(car)==nil,'one missing wheel makes grip unavailable')
car.wheels[3].tyreVirtualKM=0
assert(math.abs(Grip.average(car)-97.75)<0.001,'replacement tyres must evaluate fresh distance')
car.compoundIndex=1
assert(Grip.average(car)==nil,'missing rear curve must not borrow front')
car.compoundIndex=0
assert(Grip.average(car) and loads==2,'cache must survive compound switches')
id='car_b'; Grip.average(car); assert(loads==3)
car.compoundIndex=nil; assert(Grip.average(car)==nil)
car.compoundIndex=0; car.wheels[0].tyreVirtualKM=math.huge
assert(Grip.average(car)==nil)
car.wheels[0].tyreVirtualKM=0/0; assert(Grip.average(car)==nil)
car.wheels[0].tyreVirtualKM=1
id='blocked'; ac.INIConfig.carData=function() error('packed data unavailable') end
assert(Grip.average(car)==nil)
id='integration'
ac.INIConfig.carData=function()
 return {tryGetLut=function(_,section,key) return key=='WEAR_CURVE' and data[section] or nil end}
end
ac.getSim=function() return {} end
ac.getCar=function() return car end
ui={time=function() return 0 end}
local Telemetry=require('src/telemetry')
local state=Telemetry.new()
local opts={speedUnit='km/h',fallbackRpm=8000,rpmWarningFraction=0.8,rpmRedlineFraction=0.95,instrumentMode='digital'}
Telemetry.update(state,1/60,opts)
assert(math.abs(state.condition.grip-97.75)<0.001)
car.wheels[2].tyreVirtualKM=nil
Telemetry.update(state,1/60,opts)
assert(state.condition.grip==nil,'missing samples must clear previous grip')
ac.getCar=function() return nil end
Telemetry.update(state,1/60,opts)
assert(state.condition.grip==nil and not state.condition.available)
-- Settings migration uses a sentinel so legacy false is distinguishable from a new install.
for _,legacy in ipairs({'default','visible','hidden','grip'}) do
 local stored={}
 if legacy=='hidden' then stored.showTemperatureLegend=false end
 if legacy=='visible' then stored.showTemperatureLegend=true end
 if legacy=='grip' then stored.legendMode='grip'; stored.showTemperatureLegend=false end
 ac.storage=function(defaults,prefix)
  if prefix~='retro-ui.condition.' then return defaults end
  for k,v in pairs(defaults) do if stored[k]==nil then stored[k]=v end end
  return stored
 end
 local settings=assert(loadfile('src/condition_settings.lua'))()
 local expected=legacy=='hidden' and 'none' or legacy=='grip' and 'grip' or 'temperature'
 assert(settings.values.legendMode==expected)
 settings.setLegendMode('grip')
 assert(assert(loadfile('src/condition_settings.lua'))().values.legendMode=='grip')
end
print('Tyre grip: axle curves, arithmetic mean, missing wheels, compounds, replacements, cache and migration passed')
