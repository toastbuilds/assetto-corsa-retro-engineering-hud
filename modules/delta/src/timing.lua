local Timing = {}

local function numberOr(value, fallback)
  value = tonumber(value)
  return value or fallback
end

function Timing.count0(values)
  if values == nil then return 0 end
  local lengthOk, length = pcall(function() return #values end)
  if lengthOk and type(length) == 'number' and length > 0 then
    return math.floor(length)
  end
  if type(values) ~= 'table' then return 0 end
  if type(table.nkeys) == 'function' then
    local ok, count = pcall(table.nkeys, values)
    if ok and count then return count end
  end
  local count = 0
  for key, value in pairs(values) do
    if type(key) == 'number' and key >= 0 and value ~= nil then count = math.max(count, key + 1) end
  end
  return count
end

function Timing.sectorSplits(sim)
  local source = sim and sim.lapSplits
  local count = Timing.count0(source)
  if count > 0 then return source, count end
  local fallback = { [0] = 0.9525 }
  return fallback, 1
end

function Timing.normalizeSpline(trackName, spline)
  spline = numberOr(spline, 0)
  if trackName == 'Nordschleife - Tourist' then
    if spline > 0.9525 then spline = spline - 0.9525 else spline = spline + 0.0475 end
    spline = spline / 0.9165
    if spline > 1 then spline = 0 end
  end
  return math.max(0, math.min(1, spline))
end

function Timing.cars()
  local ok, result = pcall(function()
    local out = {}
    for _, car in ac.iterateCars.leaderboard() do out[#out + 1] = car end
    return out
  end)
  if ok and result and #result > 0 then return result end
  local fallbackOk, fallback = pcall(function()
    local out = {}
    for _, car in ac.iterateCars() do out[#out + 1] = car end
    return out
  end)
  if fallbackOk and fallback then return fallback end
  return {}
end

function Timing.getCar(index)
  local ok, car = pcall(ac.getCar, index)
  return ok and car or nil
end

function Timing.field(car, name, fallback)
  if car == nil then return fallback end
  local ok, value = pcall(function() return car[name] end)
  if not ok or value == nil then return fallback end
  return value
end

function Timing.driverName(index, car)
  local ok, name = pcall(ac.getDriverName, index)
  if ok and name and name ~= '' then return name end
  return Timing.field(car, 'driverName', 'Unknown driver')
end

function Timing.carName(index, car)
  local ok, name = pcall(ac.getCarName, index)
  if ok and name and name ~= '' then return name end
  return Timing.field(car, 'name', 'Unknown car')
end

function Timing.trackName()
  local ok, name = pcall(ac.getTrackName)
  return ok and name or 'unknown-track'
end

function Timing.trackID()
  local ok, name = pcall(ac.getTrackFullID, '[]')
  if ok and name and name ~= '' then return name end
  return Timing.trackName()
end

function Timing.lapNumber(car, estimated)
  local value = numberOr(Timing.field(car, 'lapCount', 0), 0)
  if value > 0 then return math.floor(value) end
  local sessionValue = numberOr(Timing.field(car, 'sessionLapCount', 0), 0)
  if sessionValue > 0 then return math.floor(sessionValue) end
  return math.floor(numberOr(estimated, 0))
end

function Timing.currentSector(car, count)
  local sector = math.floor(numberOr(Timing.field(car, 'currentSector', 0), 0))
  if sector < 0 then sector = 0 end
  if sector >= count then sector = count - 1 end
  return sector
end

function Timing.currentSpline(car, trackName)
  return Timing.normalizeSpline(trackName, Timing.field(car, 'splinePosition', 0))
end

function Timing.lapTimeMs(car)
  return numberOr(Timing.field(car, 'lapTimeMs', 0), 0)
end

function Timing.speedMs(car)
  return numberOr(Timing.field(car, 'speedMs', 0), 0)
end

function Timing.isInPit(car)
  return Timing.field(car, 'isInPitlane', false) == true or Timing.field(car, 'isInPit', false) == true
end

function Timing.wheelsInvalid(car)
  return numberOr(Timing.field(car, 'wheelsOutside', 0), 0) >= 3
end

local function readArrayValue(values, index)
  if values == nil then return nil end
  local ok, value = pcall(function() return values[index] end)
  return ok and numberOr(value, nil) or nil
end

function Timing.currentSplits(car)
  return Timing.field(car, 'currentSplits', nil)
end

function Timing.lastSplits(car)
  return Timing.field(car, 'lastSplits', nil)
end

function Timing.previousLapTime(car)
  return numberOr(Timing.field(car, 'previousLapTimeMs', 0), 0)
end

function Timing.completedSectorTime(car, newSector, sectorCount, lap)
  local sector = newSector - 1
  if sector < 0 then sector = sectorCount - 1 end
  local value = nil
  if newSector ~= 0 then
    value = numberOr(Timing.field(car, 'previousSectorTime', 0), 0)
    if value <= 0 then value = readArrayValue(Timing.currentSplits(car), sector) or 0 end
  else
    local last = Timing.lastSplits(car)
    value = readArrayValue(last, sector) or 0
    if value <= 0 and Timing.previousLapTime(car) > 0 then
      local sum = 0
      for i = 0, sectorCount - 2 do sum = sum + (numberOr(lap and lap.splits[i], 0)) end
      value = Timing.previousLapTime(car) - sum
    end
  end
  return math.max(0, numberOr(value, 0)), sector
end

function Timing.currentSectorPrefix(car, currentSector, lap)
  local sum = 0
  local splits = Timing.currentSplits(car)
  for i = 0, currentSector - 1 do
    local value = readArrayValue(splits, i)
    if not value or value <= 0 then value = numberOr(lap and lap.splits[i], 0) end
    sum = sum + math.max(0, value or 0)
  end
  return sum
end

function Timing.lapTimeFromSplits(lap, sectorCount)
  local total = 0
  for i = 0, sectorCount - 1 do total = total + numberOr(lap and lap.splits[i], 0) end
  return total
end

return Timing
