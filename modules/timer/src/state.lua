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
  local reference = sessionBest
  local delta = reference and time - reference or nil
  if not valid then return 'invalid', reference, delta end
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
    elapsedTime = 0,
    lastUiTime = nil,
    sectorRecordEventId = 0,
    lapRecordEventId = 0,
    lapCompletedEventId = 0,
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

function State:advanceClock(dt)
  local uiNow = type(ui.time) == 'function' and tonumber(ui.time()) or nil
  dt = tonumber(dt)
  if dt and dt >= 0 then
    self.elapsedTime = self.elapsedTime + dt
  elseif uiNow and self.lastUiTime then
    self.elapsedTime = self.elapsedTime + math.max(0, uiNow - self.lastUiTime)
  end
  self.lastUiTime = uiNow
  return self.elapsedTime
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
  self.raceEnd = { observations = {} }
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
  local now = self.elapsedTime
  self.result = {
    kind = kind,
    index = index,
    time = time,
    status = status,
    delta = delta,
    valid = valid,
    createdAt = now,
    expiresAt = now + 2
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
    if status == 'session_best' then self.sectorRecordEventId = self.sectorRecordEventId + 1 end
  end
  if valid and (oldSession == nil or time < oldSession) then self.sessionBestSectors[sector] = time end
end

function State:completeLap(carState, car)
  local lap = carState.lap
  if not lap then return end
  if carState.index == 0 then self.lapCompletedEventId = self.lapCompletedEventId + 1 end
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
    if status == 'session_best' then self.lapRecordEventId = self.lapRecordEventId + 1 end
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
  local ok, session = pcall(ac.getSession, sim.currentSessionIndex)
  if not ok or not Session.isRace(session) then
    self.raceEnd = { observations = {} }
    return false
  end
  local state = self.raceEnd or { observations = {} }
  local remaining = Session.timeLeftSeconds(sim, session)
  local frame = sim.isReplayActive == true and tonumber(sim.replayCurrentFrame) or nil
  local completed = math.max(0, math.floor(numberOr(Timing.field(player,'lapCount',
    Timing.field(player,'sessionLapCount',0)),0)))
  if (frame and state.frame and frame < state.frame)
      or (state.playerLaps and completed < state.playerLaps)
      or (remaining and state.remaining and remaining > state.remaining + 5) then
    state = { observations = {} }
  end
  self.raceEnd = state
  state.frame, state.playerLaps, state.remaining = frame, completed, remaining

  local flag = Session.flag(sim, session)
  if flag == 'FINISH' or sim.isSessionFinished == true or session.isSessionFinished == true
      or session.isFinished == true or Timing.field(player,'isRaceFinished',false) then
    state.active, state.expired = false, false
    return false
  end
  -- The official last-lap flag overrides every fallback, including extra laps.
  if flag == 'LAST LAP' then state.active = true end

  local leader, observations, leaderPosition, leaderProgress = nil, {}, math.huge, -math.huge
  for _, car in ipairs(Timing.cars()) do
    if Timing.field(car,'isActive',true) ~= false and Timing.field(car,'isConnected',true) ~= false then
      local index = Timing.field(car,'index',nil)
      local lap = numberOr(Timing.field(car,'lapCount',Timing.field(car,'sessionLapCount',0)),0)
      local spline = Timing.currentSpline(car,self.trackName)
      local position = positive(Timing.field(car,'racePosition',nil)) or math.huge
      if index ~= nil then
        local before = state.observations[index]
        local after = {lap=lap,spline=spline,crossed=false}
        if before and lap >= before.lap then
          local counterChanged = lap > before.lap
          local wrapped = before.spline > 0.75 and spline < 0.25
          local counterCross = counterChanged and not (before.pendingCounter and lap <= before.pendingCounter)
          local splineCross = wrapped and not before.pendingSpline
          after.crossed = counterCross or splineCross
          -- Counter and spline can arrive on different frames. Count one crossing.
          if splineCross and not counterChanged then after.pendingCounter = lap+1
          elseif before.pendingCounter and lap < before.pendingCounter then after.pendingCounter = before.pendingCounter end
          after.pendingSpline = not wrapped and (before.pendingSpline or (counterCross and spline > 0.75))
        end
        observations[index] = after
      end
      if position < leaderPosition or (position == leaderPosition and lap+spline > leaderProgress) then
        leader, leaderPosition, leaderProgress = car, position, lap+spline
      end
    end
  end
  local crossed = false
  if leader then
    local index = Timing.field(leader,'index',nil)
    crossed = observations[index] ~= nil and observations[index].crossed == true
  end
  state.observations = observations

  if not Session.isTimed(session) then
    local total = positive(session.laps)
    if total and completed >= math.max(0,math.floor(total+0.5)-1) then state.active = true end
  else
    if remaining ~= nil and remaining <= 0 then state.expired = true end
    if state.expired and (session.hasAdditionalLap ~= true or crossed) then state.active = true end
  end
  return state.active == true
end

function State:publishPlayerData(player)
  if not player then return end
  local playerState = self.cars[0]
  self.data.currentLapTime = Timing.lapTimeMs(player)
  self.data.lapNumber = playerState and playerState.lap and playerState.lap.number
    or math.max(0, math.floor(numberOr(Timing.field(player, 'lapCount',
      Timing.field(player, 'sessionLapCount', 0)), 0))) + 1
  self.data.sector = Timing.currentSector(player, self.sectorCount)
  self.data.invalid = playerState and playerState.lap and playerState.lap.invalid == true or isLapInvalid(player)
  self.data.inPits = playerState and playerState.lap and playerState.lap.inPits == true or Timing.isInPit(player)
end

function State:update(dt)
  self:advanceClock(dt)
  local ok, sim = pcall(ac.getSim)
  if not ok or not sim then return false end
  self:ensureContext(sim)
  local player = Timing.getCar(0)
  if sim.isLive == false or sim.isReplayActive == true then
    if sim.isReplayActive == true then
      self.cars = {}
      self.result = nil
      self.lastPlayerLapCount = nil
    end
    self:publishPlayerData(player)
    self.data.finalLap = player and self:isFinalLap(sim, player) or false
    return true
  end

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

  self:publishPlayerData(player)
  self.data.finalLap = player and self:isFinalLap(sim, player) or false
  self.data.sectorCount = self.sectorCount
  return true
end

function State:snapshot()
  local now = self:advanceClock()
  if self.result and now >= self.result.expiresAt then self.result = nil end
  self.data.clock = now
  self.data.result = self.result
  self.data.sectorRecordEventId = self.sectorRecordEventId
  self.data.lapRecordEventId = self.lapRecordEventId
  self.data.lapCompletedEventId = self.lapCompletedEventId
  return self.data
end

return State
