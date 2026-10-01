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
    history = {},
    current = nil,
    lastLapCount = nil,
    lastSector = nil,
    lastSpline = nil,
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
  self.lastSector = nil
  self.lastSpline = nil
  self.current = nil
  self:seedBest()
  if car then self:startCurrent(car) end
end

function State:startCurrent(car)
  local lapCount = math.max(0, math.floor(numberOr(Timing.field(car, 'lapCount',
    Timing.field(car, 'sessionLapCount', 0)), 0)))
  self.current = {
    number = lapCount + 1,
    time = Timing.lapTimeMs(car),
    invalid = invalid(car),
    inPits = Timing.isInPit(car)
  }
  self.lastLapCount = lapCount
  self.lastSector = numberOr(Timing.field(car, 'currentSector', 0), 0)
  self.lastSpline = numberOr(Timing.field(car, 'splinePosition', 0), 0)
end

function State:initialize(sim, car)
  self.trackID = Timing.trackID()
  self.initialized = true
  self:reset(sim, car)
end

function State:completeCurrent(car)
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
  if self.lastLapCount ~= nil and lapCount < self.lastLapCount then
    self:reset(sim, car)
    return true
  end
  if not self.current then self:startCurrent(car) end

  local sector = numberOr(Timing.field(car, 'currentSector', 0), 0)
  local spline = numberOr(Timing.field(car, 'splinePosition', 0), 0)
  local wrapped = self.lastSpline ~= nil and self.lastSpline > 0.75 and spline < 0.25
  local lapChanged = self.lastLapCount ~= nil and lapCount > self.lastLapCount
  if lapChanged or wrapped then
    self:completeCurrent(car)
    self:startCurrent(car)
  end

  self.current.time = Timing.lapTimeMs(car)
  if invalid(car) then self.current.invalid = true end
  if Timing.isInPit(car) then self.current.inPits = true end
  self.lastLapCount = lapCount
  self.lastSector = sector
  self.lastSpline = spline
  self:updateSessionBest()
  return true
end

function State:snapshot()
  return {
    current = self.current,
    history = self.history,
    personalBest = self.personalBest,
    sessionBest = self.sessionBest
  }
end

return State
