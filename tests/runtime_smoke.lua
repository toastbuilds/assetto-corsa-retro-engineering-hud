package.path = './?.lua;./?/init.lua;' .. package.path

local Vec2 = {}
Vec2.__index = Vec2
function Vec2.__add(a, b) return vec2(a.x + b.x, a.y + b.y) end
function Vec2.__sub(a, b) return vec2(a.x - b.x, a.y - b.y) end
function Vec2.__mul(a, b)
  if type(a) == 'number' then return vec2(a * b.x, a * b.y) end
  return vec2(a.x * b, a.y * b)
end
function Vec2.__div(a, b) return vec2(a.x / b, a.y / b) end
function vec2(x, y) return setmetatable({ x = x or 0, y = y or 0 }, Vec2) end

function rgbm(r, g, b, mult) return { r = r, g = g, b = b, mult = mult } end

local saved = { layoutVersion = 4, instrumentMode = 'analog' }
local car
local radarCars = {}
local sim = { raceFlagType = nil }
local carId = 'test_car'
local windowWidth, windowHeight = 460, 460
local pendingCombos = {}
local pendingSliders, pendingButtons = {}, {}
local storageByPrefix = {}
local coreErrors = {}
local lastWindowConstraint
local lastRequestedWindowSize

ac = {
  FolderID = { ContentCars = 1 },
  storage = function(defaults, prefix)
    local target = saved
    if prefix then
      storageByPrefix[prefix] = storageByPrefix[prefix] or {}
      target = storageByPrefix[prefix]
    end
    for key, value in pairs(defaults) do
      if target[key] == nil then target[key] = value end
    end
    return target
  end,
  getCar = function() return car end,
  iterateCars = setmetatable({}, {
    __call = function() return ipairs(radarCars) end
  }),
  getCarID = function() return carId end,
  getFolder = function() return 'cars' end,
  getSim = function() return sim end,
  getControllerSteerValue = function() return 0 end,
  broadcastSharedEvent = function() end,
  error = function(message) coreErrors[#coreErrors + 1] = message end,
  setWindowSizeConstraints = function(id, minimum, maximum)
    lastWindowConstraint = { id = id, minimum = minimum, maximum = maximum }
  end
}

io.load = function() return '{"topspeed":"275 km/h"}' end
JSON = { parse = function() return { topspeed = '275 km/h' } end }

local function noop() end
ui = {
  windowWidth = function() return windowWidth end,
  windowHeight = function() return windowHeight end,
  measureDWriteText = function(text, size) return vec2(#tostring(text) * size * 0.55, size) end,
  drawCircle = noop,
  drawCircleFilled = noop,
  drawLine = noop,
  drawRect = noop,
  drawRectFilled = noop,
  drawImage = noop,
  drawTriangleFilled = noop,
  dwriteDrawText = noop,
  pathArcTo = noop,
  pathClear = noop,
  pathFillConvex = noop,
  pathLineTo = noop,
  pathStroke = noop,
  popDWriteFont = noop,
  popStyleVar = noop,
  pushDWriteFont = noop,
  pushStyleVarAlpha = noop,
  setNextWindowSize = function(size)
    lastRequestedWindowSize = size
  end,
  header = noop,
  separator = noop,
  text = noop,
  textWrapped = noop,
  sameLine = noop,
  availableSpaceX = function() return 640 end,
  time = function() return 0 end,
  ComboFlags = { None = 0 },
  combo = function(label, index)
    local selected = pendingCombos[label]
    pendingCombos[label] = nil
    return selected or index, selected ~= nil
  end,
  checkbox = function() return false end,
  slider = function(label, value)
    local selected = pendingSliders[label]
    pendingSliders[label] = nil
    return selected or value, selected ~= nil
  end,
  button = function(label)
    local pressed = pendingButtons[label]
    pendingButtons[label] = nil
    return pressed or false
  end
}

-- This smoke test exercises the app's core windows; external panels have
-- separate runtimes and need not emulate their full CSP surface here.
for _, name in ipairs({ 'relative', 'delta', 'timer', 'laps', 'leaderboard', 'telemetry', 'map', 'notices' }) do
  package.preload['modules/' .. name .. '/main'] = function()
    return { getTemperatureUnit = function() return 'C' end, update = noop }
  end
end
script = {}
require('app')
local Settings = require('src/settings')
local GeneralSettings = require('src/general_settings')
local Gt7Settings = require('src/gt7_settings')
local Telemetry = require('src/telemetry')
local Gt7Retro = require('ui/gt7_retro')
local Theme = require('src/theme')
local DialLayout = require('src/layout')
local Gt7Layout = require('src/gt7_retro_layout')
local ClassicGt7Layout = Gt7Layout.get('classic')

local ConditionSettings = require('src/condition_settings')
assert(ConditionSettings.current().temperatureCoreWeight == 0.8,
  'existing installs must default to the original 80/20 mix')
pendingButtons['>  Personalization##condition.personalization'] = true
pendingSliders['Core weight'] = 35
ConditionSettings.draw()
assert(ConditionSettings.current().temperatureCoreWeight == 0.35)
package.loaded['src/condition_settings'] = nil
ConditionSettings = require('src/condition_settings')
assert(ConditionSettings.values.temperatureCoreWeight == 0.35, 'core ratio must persist after reload')
pendingCombos['##condition.temperatureDisplay'] = 2
pendingSliders['Core weight'] = 65
ConditionSettings.draw()
assert(ConditionSettings.values.temperatureDisplay == 'surface'
  and ConditionSettings.values.temperatureCoreWeight == 0.35
  and pendingSliders['Core weight'] == 65, 'surface mode must hide the blend slider and preserve its saved ratio')
pendingCombos['##condition.temperatureDisplay'] = 1
ConditionSettings.draw()
assert(ConditionSettings.values.temperatureCoreWeight == 0.65,
  'uniform General must expose the same blend slider')
pendingSliders['Core weight'] = 0
ConditionSettings.draw()
assert(ConditionSettings.values.temperatureCoreWeight == 0, '0% core must be selectable')
pendingSliders['Core weight'] = 100
ConditionSettings.draw()
assert(ConditionSettings.values.temperatureCoreWeight == 1, '100% core must be selectable')
pendingButtons['Reset appearance##condition'] = true
ConditionSettings.draw()
assert(ConditionSettings.values.temperatureCoreWeight == 0.8, 'appearance reset must restore 80/20')
ConditionSettings.values.temperatureCoreWeight = 0.4
pendingButtons['>  Advanced##condition.advanced'] = true
pendingButtons['Reset all##condition'] = true
ConditionSettings.draw()
assert(ConditionSettings.values.temperatureCoreWeight == 0.4, 'full reset must wait for confirmation')
pendingButtons['Confirm reset##condition'] = true
ConditionSettings.draw()
assert(ConditionSettings.values.temperatureCoreWeight == 0.8, 'full reset must restore 80/20')

assert(Settings.values.instrumentMode == 'analog', 'v5 migration must preserve analog')
assert(Settings.values.layoutVersion == 10 and Settings.values.analogVariant == 'original',
  'v10 migration must complete without changing the existing analog composition')
assert(Settings.values.gt7SpeedNeedleMode == 'digital'
  and Settings.values.gt7RpmNeedleMode == 'digital',
  'v6 migration must preserve the former direct GT7 needle response')
assert(Gt7Layout.rpmStartFraction == DialLayout.digitalRpmAlertStartFraction,
  'GT7 RPM band must start at the digital lower warning-light threshold')

local expected = { 'digital', 'analog' }
for index, mode in ipairs(expected) do
  pendingCombos['##dial.mode'] = index - 1
  Settings.draw()
  assert(Settings.values.instrumentMode == mode, 'instrument selector cycle failed')
end

pendingCombos['##gt7.speedNeedle'] = 1
Gt7Settings.draw()
assert(Gt7Settings.values.gt7SpeedNeedleMode == 'analog'
  and Gt7Settings.values.gt7RpmNeedleMode == 'digital',
  'GT7 speed needle selection must be independent')
pendingCombos['##gt7.rpmNeedle'] = 1
Gt7Settings.draw()
assert(Gt7Settings.values.gt7SpeedNeedleMode == 'analog'
  and Gt7Settings.values.gt7RpmNeedleMode == 'analog',
  'GT7 RPM needle selection must be independent')
assert(Gt7Settings.values.gt7RadarPresentation == 'arcs', 'GT7 radar presentation must default to arcs')
pendingButtons['>  Personalization##gt7.personalization'] = true
pendingButtons['>  Radar and flags##gt7.radar'] = true
pendingButtons['>  Lower panel##gt7.lowerPanel'] = true
pendingCombos['##gt7.radarPresentation'] = 1
Gt7Settings.draw()
assert(Gt7Settings.values.gt7RadarPresentation == 'classic_lights'
  and Gt7Settings.values.gt7RadarStyle == 'arcs',
  'GT7 radar selector must use its own storage and preserve the legacy field')
pendingCombos['##gt7.radarPresentation'] = 0
Gt7Settings.draw()
assert(Gt7Settings.values.gt7RadarPresentation == 'arcs', 'radar selector must restore arcs')
pendingCombos['##gt7.flagPresentation'] = 1
Gt7Settings.draw()
assert(Gt7Settings.values.gt7FlagPresentation == 'modern_strips',
  'flag presentation must be selectable independently from radar')
pendingCombos['##gt7.flagPresentation'] = 0
Gt7Settings.draw()
assert(Gt7Settings.values.gt7FlagPresentation == 'classic_lights',
  'flag selector must restore Classic lights independently')
pendingCombos['##gt7.lower'] = 1
Gt7Settings.draw()
assert(Gt7Settings.values.gt7LowerPanelMode == 'ffb',
  'GT7 lower panel selector must retain the FFB gauge')
pendingCombos['##gt7.lower'] = 2
Gt7Settings.draw()
assert(Gt7Settings.values.gt7LowerPanelMode == 'pedal_history',
  'GT7 lower panel selector must expose pedal history')
pendingCombos['##gt7.lower'] = 3
Gt7Settings.draw()
assert(Gt7Settings.values.gt7LowerPanelMode == 'invisible',
  'GT7 lower panel selector must expose the invisible radar space')
pendingCombos['##gt7.lower'] = 0
Gt7Settings.draw()
assert(Gt7Settings.values.gt7LowerPanelMode == 'limit',
  'GT7 lower panel selector must restore the LIMIT gauge after invisible')

local function makeCar(overrides)
  local function wheel(overrides)
    local value = {
      tyreCoreTemperature = 84,
      tyreMiddleTemperature = 86,
      tyreOptimumTemperature = 88,
      tyreWear = 0.08,
      tyreDirty = 0.02,
      tyreGrain = 0,
      tyreBlister = 0,
      tyreFlatSpot = 0,
      suspensionDamage = 0,
      isBlown = false,
      tyreSlip = 0.12,
      slipRatio = 0.02,
      slipAngle = 0.03,
      load = 1
    }
    for key, override in pairs(overrides or {}) do value[key] = override end
    return value
  end
  local value = {
    index = 0,
    isConnected = true,
    isActive = true,
    position = { x = 0, y = 0, z = 0 },
    look = { x = 0, y = 0, z = 1 },
    side = { x = 1, y = 0, z = 0 },
    aabbSize = { x = 2, y = 1, z = 4.5 },
    physicsAvailable = true,
    speedKmh = 128,
    rpm = 4200,
    rpmLimiter = 8000,
    gear = 3,
    steer = 35,
    steerLock = 540,
    gas = 0.62,
    brake = 0.15,
    clutch = 1,
    handbrake = 0,
    acceleration = { x = 0, y = 0, z = 0 },
    fuel = 18,
    maxFuel = 60,
    turboCount = 0,
    turboBoost = 0,
    tractionControlModes = 3,
    tractionControlMode = 2,
    tractionControlInAction = false,
    absModes = 3,
    absMode = 2,
    absInAction = false,
    headlightsActive = false,
    lowBeams = false,
    highBeams = false,
    turningLeftLights = false,
    turningRightLights = false,
    hazardLights = false,
    turningLightsActivePhase = true,
    isInPit = false,
    isInPitlane = false,
    manualPitsSpeedLimiterEnabled = false,
    speedLimiterInAction = false,
    engineLifeLeft = 1000,
    gearboxDamage = 0,
    damage = { [0] = 0, [1] = 0, [2] = 0, [3] = 0, [4] = 0 },
    wheels = {
      [0] = wheel(),
      [1] = wheel({ tyreCoreTemperature = 70 }),
      [2] = wheel({ tyreCoreTemperature = 112, tyreWear = 0.42 }),
      [3] = wheel({ tyreWear = 0.9, tyreFlatSpot = 0.76, isBlown = true })
    },
    ffbFinal = 0
  }
  for key, override in pairs(overrides or {}) do value[key] = override end
  return value
end

local telemetry = Telemetry.new()
local flashState = Telemetry.new()
local flashCar = makeCar({headlightsActive=false,lowBeams=true,highBeams=false,flashingLightsActive=true})
Telemetry.update(flashState,1/144,Settings.current(),flashCar)
assert(flashState.headlights and flashState.highBeams and flashState.flashingLights
  and flashState.steadyHeadlights==false and flashState.lightsAvailable,
  'the flasher must illuminate the HUD and the high-beam telltale with the normal lights off')
flashCar.flashingLightsActive=false
Telemetry.update(flashState,1/144,Settings.current(),flashCar)
assert(flashState.headlights==false and flashState.highBeams==false,
  'releasing the flasher must restore unlit headlights instead of leaving a latched telltale')
flashCar.headlightsActive=true
Telemetry.update(flashState,1/60,Settings.current(),flashCar)
assert(flashState.headlights and not flashState.highBeams,'official highBeams must override legacy low-beam inference')
flashCar.flashingLightsActive=true
Telemetry.update(flashState,1/144,Settings.current(),flashCar)
assert(flashState.highBeams and flashState.headlights,'flashing over low beams must indicate the high beams')
flashCar.flashingLightsActive=false
Telemetry.update(flashState,1/144,Settings.current(),flashCar)
assert(flashState.headlights and flashState.highBeams==false,'release must preserve normal low beams')
flashCar.headlightsActive,flashCar.highBeams,flashCar.flashingLightsActive=false,true,nil
Telemetry.update(flashState,1/144,Settings.current(),flashCar)
assert(flashState.flashingLights and flashState.headlights,'older CSP must infer flashing from active high beams with lamps off')
flashCar.headlightsActive,flashCar.highBeams,flashCar.lowBeams=true,nil,false
Telemetry.update(flashState,1/60,Settings.current(),flashCar)
assert(flashState.highBeams,'older CSP must preserve legacy high-beam detection')
flashCar.headlightsActive,flashCar.highBeams,flashCar.lowBeams=nil,nil,nil
Telemetry.update(flashState,1/60,Settings.current(),flashCar)
assert(not flashState.lightsAvailable and flashState.headlights==nil,'missing lamp telemetry must remain unavailable')
car = makeCar({ ffbFinal = 0.62 })
for _ = 1, 30 do Telemetry.update(telemetry, 1 / 60, Settings.current()) end
assert(telemetry.speedGaugeMaximum == 280 and telemetry.speedGaugeStep == 40
  and telemetry.speedGaugeSource == 'car-ui',
  'GT7 speed scale must use the current car metadata with a readable rounded range')
assert(telemetry.ffbAvailable and telemetry.ffbPercent >= 60 and telemetry.ffbPercent <= 63,
  'FFB must use and smooth ffbFinal magnitude')
assert(telemetry.gt7SpeedNeedleNormalized > 0.3 and telemetry.gt7SpeedNeedleNormalized < 0.5,
  'GT7 analog speed needle must track its own normalized target')
assert(telemetry.gt7RpmNeedleNormalized > 0.45 and telemetry.gt7RpmNeedleNormalized < 0.6,
  'GT7 analog RPM needle must track its own normalized target')
assert(telemetry.ffbNeedle > 0.55 and telemetry.ffbNeedle < 0.70,
  'FFB needle must settle near the live magnitude')
assert(telemetry.limitAvailable and telemetry.limitNeedle > 0.08 and telemetry.limitNeedle < 0.20,
  'LIMIT must follow normalized tyre slip independently of FFB')
assert(telemetry.condition.available and telemetry.condition.wheels[1].temperatureRatio > 0.9,
  'car-condition telemetry must normalize tyre temperature against its optimum')
assert(telemetry.condition.wheels[4].isBlown
  and telemetry.condition.wheels[4].conditionSeverity == 1,
  'punctures must take priority over other tyre-condition signals')
assert(math.abs(telemetry.fuelNeedleNormalized - telemetry.fuelNormalized) < 0.00001,
  'fuel needle must initialize at the true fuel level without sweeping in')

car.acceleration = { x = 0, y = 0, z = 1.2 }
for _ = 1, 75 do Telemetry.update(telemetry, 1 / 60, Settings.current()) end
assert(telemetry.fuelNeedleNormalized < telemetry.fuelNormalized - 0.03,
  'road cars must get the stronger fuel-sender slosh')
car.acceleration = { x = 1.5, y = 0, z = 0 }
for _ = 1, 75 do Telemetry.update(telemetry, 1 / 60, Settings.current()) end
assert(telemetry.fuelNeedleNormalized > telemetry.fuelNormalized + 0.02,
  'lateral G must also move the fuel sender')
car.acceleration = { x = 0, y = 0, z = 0 }
for _ = 1, 240 do Telemetry.update(telemetry, 1 / 60, Settings.current()) end
assert(math.abs(telemetry.fuelNeedleNormalized - telemetry.fuelNormalized) < 0.002,
  'fuel sender must settle back to the true level after G is released')

local roadSlosh = telemetry.fuelNormalized
  - (function()
    car.acceleration = { x = 0, y = 0, z = 1.2 }
    for _ = 1, 75 do Telemetry.update(telemetry, 1 / 60, Settings.current()) end
    return telemetry.fuelNeedleNormalized
  end)()
carId = 'test_gt3'
local gt3Telemetry = Telemetry.new()
car = makeCar({ acceleration = { x = 0, y = 0, z = 1.2 } })
for _ = 1, 76 do Telemetry.update(gt3Telemetry, 1 / 60, Settings.current()) end
local gt3Slosh = gt3Telemetry.fuelNormalized - gt3Telemetry.fuelNeedleNormalized
assert(gt3Slosh > 0.015 and roadSlosh > gt3Slosh * 1.8,
  'GT3 fuel slosh must retain the previous restrained response')
carId = 'test_car'
car = makeCar({ acceleration = { x = 0, y = 0, z = 0 } })

GeneralSettings.values.speedUnit = 'mph'
Telemetry.update(telemetry, 1 / 60, Settings.current())
assert(telemetry.speedGaugeMaximum == 175 and telemetry.speedGaugeStep == 25,
  'GT7 speed scale must rebuild cleanly for mph')
GeneralSettings.values.speedUnit = 'km/h'

local primaryCar = car

-- GT7 side radar: the nearest left car is alongside (all three lamps), while
-- the right car is close but still longitudinally offset (arrow + upper dot).
Settings.values.instrumentMode = 'gt7_retro'
local radarPlayer = makeCar({
  position = { x = 0, y = 0, z = 0 },
  side = { x = -1, y = 0, z = 0 }
})
local radarLeft = makeCar({ index = 1, position = { x = 6, y = 0, z = 0 } })
local radarRight = makeCar({ index = 2, position = { x = -4, y = 0, z = -6 } })
car, radarCars = radarPlayer, { radarLeft, radarRight }
local radarTelemetry = Telemetry.new()
Telemetry.update(radarTelemetry, 1 / 60, Settings.current())
assert(radarTelemetry.proximityRadarAvailable
  and radarTelemetry.radarLeftLevel == 3
  and radarTelemetry.radarRightLevel == 2,
  'GT7 radar must distinguish alongside traffic from a close offset car')

-- The nine-lamp option has three genuine increments in each warning band.
local ninePositions = {}
for _, distance in ipairs({ 17, 14, 11, 9, 7.5, 5.5 }) do
  ninePositions[#ninePositions + 1] = -math.sqrt(distance * distance - 4)
end
for _, longitudinal in ipairs({ -3.75, -2.25, -0.75 }) do
  ninePositions[#ninePositions + 1] = longitudinal
end
radarCars = { radarLeft, radarRight }
for level, longitudinal in ipairs(ninePositions) do
  radarLeft.position = { x = 2, z = longitudinal }
  radarRight.position = { x = -2, z = longitudinal }
  Telemetry.update(radarTelemetry, 1 / 60, Settings.current())
  assert(radarTelemetry.radarLeftLevel9 == level and radarTelemetry.radarRightLevel9 == level,
    'nine-lamp radar must reach individual level ' .. level .. ' symmetrically')
  assert(radarTelemetry.radarLeftLevel == math.ceil(level / 3),
    'existing three-stage presentations must retain their warning thresholds')
end
radarCars[#radarCars + 1] = makeCar({ index = 3, position = { x = 2, z = -15 } })
Telemetry.update(radarTelemetry, 1 / 60, Settings.current())
assert(radarTelemetry.radarLeftLevel9 == 9, 'a farther car must not downgrade a nearer warning')
radarCars = { radarLeft, radarRight }
for level = 9, 1, -1 do
  radarLeft.position.z, radarRight.position.z = ninePositions[level], ninePositions[level]
  Telemetry.update(radarTelemetry, 1 / 60, Settings.current())
  assert(radarTelemetry.radarLeftLevel9 == level and radarTelemetry.radarRightLevel9 == level,
    'receding traffic must empty nine-lamp radar one step at a time')
end
radarLeft.position.z, radarRight.position.z = -19, -19
Telemetry.update(radarTelemetry, 1 / 60, Settings.current())
assert(radarTelemetry.radarLeftLevel9 == 0 and radarTelemetry.radarRightLevel9 == 0,
  'out-of-range traffic must clear nine-stage warnings')
Settings.values.instrumentMode = 'analog'
radarTelemetry.radarLeftLevel9, radarTelemetry.radarRightLevel9 = 9, 9
Telemetry.update(radarTelemetry, 1 / 60, Settings.current())
assert(radarTelemetry.radarLeftLevel9 == 0 and radarTelemetry.radarRightLevel9 == 0,
  'leaving GT7 must clear nine-stage warnings')
Settings.values.instrumentMode = 'gt7_retro'
radarCars = {}
Telemetry.update(radarTelemetry, 1 / 60, Settings.current())
assert(radarTelemetry.radarLeftLevel9 == 0 and radarTelemetry.radarRightLevel9 == 0,
  'nine-stage warnings must clear when traffic disappears')
local radarIterator = ac.iterateCars
ac.iterateCars = function() error('grid unavailable') end
radarTelemetry.radarLeftLevel9, radarTelemetry.radarRightLevel9 = 9, 9
Telemetry.update(radarTelemetry, 1 / 60, Settings.current())
assert(not radarTelemetry.proximityRadarAvailable and radarTelemetry.radarLeftLevel9 == 0
  and radarTelemetry.radarRightLevel9 == 0, 'failed grid reads must clear nine-stage warnings')
ac.iterateCars = radarIterator
car = nil
radarTelemetry.radarLeftLevel9, radarTelemetry.radarRightLevel9 = 9, 9
Telemetry.update(radarTelemetry, 1 / 60, Settings.current())
assert(radarTelemetry.radarLeftLevel9 == 0 and radarTelemetry.radarRightLevel9 == 0,
  'missing player must clear nine-stage warnings')
car, radarCars = radarPlayer, { radarLeft, radarRight }
radarLeft.position, radarRight.position = { x = 6, y = 0, z = 0 }, { x = -4, y = 0, z = -6 }
Telemetry.update(radarTelemetry, 1 / 60, Settings.current())

local leftRedArcs = 0
local lastArcX
local outerLeftArcRadius = 0
local gearPodWidth, gearPodCenter
local indicatorTriangles = { left = 0, right = 0 }
local amberIndicators = { left = 0, right = 0 }
local flagLampHits = { left = 0, right = 0 }
local pathPoints = {}
local renderSettings = Gt7Settings.current()
renderSettings.theme = 'dark'
renderSettings.hudScale = 0.72
renderSettings.gt7RadarPresentation = 'arcs'
renderSettings.gt7FlagPresentation = 'classic_lights'
windowWidth, windowHeight = ClassicGt7Layout.width, ClassicGt7Layout.height

ui.drawCircleFilled = function(center, _, color)
  if color == Theme.get('dark').flagYellow then
    if math.abs(center.x - (ClassicGt7Layout.indicatorLeftX + ClassicGt7Layout.flagLampSideOffset)) < 0.01 then
      flagLampHits.left = flagLampHits.left + 1
    elseif math.abs(center.x - (ClassicGt7Layout.indicatorRightX - ClassicGt7Layout.flagLampSideOffset)) < 0.01 then
      flagLampHits.right = flagLampHits.right + 1
    end
  end
end
ui.pathClear = function() pathPoints = {}; lastArcX = nil end
ui.pathLineTo = function(position) pathPoints[#pathPoints + 1] = position end
ui.pathFillConvex = function(color)
  if #pathPoints == 8 and math.abs(pathPoints[1].y - ClassicGt7Layout.gearPodTop) < 0.01 then
    local minimum, maximum = pathPoints[1].x, pathPoints[1].x
    for _, position in ipairs(pathPoints) do
      minimum = math.min(minimum, position.x)
      maximum = math.max(maximum, position.x)
    end
    gearPodWidth = maximum - minimum
    gearPodCenter = (maximum + minimum) / 2
  elseif #pathPoints == 3 then
    local x = pathPoints[1].x
    if math.abs(x - (ClassicGt7Layout.indicatorLeftX - 13)) < 0.01 then
      indicatorTriangles.left = indicatorTriangles.left + 1
      if color == Theme.get('dark').amber then amberIndicators.left = amberIndicators.left + 1 end
    elseif math.abs(x - (ClassicGt7Layout.indicatorRightX + 13)) < 0.01 then
      indicatorTriangles.right = indicatorTriangles.right + 1
      if color == Theme.get('dark').amber then amberIndicators.right = amberIndicators.right + 1 end
    end
  end
end
ui.pathArcTo = function(center, radius, startAngle, endAngle)
  lastArcX = center.x
  local left = math.abs(center.x - ClassicGt7Layout.radarArcLeftX) < 0.01
  local right = math.abs(center.x - ClassicGt7Layout.radarArcRightX) < 0.01
  if left then outerLeftArcRadius = math.max(outerLeftArcRadius, radius) end
  if left or right then
    assert(math.abs(endAngle - startAngle - math.pi / 2) < 0.01,
      'each radar ring must remain a complete quarter arc')
    assert(math.abs(center.y - ClassicGt7Layout.radarArcY) < 0.01,
      'all three radar rings must share one center')
  end
end
ui.pathStroke = function(color)
  if lastArcX and math.abs(lastArcX - ClassicGt7Layout.radarArcLeftX) < 0.01
      and color == Theme.get('dark').red then leftRedArcs = leftRedArcs + 1 end
end

radarTelemetry.radarLeftLevel, radarTelemetry.radarRightLevel = 3, 0
radarTelemetry.raceFlagType, radarTelemetry.clock = 2, 0
radarTelemetry.leftIndicator, radarTelemetry.rightIndicator = true, false
Gt7Retro.draw(radarTelemetry, renderSettings)
assert(leftRedArcs == 3 and outerLeftArcRadius == 56,
  'all three nearby arcs must illuminate together at the original Classic geometry')
assert(gearPodWidth == ClassicGt7Layout.gearPodHalfWidth * 2
  and gearPodCenter == ClassicGt7Layout.gearPodCenterX and gearPodCenter == 875,
  'gear pod must stay compact in its right-side position')
assert(indicatorTriangles.left == 1 and indicatorTriangles.right == 1
  and amberIndicators.left == 1 and amberIndicators.right == 0,
  'turn indicators must remain present and independent while radar is active')
assert(flagLampHits.left == 0 and flagLampHits.right == 2,
  'radar must replace only the flag on its own traffic side')

leftRedArcs = 0
indicatorTriangles.left, indicatorTriangles.right = 0, 0
amberIndicators.left, amberIndicators.right = 0, 0
flagLampHits.left, flagLampHits.right = 0, 0
radarTelemetry.clock = ClassicGt7Layout.radarBlinkPeriod
Gt7Retro.draw(radarTelemetry, renderSettings)
assert(leftRedArcs == 0 and flagLampHits.left == 0 and flagLampHits.right == 2,
  'radar off-blink phase must keep ownership of the traffic-side flag space')
assert(indicatorTriangles.left == 1 and indicatorTriangles.right == 1 and amberIndicators.left == 1,
  'turn indicators must remain independent during the radar off-blink phase')

local arcRadiusBeforeLights = outerLeftArcRadius
renderSettings.gt7RadarPresentation = 'classic_lights'
radarTelemetry.clock = 0
Gt7Retro.draw(radarTelemetry, renderSettings)
assert(outerLeftArcRadius == arcRadiusBeforeLights,
  'Classic-light radar presentation must not draw proximity arcs')

ui.pathArcTo, ui.pathStroke = noop, noop
ui.pathClear, ui.pathLineTo, ui.pathFillConvex, ui.drawCircleFilled = noop, noop, noop, noop

radarCars = { makeCar({ index = 3, position = { x = -4, y = 0, z = 6 } }) }
Telemetry.update(radarTelemetry, 1 / 60, Settings.current())
assert(radarTelemetry.radarLeftLevel == 0 and radarTelemetry.radarRightLevel == 0,
  'GT7 radar must ignore laterally offset cars beyond the forward allowance')
radarCars[1].position.z = Gt7Layout.radarFrontAllowance
Telemetry.update(radarTelemetry, 1 / 60, Settings.current())
assert(radarTelemetry.radarLeftLevel == 0 and radarTelemetry.radarRightLevel >= 1,
  'GT7 radar must retain a side car up to five meters ahead')
radarCars[1].position.z = Gt7Layout.radarFrontAllowance + 0.1
Telemetry.update(radarTelemetry, 1 / 60, Settings.current())
assert(radarTelemetry.radarLeftLevel == 0 and radarTelemetry.radarRightLevel == 0,
  'GT7 radar must clear a side car beyond the forward allowance')
radarCars[1].position.x, radarCars[1].position.z = 0, 3
Telemetry.update(radarTelemetry, 1 / 60, Settings.current())
assert(radarTelemetry.radarLeftLevel == 0 and radarTelemetry.radarRightLevel == 0,
  'GT7 side radar must still ignore a car directly ahead')

car, radarCars = primaryCar, {}
local metadataLoader = io.load
carId = 'missing_metadata_car'
io.load = function() return nil end
local fallbackTelemetry = Telemetry.new()
car = makeCar({ rpmLimiter = 6200 })
Telemetry.update(fallbackTelemetry, 1 / 60, Settings.current())
assert(fallbackTelemetry.speedGaugeMaximum == 320
  and fallbackTelemetry.speedGaugeSource == 'fallback',
  'missing top-speed metadata must retain the explicit speed fallback')
assert(fallbackTelemetry.rpmGaugeLimiter == 7000,
  'GT7 RPM scale must follow and round the current car limiter')
io.load = metadataLoader
carId = 'test_car'
car = primaryCar

car.ffbFinal = -1.03
Telemetry.update(telemetry, 1 / 60, Settings.current())
assert(telemetry.ffbClipping, 'absolute FFB saturation must trigger clipping')
assert(telemetry.ffbNeedle < 0.9,
  'FFB needle must preserve mechanical inertia during a sudden saturation spike')
for _ = 1, 45 do Telemetry.update(telemetry, 1 / 60, Settings.current()) end
assert(telemetry.ffbNeedle > 0.95,
  'FFB needle must reach sustained high load after its inertial sweep')

car.physicsAvailable = false
Telemetry.update(telemetry, 1 / 60, Settings.current())
assert(not telemetry.ffbAvailable and telemetry.ffbPercent == 0,
  'missing physics must use explicit FFB fallback')
assert(telemetry.ffbNeedle == 0 and telemetry.ffbNeedleVelocity == 0,
  'missing physics must park the FFB needle')
assert(not telemetry.limitAvailable and telemetry.limitNeedle == 0,
  'missing wheel physics must park LIMIT rather than estimate it')

local limitTelemetry = Telemetry.new()
car = makeCar({ ffbFinal = 0, wheels = {
  [0] = { tyreSlip = 0.16, slipRatio = 0.02, slipAngle = 0.03, load = 1 },
  [1] = { tyreSlip = 0.18, slipRatio = 0.02, slipAngle = 0.03, load = 1 },
  [2] = { tyreSlip = 0.82, slipRatio = 0.14, slipAngle = 0.03, load = 1 },
  [3] = { tyreSlip = 0.76, slipRatio = 0.12, slipAngle = 0.03, load = 1 }
} })
for _ = 1, 30 do Telemetry.update(limitTelemetry, 1 / 60, Settings.current()) end
assert(limitTelemetry.limitRear > limitTelemetry.limitFront and limitTelemetry.limitNeedle > 0.65,
  'LIMIT must prioritize the more utilized axle and retain its worst-wheel peak')
car.tractionControlInAction = true
car.absInAction = true
Telemetry.update(limitTelemetry, 1 / 60, Settings.current())
assert(limitTelemetry.limitTcWarning and limitTelemetry.limitAbsWarning,
  'TC and ABS must warn without being part of the LIMIT calculation')
car.tractionControlInAction = false
car.absInAction = false
for _ = 1, 25 do Telemetry.update(limitTelemetry, 1 / 60, Settings.current()) end
assert(not limitTelemetry.limitTcWarning and not limitTelemetry.limitAbsWarning,
  'LIMIT assist warnings must release after their visible hold')

local unavailableLimitTelemetry = Telemetry.new()
car = makeCar({ wheels = {
  [0] = { load = 1 }, [1] = { load = 1 }, [2] = { load = 1 }, [3] = { load = 1 }
} })
Telemetry.update(unavailableLimitTelemetry, 1 / 60, Settings.current())
assert(not unavailableLimitTelemetry.limitAvailable and unavailableLimitTelemetry.limitNeedle == 0,
  'LIMIT must not derive an estimate when wheel-slip telemetry is absent')

local boostTelemetry = Telemetry.new()
car = makeCar({ turboCount = 1, turboBoost = 1.2 })
Telemetry.update(boostTelemetry, 1 / 60, Settings.current())
assert(boostTelemetry.boostNeedleNormalized > 0 and boostTelemetry.boostNeedleNormalized < 0.8,
  'boost needle must preserve inertia on a sudden pressure increase')
for _ = 1, 60 do Telemetry.update(boostTelemetry, 1 / 60, Settings.current()) end
assert(boostTelemetry.boostNeedleNormalized > 0.75 and boostTelemetry.boostNeedleNormalized <= 0.81,
  'boost needle must settle at the normalized pressure')
car.turboCount = 0
Telemetry.update(boostTelemetry, 1 / 60, Settings.current())
assert(boostTelemetry.boostNeedleNormalized == 0 and boostTelemetry.boostNeedleVelocity == 0,
  'naturally aspirated cars must park the hidden boost needle')

local coefficientAero = Telemetry.new()
car = makeCar({ speedKmh = 220, aeroLiftFront = -0.8, aeroLiftRear = -1.2, aeroDrag = 0.9 })
Telemetry.update(coefficientAero, 0, Settings.current(), car)
assert(coefficientAero.aeroSource == 'csp-coefficient'
  and math.abs((coefficientAero.aeroCoefficient or 0) - 2.0) < 0.0001
  and math.abs((coefficientAero.aeroFrontShare or 0) - 0.4) < 0.0001
  and coefficientAero.aeroDownforceKN == nil,
  'CSP lift coefficients must drive the AERO gauge when force telemetry is unavailable')
assert(math.abs(coefficientAero.aeroLoadNormalized - 0.64) < 0.001,
  'coefficient-only AERO must retain speed-squared scaling against the car top speed')

local wheelAero = Telemetry.new()
local staticLoad = 1000 * 9.80665 / 4
car = makeCar({ speedKmh = 10, mass = 1000, wheels = {
  [0] = { load = staticLoad }, [1] = { load = staticLoad },
  [2] = { load = staticLoad }, [3] = { load = staticLoad }
} })
Telemetry.update(wheelAero, 0, Settings.current(), car)
car.speedKmh = 220
car.wheels[0].load, car.wheels[1].load = staticLoad + 1500, staticLoad + 1500
car.wheels[2].load, car.wheels[3].load = staticLoad + 2500, staticLoad + 2500
Telemetry.update(wheelAero, 0, Settings.current(), car)
assert(wheelAero.aeroSource == 'wheel-load'
  and math.abs((wheelAero.aeroDownforceKN or 0) - 8.0) < 0.001
  and math.abs((wheelAero.aeroFrontShare or 0) - 0.375) < 0.001,
  'wheel loads must expose actual downforce in kN and its front/rear distribution')
assert(math.abs(wheelAero.aeroLoadNormalized - (8000 / 9806.65)) < 0.001,
  'wheel-load AERO must normalize force against static vehicle weight')

-- A kerb can briefly add several vehicle weights to one or more wheel loads.
-- That suspension shock must not become a visible downforce spike.
Telemetry.update(wheelAero, 1 / 60, Settings.current(), car)
local settledAeroKN = wheelAero.aeroDownforceKN
for _ = 1, 4 do
  car.wheels[0].load, car.wheels[1].load = staticLoad + 7000, staticLoad + 7000
  car.wheels[2].load, car.wheels[3].load = staticLoad + 9000, staticLoad + 9000
  Telemetry.update(wheelAero, 1 / 60, Settings.current(), car)
end
assert(wheelAero.aeroDownforceKN < settledAeroKN + 0.5,
  'kerb load spikes must be rejected instead of flickering the AERO gauge')
car.wheels[0].load, car.wheels[1].load = staticLoad + 1500, staticLoad + 1500
car.wheels[2].load, car.wheels[3].load = staticLoad + 2500, staticLoad + 2500
for _ = 1, 6 do Telemetry.update(wheelAero, 1 / 60, Settings.current(), car) end
assert(math.abs(wheelAero.aeroDownforceKN - settledAeroKN) < 0.35,
  'AERO must settle back quickly after a kerb transient')

local visualAero = Telemetry.new()
car = makeCar({ speedKmh = 137.5 })
Telemetry.update(visualAero, 0, Settings.current(), car)
assert(visualAero.aeroSource == 'visual' and visualAero.aeroDownforceKN == nil
  and math.abs(visualAero.aeroLoadNormalized - 0.25) < 0.001,
  'AERO must fall back to the previous visual speed-squared estimate when CSP data is absent')

carId = 'replacement_car'
car = makeCar({ speedKmh = 100, aeroLiftFront = -0.5, aeroLiftRear = -0.5 })
Telemetry.update(coefficientAero, 0, Settings.current(), car)
assert(coefficientAero.aeroCoefficientPeak == 1
  and coefficientAero.aeroSource == 'csp-coefficient',
  'AERO learned peaks must reset when the active car changes')
carId = 'test_car'

car = nil
Telemetry.update(wheelAero, 0, Settings.current())
assert(wheelAero.aeroSource == 'visual' and wheelAero.aeroLoadNormalized == 0
  and wheelAero.aeroDownforceKN == nil and wheelAero.aeroCoefficient == nil,
  'disconnecting must clear AERO source, force and learned values')

local scenarios = {
  { mode = 'digital', width = 460, height = 460, car = makeCar({ gear = 0, rpm = 2000 }), unit = 'km/h' },
  { mode = 'analog', width = 740, height = 420, car = makeCar({ gear = -1, rpm = 7000 }), unit = 'mph' },
  { mode = 'gt7_retro', width = 460, height = 460, car = makeCar({ gear = 0, rpm = 4200, ffbFinal = 0 }), unit = 'km/h', scale = 0.55, speedNeedle = 'digital', rpmNeedle = 'analog' },
  { mode = 'gt7_retro', width = 900, height = 360, car = makeCar({ gear = -1, rpm = 7200, ffbFinal = 0.91 }), unit = 'mph', scale = 1.15, speedNeedle = 'analog', rpmNeedle = 'digital' },
  { mode = 'gt7_retro', width = 1200, height = 420, car = makeCar({
    turboCount = 1, turboBoost = 1.2, rpm = 7800, ffbFinal = 1.03,
    turningLeftLights = true, handbrake = 1, headlightsActive = true,
    engineLifeLeft = 600, absInAction = true
  }), unit = 'km/h', scale = 0.72, flag = 2 },
  { mode = 'gt7_retro', width = 1000, height = 420, car = makeCar({ gas = 0.82, brake = 0.36 }),
    unit = 'km/h', scale = 0.80, lowerPanel = 'pedal_history' },
  { mode = 'gt7_retro', width = 1000, height = 420, car = makeCar({ ffbFinal = 0.82 }),
    unit = 'km/h', scale = 0.80, lowerPanel = 'ffb' },
  { mode = 'gt7_retro', width = 1000, height = 420, car = makeCar({
    wheels = {
      [0] = { tyreSlip = 0.12, slipRatio = 0.01, slipAngle = 0.02, load = 1 },
      [1] = { tyreSlip = 0.14, slipRatio = 0.01, slipAngle = 0.02, load = 1 },
      [2] = { tyreSlip = 0.92, slipRatio = 0.14, slipAngle = 0.04, load = 1 },
      [3] = { tyreSlip = 0.84, slipRatio = 0.13, slipAngle = 0.04, load = 1 }
    }
  }), unit = 'km/h', scale = 0.80, lowerPanel = 'limit' },
  { mode = 'gt7_retro', width = 1000, height = 420, car = makeCar(),
    unit = 'km/h', scale = 0.80, lowerPanel = 'invisible' }
}

for _, scenario in ipairs(scenarios) do
  local values = scenario.mode == 'gt7_retro' and Gt7Settings.values or Settings.values
  Settings.values.instrumentMode = scenario.mode
  GeneralSettings.values.speedUnit = scenario.unit
  values.hudScale = scenario.scale or 0.72
  GeneralSettings.values.theme = scenario.width > 1000 and 'light' or 'dark'
  values.gt7SpeedNeedleMode = scenario.speedNeedle or values.gt7SpeedNeedleMode
  values.gt7RpmNeedleMode = scenario.rpmNeedle or values.gt7RpmNeedleMode
  values.gt7LowerPanelMode = scenario.lowerPanel or values.gt7LowerPanelMode
  sim.raceFlagType = scenario.flag
  windowWidth, windowHeight, car = scenario.width, scenario.height, scenario.car
  script.update(1 / 60)
  if scenario.mode == 'gt7_retro' then script.gt7Main() else script.windowMain() end
end

-- Exercise real telemetry/update/window callbacks for every new composition.
Settings.values.instrumentMode = 'analog'
for id in pairs(require('src/dial_variants').layouts) do
  Settings.values.analogVariant = id
  for _,mode in ipairs({'auto','turbo','electric','fuel','off'}) do
    Settings.values.analogAuxiliaryMode = mode
    car = makeCar({rpm=7100,turboCount=1,turboBoost=0.7,gear=-1})
    script.update(1/60)
    script.windowMain()
    car = nil
    script.update(1/60)
    script.windowMain()
  end
end
Settings.values.analogVariant = 'original'

assert(lastRequestedWindowSize and lastRequestedWindowSize.x >= 575
  and lastRequestedWindowSize.y <= 360,
  'GT7 Retro must widen an existing square window once when entering panoramic mode')

Settings.values.instrumentMode = 'digital'
script.windowMain()

car = nil
script.update(1 / 60)
script.windowMain()
windowWidth, windowHeight = 240, 260
script.conditionMain()
assert(type(script.conditionMain) == 'function',
  'independent car-condition window must be registered separately from the main HUD')
assert(#coreErrors == 0, table.concat(coreErrors, '\n'))

print('Runtime smoke scenarios passed')
