local U = require('src/utils')
local Layout = require('src/layout')
local Gt7Layout = require('src/gt7_retro_layout')
local PedalHistory = require('src/pedal_history')
local PedalLayers = require('src/pedal_layers')
local TyreTemperature = require('src/tyre_temperature')
local TyreGrip = require('src/tyre_grip')
local TyreReadouts = require('src/tyre_readouts')
local TyreStint = require('src/tyre_stint')
local Hybrid = require('src/hybrid')
local GearSelector = require('src/gear_selector')
local CornerGearHint = require('src/corner_gear_hint')
local FocusedCar = require('src/focused_car')

local M = {}
local SIM = ac.getSim()

local function blankWheelCondition()
  return {
    available = false,
    temperature = nil,
    temperatureCore = nil,
    temperatureInside = nil,
    temperatureMiddle = nil,
    temperatureOutside = nil,
    optimumTemperature = nil,
    optimumTemperatureMin = nil,
    optimumTemperatureMax = nil,
    temperatureRatio = nil,
    wear = 0,
    remaining = 1,
    wearAvailable = false,
    dirty = 0,
    grain = 0,
    blister = 0,
    flatSpot = 0,
    suspensionDamage = 0,
    conditionSeverity = 0,
    isBlown = false
  }
end

local function blankState()
  return {
    available = false,
    clock = 0,
    speedKmh = 0,
    speedValue = 0,
    speedText = '000',
    speedUnit = 'km/h',
    speedGaugeMaximum = 320,
    speedGaugeStep = 40,
    speedGaugeTopSpeedKmh = nil,
    speedGaugeSource = 'fallback',
    rpm = 0,
    rpmText = '0000',
    rpmLimiter = nil,
    rpmDisplayLimiter = 8000,
    rpmGaugeLimiter = 8000,
    rpmSource = 'fallback',
    rpmNormalized = 0,
    rpmGaugeNormalized = 0,
    analogNeedleNormalized = 0,
    analogNeedleVelocity = 0,
    gt7SpeedNeedleNormalized = 0,
    gt7SpeedNeedleVelocity = 0,
    gt7RpmNeedleNormalized = 0,
    gt7RpmNeedleVelocity = 0,
    fuel = nil,
    maxFuel = nil,
    fuelNormalized = 0,
    fuelNeedleNormalized = 0,
    fuelNeedleVelocity = 0,
    fuelSloshG = 0,
    fuelNeedleReady = false,
    turboAvailable = false,
    turboBoost = 0,
    turboDisplayMax = 1,
    boostNeedleNormalized = 0,
    boostNeedleVelocity = 0,
    aeroLoadNormalized = 0,
    aeroLoadPercent = 0,
    aeroSource = 'visual',
    aeroDirectAvailable = false,
    aeroWheelLoadAvailable = false,
    aeroLiftFront = nil,
    aeroLiftRear = nil,
    aeroDrag = nil,
    aeroCoefficient = nil,
    aeroCoefficientPeak = 0,
    aeroDownforceKN = nil,
    aeroDownforcePeakKN = 0,
    aeroFrontShare = nil,
    _aeroLoadScale = nil,
    _aeroStaticFrontShare = nil,
    _aeroFilteredForceN = 0,
    _aeroRawForce1 = nil,
    _aeroRawForce2 = nil,
    _aeroLastSpeedKmh = nil,
    _aeroCarKey = nil,
    rpmWarningFraction = 0.86,
    rpmRedlineFraction = 0.96,
    rpmWarning = false,
    rpmRedline = false,
    gear = 0,
    gearText = 'N',
    cornerGearHint = nil,
    gearCount = 6,
    gearCountSource = 'fallback',
    steeringInput = 0,
    steeringAngle = nil,
    steerLock = nil,
    throttle = 0,
    brake = 0,
    clutch = 0,
    handbrake = 0,
    engineLifeLeft = nil,
    engineWarning = false,
    ffbAvailable = false,
    ffbSigned = 0,
    ffbMagnitudeRaw = 0,
    ffbMagnitude = 0,
    ffbNeedle = 0,
    ffbNeedleVelocity = 0,
    ffbPercent = 0,
    ffbClipping = false,
    ffbClipHold = 0,
    limitAvailable = false,
    limitRaw = 0,
    limitFront = 0,
    limitRear = 0,
    limitPeak = 0,
    limitPeakHold = 0,
    limitNeedle = 0,
    limitTcHold = 0,
    limitAbsHold = 0,
    limitTcWarning = false,
    limitAbsWarning = false,
    limitWheels = {
      { available = false }, { available = false }, { available = false }, { available = false }
    },
    pedalHistory = PedalHistory.new(),
    tcSupported = false,
    tcLevel = nil,
    tcActive = nil,
    absSupported = false,
    absLevel = nil,
    absActive = nil,
    lightsAvailable = false,
    headlights = nil,
    steadyHeadlights = nil,
    flashingLights = nil,
    highBeams = nil,
    leftIndicator = nil,
    rightIndicator = nil,
    hazardLights = nil,
    indicatorPhase = nil,
    proximityRadarAvailable = false,
    radarLeftLevel = 0,
    radarRightLevel = 0,
    radarLeftLevel9 = 0,
    radarRightLevel9 = 0,
    raceFlagType = nil,
    pitLane = false,
    pitLimiter = nil,
    tyreStint = TyreStint.new(),
    condition = {
      available = false,
      body = { front = 0, rear = 0, left = 0, right = 0 },
      engineDamage = 0,
      gearboxDamage = 0,
      wheels = {
        blankWheelCondition(), blankWheelCondition(), blankWheelCondition(), blankWheelCondition()
      }
    }
  }
end

function M.new()
  return blankState()
end

local function gearLabel(gear)
  if gear == nil then return '—' end
  if gear == 0 then return 'N' end
  if gear == -1 then return 'R' end
  return tostring(gear)
end

local function formattedSpeed(state, value, unit)
  if state.speedValue ~= value or state.speedUnit ~= unit then
    state.speedValue = value
    state.speedUnit = unit
    state.speedText = string.format('%03d', value)
  end
end

local function formattedRpm(state, value)
  if state._rpmValue ~= value then
    state._rpmValue = value
    state.rpmText = string.format('%04d', value)
  end
end

local function formattedGear(state, value)
  if state._gearValue ~= value then
    state._gearValue = value
    state.gearText = gearLabel(value)
  end
end

local function readCarTopSpeedKmh(carId)
  if type(carId) ~= 'string' or carId == '' or type(ac.getFolder) ~= 'function'
      or ac.FolderID == nil or ac.FolderID.ContentCars == nil
      or io == nil or type(io.load) ~= 'function'
      or JSON == nil or type(JSON.parse) ~= 'function' then
    return nil
  end

  local okPath, carsFolder = pcall(ac.getFolder, ac.FolderID.ContentCars)
  if not okPath or type(carsFolder) ~= 'string' then return nil end
  local path = carsFolder .. '\\' .. carId .. '\\ui\\ui_car.json'
  local okLoad, contents = pcall(io.load, path)
  if not okLoad or type(contents) ~= 'string' then return nil end
  local okJson, metadata = pcall(JSON.parse, contents)
  if not okJson or type(metadata) ~= 'table' then return nil end

  local declared = metadata.topspeed
  if type(declared) == 'number' then return declared > 0 and declared or nil end
  if type(declared) ~= 'string' then return nil end
  local parsed = tonumber(declared:match('(%d+%.?%d*)'))
  if parsed and declared:lower():find('mph', 1, true) then parsed = parsed / 0.621371 end
  return parsed and parsed > 0 and parsed or nil
end

local function niceGaugeScale(value, minimum)
  value = math.max(value or minimum, minimum)
  local rawStep = value / 8
  local magnitude = 10 ^ math.floor(math.log(rawStep) / math.log(10))
  local normalized = rawStep / magnitude
  local stepFactor = normalized <= 1 and 1
    or (normalized <= 2 and 2
    or (normalized <= 2.5 and 2.5
    or (normalized <= 4 and 4
    or (normalized <= 5 and 5 or 10))))
  local step = stepFactor * magnitude
  return math.ceil(value / step) * step, step
end

local function updateSpeedGauge(state, settings, carIndex)
  local carId = nil
  if type(ac.getCarID) == 'function' then
    local ok, value = pcall(ac.getCarID, carIndex or 0)
    if ok and type(value) == 'string' then carId = value end
  end
  local carKey = tostring(carIndex or 0) .. '/' .. tostring(carId or '')
  if state._speedGaugeCarKey ~= carKey then
    state._speedGaugeCarKey = carKey
    state.speedGaugeTopSpeedKmh = readCarTopSpeedKmh(carId)
    state.speedGaugeSource = state.speedGaugeTopSpeedKmh and 'car-ui' or 'fallback'
  end

  local basisKmh = state.speedGaugeTopSpeedKmh or 320
  if settings.speedUnit == 'mph' then
    state.speedGaugeMaximum, state.speedGaugeStep = niceGaugeScale(basisKmh * 0.621371, 80)
  else
    state.speedGaugeMaximum, state.speedGaugeStep = niceGaugeScale(basisKmh, 160)
  end
end

local function updateAnalogNeedle(state, dt)
  local step = U.clamp(dt or 0, 0, 0.05)
  if step <= 0 then return end

  local acceleration = (state.rpmGaugeNormalized - state.analogNeedleNormalized) * Layout.analogNeedleSpring
    - state.analogNeedleVelocity * Layout.analogNeedleDamping
  local velocity = U.clamp(state.analogNeedleVelocity + acceleration * step,
    -Layout.analogNeedleMaxVelocity, Layout.analogNeedleMaxVelocity)
  local position = U.clamp(state.analogNeedleNormalized + velocity * step, 0, 1)

  if position == 0 or position == 1 then velocity = 0 end
  state.analogNeedleNormalized = position
  state.analogNeedleVelocity = velocity
end

local function springNeedle(position, velocity, target, dt, spring, damping, maximumVelocity)
  local step = U.clamp(dt or 0, 0, 0.05)
  if step <= 0 then return position, velocity end

  local acceleration = (target - position) * spring - velocity * damping
  velocity = U.clamp(velocity + acceleration * step, -maximumVelocity, maximumVelocity)
  position = U.clamp(position + velocity * step, 0, 1)
  if (position == 0 and velocity < 0) or (position == 1 and velocity > 0) then velocity = 0 end
  return position, velocity
end

local function finiteNumber(value, fallback)
  if type(value) ~= 'number' or value ~= value or value == math.huge or value == -math.huge then
    return fallback
  end
  return value
end

local function resetAero(state)
  state.aeroLoadNormalized = 0
  state.aeroLoadPercent = 0
  state.aeroSource = 'visual'
  state.aeroDirectAvailable = false
  state.aeroWheelLoadAvailable = false
  state.aeroLiftFront = nil
  state.aeroLiftRear = nil
  state.aeroDrag = nil
  state.aeroCoefficient = nil
  state.aeroCoefficientPeak = 0
  state.aeroDownforceKN = nil
  state.aeroDownforcePeakKN = 0
  state.aeroFrontShare = nil
  state._aeroLoadScale = nil
  state._aeroStaticFrontShare = nil
  state._aeroFilteredForceN = 0
  state._aeroRawForce1 = nil
  state._aeroRawForce2 = nil
  state._aeroLastSpeedKmh = nil
  state._aeroCarKey = nil
end

local function updateAero(state, car, speedKmh, settings, dt)
  local carKey = false
  if type(ac.getCarID) == 'function' then
    local ok, value = pcall(ac.getCarID, U.read(car, 'index', 0))
    if ok and type(value) == 'string' then carKey = value end
  end
  if state._aeroCarKey ~= carKey then
    resetAero(state)
    state._aeroCarKey = carKey
  end

  local referenceKmh = state.speedGaugeTopSpeedKmh
    or (settings.speedUnit == 'mph' and state.speedGaugeMaximum / 0.621371 or state.speedGaugeMaximum)
    or 300
  local speedFraction = U.clamp(speedKmh / math.max(referenceKmh, 1), 0, 1)
  local visualNormalized = speedFraction * speedFraction

  local liftFront = finiteNumber(U.read(car, 'aeroLiftFront', nil), nil)
  local liftRear = finiteNumber(U.read(car, 'aeroLiftRear', nil), nil)
  local drag = finiteNumber(U.read(car, 'aeroDrag', nil), nil)
  local frontMagnitude = liftFront and math.abs(liftFront) or 0
  local rearMagnitude = liftRear and math.abs(liftRear) or 0
  local coefficient = frontMagnitude + rearMagnitude
  local directAvailable = coefficient > 0.0001

  state.aeroLiftFront = liftFront
  state.aeroLiftRear = liftRear
  state.aeroDrag = drag
  state.aeroDirectAvailable = directAvailable
  state.aeroCoefficient = directAvailable and coefficient or nil
  if directAvailable then
    state.aeroCoefficientPeak = math.max(state.aeroCoefficientPeak or 0, coefficient)
    state.aeroFrontShare = frontMagnitude / coefficient
  end

  -- Wheel loads are the only Lua-side source here that can yield force units.
  -- Detect whether a mod reports N or kg-equivalent values, then subtract the
  -- static vehicle weight. Median conditioning plus a speed-aware slew limiter
  -- keeps kerbs and suspension compression from appearing as aero flicker.
  local mass = finiteNumber(U.read(car, 'mass', nil), nil)
  local wheels = U.read(car, 'wheels', nil)
  local rawLoads, rawFront, validLoads = 0, 0, 0
  for index = 0, 3 do
    local wheel = U.read(wheels, index, nil)
    local load = finiteNumber(U.read(wheel, 'load', nil), nil)
      or finiteNumber(U.read(wheel, 'tyreLoad', nil), nil)
      or finiteNumber(U.read(wheel, 'wheelLoad', nil), nil)
    if load and load > 0 then
      rawLoads = rawLoads + load
      if index < 2 then rawFront = rawFront + load end
      validLoads = validLoads + 1
    end
  end

  local wheelForceN, wheelFrontShare = nil, nil
  if validLoads == 4 and mass and mass > 100 then
    local staticN = mass * 9.80665
    if not state._aeroLoadScale then
      local ratioN = rawLoads / staticN
      local ratioKg = rawLoads / mass
      if ratioN > 0.55 and ratioN < 1.55 then state._aeroLoadScale = 1
      elseif ratioKg > 0.55 and ratioKg < 1.55 then state._aeroLoadScale = 9.80665 end
    end
    local scale = state._aeroLoadScale
    if scale then
      local totalN = rawLoads * scale
      local frontN = rawFront * scale
      local plausible = totalN > staticN * 0.45 and totalN < staticN * 8
      if plausible then
        state.aeroWheelLoadAvailable = true
        local rawForceN = math.max(0, totalN - staticN)
        local step = U.clamp(dt or 0, 0, 0.05)

        local conditionedForceN = rawForceN
        if state._aeroRawForce1 ~= nil and state._aeroRawForce2 ~= nil then
          local a, b, c = rawForceN, state._aeroRawForce1, state._aeroRawForce2
          if a > b then a, b = b, a end
          if b > c then b, c = c, b end
          if a > b then a, b = b, a end
          conditionedForceN = b
        end
        state._aeroRawForce2 = state._aeroRawForce1
        state._aeroRawForce1 = rawForceN

        if step <= 0 then
          state._aeroFilteredForceN = conditionedForceN
        else
          local currentForceN = state._aeroFilteredForceN or conditionedForceN
          local alpha = 1 - math.exp(-step / 0.22)
          local candidateForceN = currentForceN + (conditionedForceN - currentForceN) * alpha

          -- Real aerodynamic load follows speed squared and cannot jump as fast
          -- as a tyre load does on a kerb. Allow ordinary aero response plus the
          -- extra rate implied by a genuine speed change, while clipping shocks.
          local previousSpeedKmh = state._aeroLastSpeedKmh or speedKmh
          local speedDeltaFraction = math.abs(speedKmh - previousSpeedKmh)
            / math.max(speedKmh, previousSpeedKmh, 30)
          local speedDrivenDelta = 2 * math.max(currentForceN, staticN * 0.08) * speedDeltaFraction
          local maxDelta = staticN * 0.6 * step + speedDrivenDelta * 1.5
          state._aeroFilteredForceN = U.clamp(candidateForceN,
            math.max(0, currentForceN - maxDelta), currentForceN + maxDelta)
        end
        state._aeroLastSpeedKmh = speedKmh
        wheelForceN = math.max(0, state._aeroFilteredForceN)

        if speedKmh < 35 and math.abs(totalN - staticN) < staticN * 0.18 then
          local observedShare = U.clamp(frontN / math.max(totalN, 1), 0.2, 0.8)
          state._aeroStaticFrontShare = state._aeroStaticFrontShare
            and state._aeroStaticFrontShare + (observedShare - state._aeroStaticFrontShare) * 0.08
            or observedShare
        end
        if state._aeroStaticFrontShare then
          local frontAero = math.max(0, frontN - staticN * state._aeroStaticFrontShare)
          local rearAero = math.max(0, totalN - frontN - staticN * (1 - state._aeroStaticFrontShare))
          if frontAero + rearAero > 100 then wheelFrontShare = frontAero / (frontAero + rearAero) end
        end
      end
    end
  end
  if wheelForceN == nil then state.aeroWheelLoadAvailable = false end

  -- Some CSP builds/mods expose these fields as forces despite the Lua docs
  -- calling them coefficients. Treat only clearly force-sized values that way.
  local directForceN = directAvailable and coefficient > 20 and coefficient or nil
  local forceN = directForceN or wheelForceN
  if forceN then
    state.aeroDownforceKN = forceN / 1000
    state.aeroDownforcePeakKN = math.max(state.aeroDownforcePeakKN or 0, state.aeroDownforceKN)
    state.aeroLoadNormalized = mass and mass > 100
      and U.clamp(forceN / (mass * 9.80665), 0, 1)
      or U.clamp(forceN / math.max((state.aeroDownforcePeakKN or 0) * 1000, 1), 0, 1)
    state.aeroSource = directForceN and 'csp-force' or (directAvailable and 'wheel-load+csp' or 'wheel-load')
    if not directAvailable and wheelFrontShare then state.aeroFrontShare = wheelFrontShare end
  elseif directAvailable then
    local peak = math.max(state.aeroCoefficientPeak or coefficient, 0.0001)
    state.aeroDownforceKN = nil
    state.aeroLoadNormalized = U.clamp((coefficient / peak) * visualNormalized, 0, 1)
    state.aeroSource = 'csp-coefficient'
  else
    state.aeroDownforceKN = nil
    state.aeroLoadNormalized = visualNormalized
    state.aeroSource = 'visual'
  end
  state.aeroLoadPercent = U.round(state.aeroLoadNormalized * 100)
end

local function updateFuelNeedle(state, car, dt)
  if state.fuel == nil or state.maxFuel == nil or state.maxFuel <= 0.1 then
    state.fuelNeedleNormalized = 0
    state.fuelNeedleVelocity = 0
    state.fuelSloshG = 0
    state.fuelNeedleReady = false
    return
  end

  -- CSP exposes acceleration directly in G, in car-local axes. Treat the
  -- sender as a generic float inside the tank: longitudinal slosh dominates,
  -- while lateral G adds a smaller signed displacement. The extra filter is
  -- the fuel mass moving before the deliberately under-damped gauge reacts.
  local acceleration = U.read(car, 'acceleration', nil)
  local lateralG = U.number(U.read(acceleration, 'x', 0), 0)
  local longitudinalG = U.number(U.read(acceleration, 'z', 0), 0)
  local sloshTarget = U.clamp(-longitudinalG + lateralG * Gt7Layout.fuelSloshLateralWeight,
    -Gt7Layout.fuelSloshMaxG, Gt7Layout.fuelSloshMaxG)
  local step = U.clamp(dt or 0, 0, 0.05)
  state.fuelSloshG = state.fuelSloshG
    + (sloshTarget - state.fuelSloshG) * U.clamp(step * Gt7Layout.fuelSloshFilterRate, 0, 1)

  local fuel = state.fuelNormalized
  -- A nearly full or empty tank has less room for the float to wander. Keep a
  -- little movement at the ends, but make the effect strongest around half a tank.
  local room = 0.25 + 0.75 * U.clamp(4 * fuel * (1 - fuel), 0, 1)
  local sloshMultiplier = TyreTemperature.isGT3(car) and 1 or Gt7Layout.fuelNeedleRoadSloshMultiplier
  local target = U.clamp(
    fuel + state.fuelSloshG * Gt7Layout.fuelNeedleGResponse * sloshMultiplier * room, 0, 1)

  if not state.fuelNeedleReady then
    state.fuelNeedleNormalized = fuel
    state.fuelNeedleVelocity = 0
    state.fuelNeedleReady = true
    return
  end

  state.fuelNeedleNormalized, state.fuelNeedleVelocity = springNeedle(
    state.fuelNeedleNormalized, state.fuelNeedleVelocity, target, dt,
    Gt7Layout.fuelNeedleSpring, Gt7Layout.fuelNeedleDamping,
    Gt7Layout.fuelNeedleMaxVelocity)
end

local function resetCondition(state)
  local condition = state.condition
  condition.available = false
  condition.grip = nil
  condition.gripMeter = nil
  condition.gripDetails = nil
  condition.stint = nil
  condition.compound = nil
  condition.idealPressures = nil
  condition.temperatureWindows = nil
  condition.detailOpen = false
  condition.detailPit = false
  condition.detailAfterPit = 0
  condition.body.front = 0
  condition.body.rear = 0
  condition.body.left = 0
  condition.body.right = 0
  condition.engineDamage = 0
  condition.gearboxDamage = 0
  for _, wheel in ipairs(condition.wheels) do
    wheel.available = false
    wheel.temperature = nil
    wheel.temperatureCore = nil
    wheel.temperatureInside = nil
    wheel.temperatureMiddle = nil
    wheel.temperatureOutside = nil
    wheel.optimumTemperature = nil
    wheel.optimumTemperatureMin = nil
    wheel.optimumTemperatureMax = nil
    wheel.temperatureRatio = nil
    wheel.pressure = nil
    wheel.idealPressure = nil
    wheel.wear = 0
    wheel.remaining = 1
    wheel.wearAvailable = false
    wheel.dirty = 0
    wheel.grain = 0
    wheel.blister = 0
    wheel.flatSpot = 0
    wheel.suspensionDamage = 0
    wheel.conditionSeverity = 0
    wheel.isBlown = false
  end
end

local function normalizedDamage(value)
  return U.clamp(finiteNumber(value, 0) / 100, 0, 1)
end

local function updateCondition(state, car, dt)
  local condition = state.condition
  condition.available = true
  local simOk,sim=pcall(ac.getSim)
  local grip = TyreGrip.snapshot(car,simOk and sim or nil)
  condition.grip = grip and grip.average or nil
  condition.gripMeter = grip and grip.remaining or nil
  condition.gripDetails = grip
  condition.isGT3 = TyreTemperature.isGT3(car)
  local simState = simOk and sim or nil
  local stint = TyreStint.update(state.tyreStint, car, simState, dt)
  if not condition.stint or condition.stint.resetGeneration ~= stint.resetGeneration then
    condition.detailPit, condition.detailAfterPit = false, 0
  end
  condition.stint = stint
  local pit = U.read(car, 'isInPitlane', false) == true
  if condition.detailPit and not pit then condition.detailAfterPit = 10 end
  if pit then condition.detailAfterPit = 10
  elseif U.read(simState, 'isPaused', false) ~= true then
    condition.detailAfterPit = math.max(0, (condition.detailAfterPit or 0) - math.max(dt or 0, 0))
  end
  condition.detailPit, condition.detailOpen = pit, pit or condition.detailAfterPit > 0
  local nameFunction = ac.getTyresLongName or ac.getTyresName
  local nameOk, name = pcall(function() return nameFunction and nameFunction(U.read(car, 'index', 0)) end)
  condition.compound = nameOk and type(name) == 'string' and name ~= '' and name or (grip and grip.compound)
  local pressures = TyreReadouts.idealPressures(car)
  condition.idealPressures = pressures

  local damage = U.read(car, 'damage', nil)
  condition.body.front = normalizedDamage(U.read(damage, 0, 0))
  condition.body.rear = normalizedDamage(U.read(damage, 1, 0))
  condition.body.left = normalizedDamage(U.read(damage, 2, 0))
  condition.body.right = normalizedDamage(U.read(damage, 3, 0))

  local engineLife = finiteNumber(U.read(car, 'engineLifeLeft', nil), nil)
  condition.engineDamage = engineLife and U.clamp(1 - engineLife / 1000, 0, 1) or 0
  condition.gearboxDamage = U.clamp(finiteNumber(U.read(car, 'gearboxDamage', 0), 0), 0, 1)

  local sourceWheels = U.read(car, 'wheels', nil)
  local temperatureWindows = TyreTemperature.windows(car)
  condition.temperatureWindows = temperatureWindows
  for sourceIndex = 0, 3 do
    local source = U.read(sourceWheels, sourceIndex, nil)
    local wheel = condition.wheels[sourceIndex + 1]
    wheel.available = source ~= nil
    if source then
      local coreTemperature = finiteNumber(U.read(source, 'tyreCoreTemperature', nil), nil)
      local middleTemperature = finiteNumber(U.read(source, 'tyreMiddleTemperature', nil), nil)
      local optimum = finiteNumber(U.read(source, 'tyreOptimumTemperature', nil), nil)
      wheel.temperature = coreTemperature or middleTemperature
      wheel.temperatureCore = coreTemperature
      wheel.temperatureInside = finiteNumber(U.read(source, 'tyreInsideTemperature', nil), nil)
      wheel.temperatureMiddle = middleTemperature
      wheel.temperatureOutside = finiteNumber(U.read(source, 'tyreOutsideTemperature', nil), nil)
      wheel.optimumTemperature = optimum
      local window
      if temperatureWindows then
        if sourceIndex < 2 then window = temperatureWindows.front
        else window = temperatureWindows.rear end
      end
      wheel.optimumTemperatureMin = window and window.minimum or nil
      wheel.optimumTemperatureMax = window and window.maximum or nil
      local pressure = finiteNumber(U.read(source, 'tyrePressure', nil), nil)
      wheel.pressure = pressure and pressure > 0 and pressure or nil
      if sourceIndex < 2 then wheel.idealPressure = pressures.front
      else wheel.idealPressure = pressures.rear end
      wheel.temperatureRatio = wheel.temperature and optimum and optimum > 1
        and U.clamp(wheel.temperature / optimum, 0, 2) or nil

      local rawWear = finiteNumber(U.read(source, 'tyreWear', nil), nil)
      wheel.wearAvailable = rawWear ~= nil and rawWear >= 0
      wheel.wear = wheel.wearAvailable and U.clamp(rawWear, 0, 1) or 0
      wheel.remaining = wheel.wearAvailable and (1 - wheel.wear) or 1
      wheel.dirty = U.clamp(finiteNumber(U.read(source, 'tyreDirty', 0), 0), 0, 1)
      wheel.grain = U.clamp(finiteNumber(U.read(source, 'tyreGrain', 0), 0), 0, 1)
      wheel.blister = U.clamp(finiteNumber(U.read(source, 'tyreBlister', 0), 0), 0, 1)
      wheel.flatSpot = U.clamp(finiteNumber(U.read(source, 'tyreFlatSpot', 0), 0), 0, 1)
      wheel.suspensionDamage = U.clamp(
        finiteNumber(U.read(source, 'suspensionDamage', 0), 0), 0, 1)
      wheel.isBlown = U.read(source, 'isBlown', false) == true
      wheel.conditionSeverity = math.max(wheel.wear, wheel.dirty * 0.55, wheel.grain,
        wheel.blister, wheel.flatSpot, wheel.suspensionDamage, wheel.isBlown and 1 or 0)
    else
      wheel.temperature = nil
      wheel.temperatureCore = nil
      wheel.temperatureInside = nil
      wheel.temperatureMiddle = nil
      wheel.temperatureOutside = nil
      wheel.optimumTemperature = nil
      wheel.optimumTemperatureMin = nil
      wheel.optimumTemperatureMax = nil
      wheel.temperatureRatio = nil
      wheel.pressure = nil
      wheel.idealPressure = nil
      wheel.wear = 0
      wheel.remaining = 1
      wheel.wearAvailable = false
      wheel.dirty = 0
      wheel.grain = 0
      wheel.blister = 0
      wheel.flatSpot = 0
      wheel.suspensionDamage = 0
      wheel.conditionSeverity = 0
      wheel.isBlown = false
    end
  end
end

local function updateGt7Needles(state, speedTarget, rpmTarget, dt)
  state.gt7SpeedNeedleNormalized, state.gt7SpeedNeedleVelocity = springNeedle(
    state.gt7SpeedNeedleNormalized, state.gt7SpeedNeedleVelocity, speedTarget, dt,
    Gt7Layout.speedNeedleSpring, Gt7Layout.speedNeedleDamping, Gt7Layout.speedNeedleMaxVelocity)
  state.gt7RpmNeedleNormalized, state.gt7RpmNeedleVelocity = springNeedle(
    state.gt7RpmNeedleNormalized, state.gt7RpmNeedleVelocity, rpmTarget, dt,
    Gt7Layout.rpmNeedleSpring, Gt7Layout.rpmNeedleDamping, Gt7Layout.rpmNeedleMaxVelocity)
end

local function updateFfb(state, car, dt)
  local physicsAvailable = U.read(car, 'physicsAvailable', true)
  local raw = U.number(U.read(car, 'ffbFinal', nil), nil)
  state.ffbAvailable = raw ~= nil and physicsAvailable ~= false

  if not state.ffbAvailable then
    state.ffbSigned = 0
    state.ffbMagnitudeRaw = 0
    state.ffbMagnitude = 0
    state.ffbNeedle = 0
    state.ffbNeedleVelocity = 0
    state.ffbPercent = 0
    state.ffbClipping = false
    state.ffbClipHold = 0
    return
  end

  state.ffbSigned = raw
  state.ffbMagnitudeRaw = math.abs(raw)
  local target = U.clamp(state.ffbMagnitudeRaw, 0, 1)
  local step = U.clamp(dt or 0, 0, 0.05)
  -- Faster attack keeps impacts and clipping legible; a slightly slower
  -- release removes high-frequency chatter without making the meter feel late.
  local timeConstant = target > state.ffbMagnitude and 0.055 or 0.12
  local alpha = step > 0 and (1 - math.exp(-step / timeConstant)) or 1
  state.ffbMagnitude = state.ffbMagnitude + (target - state.ffbMagnitude) * alpha
  state.ffbPercent = U.round(U.clamp(state.ffbMagnitude, 0, 1) * 100)

  -- A spring-driven needle gives the lower gauge visible mechanical mass.
  -- It follows the real absolute ffbFinal value; clipping remains tied to the
  -- unsmoothed source below so the warning never inherits the needle delay.
  if step > 0 then
    local acceleration = (target - state.ffbNeedle) * Gt7Layout.ffbNeedleSpring
      - state.ffbNeedleVelocity * Gt7Layout.ffbNeedleDamping
    local velocity = U.clamp(state.ffbNeedleVelocity + acceleration * step,
      -Gt7Layout.ffbNeedleMaxVelocity, Gt7Layout.ffbNeedleMaxVelocity)
    local position = U.clamp(state.ffbNeedle + velocity * step, 0, 1)
    if (position == 0 and velocity < 0) or (position == 1 and velocity > 0) then velocity = 0 end
    state.ffbNeedle = position
    state.ffbNeedleVelocity = velocity
  end

  if state.ffbMagnitudeRaw >= 0.98 then
    state.ffbClipHold = 0.18
  else
    state.ffbClipHold = math.max(0, state.ffbClipHold - step)
  end
  state.ffbClipping = state.ffbClipHold > 0
end

local function resetLimit(state)
  state.limitAvailable = false
  state.limitRaw = 0
  state.limitFront = 0
  state.limitRear = 0
  state.limitPeak = 0
  state.limitPeakHold = 0
  state.limitNeedle = 0
  state.limitTcHold = 0
  state.limitAbsHold = 0
  state.limitTcWarning = false
  state.limitAbsWarning = false
  for _, wheel in ipairs(state.limitWheels) do
    wheel.available = false
    wheel.tyreSlip = nil
    wheel.slipRatio = nil
    wheel.slipAngle = nil
    wheel.load = nil
    wheel.utilization = 0
  end
end

local function firstFinite(object, keys)
  for _, key in ipairs(keys) do
    local value = finiteNumber(U.read(object, key, nil), nil)
    if value ~= nil then return value end
  end
  return nil
end

local function updateLimit(state, car, dt)
  local physicsAvailable = U.read(car, 'physicsAvailable', true)
  local sourceWheels = U.read(car, 'wheels', nil)
  local step = U.clamp(dt or 0, 0, 0.05)
  local candidates = {}
  local maximumLoad = 0

  for sourceIndex = 0, 3 do
    local source = U.read(sourceWheels, sourceIndex, nil)
    local wheel = state.limitWheels[sourceIndex + 1]
    local tyreSlip = firstFinite(source, { 'tyreSlip', 'wheelTyreSlip' })
    local slipRatio = firstFinite(source, { 'slipRatio', 'tyreSlipRatio', 'wheelSlipRatio' })
    local slipAngle = firstFinite(source, { 'slipAngle', 'tyreSlipAngle', 'wheelSlipAngle' })
    local load = firstFinite(source, { 'load', 'tyreLoad', 'wheelLoad' })

    wheel.tyreSlip = tyreSlip
    wheel.slipRatio = slipRatio
    wheel.slipAngle = slipAngle
    wheel.load = load
    wheel.utilization = 0
    wheel.available = load ~= nil and (tyreSlip ~= nil or (slipRatio ~= nil and slipAngle ~= nil))

    if wheel.available then
      maximumLoad = math.max(maximumLoad, math.max(load, 0))
      candidates[sourceIndex + 1] = wheel
    end
  end

  if physicsAvailable == false or maximumLoad <= 0 or #candidates < 2 then
    resetLimit(state)
    return
  end

  local axleUsage = { 0, 0 }
  local axleLoad = { 0, 0 }
  local worst = 0
  for index, wheel in ipairs(candidates) do
    local loadFraction = U.clamp(math.max(wheel.load, 0) / maximumLoad, 0, 1)
    if loadFraction >= Gt7Layout.limitMinimumLoadFraction then
      local direct = wheel.tyreSlip and U.clamp(math.abs(wheel.tyreSlip), 0, 1) or nil
      local ratio = wheel.slipRatio and U.clamp(math.abs(wheel.slipRatio)
        / Gt7Layout.limitSlipRatioAtLimit, 0, 1) or 0
      local angle = wheel.slipAngle and U.clamp(math.abs(wheel.slipAngle)
        / Gt7Layout.limitSlipAngleAtLimit, 0, 1) or 0
      wheel.utilization = direct or math.max(ratio, angle)
      local axle = index <= 2 and 1 or 2
      axleUsage[axle] = axleUsage[axle] + wheel.utilization * loadFraction
      axleLoad[axle] = axleLoad[axle] + loadFraction
      worst = math.max(worst, wheel.utilization)
    end
  end

  state.limitFront = axleLoad[1] > 0 and axleUsage[1] / axleLoad[1] or 0
  state.limitRear = axleLoad[2] > 0 and axleUsage[2] / axleLoad[2] or 0
  local axleTarget = math.max(state.limitFront, state.limitRear)
  if worst >= state.limitPeak then
    state.limitPeak = worst
    state.limitPeakHold = Gt7Layout.limitPeakHold
  elseif state.limitPeakHold > 0 then
    state.limitPeakHold = math.max(0, state.limitPeakHold - step)
  else
    state.limitPeak = state.limitPeak + (worst - state.limitPeak)
      * (step > 0 and (1 - math.exp(-step / Gt7Layout.limitReleaseTime)) or 1)
  end

  state.limitRaw = U.clamp(math.max(axleTarget,
    state.limitPeak * Gt7Layout.limitPeakContribution), 0, 1)
  local timeConstant = state.limitRaw > state.limitNeedle
    and Gt7Layout.limitAttackTime or Gt7Layout.limitReleaseTime
  local alpha = step > 0 and (1 - math.exp(-step / timeConstant)) or 1
  state.limitNeedle = state.limitNeedle + (state.limitRaw - state.limitNeedle) * alpha
  state.limitAvailable = true
end

local function updateLimitAssistWarnings(state, dt)
  local step = U.clamp(dt or 0, 0, 0.05)
  if state.tcActive == true then
    state.limitTcHold = Gt7Layout.limitAssistHold
  else
    state.limitTcHold = math.max(0, state.limitTcHold - step)
  end
  if state.absActive == true then
    state.limitAbsHold = Gt7Layout.limitAssistHold
  else
    state.limitAbsHold = math.max(0, state.limitAbsHold - step)
  end
  state.limitTcWarning = state.limitTcHold > 0
  state.limitAbsWarning = state.limitAbsHold > 0
end

local function vectorComponent(vector, key)
  return U.number(U.read(vector, key, nil), nil)
end

local function updateProximityRadar(state, focusedCar, settings)
  state.proximityRadarAvailable = false
  state.radarLeftLevel = 0
  state.radarRightLevel = 0
  state.radarLeftLevel9 = 0
  state.radarRightLevel9 = 0

  -- The radar is specific to the GT7 panoramic layout. Keep the old turn
  -- indicators available in every other instrument mode and on CSP builds
  -- that do not expose the full-grid iterator.
  if settings.instrumentMode ~= 'gt7_retro' then return end

  local ok = pcall(function()
    local position = U.read(focusedCar, 'position', nil)
    local look = U.read(focusedCar, 'look', nil)
    local px, pz = vectorComponent(position, 'x'), vectorComponent(position, 'z')
    local lookX, lookZ = vectorComponent(look, 'x'), vectorComponent(look, 'z')
    if not px or not pz or not lookX or not lookZ then return end

    local lookLength = math.sqrt(lookX * lookX + lookZ * lookZ)
    if lookLength < 0.0001 then return end
    lookX, lookZ = lookX / lookLength, lookZ / lookLength

    -- AC's horizontal right axis is the heading rotated toward negative X
    -- when the car faces positive Z. Keep this sign aligned with the HUD.
    local sideX, sideZ = -lookZ, lookX

    local focusedIndex = U.number(U.read(focusedCar, 'index', 0), 0)
    local playerSize = U.read(focusedCar, 'aabbSize', nil)
    local playerLength = math.max(2, math.abs(vectorComponent(playerSize, 'z') or 4.5))
    local foundGridData = false

    for _, opponent in ac.iterateCars() do
      local index = U.number(U.read(opponent, 'index', -1), -1)
      local usable = index >= 0 and index ~= focusedIndex and (U.read(opponent, 'isConnected', false)
        or U.read(opponent, 'isActive', false))
      local opponentPosition = U.read(opponent, 'position', nil)
      local ox, oz = vectorComponent(opponentPosition, 'x'), vectorComponent(opponentPosition, 'z')
      if usable and ox and oz then
        foundGridData = true
        local dx, dz = ox - px, oz - pz
        local distance = math.sqrt(dx * dx + dz * dz)
        local longitudinal = dx * lookX + dz * lookZ
        -- Keep a short forward allowance so the side warning does not vanish
        -- as soon as the other car's center passes the player's center.
        if distance <= Gt7Layout.radarRange
            and longitudinal <= Gt7Layout.radarFrontAllowance then
          local lateral = dx * sideX + dz * sideZ
          local lateralAbs = math.abs(lateral)
          if lateralAbs >= Gt7Layout.radarMinLateral
              and lateralAbs <= Gt7Layout.radarMaxLateral then
            local opponentSize = U.read(opponent, 'aabbSize', nil)
            local opponentLength = math.max(2, math.abs(vectorComponent(opponentSize, 'z') or 4.5))
            local overlapLength = (playerLength + opponentLength) * 0.5
            local level = distance <= Gt7Layout.radarNearRange and 2 or 1
            if math.abs(longitudinal) <= overlapLength
                and distance <= Gt7Layout.radarAlongsideRange then
              level = 3
            end
            -- Subdivide each existing warning band into three steps. The
            -- alongside band also follows longitudinal overlap, so a close
            -- car behind us cannot light the red lamps prematurely.
            local progress
            if level == 1 then
              progress = (Gt7Layout.radarRange - distance)
                / (Gt7Layout.radarRange - Gt7Layout.radarNearRange)
            elseif level == 2 then
              local alongsideDistance = math.min(Gt7Layout.radarAlongsideRange,
                math.sqrt(overlapLength * overlapLength + lateralAbs * lateralAbs))
              progress = (Gt7Layout.radarNearRange - distance)
                / (Gt7Layout.radarNearRange - alongsideDistance)
            else
              progress = 1 - math.max(math.abs(longitudinal) / overlapLength,
                (distance - Gt7Layout.radarMinLateral)
                  / (Gt7Layout.radarAlongsideRange - Gt7Layout.radarMinLateral))
            end
            local level9 = (level - 1) * 3 + 1
              + math.min(2, math.floor(math.max(0, progress) * 3))
            if lateral < 0 then
              state.radarLeftLevel = math.max(state.radarLeftLevel, level)
              state.radarLeftLevel9 = math.max(state.radarLeftLevel9, level9)
            else
              state.radarRightLevel = math.max(state.radarRightLevel, level)
              state.radarRightLevel9 = math.max(state.radarRightLevel9, level9)
            end
          end
        end
      end
    end

    state.proximityRadarAvailable = foundGridData
  end)

  if not ok then
    state.proximityRadarAvailable = false
    state.radarLeftLevel = 0
    state.radarRightLevel = 0
    state.radarLeftLevel9 = 0
    state.radarRightLevel9 = 0
  end
end

local function resetFocusedCarState(state)
  PedalHistory.clear(state.pedalHistory)
  PedalLayers.reset(state)
  CornerGearHint.reset(state)
  state.tyreStint = TyreStint.new()
  resetAero(state)
  resetCondition(state)
  resetLimit(state)
  state.hybrid = nil
  state._speedGaugeCarKey = nil
  state._gearCountCarKey, state._observedGearCount = nil, 0
  state.analogNeedleNormalized, state.analogNeedleVelocity = 0, 0
  state.gt7SpeedNeedleNormalized, state.gt7SpeedNeedleVelocity = 0, 0
  state.gt7RpmNeedleNormalized, state.gt7RpmNeedleVelocity = 0, 0
  state.fuelNeedleNormalized, state.fuelNeedleVelocity, state.fuelNeedleReady = 0, 0, false
  state.boostNeedleNormalized, state.boostNeedleVelocity = 0, 0
  state.ffbMagnitude, state.ffbNeedle, state.ffbNeedleVelocity = 0, 0, 0
  state.ffbClipHold, state.ffbClipping = 0, false
end

-- Optional read-only sample car is used by the isolated instrument preview.
-- Live callers retain the same source and processing path.
function M.update(state, dt, settings, sampleCar, sampleCarIndex)
  state.clock = state.clock + math.max(dt or 0, 0)
  state.raceFlagType = U.read(SIM, 'raceFlagType', nil)

  local car, carIndex
  if sampleCar == false then
    car, carIndex = nil, sampleCarIndex
  elseif sampleCar ~= nil then
    car = sampleCar
    carIndex = sampleCarIndex or U.number(U.read(car, 'index', 0), 0)
  else
    car, carIndex = FocusedCar.resolve(SIM)
  end
  local carIdentity = FocusedCar.identity(car, carIndex)
  if state._focusedCarIdentity ~= carIdentity then
    state._focusedCarIdentity = carIdentity
    resetFocusedCarState(state)
  end
  state.focusedCarIndex = car and carIndex or nil
  if not car then
    state.available = false
    state.gearCount, state.gearCountSource = 6, 'fallback'
    state._gearCountCarKey, state._observedGearCount = nil, 0
    state.hybrid = nil
    CornerGearHint.reset(state)
    state.lightsAvailable = false
    state.headlights, state.steadyHeadlights, state.flashingLights, state.highBeams = nil, nil, nil, nil
    state.ffbAvailable = false
    state.ffbSigned = 0
    state.ffbMagnitudeRaw = 0
    state.ffbMagnitude = 0
    state.ffbNeedle = 0
    state.ffbNeedleVelocity = 0
    state.ffbPercent = 0
    state.ffbClipping = false
    state.ffbClipHold = 0
    resetLimit(state)
    state.gt7SpeedNeedleNormalized = 0
    state.gt7SpeedNeedleVelocity = 0
    state.gt7RpmNeedleNormalized = 0
    state.gt7RpmNeedleVelocity = 0
    state.boostNeedleNormalized = 0
    state.boostNeedleVelocity = 0
    resetAero(state)
    state.proximityRadarAvailable = false
    state.radarLeftLevel = 0
    state.radarRightLevel = 0
    state.radarLeftLevel9 = 0
    state.radarRightLevel9 = 0
    PedalHistory.clear(state.pedalHistory)
    PedalLayers.reset(state)
    TyreStint.update(state.tyreStint, nil, SIM, dt)
    resetCondition(state)
    return
  end

  state.available = true

  local speedKmh = math.max(U.number(U.read(car, 'speedKmh', 0), 0), 0)
  local speedValue = U.round(settings.speedUnit == 'mph' and speedKmh * 0.621371 or speedKmh)
  formattedSpeed(state, speedValue, settings.speedUnit)
  state.speedKmh = speedKmh
  updateSpeedGauge(state, settings, carIndex)
  updateAero(state, car, speedKmh, settings, dt)

  state.rpm = math.max(U.number(U.read(car, 'rpm', 0), 0), 0)
  local carLimiter = U.number(U.read(car, 'rpmLimiter', nil), nil)
  if carLimiter and carLimiter > 1000 then
    state.rpmLimiter = carLimiter
    state.rpmDisplayLimiter = carLimiter
    state.rpmSource = 'car'
  else
    state.rpmLimiter = nil
    state.rpmDisplayLimiter = math.max(settings.fallbackRpm, 1000)
    state.rpmSource = 'fallback'
  end
  -- Keep the car's exact limiter for alert thresholds, but round the visual
  -- gauge up to the next whole thousand so a 7.5k engine gets a clean 8k
  -- endpoint and the needle/arc can stop between 7 and 8.
  state.rpmGaugeLimiter = math.max(math.ceil(state.rpmDisplayLimiter / 1000) * 1000, 1000)
  state.rpmNormalized = U.clamp(state.rpm / state.rpmDisplayLimiter, 0, 1)
  state.rpmGaugeNormalized = U.clamp(state.rpm / state.rpmGaugeLimiter, 0, 1)
  state.rpmWarningFraction = settings.rpmWarningFraction
  state.rpmRedlineFraction = settings.rpmRedlineFraction
  state.rpmWarning = state.rpmNormalized >= settings.rpmWarningFraction
  state.rpmRedline = state.rpmNormalized >= settings.rpmRedlineFraction
  updateAnalogNeedle(state, dt)
  updateGt7Needles(state, U.clamp(state.speedValue / state.speedGaugeMaximum, 0, 1),
    state.rpmGaugeNormalized, dt)
  formattedRpm(state, U.round(state.rpm))

  state.gear = U.number(U.read(car, 'gear', 0), 0)
  formattedGear(state, state.gear)
  CornerGearHint.update(state, car, SIM, dt, settings.cornerGearHint)
  -- gearCount excludes N/R and is only meaningful with physics access.
  local count = U.read(car, 'physicsAvailable', nil) ~= false and U.read(car, 'gearCount', nil) or nil
  GearSelector.observe(state, count, state.gear, state._speedGaugeCarKey)

  local steerAngle = U.number(U.read(car, 'steer', nil), nil)
  local steerLock = U.number(U.read(car, 'steerLock', nil), nil)
  local steeringInput = nil
  if steerAngle and steerLock and math.abs(steerLock) > 0.1 then
    steeringInput = U.clamp(steerAngle / steerLock, -1, 1)
  else
    if carIndex == 0 and U.read(SIM, 'isReplayActive', false) ~= true then
      local ok, controllerSteer = pcall(ac.getControllerSteerValue)
      if ok and type(controllerSteer) == 'number' then
        steeringInput = U.clamp(controllerSteer, -1, 1)
      end
    end
  end
  state.steeringInput = steeringInput or 0
  state.steeringAngle = steerAngle
  state.steerLock = steerLock

  state.throttle = U.clamp(U.number(U.read(car, 'gas', 0), 0), 0, 1)
  state.brake = U.clamp(U.number(U.read(car, 'brake', 0), 0), 0, 1)
  local rawClutch = U.number(U.read(car, 'clutch', nil), nil)
  state.clutch = rawClutch and U.clamp(1 - rawClutch, 0, 1) or 0
  state.handbrake = U.clamp(U.number(U.read(car, 'handbrake', 0), 0), 0, 1)
  PedalHistory.update(state.pedalHistory, dt, state.throttle, state.brake)
  state.engineLifeLeft = U.number(U.read(car, 'engineLifeLeft', nil), nil)
  state.engineWarning = state.engineLifeLeft ~= nil and state.engineLifeLeft < 850
  updateCondition(state, car, dt)
  updateFfb(state, car, dt)
  updateLimit(state, car, dt)

  state.fuel = U.number(U.read(car, 'fuel', nil), nil)
  state.maxFuel = U.number(U.read(car, 'maxFuel', nil), nil)
  state.fuelNormalized = state.fuel and state.maxFuel and state.maxFuel > 0.1
    and U.clamp(state.fuel / state.maxFuel, 0, 1) or 0
  updateFuelNeedle(state, car, dt)
  local turboCount = U.number(U.read(car, 'turboCount', 0), 0)
  state.turboAvailable = turboCount > 0
  state.turboBoost = math.max(0, U.number(U.read(car, 'turboBoost', 0), 0))
  if state.turboAvailable then
    state.turboDisplayMax = math.max(state.turboDisplayMax, 1, math.ceil(state.turboBoost * 2) / 2)
    local boostTarget = U.clamp(state.turboBoost / math.max(state.turboDisplayMax, 0.1), 0, 1)
    state.boostNeedleNormalized, state.boostNeedleVelocity = springNeedle(
      state.boostNeedleNormalized, state.boostNeedleVelocity, boostTarget, dt,
      Gt7Layout.boostNeedleSpring, Gt7Layout.boostNeedleDamping,
      Gt7Layout.boostNeedleMaxVelocity)
  else
    state.turboDisplayMax = 1
    state.boostNeedleNormalized = 0
    state.boostNeedleVelocity = 0
  end

  Hybrid.update(state, car, dt or 0)

  local tcModes = U.number(U.read(car, 'tractionControlModes', nil), nil)
  state.tcSupported = tcModes ~= nil and tcModes > 0
  state.tcLevel = state.tcSupported and U.number(U.read(car, 'tractionControlMode', nil), nil) or nil
  if state.tcSupported then
    state.tcActive = U.read(car, 'tractionControlInAction', nil)
  else
    state.tcActive = nil
  end

  local absModes = U.number(U.read(car, 'absModes', nil), nil)
  state.absSupported = absModes ~= nil and absModes > 0
  state.absLevel = state.absSupported and U.number(U.read(car, 'absMode', nil), nil) or nil
  if state.absSupported then
    state.absActive = U.read(car, 'absInAction', nil)
  else
    state.absActive = nil
  end
  updateLimitAssistWarnings(state, dt)
  PedalLayers.update(state, car, SIM, dt)

  local headlights = U.read(car, 'headlightsActive', nil)
  local flashing = U.read(car, 'flashingLightsActive', nil)
  local highBeams = U.read(car, 'highBeams', nil)
  local lowBeams = U.read(car, 'lowBeams', nil)
  if highBeams == nil and headlights ~= nil and lowBeams ~= nil then
    highBeams = headlights and not lowBeams
  end
  if flashing == nil and headlights == false and highBeams ~= nil then flashing = highBeams end
  state.flashingLights = flashing
  state.highBeams = flashing == true or highBeams
  state.lightsAvailable = headlights ~= nil or flashing ~= nil or highBeams ~= nil
  state.steadyHeadlights = headlights == true or (highBeams == true and flashing ~= true)
  if state.lightsAvailable then
    state.headlights = state.steadyHeadlights or flashing == true or highBeams == true
  else state.headlights = nil end

  state.leftIndicator = U.read(car, 'turningLeftLights', nil)
  state.rightIndicator = U.read(car, 'turningRightLights', nil)
  state.hazardLights = U.read(car, 'hazardLights', nil)
  state.indicatorPhase = U.read(car, 'turningLightsActivePhase', nil)

  updateProximityRadar(state, car, settings)

  state.pitLane = U.read(car, 'isInPit', false) or U.read(car, 'isInPitlane', false)

  -- CSP exposes the driver's manual limiter selection and the final in-action
  -- state separately. Prefer the selection so the telltale stays lit while
  -- enabled, with the in-action flag as a compatibility fallback.
  local manualLimiter = U.read(car, 'manualPitsSpeedLimiterEnabled', nil)
  if manualLimiter ~= nil then
    state.pitLimiter = manualLimiter
  else
    state.pitLimiter = U.read(car, 'speedLimiterInAction', nil)
  end
end

return M
