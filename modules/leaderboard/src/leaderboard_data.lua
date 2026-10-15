local Session = require('modules/leaderboard/src/session')
local Classes = require('modules/leaderboard/src/classes')
local FlagCause = require('src/flag_cause')
local Sectors = require('modules/leaderboard/src/sectors')
local Timeline = require('modules/leaderboard/src/timeline')

local M = {}

local function read(object, key)
  if object == nil then return nil end
  local ok, value = pcall(function() return object[key] end)
  if ok then return value end
  return nil
end

local function number(value)
  value = tonumber(value)
  return value and value == value and math.abs(value) < math.huge and value or nil
end

local function bool(value)
  return value == true
end

local function validity(value)
  if type(value) == 'boolean' then return value end
  return nil
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
  if race and (bool(read(car, 'isRaceFinished')) or bool(read(car, 'isFinished'))) then return 'FIN' end
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
  -- The player can be absent from a timing leaderboard before posting a lap.
  pcall(function() append(ac.getCar(0)) end)
  return cars
end

local function splitCount(source)
  if source == nil then return nil end
  local ok, count = pcall(function() return #source end)
  return ok and count and count > 0 and math.min(3, count) or nil
end

local function makeRow(car, session, settings, sim)
  local index = number(read(car, 'index'))
  local isLocal = index == 0
  local connected = read(car, 'isConnected')
  local active = read(car, 'isActive')
  local isAI = bool(read(car, 'isAIControlled'))
  local driver = safeDriverName(index, car)
  local best = safeNumberField(car, 'bestLapTimeMs')
  local last = safeNumberField(car, 'previousLapTimeMs')
  local lapCount = safeNumberField(car, 'lapCount') or safeNumberField(car, 'sessionLapCount') or 0
  local spline = safeNumberField(car, 'splinePosition') or 0
  local speedMs = safeNumberField(car, 'speedMs') or safeNumberField(car, 'speedKmh') and safeNumberField(car, 'speedKmh') / 3.6 or 0
  local carID, carName = safeCarID(car), safeCarName(car)
  local classID, classSource = Classes.detect(carID, carName, settings.automaticClasses ~= false)
  local currentValid
  if read(car, 'physicsAvailable') == true then
    currentValid = validity(read(car, 'isLapValid'))
    if (safeNumberField(car, 'lapCutsCount') or 0) > 0 then currentValid = false end
  end
  local sectorCount = splitCount(read(sim, 'lapSplits'))
    or splitCount(read(car, 'currentSplits')) or splitCount(read(car, 'lastSplits'))
    or splitCount(read(car, 'bestLapSplits')) or 0
  local row = {
    index = index, driver = driver, number = safeNumberMethod(car, 'driverNumber'),
    carID = carID, carName = carName, classID = classID, classSource = classSource,
    connected = connected ~= false, active = active ~= false, isLocal = isLocal, isAI = isAI,
    justJumped = bool(read(car, 'justJumped')),
    racePosition = number(read(car, 'racePosition')) or 999,
    lapCount = lapCount, splinePosition = math.max(0, math.min(1, spline)),
    progress = lapCount + math.max(0, math.min(1, spline)), speedMs = speedMs,
    speedKmh = speedMs * 3.6, bestLapTimeMs = best, lastLapTimeMs = last,
    currentLapTimeMs = safeNumberField(car, 'lapTimeMs'),
    currentSector = number(read(car, 'currentSector')) or 0,
    sectorCount = sectorCount,
    currentSplits = cloneSplits(read(car, 'currentSplits')),
    lastSplits = cloneSplits(read(car, 'lastSplits')),
    bestLapSplits = cloneSplits(read(car, 'bestLapSplits')),
    currentLapValid = currentValid,
    isLastLapValid = validity(read(car, 'isLastLapValid')),
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

local function observeRace(state, rows, started, now, settings)
  local duration = math.max(1, math.min(120, number(settings.positionChangeDuration) or 40))
  local present = {}
  for i = 1, #rows do
    local row = rows[i]
    present[row.index] = true
    local identity = row.driver .. '/' .. row.carID
    local previous = state.pilots[row.index]
    local reconnected = previous and (previous.identity ~= identity
      or previous.connected == false and row.connected == true or previous.missing)
    row.reconnected = reconnected == true
    if not previous or reconnected or row.lapCount < previous.lap then
      previous = {identity = identity, position = row.position, lap = row.lapCount,
        startPosition = row.position, balance = 0,
        label = started and 'CONNECTION' or 'START'}
      state.pilots[row.index] = previous
    end
    if not started then
      -- Follow the grid until the start is actually observed.
      previous.startPosition, previous.balance, previous.label = row.position, 0, 'START'
      previous.change, previous.changeUntil = nil, nil
    elseif not previous.finished and row.connected then
      local delta = previous.position - row.position
      if delta ~= 0 then previous.change, previous.changeUntil = delta, now + duration end
      -- This is cumulative race movement, sampled at each completed lap.
      if row.lapCount > previous.lap or row.status == 'FIN' then
        previous.balance = previous.startPosition - row.position
      end
    end
    if row.status == 'FIN' then previous.finished = true end
    if previous.finished then row.status = 'FIN' end
    row.lapPositionDelta, row.positionDelta = previous.balance, previous.balance
    row.balanceLabel = previous.label
    if previous.changeUntil and now < previous.changeUntil then
      row.positionChangeDelta, row.positionChangeUntil = previous.change, previous.changeUntil
    end
    previous.position, previous.lap, previous.connected, previous.missing = row.position, row.lapCount, row.connected, false
  end
  for index, pilot in pairs(state.pilots) do
    if not present[index] then pilot.missing = true end
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
    pilots = {}, sectorConnections = {}, sectors = Sectors.new(), timeline = nil,
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
  local limit = math.max(3, math.min(10, math.floor(number(maxRows) or 5)))
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
  add(localIndex)
  for offset = 1, #rows do
    add(localIndex - offset)
    add(localIndex + offset)
    if #selected == limit then break end
  end
  -- The input is already ordered for the session: preserve that order.
  local out = {}
  for i = 1, #rows do if seen[i] then out[#out + 1] = rows[i] end end
  return out
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
  local timeline = Timeline.sample(sim)
  local started = read(sim, 'isSessionStarted') == true
  local historyReset = state.sessionIndex ~= sessionIndex or state.sessionType ~= (session and session.type)
    or Timeline.discontinuous(state.timeline, timeline, sim)
    or state.started == true and read(sim, 'isSessionStarted') == false
      and read(sim, 'isSessionFinished') ~= true and read(session, 'isOver') ~= true
  -- A restart can keep the same session ID and flag. Catch the player's
  -- completed lap counter moving backwards before retaining final results.
  local player
  pcall(function() player = ac.getCar(0) end)
  local playerLap = safeNumberField(player, 'lapCount')
  if playerLap and state.playerLap and playerLap < state.playerLap then historyReset = true end
  if historyReset then
    state.sessionIndex = sessionIndex
    state.sessionType = session and session.type
    state.rows, state.shownRows, state.localRow = {}, {}, nil
    state.pilots, state.sectorConnections, state.bestSeen, state.improvementUntil = {}, {}, {}, {}
    Sectors.reset(state.sectors)
    state.finalRows = nil
    state.sessionBest, state.enteredAt = nil, now
  end
  state.timeline, state.started, state.playerLap = timeline, started, playerLap
  local race = Session.isRace(session)
  local personal = Session.isPersonal(session)

  local rows = {}
  local flagKind, flagIndex = FlagCause.resolve(sim)
  local rawCars = collectCars()
  for i = 1, #rawCars do
    local row = makeRow(rawCars[i], session, settings, sim)
    if row.index ~= 0 and row.index == flagIndex then row.flagCauseKind = flagKind end
    if shouldKeep(row, session) and (not personal or row.isLocal) then rows[#rows + 1] = row end
  end
  if race then table.sort(rows, raceSort) else table.sort(rows, practiceSort) end
  for i = 1, #rows do
    rows[i].position = race and rows[i].racePosition < 999 and rows[i].racePosition > 0 and rows[i].racePosition or i
    if not race then rows[i].racePosition = i end
    observeImprovements(state, rows[i], now)
  end
  if race then observeRace(state, rows, started, now, settings) end
  local final = race and (read(sim, 'isSessionFinished') == true
    or read(session, 'isSessionFinished') == true or read(session, 'isFinished') == true or read(session, 'isOver') == true)
  if race and #rows > 0 then
    local allFinished, sawFinish = true, false
    for i = 1, #rows do
      sawFinish = sawFinish or rows[i].status == 'FIN'
      if rows[i].connected and rows[i].active and rows[i].status ~= 'FIN' and rows[i].status ~= 'RET' then allFinished = false end
    end
    final = final or started and sawFinish and allFinished
  end
  if final and not state.finalRows then state.finalRows = rows end
  if state.finalRows then rows, final = state.finalRows, true end
  if not race then
    local present = {}
    for i = 1, #rows do
      local row = rows[i]
      local previous = state.sectorConnections[row.index]
      row.reconnected = previous ~= nil and (previous.missing or previous.connected == false and row.connected)
      state.sectorConnections[row.index] = {connected = row.connected}
      present[row.index] = true
    end
    for index, connection in pairs(state.sectorConnections) do
      if not present[index] then connection.missing = true end
    end
    Sectors.update(state.sectors, rows, settings)
  end

  local sessionBest
  for i = 1, #rows do
    if validTime(rows[i].bestLapTimeMs) and (sessionBest == nil or rows[i].bestLapTimeMs < sessionBest) then sessionBest = rows[i].bestLapTimeMs end
  end
  state.sessionBest = sessionBest
  for i = 1, #rows do
    local row = rows[i]
    row.sessionBest = sessionBest ~= nil and row.bestLapTimeMs == sessionBest
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
    flagLabel = header.flagLabel, flagRole = header.flagRole, enteredAt = state.enteredAt,
    historyReset = historyReset, timeline = timeline, final = final, personal = personal
  }
  state.snapshot = snapshot
  return snapshot
end

return M
