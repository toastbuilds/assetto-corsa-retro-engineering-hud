local harness = dofile('tests/gt7_layouts.lua')
local Hybrid = require('src/hybrid')
local Telemetry = require('src/telemetry')
local carID = 'cadillac_test'
ac.getCarID = function() return carID end
local car = { index=0, kersPresent=true, kersCharge=0.84, kersInput=0.7,
  physicsAvailable=true, kersCharging=false, wheels={} }
local physics = { isAvailable=true, wheels={} }
for i=0,3 do
  car.wheels[i]={angularSpeed=100}
  physics.wheels[i]={electricTorque=300}
end
local state = { available=true, turboAvailable=false }
Hybrid.update(state,car,0,physics)
assert(state.hybrid.powerKw==120 and state.hybrid.charge==0.84,
  'wheel torque times angular velocity must provide kW independently of battery charge')
assert(Hybrid.forGauge(state)==state.hybrid,'hybrids without turbo must select electric automatically')
state.turboAvailable=true
assert(Hybrid.forGauge(state)==state.hybrid and Hybrid.forGauge(state,'auto')==state.hybrid
  and Hybrid.forGauge(state,'electric')==state.hybrid,
  'hybrids must select electric automatically even when turbo is available')
assert(Hybrid.forGauge(state,'fuel')==nil and Hybrid.forGauge(state,'off')==nil
  and Hybrid.forGauge(state,'turbo')==nil, 'explicit auxiliary selections must remain available')
state.turboAvailable=false
for i=0,3 do physics.wheels[i].electricTorque=-200 end
Hybrid.update(state,car,0,physics)
assert(state.hybrid.powerKw==-80 and state.hybrid.needle<0,'recovery must retain negative electric power')
for i=0,3 do physics.wheels[i].electricTorque=0 end
Hybrid.update(state,car,0,physics)
assert(state.hybrid.powerKw==0 and state.hybrid.needle==0,'a populated channel must retain measured zero')
carID='unpopulated_mod'
Hybrid.update(state,car,0,physics)
assert(state.hybrid.powerKw==nil and state.hybrid.delivery==0.7,
  'an unpopulated torque channel must fall back to ERS percentage, not fabricated kW')
assert(not state.hybrid.measuredTorque and state.hybrid.maximumKw==50,'car change must clear scale and channel history')
car.kersCharge=0
Hybrid.update(state,car,0,physics)
assert(state.hybrid.charge==0,'an empty battery is valid telemetry')
physics.wheels[2].electricTorque=100
car.wheels[1].angularSpeed=nil
Hybrid.update(state,car,0,physics)
assert(state.hybrid.powerKw==nil,'missing data from any wheel must suppress kW')
car.wheels[1].angularSpeed=100
car.physicsAvailable=false
Hybrid.update(state,car,0,physics)
assert(state.hybrid.powerKw==nil,'physics-only readings must not survive in a replay or remote car')
car.kersCharge,car.kersInput=nil,nil
Hybrid.update(state,car,0,physics)
assert(state.hybrid.charge==nil and state.hybrid.needle==nil,'missing charge and delivery must remain unavailable')
car.kersPresent=false
Hybrid.update(state,car,0,physics)
assert(state.hybrid==nil,'switching to a conventional car must clear hybrid state')

-- Exercise the production telemetry integration, rather than only the helper.
car.kersPresent,car.physicsAvailable,car.kersCharge,car.kersInput=true,true,0.84,0.7
car.turboCount,car.turboBoost=1,0.7
for i=0,3 do physics.wheels[i].electricTorque=300 end
ac.getCarPhysics=function() return physics end
local live = Telemetry.new()
Telemetry.update(live,0,require('src/settings').current(),car)
assert(live.turboAvailable and live.hybrid and live.hybrid.powerKw==120
  and Hybrid.forGauge(live)==live.hybrid, 'live hybrid turbo telemetry must select the battery gauge')
ac.getCar=function() return nil end
Telemetry.update(live,0,require('src/settings').current())
assert(live.hybrid==nil,'losing the current car must clear electric readings')

local drawState=harness.state
drawState.available,drawState.turboAvailable=true,false
drawState.hybrid={powerKw=120,needle=0.8,charge=0.84}
drawState.raceFlagType,drawState.rpmWarning,drawState.rpmRedline=nil,false,false
drawState.fuel,drawState.maxFuel,drawState.fuelNormalized=30,50,0.6
local function texts(calls)
  local labels={}
  for _,call in ipairs(calls) do
    if call.kind=='text' then labels[call.text]=true end
  end
  return labels
end
for _,turbo in ipairs({false,true}) do
  drawState.turboAvailable=turbo
  for _,theme in ipairs({'dark','light'}) do
    for _,lights in ipairs({false,true}) do
      drawState.headlights,drawState.gt7Instruments=lights,nil
      local options={theme=theme,hudScale=1}
      for _,window in ipairs({{620,620},{460,460},{330,330}}) do
        local labels=texts(harness.drawDial(options,drawState,window))
        assert(labels['CHG'] and labels['PWR'] and labels['120 kW'] and labels['84%'],
          'standalone must show independent charge and electric power using the Triptych layout')
      end
      for _,mode in ipairs({'analog','digital'}) do
        options.gt7SpeedNeedleMode,options.gt7RpmNeedleMode=mode,mode
        for _,frame in ipairs({'classic','modern','outer_pedals','steering_dial'}) do
          for _,window in ipairs({{1440,500},{720,360}}) do
            local labels=texts(harness.draw(frame,options,drawState,window))
            assert(labels['CHG'] and labels['PWR'] and labels['120 kW'] and labels['84%']
              and not labels['BOOST'] and not labels['NAT ASP'],
              'all GT7 modes and compositions must use the electric RPM subinstrument')
            assert(labels['FUEL'],'GT7 electric mode must preserve the speed dial fuel gauge')
          end
        end
      end
    end
  end
end
drawState.hybrid={powerKw=-80,needle=-0.8,charge=0}
local labels=texts(harness.drawDial({hudScale=1},drawState))
assert(labels['-80 kW'] and labels['0%'],'recovery and empty battery must remain explicit')
drawState.hybrid={delivery=0.7,needle=0.7}
labels=texts(harness.draw('classic',nil,drawState))
assert(labels['ERS 70%'] and labels['--%'] and not labels['120 kW'],
  'unsupported mods must label ERS input and unavailable battery honestly')
drawState.turboAvailable,drawState.turboBoost,drawState.turboDisplayMax=true,0.7,1.5
labels=texts(harness.drawDial({hudScale=1},drawState))
assert(labels['ERS 70%'] and labels['--%'] and labels['CHG'] and not labels['TURBO'],
  'hybrid turbos must show electric delivery and battery in Auto even without measured kW')
labels=texts(harness.drawDial({analogAuxiliaryMode='turbo',hudScale=1},drawState))
assert(labels['TURBO'] and labels['0.70 BAR'] and not labels['CHG'],
  'explicit Turbo must remain available on the standalone dial')
labels=texts(harness.drawDial({analogAuxiliaryMode='electric',hudScale=1},drawState))
assert(labels['ERS 70%'],'standalone Electric override must also work on hybrid turbo cars')
drawState.hybrid=nil
labels=texts(harness.drawDial({hudScale=1},drawState))
assert(labels['TURBO'] and labels['0.70 BAR'] and not labels['CHG'],
  'conventional turbo cars must still select boost automatically')
labels=texts(harness.drawDial({analogAuxiliaryMode='electric',hudScale=1},drawState))
assert(labels['ERS N/A'] and not labels['FUEL'],'explicit Electric without data must not silently display fuel')

print('Hybrid instruments: mechanical kW, regeneration, zero/missing data, car changes, telemetry integration, hybrid priority with/without turbo, themes, sizes and all GT7 compositions passed')
