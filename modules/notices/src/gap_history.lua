local M = {}
M.__index = M

local LAP_WINDOW = 4
local SAMPLE_LAPS = 1 / 96
local MAX_POINTS = 512

function M.new()
  return setmetatable({points = {}, missing = false}, M)
end

function M:add(progress, gap, estimated, incident, force)
  if gap == nil then self.missing = true; return end
  local points = self.points
  local last = points[#points]
  if last and progress <= last.progress then return end
  if last and not force and not self.missing and last.incident == incident
      and progress - last.progress < SAMPLE_LAPS then return end
  points[#points + 1] = {progress = progress, gap = gap, estimated = estimated == true,
    incident = incident, breakBefore = self.missing}
  self.missing = false
  while #points > 2 and (points[2].progress <= progress - LAP_WINDOW or #points > MAX_POINTS) do
    table.remove(points, 1)
  end
end

-- A copy belongs to this pass: queued summaries must not change with live data.
function M:snapshot(progress)
  local result = {points = {}, endProgress = progress}
  local cutoff = progress - LAP_WINDOW
  for i, point in ipairs(self.points) do
    if point.progress >= cutoff and point.progress <= progress then
      local previous = self.points[i - 1]
      if #result.points == 0 and previous and previous.progress < cutoff
          and point.progress > cutoff and not point.breakBefore then
        local fraction = (cutoff - previous.progress) / (point.progress - previous.progress)
        result.points[1] = {progress = cutoff,
          gap = previous.gap + (point.gap - previous.gap) * fraction,
          estimated = previous.estimated or point.estimated, incident = previous.incident}
      end
      result.points[#result.points + 1] = {progress = point.progress, gap = point.gap,
        estimated = point.estimated, incident = point.incident, breakBefore = point.breakBefore}
    end
  end
  return result
end

return M
