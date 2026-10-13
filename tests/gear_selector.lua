package.path='./?.lua;./?/init.lua;'..package.path
local Selector=require('src/gear_selector')
local function close(a,b) assert(math.abs(a-b)<0.000001,tostring(a)..' ~= '..tostring(b)) end
local state={}
Selector.observe(state,5,3,'five-speed')
assert(state.gearCount==5 and state.gearCountSource=='car')
Selector.observe(state,nil,7,'seven-speed')
assert(state.gearCount==7 and state.gearCountSource=='observed')
Selector.observe(state,nil,2,'seven-speed')
assert(state.gearCount==7,'observed gears must not disappear on a downshift')
Selector.observe(state,nil,1,'another-car')
assert(state.gearCount==6 and state.gearCountSource=='fallback')
for _,value in ipairs({0,-1,0/0,math.huge,5.5,100}) do
  assert(Selector.count(value)==6,'invalid physics counts use six forward gears')
end
assert(Selector.angle(0,6)==nil and Selector.angle(nil,6)==nil)
local animation,angle=Selector.sample(nil,2,6,0,true,'car')
close(angle,Selector.angle(2,6))
animation,angle=Selector.sample(animation,3,6,0.01,true,'car')
local from=angle
animation,angle=Selector.sample(animation,3,6,0.07,true,'car')
assert(angle>from and angle<=Selector.angle(3,6)+2)
local interrupted=angle
animation,angle=Selector.sample(animation,4,6,0.07,true,'car')
close(angle,interrupted)
animation,angle=Selector.sample(animation,4,6,0.17,true,'car')
assert(angle>Selector.angle(4,6) and angle-Selector.angle(4,6)<2,'the mechanical rebound stays restrained')
animation,angle=Selector.sample(animation,4,6,0.19,true,'car')
close(angle,Selector.angle(4,6))
animation,angle=Selector.sample(animation,0,6,0.20,true,'car')
close(angle,Selector.angle(4,6))
animation,angle=Selector.sample(animation,-1,6,0.21,false,'car')
close(angle,Selector.angle(-1,6))
animation,angle=Selector.sample(animation,6,6,0.22,true,'new-car')
close(angle,Selector.angle(6,6))
animation,angle=Selector.sample(animation,1,6,0,true,'new-car')
close(angle,Selector.angle(1,6))
animation,angle=Selector.sample(animation,5,6,1,true,'new-car')
close(angle,Selector.angle(5,6))
assert(Selector.angle(-1,6)<Selector.angle(1,6) and Selector.angle(6,6)<0,
  'all gear marks follow the upper arc in left-to-right order')

local cueState={available=true,gearText='3',gearCount=6,rpmDisplayLimiter=8000,
  rpmRedlineFraction=0.96,rpm=7833}
assert(Selector.shiftCue(cueState)==nil,'upshift cue stays off below 2% above configured redline')
cueState.rpm=7834
local cue=Selector.shiftCue(cueState)
assert(cue and cue.gear==4 and cue.direction=='up','upshift cue marks the next gear above configured redline')
cueState.rpm=4401
assert(Selector.shiftCue(cueState)==nil,'downshift cue stays off above 55% RPM')
cueState.rpm=4400
cue=Selector.shiftCue(cueState)
assert(cue and cue.gear==2 and cue.direction=='down','downshift cue marks the previous gear at 55% RPM')
cueState.gearText='1'
assert(Selector.shiftCue(cueState)==nil,'first gear never recommends reverse')
cueState.gearText='6'; cueState.rpm=8000
assert(Selector.shiftCue(cueState)==nil,'top gear has no unavailable upshift cue')
cueState.gearText='N'
assert(Selector.shiftCue(cueState)==nil,'neutral has no shift cue')

local h=dofile('tests/gt7_layouts.lua')
local Telemetry=require('src/telemetry')
local Settings=require('src/settings')
local telemetry=Telemetry.new()
local car={gear=3,gearCount=5,physicsAvailable=true}
Telemetry.update(telemetry,0.016,Settings.current(),car)
assert(telemetry.gearCount==5 and telemetry.gearCountSource=='car')
car.physicsAvailable=false
Telemetry.update(telemetry,0.016,Settings.current(),car)
assert(telemetry.gearCount==6 and telemetry.gearCountSource=='fallback')
ac.getCar=function() return nil end
Telemetry.update(telemetry,0.016,Settings.current())
assert(telemetry.gearCount==6 and telemetry._observedGearCount==0)
Settings.values.digitalVariant='snap'
Settings.values.animateGearSelector=false
assert(Settings.current().digitalVariant=='snap' and Settings.current().animateGearSelector==false)
local sawNeutral=false
for _,gear in ipairs({'N','R','1','4','8'}) do
  h.state.gearText,h.state.gearCount,h.state.available=gear,gear=='8' and 8 or 6,true
  local calls=h.drawDial({instrumentMode='digital',digitalVariant='snap',hudScale=1},h.state)
  local neutralCount=0
  for _,call in ipairs(calls) do
    if call.kind=='text' and call.text=='N' then neutralCount=neutralCount+1 end
    assert(not (call.kind=='text' and call.text=='CLUTCH'), 'Snap Selector omits the clutch pedal')
  end
  if gear=='N' then assert(neutralCount==1,'N is only printed in the central selector'); sawNeutral=true
  else assert(neutralCount==0) end
end
assert(sawNeutral)
print('Snap selector: gear metadata, 120 ms settling, restrained rebound, interruption, neutral/reverse, reset and visibility passed')
