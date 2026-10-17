local Timing = require('modules/delta/src/timing')

local State = {}
State.__index = State

local function numberOr(value, fallback)
  value = tonumber(value)
  return value or fallback
end

local function positive(value)
  value = tonumber(value)
  return value and value > 0 and value or nil
end

local function invalid(car)
  if Timing.wheelsInvalid(car) then return true end
  if Timing.field(car, 'isLapValid', nil) == false then return true end
  if Timing.field(car, 'isCurrentLapValid', nil) == false then return true end
  return false
end

local function classify(time, valid, personalBest, sessionBest)
  if not valid then return 'invalid' end
  if sessionBest == nil or time < sessionBest then return 'session_best' end
  if personalBest == nil or time < personalBest then return 'personal_best' end
  return 'slower'
end

function State.new()
  return setmetatable({
    initialized = false,
    sessionIndex = nil,
    trackID = nil,
    trackName = nil,
    transitionStartedAt = nil,
    history = {},
    current = nil,
    lastLapCount = nil,
    replayActive = false,
    lastReplayFrame = nil,
    lastUpdateTime = nil,
    personalBest = nil,
    sessionBest = nil
  }, State)
end

function State:seedBest()
  local cars = Timing.cars()
  for i = 1, #cars do
    local car = cars[i]
    local index = math.floor(numberOr(Timing.field(car, 'index', i - 1), i - 1))
    local best = positive(Timing.field(car, 'bestLapTimeMs', nil))
    if best and (self.sessionBest == nil or best < self.sessionBest) then self.sessionBest = best end
    if index == 0 and best then self.personalBest = best end
  end
end

function State:reset(sim, car)
  self.sessionIndex = sim and sim.currentSessionIndex or -1
  self.history = {}
  self.personalBest = nil
  self.sessionBest = nil
  self.lastLapCount = nil
  self.replayActive = sim and sim.isReplayActive == true or false
  self.lastReplayFrame = self.replayActive and tonumber(sim.replayCurrentFrame) or nil
  self.lastUpdateTime = type(ui.time) == 'function' and ui.time() or nil
  self.current = nil
  self.transitionStartedAt = nil
  self:seedBest()
  if car then self:startCurrent(car) end
end

function State:startCurrent(car)
  local lapCount = math.max(0, math.floor(numberOr(Timing.field(car, 'lapCount',
    Timing.field(car, 'sessionLapCount', 0)), 0)))
  self.current = {
    number = lapCount + 1,
    time = Timing.lapTimeMs(car),
    estimatedTime = positive(Timing.field(car, 'estimatedLapTimeMs', nil)),
    progress = Timing.currentSpline(car, self.trackName),
    status = 'current',
    invalid = invalid(car),
    inPits = Timing.isInPit(car)
  }
  self.lastLapCount = lapCount
end

function State:initialize(sim, car)
  self.trackID = Timing.trackID()
  self.trackName = Timing.trackName()
  self.initialized = true
  self:reset(sim, car)
end

function State:completeCurrent(car, animate)
  if not self.current then return end
  local time = positive(Timing.previousLapTime(car))
  if not time then return end
  local valid = not self.current.invalid
  local status = classify(time, valid, self.personalBest, self.sessionBest)
  table.insert(self.history, 1, {
    number = self.current.number,
    time = time,
    invalid = not valid,
    inPits = self.current.inPits,
    status = status
  })
  while #self.history > 32 do table.remove(self.history) end
  self.transitionStartedAt = animate and type(ui.time) == 'function' and ui.time() or nil
  if valid and (self.personalBest == nil or time < self.personalBest) then self.personalBest = time end
  if valid and (self.sessionBest == nil or time < self.sessionBest) then self.sessionBest = time end
end

function State:updateSessionBest()
  local cars = Timing.cars()
  for i = 1, #cars do
    local best = positive(Timing.field(cars[i], 'bestLapTimeMs', nil))
    if best and (self.sessionBest == nil or best < self.sessionBest) then self.sessionBest = best end
  end
end

function State:updateCurrentStatus(car)
  if self.current.invalid then
    self.current.status = 'invalid'
    return
  end
  local estimate = positive(Timing.field(car, 'estimatedLapTimeMs', nil))
  if not estimate or (not self.personalBest and not self.sessionBest) then
    self.current.status = 'current'
  elseif self.sessionBest and estimate < self.sessionBest then
    self.current.status = 'session_best'
  elseif self.personalBest and estimate < self.personalBest then
    self.current.status = 'personal_best'
  else
    self.current.status = 'slower'
  end
end

function State:replayDiscontinuity(sim, now)
  if self.replayActive ~= (sim.isReplayActive == true) then return true end
  local frame = self.replayActive and tonumber(sim.replayCurrentFrame) or nil
  if frame == nil or self.lastReplayFrame == nil then return false end
  local frameDelta = frame - self.lastReplayFrame
  if frameDelta < 0 then return true end
  local frameMs = positive(sim.replayFrameMs)
  if not frameMs or now == nil or self.lastUpdateTime == nil then return false end
  local elapsed = math.max(0, now - self.lastUpdateTime)
  local rate = math.max(1, math.abs(numberOr(sim.replayPlaybackRate, 1)))
  return frameDelta * frameMs > math.max(1000, elapsed * 1000 * rate + 250)
end

function State:update()
  local ok, sim = pcall(ac.getSim)
  if not ok or not sim then return false end
  local car = Timing.getCar(0)
  local trackID = Timing.trackID()
  if not self.initialized or self.trackID ~= trackID then self:initialize(sim, car) end
  if self.sessionIndex ~= sim.currentSessionIndex then self:reset(sim, car) end
  if not car then return true end

  local lapCount = math.max(0, math.floor(numberOr(Timing.field(car, 'lapCount',
    Timing.field(car, 'sessionLapCount', 0)), 0)))
  local now = type(ui.time) == 'function' and ui.time() or nil
  if self:replayDiscontinuity(sim, now) or (self.lastLapCount ~= nil
      and (lapCount < self.lastLapCount or lapCount > self.lastLapCount + 1)) then
    self:reset(sim, car)
    return true
  end
  if not self.current then self:startCurrent(car) end

  local spline = Timing.currentSpline(car, self.trackName)
  local lapChanged = self.lastLapCount ~= nil and lapCount > self.lastLapCount
  if lapChanged then
    self:completeCurrent(car, sim.isLive ~= false or (sim.isReplayActive == true
      and numberOr(sim.replayPlaybackRate, 1) > 0))
    self:startCurrent(car)
  end

  self.current.time = Timing.lapTimeMs(car)
  self.current.estimatedTime = positive(Timing.field(car, 'estimatedLapTimeMs', nil))
  self.current.progress = spline
  if invalid(car) then self.current.invalid = true end
  if Timing.isInPit(car) then self.current.inPits = true end
  self.lastLapCount = lapCount
  self.lastReplayFrame = self.replayActive and tonumber(sim.replayCurrentFrame) or nil
  self.lastUpdateTime = now
  self:updateSessionBest()
  self:updateCurrentStatus(car)
  return true
end

function State:snapshot()
  return {
    current = self.current,
    transitionStartedAt = self.transitionStartedAt,
    history = self.history,
    personalBest = self.personalBest,
    sessionBest = self.sessionBest
  }
end

return State
