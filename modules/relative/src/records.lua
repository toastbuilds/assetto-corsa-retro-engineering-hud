local Records = {}
Records.__index = Records

local function validTime(value)
  value = tonumber(value)
  if value and value == value and value >= 1000 and value <= 7200000 then return value end
  return nil
end

function Records.new()
  return setmetatable({ trackID = nil, carID = nil, trackName = '', sessionBest = nil, trackBest = nil }, Records)
end

function Records:resetSession()
  self.sessionBest = nil
end

function Records:setTrack(id, name, carID)
  self.trackName = name or ''
  if id == self.trackID and carID == self.carID then return false end
  self.trackID, self.carID = id, carID
  self:resetSession()
  self.trackBest, self.storage = nil, nil
  if id and id ~= '' and carID and carID ~= '' then
    -- The old track-only history includes rivals and cannot safely seed a
    -- personal record. Keep it intact and use a separate per-car namespace.
    self.storage = ac.storage({ best = 0 }, 'retro-ui.relative.personal.v2.' .. id .. '[#]' .. carID)
    self.trackBest = validTime(self.storage.best)
  end
  return true
end

function Records:update(sample)
  -- CSP's session best is already a completed-lap reference, so joining a
  -- session halfway through still shows the player's record. The previous-lap fallback
  -- requires explicit validity and never uses the new lap's validity flag.
  if sample.index ~= 0 or not self.carID or self.carID == ''
      or sample.carID ~= self.carID or sample.replay then return end
  local best = validTime(sample.bestLapTimeMs)
  local previous = validTime(sample.previousLapTimeMs)
  if sample.isLastLapValid == false and best == previous then best = nil end
  if sample.isLastLapValid == true and not sample.teleported and previous
      and (not best or previous < best) then best = previous end
  if not best then return end
  if not self.sessionBest or best < self.sessionBest then self.sessionBest = best end
  if not self.trackBest or best < self.trackBest then
    self.trackBest = best
    if self.storage then self.storage.best = best end
  end
end

function Records.timeText(value)
  value = validTime(value)
  if not value then return '-:--.---' end
  -- Format integer milliseconds to avoid a rounded 60.000 seconds field.
  local ms = math.floor(value + 0.5)
  return string.format('%d:%02d.%03d', math.floor(ms / 60000),
    math.floor(ms / 1000) % 60, ms % 1000)
end

return Records
