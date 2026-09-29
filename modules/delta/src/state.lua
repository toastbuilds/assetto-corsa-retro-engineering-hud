local Constants = require('modules/delta/src/constants')
local LapData = require('modules/delta/src/lap_data')
local Storage = require('modules/delta/src/storage')
local Timing = require('modules/delta/src/timing')

local State = {}
State.__index = State

local function numberOr(value, fallback)
  value = tonumber(value)
  return value or fallback
end

local function clamp(value, minimum, maximum)
  return math.max(minimum, math.min(maximum, value))
end

local function validTime(value)
  return numberOr(value, 0) > 0
end

local function addIfPositive(total, value)
  value = numberOr(value, 0)
  return total + math.max(0, value)
end

function State.new(settings)
  local self = setmetatable({
    settings = settings,
    initialized = false,
    sessionIndex = nil,
    trackID = nil,
    trackName = nil,
    carName = nil,
    sectorSplits = nil,
    sectorCount = 1,
    storage = nil,
    currentMode = Constants.Modes.SESSION_LAP,
    cars = {},
    sessionBestLap = nil,
    sessionBestSectors = {},
    personalBestSectors = {},
    previousLap = nil,
    multiplayerBestLap = nil,
    historicalBestLap = nil,
    historicalBestSectors = {},
    notifications = { [1] = nil, [2] = nil },
    notificationMovementAt = 0,
    data = {
      timeDelta = nil,
      speedDelta = 0,
      invalid = false,
      star = '',
      sector = 0,
      sectorCount = 1,
      lapNumber = 0,
      message = 'WAITING FOR TELEMETRY'
    }
  }, State)
  return self
end

local function selectedMode(settings, sim, fallback)
  local selection = 0
  local session = nil
  if sim then pcall(function() session = ac.getSession(sim.currentSessionIndex) end) end
  local sessionType = session and session.type or (sim and sim.type)
  local sessionTypes = ac.SessionType or {}
  if sessionType == sessionTypes.Practice then selection = settings.practiceMode or 0 end
  if sessionType == sessionTypes.Qualify then selection = settings.qualifyMode or 0 end
  if sessionType == sessionTypes.Race then selection = settings.raceMode or 0 end
  if selection >= 1 and selection <= 6 then return selection - 1 end
  return Constants.normalizeMode(fallback, Constants.Modes.SESSION_LAP)
end

function State:resetSession(sim)
  self.cars = {}
  self.sessionBestLap = nil
  self.sessionBestSectors = {}
  self.personalBestSectors = {}
  self.previousLap = nil
  self.multiplayerBestLap = nil
  self.notifications[1] = nil
  self.notifications[2] = nil
  self.notificationMovementAt = 0
  self.data.timeDelta = nil
  self.data.speedDelta = 0
  self.data.invalid = false
  self.data.star = ''
  self.data.message = 'COMPLETE A CLEAN LAP'
  if sim then
    self.sessionIndex = sim.currentSessionIndex
    self.currentMode = selectedMode(self.settings, sim, self.currentMode)
  end
end

local function historySectorRecord(value)
  if type(value) ~= 'table' then return nil end
  local time = tonumber(value.time)
  local lap = value.lap
  if not time and value.splits then
    time = tonumber(value.splits[0])
    lap = value
  end
  if not time or time <= 0 or type(lap) ~= 'table' then return nil end
  return { time = time, lap = lap }
end

function State:loadHistory()
  self.historicalBestLap = nil
  self.historicalBestSectors = {}
  local stored = self.storage and self.storage:load() or nil
  if type(stored) ~= 'table' then return end
  if type(stored.fastestLap) == 'table' and validTime(stored.fastestLap.laptime) then
    self.historicalBestLap = stored.fastestLap
  end
  local sectors = stored.fastestSectors
  if type(sectors) == 'table' then
    for i = 0, self.sectorCount - 1 do
      local record = historySectorRecord(sectors[i])
      if record then self.historicalBestSectors[i] = record end
    end
  end
end

function State:persistHistory()
  if not self.storage then return false end
  return self.storage:save({
    version = 1,
    fastestLap = self.historicalBestLap,
    fastestSectors = self.historicalBestSectors
  })
end

function State:initialize()
  local simOk, sim = pcall(ac.getSim)
  if not simOk or sim == nil then return false, 'SIM_NOT_READY' end
  self.trackName = Timing.trackName()
  self.trackID = Timing.trackID()
  local player = Timing.getCar(0)
  self.carName = Timing.carName(0, player)
  self.sectorSplits, self.sectorCount = Timing.sectorSplits(sim)
  local storageOk, storage = pcall(Storage.new, self.trackID, self.carName)
  if not storageOk or storage == nil then return false, 'STORAGE_NOT_READY' end
  self.storage = storage
  self:loadHistory()
  self.currentMode = selectedMode(self.settings, sim, self.storage:getLastMode(Constants.Modes.SESSION_LAP))
  self.sessionIndex = sim.currentSessionIndex or -1
  self.initialized = true
  self:resetSession(sim)
  return true
end

function State:ensureTrack(sim)
  local trackID = Timing.trackID()
  local player = Timing.getCar(0)
  local carName = Timing.carName(0, player)
  if trackID == self.trackID and carName == self.carName then return end
  self.trackName = Timing.trackName()
  self.trackID = trackID
  self.carName = carName
  self.sectorSplits, self.sectorCount = Timing.sectorSplits(sim)
  self.storage = Storage.new(self.trackID, self.carName)
  self:loadHistory()
  self.currentMode = self.storage:getLastMode(Constants.Modes.SESSION_LAP)
  self:resetSession(sim)
end

local function addSectorReference(bucket, sector, time, lap)
  if not validTime(time) then return false end
  local old = bucket[sector]
  if old == nil or time < numberOr(old.time, 0) or numberOr(old.time, 0) <= 0 then
    bucket[sector] = { time = time, lap = lap }
    return true
  end
  return false
end

function State:pushNotification(notification)
  notification.createdAt = ui.time()
  self.notifications[2] = self.notifications[1]
  self.notifications[1] = notification
  self.notificationMovementAt = notification.createdAt
end

function State:referenceLap(mode)
  if mode == Constants.Modes.SESSION_LAP then return self.sessionBestLap end
  if mode == Constants.Modes.FASTEST_LAP then return self.historicalBestLap end
  if mode == Constants.Modes.PREVIOUS_LAP then return self.previousLap end
  if mode == Constants.Modes.MULTIPLAYER_LAP then return self.multiplayerBestLap end
  return nil
end

function State:sectorReference(mode, sector)
  if mode == Constants.Modes.SESSION_OPTIMAL then return self.personalBestSectors[sector] end
  if mode == Constants.Modes.FASTEST_OPTIMAL then return self.historicalBestSectors[sector] end
  local lap = self:referenceLap(mode)
  if not lap then return nil end
  local time = numberOr(lap.splits and lap.splits[sector], 0)
  return time > 0 and { time = time, lap = lap } or nil
end

function State:referenceLapTime(mode)
  if mode == Constants.Modes.SESSION_OPTIMAL or mode == Constants.Modes.FASTEST_OPTIMAL then
    local total, count = 0, 0
    for i = 0, self.sectorCount - 1 do
      local ref = self:sectorReference(mode, i)
      if not ref or not validTime(ref.time) then return 0 end
      total = total + ref.time
      count = count + 1
    end
    return count == self.sectorCount and total or 0
  end
  local lap = self:referenceLap(mode)
  return lap and numberOr(lap.laptime, 0) or 0
end

function State:referenceSectorTime(mode, sector)
  local ref = self:sectorReference(mode, sector)
  return ref and numberOr(ref.time, 0) or 0
end

function State:updateSectorRecords(lap, sector, time, carIndex)
  if not validTime(time) or lap.invalid_sectors[sector] == true then return end
  addSectorReference(self.sessionBestSectors, sector, time, lap)
  if carIndex == 0 then
    local changedPersonal = addSectorReference(self.personalBestSectors, sector, time, lap)
    local changedHistorical = addSectorReference(self.historicalBestSectors, sector, time, lap)
    if changedHistorical and not self.settings.saveOnClose then self:persistHistory() end
    return changedPersonal, changedHistorical
  end
end

function State:completeLap(lap, carIndex, car)
  if not lap then return end
  lap.complete = true
  local previousTime = Timing.previousLapTime(car)
  if previousTime > 0 then lap.laptime = previousTime end
  if not validTime(lap.laptime) then lap.laptime = Timing.lapTimeFromSplits(lap, self.sectorCount) end
  local sim = ac.getSim()
  lap.timestamp = numberOr(sim and sim.timestamp, 0)
  local lapIsValid = LapData.isValidForRecord(lap, self.sectorCount)

  if carIndex == 0 then
    local benchmark = self:referenceLapTime(self.currentMode)
    if self.settings.showLapNotifications then
      self:pushNotification({
        kind = 'lap',
        lapNumber = lap.lap_number,
        lapTime = lap.laptime,
        lapDelta = benchmark > 0 and lap.laptime - benchmark or nil,
        valid = lapIsValid
      })
    end
    self.previousLap = lap
    if lapIsValid then
      if self.sessionBestLap == nil or lap.laptime < numberOr(self.sessionBestLap.laptime, 0) or numberOr(self.sessionBestLap.laptime, 0) <= 0 then
        self.sessionBestLap = lap
      end
      if self.historicalBestLap == nil or lap.laptime < numberOr(self.historicalBestLap.laptime, 0) or numberOr(self.historicalBestLap.laptime, 0) <= 0 then
        self.historicalBestLap = lap
        if not self.settings.saveOnClose then self:persistHistory() end
      end
    end
  end

  if lapIsValid and (self.multiplayerBestLap == nil or lap.laptime < numberOr(self.multiplayerBestLap.laptime, 0) or numberOr(self.multiplayerBestLap.laptime, 0) <= 0) then
    self.multiplayerBestLap = lap
    if self.settings.showRecordNotifications then
      self:pushNotification({ kind = 'record', driverName = lap.playername or Timing.driverName(carIndex, car) })
    end
  end
end

function State:finishSector(carState, car, newSector)
  local lap = carState.lap
  if not lap then return end
  local time, sector = Timing.completedSectorTime(car, newSector, self.sectorCount, lap)
  if time <= 0 then return end
  lap.splits[sector] = time
  if lap.invalid == true then lap.invalid_sectors[sector] = true end
  local valid = lap.invalid_sectors[sector] ~= true
  local benchmark = self:referenceSectorTime(self.currentMode, sector)
  if carState.index == 0 and self.settings.showSectorNotifications and benchmark > 0 then
    self:pushNotification({
      kind = 'sector',
      sector = sector,
      sectorTime = time,
      sectorDelta = time - benchmark,
      valid = valid
    })
  end
  self:updateSectorRecords(lap, sector, time, carState.index)
end

function State:processCar(car)
  local index = math.floor(numberOr(Timing.field(car, 'index', 0), 0))
  local carState = self.cars[index]
  if not carState then
      carState = { index = index, lap = nil, lapNumber = 0, lastSector = 0, lastSpline = nil, lastSeen = ui.time() }
    self.cars[index] = carState
  end
  carState.lastSeen = ui.time()
  local sector = Timing.currentSector(car, self.sectorCount)
  local spline = Timing.currentSpline(car, self.trackName)
  local lapNumber = Timing.lapNumber(car, carState.lapNumber)
  local lapTime = Timing.lapTimeMs(car)

  if Timing.isInPit(car) then
    carState.lastSector = sector
    carState.lastSpline = spline
    return
  end

  if carState.lap == nil then
    if lapTime <= 0 then
      carState.lastSector = sector
      carState.lapNumber = lapNumber
      carState.lastSpline = spline
      return
    end
    local firstBoundary = numberOr(self.sectorSplits and self.sectorSplits[0], 1)
    if spline > math.min(1, firstBoundary + 0.01) then
      carState.lastSector = sector
      carState.lapNumber = lapNumber
      carState.lastSpline = spline
      return
    end
    carState.lapNumber = lapNumber
    carState.lastSector = sector
    carState.lastSpline = spline
    carState.lap = LapData.new(self.trackName, index, self.sectorCount, lapNumber,
      Timing.driverName(index, car), Timing.carName(index, car))
  end

  if lapNumber < carState.lapNumber or lapNumber - carState.lapNumber > 1 then
    carState.lap = nil
    carState.lapNumber = lapNumber
    carState.lastSector = sector
    carState.lastSpline = spline
    return
  end

  local wrapped = self.sectorCount > 1 and sector == 0 and carState.lastSector == self.sectorCount - 1
  local splineWrapped = self.sectorCount == 1 and carState.lastSpline ~= nil
    and carState.lastSpline > 0.75 and spline < 0.25
  local lapChanged = lapNumber > carState.lapNumber
  if wrapped or splineWrapped or lapChanged then
    self:finishSector(carState, car, 0)
    self:completeLap(carState.lap, index, car)
    carState.previousLap = carState.lap
    carState.lap = nil
    carState.lapNumber = lapNumber
    carState.lastSector = sector
    carState.lastSpline = spline
    return
  end

  if sector ~= carState.lastSector then self:finishSector(carState, car, sector) end
  carState.lastSector = sector
  if Timing.wheelsInvalid(car) then
    carState.lap.invalid = true
    carState.lap.invalid_sectors[sector] = true
  end
  LapData.addSample(carState.lap, spline, lapTime, Timing.speedMs(car))
  carState.lastSpline = spline
end

local function sectorStart(splits, index, count)
  if index <= 0 then return 0 end
  return clamp(numberOr(splits[index], 0), 0, 1)
end

function State:updateData(car)
  local playerState = self.cars[0]
  local lap = playerState and playerState.lap
  self.data.sector = Timing.currentSector(car, self.sectorCount)
  self.data.sectorCount = self.sectorCount
  self.data.lapNumber = playerState and playerState.lapNumber or 0
  self.data.invalid = lap and lap.invalid == true or false
  self.data.star = self.data.invalid and '*' or ''
  self.data.currentLapTime = Timing.lapTimeMs(car)
  self.data.timeDelta = nil
  self.data.speedDelta = 0
  self.data.message = 'COMPLETE A CLEAN LAP'
  if not lap then return end

  local mode = self.currentMode
  local spline = Timing.currentSpline(car, self.trackName)
  local currentLapTime = Timing.lapTimeMs(car)
  local currentSector = self.data.sector
  local reference, referenceElapsed, referenceSpeed, currentElapsed
  if mode == Constants.Modes.SESSION_OPTIMAL or mode == Constants.Modes.FASTEST_OPTIMAL then
    reference = self:sectorReference(mode, currentSector)
    if not reference then
      self.data.message = 'COLLECT REFERENCE SECTORS'
      return
    end
    local currentPrefix = Timing.currentSectorPrefix(car, currentSector, lap)
    local referencePrefix = 0
    for i = 0, currentSector - 1 do
      local part = self:sectorReference(mode, i)
      if not part then self.data.message = 'COLLECT REFERENCE SECTORS'; return end
      referencePrefix = referencePrefix + numberOr(part.time, 0)
    end
    local rawReferenceElapsed, speed = LapData.elapsedAtOffset(reference.lap, spline)
    if rawReferenceElapsed then
      referenceElapsed = rawReferenceElapsed - 0
      for i = 0, currentSector - 1 do referenceElapsed = referenceElapsed - numberOr(reference.lap.splits[i], 0) end
      referenceElapsed = math.max(0, referenceElapsed)
    else
      local start = sectorStart(self.sectorSplits, currentSector, self.sectorCount)
      local finish = currentSector + 1 < self.sectorCount and sectorStart(self.sectorSplits, currentSector + 1, self.sectorCount) or 1
      local progress = finish > start and clamp((spline - start) / (finish - start), 0, 1) or 0
      referenceElapsed = numberOr(reference.time, 0) * progress
      speed = nil
    end
    currentElapsed = currentLapTime - currentPrefix
    referenceElapsed = referenceElapsed
    referenceSpeed = speed
  else
    reference = self:referenceLap(mode)
    if not reference then
      self.data.message = 'COMPLETE A CLEAN LAP'
      return
    end
    referenceElapsed, referenceSpeed = LapData.elapsedAtOffset(reference, spline)
    if not referenceElapsed then
      referenceElapsed = numberOr(reference.laptime, 0) * spline
    end
    currentElapsed = currentLapTime
  end

  if not validTime(referenceElapsed) then return end
  self.data.timeDelta = currentElapsed - referenceElapsed
  self.data.speedDelta = Timing.speedMs(car) - numberOr(referenceSpeed, Timing.speedMs(car))
  self.data.message = nil
end

function State:update(dt)
  if not self.initialized then
    local ready = self:initialize()
    if ready ~= true then return false end
  end
  local simOk, sim = pcall(ac.getSim)
  if not simOk or sim == nil then return false end
  self:ensureTrack(sim)
  if self.sessionIndex ~= sim.currentSessionIndex then self:resetSession(sim) end
  if sim.isLive == false then return end

  local cars = Timing.cars()
  local seenPlayer = false
  for i = 1, #cars do
    local car = cars[i]
    local index = math.floor(numberOr(Timing.field(car, 'index', -1), -1))
    if index >= 0 then
      self:processCar(car)
      if index == 0 then seenPlayer = true end
    end
  end
  if not seenPlayer then
    local player = Timing.getCar(0)
    if player then self:processCar(player) end
  end
  local player = Timing.getCar(0)
  if player then self:updateData(player) end
  local now = ui.time()
  for index, carState in pairs(self.cars) do
    if now - numberOr(carState.lastSeen, now) > 5 then self.cars[index] = nil end
  end
  return true
end

function State:onSessionStart()
  if not self.initialized then return end
  local sim = ac.getSim()
  if sim then self:resetSession(sim) end
end

function State:setMode(mode)
  mode = Constants.normalizeMode(mode, self.currentMode)
  self.currentMode = mode
  if self.storage then self.storage:setLastMode(mode) end
end

function State:changeMode(direction)
  local mode = self.currentMode + (direction < 0 and -1 or 1)
  if mode < 0 then mode = 5 end
  if mode > 5 then mode = 0 end
  self:setMode(mode)
end

function State:save()
  if self.settings.saveOnClose then self:persistHistory() end
end

function State:snapshot()
  self.data.mode = self.currentMode
  self.data.modeLabel = Constants.ModeLabels[self.currentMode]
  self.data.modeShortLabel = Constants.ModeShortLabels[self.currentMode]
  self.data.currentLap = self.cars[0] and self.cars[0].lap or nil
  self.data.previousLap = self.previousLap
  self.data.sessionBestLap = self.sessionBestLap
  self.data.historicalBestLap = self.historicalBestLap
  self.data.multiplayerBestLap = self.multiplayerBestLap
  self.data.personalSector = self.personalBestSectors[self.data.sector]
  self.data.sessionSector = self.sessionBestSectors[self.data.sector]
  self.data.notification1 = self.notifications[1]
  self.data.notification2 = self.notifications[2]
  self.data.notificationMovementAt = self.notificationMovementAt
  return self.data
end

return State
