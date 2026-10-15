package.path = './?.lua;./?/init.lua;' .. package.path
local Model = require('src/pedal_layers')
local raw, reads, iniReads = {gas = 0.8, brake = 0.6}, 0, 0
local id, denied = 'test', false
local assistedBlip = false
local config = {LEVEL = 0.8, POINT_0 = 20, POINT_1 = 140, POINT_2 = 60, ELECTRONIC = 1}
physics = {getCarInputControls = function()
  reads = reads + 1
  if denied then error('unavailable online') end
  return raw
end}
ac = {getCarID = function() return id end, getAssists = function() return {autoBlip = assistedBlip} end,
  INIConfig = {carData = function()
    iniReads = iniReads + 1
    return {get = function(_, _, key, fallback) return config[key] == nil and fallback or config[key] end}
  end}}
local sim = {currentSessionIndex = 1, time = 0}
local car = {index = 0, physicsAvailable = true, gas = 0.9, brake = 0.7, gear = 3, engagedGear = 3,
  tractionControlModes = 3, absModes = 3, tractionControlInAction = false, absInAction = false}
local function tick(state, dt)
  sim.time = sim.time + dt * 1000
  Model.update(state, car, sim, dt)
  return state.pedalLayers
end
local state = {throttle = 123, brake = 456}
local layers = tick(state, 1/60)
assert(layers.source == 'user' and layers.throttle.input == 0.8 and layers.brake.input == 0.6)
assert(layers.throttle.output == 0.8 and layers.brake.output == 0.6)
assert(state.throttle == 123 and state.brake == 456, 'Layer estimation cannot overwrite existing telemetry')
car.tractionControlInAction, car.absInAction = true, true
for i = 1, 60 do layers = tick(state, 1/60) end
assert(layers.throttle.output < 0.001 and layers.brake.output < 0.001)
assert(layers.throttle.input == 0.8 and layers.brake.input == 0.6, 'Cuts must not reduce the input layer')
car.tractionControlInAction, car.absInAction = false, false
for i = 1, 60 do layers = tick(state, 1/60) end
assert(layers.throttle.output > 0.799 and layers.brake.output > 0.599)
assert(iniReads == 1, 'Read the drivetrain once per car, not once per frame')

for _, fps in ipairs({30, 60, 144}) do
  local sample = {}
  car.tractionControlInAction, car.absInAction = true, true
  for i = 1, fps do layers = tick(sample, 1/fps) end
  assert(layers.throttle.output < 0.001, 'Steady intervention must converge at all supported frame rates')
  car.tractionControlInAction, car.absInAction = false, false
  for i = 1, fps do layers = tick(sample, 1/fps) end
  assert(layers.throttle.output > 0.799, 'Recovery must converge independently of frame rate')
end

state = {}
tick(state, 0.01)
car.gear, car.engagedGear = 4, 0
assert(tick(state, 0.01).throttle.output == 0, 'A confirmed shift cuts the estimated output')
car.gear = 0
assert(tick(state, 0.01).throttle.output == raw.gas, 'Neutral is not a shift cut')
car.gear, car.engagedGear = 3, 3
tick(state, 0.01)
raw.gas = 0
car.gear, car.engagedGear = 2, 0
tick(state, 0.01)
layers = tick(state, 0.04)
assert(layers.throttle.input == 0 and layers.throttle.output == 0.8, 'Auto-blip can exceed the pilot input')
car.engagedGear = 2
layers = tick(state, 0.01)
assert(layers.throttle.output == 0.8, 'Completing a shift must not restart its blip envelope')
sim.isPaused = true
local pausedClock, pausedLayer = state._pedalLayers.clock, layers
tick(state, 0.2)
assert(state._pedalLayers.clock == pausedClock and state.pedalLayers == pausedLayer, 'Pause freezes the estimate')
sim.isPaused = false
layers = tick(state, 0.2)
assert(layers.throttle.output == 0, 'POINT_2 is a release duration and the blip eventually ends')

car.gear, car.engagedGear = 3, 3
tick(state, 0.01)
car.gear, car.engagedGear = 2, 0
tick(state, 0.01)
tick(state, 0.04)
car.resetCounter, car.gear, car.engagedGear = 1, 2, 2
assert(tick(state, 0.01).throttle.output == 0, 'A reset removes the previous shift envelope')
id, config = 'missing_config', {}
state = {}
car.gear, car.engagedGear = 3, 3
tick(state, 0.01)
car.gear, car.engagedGear = 2, 2
assert(tick(state, 0.04).throttle.output == 0, 'Missing config cannot create a blip')

id, config, state = 'assisted_blip',
  {LEVEL = 0.8, POINT_0 = 20, POINT_1 = 140, POINT_2 = 60, ELECTRONIC = 0}, {}
car.gear, car.engagedGear = 3, 3
tick(state, 0.01)
car.gear, car.engagedGear = 2, 2
assert(tick(state, 0.04).throttle.output == 0, 'Non-electronic blip needs the assist enabled')
assistedBlip = true
car.gear, car.engagedGear = 1, 1
tick(state, 0.01)
assert(tick(state, 0.04).throttle.output == 0.8, 'The user auto-blip assist enables a valid envelope')
sim.currentSessionTime = 500
tick(state, 0.01)
sim.currentSessionTime = 0
assert(tick(state, 0.01).throttle.output == 0,
  'A same-ID session restart cannot retain a previous blip')
car.tractionControlModes, car.absModes, car.tractionControlInAction, car.absInAction, car.engagedGear = nil,nil,nil,nil,nil
layers = tick({}, 1/60)
assert(layers.throttle.output == nil and layers.brake.output == nil,
  'Unknown intervention and gear channels cannot masquerade as no intervention')
car.tractionControlModes, car.absModes, car.tractionControlInAction, car.absInAction, car.engagedGear = 3,3,false,false,1

denied, raw.gas, state = true, 0.8, {}
local before = reads
for i = 1, 20 do layers = tick(state, 1/60) end
assert(reads == before + 1 and layers.source == 'car' and layers.throttle.input == car.gas,
  'Denied input access is cached; car controls remain available')
sim.currentSessionIndex = 2
tick(state, 1/60)
assert(reads == before + 2, 'A new session retries input access')
sim.isReplayActive = true
layers = tick(state, 1/60)
assert(layers.throttle.output == nil and layers.brake.output == nil, 'Replays show input only')
sim.isReplayActive, car.isAIControlled = false, true
assert(tick(state, 1/60).throttle.output == nil, 'Autopilot cannot be treated as human pedal telemetry')
car.isAIControlled, car.physicsAvailable = false, false
assert(tick(state, 1/60).brake.output == nil, 'Unavailable physics cannot fabricate an ABS estimate')
Model.update(state, nil, sim, 0.01)
assert(state.pedalLayers == nil and state._pedalLayers == nil)

-- Build a real intermediate estimate for the renderer sweeps.
denied, car.physicsAvailable, state = false, true, {}
for i = 1, 120 do
  car.tractionControlInAction, car.absInAction = i % 4 == 0, i % 3 == 0
  layers = tick(state, 1/60)
end
assert(layers.throttle.output > 0 and layers.throttle.output < layers.throttle.input)
local harness = dofile('tests/gt7_layouts.lua')
harness.state.pedalLayers = layers
local scenarios = 0
for _, theme in ipairs({'dark', 'light'}) do
  for _, size in ipairs({420, 620}) do
    for _, mode in ipairs({'analog', 'digital'}) do
      local layouts = require(mode == 'analog' and 'src/dial_variants' or 'src/digital_dial_variants').layouts
      for name in pairs(layouts) do
        local options = {theme = theme, instrumentMode = mode, hudScale = 1,
          analogVariant = name, digitalVariant = name, pedalDisplay = 'estimated'}
        local calls = harness.drawDial(options, harness.state, {size,size})
        options.pedalDisplay = 'classic'
        local classic = harness.drawDial(options, harness.state, {size,size})
        assert(#calls > #classic, 'Each Dial pedal geometry must actually render the second layer: ' .. name)
        scenarios = scenarios + 1
      end
    end
    for _, frame in ipairs({'classic', 'modern', 'outer_pedals', 'steering_dial'}) do
      local calls = harness.draw(frame, {theme = theme, pedalDisplay = 'estimated'}, harness.state, {size*2,size})
      local classic = harness.draw(frame, {theme = theme, pedalDisplay = 'classic'}, harness.state, {size*2,size})
      assert(#calls > #classic, 'Every GT7 composition must render the dynamic layers')
      scenarios = scenarios + 1
    end
  end
end
print('Pedal layers: input/cuts, FPS, shifts, blip, fallbacks, resets and ' .. scenarios .. ' render scenarios passed')
