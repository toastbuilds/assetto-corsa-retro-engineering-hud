local Sectors = {}
Sectors.__index = Sectors

local function finite(value)
  value = tonumber(value)
  return value and value == value and value ~= math.huge and value ~= -math.huge and value or nil
end

local function sectorIndex(value)
  value = finite(value)
  if value and value == math.floor(value) and value >= 0 and value <= 2 then return value end
  return nil
end

local function sectorTime(value)
  value = finite(value)
  if value and value >= 1000 and value <= 600000 then return value end
  return nil
end

function Sectors.new()
  return setmetatable({ cars = {}, best = {}, playerLast = {} }, Sectors)
end

function Sectors:reset()
  self.cars, self.best, self.playerLast = {}, {}, {}
end

function Sectors:update(index, classID, sample, now)
  local sector = sectorIndex(sample.currentSector)
  local lap = finite(sample.lapCount)
  local lapTime = finite(sample.lapTimeMs)
  local inPit = sample.inPit == true
  local invalid = sample.isLapValid == false
  local state = self.cars[index]
  local restarted = not state or state.sector == nil or state.lap == nil
    or state.carID ~= sample.carID or state.classID ~= classID
    or sample.teleported or sector == nil or lap == nil or lap < 0
    or (state and (lap < state.lap or lap > state.lap + 1
      or (lap ~= state.lap and sector == state.sector)))

  if restarted then
    state = {
      carID = sample.carID, classID = classID, sector = sector, lap = lap,
      startLapTime = sector == 0 and 0 or nil,
      lapInvalid = inPit or invalid,
      completed = {}, lastSeen = now
    }
    self.cars[index] = state
    return
  end

  if state.sector ~= sector then
    local expected = (state.sector + 1) % 3
    local expectedLap = state.lap + (state.sector == 2 and 1 or 0)
    if sector == expected and lap == expectedLap and not state.lapInvalid
        and not inPit and not invalid then
      local completed = sectorTime(sample.previousSectorTime)
      if state.sector == 2 then
        local previousLap = finite(sample.previousLapTimeMs)
        if previousLap and state.completed[1] and state.completed[2] then
          completed = sectorTime(previousLap - state.completed[1] - state.completed[2]) or completed
        end
      end
      if completed then
        local number = state.sector + 1
        state.completed[number] = completed
        if index == 0 then self.playerLast[number] = completed end
        if classID and classID ~= 'UNKNOWN' then
          local best = self.best[classID] or {}
          if not best[number] or completed < best[number] then best[number] = completed end
          self.best[classID] = best
        end
      end
    end
    state.startLapTime = sector == 0 and 0 or lapTime
    if sector == 0 then
      state.completed = {}
      state.lapInvalid = inPit or invalid
    else
      state.lapInvalid = state.lapInvalid or inPit or invalid
    end
  else
    state.lapInvalid = state.lapInvalid or inPit or invalid
  end

  state.sector, state.lap, state.lastSeen = sector, lap, now
  state.lapTime = lapTime
end

function Sectors:prune(now)
  for index, state in pairs(self.cars) do
    if now - state.lastSeen > 5 then self.cars[index] = nil end
  end
end

function Sectors:snapshot(playerClass)
  local state = self.cars[0]
  local best = playerClass and playerClass ~= 'UNKNOWN' and self.best[playerClass] or nil
  local elapsed = state and state.lapTime and state.startLapTime
    and not state.lapInvalid and state.lapTime - state.startLapTime or nil
  if elapsed and (elapsed < 0 or elapsed > 600000) then elapsed = nil end
  return {
    current = state and state.sector and state.sector + 1 or nil,
    elapsed = elapsed,
    last = self.playerLast,
    best = best or {}
  }
end

function Sectors.timeText(value)
  if not value then return '--.---' end
  local seconds = value / 1000
  if seconds >= 60 then
    return string.format('%d:%06.3f', math.floor(seconds / 60), seconds % 60)
  end
  return string.format('%.3f', seconds)
end

function Sectors.deltaText(last, best)
  if not last or not best then return '--' end
  return string.format('%+.3f', (last - best) / 1000)
end

return Sectors
