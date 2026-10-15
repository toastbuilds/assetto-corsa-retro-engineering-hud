local GeneralSettings = require('src/general_settings')
local Theme = require('src/theme')
local Layouts = require('src/gt7_retro_layout')
local Layout = Layouts
local PedalHistory = require('src/pedal_history')
local PedalLayers = require('ui/pedal_layers')
local U = require('src/utils')
local Instruments = require('ui/side_instruments')
local InstrumentConfig = require('src/instrument_config')
local InstrumentLayout = require('src/instrument_layout')

local M = {}
local C = Theme.colors

local function point(origin, scale, x, y)
  return origin + vec2(x * scale, y * scale)
end

local function withAlpha(color, alpha)
  return Theme.withAlpha(color, U.clamp(alpha, 0, 1))
end

local function centeredText(text, size, center, color)
  local measured = ui.measureDWriteText(text, size)
  ui.dwriteDrawText(text, size, center - measured / 2, color)
end

local function drawLine(p1, p2, color, width)
  ui.drawLine(p1, p2, color, width)
end

local function drawArc(center, radius, startAngle, endAngle, color, width, segments)
  ui.pathClear()
  ui.pathArcTo(center, radius, startAngle, endAngle, segments or 32)
  ui.pathStroke(color, false, width)
end

local function ellipsePoint(center, radiusX, radiusY, angle)
  return center + vec2(math.cos(angle) * radiusX, math.sin(angle) * radiusY)
end

local function drawEllipseSegment(center, radiusX, radiusY, startAngle, endAngle, color, width, steps)
  local previous = ellipsePoint(center, radiusX, radiusY, startAngle)
  for i = 1, steps or 5 do
    local angle = startAngle + (endAngle - startAngle) * i / (steps or 5)
    local current = ellipsePoint(center, radiusX, radiusY, angle)
    drawLine(previous, current, color, width)
    previous = current
  end
end

local function buildPolygon(origin, scale, coordinates)
  -- Mirrored accents and arrows must keep clockwise winding for convex fill
  -- antialiasing. Preserve the first vertex when reversing the remaining ones.
  local area = 0
  for i, coordinate in ipairs(coordinates) do
    local following = coordinates[i % #coordinates + 1]
    area = area + coordinate[1] * following[2] - following[1] * coordinate[2]
  end
  ui.pathClear()
  ui.pathLineTo(point(origin, scale, coordinates[1][1], coordinates[1][2]))
  local first, last, step = 2, #coordinates, 1
  if area < 0 then first, last, step = #coordinates, 2, -1 end
  for i = first, last, step do
    ui.pathLineTo(point(origin, scale, coordinates[i][1], coordinates[i][2]))
  end
end

local function drawPolygon(origin, scale, coordinates, fill, stroke, strokeWidth)
  buildPolygon(origin, scale, coordinates)
  ui.pathFillConvex(fill)
  buildPolygon(origin, scale, coordinates)
  ui.pathStroke(stroke, true, strokeWidth * scale)
end

local function drawChamferedPanel(origin, scale, left, top, right, bottom, chamfer, fill, stroke, width)
  drawPolygon(origin, scale, {
    { left + chamfer, top }, { right - chamfer, top },
    { right, top + chamfer }, { right, bottom - chamfer },
    { right - chamfer, bottom }, { left + chamfer, bottom },
    { left, bottom - chamfer }, { left, top + chamfer }
  }, fill, stroke, width)
end

local function alertPulse(state, settings, redline)
  if redline then
    if settings.animateRedlineAlert == false then return true end
    return math.floor(state.clock / Layout.redlineBlinkPeriod) % 2 == 0
  end
  if settings.animateShiftAlert == false then return true end
  return math.floor(state.clock / Layout.shiftBlinkPeriod) % 2 == 0
end

local function indicatorLit(state, settings)
  if settings.animateIndicators == false then return true end
  if type(state.indicatorPhase) == 'boolean' then return state.indicatorPhase end
  if type(state.indicatorPhase) == 'number' then return state.indicatorPhase > 0.5 end
  return math.floor(state.clock / Layout.indicatorPeriod) % 2 == 0
end

local function warningBlink(state, settings)
  if settings.animateRedlineAlert == false then return true end
  return math.floor(state.clock / Layout.flagBlinkPeriod) % 2 == 0
end

local function flagColor(state)
  local flag = state.raceFlagType
  if type(flag) ~= 'number' or flag == 0 then return nil end

  -- Match the established digital-mode mapping of CSP flag values.
  if flag == 2 then return C.flagYellow end
  if flag == 5 or flag == 8 then return C.flagRed or C.red end
  if flag == 12 then return C.flagBlue or C.shiftBlue end
  if flag == 13 or flag == 14 then return C.flagNeutral or C.primary end
  return nil
end

local function flagBlinkOn(state, settings)
  if settings == nil or settings.animateFlagAlert ~= false then
    return math.floor(state.clock / Layout.flagBlinkPeriod) % 2 == 0
  end
  return true
end

local function drawDialBezel(center, radius, scale, state, settings)
  local color = flagColor(state)
  local lit = color ~= nil and flagBlinkOn(state, settings)

  if lit then
    ui.drawCircle(center, radius, withAlpha(color, 0.16), 72, 11 * scale)
  end
  ui.drawCircle(center, radius, lit and color or C.metal, 72, (lit and 5 or 4) * scale)
  ui.drawCircle(center, radius - 8 * scale,
    lit and withAlpha(color, 0.78) or C.outline, 72, 2 * scale)
  ui.drawCircle(center, radius - 16 * scale,
    lit and withAlpha(color, 0.34) or C.outlineDim, 72, 2 * scale)
end

local function rpmColor(fraction, active, state, settings)
  local warning = state.rpmWarningFraction or 0.86
  local redline = state.rpmRedlineFraction or 0.96
  local shiftZoneStart = math.max(0, math.min(warning, redline - 0.14))
  if not active then return C.inactive end

  if fraction >= redline then
    if state.rpmRedline then
      return alertPulse(state, settings, true) and C.red or C.amber
    end
    return C.red
  end
  if fraction >= shiftZoneStart then
    return state.rpmWarning and alertPulse(state, settings, false) and C.shiftBlue or C.shiftBlueDim
  end
  return C.primary
end

local function rpmDialColor(fraction, active, state, settings)
  local limiter = math.max(state.rpmDisplayLimiter or 1000, 1000)
  local gaugeLimiter = math.max(state.rpmGaugeLimiter or limiter, 1000)
  return rpmColor(U.clamp(fraction * gaugeLimiter / limiter, 0, 1), active, state, settings)
end

local function drawRpmBar(origin, scale, state, settings)
  local totalWidth = Layout.rpmRight - Layout.rpmLeft
  local segmentWidth = (totalWidth - Layout.rpmGap * (Layout.rpmSegments - 1)) / Layout.rpmSegments
  local rpmFraction = U.clamp(state.rpmNormalized or 0, 0, 1)
  local startFraction = Layout.rpmStartFraction
  local displayedFraction = U.clamp((rpmFraction - startFraction) / (1 - startFraction), 0, 1)
  local filled = rpmFraction >= startFraction
    and math.max(1, math.ceil(displayedFraction * Layout.rpmSegments)) or 0
  for i = 1, Layout.rpmSegments do
    local fraction = startFraction + (1 - startFraction) * i / Layout.rpmSegments
    local x = Layout.rpmLeft + (i - 1) * (segmentWidth + Layout.rpmGap)
    local topLeft = point(origin, scale, x, Layout.rpmTop)
    local bottomRight = point(origin, scale, x + segmentWidth, Layout.rpmTop + Layout.rpmHeight)
    ui.drawRectFilled(topLeft, bottomRight, rpmColor(fraction, i <= filled, state, settings))
  end
end

local function drawTriangle(origin, scale, x, y, direction, color)
  local sign = direction == 'left' and -1 or 1
  drawPolygon(origin, scale, {
    { x + sign * 13, y }, { x - sign * 8, y - 12 }, { x - sign * 8, y + 12 }
  }, color, color, 1)
end

local function modernFlagAppearance(state)
  -- ac.FlagType values from CSP's SDK. These dedicated strips never blink
  -- or yield to radar. Clear/start/cancelled-stop conditions stay green.
  local flag = tonumber(state.raceFlagType) or 0
  if flag == 2 then return C.flagYellow end
  if flag == 3 then return C.flagYellow, 'slippery' end
  if flag == 4 or flag == 15 then return C.flagRed or C.red end
  if flag == 5 or flag == 8 then return C.flagBlack end
  if flag == 6 or flag == 7 or flag == 14 then return C.flagWhite end
  if flag == 9 then return C.flagBlack, 'mechanical' end
  if flag == 10 then return C.flagWhite, 'split' end
  if flag == 12 then return C.flagBlue or C.shiftBlue end
  if flag == 13 then return C.flagWhite, 'checkered' end
  if flag == 16 then return C.flagPurple end
  return C.green
end

local function drawModernFlagStrip(origin, scale, x, top, bottom, state)
  local color, pattern = modernFlagAppearance(state)
  local left, right = x - 2, x + 2
  ui.drawRectFilled(point(origin, scale, left, top), point(origin, scale, right, bottom), color)
  if pattern == 'checkered' or pattern == 'slippery' then
    local rows = 9
    local columns = pattern == 'checkered' and 2 or 1
    local cellWidth, cellHeight = (right - left) / columns, (bottom - top) / rows
    for row = 0, rows - 1 do
      for column = 0, columns - 1 do
        if (row + column) % 2 == 0 then
          ui.drawRectFilled(point(origin, scale, left + column * cellWidth, top + row * cellHeight),
            point(origin, scale, left + (column + 1) * cellWidth, top + (row + 1) * cellHeight),
            pattern == 'checkered' and C.flagBlack or C.red)
        end
      end
    end
  elseif pattern == 'split' then
    ui.drawRectFilled(point(origin, scale, left, top), point(origin, scale, right, (top + bottom) / 2), C.flagBlack)
  elseif pattern == 'mechanical' then
    ui.drawCircleFilled(point(origin, scale, x, (top + bottom) / 2), 1.5 * scale, C.amber, 12)
  end
  ui.drawRect(point(origin, scale, left, top), point(origin, scale, right, bottom),
    color == C.flagBlack and C.flagWhite or color, 0, nil, 0.6 * scale)
end

local function drawCenterBackdrop(origin, scale, backdropOpacity, state)
  local chamfer = Layout.centerBackdropChamfer
  local bottomLeft = Layout.centerLeft + Layout.centerBackdropBottomInset
  local bottomRight = Layout.centerRight - Layout.centerBackdropBottomInset
  drawPolygon(origin, scale, {
    { Layout.centerLeft + chamfer, Layout.centerTop },
    { Layout.centerRight - chamfer, Layout.centerTop },
    { Layout.centerRight, Layout.centerTop + chamfer },
    { Layout.centerRight, Layout.centerBottom - chamfer },
    { bottomRight - chamfer, Layout.centerBottom },
    { bottomLeft + chamfer, Layout.centerBottom },
    { Layout.centerLeft, Layout.centerBottom - chamfer },
    { Layout.centerLeft, Layout.centerTop + chamfer }
  }, withAlpha(C.panel, math.min(0.92, math.max(0.58, backdropOpacity + 0.12))),
    Layout.centerStyle == 'classic' and C.outlineDim or C.outlineSoft, 1.2)

  if Layout.centerStyle == 'modern' then
    local top = Layout.centerTop + 24
    drawLine(point(origin, scale, Layout.centerLeft + 40, top),
      point(origin, scale, Layout.centerRight - 40, top), C.outlineDim, 1 * scale)
  elseif Layout.centerStyle == 'steering_dial' then
    drawChamferedPanel(origin, scale, Layout.readoutLeft, Layout.readoutTop,
      Layout.readoutRight, Layout.readoutBottom, 14,
      withAlpha(C.panelRaised, backdropOpacity * 0.28), C.outlineDim, 1)
    drawLine(point(origin, scale, Layout.readoutDividerX, Layout.readoutTop + 16),
      point(origin, scale, Layout.readoutDividerX, Layout.readoutBottom - 12), C.outlineDim, 1 * scale)
  elseif Layout.centerStyle == 'outer' then
    local divider = Layout.gearPodCenterX - Layout.gearPodHalfWidth - 36
    drawLine(point(origin, scale, divider, Layout.gearPodTop + 12),
      point(origin, scale, divider, Layout.gearPodBottom - 10), C.outlineDim, 1 * scale)
  end
end

local function drawGearPod(origin, scale, state, settings, backdropOpacity)
  local halfWidth = Layout.gearPodHalfWidth
  local left = Layout.gearPodCenterX - halfWidth
  local right = Layout.gearPodCenterX + halfWidth
  local top = Layout.gearPodTop
  local bottom = Layout.gearPodBottom
  local chamfer = Layout.gearPodChamfer
  local warning = state.rpmWarning == true
  local redline = state.rpmRedline == true
  local alert = warning or redline
  local pulse = alert and alertPulse(state, settings, redline)
  local accent = redline and C.red or C.amber
  local fill = alert
    and withAlpha(accent, pulse and 0.28 or 0.10)
    or withAlpha(C.panelRaised, math.min(0.86, math.max(0.54, backdropOpacity + 0.02)))
  local stroke = alert and (pulse and accent or withAlpha(accent, 0.55)) or C.outlineSoft

  drawPolygon(origin, scale, {
    { left + chamfer, top }, { right - chamfer, top },
    { right, top + chamfer }, { right, bottom - chamfer },
    { right - chamfer, bottom }, { left + chamfer, bottom },
    { left, bottom - chamfer }, { left, top + chamfer }
  }, fill, stroke, alert and 2.4 or 1.4)
  return halfWidth
end

local function drawSpeedReadout(origin, scale, state)
  local speedSize = Layout.speedTextSize * scale
  local speedWidth = ui.measureDWriteText(state.speedText, speedSize).x
  if speedWidth > Layout.speedReadoutWidth * scale then
    speedSize = speedSize * Layout.speedReadoutWidth * scale / speedWidth
  end
  centeredText(state.speedText, speedSize,
    point(origin, scale, Layout.speedCenterX, Layout.speedCenterY), C.primary)
  centeredText(state.speedUnit, 19 * scale,
    point(origin, scale, Layout.speedCenterX, Layout.speedUnitY), C.secondary)
  if Layout.speedLabelX then
    centeredText('SPEED', 12 * scale,
      point(origin, scale, Layout.speedLabelX, Layout.speedLabelY), C.secondary)
  end
end

local function drawGearReadout(origin, scale, state, settings, backdropOpacity)
  local redlineOn = state.rpmRedline and alertPulse(state, settings, true)
  local valueColor = state.rpmRedline and (redlineOn and C.red or C.amber)
    or (state.rpmWarning and C.amber or C.primary)
  local gearPodHalfWidth = drawGearPod(origin, scale, state, settings, backdropOpacity)
  local gearSize = 100 * scale
  local measuredGearWidth = ui.measureDWriteText(state.gearText, gearSize).x
  local availableGearWidth = (gearPodHalfWidth * 2 - 20) * scale
  if measuredGearWidth > availableGearWidth then
    gearSize = gearSize * availableGearWidth / measuredGearWidth
  end
  centeredText(state.gearText, gearSize,
    point(origin, scale, Layout.gearPodCenterX, Layout.gearCenterY), valueColor)
  centeredText('GEAR', 14 * scale, point(origin, scale, Layout.gearPodCenterX, Layout.gearLabelY),
    state.rpmRedline and C.red or (state.rpmWarning and C.amber or C.secondary))
end

local function drawSteering(origin, scale, state, settings)
  if settings.showSteering ~= false then
    local steering = U.clamp(state.steeringInput or 0, -1, 1)
    local x, y = Layout.steeringCenterX, Layout.steeringCenterY
    if Layout.steeringStyle == 'dial' then
      local center = point(origin, scale, x, y)
      drawArc(center, Layout.steeringRadius * scale, math.pi, math.pi * 2, C.inactive, 10 * scale, 36)
      drawLine(point(origin, scale, x - 28, y), point(origin, scale, x + 28, y), C.metalDim, 2 * scale)
      drawLine(point(origin, scale, x, y - 16), point(origin, scale, x, y + 26), C.outlineSoft, 2 * scale)
      local tip = U.polar(center, Layout.steeringRadius * scale, -math.pi / 2 + steering * math.pi / 2)
      drawLine(center, tip, C.cyan, 4 * scale)
      ui.drawCircleFilled(center, 6 * scale, C.cyan, 20)
      ui.drawCircleFilled(center, 3 * scale, C.primary, 16)
    else
      local half = Layout.steeringHalfWidth
      drawLine(point(origin, scale, x - half, y), point(origin, scale, x + half, y), C.outlineDim, 3 * scale)
      drawLine(point(origin, scale, x, y - 9), point(origin, scale, x, y + 9), C.primary, 2 * scale)
      local markerX = x + steering * (half - 6)
      if Layout.steeringStyle == 'modern' then
        for i = -5, 5 do
          local tickX = x + i * half / 5
          drawLine(point(origin, scale, tickX, y - 3), point(origin, scale, tickX, y + 3),
            C.outlineSoft, 1 * scale)
        end
        ui.drawRectFilled(point(origin, scale, markerX - 3, y - 10),
          point(origin, scale, markerX + 3, y + 10), C.cyan)
      else
        ui.drawCircleFilled(point(origin, scale, markerX, y), 5 * scale, C.cyan, 16)
      end
    end
    centeredText('STEER', 11 * scale,
      point(origin, scale, x, Layout.steeringLabelY), C.secondary)
  end
end

local function drawSpeedDial(origin, scale, state, settings, backdropOpacity)
  local center = point(origin, scale, Layout.leftCenterX, Layout.dialCenterY)
  scale = scale * (Layout.instrumentScale or 1)
  Instruments.draw(center, scale, state, settings, Layout, C, backdropOpacity, false, rpmDialColor)
  drawDialBezel(center, Layout.dialRadius * scale, scale, state, settings)
end

local function drawRpmDial(origin, scale, state, settings, backdropOpacity)
  local center = point(origin, scale, Layout.rightCenterX, Layout.dialCenterY)
  scale = scale * (Layout.instrumentScale or 1)
  Instruments.draw(center, scale, state, settings, Layout, C, backdropOpacity, true, rpmDialColor)
  drawDialBezel(center, Layout.dialRadius * scale, scale, state, settings)
end

local function drawFfb(origin, scale, state)
  local center = point(origin, scale, Layout.ffbCenterX, Layout.ffbCenterY)
  local fraction = state.ffbAvailable and U.clamp(state.ffbNeedle or 0, 0, 1) or 0

  local angle = Layout.ffbStart + (Layout.ffbEnd - Layout.ffbStart) * fraction
  local pivot = center + vec2(0, Layout.ffbNeedlePivotOffsetY * scale)
  local tip = ellipsePoint(center, (Layout.ffbRadiusX - 8) * scale,
    (Layout.ffbRadiusY - 8) * scale, angle)
  local needleColor = not state.ffbAvailable and C.outlineSoft
    or (state.ffbClipping and C.red or (fraction >= 0.9 and C.amber or C.primary))
  drawLine(pivot, tip, withAlpha(C.backlight, 0.16), 10 * scale)
  drawLine(pivot, tip, C.outlineDim, 6 * scale)
  drawLine(pivot, tip, needleColor, 3 * scale)
  ui.drawCircleFilled(pivot, 10 * scale, C.panelRaised, 20)
  ui.drawCircle(pivot, 10 * scale, C.outlineSoft, 20, 2 * scale)
  ui.drawCircleFilled(pivot, 3.5 * scale, needleColor, 16)
end

local function drawLimit(origin, scale, state)
  local center = point(origin, scale, Layout.ffbCenterX, Layout.ffbCenterY)
  local fraction = state.limitAvailable and U.clamp(state.limitNeedle or 0, 0, 1) or 0
  local assistColor = state.limitAbsWarning and C.red or (state.limitTcWarning and C.amber or nil)

  local angle = Layout.ffbStart + (Layout.ffbEnd - Layout.ffbStart) * fraction
  local pivot = center + vec2(0, Layout.ffbNeedlePivotOffsetY * scale)
  local tip = ellipsePoint(center, (Layout.ffbRadiusX - 8) * scale,
    (Layout.ffbRadiusY - 8) * scale, angle)
  local needleColor = not state.limitAvailable and C.outlineSoft
    or assistColor
    or (fraction >= Layout.limitRedFraction and C.red
      or (fraction >= Layout.limitAmberFraction and C.amber or C.primary))
  drawLine(pivot, tip, withAlpha(C.backlight, 0.16), 10 * scale)
  drawLine(pivot, tip, C.outlineDim, 6 * scale)
  drawLine(pivot, tip, needleColor, 3 * scale)
  ui.drawCircleFilled(pivot, 10 * scale, C.panelRaised, 20)
  ui.drawCircle(pivot, 10 * scale, C.outlineSoft, 20, 2 * scale)
  ui.drawCircleFilled(pivot, 3.5 * scale, needleColor, 16)
end

local function drawPedalTrace(origin, scale, history, key, color, width, top, bottom)
  if not history or history.count == 0 then return end
  local left = Layout.historyLeft + 12
  local right = Layout.historyRight - 12
  local plotWidth = right - left
  local plotHeight = bottom - top
  local firstOffset = PedalHistory.CAPACITY - history.count
  ui.pathClear()
  for ordinal = 0, history.count - 1 do
    local sample = PedalHistory.sampleAt(history, ordinal)
    local value = U.clamp(sample and sample[key] or 0, 0, 1)
    local x = left + (firstOffset + ordinal) / (PedalHistory.CAPACITY - 1) * plotWidth
    local y = bottom - value * plotHeight
    ui.pathLineTo(point(origin, scale, x, y))
  end
  ui.pathStroke(color, false, width * scale)
end

local function drawLowerFrame(origin, scale, backdropOpacity)
  local fill = withAlpha(C.panel, math.min(0.90, math.max(0.52, backdropOpacity + 0.08)))
  if Layout.lowerFrameStyle == 'classic' then
    local topLeft = point(origin, scale, Layout.historyLeft, Layout.historyTop)
    local bottomRight = point(origin, scale, Layout.historyRight, Layout.historyBottom)
    ui.drawRectFilled(topLeft, bottomRight, fill, 8 * scale)
    ui.drawRect(topLeft, bottomRight, C.outlineSoft, 8 * scale, nil, 1.1 * scale)
  else
    drawChamferedPanel(origin, scale, Layout.historyLeft, Layout.historyTop,
      Layout.historyRight, Layout.historyBottom, 16, fill, C.outlineSoft, 1.1)
  end
end

local function drawPedalHistory(origin, scale, state, backdropOpacity)
  local left = Layout.historyLeft
  local right = Layout.historyRight
  local top = Layout.historyTop
  local bottom = Layout.historyBottom
  if not Layout.lowerFrame then drawLowerFrame(origin, scale, backdropOpacity) end

  centeredText('PEDALS', 11 * scale, point(origin, scale, left + 45, top + 13), C.secondary)
  drawLine(point(origin, scale, right - 102, top + 13),
    point(origin, scale, right - 88, top + 13), C.red, 2 * scale)
  centeredText('BRK', 9 * scale, point(origin, scale, right - 72, top + 13), C.red)
  drawLine(point(origin, scale, right - 50, top + 13),
    point(origin, scale, right - 36, top + 13), C.cyan, 2 * scale)
  centeredText('THR', 9 * scale, point(origin, scale, right - 20, top + 13), C.cyan)

  local plotTop = top + 25
  local plotBottom = bottom - 10
  local plotLeft = left + 12
  local plotRight = right - 12
  for row = 0, Layout.historyGridRows do
    local y = plotTop + (plotBottom - plotTop) * row / Layout.historyGridRows
    drawLine(point(origin, scale, plotLeft, y), point(origin, scale, plotRight, y),
      withAlpha(C.outlineDim, 0.62), 0.7 * scale)
  end
  for column = 0, Layout.historyGridColumns do
    local x = plotLeft + (plotRight - plotLeft) * column / Layout.historyGridColumns
    drawLine(point(origin, scale, x, plotTop), point(origin, scale, x, plotBottom),
      withAlpha(C.outlineDim, 0.48), 0.7 * scale)
  end
  drawLine(point(origin, scale, plotLeft, plotBottom), point(origin, scale, plotRight, plotBottom),
    withAlpha(C.amber, 0.72), 1 * scale)

  drawPedalTrace(origin, scale, state.pedalHistory, 'brake', C.red, 2.2, plotTop, plotBottom)
  drawPedalTrace(origin, scale, state.pedalHistory, 'throttle', C.cyan, 2.2, plotTop, plotBottom)
  if not state.pedalHistory or state.pedalHistory.count == 0 then
    centeredText('NO PEDAL DATA', 10 * scale,
      point(origin, scale, (left + right) / 2, (plotTop + plotBottom) / 2), C.outlineSoft)
  end
end

local function drawPedalBar(origin, scale, x, value, activeColor, side, assistColor, layer)
  local segmentCount = Layout.pedalSegments
  local gap = Layout.pedalGap * scale
  local segmentHeight = (Layout.pedalHeight * scale - gap * (segmentCount - 1)) / segmentCount
  local filled = math.floor(U.clamp(value or 0, 0, 1) * segmentCount + 0.5)

  for i = 1, segmentCount do
    local y = Layout.pedalTop * scale + (segmentCount - i) * (segmentHeight + gap)
    local color = i <= filled and activeColor or C.inactive
    local intervention = not layer and i > segmentCount - 2 and assistColor ~= nil
    if intervention then color = assistColor end
    if Layout.pedalUpperExtraWidth then
      local extra = i > segmentCount - 2 and Layout.pedalUpperExtraWidth or 0
      local left = x - (side == 'left' and extra or 0)
      drawChamferedPanel(origin, scale, left, y / scale,
        left + Layout.pedalWidth + extra, (y + segmentHeight) / scale, 2,
        layer and C.inactive or color,
        (intervention or i <= filled) and withAlpha(color, 0.6) or C.outlineDim, 0.6)
    else
      local topLeft = origin + vec2(x * scale, y)
      if not layer then
        ui.drawRectFilled(topLeft, topLeft + vec2(Layout.pedalWidth * scale, segmentHeight), color)
      end
    end
    if layer then
      local extra = Layout.pedalUpperExtraWidth and i > segmentCount - 2 and Layout.pedalUpperExtraWidth or 0
      local left = x - (side == 'left' and extra or 0)
      local inset = Layout.pedalUpperExtraWidth and 2 * scale or 0
      PedalLayers.rect(origin + vec2(left * scale + inset, y + inset),
        origin + vec2((left + Layout.pedalWidth + extra) * scale - inset, y + segmentHeight - inset),
        PedalLayers.fraction(layer.input, i, segmentCount),
        layer.output and PedalLayers.fraction(layer.output, i, segmentCount), activeColor, C.primary, C.inactive)
    end
  end
end

local function drawFlagLamps(origin, scale, x, state, settings)
  local color = flagColor(state)
  local lit = color ~= nil and flagBlinkOn(state, settings)
  local lampColor = lit and color or C.inactive
  for offset = -1, 1, 2 do
    local center = point(origin, scale, x, Layout.indicatorY + offset * Layout.flagLampSpacing / 2)
    if lit then ui.drawCircleFilled(center, 8 * scale, withAlpha(color, 0.16), 18) end
    ui.drawCircleFilled(center, Layout.flagLampRadius * scale, lampColor, 18)
  end
end

local function drawModernRadarBars(origin, scale, side, level, visible)
  local direction = side == 'left' and -1 or 1
  local x = side == 'left' and Layout.centerLeft or Layout.centerRight
  local accent = level >= 3 and C.red or C.amber
  for i = 1, 3 do
    local y = Layout.centerTop + 102 + (3 - i) * 15
    local coordinates = {
      { x - direction * 16, y }, { x - direction * 32, y + 16 },
      { x - direction * 32, y + 27 }, { x - direction * 16, y + 11 }
    }
    local active = visible and level >= i
    if active then
      drawPolygon(origin, scale, coordinates, withAlpha(accent, 0.08), withAlpha(accent, 0.18), 4)
    end
    local color = active and accent or C.outlineDim
    drawPolygon(origin, scale, coordinates, color, color, 0.7)
  end
end

local function drawRadarLamp(origin, scale, x, y, active, color)
  local center = point(origin, scale, x, y)
  if active then
    ui.drawCircleFilled(center, 9 * scale, withAlpha(color, 0.18), 20)
    ui.drawCircleFilled(center, Layout.flagLampRadius * scale, color, 18)
  else
    ui.drawCircleFilled(center, Layout.flagLampRadius * scale, C.outlineDim, 18)
  end
end

local function drawRadarLights(origin, scale, side, level, visible)
  local left = side == 'left'
  local indicatorX = left and Layout.indicatorLeftX or Layout.indicatorRightX
  local x = indicatorX + (left and -38 or 38)
  local lampX = x + (left and -22 or 22)
  local color = level >= 3 and C.red or C.amber
  local shownLevel = visible and level or 0

  drawTriangle(origin, scale, x, Layout.indicatorY, side,
    shownLevel >= 1 and color or C.outlineDim)
  drawRadarLamp(origin, scale, lampX,
    Layout.indicatorY - Layout.flagLampSpacing / 2, shownLevel >= 2, color)
  drawRadarLamp(origin, scale, lampX,
    Layout.indicatorY + Layout.flagLampSpacing / 2, shownLevel >= 3, color)
end

local function drawRadarArcs(origin, scale, side, level, visible)
  if level == 0 then return end
  local left = side == 'left'
  local x = left and Layout.radarArcLeftX or Layout.radarArcRightX
  local center = point(origin, scale, x, Layout.radarArcY)
  local color = level >= 3 and C.red or C.amber
  local startAngle = left and -math.pi / 2 or math.pi
  local endAngle = left and 0 or math.pi * 1.5

  for i = 1, 3 do
    local designRadius = Layout.radarArcFirstRadius + (i - 1) * Layout.radarArcRadiusStep
    local radius = designRadius * scale
    local active = visible and level >= i
    if active then
      drawArc(center, radius, startAngle, endAngle, withAlpha(color, 0.18), 12 * scale, 20)
    end
    drawArc(center, radius, startAngle, endAngle,
      active and color or C.outlineDim, (active and 6 or 3) * scale, 20)
  end
end

local function drawTurnIndicator(origin, scale, side, state, settings)
  local left = side == 'left'
  local x = left and Layout.indicatorLeftX or Layout.indicatorRightX
  local blink = indicatorLit(state, settings)
  local indicator = left and state.leftIndicator or false
  if not left then indicator = state.rightIndicator end
  local active = (state.hazardLights or indicator) and blink
  drawTriangle(origin, scale, x, Layout.indicatorY, side,
    active and C.amber or C.outlineDim)
end

local function drawVerticalColumn(origin, scale, side, count, filled, visible, color, outside)
  local left = side == 'left'
  local x = left and Layout.sections.alerts.columnLeftX or Layout.sections.alerts.columnRightX
  if outside then x = left and Layout.centerLeft - 20 or Layout.centerRight + 20 end
  local bottom = count == 9 and 269 or 251
  local spacing = count == 9 and 18 or 14
  for i = 1, count do
    local lampColor = type(color) == 'function' and color(i) or color
    drawRadarLamp(origin, scale, x, bottom - (i - 1) * spacing,
      visible and i <= filled, lampColor or C.outlineDim)
  end
end

local function drawFlagPresentation(origin, scale, side, state, settings)
  local left = side == 'left'
  local style = Layout.flagPresentation
  if style == 'modern_strips' then
    local x = left and Layout.centerLeft + 14 or Layout.centerRight - 14
    drawModernFlagStrip(origin, scale, x, Layout.centerTop + 40, Layout.centerTop + 67, state)
    return
  end
  if style == 'classic_lights' then
    local indicatorX = left and Layout.indicatorLeftX or Layout.indicatorRightX
    local x = left and indicatorX + Layout.flagLampSideOffset or indicatorX - Layout.flagLampSideOffset
    drawFlagLamps(origin, scale, x, state, settings)
    return
  end
  local count = style == 'column_9' and 9 or 3
  local color = flagColor(state)
  local visible = color ~= nil and flagBlinkOn(state, settings)
  drawVerticalColumn(origin, scale, side, count, count, visible, color, false)
end

local function nineLampColor(index)
  return index <= 3 and C.flagYellow or (index <= 6 and C.shiftBlue or C.red)
end

local function drawRadarPresentation(origin, scale, side, level, visible, level9)
  local style = Layout.radarPresentation
  if style == 'classic_lights' then
    drawRadarLights(origin, scale, side, level, visible)
  elseif style == 'modern_bars' then
    drawModernRadarBars(origin, scale, side, level, visible)
  elseif style == 'column_3' or style == 'column_9' then
    local count = style == 'column_9' and 9 or 3
    local filled = count == 9 and math.max(0, math.min(9, level9 or level)) or level
    local color = count == 9 and nineLampColor or (level >= 3 and C.red or C.amber)
    drawVerticalColumn(origin, scale, side, count, filled, visible, color,
      Layout.flagPresentation == 'modern_strips')
  else
    drawRadarArcs(origin, scale, side, level, visible)
  end
end

local function drawSideIndicators(origin, scale, state, settings)
  local radarEnabled = settings.gt7ProximityRadar ~= false and state.proximityRadarAvailable
  local blinkOn = math.floor((state.clock or 0) / Layout.radarBlinkPeriod) % 2 == 0
  local function drawSide(side, level, level9)
    drawTurnIndicator(origin, scale, side, state, settings)

    -- Modern continuous flag strips are a persistent status channel and never
    -- yield to proximity radar, even during the radar's off blink phase.
    if Layout.flagPresentation == 'modern_strips' then
      drawFlagPresentation(origin, scale, side, state, settings)
    end

    local traffic = radarEnabled and level > 0
    if traffic then
      drawRadarPresentation(origin, scale, side, level, level < 3 or blinkOn, level9)
    elseif Layout.flagPresentation ~= 'modern_strips' then
      drawFlagPresentation(origin, scale, side, state, settings)
    end
  end
  drawSide('left', state.radarLeftLevel or 0, state.radarLeftLevel9)
  drawSide('right', state.radarRightLevel or 0, state.radarRightLevel9)
end

local function drawPedals(origin, scale, state, settings)
  drawPedalBar(origin, scale, Layout.brakeX, state.brake, C.red, 'left',
    state.absActive == true and C.flagWhite or nil, PedalLayers.channel(state, settings, 'brake'))
  drawPedalBar(origin, scale, Layout.throttleX, state.throttle, C.cyan, 'right',
    state.tcActive == true and C.red or nil, PedalLayers.channel(state, settings, 'throttle'))
end

local function drawBrakeIcon(center, scale, color)
  ui.drawCircle(center, 12 * scale, color, 24, 2 * scale)
  drawArc(center, 17 * scale, math.rad(120), math.rad(240), color, 2 * scale, 12)
  drawArc(center, 17 * scale, math.rad(-60), math.rad(60), color, 2 * scale, 12)
  centeredText('!', 15 * scale, center, color)
end

local function drawLightIcon(center, scale, color)
  ui.drawRectFilled(center + vec2(-12 * scale, -8 * scale), center + vec2(-4 * scale, 8 * scale), color)
  for i = -1, 1 do
    drawLine(center + vec2(1 * scale, i * 5 * scale), center + vec2(16 * scale, i * 8 * scale), color, 2 * scale)
  end
end

local function drawEngineIcon(center, scale, color)
  -- This icon uses screen-space lines to stay crisp at small HUD scales.
  drawLine(center + vec2(-14 * scale, -8 * scale), center + vec2(10 * scale, -8 * scale), color, 2 * scale)
  drawLine(center + vec2(10 * scale, -8 * scale), center + vec2(15 * scale, -2 * scale), color, 2 * scale)
  drawLine(center + vec2(15 * scale, -2 * scale), center + vec2(15 * scale, 9 * scale), color, 2 * scale)
  drawLine(center + vec2(15 * scale, 9 * scale), center + vec2(-14 * scale, 9 * scale), color, 2 * scale)
  drawLine(center + vec2(-14 * scale, 9 * scale), center + vec2(-14 * scale, -8 * scale), color, 2 * scale)
  drawLine(center + vec2(-8 * scale, -8 * scale), center + vec2(-8 * scale, -13 * scale), color, 2 * scale)
  drawLine(center + vec2(-8 * scale, -13 * scale), center + vec2(2 * scale, -13 * scale), color, 2 * scale)
end

local function drawStatusPod(origin, scale, x, label, available, active, color, icon, backdropOpacity)
  local factor = Layout.indicatorScale or 1
  local anchor = x < Layout.width / 2 and Layout.leftCenterX or Layout.rightCenterX
  x = anchor + (x - anchor) * factor
  local center = point(origin, scale, x, Layout.statusY or 443)
  scale = scale * factor
  local panelFill = withAlpha(C.panelRaised, math.max(0.82, math.min(0.98, backdropOpacity + 0.18)))
  local fill = active and withAlpha(color, 0.26) or panelFill
  local stroke = active and color or (available and C.outlineSoft or C.outlineDim)
  ui.drawCircleFilled(center, 23 * scale, fill, 28)
  ui.drawCircle(center, 23 * scale, stroke, 28, (active and 2.2 or 1.2) * scale)
  if active then
    ui.drawCircleFilled(center, 17 * scale, withAlpha(color, 0.12), 28)
  end
  local iconColor = not available and C.outlineDim or (active and color or C.secondary)
  if icon then icon(center, scale, iconColor) else centeredText(label, 11 * scale, center, iconColor) end
end

local function drawStatusStrips(origin, scale, state, settings, backdropOpacity)
  local fuelLow = state.fuel ~= nil and (state.fuelNormalized or 0) < InstrumentConfig.fuelWarning
  local fuelActive = fuelLow and warningBlink(state, settings)
  drawStatusPod(origin, scale, Layout.leftCenterX + Layout.leftFuelStatusOffset,
    'FUEL', state.fuel ~= nil, fuelActive, C.red, Instruments.fuelIcon, backdropOpacity)
  drawStatusPod(origin, scale, Layout.leftCenterX + Layout.leftTcStatusOffset,
    'TC', state.tcSupported, state.tcActive == true,
    C.amber, nil, backdropOpacity)
  drawStatusPod(origin, scale, Layout.leftCenterX + Layout.leftPitStatusOffset,
    'PIT', true, state.pitLane or state.pitLimiter == true,
    C.amber, nil, backdropOpacity)
  drawStatusPod(origin, scale, Layout.leftCenterX + Layout.leftLimiterStatusOffset,
    'LIM', state.pitLimiter ~= nil,
    state.pitLimiter == true, C.amber, nil, backdropOpacity)

  drawStatusPod(origin, scale, Layout.rightCenterX + Layout.rightAbsStatusOffset,
    'ABS', state.absSupported,
    state.absActive == true or state.absLevel == 0, state.absLevel == 0 and C.red or C.amber,
    nil, backdropOpacity)
  local lightsAvailable = settings.showLights and state.lightsAvailable
  drawStatusPod(origin, scale, Layout.rightCenterX + Layout.rightLightsStatusOffset,
    'L', lightsAvailable, lightsAvailable and state.headlights == true,
    state.highBeams and C.amber or C.cyan, lightsAvailable and drawLightIcon or nil, backdropOpacity)
  drawStatusPod(origin, scale, Layout.rightCenterX + Layout.rightBrakeStatusOffset,
    'P', true, state.handbrake > 0.05,
    C.red, drawBrakeIcon, backdropOpacity)
  drawStatusPod(origin, scale, Layout.rightCenterX + Layout.rightEngineStatusOffset,
    'ENG', state.engineLifeLeft ~= nil, state.engineWarning,
    C.red, drawEngineIcon, backdropOpacity)
end

local function drawDebug(origin, scale, state, width, height)
  local function raw(value)
    return value == nil and '---' or string.format('%+.2f', value)
  end
  local rows = {
    string.format('FIT %.0fx%.0f', width, height),
    string.format('RPM %.0f / %.0f', state.rpm or 0, state.rpmDisplayLimiter or 0),
    string.format('FFB RAW %+.3f', state.ffbSigned or 0),
    string.format('FFB UI %d%% %s', state.ffbPercent or 0, state.ffbAvailable and 'FINAL' or 'N/A'),
    string.format('TURBO %s %.2f', state.turboAvailable and 'YES' or 'NO', state.turboBoost or 0),
    string.format('VACUUM %s', state.gt7Instruments and state.gt7Instruments.boostSimulated and 'SIMULATED' or 'INACTIVE'),
    string.format('LIMIT %3d%% F %.2f R %.2f', U.round((state.limitNeedle or 0) * 100),
      state.limitFront or 0, state.limitRear or 0)
  }
  for index, wheel in ipairs(state.limitWheels or {}) do
    rows[#rows + 1] = string.format('W%d S%s R%s A%s L%s', index, raw(wheel.tyreSlip),
      raw(wheel.slipRatio), raw(wheel.slipAngle), raw(wheel.load))
  end
  local topLeft = point(origin, scale, Layout.debugLeft, 305)
  ui.drawRectFilled(topLeft, topLeft + vec2(190 * scale, (#rows * 13 + 10) * scale),
    withAlpha(C.debug, 0.92))
  for i, row in ipairs(rows) do
    ui.dwriteDrawText(row, 9 * scale, topLeft + vec2(7 * scale, (i * 13 - 9) * scale), C.primary)
  end
end

function M.draw(state, settings)
  Layout = InstrumentLayout.resolve(Layouts.resolve(settings), settings)
  C = GeneralSettings.palette(Theme.get(settings.theme), settings.backgroundOpacity)
  local width = ui.windowWidth()
  local height = ui.windowHeight()
  local fitWidth, fitHeight = Layout.fitRight - Layout.fitLeft, Layout.fitBottom - Layout.fitTop
  local fittedScale = math.min(width / fitWidth, height / fitHeight)
  -- Window resizing is the primary scale control. The persisted 0.72 default
  -- is neutral here, while the shared slider remains available as a restrained
  -- fine adjustment around the mouse-controlled fitted size.
  local sliderScale = 1 + ((settings.hudScale or 0.72) - 0.72) * 0.6
  local scale = fittedScale * U.clamp(sliderScale, 0.82, 1.28)
  local origin = vec2((width - fitWidth * scale) / 2 - Layout.fitLeft * scale,
    (height - fitHeight * scale) / 2 - Layout.fitTop * scale)
  local backdropOpacity = 0.72 -- Authored reference; palette applies global background opacity.

  ui.pushStyleVarAlpha(settings.opacity or 1)
  ui.pushDWriteFont(Theme.fonts.utility)

  drawCenterBackdrop(origin, scale, backdropOpacity, state)
  if Layout.showRpmBar then drawRpmBar(origin, scale, state, settings) end
  drawSpeedReadout(origin, scale, state)
  drawGearReadout(origin, scale, state, settings, backdropOpacity)
  drawSteering(origin, scale, state, settings)
  drawSpeedDial(origin, scale, state, settings, backdropOpacity)
  drawRpmDial(origin, scale, state, settings, backdropOpacity)
  drawPedals(origin, scale, state, settings)
  drawSideIndicators(origin, scale, state, settings)
  if Layout.lowerFrame and settings.gt7LowerPanelMode == 'pedal_history' then
    drawLowerFrame(origin, scale, backdropOpacity)
  end
  if settings.gt7LowerPanelMode == 'pedal_history' then
    drawPedalHistory(origin, scale, state, backdropOpacity)
  elseif settings.gt7LowerPanelMode == 'ffb' then
    drawFfb(origin, scale, state)
  elseif settings.gt7LowerPanelMode ~= 'invisible' then
    drawLimit(origin, scale, state)
  end
  drawStatusStrips(origin, scale, state, settings, backdropOpacity)
  if settings.debug then drawDebug(origin, scale, state, width, height) end


  ui.popDWriteFont()
  ui.popStyleVar(1)
end

return M
