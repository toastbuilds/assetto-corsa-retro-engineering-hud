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

local function positive(value)
  value = number(value)
  return value and value > 0 and value or nil
end

local function seconds(value, key)
  value = positive(value)
  if not value then return nil end
  -- CSP has used both seconds and milliseconds for time-left style fields.
  if key and key:lower():find('ms', 1, true) then return value / 1000 end
  if value > 100000 then return value / 1000 end
  -- A millisecond value exposed under a generic `timeLeft` name is common in
  -- older CSP builds; normal session countdowns are not hours long.
  if value > 7200 then return value / 1000 end
  return value
end

function M.safeCurrent()
  local ok, sim = pcall(ac.getSim)
  if not ok or sim == nil then return nil, nil end
  local index = number(read(sim, 'currentSessionIndex')) or 0
  local sessionOk, session = pcall(function() return ac.getSession(index) end)
  return sim, sessionOk and session or nil
end

function M.isRace(session)
  return session ~= nil and ac.SessionType ~= nil and session.type == ac.SessionType.Race
end

function M.isTimed(session)
  return session ~= nil and M.isRace(session) and read(session, 'isTimedRace') == true
end

function M.typeLabel(session)
  if session == nil then return 'WAIT' end
  if ac.SessionType ~= nil then
    if session.type == ac.SessionType.Race then return 'RACE' end
    if session.type == ac.SessionType.Qualify then return 'QUAL' end
    if session.type == ac.SessionType.Practice then return 'PRAC' end
    if ac.SessionType.Hotlap ~= nil and session.type == ac.SessionType.Hotlap then return 'HOTLAP' end
    if ac.SessionType.TimeAttack ~= nil and session.type == ac.SessionType.TimeAttack then return 'TA' end
  end
  return 'SESSION'
end

function M.timeLeftSeconds(sim, session)
  local candidates = {
    { read(session, 'timeLeft'), 'timeLeft' },
    { read(session, 'timeLeftMs'), 'timeLeftMs' },
    { read(sim, 'timeLeft'), 'timeLeft' },
    { read(sim, 'sessionTimeLeft'), 'sessionTimeLeft' },
    { read(sim, 'sessionTimeLeftMs'), 'sessionTimeLeftMs' }
  }
  for i = 1, #candidates do
    local value = seconds(candidates[i][1], candidates[i][2])
    if value then return value end
  end
  return nil
end

function M.formatDuration(value)
  value = math.max(0, math.floor((number(value) or 0) + 0.5))
  local hours = math.floor(value / 3600)
  local minutes = math.floor((value % 3600) / 60)
  local secs = value % 60
  if hours > 0 then return string.format('%d:%02d:%02d', hours, minutes, secs) end
  return string.format('%02d:%02d', minutes, secs)
end

function M.currentLap(row)
  local lap = row and number(row.lapCount)
  if not lap then return '--' end
  return tostring(math.max(1, math.floor(lap + 1)))
end

function M.sessionBestReferenceSeconds(sessionBest)
  local best = positive(sessionBest)
  if best then return best / 1000 end
  return nil
end

function M.lapHeader(session, sim, leaderRow, sessionBest, showEstimate)
  local laps = positive(read(session, 'laps'))
  if not M.isTimed(session) and laps then return 'LAPS: ' .. tostring(math.floor(laps + 0.5)) end
  if not M.isTimed(session) then return 'LAPS: --' end
  if showEstimate == false then return 'LAPS: --' end

  local remaining = M.timeLeftSeconds(sim, session)
  -- A total-lap projection becomes trustworthy as soon as any driver has set
  -- a valid fastest lap. Do not wait for the current leader to complete one.
  local reference = M.sessionBestReferenceSeconds(sessionBest)
  local leaderLap = leaderRow and number(leaderRow.lapCount)
  if not remaining or not reference or not leaderLap or reference < 5 or reference > 600 then
    return 'LAPS: --'
  end

  local projected = math.max(0, math.floor(leaderLap + math.ceil(remaining / reference)))
  if read(session, 'hasAdditionalLap') == true then projected = projected + 1 end
  if projected <= 0 then return 'LAPS: --' end
  return 'LAPS: ~' .. tostring(projected)
end

function M.lapsRemaining(session, sim, localRow, leaderRow, sessionBest)
  if not M.isRace(session) or localRow == nil then return nil end
  local laps = positive(read(session, 'laps'))
  if laps and not M.isTimed(session) then
    return math.max(0, math.floor(laps - (number(localRow.lapCount) or 0)))
  end
  local remaining = M.timeLeftSeconds(sim, session)
  local reference = M.sessionBestReferenceSeconds(sessionBest)
  if not remaining or not reference or reference < 5 or reference > 600 then return nil end
  local localLap = number(localRow.lapCount)
  if not localLap then return nil end
  local extra = read(session, 'hasAdditionalLap') == true and 1 or 0
  return math.max(0, math.ceil(remaining / reference) + extra)
end

local function enumEquals(value, enum, key)
  return enum ~= nil and key ~= nil and enum[key] ~= nil and value == enum[key]
end

local function flagMatches(flag, flags, keys, replayValue)
  for i = 1, #keys do
    if enumEquals(flag, flags, keys[i]) then return true end
  end
  -- Replay telemetry can expose the raw CSP value without a usable enum.
  return replayValue ~= nil and number(flag) == replayValue
end

function M.flag(sim, session)
  local flag = read(sim, 'raceFlagType')
  local flags = ac.FlagType
  if flagMatches(flag, flags, { 'Green' }, 1) then return 'GREEN', 'green' end
  -- CSP calls the yellow/caution flag "Caution". In replays it is commonly
  -- delivered as raw value 2, which is also what the companion HUD uses.
  if flagMatches(flag, flags, { 'Caution', 'Yellow' }, 2) then return 'YELLOW', 'yellow' end
  if enumEquals(flag, flags, 'Black') then return 'BLACK', 'red' end
  if flagMatches(flag, flags, { 'Stop' }, 5) then return 'STOP', 'red' end
  if flagMatches(flag, flags, { 'ReturnToPits' }, 8) then return 'PIT', 'red' end
  if flagMatches(flag, flags, { 'FasterCar', 'Blue' }, 12) then return 'BLUE', 'blue' end
  if enumEquals(flag, flags, 'Penalty') then return 'PENALTY', 'red' end
  if flagMatches(flag, flags, { 'Finished' }, 13) then return 'FINISH', 'white' end
  if flagMatches(flag, flags, { 'OneLapLeft' }, 14) then return 'LAST LAP', 'white' end
  if enumEquals(flag, flags, 'White') then return 'WHITE', 'white' end

  if read(session, 'isSessionFinished') == true or read(session, 'isFinished') == true
      or read(sim, 'isSessionFinished') == true then
    local label = M.typeLabel(session)
    if label == 'PRAC' then label = 'PRACTICE' end
    if label == 'QUAL' then label = 'QUALIFY' end
    return label .. ' OVER', 'white'
  end
  return nil, nil
end

function M.temperature(sim, key, unit)
  local value = number(read(sim, key))
  if not value then return '--' end
  if unit == 'F' then return string.format('%.0f° F', value * 9 / 5 + 32) end
  return string.format('%.0f° C', value)
end

function M.snapshotHeader(sim, session, localRow, leaderRow, sessionBest, settings)
  local flag, flagRole = M.flag(sim, session)
  local timeLeft = M.timeLeftSeconds(sim, session)
  return {
    typeLabel = M.typeLabel(session),
    timeText = timeLeft and M.formatDuration(timeLeft) or '--:--',
    currentLapText = M.currentLap(localRow),
    lapsText = M.lapHeader(session, sim, leaderRow, sessionBest, settings.showLapEstimate),
    ambientText = M.temperature(sim, 'ambientTemperature', settings.temperatureUnit),
    trackText = M.temperature(sim, 'trackTemperature', settings.temperatureUnit),
    flagLabel = flag,
    flagRole = flagRole,
    isTimed = M.isTimed(session)
  }
end

return M
