package.path = './?.lua;./?/init.lua;' .. package.path

local GearHint = require('src/corner_gear_hint')
local samples = 0
local radius = 100
local circumference = 2 * math.pi * radius

local torqueCurve = {
  get = function(_, rpm) return 300 - rpm * 0.01 end
}
ac = {
  getTrackFullID = function() return 'synthetic-circle' end,
  getTrackName = function() return 'Synthetic circle' end,
  hasTrackSpline = function() return true end,
  trackProgressToWorldCoordinate = function(progress)
    samples = samples + 1
    local angle = progress * 2 * math.pi
    return {x = radius * math.cos(angle), z = radius * math.sin(angle)}
  end,
  getCarID = function() return 'test-car' end,
  getCarPhysics = function()
    return {finalRatio = 4, gearRatios = {[1]=3.2,[2]=2.1,[3]=1.5,[4]=1.1,[5]=0.9,[6]=0.75},
      wheels = {[0]={tyreLoadedRadius=0.34},[1]={tyreLoadedRadius=0.34},
        [2]={tyreLoadedRadius=0.34},[3]={tyreLoadedRadius=0.34}}}
  end,
  INIConfig = {carData = function(_, file)
    if file == 'engine.ini' then
      return {get = function(_, section, key) if section == 'HEADER' and key == 'POWER_CURVE' then return 'test.lut' end end}
    end
    return nil
  end},
  DataLUT11 = {carData = function() return torqueCurve end}
}

local sim = {trackLengthM = circumference, isReplayActive = false}
local car = {index=0, id='test-car', gear=4, gearCount=6, speedMs=40, speedKmh=144,
  splinePosition=0.97, rpmLimiter=8000, physicsAvailable=true, isAIControlled=false,
  isUserControlled=true, isInPit=false, isInPitlane=false}
local state = {clock=0, rpmDisplayLimiter=8000}

GearHint.update(state, car, sim, 1/60, true)
assert(state.cornerGearHint and state.cornerGearHint.gear == 2,
  'torque curve selects the gear with the greatest safe wheel torque')
assert(state.cornerGearHint.direction == 'down' and state.cornerGearHint.overspeed,
  'a slower target gear is shown red when speed exceeds the target by 10 km/h')
assert(state.cornerGearHint.braking,
  'the cue flashes when the remaining apex distance reaches the estimated braking distance')
local sampledOnce = samples
GearHint.update(state, car, sim, 1/60, true)
assert(samples == sampledOnce, 'the AI spline geometry is sampled once and cached for the track')

state.clock = 2
car.splinePosition = 0.1
GearHint.update(state, car, sim, 1/60, true)
assert(state.cornerGearHint and not state.cornerGearHint.braking,
  'the corner recommendation remains visible before the braking point without flashing')

car.gear = 2
GearHint.update(state, car, sim, 1/60, true)
assert(state.cornerGearHint == nil, 'no cue is shown when the suggested gear is already selected')
car.gear = 4

sim.isReplayActive = true
GearHint.update(state, car, sim, 1/60, true)
assert(state.cornerGearHint == nil, 'replays hide the corner recommendation')
sim.isReplayActive = false
car.isInPitlane = true
GearHint.update(state, car, sim, 1/60, true)
assert(state.cornerGearHint == nil, 'the cue is hidden in the pit lane')
car.isInPitlane, car.isAIControlled = false, true
GearHint.update(state, car, sim, 1/60, true)
assert(state.cornerGearHint == nil, 'the cue is hidden under AI control')
car.isAIControlled, car.gear = false, 0
GearHint.update(state, car, sim, 1/60, true)
assert(state.cornerGearHint == nil, 'neutral and reverse suppress the cue')
car.gear = 4
GearHint.update(state, car, sim, 1/60, false)
assert(state.cornerGearHint == nil, 'the global setting disables calculation and display')

GearHint.clearCaches()
state._cornerGearRuntime = nil
ac.DataLUT11.carData = function() return nil end
samples = 0
state.clock, car.splinePosition = 0, 0.97
GearHint.update(state, car, sim, 1/60, true)
assert(state.cornerGearHint and state.cornerGearHint.gear == 2
    and state.cornerGearHint.source == 'ratio',
  'without a torque curve, the shortest gear below the RPM safety margin is used')

local Visual = require('ui/corner_gear_hint')
local shown = Visual.visual({gear=4,clock=0,cornerGearHint=state.cornerGearHint}, {cornerGearHint=true})
assert(shown and shown.direction == 'down' and shown.overspeed,
  'renderer receives arrow direction and overspeed color state')
assert(Visual.visual({gear=4,clock=0,cornerGearHint=state.cornerGearHint}, {cornerGearHint=false}) == nil,
  'renderer also respects the shared setting')
local lines, label = {}, nil
assert(Visual.draw({gear=4,clock=0,cornerGearHint=state.cornerGearHint}, {cornerGearHint=true},
  100, 100, 20, {primary='primary',red='red'},
  function(x1,y1,x2,y2,color,width) lines[#lines+1]={x1,y1,x2,y2,color,width} end,
  function(value) label=value end))
assert(#lines == 3 and label == '2' and lines[1][5] == 'red',
  'render helper draws a red directional arrow and the target gear')
assert(not Visual.draw({gear=4,clock=0.15,cornerGearHint=state.cornerGearHint}, {cornerGearHint=true},
  100, 100, 20, {primary='primary',red='red'}, function() end, function() end),
  'the cue blinks at the braking point')

local expected = {
  analog = {stacked={'original'}, side={'concentric','shelf','spoke'}, selector={'snap'}},
  digital = {
    stacked={'original','column','floating','offset','orbit'},
    side={'bridge','core_capsule','radial'}, selector={'snap'}
  }
}
for instrument, presentations in pairs(expected) do
  for presentation, variants in pairs(presentations) do
    for _, variant in ipairs(variants) do
      assert(Visual.presentation(instrument,variant)==presentation,
        instrument..' '..variant..' uses '..presentation..' gear cue')
    end
  end
end
for _, variant in ipairs({'fan','track','halo','jewel','spectrum'}) do
  assert(Visual.presentation('analog',variant)==nil,'unlisted analog faces hide the cue')
end
for _, variant in ipairs({'halo','jewel','spectrum'}) do
  assert(Visual.presentation('digital',variant)==nil,'unlisted digital faces hide the cue')
end
local kind,current,recommendation=Visual.placements('digital','column',310,147,105)
assert(kind=='stacked' and current.size<105 and current.y<147 and recommendation.y>147,
  'stacked cue reduces and raises the current gear, then places the hint underneath')
kind,current,recommendation=Visual.placements('analog','spoke',459,383,61)
assert(kind=='side' and current.x<459 and recommendation.x>459,
  'side-by-side cue moves the current gear left and recommendation right')
kind,current,recommendation=Visual.placements('gt7',nil,820,172,100)
assert(kind=='gt7' and current.x>820 and recommendation.x<820,
  'GT7 places the current gear on the right and recommendation on the left')

print('Suggested corner gear: geometry, torque selection, fallback, braking cue and hide conditions passed')
