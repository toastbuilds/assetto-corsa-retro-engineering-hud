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
  slider = function(_, value) return value, false end,
  button = function() return false end
}

-- This smoke test exercises the app's core windows; external panels have
-- separate runtimes and need not emulate their full CSP surface here.
for _, name in ipairs({ 'relative', 'delta', 'leaderboard', 'telemetry', 'map' }) do
  package.preload['modules/' .. name .. '/main'] = function()
    return { getTemperatureUnit = function() return 'C' end, update = noop }
  end
end
script = {}
require('app')
local Settings = require('src/settings')
local Gt7Settings = require('src/gt7_settings')
local Telemetry = require('src/telemetry')
local Gt7Retro = require('ui/gt7_retro')
local Theme = require('src/theme')
local DialLayout = require('src/layout')
local Gt7Layout = require('src/gt7_retro_layout')

assert(Settings.values.instrumentMode == 'analog', 'v5 migration must preserve analog')
assert(Settings.values.layoutVersion == 9, 'v9 migration must complete')
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
assert(Gt7Settings.values.gt7RadarStyle == 'arcs', 'GT7 radar must default to arcs')
pendingCombos['##gt7.radarStyle'] = 1
Gt7Settings.draw()
assert(Gt7Settings.values.gt7RadarStyle == 'lights', 'indicator radar option must enable arrow and dots')
pendingCombos['##gt7.radarStyle'] = 0
Gt7Settings.draw()
assert(Gt7Settings.values.gt7RadarStyle == 'arcs', 'indicator radar option must restore arcs')
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
car = makeCar({ ffbFinal = 0.62 })
for _ = 1, 30 do Telemetry.update(telemetry, 1 / 60, Settings.values) end
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

Settings.values.speedUnit = 'mph'
Telemetry.update(telemetry, 1 / 60, Settings.values)
assert(telemetry.speedGaugeMaximum == 175 and telemetry.speedGaugeStep == 25,
  'GT7 speed scale must rebuild cleanly for mph')
Settings.values.speedUnit = 'km/h'

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
Telemetry.update(radarTelemetry, 1 / 60, Settings.values)
assert(radarTelemetry.proximityRadarAvailable
  and radarTelemetry.radarLeftLevel == 3
  and radarTelemetry.radarRightLevel == 2,
  'GT7 radar must distinguish alongside traffic from a close offset car')

local leftRedArcs = 0
local lastArcX
local outerLeftArcRadius = 0
local gearPodWidth, gearPodCenter
local radarArcCalls = 0
local indicatorTriangles = { left = 0, right = 0 }
local amberIndicators = { left = 0, right = 0 }
local flagLampHits = { left = 0, right = 0 }
local pathPoints = {}
ui.drawCircleFilled = function(center, _, color)
  if color == Theme.get('dark').flagYellow then
    if math.abs(center.x - (Gt7Layout.indicatorLeftX + Gt7Layout.flagLampSideOffset)) < 0.01 then
      flagLampHits.left = flagLampHits.left + 1
    elseif math.abs(center.x - (Gt7Layout.indicatorRightX - Gt7Layout.flagLampSideOffset)) < 0.01 then
      flagLampHits.right = flagLampHits.right + 1
    end
  end
end
ui.pathClear = function() pathPoints = {}; lastArcX = nil end
ui.pathLineTo = function(position) pathPoints[#pathPoints + 1] = position end
ui.pathFillConvex = function(color)
  if #pathPoints == 8 and math.abs(pathPoints[1].y - Gt7Layout.gearPodTop) < 0.01 then
    local minimum, maximum = pathPoints[1].x, pathPoints[1].x
    for _, position in ipairs(pathPoints) do
      minimum = math.min(minimum, position.x)
      maximum = math.max(maximum, position.x)
    end
    gearPodWidth = maximum - minimum
    gearPodCenter = (maximum + minimum) / 2
  elseif #pathPoints == 3 then
    local x = pathPoints[1].x
    if math.abs(x - (Gt7Layout.indicatorLeftX - 13)) < 0.01 then
      indicatorTriangles.left = indicatorTriangles.left + 1
      if color == Theme.get('dark').amber then
        amberIndicators.left = amberIndicators.left + 1
      end
    elseif math.abs(x - (Gt7Layout.indicatorRightX + 13)) < 0.01 then
      indicatorTriangles.right = indicatorTriangles.right + 1
      if color == Theme.get('dark').amber then
        amberIndicators.right = amberIndicators.right + 1
      end
    end
  end
end
ui.pathArcTo = function(center, radius, startAngle, endAngle)
  lastArcX = center.x
  local left = math.abs(center.x - Gt7Layout.radarArcLeftX) < 0.01
  local right = math.abs(center.x - Gt7Layout.radarArcRightX) < 0.01
  if left then
    outerLeftArcRadius = math.max(outerLeftArcRadius, radius)
  end
  if left or right then
    assert(math.abs(endAngle - startAngle - math.pi / 2) < 0.01,
      'each radar ring must remain a complete quarter arc')
    assert(math.abs(center.y - Gt7Layout.radarArcY) < 0.01,
      'all three radar rings must share one center')
    for step = 0, 20 do
      local angle = startAngle + (endAngle - startAngle) * step / 20
      local x = center.x + radius * math.cos(angle)
      local y = center.y + radius * math.sin(angle)
      local inset = left and x - Gt7Layout.centerLeft or Gt7Layout.centerRight - x
      local panelBottom = math.min(Gt7Layout.centerBottom,
        Gt7Layout.centerBottom - Gt7Layout.centerBackdropChamfer
        + Gt7Layout.centerBackdropChamfer * inset
        / (Gt7Layout.centerBackdropBottomInset + Gt7Layout.centerBackdropChamfer))
      assert(inset >= 6 and panelBottom - y >= 6,
        'every radar ring must stay inside the panel with room for its glow')
    end
    radarArcCalls = radarArcCalls + 1
  end
end
ui.pathStroke = function(color)
  if lastArcX and math.abs(lastArcX - Gt7Layout.radarArcLeftX) < 0.01
      and color == Theme.get('dark').red then
    leftRedArcs = leftRedArcs + 1
  end
end
Settings.values.gt7RadarStyle = 'arcs'
Settings.values.theme = 'dark'
Settings.values.hudScale = 0.72
windowWidth, windowHeight = Gt7Layout.width, Gt7Layout.height
radarTelemetry.clock = 0
Gt7Retro.draw(radarTelemetry, Settings.values)
assert(leftRedArcs == 3, 'all three nearby arcs must illuminate together')
assert(gearPodWidth == Gt7Layout.gearPodHalfWidth * 2
  and gearPodCenter == Gt7Layout.gearPodCenterX and gearPodCenter == 875,
  'gear pod must stay compact in its right-side position')
assert(Gt7Layout.radarArcRightX
  - (Gt7Layout.radarArcFirstRadius + 2 * Gt7Layout.radarArcRadiusStep)
  - (gearPodCenter + gearPodWidth / 2) >= 12,
  'gear pod must leave visible clearance before the right radar arc')
assert(outerLeftArcRadius == 56 and radarArcCalls >= 6,
  'the reference-style radar arcs must be visible on both sides')
assert(indicatorTriangles.left == 0 and indicatorTriangles.right == 0,
  'arcs must replace indicators only on sides with nearby cars')
leftRedArcs = 0
radarTelemetry.clock = Gt7Layout.radarBlinkPeriod
Gt7Retro.draw(radarTelemetry, Settings.values)
assert(leftRedArcs == 0, 'all three nearby arcs must extinguish together on blink')
assert(gearPodWidth == Gt7Layout.gearPodHalfWidth * 2,
  'gear pod must not change size during a radar blink')
radarTelemetry.radarLeftLevel, radarTelemetry.radarRightLevel = 0, 0
radarTelemetry.raceFlagType, radarTelemetry.clock = 2, 0
radarTelemetry.leftIndicator, radarTelemetry.rightIndicator = true, false
indicatorTriangles.left, indicatorTriangles.right = 0, 0
Gt7Retro.draw(radarTelemetry, Settings.values)
assert(gearPodWidth == Gt7Layout.gearPodHalfWidth * 2,
  'gear pod must remain compact when the arc radar has no nearby cars')
assert(indicatorTriangles.left == 1 and indicatorTriangles.right == 1,
  'both default indicators must appear with no nearby cars')
assert(flagLampHits.left == 2 and flagLampHits.right == 2,
  'default flag lamps must remain visible while radar is ready')
assert(amberIndicators.left == 1 and amberIndicators.right == 0,
  'default turn indicators must follow the correct side')
radarTelemetry.radarLeftLevel = 3
indicatorTriangles.left, indicatorTriangles.right = 0, 0
flagLampHits.left, flagLampHits.right = 0, 0
Gt7Retro.draw(radarTelemetry, Settings.values)
assert(indicatorTriangles.left == 0 and indicatorTriangles.right == 1,
  'a nearby car must replace only its own side indicator with arcs')
assert(flagLampHits.left == 0 and flagLampHits.right == 2,
  'a nearby car must hide flag lamps only on its own side')
radarTelemetry.radarLeftLevel, radarTelemetry.radarRightLevel = 3, 2
radarTelemetry.raceFlagType = nil
radarTelemetry.leftIndicator = false
Settings.values.gt7RadarStyle = 'lights'
local arcCountBeforeIndicatorRadar = radarArcCalls
Gt7Retro.draw(radarTelemetry, Settings.values)
assert(gearPodWidth == Gt7Layout.gearPodHalfWidth * 2,
  'gear pod must keep its compact width with the indicator radar style')
assert(radarArcCalls == arcCountBeforeIndicatorRadar,
  'indicator radar option must use lights instead of arcs')
local leftRedTriangle, leftRedDots = 0, 0
local pathTouchesLeftIndicator = false
ui.pathClear = function() pathTouchesLeftIndicator = false end
ui.pathLineTo = function(position)
  if position.x > 445 and position.x < 475 and position.y > 245 and position.y < 275 then
    pathTouchesLeftIndicator = true
  end
end
ui.pathFillConvex = function(color)
  if pathTouchesLeftIndicator and color == Theme.get('dark').red then
    leftRedTriangle = leftRedTriangle + 1
  end
end
ui.drawCircleFilled = function(center, _, color)
  if math.abs(center.x - (Gt7Layout.indicatorLeftX + Gt7Layout.flagLampSideOffset)) < 0.01
      and color == Theme.get('dark').red then
    leftRedDots = leftRedDots + 1
  end
end
radarTelemetry.clock = 0
Gt7Retro.draw(radarTelemetry, Settings.values)
assert(leftRedTriangle == 1 and leftRedDots == 2,
  'arrow and both dots must illuminate together for a car alongside')
leftRedTriangle, leftRedDots = 0, 0
radarTelemetry.clock = Gt7Layout.radarBlinkPeriod
Gt7Retro.draw(radarTelemetry, Settings.values)
assert(leftRedTriangle == 0 and leftRedDots == 0,
  'arrow and both dots must extinguish together on blink')
ui.pathArcTo, ui.pathStroke = noop, noop
ui.pathClear, ui.pathLineTo, ui.pathFillConvex, ui.drawCircleFilled = noop, noop, noop, noop

radarCars = { makeCar({ index = 3, position = { x = -4, y = 0, z = 6 } }) }
Telemetry.update(radarTelemetry, 1 / 60, Settings.values)
assert(radarTelemetry.radarLeftLevel == 0 and radarTelemetry.radarRightLevel == 0,
  'GT7 radar must ignore laterally offset cars beyond the forward allowance')
radarCars[1].position.z = Gt7Layout.radarFrontAllowance
Telemetry.update(radarTelemetry, 1 / 60, Settings.values)
assert(radarTelemetry.radarLeftLevel == 0 and radarTelemetry.radarRightLevel >= 1,
  'GT7 radar must retain a side car up to five meters ahead')
radarCars[1].position.z = Gt7Layout.radarFrontAllowance + 0.1
Telemetry.update(radarTelemetry, 1 / 60, Settings.values)
assert(radarTelemetry.radarLeftLevel == 0 and radarTelemetry.radarRightLevel == 0,
  'GT7 radar must clear a side car beyond the forward allowance')
radarCars[1].position.x, radarCars[1].position.z = 0, 3
Telemetry.update(radarTelemetry, 1 / 60, Settings.values)
assert(radarTelemetry.radarLeftLevel == 0 and radarTelemetry.radarRightLevel == 0,
  'GT7 side radar must still ignore a car directly ahead')

car, radarCars = primaryCar, {}
local metadataLoader = io.load
carId = 'missing_metadata_car'
io.load = function() return nil end
local fallbackTelemetry = Telemetry.new()
car = makeCar({ rpmLimiter = 6200 })
Telemetry.update(fallbackTelemetry, 1 / 60, Settings.values)
assert(fallbackTelemetry.speedGaugeMaximum == 320
  and fallbackTelemetry.speedGaugeSource == 'fallback',
  'missing top-speed metadata must retain the explicit speed fallback')
assert(fallbackTelemetry.rpmGaugeLimiter == 7000,
  'GT7 RPM scale must follow and round the current car limiter')
io.load = metadataLoader
carId = 'test_car'
car = primaryCar

car.ffbFinal = -1.03
Telemetry.update(telemetry, 1 / 60, Settings.values)
assert(telemetry.ffbClipping, 'absolute FFB saturation must trigger clipping')
assert(telemetry.ffbNeedle < 0.9,
  'FFB needle must preserve mechanical inertia during a sudden saturation spike')
for _ = 1, 45 do Telemetry.update(telemetry, 1 / 60, Settings.values) end
assert(telemetry.ffbNeedle > 0.95,
  'FFB needle must reach sustained high load after its inertial sweep')

car.physicsAvailable = false
Telemetry.update(telemetry, 1 / 60, Settings.values)
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
for _ = 1, 30 do Telemetry.update(limitTelemetry, 1 / 60, Settings.values) end
assert(limitTelemetry.limitRear > limitTelemetry.limitFront and limitTelemetry.limitNeedle > 0.65,
  'LIMIT must prioritize the more utilized axle and retain its worst-wheel peak')
car.tractionControlInAction = true
car.absInAction = true
Telemetry.update(limitTelemetry, 1 / 60, Settings.values)
assert(limitTelemetry.limitTcWarning and limitTelemetry.limitAbsWarning,
  'TC and ABS must warn without being part of the LIMIT calculation')
car.tractionControlInAction = false
car.absInAction = false
for _ = 1, 25 do Telemetry.update(limitTelemetry, 1 / 60, Settings.values) end
assert(not limitTelemetry.limitTcWarning and not limitTelemetry.limitAbsWarning,
  'LIMIT assist warnings must release after their visible hold')

local unavailableLimitTelemetry = Telemetry.new()
car = makeCar({ wheels = {
  [0] = { load = 1 }, [1] = { load = 1 }, [2] = { load = 1 }, [3] = { load = 1 }
} })
Telemetry.update(unavailableLimitTelemetry, 1 / 60, Settings.values)
assert(not unavailableLimitTelemetry.limitAvailable and unavailableLimitTelemetry.limitNeedle == 0,
  'LIMIT must not derive an estimate when wheel-slip telemetry is absent')

local boostTelemetry = Telemetry.new()
car = makeCar({ turboCount = 1, turboBoost = 1.2 })
Telemetry.update(boostTelemetry, 1 / 60, Settings.values)
assert(boostTelemetry.boostNeedleNormalized > 0 and boostTelemetry.boostNeedleNormalized < 0.8,
  'boost needle must preserve inertia on a sudden pressure increase')
for _ = 1, 60 do Telemetry.update(boostTelemetry, 1 / 60, Settings.values) end
assert(boostTelemetry.boostNeedleNormalized > 0.75 and boostTelemetry.boostNeedleNormalized <= 0.81,
  'boost needle must settle at the normalized pressure')
car.turboCount = 0
Telemetry.update(boostTelemetry, 1 / 60, Settings.values)
assert(boostTelemetry.boostNeedleNormalized == 0 and boostTelemetry.boostNeedleVelocity == 0,
  'naturally aspirated cars must park the hidden boost needle')

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
  Settings.values.speedUnit = scenario.unit
  values.hudScale = scenario.scale or 0.72
  Settings.values.theme = scenario.width > 1000 and 'light' or 'dark'
  values.gt7SpeedNeedleMode = scenario.speedNeedle or values.gt7SpeedNeedleMode
  values.gt7RpmNeedleMode = scenario.rpmNeedle or values.gt7RpmNeedleMode
  values.gt7LowerPanelMode = scenario.lowerPanel or values.gt7LowerPanelMode
  sim.raceFlagType = scenario.flag
  windowWidth, windowHeight, car = scenario.width, scenario.height, scenario.car
  script.update(1 / 60)
  if scenario.mode == 'gt7_retro' then script.gt7Main() else script.windowMain() end
end

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
