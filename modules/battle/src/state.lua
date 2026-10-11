local Session = require('modules/leaderboard/src/session')
local M = {}
M.__index = M

function M.new() return setmetatable({ histories = {}, snapshot = nil }, M) end
function M:reset() self.histories, self.lastProgress, self.lastTime = {}, nil, nil end

local function finite(v)
  return type(v) == 'number' and v == v and math.abs(v) < math.huge
end

local function sampleAt(history, progress)
  for i = 2, #history do
    local a, b = history[i - 1], history[i]
    if a.progress <= progress and b.progress >= progress and b.progress > a.progress then
      return a.gap + (b.gap - a.gap) * (progress - a.progress) / (b.progress - a.progress)
    end
  end
end

function M:rival(row, position, side, progress, now, final)
  if not row then self.histories[side] = nil; return nil end
  local identity = tostring(row.index) .. '/' .. row.driver .. '/' .. row.carID
  local estimated = row.intervalSource == 'estimated'
  local available = row.active ~= false and row.connected ~= false
    and row.status ~= 'PIT' and row.status ~= 'RET' and row.status ~= 'OFF'
  local gap = available and finite(row.intervalSeconds) and math.abs(row.intervalSeconds) or nil
  local h = self.histories[side]
  if not h or h.identity ~= identity or h.estimated ~= estimated or not gap then
    h = { identity = identity, estimated = estimated, points = {} }
    self.histories[side] = h
  end
  local points = h.points
  if gap and not final and (not h.time or now - h.time >= 0.5) then
    local last = points[#points]
    if not last or progress > last.progress + 0.00001 then
      points[#points + 1] = { progress = progress, gap = gap }
    end
    h.time = now
    while #points > 2 and (points[2].progress < progress - 3 or #points > 720) do table.remove(points, 1) end
  end
  local laps = #points > 1 and math.min(3, math.floor(progress - points[1].progress + 0.000001)) or 0
  local old = laps > 0 and sampleAt(points, progress - laps) or nil
  local rate = gap and old and (gap - old) / laps or nil
  local favorable = rate and (side == 'ahead' and rate < 0 or side == 'behind' and rate > 0)
  local trend = 'COLLECTING LAP DATA'
  local role = 'secondary'
  if rate then
    role = math.abs(rate) < 0.05 and 'secondary' or favorable and 'green' or 'red'
    trend = math.abs(rate) < 0.05 and 'GAP STABLE' or string.format('%s %s %s%.1f s/LAP',
      favorable and 'YOU' or row.driver:upper(), favorable and 'GAIN' or 'GAINS', estimated and '~' or '', math.abs(rate))
  end
  local value = gap and string.format('%s%.1f s', estimated and '~' or '', gap)
    or (not available and row.status) or row.interval or '--'
  return { driver = row.driver:upper(), position = position, value = value, trend = trend,
    role = role, points = points, laps = laps, status = row.status }
end

function M:update(source)
  local player = source and source.localRow
  if not player or not Session.isRace(source.session) then
    self:reset(); self.snapshot = { message = 'AVAILABLE IN RACE SESSIONS' }; return
  end
  local progress = player.progress
  local now = source.timeline and source.timeline.time or ui.time()
  if not finite(progress) or not finite(now) then self:reset(); self.snapshot = { message = 'WAITING FOR RACE DATA' }; return end
  if source.historyReset or self.lastTime and (now < self.lastTime or now - self.lastTime > 2)
      or self.lastProgress and (progress < self.lastProgress or progress - self.lastProgress > 0.25) then self:reset() end
  self.lastProgress, self.lastTime = progress, now
  local rows, own = {}, nil
  for _, row in ipairs(source.rows or {}) do
    if row.classID == player.classID then
      rows[#rows + 1] = row
      if row.index == player.index then own = #rows end
    end
  end
  if not own then self.snapshot = { message = 'WAITING FOR CLASS DATA' }; return end
  if player.status == 'PIT' or player.status == 'OFF' or player.status == 'RET' then self.histories = {} end
  local stopped = source.final or player.status == 'PIT' or player.status == 'OFF' or player.status == 'RET'
  self.snapshot = { classID = player.classID or 'OPEN', position = own, final = source.final,
    ahead = self:rival(rows[own - 1], own - 1, 'ahead', progress, now, stopped),
    behind = self:rival(rows[own + 1], own + 1, 'behind', progress, now, stopped) }
end

function M.preview()
  return { classID = 'GT3', position = 5,
    ahead = { driver = 'MARTIN', position = 4, value = '1.4 s', trend = 'YOU GAIN 0.3 s/LAP', role = 'green', laps = 3,
      points = {{progress=0,gap=2.3},{progress=0.5,gap=2.1},{progress=1,gap=2},{progress=1.5,gap=1.8},{progress=2,gap=1.9},{progress=2.5,gap=1.6},{progress=3,gap=1.4}} },
    behind = { driver = 'COSTA', position = 6, value = '0.8 s', trend = 'COSTA GAINS 0.2 s/LAP', role = 'red', laps = 3,
      points = {{progress=0,gap=1.4},{progress=0.5,gap=1.3},{progress=1,gap=1.1},{progress=1.5,gap=1.2},{progress=2,gap=1},{progress=2.5,gap=0.9},{progress=3,gap=0.8}} } }
end
return M
