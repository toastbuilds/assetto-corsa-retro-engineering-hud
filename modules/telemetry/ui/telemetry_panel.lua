local Theme = require('modules/telemetry/src/theme')
local U = require('modules/telemetry/src/utils')
local History = require('modules/telemetry/src/history')

local M = {}

local TRACE_DEFS = {
  { key = 'throttle', label = 'THR', setting = 'showThrottleTrace', role = 'green' },
  { key = 'brake', label = 'BRK', setting = 'showBrakeTrace', role = 'red' },
  { key = 'clutch', label = 'CLT', setting = 'showClutchTrace', role = 'cyan' },
  { key = 'ffb', label = 'FFB', setting = 'showFfbTrace', role = 'primary' },
  { key = 'handbrake', label = 'HBR', setting = 'showHandbrake', role = 'amber' }
}

local BAR_DEFS = {
  { key = 'clutchPressed', role = 'cyan' },
  { key = 'brake', role = 'red' },
  { key = 'throttle', role = 'green' },
  { key = 'handbrake', role = 'amber' }
}

local function color(palette, role, alpha)
  return Theme.withAlpha(palette[role], alpha or 1)
end

local function text(value, size, position, paletteColor)
  ui.dwriteDrawText(value, size, position, paletteColor)
end

local function drawArc(center, radius, startAngle, endAngle, paletteColor, width, segments)
  ui.pathClear()
  ui.pathArcTo(center, radius, startAngle, endAngle, segments or 32)
  ui.pathStroke(paletteColor, false, width)
end

local function drawChamferedRect(left, top, right, bottom, chamfer, fill, stroke, strokeWidth)
  ui.pathClear()
  ui.pathLineTo(vec2(left + chamfer, top))
  ui.pathLineTo(vec2(right - chamfer, top))
  ui.pathLineTo(vec2(right, top + chamfer))
  ui.pathLineTo(vec2(right, bottom - chamfer))
  ui.pathLineTo(vec2(right - chamfer, bottom))
  ui.pathLineTo(vec2(left + chamfer, bottom))
  ui.pathLineTo(vec2(left, bottom - chamfer))
  ui.pathLineTo(vec2(left, top + chamfer))
  ui.pathFillConvex(fill)

  ui.pathClear()
  ui.pathLineTo(vec2(left + chamfer, top))
  ui.pathLineTo(vec2(right - chamfer, top))
  ui.pathLineTo(vec2(right, top + chamfer))
  ui.pathLineTo(vec2(right, bottom - chamfer))
  ui.pathLineTo(vec2(right - chamfer, bottom))
  ui.pathLineTo(vec2(left + chamfer, bottom))
  ui.pathLineTo(vec2(left, bottom - chamfer))
  ui.pathLineTo(vec2(left, top + chamfer))
  ui.pathStroke(stroke, true, strokeWidth)
end

local function drawScrew(x, y, palette, scale)
  ui.drawCircleFilled(vec2(x, y), 3.5 * scale, color(palette, 'panelRaised', 0.96), 16)
  ui.drawCircle(vec2(x, y), 3.5 * scale, color(palette, 'outlineSoft', 0.92), 16, 0.8 * scale)
  ui.drawLine(vec2(x - 1.5 * scale, y - 1.5 * scale),
    vec2(x + 1.5 * scale, y + 1.5 * scale), color(palette, 'outline', 0.92), 0.9 * scale)
end

local function drawPanelFrame(x, y, width, height, palette, scale, surfaceOpacity)
  local opacity = U.clamp(surfaceOpacity or 1, 0, 1)
  drawChamferedRect(x, y, x + width, y + height, 5 * scale,
    color(palette, 'panel', 0.92 * opacity), color(palette, 'metal', 0.82), 1.1 * scale)
  drawChamferedRect(x + 4 * scale, y + 4 * scale, x + width - 4 * scale,
    y + height - 4 * scale, 3 * scale, color(palette, 'void', 0.24 * opacity),
    color(palette, 'outlineDim', 0.78), 0.8 * scale)
  drawScrew(x + 9 * scale, y + 9 * scale, palette, scale)
  drawScrew(x + width - 9 * scale, y + 9 * scale, palette, scale)
  drawScrew(x + 9 * scale, y + height - 9 * scale, palette, scale)
  drawScrew(x + width - 9 * scale, y + height - 9 * scale, palette, scale)
end

local function drawDial(x, y, width, height, state, palette, scale)
  local center = vec2(x + width * 0.48, y + height * 0.56)
  local radius = math.min(width * 0.42, height * 0.43)
  local startAngle = math.rad(135)
  local endAngle = math.rad(405)
  local normalized = U.clamp(state.ffbNeedle or state.ffbMagnitude, 0, 1)
  local markerAngle = startAngle + (endAngle - startAngle) * normalized
  local needleColor = state.ffbClipping and color(palette, 'red', 1)
    or color(palette, 'primary', 1)

  ui.drawCircleFilled(center, radius + 6 * scale, color(palette, 'panelRaised', 0.82), 64)
  ui.drawCircle(center, radius + 6 * scale, color(palette, 'outlineSoft', 0.9), 64, 1.1 * scale)
  ui.drawCircle(center, radius, color(palette, 'outline', 0.90), 64, 1.1 * scale)
  drawArc(center, radius - 5 * scale, startAngle, endAngle, color(palette, 'outlineDim', 0.9), 1.2 * scale, 64)
  drawArc(center, radius - 5 * scale, startAngle, markerAngle, needleColor, 3 * scale, 32)

  for tick = 0, 24 do
    local fraction = tick / 24
    local angle = startAngle + (endAngle - startAngle) * fraction
    local inner = center + vec2(math.cos(angle) * (radius - 10 * scale),
      math.sin(angle) * (radius - 10 * scale))
    local outer = center + vec2(math.cos(angle) * (radius - 4 * scale),
      math.sin(angle) * (radius - 4 * scale))
    ui.drawLine(inner, outer, color(palette, tick % 6 == 0 and 'amber' or 'secondary',
      tick % 6 == 0 and 0.92 or 0.55), tick % 6 == 0 and 1.2 * scale or 0.7 * scale)
  end

  local pointer = center + vec2(math.cos(markerAngle) * (radius - 12 * scale),
    math.sin(markerAngle) * (radius - 12 * scale))
  ui.drawLine(center, pointer, Theme.withAlpha(needleColor, 0.18), 5.5 * scale)
  ui.drawLine(center, pointer, needleColor, 2.2 * scale)
  ui.drawCircleFilled(center, 4 * scale, needleColor, 20)
  ui.drawCircle(center, 7 * scale, color(palette, 'outline', 0.95), 20, 1.1 * scale)
  ui.drawCircleFilled(pointer, 2.6 * scale, needleColor, 16)

end

local function drawNormalBar(x, top, width, height, value, paletteColor, palette, scale)
  local segments = 10
  local gap = 1.2 * scale
  local segmentHeight = (height - gap * (segments - 1)) / segments
  local clamped = U.clamp(value, 0, 1)
  local filled = math.floor(clamped * segments + 0.5)

  drawChamferedRect(x, top, x + width, top + height, 2 * scale,
    color(palette, 'void', 0.82), color(palette, 'outlineSoft', 0.85), 0.9 * scale)
  for index = 1, segments do
    local segmentTop = top + height - index * segmentHeight - (index - 1) * gap
    local active = index <= filled
    ui.drawRectFilled(vec2(x + 2 * scale, segmentTop),
      vec2(x + width - 2 * scale, segmentTop + segmentHeight),
      active and paletteColor or color(palette, 'inactive', 0.75))
  end
end

local function drawCluster(x, y, width, height, state, settings, palette, scale, surfaceOpacity)
  drawPanelFrame(x, y, width, height, palette, scale, surfaceOpacity)
  if state.ffbClipping then
    text('CLIP', 7 * scale, vec2(x + width - 27 * scale, y + 7 * scale), color(palette, 'red', 1))
  end

  local dialWidth = 132 * scale
  drawDial(x + 3 * scale, y + 7 * scale, dialWidth, height - 10 * scale, state, palette, scale)

  local barsLeft = x + 132 * scale
  local barGap = 4 * scale
  local barWidth = 17 * scale
  local top = y + 24 * scale
  local barHeight = height - 38 * scale

  local barIndex = 0
  for index = 1, #BAR_DEFS do
    local definition = BAR_DEFS[index]
    if definition.key ~= 'handbrake' or settings.showHandbrake then
      barIndex = barIndex + 1
      local barX = barsLeft + (barIndex - 1) * (barWidth + barGap)
      local value = state[definition.key]
      local barColor = color(palette, definition.role, 1)
      drawNormalBar(barX, top, barWidth, barHeight, value, barColor, palette, scale)
      local active = U.clamp(value, 0, 1) >= 0.98
      ui.drawCircleFilled(vec2(barX + barWidth * 0.5, y + 15 * scale), 2.5 * scale,
        active and barColor or color(palette, 'inactive', 0.9), 16)
      ui.drawCircle(vec2(barX + barWidth * 0.5, y + 15 * scale), 3.4 * scale,
        color(palette, 'outlineSoft', 0.9), 16, 0.7 * scale)
    end
  end
end

local function traceEnabled(trace, settings)
  return settings[trace.setting] == true
end

local function drawGrid(left, top, right, bottom, palette, settings, scale)
  if not settings.showTicksGrid then return end
  local width = right - left
  local height = bottom - top
  for tick = 0, 5 do
    local x = left + width * tick / 5
    ui.drawLine(vec2(x, top), vec2(x, bottom), color(palette, 'outlineDim', 0.65), 0.6 * scale)
  end
  for tick = 0, 4 do
    local y = top + height * tick / 4
    ui.drawLine(vec2(left, y), vec2(right, y), color(palette, 'outlineDim', 0.6), 0.6 * scale)
  end
  ui.drawLine(vec2(left, bottom), vec2(right, bottom), color(palette, 'amber', 0.72), 1.0 * scale)
end

local function drawTrace(history, trace, left, top, width, height, palette, scale)
  if history.count == 0 then return end
  local bottom = top + height
  local firstOffset = History.CAPACITY - history.count
  ui.pathClear()
  for ordinal = 0, history.count - 1 do
    local sample = History.sampleAt(history, ordinal)
    local normalized = U.clamp(sample[trace.key], 0, 1)
    local x = left + (firstOffset + ordinal) / (History.CAPACITY - 1) * width
    local y = bottom - normalized * height
    ui.pathLineTo(vec2(x, y))
  end
  ui.pathStroke(color(palette, trace.role, trace.key == 'ffb' and 1 or 0.95),
    false, trace.key == 'ffb' and 2.0 * scale or 1.5 * scale)
end

local function drawLegend(x, y, graphWidth, settings, palette, scale)
  if not settings.showLegend then return end
  local cursorX = x
  for index = 1, #TRACE_DEFS do
    local trace = TRACE_DEFS[index]
    if traceEnabled(trace, settings) then
      local traceColor = color(palette, trace.role, 1)
      ui.drawLine(vec2(cursorX, y + 5 * scale), vec2(cursorX + 13 * scale, y + 5 * scale), traceColor, 1.8 * scale)
      text(trace.label, 7 * scale, vec2(cursorX + 16 * scale, y), traceColor)
      cursorX = cursorX + 47 * scale
      if cursorX > x + graphWidth - 35 * scale then break end
    end
  end
end

local function drawGraph(x, y, width, height, history, state, settings, palette, scale, surfaceOpacity)
  drawPanelFrame(x, y, width, height, palette, scale, surfaceOpacity)
  if state.ffbClipping then
    text('CLIP', 7 * scale, vec2(x + width - 27 * scale, y + 7 * scale), color(palette, 'red', 1))
  end
  drawLegend(x + 10 * scale, y + 4 * scale, width - 20 * scale, settings, palette, scale)

  local left = x + 13 * scale
  local right = x + width - 11 * scale
  local top = settings.showLegend and y + 22 * scale or y + 9 * scale
  local bottom = y + height - 9 * scale
  drawGrid(left, top, right, bottom, palette, settings, scale)

  for index = 1, #TRACE_DEFS do
    local trace = TRACE_DEFS[index]
    if traceEnabled(trace, settings) then
      drawTrace(history, trace, left, top, right - left, bottom - top, palette, scale)
    end
  end

  if settings.showTicksGrid then
    for tick = 0, 5 do
      local tickX = left + (right - left) * tick / 5
      ui.drawLine(vec2(tickX, bottom), vec2(tickX, bottom + 3 * scale), color(palette, 'amber', 0.85), 0.8 * scale)
    end
  end
end

local function graphOnRight(settings)
  if settings.layout == 'left' then return true end
  if settings.layout == 'right' then return false end

  local ok, position = pcall(function() return ui.windowPos() end)
  if not ok or position == nil or position.x == nil then return true end

  local viewportWidth = 1920
  local viewportOk, viewport = pcall(function() return ui.getMainViewportSize() end)
  if viewportOk and viewport ~= nil and viewport.x ~= nil then viewportWidth = viewport.x end
  return position.x < viewportWidth * 0.5
end

function M.draw(state, history, settings, visual)
  local width = ui.windowWidth()
  local height = ui.windowHeight()
  local scale = U.clamp(settings.hudScale, 0.60, 1.20)
  local palette = visual.palette
  local instrumentOpacity = U.clamp((visual.instrumentOpacity or 1) * settings.instrumentOpacity, 0, 1)
  local backdropOpacity = U.clamp((visual.backdropOpacity or 0.72) * settings.backdropOpacity, 0, 1)
  local margin = 5 * scale
  local gap = 0
  local clusterWidth = (settings.showHandbrake and 220 or 205) * scale
  local clusterHeight = math.max(120 * scale, height - margin * 2)

  ui.pushStyleVarAlpha(instrumentOpacity)
  ui.pushDWriteFont(Theme.fonts.utility)

  local graphVisible = settings.graphExpanded == true
  if graphVisible then
    local available = width - margin * 2 - clusterWidth - gap
    local configuredGraphWidth = settings.graphWidth * scale
    local graphWidth = math.max(180 * scale, math.min(configuredGraphWidth, available))
    local totalWidth = clusterWidth + gap + graphWidth
    local startX = math.max(margin, (width - totalWidth) * 0.5)
    local clusterX, graphX
    if graphOnRight(settings) then
      clusterX, graphX = startX, startX + clusterWidth + gap
    else
      graphX, clusterX = startX, startX + graphWidth + gap
    end
    drawCluster(clusterX, margin, clusterWidth, clusterHeight, state, settings, palette, scale, backdropOpacity)
    drawGraph(graphX, margin, graphWidth, clusterHeight, history, state, settings, palette, scale, backdropOpacity)
  else
    local clusterX = math.max(margin, (width - clusterWidth) * 0.5)
    drawCluster(clusterX, margin, math.min(clusterWidth, width - margin * 2), clusterHeight,
      state, settings, palette, scale, backdropOpacity)
  end

  ui.popDWriteFont()
  ui.popStyleVar(1)
end

return M
