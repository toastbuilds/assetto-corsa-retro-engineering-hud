local Session = require('modules/leaderboard/src/session')
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

local function arrayValue(values, index)
  if values == nil then return nil end
  local ok, value = pcall(function() return values[index] end)
  return ok and positive(value) or nil
end

local function isLapInvalid(car)
  if Timing.wheelsInvalid(car) then return true end
  if Timing.field(car, 'isLapValid', nil) == false then return true end
  if Timing.field(car, 'isCurrentLapValid', nil) == false then return true end
  return false
end

local function bestSplits(car)
  for _, key in ipairs({ 'bestSplits', 'bestSectorTimes', 'bestSectors' }) do
    local values = Timing.field(car, key, nil)
    if values ~= nil then return values end
  end
  return nil
end

local function newLap(lapCount, sectorCount)
  local lap = {
    number = math.max(1, math.floor(numberOr(lapCount, 0)) + 1),
    invalid = false,
    inPits = false,
    splits = {}
  }
  for i = 0, math.max(1, sectorCount) - 1 do lap.splits[i] = 0 end
  return lap
end

local function classify(time, valid, personalBest, sessionBest)
  if not valid then return 'invalid', personalBest or sessionBest, nil end
  local reference = personalBest or sessionBest
  local delta = reference and time - reference or nil
  if sessionBest == nil or time < sessionBest then return 'session_best', reference, delta end
  if personalBest == nil or time < personalBest then return 'personal_best', reference, delta end
  return 'slower', reference, delta
end

function State.new(settings)
  return setmetatable({
    settings = settings,
    initialized = false,
    sessionIndex = nil,
    trackID = nil,
    trackName = nil,
    sectorSplits = nil,
    sectorCount = 1,
    cars = {},
    personalBestLap = nil,
    sessionBestLap = nil,
    personalBestSectors = {},
    sessionBestSectors = {},
    result = nil,
    audioEventId = 0,
    lastPlayerLapCount = nil,
    data = {
      currentLapTime = 0,
      lapNumber = 1,
      sector = 0,
      sectorCount = 1,
      invalid = false,
      inPits = false,
      finalLap = false
    }
  }, State)
end

function State:seedRecords()
  local cars = Timing.cars()
  for i = 1, #cars do
    local car = cars[i]
    local index = math.floor(numberOr(Timing.field(car, 'index', i - 1), i - 1))
    local bestLap = positive(Timing.field(car, 'bestLapTimeMs', nil))
    if bestLap and (self.sessionBestLap == nil or bestLap < self.sessionBestLap) then self.sessionBestLap = bestLap end
    if index == 0 and bestLap then self.personalBestLap = bestLap end
    local splits = bestSplits(car)
    for sector = 0, self.sectorCount - 1 do
      local value = arrayValue(splits, sector)
      if value and (self.sessionBestSectors[sector] == nil or value < self.sessionBestSectors[sector]) then
        self.sessionBestSectors[sector] = value
      end
      if index == 0 and value then self.personalBestSectors[sector] = value end
    end
  end
end

function State:resetSession(sim)
  self.sessionIndex = sim and sim.currentSessionIndex or -1
  self.cars = {}
  self.personalBestLap = nil
  self.sessionBestLap = nil
  self.personalBestSectors = {}
  self.sessionBestSectors = {}
  self.result = nil
  self.lastPlayerLapCount = nil
  self.data.currentLapTime = 0
  self.data.lapNumber = 1
  self.data.sector = 0
  self.data.invalid = false
  self.data.inPits = false
  self.data.finalLap = false
  self:seedRecords()
end

function State:initialize(sim)
  self.trackName = Timing.trackName()
  self.trackID = Timing.trackID()
  self.sectorSplits, self.sectorCount = Timing.sectorSplits(sim)
  self.data.sectorCount = self.sectorCount
  self.initialized = true
  self:resetSession(sim)
end

function State:ensureContext(sim)
  local trackID = Timing.trackID()
  if not self.initialized or trackID ~= self.trackID then
    self:initialize(sim)
    return
  end
  if self.sessionIndex ~= sim.currentSessionIndex then self:resetSession(sim) end
end

function State:showResult(kind, index, time, status, delta, valid)
  local now = type(ui.time) == 'function' and ui.time() or 0
  self.result = {
    kind = kind,
    index = index,
    time = time,
    status = status,
    delta = delta,
    valid = valid,
    createdAt = now,
    expiresAt = now + (self.settings.freezeDuration or 3)
  }
end

function State:finishSector(carState, car, newSector)
  local lap = carState.lap
  if not lap then return end
  local time, sector = Timing.completedSectorTime(car, newSector, self.sectorCount, lap)
  if time <= 0 then return end
  lap.splits[sector] = time
  local valid = not lap.invalid
  local oldSession = self.sessionBestSectors[sector]
  if carState.index == 0 then
    local oldPersonal = self.personalBestSectors[sector]
    local status, _, delta = classify(time, valid, oldPersonal, oldSession)
    self:showResult('sector', sector, time, status, delta, valid)
    if valid and (oldPersonal == nil or time < oldPersonal) then self.personalBestSectors[sector] = time end
    if status == 'session_best' then self.audioEventId = self.audioEventId + 1 end
  end
  if valid and (oldSession == nil or time < oldSession) then self.sessionBestSectors[sector] = time end
end

function State:completeLap(carState, car)
  local lap = carState.lap
  if not lap then return end
  local time = positive(Timing.previousLapTime(car))
  if not time then
    time = 0
    for sector = 0, self.sectorCount - 1 do time = time + numberOr(lap.splits[sector], 0) end
    if time <= 0 then time = nil end
  end
  if not time then return end
  local valid = not lap.invalid
  local oldSession = self.sessionBestLap
  if carState.index == 0 then
    local oldPersonal = self.personalBestLap
    local status, _, delta = classify(time, valid, oldPersonal, oldSession)
    self:showResult('lap', lap.number, time, status, delta, valid)
    if valid and (oldPersonal == nil or time < oldPersonal) then self.personalBestLap = time end
    if status == 'session_best' then self.audioEventId = self.audioEventId + 1 end
  end
  if valid and (oldSession == nil or time < oldSession) then self.sessionBestLap = time end
end

function State:processCar(car)
  local index = math.floor(numberOr(Timing.field(car, 'index', 0), 0))
  local lapCount = math.max(0, math.floor(numberOr(Timing.field(car, 'lapCount', Timing.field(car, 'sessionLapCount', 0)), 0)))
  local sector = Timing.currentSector(car, self.sectorCount)
  local spline = Timing.currentSpline(car, self.trackName)
  local carState = self.cars[index]
  if not carState then
    carState = {
      index = index,
      lapCount = lapCount,
      lastSector = sector,
      lastSpline = spline,
      lap = newLap(lapCount, self.sectorCount)
    }
    self.cars[index] = carState
  end

  if lapCount < carState.lapCount then
    carState.lapCount = lapCount
    carState.lastSector = sector
    carState.lastSpline = spline
    carState.lap = newLap(lapCount, self.sectorCount)
    return
  end

  if Timing.isInPit(car) then carState.lap.inPits = true end
  if isLapInvalid(car) then carState.lap.invalid = true end

  local wrapped = self.sectorCount > 1 and sector == 0 and carState.lastSector == self.sectorCount - 1
  local splineWrapped = self.sectorCount == 1 and carState.lastSpline ~= nil
    and carState.lastSpline > 0.75 and spline < 0.25
  local lapChanged = lapCount > carState.lapCount
  if wrapped or splineWrapped or lapChanged then
    self:finishSector(carState, car, 0)
    self:completeLap(carState, car)
    carState.lapCount = lapCount
    carState.lastSector = sector
    carState.lastSpline = spline
    carState.lap = newLap(lapCount, self.sectorCount)
    if Timing.isInPit(car) then carState.lap.inPits = true end
    if isLapInvalid(car) then carState.lap.invalid = true end
    return
  end

  if sector ~= carState.lastSector then self:finishSector(carState, car, sector) end
  carState.lastSector = sector
  carState.lastSpline = spline
end

function State:isFinalLap(sim, player)
  local session
  local ok = pcall(function() session = ac.getSession(sim.currentSessionIndex) end)
  if not ok or not Session.isRace(session) then return false end
  local flag = Session.flag(sim, session)
  if flag == 'LAST LAP' then return true end
  if not Session.isTimed(session) then
    local total = positive(session and session.laps)
    local completed = math.max(0, math.floor(numberOr(Timing.field(player, 'lapCount',
      Timing.field(player, 'sessionLapCount', 0)), 0)))
    return total ~= nil and completed >= math.max(0, math.floor(total + 0.5) - 1)
  end
  return false
end

function State:update()
  local ok, sim = pcall(ac.getSim)
  if not ok or not sim then return false end
  self:ensureContext(sim)
  if sim.isLive == false then return true end

  local player = Timing.getCar(0)
  if player then
    local playerLapCount = math.max(0, math.floor(numberOr(Timing.field(player, 'lapCount',
      Timing.field(player, 'sessionLapCount', 0)), 0)))
    if self.lastPlayerLapCount ~= nil and playerLapCount < self.lastPlayerLapCount then
      self:resetSession(sim)
    end
    self.lastPlayerLapCount = playerLapCount
  end

  local cars = Timing.cars()
  local sawPlayer = false
  for i = 1, #cars do
    local car = cars[i]
    self:processCar(car)
    if math.floor(numberOr(Timing.field(car, 'index', -1), -1)) == 0 then sawPlayer = true end
  end
  if player and not sawPlayer then self:processCar(player) end

  if player then
    local playerState = self.cars[0]
    self.data.currentLapTime = Timing.lapTimeMs(player)
    self.data.lapNumber = playerState and playerState.lap and playerState.lap.number or 1
    self.data.sector = Timing.currentSector(player, self.sectorCount)
    self.data.invalid = playerState and playerState.lap and playerState.lap.invalid == true or isLapInvalid(player)
    self.data.inPits = playerState and playerState.lap and playerState.lap.inPits == true or Timing.isInPit(player)
    self.data.finalLap = self:isFinalLap(sim, player)
  end
  self.data.sectorCount = self.sectorCount
  return true
end

function State:snapshot()
  local now = type(ui.time) == 'function' and ui.time() or 0
  if self.result and now > self.result.expiresAt then self.result = nil end
  self.data.result = self.result
  self.data.audioEventId = self.audioEventId
  return self.data
end

return State
