local M = {}

-- Row contract: SDK split arrays must be copied to 1-based Lua tables;
-- currentSector remains 0-based and lapCount counts completed laps.
-- currentLapValid is true/false/nil. Main gates car.isLapValid and lapCutsCount
-- on car.physicsAvailable == true; isCurrentLapValid is not an SDK field.
-- isLastLapValid is independent of physics availability. bestLapSplits is
-- the recorded best LAP's splits, never the unrestricted SDK bestSplits.
-- Optional bestLapTimeMs/lastLapTimeMs validate complete split snapshots.
-- sectorCount comes from #sim.lapSplits, falling back to SDK array lengths
-- (zero-filled entries count). With no evidence, hide all indicators.

local function number(value)
  value = tonumber(value)
  return value and value == value and math.abs(value) < math.huge and value or nil
end

local function time(value)
  value = number(value)
  return value and value > 0 and value or nil
end

local function integer(value, maximum)
  value = number(value)
  if value and value >= 0 and value == math.floor(value)
      and (not maximum or value <= maximum) then return value end
  return nil
end

local function validity(value)
  if value == true or value == false then return value end
  return nil
end

local function sectorCount(row)
  if row.sectorCount ~= nil then return math.min(3, integer(row.sectorCount) or 0) end
  local count = 0
  for _, key in ipairs({'currentSplits', 'lastSplits', 'bestLapSplits'}) do
    local source = row[key]
    if type(source) == 'table' then count = math.max(count, #source) end
  end
  return math.min(3, count)
end

local function splits(source, count)
  local out = {}
  for s = 1, count do out[s] = time(source and source[s]) end
  return out
end

local function complete(values, count, lapTime)
  if count == 0 then return false end
  local total = 0
  for s = 1, count do
    if not values[s] then return false end
    total = total + values[s]
  end
  if lapTime ~= nil then
    lapTime = time(lapTime)
    -- Allow millisecond rounding, but reject stale or mismatched SDK arrays.
    if not lapTime or math.abs(total - lapTime) > count then return false end
  end
  return true
end

local function commit(car, values)
  for s = 1, car.sectorCount do car.pb[s] = math.min(car.pb[s] or values[s], values[s]) end
end

local function compare(value, own, reference, known)
  if not value or not known then return 'NEUTRAL' end
  if not reference or value <= reference + 0.5 then return 'PURPLE' end
  if not own or value <= own + 0.5 then return 'GREEN' end
  return 'AMBER'
end

local function classID(value)
  if type(value) ~= 'string' then return nil end
  value = value:match('^%s*(.-)%s*$')
  return value ~= '' and value:upper() ~= 'UNKNOWN' and value or nil
end

local function references(state)
  local general, classes = {}, {}
  for _, car in pairs(state.cars) do
    local class = car.classID
    if class then classes[class] = classes[class] or {} end
    for s = 1, car.sectorCount do
      local value = car.pb[s]
      if value then
        general[s] = math.min(general[s] or value, value)
        if class then classes[class][s] = math.min(classes[class][s] or value, value) end
      end
    end
  end
  return general, classes
end

local function referenceFor(car, settings, general, classes)
  if settings.sectorReference == 'Class' then
    if car.classID then return classes[car.classID] or {}, car.classID end
    return general, 'GENERAL (UNKNOWN CLASS)'
  end
  return general, 'GENERAL'
end

function M.new() return {cars = {}} end
function M.reset(state) state.cars = {} end

local function newCar(row, count)
  return {pb = {}, driver = row.driver, carID = row.carID, sectorCount = count}
end

local function observe(car, row, lap, sector)
  if lap == nil or sector == nil then
    -- A gap in telemetry cannot locate a subsequent validity transition.
    car.lastValidity, car.sector = nil, nil
    return
  end

  if car.lap == nil or lap > car.lap then
    local consecutive = car.lap ~= nil and lap == car.lap + 1
    car.previous = lap > 0 and {
      invalid = consecutive and car.invalid or false,
      invalidSector = consecutive and car.invalidSector or nil,
      splits = {}, valid = nil, committed = false
    } or nil
    car.lap = lap
    car.invalid, car.invalidSector, car.lastValidity, car.sector = false, nil, nil, nil
  elseif car.sector and sector < car.sector then
    -- Returning to pits/rewinding inside a lap makes the affected sector
    -- ambiguous, but must never erase an already observed invalidation.
    car.invalidSector, car.lastValidity = nil, nil
  end

  local previous = car.previous
  if previous and not previous.committed then
    local valid = validity(row.isLastLapValid)
    if valid ~= nil then
      if previous.valid ~= false then previous.valid = valid end
    end
    if row.lastSplits then previous.splits = splits(row.lastSplits, car.sectorCount) end
    if previous.valid == true and not previous.invalid
        and complete(previous.splits, car.sectorCount, row.lastLapTimeMs) then
      commit(car, previous.splits)
      previous.committed = true
    end
  end

  local valid = validity(row.currentLapValid)
  if valid == false then
    if not car.invalid then
      -- Only consecutive true -> false samples in the same sector identify it.
      car.invalidSector = car.lastValidity == true and car.sector == sector and sector or nil
    end
    car.invalid = true
  end
  car.lastValidity, car.sector = valid, sector
end

function M.update(state, rows, settings)
  settings = settings or {}
  -- Reset/seed every row before building references, so iteration order does
  -- not change colors and rewinds cannot leave stale records in this frame.
  for i = 1, #rows do
    local row = rows[i]
    local car = state.cars[row.index]
    local lap = integer(row.lapCount)
    local count = sectorCount(row)
    if not car or car.driver ~= row.driver or car.carID ~= row.carID
        or row.reconnected == true or (car.connected == false and row.connected ~= false)
        or (lap and car.lap and lap < car.lap)
        or (count > 0 and count ~= car.sectorCount) then
      car = newCar(row, count)
      state.cars[row.index] = car
    end
    car.classID, car.connected = classID(row.classID), row.connected ~= false
    local best = splits(row.bestLapSplits, count)
    if complete(best, count, row.bestLapTimeMs) then commit(car, best) end
    local sector = integer(row.currentSector, count - 1)
    observe(car, row, lap, sector and sector + 1 or nil)
  end

  local general, classes = references(state)
  for i = 1, #rows do
    local row = rows[i]
    local car = state.cars[row.index]
    local reference, label = referenceFor(car, settings, general, classes)
    local count = sectorCount(row)
    local sector = integer(row.currentSector, count - 1)
    sector = sector and sector + 1 or nil
    local usable = integer(row.lapCount) ~= nil and sector ~= nil
    local valid = validity(row.currentLapValid)
    row.sectorReferenceLabel, row.sectors = label, {}
    for s = 1, count do
      local value, role = nil, 'NEUTRAL'
      if usable then
        if s < sector then
          -- This slot belongs to the current lap even when its split is
          -- missing. Never fall back to a previous lap's time or color.
          value = time(row.currentSplits and row.currentSplits[s])
          local known = valid == true or (valid == false and car.invalidSector ~= nil)
          role = compare(value, car.pb[s], reference[s], known)
        elseif car.previous then
          local previous = car.previous
          value = previous.splits[s]
          local invalid = previous.invalid or previous.valid == false
          local red = invalid and (not previous.invalidSector or previous.invalidSector == s)
          role = red and 'RED' or compare(value, car.pb[s], reference[s], previous.valid ~= nil)
        end
        if car.invalid and (not car.invalidSector or car.invalidSector == s) then role = 'RED' end
      end
      row.sectors[s] = {timeMs = value, role = role, active = s == sector}
    end
  end
end

return M
