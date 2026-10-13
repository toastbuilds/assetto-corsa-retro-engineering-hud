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
assert(angle>from and angle<Selector.angle(3,6)+1)
local interrupted=angle
animation,angle=Selector.sample(animation,4,6,0.07,true,'car')
close(angle,interrupted)
animation,angle=Selector.sample(animation,4,6,0.17,true,'car')
assert(angle>Selector.angle(4,6) and angle-Selector.angle(4,6)<1,'the mechanical rebound stays restrained')
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
  end
  if gear=='N' then assert(neutralCount==1,'N is only printed in the central selector'); sawNeutral=true
  else assert(neutralCount==0) end
end
assert(sawNeutral)
print('Snap selector: gear metadata, 120 ms settling, restrained rebound, interruption, neutral/reverse, reset and visibility passed')
