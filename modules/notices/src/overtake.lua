local Session = require('modules/leaderboard/src/session')
local FlagCause = require('src/flag_cause')
local M = {}
M.__index = M

local SAMPLE_INTERVAL = 0.5
local MAX_SAMPLE_GAP = 2
local MAX_HISTORY_LAPS = 3
local MAX_HISTORY_POINTS = 720
local INCIDENT_MEMORY_SECONDS = 20
local EPSILON = 0.000001

local function finite(value)
  value = tonumber(value)
  return value and value == value and math.abs(value) < math.huge and value or nil
end

local function read(object, key)
  if object == nil then return nil end
  local ok, value = pcall(function() return object[key] end)
  return ok and value or nil
end

local function identity(row)
  return table.concat({tostring(row.index), tostring(row.driver or ''), tostring(row.carID or '')}, '/')
end

local function position(row)
  local value = finite(row and row.racePosition)
  if not value or value < 1 or value >= 999 then return nil end
  return math.floor(value + 0.5)
end

local function active(row)
  if not row or row.justJumped == true or row.active == false
      or row.status == 'PIT' or row.status == 'RET'
      or row.status == 'FIN' then return false end
  if row.isAI then return true end
  return row.connected ~= false and row.status ~= 'OFF'
end

local function sampleAt(points, progress)
  for i = 2, #points do
    local a, b = points[i - 1], points[i]
    if a.progress <= progress and progress <= b.progress and b.progress > a.progress then
      local fraction = (progress - a.progress) / (b.progress - a.progress)
      return a.gap + (b.gap - a.gap) * fraction, a.estimated or b.estimated
    end
  end
end

local function closingRate(history)
  local points = history and history.points
  if not points or #points < 2 then return nil, false end
  local latest = points[#points]
  local laps = math.min(MAX_HISTORY_LAPS,
    math.floor(latest.progress - points[1].progress + EPSILON))
  if laps < 1 then return nil, false end
  local oldGap, estimated = sampleAt(points, latest.progress - laps)
  if oldGap == nil then return nil, false end
  return (oldGap - latest.gap) / laps, estimated or latest.estimated
end

local function clearHistory(self)
  self.previousRows, self.histories, self.incidents = {}, {}, {}
  self.sessionIndex, self.lastProgress, self.lastTime = nil, nil, nil
end

function M.new()
  return setmetatable({previousRows = {}, histories = {}, incidents = {}}, M)
end

function M:reset()
  clearHistory(self)
end

function M:update(snapshot, enabled)
  if enabled == false or not snapshot or not Session.isRace(snapshot.session)
      or snapshot.final == true or snapshot.sim == nil
      or read(snapshot.sim, 'isSessionStarted') ~= true
      or read(snapshot.sim, 'isSessionFinished') == true
      or read(snapshot.sim, 'isReplayActive') == true then
    self:reset()
    return {}
  end

  local player = snapshot.localRow
  local now = finite(snapshot.timeline and snapshot.timeline.time)
  local progress = finite(player and player.progress)
  local sessionIndex = finite(read(snapshot.sim, 'currentSessionIndex')) or 0
  if not active(player) or not now or not progress then
    self:reset()
    return {}
  end

  local playerPosition = position(player)
  local discontinuous = snapshot.historyReset == true
    or self.sessionIndex ~= nil and self.sessionIndex ~= sessionIndex
    or self.lastTime ~= nil and (now < self.lastTime or now - self.lastTime > MAX_SAMPLE_GAP)
    or self.lastProgress ~= nil and (progress < self.lastProgress - EPSILON
      or progress - self.lastProgress > 0.25)
  if discontinuous then clearHistory(self) end

  local rowsByIndex, events, candidates = {}, {}, {}
  for i = 1, #(snapshot.rows or {}) do
    local row = snapshot.rows[i]
    if finite(row.index) then rowsByIndex[row.index] = row end
  end

  -- Keep recent, rival-specific context until AC reports the position swap.
  -- A track exit describes what was observed; it does not confirm a crash.
  local flagKind, flagIndex = FlagCause.resolve(snapshot.sim)
  local incidents = {}
  for index, row in pairs(rowsByIndex) do
    if index ~= player.index and active(row) then
      local rowIdentity = identity(row)
      local recent = self.incidents[index]
      if recent and (recent.identity ~= rowIdentity
          or now - recent.time >= INCIDENT_MEMORY_SECONDS) then recent = nil end
      if read(snapshot.sim, 'isPaused') ~= true then
        if flagKind == 'yellow' and flagIndex == index then
          recent = {identity = rowIdentity, kind = 'yellow', time = now}
        elseif finite(read(row.car, 'wheelsOutside')) == 4
            and (not recent or recent.kind ~= 'yellow') then
          recent = {identity = rowIdentity, kind = 'offtrack', time = now}
        end
      end
      incidents[index] = recent
      if recent then self.histories[index] = nil end
    end
  end
  self.incidents = incidents

  local previousPlayer = self.previousRows[player.index]
  local previousPlayerPosition = previousPlayer and previousPlayer.position
  local canDetect = not discontinuous and read(snapshot.sim, 'isPaused') ~= true
    and playerPosition and previousPlayer and previousPlayer.identity == identity(player)
    and previousPlayer.live and active(player) and previousPlayerPosition
    and playerPosition < previousPlayerPosition

  if canDetect then
    for index, row in pairs(rowsByIndex) do
      if index ~= player.index then
        local previous = self.previousRows[index]
        local rowPosition = position(row)
        if previous and previous.identity == identity(row) and previous.live and active(row)
            and previous.position and rowPosition
            and previous.position < previousPlayerPosition and rowPosition > playerPosition then
          candidates[#candidates + 1] = {row = row, oldPosition = previous.position,
            index = index}
        end
      end
    end
    -- If several positions update in one frame, narrate the passes in order.
    table.sort(candidates, function(a, b) return a.oldPosition > b.oldPosition end)
    for i = 1, #candidates do
      local candidate = candidates[i]
      local rate, estimated = closingRate(self.histories[candidate.index])
      local incident = self.incidents[candidate.index]
      local passed = candidate.row
      events[#events + 1] = {
        kind = 'overtake', index = candidate.index, identity = identity(passed),
        driver = tostring(passed.driver or ''), carName = tostring(passed.carName or ''),
        classID = tostring(passed.classID or ''),
        fromPosition = candidate.oldPosition + 1, toPosition = candidate.oldPosition,
        closingRate = rate, estimated = estimated,
        incident = incident and incident.kind or nil
      }
      self.histories[candidate.index] = nil
    end
  end

  local currentPrevious = {}
  for index, row in pairs(rowsByIndex) do
    local rowIdentity = identity(row)
    local rowPosition = position(row)
    local old = self.previousRows[index]
    if old and old.identity ~= rowIdentity then self.histories[index] = nil end
    currentPrevious[index] = {identity = rowIdentity, position = rowPosition, live = active(row)}

    local gap = finite(row.intervalSeconds)
    local history = self.histories[index]
    local isAhead = index ~= player.index and active(row) and rowPosition and playerPosition
      and rowPosition < playerPosition and gap and gap > 0 and not self.incidents[index]
      and snapshot.timeline.measuredClock ~= false
    if isAhead then
      if not history then history = {identity = rowIdentity, points = {}}; self.histories[index] = history end
      if history.identity ~= rowIdentity then
        history = {identity = rowIdentity, points = {}}
        self.histories[index] = history
      end
      local points = history.points
      local last = points[#points]
      if not last or now - last.time >= SAMPLE_INTERVAL then
        if not last or progress > last.progress + EPSILON then
          points[#points + 1] = {progress = progress, gap = gap,
            time = now, estimated = row.intervalSource == 'estimated'}
          while #points > 2 and (points[2].progress < progress - MAX_HISTORY_LAPS
              or #points > MAX_HISTORY_POINTS) do
            table.remove(points, 1)
          end
        end
      end
    elseif index ~= player.index then
      -- Events consume the last approach sample above; everyone else loses
      -- their stale history once they are no longer a live car ahead.
      self.histories[index] = nil
    end
  end

  for index in pairs(self.histories) do
    if not rowsByIndex[index] then self.histories[index] = nil end
  end

  self.previousRows = currentPrevious
  self.sessionIndex, self.lastProgress, self.lastTime = sessionIndex, progress, now
  return events
end

return M
