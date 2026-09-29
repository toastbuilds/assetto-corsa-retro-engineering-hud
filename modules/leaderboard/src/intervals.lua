local M = {}

local function number(value)
  value = tonumber(value)
  return value and value == value and value or nil
end

local function read(object, key)
  if object == nil then return nil end
  local ok, value = pcall(function() return object[key] end)
  return ok and value or nil
end

local function lapDifference(delta)
  if delta >= 1 then return 'L +' .. tostring(math.max(1, math.floor(delta + 0.1))) end
  if delta <= -1 then return 'L -' .. tostring(math.max(1, math.floor(-delta + 0.1))) end
  return nil
end

local function formatSeconds(value)
  value = number(value)
  if not value or math.abs(value) > 120 then return '--' end
  if math.abs(value) < 0.05 then return '0.0s' end
  return string.format('%+.1fs', value)
end

local function appendSample(carState, row, now)
  if row == nil or row.progress == nil or row.active == false then return end
  local previous = carState.lastProgress
  if previous ~= nil and row.progress < previous - 0.20 then carState.history = {} end
  carState.lastProgress = row.progress
  carState.lastSeen = now
  local history = carState.history
  history[#history + 1] = { time = now, progress = row.progress }
  while #history > 2 and (history[1].time < now - 18 or #history > 180) do table.remove(history, 1) end
end

local function crossingTime(carState, target)
  if carState == nil then return nil end
  local history = carState.history
  for i = #history, 2, -1 do
    local a, b = history[i - 1], history[i]
    if a.progress <= target and target <= b.progress and b.progress > a.progress then
      return a.time + (target - a.progress) * (b.time - a.time) / (b.progress - a.progress)
    end
  end
  return nil
end

local function liveLapDelta(row, localRow)
  if row.lapCount ~= localRow.lapCount then return nil end
  local other = number(row.currentLapTimeMs)
  local player = number(localRow.currentLapTimeMs)
  if other and player and other > 0 and player > 0 then return (player - other) / 1000 end
  return nil
end

local function estimate(row, localRow, state, trackLength)
  local delta = row.progress - localRow.progress
  -- Progress is unwrapped for lap differences, but a same-lap pair can sit
  -- on opposite sides of the finish line. Use displayed order to choose the
  -- physical direction in that narrow wrap-around case.
  local direction = row.position < localRow.position and 1 or -1
  if math.abs(delta) < 1 then
    if direction > 0 and delta < 0 then delta = delta + 1 end
    if direction < 0 and delta > 0 then delta = delta - 1 end
  end
  local laps = lapDifference(delta)
  if laps then return laps end

  local direct = liveLapDelta(row, localRow)
  if direct then return formatSeconds(delta >= 0 and math.abs(direct) or -math.abs(direct)) end

  local now = ui.time()
  if delta > 0 then
    local crossed = crossingTime(state.cars[row.index], localRow.progress)
    if crossed then return formatSeconds(now - crossed) end
  elseif delta < 0 then
    local crossed = crossingTime(state.cars[localRow.index], row.progress)
    if crossed then return formatSeconds(-(now - crossed)) end
  else
    return '0.0s'
  end

  -- Safe fallback: physical spline distance divided by a clamped speed. This
  -- is deliberately a fallback only; lap history wins whenever available.
  local splineDelta = math.abs(row.splinePosition - localRow.splinePosition)
  splineDelta = math.min(splineDelta, 1 - splineDelta)
  local speed = number(localRow.speedMs) or number(row.speedMs) or 18
  speed = math.max(18, speed)
  local seconds = splineDelta * (number(trackLength) or 0) / speed
  if seconds <= 0 or seconds > 120 then return '--' end
  return formatSeconds(delta >= 0 and seconds or -seconds)
end

function M.new()
  return { cars = {}, cache = {}, lastRefresh = -math.huge, sessionIndex = nil }
end

function M.reset(state, sessionIndex)
  state.cars, state.cache = {}, {}
  state.lastRefresh, state.sessionIndex = -math.huge, sessionIndex
end

function M.update(state, snapshot, settings)
  if snapshot == nil or snapshot.rows == nil then return end
  local sessionIndex = number(read(snapshot.sim, 'currentSessionIndex')) or 0
  if state.sessionIndex ~= sessionIndex then M.reset(state, sessionIndex) end
  local now = ui.time()
  local localRow = snapshot.localRow
  for i = 1, #snapshot.rows do
    local row = snapshot.rows[i]
    local carState = state.cars[row.index] or { history = {} }
    state.cars[row.index] = carState
    appendSample(carState, row, now)
  end
  for index, carState in pairs(state.cars) do
    if carState.lastSeen and now - carState.lastSeen > 5 then state.cars[index] = nil end
  end

  local refresh = math.max(0.10, number(settings.intervalRefresh) or 0.25)
  if now - state.lastRefresh < refresh then
    for i = 1, #snapshot.rows do snapshot.rows[i].interval = state.cache[snapshot.rows[i].index] or '--' end
    return
  end
  state.lastRefresh = now
  for i = 1, #snapshot.rows do
    local row = snapshot.rows[i]
    if localRow == nil then
      state.cache[row.index] = '--'
    elseif row.index == localRow.index then
      state.cache[row.index] = '-'
    elseif snapshot.header and snapshot.header.isTimed and row.status == 'FIN' then
      state.cache[row.index] = '--'
    elseif row.status == 'OFF' or row.status == 'RET' then
      state.cache[row.index] = '--'
    else
      state.cache[row.index] = estimate(row, localRow, state, read(snapshot.sim, 'trackLengthM'))
    end
    row.interval = state.cache[row.index]
  end
end

return M
