local U = require('src/utils')

local M = {}
local geometryCache = {}
local drivetrainCache = {}

local LATERAL_G = 0.9
local BRAKING_DECELERATION = 5
local RED_DIFFERENTIAL_MS = 10 / 3.6
local RPM_SAFETY_FRACTION = 0.90
local CORNER_EARLY_ENTRY_METERS = 200
local LOG_INTERVAL_SECONDS = 10
local MIN_LOG_INTERVAL_SECONDS = 1
local lastDiagnosticLog = {signature = nil, at = -math.huge}

local function read(object, key, fallback)
  return U.read(object, key, fallback)
end

local function finite(value)
  return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

local function number(value)
  value = tonumber(value)
  return finite(value) and value or nil
end

local function diagnostic(state, reason, fields)
  if not ac.log then return end
  local clock = number(read(state, 'clock')) or 0
  local parts = {'[Retro UI corner gear] ', reason}
  if fields then
    for _, item in ipairs(fields) do
      parts[#parts + 1] = ' '
      parts[#parts + 1] = item[1]
      parts[#parts + 1] = '='
      parts[#parts + 1] = tostring(item[2])
    end
  end
  local message = table.concat(parts)
  local elapsed = clock - lastDiagnosticLog.at
  local minimumInterval = reason ~= lastDiagnosticLog.signature
    and MIN_LOG_INTERVAL_SECONDS or LOG_INTERVAL_SECONDS
  if elapsed >= minimumInterval then
    lastDiagnosticLog.signature, lastDiagnosticLog.at = reason, clock
    pcall(ac.log, message)
  end
end

local function trackKey(sim)
  local id
  if ac.getTrackFullID then
    local ok, value = pcall(ac.getTrackFullID, '/')
    if ok and type(value) == 'string' and value ~= '' then id = value end
  end
  if not id and ac.getTrackName then
    local ok, value = pcall(ac.getTrackName)
    if ok and value then id = tostring(value) end
  end
  return tostring(id or 'unknown') .. ':' .. tostring(read(sim, 'trackLengthM', 0))
end

local function worldAt(progress)
  local ok, position = pcall(ac.trackProgressToWorldCoordinate, progress, true)
  if not ok or not position then return nil end
  local x, z = number(read(position, 'x')), number(read(position, 'z'))
  if not x or not z then return nil end
  return {x = x, z = z}
end

local function circumradius(a, b, c)
  local abx, abz = b.x - a.x, b.z - a.z
  local bcx, bcz = c.x - b.x, c.z - b.z
  local cax, caz = a.x - c.x, a.z - c.z
  local ab = math.sqrt(abx * abx + abz * abz)
  local bc = math.sqrt(bcx * bcx + bcz * bcz)
  local ca = math.sqrt(cax * cax + caz * caz)
  local cross = math.abs(abx * (c.z - a.z) - abz * (c.x - a.x))
  if cross < 0.0001 then return math.huge end
  return ab * bc * ca / (2 * cross)
end

local function buildGeometry(sim)
  local length = number(read(sim, 'trackLengthM'))
  if not length or length < 100 or length > 100000 then return nil end
  if not ac.trackProgressToWorldCoordinate then return nil end
  if ac.hasTrackSpline then
    local ok, available = pcall(ac.hasTrackSpline)
    if not ok or available ~= true then return nil end
  end

  local count = math.max(240, math.min(1800, math.floor(length / 10)))
  local points = {}
  for i = 0, count - 1 do
    points[i + 1] = worldAt(i / count)
    if not points[i + 1] then return nil end
  end

  local radii, corner = {}, {}
  local offset = math.max(3, math.floor(30 / (length / count) + 0.5))
  for i = 0, count - 1 do
    local before = points[((i - offset) % count) + 1]
    local middle = points[i + 1]
    local after = points[((i + offset) % count) + 1]
    local radius = circumradius(before, middle, after)
    radii[i + 1] = radius
    corner[i + 1] = radius < 500
  end

  local groups, current = {}, nil
  for i = 1, count do
    if corner[i] then
      if not current then current = {first = i, last = i, minRadius = radii[i], apex = i}
      else
        current.last = i
        if radii[i] < current.minRadius then
          current.minRadius, current.apex = radii[i], i
        end
      end
    elseif current then
      groups[#groups + 1] = current
      current = nil
    end
  end
  if current then groups[#groups + 1] = current end
  if #groups == 0 then return {length = length, corners = {}} end

  local step = length / count
  local merged = {}
  for _, group in ipairs(groups) do
    local previous = merged[#merged]
    local gap = previous and (group.first - previous.last - 1) * step or math.huge
    if previous and gap <= 35 then
      previous.last = group.last
      if group.minRadius < previous.minRadius then
        previous.minRadius, previous.apex = group.minRadius, group.apex
      end
    else
      merged[#merged + 1] = {
        first = group.first, last = group.last,
        minRadius = group.minRadius, apex = group.apex
      }
    end
  end
  if #merged > 1 then
    local first, last = merged[1], merged[#merged]
    local wrapGap = (first.first + count - last.last - 1) * step
    if wrapGap <= 35 then
      last.wraps = true
      last.endIndex = first.last
      if first.minRadius < last.minRadius then
        last.minRadius, last.apex = first.minRadius, first.apex
      end
      table.remove(merged, 1)
    end
  end

  local corners = {}
  for _, group in ipairs(merged) do
    local finish = group.endIndex or group.last
    local countInGroup = group.wraps and (count - group.first + 1) + finish
      or finish - group.first + 1
    if group.minRadius >= 6 and countInGroup >= 2 then
      corners[#corners + 1] = {
        entry = (((group.first - 1) * step) - CORNER_EARLY_ENTRY_METERS) % length,
        exit = (finish * step) % length,
        arcLength = countInGroup * step + CORNER_EARLY_ENTRY_METERS,
        apex = ((group.apex - 1) * step) % length,
        radius = group.minRadius,
        targetSpeed = math.sqrt(LATERAL_G * 9.81 * group.minRadius)
      }
    end
  end
  return {length = length, corners = corners}
end

local function geometry(sim)
  local key = trackKey(sim)
  local cached = geometryCache[key]
  if cached then return cached end
  local ok, result = pcall(buildGeometry, sim)
  if not ok or not result then return nil end
  geometryCache = {[key] = result}
  return result
end

local function carKey(car, index)
  if ac.getCarID then
    local ok, result = pcall(ac.getCarID, index)
    if ok and result then return tostring(result) end
  end
  return tostring(read(car, 'id', index))
end

local function iniNumber(config, section, key)
  local ok, value = pcall(function() return config:get(section, key, nil) end)
  return ok and number(value) or nil
end

local function readTorqueCurve(index)
  if not ac.INIConfig or not ac.INIConfig.carData or not ac.DataLUT11 then return nil end
  local ok, config = pcall(ac.INIConfig.carData, index, 'engine.ini')
  if not ok or not config then return nil end
  local readOK, value = pcall(function() return config:get('HEADER', 'POWER_CURVE', '') end)
  if not readOK or type(value) ~= 'string' or value == '' then return nil end
  if value:sub(1, 1) == '(' and ac.DataLUT11.parse then
    local parsed, lut = pcall(ac.DataLUT11.parse, value)
    if parsed and lut then return lut end
  end
  local loaded, lut = pcall(ac.DataLUT11.carData, index, value)
  return loaded and lut or nil
end

local function ratioFromPhysics(physics, gear)
  local ratios = read(physics, 'gearRatios')
  if ratios then
    local ok, result = pcall(function() return number(ratios[gear]) end)
    if ok and result and result > 0 then return result end
  end
  return nil
end

local function drivetrainFor(car, physics, index, key)
  local cached = drivetrainCache[key]
  if cached then return cached end
  local ratios, finalRatio = {}, number(read(physics, 'finalRatio'))
  local physicsFinalRatio = finalRatio
  if finalRatio and finalRatio <= 0 then finalRatio = nil end
  local carGearCount = number(read(car, 'gearCount'))
  local physicsGearCount = number(read(physics, 'gearCount'))
  local count = carGearCount or physicsGearCount
  count = math.floor(U.clamp(count or 0, 0, 10))
  -- CSP StateCarPhysics.gearRatios is a zero-based array. AC gear 1 can be
  -- stored at index 2 when index 1 is reserved for neutral; detect that shape
  -- and map forward gear numbers to the corresponding physics entries.
  local ratioIndexOffset = not ratioFromPhysics(physics, 1)
      and ratioFromPhysics(physics, 2) and 1 or 0
  local physicsRatioCount = 0
  for gear = 1, math.max(count, 8) do
    ratios[gear] = ratioFromPhysics(physics, gear + ratioIndexOffset)
    if ratios[gear] then physicsRatioCount = physicsRatioCount + 1 end
  end

  local needsIni = not finalRatio or count == 0
  for gear = 1, count do if not ratios[gear] then needsIni = true end end
  local iniLoaded, iniCount, iniFinalRatio = false, nil, nil
  if ac.INIConfig and ac.INIConfig.carData and needsIni then
    local ok, config = pcall(ac.INIConfig.carData, index, 'drivetrain.ini')
    if ok and config then
      iniLoaded = true
      iniCount = math.floor(U.clamp(iniNumber(config, 'GEARS', 'COUNT') or 0, 0, 10))
      if count == 0 then count = iniCount end
      if not finalRatio then
        iniFinalRatio = iniNumber(config, 'GEARS', 'FINAL')
        finalRatio = iniFinalRatio
      end
      for gear = 1, math.max(count, iniCount) do
        if not ratios[gear] then ratios[gear] = iniNumber(config, 'GEARS', 'GEAR_' .. gear) end
      end
    end
  end
  if count == 0 then
    for gear = 1, 10 do if ratios[gear] then count = gear end end
  end
  local missingRatios = {}
  for gear = 1, count do
    if not ratios[gear] or ratios[gear] <= 0 then missingRatios[#missingRatios + 1] = gear end
  end
  local function failure(reason)
    return nil, string.format('%s car_count=%s physics_count=%s ini_count=%s physics_final=%s ini_final=%s physics_ratios=%d/%d ratio_index_offset=%d missing_ratios=%s ini_loaded=%s',
      reason, tostring(carGearCount), tostring(physicsGearCount), tostring(iniCount),
      tostring(physicsFinalRatio), tostring(iniFinalRatio), physicsRatioCount, count, ratioIndexOffset,
      #missingRatios > 0 and table.concat(missingRatios, ',') or 'none', tostring(iniLoaded))
  end
  if count < 1 then return failure('no_gear_count') end
  if not finalRatio or finalRatio <= 0 then return failure('no_final_ratio') end
  for gear = 1, count do
    if not ratios[gear] or ratios[gear] <= 0 then return failure('incomplete_gear_ratios') end
  end

  local radius
  local carRadiusCount = 0
  local tyreIniLoaded, tyreIniFront, tyreIniRear = false, nil, nil
  -- Loaded tyre radius belongs to StateWheel (car.wheels), not
  -- StateWheelPhysics (physics.wheels).
  local wheels = read(car, 'wheels')
  if wheels then
    local total, n = 0, 0
    for i = 0, 3 do
      local ok, wheel = pcall(function() return wheels[i] end)
      local loaded = ok and number(read(wheel, 'tyreLoadedRadius')) or nil
      if loaded and loaded > 0.1 and loaded < 1 then
        total, n = total + loaded, n + 1
        carRadiusCount = carRadiusCount + 1
      end
    end
    if n > 0 then radius = total / n end
  end
  if not radius and ac.INIConfig and ac.INIConfig.carData then
    local ok, tyres = pcall(ac.INIConfig.carData, index, 'tyres.ini')
    if ok and tyres then
      tyreIniLoaded = true
      tyreIniFront = iniNumber(tyres, 'FRONT', 'RADIUS')
      tyreIniRear = iniNumber(tyres, 'REAR', 'RADIUS')
      for _, configured in ipairs({tyreIniFront or 0, tyreIniRear or 0}) do
        if configured and configured > 0.1 and configured < 1 then radius = configured; break end
      end
    end
  end
  if not radius then
    local _, detail = failure('no_wheel_radius')
    return nil, string.format('%s car_wheels=%s car_radius_count=%d tyre_ini_loaded=%s tyre_ini_front=%s tyre_ini_rear=%s',
      detail, tostring(wheels ~= nil), carRadiusCount, tostring(tyreIniLoaded),
      tostring(tyreIniFront), tostring(tyreIniRear))
  end

  local result = {count = count, ratios = ratios, finalRatio = finalRatio, wheelRadius = radius,
    torqueCurve = readTorqueCurve(index)}
  drivetrainCache[key] = result
  return result, string.format('ok gears=%d final=%.5f radius=%.4f physics_ratios=%d ratio_index_offset=%d car_radius_count=%d ini_loaded=%s',
    count, finalRatio, radius, physicsRatioCount, ratioIndexOffset, carRadiusCount, tostring(iniLoaded))
end

local function wrapDistance(from, to, length)
  return (to - from) % length
end

local function nextCorner(track, progress)
  local position = U.clamp(progress, 0, 1) * track.length
  local selected, bestDistance, selectedInside, selectedApexDistance
  for _, corner in ipairs(track.corners) do
    local toEntry = wrapDistance(position, corner.entry, track.length)
    local fromEntry = wrapDistance(corner.entry, position, track.length)
    local inside = fromEntry <= corner.arcLength
    local toExit = wrapDistance(position, corner.exit, track.length)
    if inside and toExit < 1 then inside = false end
    local distance = inside and 0 or toEntry
    if not selected or distance < bestDistance then
      selected, bestDistance, selectedInside = corner, distance, inside
      selectedApexDistance = wrapDistance(position, corner.apex, track.length)
    end
  end
  if not selected then return nil end
  return selected, bestDistance, selectedApexDistance, selectedInside
end

local function selectGear(drivetrain, targetSpeed, limiter)
  local safeRpm = limiter * RPM_SAFETY_FRACTION
  local bestGear, bestForce, fallbackGear, fallbackRatio
  for gear = 1, drivetrain.count do
    local ratio = drivetrain.ratios[gear] * drivetrain.finalRatio
    local rpm = targetSpeed / (2 * math.pi * drivetrain.wheelRadius) * 60 * ratio
    if rpm <= safeRpm then
      if not fallbackGear or ratio > fallbackRatio then fallbackGear, fallbackRatio = gear, ratio end
      local curve, torque = drivetrain.torqueCurve, nil
      if curve then
        local ok, value = pcall(function() return curve:get(rpm) end)
        torque = ok and number(value) or nil
      end
      if torque and torque > 0 then
        local wheelForce = torque * ratio
        if not bestForce or wheelForce > bestForce then bestGear, bestForce = gear, wheelForce end
      end
    end
  end
  return bestGear or fallbackGear
end

function M.reset(state)
  state.cornerGearHint = nil
  state._cornerGearRuntime = nil
end

function M.update(state, car, sim, dt, enabled)
  state.cornerGearHint = nil
  if enabled == false then diagnostic(state, 'hidden:disabled'); return end
  if not car or not sim then diagnostic(state, 'hidden:missing-session-data'); return end
  if read(car, 'isInPitlane') == true or read(car, 'isInPit') == true then
    diagnostic(state, 'hidden:pit'); return
  end
  if read(car, 'physicsAvailable') == false then diagnostic(state, 'hidden:physics-unavailable'); return end

  local gear = number(read(car, 'gear'))
  if not gear or gear < 1 then diagnostic(state, 'hidden:neutral-or-reverse'); return end
  local track = geometry(sim)
  if not track then
    local splineAvailable = 'unknown'
    if ac.hasTrackSpline then
      local ok, available = pcall(ac.hasTrackSpline)
      splineAvailable = ok and tostring(available) or 'error'
    end
    diagnostic(state, 'hidden:track-geometry-unavailable', {
      {'track', trackKey(sim)}, {'length_m', read(sim, 'trackLengthM', '?')},
      {'spline_available', splineAvailable}
    })
    return
  end
  if #track.corners == 0 then
    diagnostic(state, 'hidden:no-corners-detected', {{'track', trackKey(sim)}})
    return
  end
  local progress = number(read(car, 'splinePosition'))
  if not progress then diagnostic(state, 'hidden:no-spline-position'); return end
  local corner, distanceToEntry, distanceToApex = nextCorner(track, progress)
  if not corner then diagnostic(state, 'hidden:no-next-corner'); return end

  local runtime = state._cornerGearRuntime or {}
  local index = number(read(car, 'index', 0)) or 0
  local id = carKey(car, index)
  local runtimeKey = tostring(index) .. '/' .. id
  if runtime.carKey ~= runtimeKey then runtime = {carKey = runtimeKey, retryAt = 0} end
  local clock = number(read(state, 'clock')) or 0
  if not runtime.drivetrain and clock >= (runtime.retryAt or 0) then
    local physics
    if ac.getCarPhysics then
      local ok, result = pcall(ac.getCarPhysics, index)
      if ok then physics = result end
    end
    runtime.drivetrain, runtime.drivetrainDetail = drivetrainFor(car, physics, index, runtimeKey)
    runtime.retryAt = clock + 1
  end
  state._cornerGearRuntime = runtime
  local drivetrain = runtime.drivetrain
  local limiter = number(read(car, 'rpmLimiter')) or number(read(state, 'rpmDisplayLimiter'))
  if not drivetrain then
    diagnostic(state, 'hidden:drivetrain-data-unavailable', {
      {'track', trackKey(sim)}, {'progress', string.format('%.3f', progress)},
      {'corner_m', math.floor(distanceToEntry + 0.5)}, {'gear', gear},
      {'detail', runtime.drivetrainDetail or 'not-yet-read'}
    })
    return
  end
  if not limiter or limiter <= 1000 then
    diagnostic(state, 'hidden:rpm-limiter-unavailable', {{'gear', gear}})
    return
  end

  local targetGear = selectGear(drivetrain, corner.targetSpeed, limiter)
  if not targetGear then
    diagnostic(state, 'hidden:no-safe-gear', {
      {'progress', string.format('%.3f', progress)}, {'corner_m', math.floor(distanceToEntry + 0.5)},
      {'radius_m', math.floor(corner.radius + 0.5)}, {'gear', gear}
    })
    return
  end
  if targetGear == gear then
    diagnostic(state, 'hidden:already-in-recommended-gear', {
      {'progress', string.format('%.3f', progress)}, {'corner_m', math.floor(distanceToEntry + 0.5)},
      {'radius_m', math.floor(corner.radius + 0.5)}, {'gear', gear}
    })
    return
  end
  local speed = number(read(car, 'speedMs'))
  if not speed then speed = (number(read(car, 'speedKmh')) or 0) / 3.6 end
  speed = math.max(0, speed)
  local target = corner.targetSpeed
  local excess = speed - target
  local brakingDistance = excess > 0 and (speed * speed - target * target) / (2 * BRAKING_DECELERATION) or 0
  local brakingWindow = math.max(8, speed * 0.15)
  state.cornerGearHint = {
    gear = targetGear,
    direction = targetGear > gear and 'up' or 'down',
    overspeed = excess > RED_DIFFERENTIAL_MS,
    braking = excess > 0 and math.abs(distanceToApex - brakingDistance) <= brakingWindow,
    targetSpeedKmh = target * 3.6,
    radius = corner.radius,
    distanceToCorner = distanceToEntry,
    distanceToApex = distanceToApex,
    brakingDistance = brakingDistance,
    source = drivetrain.torqueCurve and 'torque' or 'ratio'
  }
  diagnostic(state, 'shown', {
    {'progress', string.format('%.3f', progress)}, {'corner_m', math.floor(distanceToEntry + 0.5)},
    {'apex_m', math.floor(distanceToApex + 0.5)}, {'radius_m', math.floor(corner.radius + 0.5)},
    {'speed_kmh', math.floor(speed * 3.6 + 0.5)}, {'gear', gear}, {'suggested', targetGear},
    {'target_kmh', math.floor(target * 3.6 + 0.5)}, {'source', state.cornerGearHint.source}
  })
end

function M.clearCaches()
  geometryCache, drivetrainCache = {}, {}
end

return M
