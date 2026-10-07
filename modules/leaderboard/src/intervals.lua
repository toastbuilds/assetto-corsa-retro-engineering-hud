local Timeline = require('modules/leaderboard/src/timeline')
local M = {}

-- Precise shared gates take priority. Continuous position history and a
-- distance/speed estimate keep live gaps available while gates are missing.
local POINTS, MAX_SECONDS, MAX_SAMPLE_GAP = 100, 120, 2
local EPSILON = 0.000001

local function number(value)
  value = tonumber(value)
  return value and value == value and math.abs(value) < math.huge and value or nil
end

local function read(object, key)
  if object == nil then return nil end
  local ok, value = pcall(function() return object[key] end)
  if ok then return value end
  return nil
end

local function lapDifference(delta)
  if delta >= 1 then return 'L +' .. tostring(math.floor(delta)) end
  if delta <= -1 then return 'L -' .. tostring(math.floor(-delta)) end
end

local function formatSeconds(value)
  if not value or math.abs(value) > MAX_SECONDS then return '--' end
  if math.abs(value) < 0.05 then return '0.0s' end
  return string.format('%+.1fs', value)
end

local function disposeSDK(state)
  for i = 1, #(state.subscriptions or {}) do pcall(state.subscriptions[i]) end
  state.subscriptions, state.sdkEvents = {}, {}
  state.sdkActive, state.sdkAttempted = false, false
end

function M.new()
  return {cars = {}, cache = {}, lastRefresh = -math.huge, sessionIndex = nil,
    subscriptions = {}, sdkEvents = {}, generation = 0}
end

function M.reset(state, sessionIndex)
  disposeSDK(state)
  state.generation = (state.generation or 0) + 1
  state.cars, state.cache = {}, {}
  state.lastRefresh, state.sessionIndex = -math.huge, sessionIndex
  state.timeline, state.localIndex, state.finalFrozen = nil, nil, false
  state.resetToken, state.resetSnapshot = nil, nil
end

local function startSDK(state, timeline)
  if state.sdkAttempted or timeline.replay or timeline.clock == 'wall'
    or timeline.clock == 'session' then return end
  state.sdkAttempted = true
  if type(read(ac, 'onTrackPointCrossed')) ~= 'function' then return end
  local generation = state.generation
  for point = 0, POINTS - 1 do
    local gate = point
    local ok, subscription = pcall(ac.onTrackPointCrossed, -1, gate / POINTS, function(index, timeMs)
      local time = number(timeMs)
      local car = state.cars[index]
      if state.generation ~= generation or not state.sdkActive or not car
        or not state.timeline or state.timeline.replay or not time then return end
      -- Bound pending events if the app is not being updated.
      if #state.sdkEvents >= 4096 then car.overflow = true; return end
      state.sdkEvents[#state.sdkEvents + 1] = {car = car, index = index, gate = gate, time = time / 1000}
    end)
    if not ok or type(subscription) ~= 'function' then
      disposeSDK(state)
      state.sdkAttempted = true
      return
    end
    state.subscriptions[#state.subscriptions + 1] = subscription
  end
  state.sdkActive = true
end

local function available(row)
  return row.active ~= false and row.connected ~= false and row.status ~= 'OFF'
    and row.status ~= 'RET' and row.status ~= 'PIT'
    and read(row.car, 'isConnected') ~= false and read(row.car, 'isActive') ~= false
    and read(row.car, 'isInPitlane') ~= true and read(row.car, 'isInPit') ~= true
end

local function identity(row)
  return tostring(row.driver or '') .. '/' .. tostring(row.carID or '')
end

local function addCrossing(car, gate, time, source)
  local previous = car.crossings[gate]
  if not previous or source == 'sdk' and previous.source ~= 'sdk' then
    car.crossings[gate] = {time = time, source = source}
  end
end

local function observe(state, row, timeline, sim)
  local progress, now = number(row.progress), timeline.time
  local car = state.cars[row.index]
  if not progress or not available(row) or timeline.measuredClock == false then
    if car then state.lastRefresh = -math.huge end
    state.cars[row.index] = nil
    return
  end
  local previous = car and car.last
  local rawProgress = progress
  local onlineZeroLap = read(sim, 'isOnlineRace') == true and row.lapCount == 0
  local lapOffset = onlineZeroLap and car and car.lapOffset or 0
  -- CMRT tracks finish crossings because online remote lapCount can stay zero.
  -- Only unwrap continuous forward motion; jumps and reconnects still reset.
  if onlineZeroLap and car and car.rawProgress and previous
    and car.rawProgress > 0.9 and rawProgress < 0.1
    and rawProgress + 1 - car.rawProgress < 0.1
    and now > previous.time and now - previous.time <= MAX_SAMPLE_GAP
    and not row.reconnected and not row.historyReset and not row.justJumped
    and read(row.car, 'justJumped') ~= true then
    lapOffset = lapOffset + 1
  end
  progress = progress + lapOffset
  local reset = not car or car.identity ~= identity(row) or row.reconnected == true
    or row.historyReset == true or row.justJumped == true or read(row.car, 'justJumped') == true
    or car.overflow or (car.lastSeen and now - car.lastSeen > MAX_SAMPLE_GAP)
  if previous and (progress < previous.progress - EPSILON
    or progress - previous.progress > 0.25 or now < previous.time
    or (now == previous.time and math.abs(progress - previous.progress) > EPSILON)) then reset = true end
  if reset then
    progress, lapOffset = rawProgress, 0
    car = {crossings = {}, history = {}, identity = identity(row), startedAt = now, startProgress = progress}
    state.cars[row.index], state.lastRefresh = car, -math.huge
    previous = nil
  end
  -- Registering SDK callbacks does not guarantee they will arrive for every
  -- car. Always retain bracketed position crossings; consumeSDK replaces them
  -- with the more precise physics timestamps when available on the same clock.
  if previous and now > previous.time and progress > previous.progress then
    local first = math.floor(previous.progress * POINTS + EPSILON) + 1
    local last = math.floor(progress * POINTS + EPSILON)
    for gate = first, last do
      local fraction = (gate / POINTS - previous.progress) / (progress - previous.progress)
      if fraction >= 0 and fraction <= 1 + EPSILON then
        addCrossing(car, gate, previous.time + math.min(1, fraction) * (now - previous.time), 'observed')
      end
    end
  end
  car.last, car.lastSeen = {progress = progress, time = now}, now
  car.rawProgress, car.lapOffset = rawProgress, lapOffset
  local history = car.history
  if #history == 0 or now - history[#history].time >= 0.05 then
    history[#history + 1] = car.last
  end
  while #history > 2 and (history[2].time < now - MAX_SECONDS or #history > 4096) do
    table.remove(history, 1)
  end
  for gate, crossed in pairs(car.crossings) do
    if crossed.time < now - MAX_SECONDS or gate < math.floor(progress * POINTS) - POINTS * 2 then
      car.crossings[gate] = nil
    end
  end
end

local function consumeSDK(state, timeline)
  for i = 1, #state.sdkEvents do
    local event = state.sdkEvents[i]
    local car = state.cars[event.index]
    if car == event.car and event.time >= car.startedAt and event.time <= timeline.time + 0.01
      and event.time >= timeline.time - MAX_SAMPLE_GAP then
      -- The event can be delivered just after an observation. Locate its most
      -- recent lap occurrence using the current unwrapped position.
      local lap = math.floor(car.last.progress - event.gate / POINTS + EPSILON)
      local gate = lap * POINTS + event.gate
      if gate / POINTS > car.startProgress + EPSILON then
        addCrossing(car, gate, event.time, 'sdk')
      end
    end
  end
  state.sdkEvents = {}
end

local function crossingTime(car, target)
  local history, b = car.history, car.last
  for i = #history, 1, -1 do
    local a = history[i]
    if a.progress <= target and target <= b.progress and b.progress > a.progress then
      return a.time + (target - a.progress) * (b.time - a.time) / (b.progress - a.progress)
    end
    b = a
  end
end

local function measured(row, localRow, state, sim)
  local other, player = state.cars[row.index], state.cars[localRow.index]
  if not other or not player then return '--' end
  local delta = other.last.progress - player.last.progress
  local laps = lapDifference(delta)
  if laps then return laps end
  local latest, seconds, source
  for gate, crossing in pairs(player.crossings) do
    local otherCrossing = other.crossings[gate]
    if otherCrossing and (not latest or gate > latest) then
      latest, seconds = gate, crossing.time - otherCrossing.time
      source = crossing.source == 'sdk' and otherCrossing.source == 'sdk' and 'sdk' or 'observed'
    end
  end
  local validPair = seconds and delta * seconds >= -EPSILON and math.abs(seconds) <= MAX_SECONDS
  local now = state.timeline.time
  -- Do not keep an old SDK gap while a stopped car's separation grows.
  if validPair and source == 'sdk'
    and math.max(player.crossings[latest].time, other.crossings[latest].time) >= now - MAX_SAMPLE_GAP then
    return formatSeconds(seconds), seconds, source
  end
  -- Never estimate from the first sample after a restart, seek or teleport.
  if now <= player.startedAt or now <= other.startedAt then return '--' end
  local front, back, backRow = other, player, localRow
  if delta < 0 then front, back, backRow = player, other, row end
  -- As in CMRT, use how long the leading car took to cover the separation.
  -- Unwrapped history naturally spans the finish line without mixing lap clocks.
  local crossing = crossingTime(front, back.last.progress)
  if crossing then
    local gap = (delta < 0 and -1 or 1) * (now - crossing)
    if math.abs(gap) <= MAX_SECONDS then return formatSeconds(gap), gap, 'history' end
  end
  if validPair and source ~= 'sdk' then return formatSeconds(seconds), seconds, source end
  local length, speed = number(read(sim, 'trackLengthM')), number(backRow.speedMs)
  if not length or length <= 0 or not speed then return '--' end
  local gap = delta * length / math.max(18, math.abs(speed))
  if math.abs(gap) > MAX_SECONDS then return '--' end
  return '~' .. formatSeconds(gap), gap, 'estimated'
end

local function applyCache(state, rows)
  for i = 1, #rows do
    local row, cached = rows[i], state.cache[rows[i].index]
    row.interval = cached and cached.display or '--'
    row.intervalSeconds = cached and cached.seconds or nil
    row.intervalSource = cached and cached.source or nil
  end
end

-- Snapshot contract: historyReset/resetIntervals clear immediately; a changed
-- resetToken also clears history. Optional timeline is Timeline.sample(sim).
-- row.interval is the existing display API. intervalSeconds/intervalSource are
-- sources are 'sdk', 'history', 'observed' or 'estimated'. final
-- computes once and freezes that cache until a reset or return to live data.
function M.update(state, snapshot, settings)
  if snapshot == nil or snapshot.rows == nil then M.reset(state); return end
  local sessionIndex = number(read(snapshot.sim, 'currentSessionIndex')) or 0
  local timeline = snapshot.timeline or Timeline.sample(snapshot.sim)
  local resetFlag = snapshot.historyReset == true or snapshot.resetIntervals == true
  local reset = state.sessionIndex ~= sessionIndex
    or (resetFlag and state.resetSnapshot ~= snapshot) or state.resetToken ~= snapshot.resetToken
    or Timeline.discontinuous(state.timeline, timeline, snapshot.sim)
  if reset then M.reset(state, sessionIndex) end
  state.resetSnapshot = resetFlag and snapshot or nil
  state.resetToken, state.timeline = snapshot.resetToken, timeline
  if snapshot.final == true and state.finalFrozen then applyCache(state, snapshot.rows); return end
  if state.finalFrozen then
    -- Never join newly moving telemetry to the frozen finishing observations.
    M.reset(state, sessionIndex)
    state.resetToken, state.timeline = snapshot.resetToken, timeline
    state.resetSnapshot = resetFlag and snapshot or nil
  end
  local localRow = snapshot.localRow
  local localIndex = localRow and localRow.index
  if state.localIndex ~= localIndex or snapshot.final == true then state.lastRefresh = -math.huge end
  state.localIndex = localIndex

  local seen = {}
  for i = 1, #snapshot.rows do
    local row = snapshot.rows[i]
    seen[row.index] = true
    observe(state, row, timeline, snapshot.sim)
  end
  for index in pairs(state.cars) do
    if not seen[index] then state.cars[index] = nil; state.cache[index] = nil; state.lastRefresh = -math.huge end
  end
  consumeSDK(state, timeline)
  startSDK(state, timeline)

  local refresh = math.max(0.10, number(settings and settings.intervalRefresh) or 0.25)
  local now = timeline.time
  if now - state.lastRefresh >= refresh then
    state.lastRefresh = now
    state.cache = {}
    for i = 1, #snapshot.rows do
      local row = snapshot.rows[i]
      local display, seconds, source = '--', nil, nil
      if localRow and row.index == localRow.index then
        display = '-'
      elseif localRow then
        display, seconds, source = measured(row, localRow, state, snapshot.sim)
      end
      state.cache[row.index] = {display = display, seconds = seconds, source = source}
    end
  end
  applyCache(state, snapshot.rows)
  if snapshot.final == true then
    state.finalFrozen = true
    disposeSDK(state)
  end
end

return M
