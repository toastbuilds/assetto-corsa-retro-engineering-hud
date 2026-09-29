local Session = require('modules/leaderboard/src/session')
local Classes = require('modules/leaderboard/src/classes')
local FlagCause = require('src/flag_cause')

local M = {}

local function read(object, key)
  if object == nil then return nil end
  local ok, value = pcall(function() return object[key] end)
  return ok and value or nil
end

local function number(value)
  value = tonumber(value)
  return value and value == value and value or nil
end

local function bool(value)
  return value == true
end

local function safeDriverName(index, car)
  local name
  pcall(function() name = car:driverName() end)
  if not name or name == '' then pcall(function() name = ac.getDriverName(index) end) end
  return name and tostring(name) or ''
end

local function safeCarID(car)
  local value
  pcall(function() value = car:id() end)
  return value and tostring(value) or ''
end

local function safeCarName(car)
  local value
  pcall(function() value = car:name() end)
  return value and tostring(value) or ''
end

local function safeNumberMethod(car, method)
  local value
  pcall(function() value = car[method](car) end)
  return number(value)
end

local function safeNumberField(car, key)
  return number(read(car, key))
end

local function cloneSplits(source)
  if source == nil then return nil end
  local ok, count = pcall(function() return #source end)
  if not ok or not count or count <= 0 then return nil end
  local out = {}
  for index = 0, count - 1 do
    local value = number(read(source, index))
    out[index + 1] = value
  end
  return out
end

local function validTime(value)
  return value ~= nil and value > 0
end

local function isPit(car)
  return bool(read(car, 'isInPitlane')) or bool(read(car, 'isInPit'))
end

local function statusFor(car, isLocal, race)
  if bool(read(car, 'isRaceFinished')) or bool(read(car, 'isFinished')) then return 'FIN' end
  if bool(read(car, 'isRetired')) or bool(read(car, 'isRaceRetired')) then return 'RET' end
  if isPit(car) then return 'PIT' end
  if not isLocal and read(car, 'isConnected') == false then return 'OFF' end
  if not isLocal and read(car, 'isActive') == false then return 'OFF' end
  if race then return 'L ' .. tostring(math.max(1, math.floor((safeNumberField(car, 'lapCount') or 0) + 1))) end
  return 'LIVE'
end

local function collectCars()
  local cars = {}
  local function append(car)
    if car == nil then return end
    local index = number(read(car, 'index'))
    if index == nil then return end
    for i = 1, #cars do
      if cars[i].index == index then return end
    end
    cars[#cars + 1] = car
  end

  local ok = pcall(function()
    for _, car in ac.iterateCars.leaderboard() do append(car) end
  end)
  if not ok or #cars == 0 then
    pcall(function()
      for _, car in ac.iterateCars() do append(car) end
    end)
  end
  return cars
end

local function makeRow(car, session, settings)
  local index = number(read(car, 'index'))
  local isLocal = index == 0
  local connected = read(car, 'isConnected')
  local active = read(car, 'isActive')
  local driver = safeDriverName(index, car)
  local best = safeNumberField(car, 'bestLapTimeMs')
  local last = safeNumberField(car, 'previousLapTimeMs')
  local lapCount = safeNumberField(car, 'lapCount') or safeNumberField(car, 'sessionLapCount') or 0
  local spline = safeNumberField(car, 'splinePosition') or 0
  local speedMs = safeNumberField(car, 'speedMs') or safeNumberField(car, 'speedKmh') and safeNumberField(car, 'speedKmh') / 3.6 or 0
  local carID, carName = safeCarID(car), safeCarName(car)
  local classID, classSource = Classes.detect(carID, carName, settings.automaticClasses ~= false)
  local row = {
    index = index, driver = driver, number = safeNumberMethod(car, 'driverNumber'),
    carID = carID, carName = carName, classID = classID, classSource = classSource,
    connected = connected ~= false, active = active ~= false, isLocal = isLocal,
    racePosition = number(read(car, 'racePosition')) or 999,
    lapCount = lapCount, splinePosition = math.max(0, math.min(1, spline)),
    progress = lapCount + math.max(0, math.min(1, spline)), speedMs = speedMs,
    speedKmh = speedMs * 3.6, bestLapTimeMs = best, lastLapTimeMs = last,
    currentLapTimeMs = safeNumberField(car, 'currentLapTimeMs') or safeNumberField(car, 'currentLapTime'),
    currentSector = number(read(car, 'currentSector')) or 0,
    currentSplits = cloneSplits(read(car, 'currentSplits')),
    lastSplits = cloneSplits(read(car, 'lastSplits')),
    isLastLapValid = read(car, 'isLastLapValid'),
    tyreCompound = tostring(read(car, 'tyreCompound') or read(car, 'tyresName') or ''),
    status = statusFor(car, isLocal, Session.isRace(session)),
    car = car
  }
  return row
end

local function practiceSort(a, b)
  local aValid, bValid = validTime(a.bestLapTimeMs), validTime(b.bestLapTimeMs)
  if aValid ~= bValid then return aValid end
  if aValid and a.bestLapTimeMs ~= b.bestLapTimeMs then return a.bestLapTimeMs < b.bestLapTimeMs end
  if a.connected ~= b.connected then return a.connected end
  return a.driver < b.driver
end

local function raceSort(a, b)
  if a.racePosition ~= b.racePosition then return a.racePosition < b.racePosition end
  if a.progress ~= b.progress then return a.progress > b.progress end
  return a.driver < b.driver
end

local function shouldKeep(row, session)
  if row.driver == '' then return false end
  if Session.isRace(session) then return true end
  return row.connected or validTime(row.bestLapTimeMs)
end

local function capturePositions(rows, target)
  for i = 1, #rows do
    if target[rows[i].index] == nil then target[rows[i].index] = i end
  end
end

local function observeLapPositionDeltas(state, rows, race)
  for i = 1, #rows do
    local row = rows[i]
    if not race then
      row.lapPositionDelta = nil
    else
      local lap = math.max(0, math.floor(number(row.lapCount) or 0))
      local previousLap = state.lastLapCounts[row.index]
      if previousLap == nil or lap < previousLap then
        state.lastLapCounts[row.index] = lap
        state.lapStartPositions[row.index] = row.position
        state.lapPositionDeltas[row.index] = nil
      elseif lap > previousLap then
        local startPosition = state.lapStartPositions[row.index] or row.position
        state.lapPositionDeltas[row.index] = startPosition - row.position
        state.lastLapCounts[row.index] = lap
        state.lapStartPositions[row.index] = row.position
      end
      row.lapPositionDelta = state.lapPositionDeltas[row.index]
    end
  end
end

local function observeImprovements(state, row, now)
  local oldBest = state.bestSeen[row.index]
  if validTime(row.bestLapTimeMs) and (oldBest == nil or row.bestLapTimeMs < oldBest - 0.5) then
    if oldBest ~= nil then state.improvementUntil[row.index] = now + 2.8 end
    state.bestSeen[row.index] = row.bestLapTimeMs
  elseif oldBest == nil and validTime(row.bestLapTimeMs) then
    state.bestSeen[row.index] = row.bestLapTimeMs
  end
  if state.improvementUntil[row.index] and state.improvementUntil[row.index] > now then
    row.improvement = 'PB'
  end
end

function M.new()
  return {
    sessionIndex = nil, rows = {}, shownRows = {}, localRow = nil,
    sessionPositions = {}, racePositions = {}, raceCaptured = false,
    lapStartPositions = {}, lastLapCounts = {}, lapPositionDeltas = {},
    bestSeen = {}, improvementUntil = {}, sessionBest = nil, enteredAt = 0,
    snapshot = nil
  }
end

function M.empty()
  return {
    header = { typeLabel = 'WAIT', timeText = '--:--', currentLapText = '--', lapsText = 'LAPS: --', ambientText = '--', trackText = '--' },
    rows = {}, shownRows = {}, localRow = nil, session = nil, sim = nil,
    flagLabel = nil, flagRole = nil, lapsRemaining = nil, enteredAt = ui.time(), error = nil
  }
end

function M.selectRows(rows, localRow, maxRows)
  local limit = math.max(3, math.floor(tonumber(maxRows) or 6))
  if #rows <= limit then return rows end
  if localRow == nil then
    local out = {}
    for i = 1, limit do out[i] = rows[i] end
    return out
  end

  local localIndex = 1
  for i = 1, #rows do if rows[i].index == localRow.index then localIndex = i break end end
  local selected = {}
  local seen = {}
  local function add(index)
    if index >= 1 and index <= #rows and not seen[index] and #selected < limit then
      seen[index] = true; selected[#selected + 1] = rows[index]
    end
  end

  add(1)
  local half = math.floor((limit - 2) / 2)
  for offset = half, 1, -1 do add(localIndex - offset) end
  add(localIndex)
  for offset = 1, limit do add(localIndex + offset) end
  -- Fill any remaining slots near the local driver while preserving order.
  for i = 1, #rows do add(i) end
  table.sort(selected, function(a, b) return a.racePosition < b.racePosition or (a.racePosition == b.racePosition and a.progress > b.progress) end)
  return selected
end

function M.update(state, settings)
  local sim, session = Session.safeCurrent()
  -- CSP can briefly expose simulation data before its session object. Cars
  -- are still useful in that interval, so only give up when the sim is absent.
  if sim == nil then
    return M.empty()
  end
  local sessionIndex = number(read(sim, 'currentSessionIndex')) or 0
  local now = ui.time()
  if state.sessionIndex ~= sessionIndex then
    state.sessionIndex = sessionIndex
    state.rows, state.shownRows, state.localRow = {}, {}, nil
    state.sessionPositions, state.racePositions = {}, {}
    state.lapStartPositions, state.lastLapCounts, state.lapPositionDeltas = {}, {}, {}
    state.raceCaptured, state.bestSeen, state.improvementUntil = false, {}, {}
    state.sessionBest, state.enteredAt = nil, now
  end

  local rows = {}
  local flagKind, flagIndex = FlagCause.resolve(sim)
  local rawCars = collectCars()
  for i = 1, #rawCars do
    local row = makeRow(rawCars[i], session, settings)
    if row.index ~= 0 and row.index == flagIndex then row.flagCauseKind = flagKind end
    if shouldKeep(row, session) then rows[#rows + 1] = row end
  end
  if Session.isRace(session) then table.sort(rows, raceSort) else table.sort(rows, practiceSort) end
  for i = 1, #rows do
    rows[i].position = i
    if not Session.isRace(session) then rows[i].racePosition = i end
    observeImprovements(state, rows[i], now)
  end
  observeLapPositionDeltas(state, rows, Session.isRace(session))

  if next(state.sessionPositions) == nil then capturePositions(rows, state.sessionPositions) end
  local raceStarted = not Session.isRace(session) or (read(sim, 'raceFlagType') ~= nil and read(ac.FlagType, 'None') ~= read(sim, 'raceFlagType'))
  if Session.isRace(session) and raceStarted and not state.raceCaptured then
    capturePositions(rows, state.racePositions)
    state.raceCaptured = true
  end

  local sessionBest
  for i = 1, #rows do
    if validTime(rows[i].bestLapTimeMs) and (sessionBest == nil or rows[i].bestLapTimeMs < sessionBest) then sessionBest = rows[i].bestLapTimeMs end
  end
  state.sessionBest = sessionBest
  for i = 1, #rows do
    local row = rows[i]
    row.sessionBest = sessionBest ~= nil and row.bestLapTimeMs == sessionBest
    local start = Session.isRace(session) and state.racePositions[row.index] or state.sessionPositions[row.index]
    row.positionDelta = start and start - row.position or 0
  end

  local localRow
  for i = 1, #rows do if rows[i].isLocal then localRow = rows[i] break end end
  local leaderRow = rows[1]
  local header = Session.snapshotHeader(sim, session, localRow, leaderRow, sessionBest, settings)
  local shown = M.selectRows(rows, localRow, settings.maxRows)
  state.rows, state.shownRows, state.localRow = rows, shown, localRow
  local snapshot = {
    header = header, rows = rows, shownRows = shown, localRow = localRow,
    leaderRow = leaderRow, session = session, sim = sim, sessionBest = sessionBest,
    lapsRemaining = Session.lapsRemaining(session, sim, localRow, leaderRow, sessionBest),
    flagLabel = header.flagLabel, flagRole = header.flagRole, enteredAt = state.enteredAt
  }
  state.snapshot = snapshot
  return snapshot
end

return M
