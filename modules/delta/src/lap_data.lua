local LapData = {}

local function numberOr(value, fallback)
  value = tonumber(value)
  return value or fallback
end

function LapData.new(trackName, carIndex, sectorCount, lapNumber, driverName, carName)
  local lap = {
    version = 1,
    trackname = trackName or '',
    carname = carName or '',
    playername = driverName or '',
    car_index = carIndex or 0,
    lap_number = lapNumber or 0,
    timestamp = 0,
    complete = false,
    invalid = false,
    invalid_sectors = {},
    laptime = 0,
    splits = {},
    next_index = 0,
    offset = {},
    elapsed_seconds = {},
    speed_ms = {}
  }
  for i = 0, math.max(1, sectorCount or 1) - 1 do
    lap.invalid_sectors[i] = false
    lap.splits[i] = 0
  end
  return lap
end

function LapData.countSamples(lap)
  return math.max(0, math.floor(numberOr(lap and lap.next_index, 0)))
end

function LapData.isNextOffsetOK(lap, offset)
  if not lap then return false end
  offset = numberOr(offset, -1)
  if offset < 0 or offset > 1.05 then return false end
  local nextIndex = LapData.countSamples(lap)
  if nextIndex > 0 then
    local last = tonumber(lap.offset[nextIndex - 1])
    if not last or offset <= last or offset >= last + 0.10 then return false end
  end
  return true
end

function LapData.addSample(lap, offset, elapsedMs, speedMs)
  if not LapData.isNextOffsetOK(lap, offset) then return false end
  local index = LapData.countSamples(lap)
  lap.offset[index] = offset
  lap.elapsed_seconds[index] = numberOr(elapsedMs, 0)
  lap.speed_ms[index] = numberOr(speedMs, 0)
  lap.next_index = index + 1
  return true
end

function LapData.indexForOffset(lap, offset)
  local count = LapData.countSamples(lap)
  if count <= 0 then return -1 end
  local lo, hi = 0, count
  while lo < hi do
    local mid = math.floor((lo + hi) / 2)
    if offset < lap.offset[mid] then hi = mid else lo = mid + 1 end
  end
  return lo - 1
end

function LapData.elapsedAtOffset(lap, offset)
  local index = LapData.indexForOffset(lap, offset)
  if index < 0 then return nil, nil end
  local count = LapData.countSamples(lap)
  local t0 = numberOr(lap.elapsed_seconds[index], nil)
  local s0 = numberOr(lap.offset[index], nil)
  if not t0 or not s0 then return nil, nil end
  local nextIndex = index + 1
  if nextIndex >= count then return t0, numberOr(lap.speed_ms[index], 0) end
  local s1 = numberOr(lap.offset[nextIndex], s0)
  local t1 = numberOr(lap.elapsed_seconds[nextIndex], t0)
  local ratio = s1 > s0 and math.max(0, math.min(1, (offset - s0) / (s1 - s0))) or 0
  local speed0 = numberOr(lap.speed_ms[index], 0)
  local speed1 = numberOr(lap.speed_ms[nextIndex], speed0)
  return t0 + (t1 - t0) * ratio, speed0 + (speed1 - speed0) * ratio
end

function LapData.hasCoverage(lap)
  local count = LapData.countSamples(lap)
  if count < 20 then return false end
  local lastOffset = tonumber(lap.offset[count - 1]) or 0
  return lastOffset >= 0.50 and (tonumber(lap.laptime) or 0) > 0
end

function LapData.isValidForRecord(lap, sectorCount)
  if not lap or lap.complete ~= true or lap.invalid == true then return false end
  if not LapData.hasCoverage(lap) then return false end
  for i = 0, math.max(1, sectorCount or 1) - 1 do
    if (tonumber(lap.splits[i]) or 0) <= 0 or lap.invalid_sectors[i] == true then return false end
  end
  return (tonumber(lap.laptime) or 0) > 0
end

function LapData.copySectorTimes(lap, sectorCount)
  local out = {}
  for i = 0, math.max(1, sectorCount or 1) - 1 do
    local value = tonumber(lap and lap.splits and lap.splits[i]) or 0
    if value > 0 then out[i] = value end
  end
  return out
end

function LapData.timeDeltaToString(timeMs)
  timeMs = tonumber(timeMs) or 0
  if math.abs(timeMs) < 5 then return '0.00' end
  timeMs = math.max(-99990, math.min(99990, timeMs))
  return string.format('%+.2f', timeMs / 1000)
end

function LapData.timeToString(timeMs)
  timeMs = tonumber(timeMs)
  if not timeMs or timeMs <= 0 then return '--.---' end
  local seconds = timeMs / 1000
  local minutes = math.floor(seconds / 60)
  seconds = seconds - minutes * 60
  if minutes > 0 then return string.format('%d:%06.3f', minutes, seconds) end
  return string.format('%06.3f', seconds)
end

return LapData
