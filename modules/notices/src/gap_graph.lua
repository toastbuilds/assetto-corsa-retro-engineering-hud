local Theme = require('src/theme')
local TimingUI = require('modules/timing/src/ui')
local M = {}
local MAX_GRAPH_LAPS = 4
local MIN_GRAPH_LAPS = 1 / 96

function M.draw(history, p, scale, colors, ink)
  local points = history and history.points or {}
  local endProgress = history and history.endProgress or 0
  local firstProgress = points[1] and points[1].progress or endProgress
  local availableLaps = points[1] and math.max(0, math.min(MAX_GRAPH_LAPS,
    endProgress - firstProgress)) or MAX_GRAPH_LAPS
  local graphLaps = math.max(MIN_GRAPH_LAPS, availableLaps)
  local graphStart = endProgress - graphLaps
  local low, high, estimated, observed = 0, 1, false, 0
  for i, point in ipairs(points) do
    low, high = math.min(low, point.gap), math.max(high, point.gap)
    estimated = estimated or point.estimated
    if i > 1 and not point.breakBefore then
      observed = observed + point.progress - points[i - 1].progress
    end
  end
  low, high = math.floor(low), math.ceil(high)
  if high <= low then high = low + 1 end
  local function xy(point)
    return p(60 + (point.progress - graphStart) / graphLaps * 580,
      224 - (point.gap - low) / (high - low) * 78)
  end
  ui.pushDWriteFont(Theme.fonts.utility)
  ui.dwriteDrawText((estimated and '~ ' or '') .. 'GAP TO RIVAL (s)', 13 * scale,
    p(20, 113), ink(colors.primary))
  local coverage = string.format('%.1f / 4 LAPS OBSERVED', math.min(4, observed))
  local measured = ui.measureDWriteText(coverage, 12 * scale)
  ui.dwriteDrawText(coverage, 12 * scale, p(640, 114) - vec2(measured.x, 0), ink(colors.secondary))
  local labels = {}
  local axisLabels = {low, (low + high) / 2, high}
  if low <= 0 and high >= 0 then axisLabels[#axisLabels + 1] = 0 end
  for _, gap in ipairs(axisLabels) do
    local y = 224 - (gap - low) / (high - low) * 78
    ui.drawLine(p(60, y), p(640, y), ink(colors.outlineSoft), scale)
    local fits = true
    for _, previousY in ipairs(labels) do if math.abs(y - previousY) < 13 then fits = false end end
    if fits then
      labels[#labels + 1] = y
      local label = string.format('%g', gap)
      local width = ui.measureDWriteText(label, 11 * scale).x
      ui.dwriteDrawText(label, 11 * scale, p(50, y - 6) - vec2(width, 0), ink(colors.secondary))
    end
  end
  local previousLapLabel
  for i = 0, 4 do
    local x = 60 + i * 145
    ui.drawLine(p(x, 146), p(x, 224), ink(colors.outlineSoft, 0.35), scale)
    local label
    if i == 4 then
      label = 'PASS'
    else
      local lapsBeforePass = graphLaps * (4 - i) / 4
      local rounded = math.floor(lapsBeforePass * 100 + 0.5) / 100
      if rounded > 0 and rounded ~= previousLapLabel then
        label = string.format('-%gL', rounded)
        previousLapLabel = rounded
      end
    end
    if label then
      TimingUI.centeredText(label, 11 * scale, p(x, 243), ink(colors.secondary))
    end
  end
  if #points == 0 then
    TimingUI.centeredText('NO GAP HISTORY', 14 * scale, p(350, 185), ink(colors.secondary))
  else
    for i, point in ipairs(points) do
      local previous = points[i - 1]
      local color = (point.incident or previous and previous.incident)
        and colors.flagYellow or colors.green
      if previous and not point.breakBefore then
        ui.drawLine(xy(previous), xy(point), ink(color), 2 * scale)
      end
      if i == #points or point.incident and (not previous or previous.incident ~= point.incident) then
        ui.drawCircleFilled(xy(point), 3 * scale, ink(color), 12)
      end
    end
  end
  ui.popDWriteFont()
end

return M
