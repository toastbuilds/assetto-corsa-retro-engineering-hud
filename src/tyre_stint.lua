local U = require('src/utils')
local M = {}

local function number(value)
  if type(value) == 'number' and value == value and math.abs(value) < math.huge then
    return value
  end
end

local function nonnegative(value)
  value = number(value)
  return value and value >= 0 and value or nil
end

local function snapshot(state)
  local value = state.snapshot
  value.laps = state.laps + state.priorLaps
  value.km = state.km + state.priorKm
  value.approximate = state.approximate
  value.observedOnly = state.observedOnly
  return value
end

local function clear(state)
  local generation = state.snapshot and state.snapshot.resetGeneration + 1 or 0
  state.snapshot = { laps = 0, km = 0, approximate = true,
    observedOnly = true, resetGeneration = generation }
  state.laps, state.km, state.priorLaps, state.priorKm = 0, 0, 0, 0
  state.approximate, state.observedOnly = true, true
  state.canEstimate = false
  state.previous, state.origin, state.context, state.lastTyres = nil, nil, nil, nil
  state.pendingCounter, state.pendingWrap = nil, nil
  state.calibration = { km = 0, samples = 0, virtual = {0, 0, 0, 0} }
end

-- One subscription per API, with weak state references and guarded teardown.
-- Tests and older CSP builds can omit either callback API (and ac.storage).
local states = setmetatable({}, { __mode = 'k' })
local hookedApi
local function subscribe()
  local api = ac
  if api == nil or api == hookedApi then return end
  hookedApi = api
  local register = U.read(api, 'onSessionStart', nil)
  if type(register) ~= 'function' then return end
  local active = true
  local ok, disposable = pcall(register, function()
    if active then
      for state in pairs(states) do clear(state) end
    end
  end)
  if not ok then return end
  local release = U.read(api, 'onRelease', nil)
  if type(release) == 'function' then
    pcall(release, function()
      if not active then return end
      active = false
      if type(disposable) == 'function' then pcall(disposable)
      else
        local dispose = U.read(disposable, 'dispose', nil)
        if type(dispose) == 'function' then pcall(dispose, disposable) end
      end
    end)
  end
end

function M.new()
  local state = {}
  clear(state)
  states[state] = true
  subscribe()
  return state
end

local function sample(car)
  local value = {
    lap = nonnegative(U.read(car, 'lapCount', nil)),
    spline = nonnegative(U.read(car, 'splinePosition', nil)),
    compound = U.read(car, 'compoundIndex', nil),
    resetCounter = nonnegative(U.read(car, 'resetCounter', nil)),
    physicsAvailable = U.read(car, 'physicsAvailable', nil),
    speed = nonnegative(U.read(car, 'speedKmh', nil)),
    virtual = {}, wear = {},
  }
  value.odometer = nonnegative(U.read(car, 'distanceDrivenSessionKm', nil))
  value.distanceSource = 'session'
  if value.odometer == nil then
    value.odometer = nonnegative(U.read(car, 'distanceDrivenTotalKm', nil))
    value.distanceSource = 'total'
  end
  if value.spline and value.spline > 1 then value.spline = nil end
  local wheels = U.read(car, 'wheels', nil)
  for i = 1, 4 do
    local wheel = U.read(wheels, i - 1, nil)
    value.virtual[i] = nonnegative(U.read(wheel, 'tyreVirtualKM', nil))
    value.wear[i] = nonnegative(U.read(wheel, 'tyreWear', nil))
  end
  local position = U.read(car, 'position', nil)
  local x, y, z = number(U.read(position, 'x', nil)),
    number(U.read(position, 'y', nil)), number(U.read(position, 'z', nil))
  if x and y and z then value.position = {x, y, z} end
  return value
end

local function fresh(value)
  for i = 1, 4 do
    if value.virtual[i] == nil or value.virtual[i] > 0.000001
      or (value.wear[i] and value.wear[i] > 0.000001) then return false end
  end
  return true
end

local function tyreChange(before, after)
  if before.physicsAvailable == false or after.physicsAvailable == false then
    return false, true
  end
  if before.compound ~= nil and after.compound ~= nil
    and before.compound ~= after.compound then return true, false end
  local virtualDrops, wearDrops, changed = 0, 0, false
  for i = 1, 4 do
    local a, b = before.virtual[i], after.virtual[i]
    if a ~= nil and b == nil then changed = true end
    if a and b and b < a - 0.000001 then
      changed = true
      if b <= math.max(0.01, a * 0.05) then virtualDrops = virtualDrops + 1 end
    end
    a, b = before.wear[i], after.wear[i]
    if a and b and b < a - 0.0001 then
      changed = true
      if b <= math.max(0.001, a * 0.05) then wearDrops = wearDrops + 1 end
    end
  end
  -- A single noisy or missing wheel cannot identify a replacement set.
  return virtualDrops == 4 or wearDrops == 4 or (changed and fresh(after)), changed
end

local function context(car, sim)
  local replay
  if sim ~= nil then replay = U.read(sim, 'isReplayActive', false) == true end
  return {
    index = U.read(car, 'index', nil), carSession = U.read(car, 'sessionID', nil),
    session = U.read(sim, 'currentSessionIndex', nil),
    replay = replay,
    frame = nonnegative(U.read(sim, 'replayCurrentFrame', nil)),
    time = number(U.read(sim, 'time', nil)),
  }
end

local function elapsedSeconds(sim, dt, replay)
  local elapsed = nonnegative(U.read(sim, 'dt', nil))
  if elapsed ~= nil then return elapsed end
  local rate = replay and nonnegative(U.read(sim, 'replayPlaybackRate', nil)) or nil
  return dt * (rate or 1)
end

local function different(a, b)
  return a ~= nil and b ~= nil and a ~= b
end

local function contextReset(before, after, sim, dt)
  if before == nil then return false end
  if different(before.index, after.index) or different(before.carSession, after.carSession)
    or different(before.session, after.session) or different(before.replay, after.replay) then
    return true
  end
  if after.replay and before.frame and after.frame then
    local frames = after.frame - before.frame
    local frameMs = nonnegative(U.read(sim, 'replayFrameMs', nil))
    -- sim.dt already includes playback speed; caller dt is wall time.
    local elapsed = elapsedSeconds(sim, dt, true)
    local expected = frameMs and frameMs > 0 and elapsed * 1000 / frameMs or 0
    if frames < 0 or frames > math.max(2, expected + 2) then return true end
  end
  return before.time ~= nil and after.time ~= nil and after.time < before.time
end

local function baseline(state, value)
  state.previous, state.origin, state.lastTyres = value, value, value
  -- Physics-only channels can read as zero in replay or on remote cars.
  state.approximate = not fresh(value) or value.physicsAvailable == false
    or (state.context and state.context.replay == true) or false
  state.observedOnly = state.approximate
  state.canEstimate = value.physicsAvailable ~= false
  if state.context and state.context.replay then
    local positive = false
    for i = 1, 4 do
      if value.virtual[i] and value.virtual[i] > 0 then positive = true end
    end
    if not positive then state.canEstimate = false end
  end
end

local function countLaps(state, before, after)
  local wraps = before.spline and after.spline
    and before.spline > 0.75 and after.spline < 0.25
  local count = 0
  if before.lap and after.lap and after.lap > before.lap then
    count = after.lap - before.lap
    if state.pendingCounter then
      count = math.max(0, after.lap - math.max(before.lap, state.pendingCounter))
      if after.lap >= state.pendingCounter then state.pendingCounter = nil end
    end
    if count > 0 and not wraps and before.spline and before.spline > 0.75 then
      state.pendingWrap = true
    end
  end
  if wraps then
    if count == 0 and not state.pendingWrap then
      count = 1
      if after.lap then
        state.pendingCounter = math.max(state.pendingCounter or after.lap, after.lap) + 1
      end
    end
    state.pendingWrap = nil
  elseif after.spline and after.spline >= 0.25 and after.spline <= 0.75 then
    state.pendingWrap = nil
  end
  state.laps = state.laps + count
end

local function calibrate(state, before, after, distance, sim)
  if not state.observedOnly or not state.canEstimate or distance <= 0
    or before.physicsAvailable == false or after.physicsAvailable == false then return end
  local c = state.calibration
  local deltas = {}
  for i = 1, 4 do
    local a, b = before.virtual[i], after.virtual[i]
    if a == nil or b == nil or b <= a then return end
    deltas[i] = b - a
    -- Require several consistent intervals, rather than trusting one sample.
    if c.samples > 0 then
      local ratio = (deltas[i] / distance) / (c.virtual[i] / c.km)
      if ratio < 0.75 or ratio > 1.25 then
        state.calibration = { km = 0, samples = 0, virtual = {0, 0, 0, 0} }
        return
      end
    end
  end
  c.km, c.samples = c.km + distance, c.samples + 1
  for i = 1, 4 do c.virtual[i] = c.virtual[i] + deltas[i] end
  if c.samples < 3 or c.km < 0.1 then return end
  local prior = 0
  for i = 1, 4 do
    local origin = state.origin.virtual[i]
    if origin == nil then return end
    prior = prior + origin * (c.km / c.virtual[i]) / 4
  end
  if number(prior) == nil then return end
  state.priorKm, state.observedOnly = prior, false
  local length = nonnegative(U.read(sim, 'trackLengthM', nil))
  local priorLaps = length and length > 0 and number(prior / (length / 1000))
  if priorLaps then state.priorLaps = math.floor(priorLaps) end
  state.approximate = true
end

function M.update(state, car, sim, dt)
  subscribe()
  dt = nonnegative(dt) or 0
  local ctx = context(car, sim)
  if contextReset(state.context, ctx, sim, dt) then clear(state) end
  -- Missing car or sim fields cannot erase the identity of the last valid sample.
  if state.context then
    for key, value in pairs(state.context) do
      if ctx[key] == nil then ctx[key] = value end
    end
  end
  state.context = ctx
  if car == nil then
    -- Do not bridge odometer, lap or wear changes across unavailable telemetry.
    state.previous, state.pendingCounter, state.pendingWrap = nil, nil, nil
    state.calibration = { km = 0, samples = 0, virtual = {0, 0, 0, 0} }
    state.approximate = true
    return snapshot(state)
  end
  local value = sample(car)
  local before = state.previous
  local replaced, ambiguous = false, false
  if state.lastTyres then replaced, ambiguous = tyreChange(state.lastTyres, value) end
  if replaced then
    clear(state)
    state.context = ctx
    baseline(state, value)
    return snapshot(state)
  end
  state.lastTyres = value
  if before == nil then
    if state.origin == nil then baseline(state, value)
    else state.previous = value end
    return snapshot(state)
  end
  local elapsed = elapsedSeconds(sim, dt, ctx.replay)
  local speed = math.max(before.speed or 600, value.speed or 600)
  local maximumKm = math.max(0.05, speed * elapsed / 3600 * 3 + 0.02)
  local delta = before.odometer and value.odometer
    and value.distanceSource == before.distanceSource and value.odometer - before.odometer or nil
  local jumped = U.read(car, 'justJumped', false) == true
    or different(before.resetCounter, value.resetCounter)
    or (delta ~= nil and (delta < -0.000001 or delta > maximumKm))
    or (before.lap and value.lap and value.lap < before.lap)
  if before.position and value.position then
    local metersSquared = 0
    for i = 1, 3 do metersSquared = metersSquared + (value.position[i] - before.position[i]) ^ 2 end
    if metersSquared > (maximumKm * 1000) ^ 2 then jumped = true end
  end
  if jumped or ambiguous then
    state.approximate = true
    state.calibration = { km = 0, samples = 0, virtual = {0, 0, 0, 0} }
  end
  if jumped then
    state.pendingCounter, state.pendingWrap = nil, nil
  else
    countLaps(state, before, value)
    if delta ~= nil and delta >= 0 then
      state.km = state.km + delta
      if not ambiguous then calibrate(state, before, value, delta, sim) end
    else state.approximate = true end
  end
  state.previous = value
  return snapshot(state)
end

return M
