local harness = dofile('tests/gt7_layouts.lua')
local Hybrid = require('src/hybrid')
local Theme = require('src/theme')
local carID = 'hybrid_regeneration_test'
ac.getCarID = function() return carID end
local car = { index=0, kersPresent=true, kersCharge=0.5, kersInput=0,
  kersCharging=false, brake=0.8, wheels={} }
local physics = { isAvailable=true, wheels={} }
for i=0,3 do
  car.wheels[i]={angularSpeed=100}
  physics.wheels[i]={electricTorque=200}
end
local state={available=true,turboAvailable=true}
Hybrid.update(state,car,0,physics)
for i=0,3 do physics.wheels[i].electricTorque=0 end
car.kersCharging,car.kersCharge=true,0.502
Hybrid.update(state,car,0.1,physics)
assert(state.hybrid.needle<0,
  'battery charging under braking must move the indicator into negative CHG even when wheel torque is zero')

local function texts(calls)
  local labels={}
  for _,call in ipairs(calls) do
    if call.kind=='text' then labels[call.text]=true end
  end
  return labels
end
local drawState=harness.state
drawState.available=true
drawState.hybrid,drawState.turboAvailable=state.hybrid,true
for _,theme in ipairs({'dark','light'}) do
  local calls=harness.drawDial({theme=theme,hudScale=1},drawState)
  local labels=texts(calls)
  assert(labels['-2.0%/s'] and not labels['0 kW'],
    'standalone must show negative battery recovery without reporting wheel zero as regeneration power')
  local chargeSegments=0
  local green=Theme.get(theme).green
  for _,call in ipairs(calls) do
    if call.kind=='arc' and math.abs(call.radius-206)<0.001
        and call.color.r==green.r and call.color.g==green.g and call.color.b==green.b then
      assert(call.startAngle>math.pi/2,'green recovery segments must lie on the CHG side')
      chargeSegments=chargeSegments+1
    end
  end
  assert(chargeSegments>0,'negative recovery must visibly fill green CHG segments')
  for _,mode in ipairs({'analog','digital'}) do
    for _,frame in ipairs({'classic','modern','outer_pedals','steering_dial'}) do
      labels=texts(harness.draw(frame,{theme=theme,gt7RpmNeedleMode=mode},drawState))
      assert(labels['-2.0%/s'],'GT7 must display the same negative recovery reading')
    end
  end
end

-- Actual negative wheel power remains the preferred quantitative channel.
for i=0,3 do physics.wheels[i].electricTorque=-200 end
Hybrid.update(state,car,0.1,physics)
assert(state.hybrid.powerKw==-80 and not state.hybrid.batteryRecovery and state.hybrid.needle<0,
  'measured regenerative power must remain negative kW')
assert(texts(harness.drawDial(nil,drawState))['-80 kW'])
for i=0,3 do physics.wheels[i].electricTorque=0 end
car.kersCharge=0.504
Hybrid.update(state,car,0.1,physics)
assert(state.hybrid.batteryRecovery and state.hybrid.needle<0)
car.kersCharging=false
car.kersCharge=0.506
Hybrid.update(state,car,0.1,physics)
assert(state.hybrid.batteryRecovery and state.hybrid.chargeRecoveryRate>0,
  'a real charge increase must detect recovery even when the charging flag is missing')
car.kersCharge=0.504
Hybrid.update(state,car,0.1,physics)
assert(not state.hybrid.batteryRecovery and state.hybrid.chargeRecoveryRate==nil,
  'braking alone or a falling battery must not fabricate recovery')
assert(state.hybrid.needle==0,'ending recovery at zero must clear CHG segments immediately')
car.kersCharging=true
Hybrid.update(state,car,0.1,physics)
assert(state.hybrid.batteryRecovery and state.hybrid.chargeRecoveryRate==nil
  and texts(harness.drawDial(nil,drawState))['CHG'],
  'charging flag without a measured rate must show CHG rather than invented negative kW')
physics.isAvailable=false
car.kersCharge=0.506
Hybrid.update(state,car,0.1,physics)
assert(state.hybrid.powerKw==nil and state.hybrid.needle<0,
  'mods without wheel physics must still show battery recovery')
-- Some mods publish a positive-only torque channel during brake recovery.
physics.isAvailable=true
for i=0,3 do physics.wheels[i].electricTorque=200 end
car.kersCharge=0.508
Hybrid.update(state,car,0.1,physics)
assert(state.hybrid.batteryRecovery and state.hybrid.needle<0,
  'braking and confirmed charging must not appear as positive electric delivery')
car.brake,car.kersCharging,car.kersCharge=0,false,0.506
Hybrid.update(state,car,0.1,physics)
assert(not state.hybrid.batteryRecovery and state.hybrid.powerKw==80 and state.hybrid.needle>0,
  'transition back to delivery must immediately move to the positive side')
for i=0,3 do physics.wheels[i].electricTorque=0 end
car.kersCharge,car.resetCounter=0.508,1
Hybrid.update(state,car,0.1,physics)
assert(state.hybrid.chargeRecoveryRate==nil,'resetting the car must discard charge history')
car.kersCharge=0.51
Hybrid.update(state,car,1,physics)
assert(state.hybrid.chargeRecoveryRate==nil,'a paused or delayed sample must not create a recovery spike')
car.kersCharge=0.8
Hybrid.update(state,car,0.1,physics)
assert(state.hybrid.chargeRecoveryRate==nil,'large battery jumps must not look like regeneration')
local sim={time=1000,currentSessionIndex=0}
ac.getSim=function() return sim end
Hybrid.update(state,car,0.1,physics)
sim.currentSessionIndex,car.kersCharge=1,0.802
Hybrid.update(state,car,0.1,physics)
assert(state.hybrid.chargeRecoveryRate==nil,'session changes must discard charge history')
sim.time,car.kersCharge=900,0.804
Hybrid.update(state,car,0.1,physics)
assert(state.hybrid.chargeRecoveryRate==nil,'time rewind must discard charge history')
sim.isReplayActive,car.kersCharge=true,0.806
Hybrid.update(state,car,0.1,physics)
assert(state.hybrid.chargeRecoveryRate==nil,'replay charge rate must not be measured against live frame time')
sim.isReplayActive=false
car.kersCharge=nil
Hybrid.update(state,car,0.1,physics)
assert(state.hybrid.chargeRecoveryRate==nil,'missing charge must discard recovery samples')
carID='replacement_hybrid'
car.kersCharge=0.9
Hybrid.update(state,car,0.1,physics)
assert(state.hybrid.chargeRecoveryRate==nil,'car changes must not compare unrelated batteries')

-- Repeat the recovery display checks against Free's renderer and palette.
package.loaded['src/theme']=assert(loadfile('free-edition/src/theme.lua'))()
package.loaded['src/gt7_retro_layout']=assert(loadfile('free-edition/src/gt7_retro_layout.lua'))()
package.loaded['ui/instrument_illumination']=nil
package.loaded['ui/hybrid_gauge']=nil
ui.pathFillConvex=function() end
local freeRenderer=assert(loadfile('free-edition/ui/gt7_retro.lua'))()
local freeDial=assert(loadfile('ui/dial.lua'))()
drawState.hybrid={batteryRecovery=true,chargeRecoveryRate=2,needle=-0.8,charge=0.84}
for _,theme in ipairs({'dark','light'}) do
  local options=require('src/gt7_settings').current()
  options.theme=theme
  for _,mode in ipairs({'analog','digital'}) do
    options.gt7RpmNeedleMode=mode
    assert(texts(harness.drawRenderer(freeRenderer,drawState,options,{1440,500}))['-2.0%/s'])
  end
  options=require('src/settings').current()
  options.theme,options.instrumentMode,options.analogAuxiliaryMode=theme,'analog','auto'
  assert(texts(harness.drawRenderer(freeDial,drawState,options,{620,620}))['-2.0%/s'])
end
print('Hybrid regeneration: negative recovery, measured kW and battery rate, missing channels, transitions, resets/replays and Free/Premium dials passed')
