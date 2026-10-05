local GeneralSettings = require('src/general_settings')
local Theme = require('src/theme')
local Layout = require('src/layout')
local U = require('src/utils')
local InstrumentConfig = require('src/instrument_config')
local Needle = require('ui/instrument_needle')
local Hybrid = require('src/hybrid')
local HybridGauge = require('ui/hybrid_gauge')

local M = {}
local drawAnalogElectronics
-- Updated at the start of each frame so every drawing helper uses the same
-- selected palette, including the analog-only elements.
local C = Theme.colors

local function point(origin, scale, x, y)
  return origin + vec2(x * scale, y * scale)
end

local function centeredText(text, size, center, color)
  local measured = ui.measureDWriteText(text, size)
  ui.dwriteDrawText(text, size, center - measured / 2, color)
end

local function centeredBacklitText(text, size, center, color, scale, backlit)
  if backlit then
    local glow = Theme.withAlpha(C.backlight, 0.26)
    local spread = 1.35 * scale
    centeredText(text, size, center + vec2(-spread, 0), glow)
    centeredText(text, size, center + vec2(spread, 0), glow)
    centeredText(text, size, center + vec2(0, -spread), glow)
    centeredText(text, size, center + vec2(0, spread), glow)
  end
  centeredText(text, size, center, color)
end

local function drawArc(center, radius, startAngle, endAngle, color, width, segments)
  ui.pathClear()
  ui.pathArcTo(center, radius, startAngle, endAngle, segments or 32)
  ui.pathStroke(color, false, width)
end

local function drawLine(p1, p2, color, width)
  ui.drawLine(p1, p2, color, width)
end

local function drawOctagon(center, halfWidth, halfHeight, chamfer, fill, stroke, strokeWidth)
  local function p(x, y)
    return center + vec2(x, y)
  end

  ui.pathClear()
  ui.pathLineTo(p(-halfWidth + chamfer, -halfHeight))
  ui.pathLineTo(p(halfWidth - chamfer, -halfHeight))
  ui.pathLineTo(p(halfWidth, -halfHeight + chamfer))
  ui.pathLineTo(p(halfWidth, halfHeight - chamfer))
  ui.pathLineTo(p(halfWidth - chamfer, halfHeight))
  ui.pathLineTo(p(-halfWidth + chamfer, halfHeight))
  ui.pathLineTo(p(-halfWidth, halfHeight - chamfer))
  ui.pathLineTo(p(-halfWidth, -halfHeight + chamfer))
  ui.pathFillConvex(fill)

  ui.pathClear()
  ui.pathLineTo(p(-halfWidth + chamfer, -halfHeight))
  ui.pathLineTo(p(halfWidth - chamfer, -halfHeight))
  ui.pathLineTo(p(halfWidth, -halfHeight + chamfer))
  ui.pathLineTo(p(halfWidth, halfHeight - chamfer))
  ui.pathLineTo(p(halfWidth - chamfer, halfHeight))
  ui.pathLineTo(p(-halfWidth + chamfer, halfHeight))
  ui.pathLineTo(p(-halfWidth, halfHeight - chamfer))
  ui.pathLineTo(p(-halfWidth, -halfHeight + chamfer))
  ui.pathStroke(stroke, true, strokeWidth)
end

local function drawBezelArcCut(center, radius, angle, span, scale, active, backdrop, activeFill, activeStroke)
  local halfWidth = Layout.bezelCutWidth * scale / 2
  local startAngle = angle - span / 2
  local endAngle = angle + span / 2
  local activeColor = activeStroke or C.amber
  local fill = active and (activeFill or Theme.withAlpha(activeColor, 0.92)) or backdrop
  local stroke = active and activeColor or C.outlineDim

  if active then
    drawArc(center, radius, startAngle, endAngle, Theme.withAlpha(activeColor, 0.22),
      (Layout.bezelCutWidth + 10) * scale, 10)
  end
  drawArc(center, radius, startAngle, endAngle, fill, Layout.bezelCutWidth * scale, 10)
  drawArc(center, radius - halfWidth, startAngle, endAngle, C.outlineDim, 1.2 * scale, 10)
  drawArc(center, radius + halfWidth, startAngle, endAngle, C.outlineDim, 1.2 * scale, 10)
  drawArc(center, radius, startAngle, endAngle, stroke, 2.4 * scale, 10)
end

local function indicatorLit(state, animationEnabled)
  if not animationEnabled then return true end

  if type(state.indicatorPhase) == 'boolean' then
    return state.indicatorPhase
  end

  if type(state.indicatorPhase) == 'number' then
    return state.indicatorPhase > 0.5
  end

  return math.floor(state.clock / Layout.indicatorBlinkPeriod) % 2 == 0
end

local function redlinePulseOn(state, settings)
  if not state.rpmRedline then return false end
  if settings == nil or settings.animateRedlineAlert ~= false then
    return math.floor(state.clock / Layout.redlineBlinkPeriod) % 2 == 0
  end
  return true
end

local function redlineColor(state, settings)
  return redlinePulseOn(state, settings) and C.red or C.amber
end

local function rpmScaleStep(maxRpm)
  local maxThousands = maxRpm / 1000
  if maxThousands <= 10 then return 1 end
  if maxThousands <= 20 then return 2 end
  return 5
end

local function rpmGaugeLimiter(state)
  local limiter = math.max(state.rpmDisplayLimiter or 1000, 1000)
  return math.max(state.rpmGaugeLimiter or math.ceil(limiter / 1000) * 1000, 1000)
end

local function rpmArcFraction(state, threshold)
  local limiter = math.max(state.rpmDisplayLimiter or 1000, 1000)
  return U.clamp(limiter * (threshold or 1) / rpmGaugeLimiter(state), 0, 1)
end

local function rpmScaleColor(fraction, state, settings)
  local redlineFraction = rpmArcFraction(state, state.rpmRedlineFraction)
  if fraction >= redlineFraction then
    return state.rpmRedline and redlineColor(state, settings) or C.red
  end

  local shiftZoneStart = math.max(0, math.min(rpmArcFraction(state, state.rpmWarningFraction),
    redlineFraction - Layout.shiftZoneMinimumFraction))
  if fraction >= shiftZoneStart then
    local shiftLit = state.rpmWarning
      and (settings == nil or settings.animateShiftAlert ~= false)
      and math.floor(state.clock / Layout.shiftBlinkPeriod) % 2 == 0
    return state.rpmWarning and shiftLit and C.shiftBlue or C.shiftBlueDim
  end
  return C.primary
end

local function drawRpmScale(center, scale, state, settings, radius, tickInnerOffset,
    tickOuterOffset, labelOffset, fontSize, tickWidth, backlit, neutral, drawTicks, drawLabels)
  local maxRpm = rpmGaugeLimiter(state)
  local maxThousands = maxRpm / 1000
  local step = rpmScaleStep(maxRpm)
  local value = 0

  while value <= maxThousands + 0.001 do
    local fraction = math.min(value / maxThousands, 1)
    local angle = Layout.rpmStart + (Layout.rpmEnd - Layout.rpmStart) * fraction
    local tickInner = U.polar(center, radius * scale - tickInnerOffset * scale, angle)
    local tickOuter = U.polar(center, radius * scale - tickOuterOffset * scale, angle)
    local color = neutral and C.primary or rpmScaleColor(fraction, state, settings)
    if drawTicks ~= false then
      drawLine(tickInner, tickOuter, color, tickWidth * scale)
    end
    local labelPosition = U.polar(center, radius * scale - labelOffset * scale, angle)
    if drawLabels ~= false then
      centeredBacklitText(string.format('%.0f', value), fontSize * scale, labelPosition,
        color, scale, backlit)
    end
    value = value + step
  end
end

local function drawRedlinePulse(center, radius, scale, state, settings)
  if not state.rpmRedline then return end
  local startFraction = rpmArcFraction(state, state.rpmRedlineFraction)
  local endFraction = U.clamp(state.rpmGaugeNormalized or state.rpmNormalized or 0, 0, 1)
  if endFraction <= startFraction then return end
  local span = Layout.rpmEnd - Layout.rpmStart
  drawArc(center, radius,
    Layout.rpmStart + span * startFraction,
    Layout.rpmStart + span * endFraction,
    redlineColor(state, settings), 3 * scale, 24)
end

local function drawAnalogRedlineSegments(center, scale, state, settings)
  local redlineFraction = rpmArcFraction(state, state.rpmRedlineFraction)
  local segmentCount = math.max(2, math.ceil((1 - redlineFraction) * Layout.rpmSegments))
  local firstAngle = Layout.rpmStart + (Layout.rpmEnd - Layout.rpmStart) * redlineFraction
  local segmentSpan = (Layout.rpmEnd - firstAngle) / segmentCount
  local active = U.clamp(state.rpmGaugeNormalized or state.rpmNormalized or 0, 0, 1)
    >= redlineFraction
  local color = active and (state.rpmRedline and redlineColor(state, settings) or C.red) or C.redDim
  local radius = Layout.analogTickRadius * scale
  local innerRadius = radius - InstrumentConfig.dial.segmentDepth * scale
  local gap = InstrumentConfig.dial.segmentGap

  for i = 1, segmentCount do
    local startAngle = firstAngle + (i - 1) * segmentSpan + segmentSpan * gap / 2
    local endAngle = firstAngle + i * segmentSpan - segmentSpan * gap / 2
    ui.pathClear()
    ui.pathLineTo(U.polar(center, radius, startAngle))
    ui.pathLineTo(U.polar(center, radius, endAngle))
    ui.pathLineTo(U.polar(center, innerRadius, endAngle))
    ui.pathLineTo(U.polar(center, innerRadius, startAngle))
    ui.pathFillConvex(color)
  end
end

local function drawRpmArc(center, scale, state, settings)
  local segmentCount = Layout.rpmSegments
  local span = (Layout.rpmEnd - Layout.rpmStart) / segmentCount
  local filled = math.floor((state.rpmGaugeNormalized or state.rpmNormalized) * segmentCount + 0.5)

  local shiftLit = state.rpmWarning
    and (settings == nil or settings.animateShiftAlert ~= false)
    and math.floor(state.clock / Layout.shiftBlinkPeriod) % 2 == 0
  local redlineFraction = rpmArcFraction(state, state.rpmRedlineFraction)
  local shiftZoneStart = math.max(0, math.min(rpmArcFraction(state, state.rpmWarningFraction),
    redlineFraction - Layout.shiftZoneMinimumFraction))

  drawArc(center, Layout.rpmRadius * scale, Layout.rpmStart, Layout.rpmEnd,
    C.outlineDim, Layout.rpmTrackWidth * scale, 72)

  for i = 1, segmentCount do
    local a1 = Layout.rpmStart + (i - 1) * span + 0.012
    local a2 = Layout.rpmStart + i * span - 0.012
    local fraction = i / segmentCount
    local inShiftZone = fraction >= shiftZoneStart and fraction < redlineFraction
    local color = C.inactive
    if i <= filled then
      if fraction >= redlineFraction then
        color = state.rpmRedline and redlineColor(state, settings) or C.red
      elseif inShiftZone then
        color = state.rpmWarning and shiftLit and C.shiftBlue or C.shiftBlueDim
      else
        color = C.primary
      end
    end
    drawArc(center, Layout.rpmRadius * scale, a1, a2, color, Layout.rpmSegmentWidth * scale, 5)
  end

  -- Major marks follow the same RPM limit as the filled arc, not a fixed 0–9
  -- index that becomes incorrect on lower-revving cars.
  drawRpmScale(center, scale, state, settings, Layout.rpmRadius, 18, 8, 38, 22, 2)
end

local function drawAnalogDial(center, scale, state, settings, surface, origin)
  local dialCenter = center + vec2(0, Layout.analogDialOffsetY * scale)
  local dialRadius = Layout.analogDialRadius * scale
  local tickRadius = Layout.analogTickRadius * scale
  local tickCount = Layout.analogMinorTickCount
  local span = Layout.rpmEnd - Layout.rpmStart
  local shiftLit = state.rpmWarning
    and (settings == nil or settings.animateShiftAlert ~= false)
    and math.floor(state.clock / Layout.shiftBlinkPeriod) % 2 == 0
  local redlineFraction = rpmArcFraction(state, state.rpmRedlineFraction)
  local shiftZoneStart = math.max(0, math.min(rpmArcFraction(state, state.rpmWarningFraction),
    redlineFraction - Layout.shiftZoneMinimumFraction))

  ui.drawCircleFilled(dialCenter, dialRadius, surface, 96)
  ui.drawCircle(dialCenter, dialRadius, C.outlineSoft, 96, 1.7 * scale)
  drawArc(dialCenter, tickRadius, Layout.rpmStart, Layout.rpmEnd, C.outlineDim, 2 * scale, 72)
  drawAnalogElectronics(origin, scale, state, settings, surface)
  drawAnalogRedlineSegments(dialCenter, scale, state, settings)

  for i = 0, tickCount do
    local fraction = i / tickCount
    local angle = Layout.rpmStart + span * fraction
    local inShiftZone = fraction >= shiftZoneStart and fraction < redlineFraction
    if fraction < redlineFraction then
      local color = C.secondary
      if inShiftZone then
        color = state.rpmWarning and shiftLit and C.shiftBlue or C.shiftBlueDim
      end
      local length = 7 * scale
      local outer = U.polar(dialCenter, tickRadius, angle)
      local inner = U.polar(dialCenter, tickRadius - length, angle)
      drawLine(inner, outer, color, 1.4 * scale)
    end
  end

  local backlit = state.headlights == true
  -- Draw marks above the blocks; redraw the numbers after the needle so values like 7 stay legible.
  drawRpmScale(dialCenter, scale, state, settings, Layout.analogTickRadius, 15, 0, 31, 22, 2.4,
    backlit, true, true, false)

  local gearCenter = dialCenter + vec2(0, Layout.analogGearOffsetY * scale)
  local gearColor = state.rpmWarning and C.amber or C.primary
  -- Put the gear pod behind the needle so the needle remains continuous
  -- across the pod instead of disappearing underneath it.
  ui.drawCircleFilled(gearCenter, Layout.analogGearPodRadius * scale, C.panelRaised, 32)
  ui.drawCircle(gearCenter, Layout.analogGearPodRadius * scale, C.outlineSoft, 32, 1.6 * scale)
  ui.drawCircle(gearCenter, (Layout.analogGearPodRadius - 5) * scale, C.outlineDim, 32, 1 * scale)

  local needleAngle = Layout.rpmStart + span * state.analogNeedleNormalized
  local needleColor = state.rpmWarning and C.amber or nil
  local style = InstrumentConfig.normalizeNeedleStyle(settings.analogNeedleStyle, 'a01')
  local preset = InstrumentConfig.needlePreset(style)
  Needle.draw(dialCenter, scale * Layout.analogNeedleLength / preset.length,
    needleAngle, preset, C, backlit and 1 or 0, needleColor)
  drawRpmScale(dialCenter, scale, state, settings, Layout.analogTickRadius, 15, 0, 31, 22, 2.4,
    backlit, true, false, true)

  centeredBacklitText(state.gearText, Layout.analogGearFontSize * scale, gearCenter,
    gearColor, scale, backlit)
  centeredBacklitText(state.speedText, Layout.analogSpeedFontSize * scale,
    dialCenter + vec2(0, Layout.analogSpeedOffsetY * scale), C.primary, scale, backlit)
end

local function drawAnalogAuxiliary(center, origin, scale, state, settings)
  local requestedMode = settings.analogAuxiliaryMode or 'auto'
  if requestedMode == 'off' then return end

  local hybrid = Hybrid.forGauge(state, requestedMode)
  if hybrid then
    HybridGauge.draw(center, scale, hybrid, C, settings.theme, state.headlights and 1 or 0, 'standalone')
    return
  end
  if requestedMode == 'electric' then
    centeredText('ERS N/A', 13 * scale,
      point(origin, scale, Layout.centerX, Layout.analogAuxLabelY), C.secondary)
    return
  end

  local useTurbo = requestedMode == 'turbo' or (requestedMode == 'auto' and state.turboAvailable)
  local available = useTurbo and state.turboAvailable or state.fuel ~= nil and state.maxFuel ~= nil
  local label = useTurbo and 'TURBO' or 'FUEL'
  local value = 'N/A'
  local normalized = 0
  local accent = C.secondary
  if useTurbo and state.turboAvailable then
    value = string.format('%.2f BAR', state.turboBoost)
    normalized = U.clamp(state.turboBoost / state.turboDisplayMax, 0, 1)
    accent = C.cyan
  elseif not useTurbo and available then
    value = string.format('%.0f L', state.fuel)
    normalized = state.fuelNormalized
    accent = normalized < 0.15 and C.red or C.primary
  end

  local radius = Layout.analogAuxArcRadius * scale
  local span = (Layout.analogAuxArcEnd - Layout.analogAuxArcStart) / Layout.analogAuxSegments
  local filled = math.floor(normalized * Layout.analogAuxSegments + 0.5)
  drawArc(center, radius, Layout.analogAuxArcStart, Layout.analogAuxArcEnd,
    C.outlineDim, (Layout.analogAuxArcWidth + 4) * scale, 32)
  for i = 1, Layout.analogAuxSegments do
    local startAngle = Layout.analogAuxArcStart + (i - 1) * span + 0.012
    local endAngle = Layout.analogAuxArcStart + i * span - 0.012
    drawArc(center, radius, startAngle, endAngle,
      i <= filled and accent or C.inactive, Layout.analogAuxArcWidth * scale, 5)
  end

  local backlit = state.headlights == true
  centeredBacklitText(label, 11 * scale,
    point(origin, scale, Layout.centerX - 66, Layout.analogAuxLabelY), C.secondary, scale, backlit)
  centeredBacklitText(value, 13 * scale,
    point(origin, scale, Layout.centerX + 52, Layout.analogAuxLabelY), accent, scale, backlit)
end

local function flagColor(state)
  local flag = state.raceFlagType
  if type(flag) ~= 'number' or flag == 0 then return nil end

  -- ac.FlagType values: Caution=2, Stop=5, ReturnToPits=8,
  -- FasterCar=12, Finished=13 and OneLapLeft=14.
  if flag == 2 then return C.flagYellow end
  if flag == 5 or flag == 8 then return C.red end
  if flag == 12 then return C.shiftBlue end
  if flag == 13 or flag == 14 then return C.primary end
  return nil
end

local function flagBlinkOn(state, settings)
  if settings == nil or settings.animateFlagAlert ~= false then
    return math.floor(state.clock / Layout.indicatorBlinkPeriod) % 2 == 0
  end
  return true
end

local function digitalRpmBezelFraction(state)
  return U.clamp(state.rpmNormalized or 0, 0, 1)
end

local function digitalRpmBezelColor(state)
  local fraction = digitalRpmBezelFraction(state)
  local warningFraction = state.rpmWarningFraction or 0.86
  local redlineFraction = state.rpmRedlineFraction or 0.96

  if fraction >= redlineFraction then return C.red end
  if fraction >= warningFraction then return C.shiftBlue end
  return C.flagYellow
end

local function digitalRpmBezelActive(state)
  return state.available == true
    and digitalRpmBezelFraction(state) >= Layout.digitalRpmAlertStartFraction
end

local function digitalRpmBezelLit(state, settings)
  if not digitalRpmBezelActive(state) then return false end

  local fraction = digitalRpmBezelFraction(state)
  local warningFraction = state.rpmWarningFraction or 0.86
  local redlineFraction = state.rpmRedlineFraction or 0.96
  if fraction >= redlineFraction then
    return redlinePulseOn(state, settings)
  end
  if fraction >= warningFraction then
    if settings == nil or settings.animateShiftAlert ~= false then
      return math.floor(state.clock / Layout.indicatorBlinkPeriod) % 2 == 0
    end
  end
  return true
end

local function drawAnalogStatusIcon(center, scale, kind, color, backlit)
  local iconColor = color

  if kind == 'lights' then
    ui.drawRectFilled(center + vec2(-7 * scale, -5 * scale),
      center + vec2(-3 * scale, 5 * scale), iconColor)
    for i = -1, 1 do
      drawLine(center + vec2(-1 * scale, i * 4 * scale),
        center + vec2(8 * scale, i * 5 * scale), iconColor, 1.2 * scale)
    end
  elseif kind == 'flag' then
    drawLine(center + vec2(-6 * scale, -8 * scale),
      center + vec2(-6 * scale, 8 * scale), iconColor, 1.4 * scale)
    ui.pathClear()
    ui.pathLineTo(center + vec2(-4 * scale, -7 * scale))
    ui.pathLineTo(center + vec2(7 * scale, -4 * scale))
    ui.pathLineTo(center + vec2(-4 * scale, 0))
    ui.pathFillConvex(iconColor)
  elseif kind == 'abs' then
    centeredBacklitText('ABS', 7 * scale, center, iconColor, scale, backlit)
  elseif kind == 'tc' then
    centeredBacklitText('TC', 9 * scale, center, iconColor, scale, backlit)
  else
    centeredBacklitText('P', 11 * scale, center, iconColor, scale, backlit)
  end
end

local function drawAnalogStatusPod(origin, scale, x, y, kind, available, active, accent, backlit)
  local center = point(origin, scale, x, y)
  local radius = Layout.analogStatusPodRadius * scale
  local stroke = active and accent or (available and C.outlineSoft or C.outlineDim)
  local fill = active and Theme.withAlpha(accent, 0.20) or C.panelRaised
  local iconColor = active and accent or (available and C.secondary or C.outlineDim)

  ui.drawCircleFilled(center, radius, fill, 32)
  ui.drawCircle(center, radius, stroke, 32, (active and 2.1 or 1.4) * scale)
  ui.drawCircle(center, (Layout.analogStatusPodRadius - 5) * scale, C.outlineDim, 32, 1 * scale)
  if active then
    ui.drawCircleFilled(center, (radius - 7 * scale), Theme.withAlpha(accent, 0.12), 28)
  end
  drawAnalogStatusIcon(center, scale, kind, iconColor, backlit)
end

local function drawAnalogFlagPod(origin, scale, state, dialSurface)
  local center = point(origin, scale, Layout.analogFlagX, Layout.analogFlagY)
  local color = flagColor(state)
  local active = color ~= nil
  local halfSize = Layout.analogFlagPodHalfSize * scale
  local chamfer = Layout.analogFlagPodChamfer * scale
  local glowSpread = Layout.analogFlagGlowSpread * scale

  if active then
    -- Layered chamfered squares make the flag light read as a focused glow
    -- without putting it back onto the outer bezel.
    drawOctagon(center, halfSize + glowSpread, halfSize + glowSpread,
      chamfer + 2 * scale, Theme.withAlpha(color, 0.10),
      Theme.withAlpha(color, 0.22), 2 * scale)
    drawOctagon(center, halfSize + 4 * scale, halfSize + 4 * scale,
      chamfer + scale, Theme.withAlpha(color, 0.18),
      Theme.withAlpha(color, 0.54), 2.2 * scale)
    drawOctagon(center, halfSize, halfSize, chamfer,
      Theme.withAlpha(color, 0.78), color, 2.6 * scale)
  else
    drawOctagon(center, halfSize, halfSize, chamfer, dialSurface, C.outlineDim, 1.4 * scale)
  end

  drawAnalogStatusIcon(center, scale, 'flag', active and C.void or C.outlineDim, false)
end

drawAnalogElectronics = function(origin, scale, state, settings, dialSurface)
  local backlit = state.headlights == true
  local x = Layout.analogElectronicsX
  local y = Layout.analogElectronicsFirstY
  local spacingX = Layout.analogElectronicsSpacingX
  local spacingY = Layout.analogElectronicsSpacingY
  local lightsAvailable = settings.showLights ~= false and state.lightsAvailable
  local lightsActive = lightsAvailable and state.headlights == true
  local lightsColor = state.highBeams and C.amber or C.cyan

  -- Analog mode keeps electronics compact and icon-only: no TC/ABS level numbers.
  drawAnalogStatusPod(origin, scale, x, y, 'tc', state.tcSupported, state.tcActive == true,
    C.amber, backlit)
  drawAnalogStatusPod(origin, scale, x + spacingX, y, 'abs', state.absSupported, state.absActive == true,
    C.amber, backlit)
  drawAnalogStatusPod(origin, scale, x, y + spacingY, 'lights', lightsAvailable, lightsActive,
    lightsColor, backlit)
  drawAnalogStatusPod(origin, scale, x + spacingX, y + spacingY, 'pit',
    state.pitLimiter ~= nil or state.pitLane,
    state.pitLimiter == true or state.pitLane, C.amber, backlit)

  drawAnalogFlagPod(origin, scale, state, dialSurface)
end

local function drawSpeedBrackets(origin, scale)
  local y = Layout.speedUnitY + 18
  local leftStart = point(origin, scale, Layout.centerX - 108, y)
  local leftEnd = point(origin, scale, Layout.centerX - 62, y)
  local rightStart = point(origin, scale, Layout.centerX + 62, y)
  local rightEnd = point(origin, scale, Layout.centerX + 108, y)
  drawLine(leftStart, leftEnd, C.cyanDim, 2.2 * scale)
  drawLine(rightStart, rightEnd, C.cyanDim, 2.2 * scale)
  drawLine(leftEnd - vec2(8 * scale, 0), leftEnd, C.cyan, 1.3 * scale)
  drawLine(rightStart, rightStart + vec2(8 * scale, 0), C.cyan, 1.3 * scale)
end

local function drawSteering(center, origin, scale, state)
  if not state.showSteering then return end

  local y = point(origin, scale, Layout.centerX, Layout.steeringY).y
  local left = point(origin, scale, Layout.centerX - Layout.steeringHalfWidth, Layout.steeringY)
  local right = point(origin, scale, Layout.centerX + Layout.steeringHalfWidth, Layout.steeringY)
  drawLine(left, right, C.outlineSoft, 3 * scale)
  drawLine(point(origin, scale, Layout.centerX, Layout.steeringY - 8),
    point(origin, scale, Layout.centerX, Layout.steeringY + 8), C.primary, 2 * scale)

  local markerX = Layout.centerX + state.steeringInput * Layout.steeringHalfWidth
  ui.drawCircleFilled(point(origin, scale, markerX, Layout.steeringY), 5 * scale,
    math.abs(state.steeringInput) > 0.04 and C.cyan or C.primary, 18)

  local steeringLabel = state.steeringAngle and string.format('%+03d°', U.round(state.steeringAngle)) or 'INPUT'
  centeredText(steeringLabel, 9 * scale, point(origin, scale, Layout.centerX, Layout.steeringY + 15), C.secondary)
end

local function drawPedalBar(origin, scale, x, label, value, color, labelColor, inactiveColor,
    panelColor, alertColor, alertLit)
  local y = Layout.pedalY
  local width = Layout.pedalWidth
  local height = Layout.pedalHeight
  local segmentCount = 12
  local gap = 3 * scale
  local segmentHeight = (height * scale - gap * (segmentCount - 1)) / segmentCount
  local filled = math.floor(value * segmentCount + 0.5)

  local housingLeft = (x - 14) * scale
  local housingRight = (x + width + 14) * scale
  local housingTop = (y - 38) * scale
  local housingBottom = (y + height + 17) * scale
  local chamfer = 10 * scale
  local housingAlertActive = alertColor ~= nil and alertLit == true
  local housingFill = housingAlertActive and Theme.withAlpha(alertColor, 0.18) or panelColor
  local housingStroke = housingAlertActive and alertColor or C.outlineSoft

  ui.pathClear()
  ui.pathLineTo(origin + vec2(housingLeft + chamfer, housingTop))
  ui.pathLineTo(origin + vec2(housingRight - chamfer, housingTop))
  ui.pathLineTo(origin + vec2(housingRight, housingTop + chamfer))
  ui.pathLineTo(origin + vec2(housingRight, housingBottom - chamfer))
  ui.pathLineTo(origin + vec2(housingRight - chamfer, housingBottom))
  ui.pathLineTo(origin + vec2(housingLeft + chamfer, housingBottom))
  ui.pathLineTo(origin + vec2(housingLeft, housingBottom - chamfer))
  ui.pathLineTo(origin + vec2(housingLeft, housingTop + chamfer))
  ui.pathFillConvex(housingFill)

  ui.pathClear()
  ui.pathLineTo(origin + vec2(housingLeft + chamfer, housingTop))
  ui.pathLineTo(origin + vec2(housingRight - chamfer, housingTop))
  ui.pathLineTo(origin + vec2(housingRight, housingTop + chamfer))
  ui.pathLineTo(origin + vec2(housingRight, housingBottom - chamfer))
  ui.pathLineTo(origin + vec2(housingRight - chamfer, housingBottom))
  ui.pathLineTo(origin + vec2(housingLeft + chamfer, housingBottom))
  ui.pathLineTo(origin + vec2(housingLeft, housingBottom - chamfer))
  ui.pathLineTo(origin + vec2(housingLeft, housingTop + chamfer))
  if housingAlertActive then
    ui.pathStroke(Theme.withAlpha(alertColor, 0.24), true, 5 * scale)
  end
  ui.pathStroke(housingStroke, true, (housingAlertActive and 2.3 or 1.4) * scale)

  if label then
    centeredText(label, 12 * scale, point(origin, scale, x + width / 2, y - 16), labelColor)
  end
  for i = 1, segmentCount do
    local segmentY = y * scale + (segmentCount - i) * (segmentHeight + gap)
    local topLeft = origin + vec2(x * scale, segmentY)
    local bottomRight = topLeft + vec2(width * scale, segmentHeight)
    ui.drawRectFilled(topLeft, bottomRight, i <= filled and color or inactiveColor)
  end

  local tl = point(origin, scale, x, y)
  local tr = point(origin, scale, x + width, y)
  local br = point(origin, scale, x + width, y + height)
  local bl = point(origin, scale, x, y + height)
  drawLine(tl, tr, C.outlineSoft, 1.5 * scale)
  drawLine(tr, br, C.outlineSoft, 1.5 * scale)
  drawLine(br, bl, C.outlineSoft, 1.5 * scale)
  drawLine(bl, tl, C.outlineSoft, 1.5 * scale)
end

local function drawElectronicsShelf(origin, scale, panelColor)
  local cx = Layout.centerX * scale
  local top = Layout.shelfTopY * scale
  local bottom = Layout.shelfBottomY * scale
  local topHalf = Layout.shelfTopHalfWidth * scale
  local bottomHalf = Layout.shelfBottomHalfWidth * scale
  local notch = 10 * scale

  ui.pathClear()
  ui.pathLineTo(origin + vec2(cx - topHalf + notch, top))
  ui.pathLineTo(origin + vec2(cx + topHalf - notch, top))
  ui.pathLineTo(origin + vec2(cx + topHalf, top + notch))
  ui.pathLineTo(origin + vec2(cx + bottomHalf, bottom))
  ui.pathLineTo(origin + vec2(cx - bottomHalf, bottom))
  ui.pathLineTo(origin + vec2(cx - topHalf, top + notch))
  ui.pathFillConvex(panelColor)

  ui.pathClear()
  ui.pathLineTo(origin + vec2(cx - topHalf + notch, top))
  ui.pathLineTo(origin + vec2(cx + topHalf - notch, top))
  ui.pathLineTo(origin + vec2(cx + topHalf, top + notch))
  ui.pathLineTo(origin + vec2(cx + bottomHalf, bottom))
  ui.pathLineTo(origin + vec2(cx - bottomHalf, bottom))
  ui.pathLineTo(origin + vec2(cx - topHalf, top + notch))
  ui.pathStroke(C.outlineDim, true, 1.5 * scale)
end

local function drawClutch(origin, scale, state)
  centeredText('CLUTCH', 10 * scale, point(origin, scale, Layout.centerX, Layout.clutchLabelY), C.secondary)
  local tl = point(origin, scale, Layout.clutchX, Layout.clutchY)
  local br = tl + vec2(Layout.clutchWidth * scale, Layout.clutchHeight * scale)
  ui.drawRectFilled(tl, br, C.inactive)
  ui.drawRectFilled(tl, tl + vec2(Layout.clutchWidth * scale * state.clutch, Layout.clutchHeight * scale), C.cyan)
end

local function drawHeadlightIcon(center, scale, state)
  local color = state.headlights and (state.highBeams and C.amber or C.cyan) or C.secondary
  ui.drawRectFilled(center - vec2(6 * scale, 8 * scale), center + vec2(1 * scale, 8 * scale), color)
  for i = -1, 1 do
    drawLine(center + vec2(6 * scale, i * 5 * scale), center + vec2(21 * scale, i * 8 * scale), color, 2 * scale)
  end
end

local function drawCell(origin, scale, x, label, value, active, valueColor, drawIcon, panel, panelRaised)
  local y = Layout.electronicsY
  local w = Layout.electronicsWidth
  local h = Layout.electronicsHeight
  local center = point(origin, scale, x + w / 2, y + h / 2)
  local left = x * scale
  local top = y * scale
  local right = (x + w) * scale
  local bottom = (y + h) * scale
  local chamfer = 6 * scale

  ui.pathClear()
  ui.pathLineTo(origin + vec2(left + chamfer, top))
  ui.pathLineTo(origin + vec2(right - chamfer, top))
  ui.pathLineTo(origin + vec2(right, top + chamfer))
  ui.pathLineTo(origin + vec2(right, bottom - chamfer))
  ui.pathLineTo(origin + vec2(right - chamfer, bottom))
  ui.pathLineTo(origin + vec2(left + chamfer, bottom))
  ui.pathLineTo(origin + vec2(left, bottom - chamfer))
  ui.pathLineTo(origin + vec2(left, top + chamfer))
  ui.pathFillConvex(active and panelRaised or panel)

  ui.pathClear()
  ui.pathLineTo(origin + vec2(left + chamfer, top))
  ui.pathLineTo(origin + vec2(right - chamfer, top))
  ui.pathLineTo(origin + vec2(right, top + chamfer))
  ui.pathLineTo(origin + vec2(right, bottom - chamfer))
  ui.pathLineTo(origin + vec2(right - chamfer, bottom))
  ui.pathLineTo(origin + vec2(left + chamfer, bottom))
  ui.pathLineTo(origin + vec2(left, bottom - chamfer))
  ui.pathLineTo(origin + vec2(left, top + chamfer))
  ui.pathStroke(active and C.cyan or C.outlineSoft, true, (active and 2.2 or 1.4) * scale)

  centeredText(label, 10 * scale, point(origin, scale, x + w / 2, y + 15), active and C.primary or C.secondary)
  if drawIcon then
    drawIcon(center + vec2(0, 11 * scale), scale)
  else
    centeredText(value, 25 * scale, point(origin, scale, x + w / 2, y + 42), valueColor or C.primary)
  end
end

local function drawWarningBezelCut(center, scale, state, backdrop)
  drawBezelArcCut(center, Layout.bezelCutRadius * scale, math.pi / 2,
    Layout.warningArcSpan, scale, state.handbrake > 0.9, backdrop, C.amberDim, C.amber)
end

local function drawDigitalRpmBezelCut(center, scale, state, settings, backdrop)
  local active = digitalRpmBezelLit(state, settings)
  local color = digitalRpmBezelColor(state)
  local fill = Theme.withAlpha(color, 0.92)
  drawBezelArcCut(center, Layout.bezelCutRadius * scale, math.pi / 2,
    Layout.turnIndicatorArcSpan, scale, active, backdrop, fill, color)
end

local function drawScrews(center, scale)
  local left = U.polar(center, 240 * scale, math.rad(143))
  local right = U.polar(center, 240 * scale, math.rad(37))
  local function drawScrew(screw)
    ui.drawCircleFilled(screw, 7 * scale, C.panelRaised, 24)
    ui.drawCircle(screw, 7 * scale, C.outlineSoft, 24, 1.2 * scale)
    drawLine(screw - vec2(2 * scale, 2 * scale), screw + vec2(2 * scale, 2 * scale), C.outline, 1.4 * scale)
  end
  drawScrew(left)
  drawScrew(right)
end

local function drawDebug(origin, scale, state)
  local x = 14 * scale
  local y = 14 * scale
  local w = 230 * scale
  local h = 156 * scale
  ui.drawRectFilled(origin + vec2(x, y), origin + vec2(x + w, y + h), C.debug)
  local rows = {
    string.format('SPD  %s %s', state.speedText, state.speedUnit),
    string.format('GEAR %s   RPM %s', state.gearText, state.rpmText),
    string.format('LIM  %s (%s)', state.rpmLimiter and string.format('%.0f', state.rpmLimiter) or 'n/a', state.rpmSource),
    string.format('STR  %+.2f  %s', state.steeringInput, state.steeringAngle and string.format('%+.0f°', state.steeringAngle) or 'n/a'),
    string.format('PED  T %.2f  B %.2f  C %.2f', state.throttle, state.brake, state.clutch),
    string.format('TC   %s / %s', state.tcLevel and tostring(state.tcLevel) or 'n/a', U.boolText(state.tcActive)),
    string.format('ABS  %s / %s', state.absLevel and tostring(state.absLevel) or 'n/a', U.boolText(state.absActive)),
    string.format('LGT  %s  PIT %s', U.boolText(state.headlights), U.boolText(state.pitLimiter))
  }
  for i, row in ipairs(rows) do
    ui.dwriteDrawText(row, 10 * scale, origin + vec2(x + 9 * scale, y + (i - 1) * 17 * scale + 6 * scale), C.primary)
  end
end

function M.draw(state, settings)
  C = GeneralSettings.palette(Theme.get(settings.theme), settings.backgroundOpacity)

  local width = ui.windowWidth()
  local height = ui.windowHeight()
  local fittedScale = math.min(width, height) / Layout.baseSize
  local scale = fittedScale * settings.hudScale
  local designSize = Layout.baseSize * scale
  local origin = vec2((width - designSize) / 2,
    (height - designSize) / 2 + Layout.viewportOffsetY * scale)
  local center = point(origin, scale, Layout.centerX, Layout.centerY)
  local backdropOpacity = 0.72 -- Authored reference; palette applies global background opacity.
  local outerSurface = Theme.withAlpha(C.void, backdropOpacity * 0.82)
  local innerSurface = Theme.withAlpha(C.surface, backdropOpacity)
  local coreSurface = Theme.withAlpha(C.panel, math.min(0.92, backdropOpacity + 0.16))
  local raisedSurface = Theme.withAlpha(C.panelRaised, math.min(0.94, backdropOpacity + 0.22))
  local inactiveSurface = Theme.withAlpha(C.inactive, backdropOpacity * 0.8)

  ui.pushStyleVarAlpha(settings.opacity)
  ui.pushDWriteFont(Theme.fonts.utility)

  ui.drawCircleFilled(center, Layout.outerRadius * scale, outerSurface, 96)
  ui.drawCircleFilled(center, Layout.innerRadius * scale, innerSurface, 96)
  ui.drawCircle(center, Layout.outerRadius * scale, C.metal, 96, 3 * scale)
  ui.drawCircle(center, (Layout.outerRadius - 7) * scale, C.metalDim, 96, 3 * scale)
  ui.drawCircle(center, (Layout.outerRadius - 15) * scale, C.outlineDim, 96, 5 * scale)
  ui.drawCircle(center, (Layout.outerRadius - 22) * scale, C.metalDim, 96, 2 * scale)
  ui.drawCircle(center, Layout.innerRadius * scale, C.outline, 96, 1.5 * scale)

  local analogMode = settings.instrumentMode == 'analog'
  if not analogMode then
    drawRpmArc(center, scale, state, settings)
    drawRedlinePulse(center, Layout.rpmRadius * scale, scale, state, settings)
  end

  local leftCutAngle = math.pi - Layout.turnIndicatorAngle
  local rightCutAngle = Layout.turnIndicatorAngle
  local blinkOn = indicatorLit(state, settings.animateIndicators ~= false)
  local leftActive = (state.hazardLights or state.leftIndicator) and blinkOn
  local rightActive = (state.hazardLights or state.rightIndicator) and blinkOn
  drawBezelArcCut(center, Layout.bezelCutRadius * scale, leftCutAngle,
    Layout.turnIndicatorArcSpan, scale, leftActive == true, outerSurface)
  drawBezelArcCut(center, Layout.bezelCutRadius * scale, rightCutAngle,
    Layout.turnIndicatorArcSpan, scale, rightActive == true, outerSurface)

  if analogMode then
    drawAnalogDial(center, scale, state, settings, coreSurface, origin)
    drawAnalogAuxiliary(center, origin, scale, state, settings)
  else
    local coreAlertSurface = coreSurface
    local coreAlertBorder = C.cyanDim
    if state.rpmRedline then
      coreAlertSurface = Theme.withAlpha(C.coreRed, math.min(0.94, backdropOpacity + 0.18))
      coreAlertBorder = redlineColor(state, settings)
    elseif state.rpmWarning then
      coreAlertSurface = Theme.withAlpha(C.coreAmber, math.min(0.94, backdropOpacity + 0.18))
      coreAlertBorder = C.amber
    end
    drawOctagon(center, Layout.coreFrameHalfWidth * scale, Layout.coreFrameHalfHeight * scale,
      Layout.coreFrameChamfer * scale, Theme.withAlpha(C.panel, backdropOpacity * 0.24), C.outlineSoft, 1.4 * scale)
    drawOctagon(center + vec2(0, Layout.coreOffsetY * scale), Layout.coreHalfWidth * scale,
      Layout.coreHalfHeight * scale, Layout.coreChamfer * scale, coreAlertSurface, coreAlertBorder, 2 * scale)
    drawSteering(center, origin, scale, {
      showSteering = settings.showSteering,
      steeringInput = state.steeringInput,
      steeringAngle = state.steeringAngle
    })

    local digitalFlagColor = flagColor(state)
    local digitalFlagLit = digitalFlagColor and flagBlinkOn(state, settings)
    local pedalPanel = Theme.withAlpha(C.panel, backdropOpacity * 0.62)
    drawPedalBar(origin, scale, Layout.brakeX, nil, state.brake, C.red, C.primary,
      inactiveSurface, pedalPanel, digitalFlagColor, digitalFlagLit)
    drawPedalBar(origin, scale, Layout.throttleX, nil, state.throttle, C.cyan, C.primary,
      inactiveSurface, pedalPanel, digitalFlagColor, digitalFlagLit)

    centeredText(state.speedText, 42 * scale, point(origin, scale, Layout.centerX, Layout.speedY), C.primary)
    centeredText(state.speedUnit, 14 * scale, point(origin, scale, Layout.centerX, Layout.speedUnitY), C.secondary)
    drawSpeedBrackets(origin, scale)
    local digitalAlertColor = state.rpmRedline and redlineColor(state, settings)
      or (state.rpmWarning and C.amber or C.primary)
    centeredText(state.gearText, Layout.gearFontSize * scale, point(origin, scale, Layout.centerX, Layout.gearY), digitalAlertColor)
    local digitalRpmColor = state.rpmRedline and digitalAlertColor
      or (state.rpmWarning and C.amber or C.primary)
    local digitalFlagColor = flagColor(state)
    if digitalFlagColor then
      digitalRpmColor = flagBlinkOn(state, settings)
        and digitalFlagColor or Theme.withAlpha(digitalFlagColor, 0.22)
    end
    centeredText(state.rpmText, 39 * scale, point(origin, scale, Layout.centerX, Layout.rpmY),
      digitalRpmColor)
    centeredText('RPM', 13 * scale, point(origin, scale, Layout.centerX, Layout.rpmLabelY), C.secondary)

    drawElectronicsShelf(origin, scale, Theme.withAlpha(C.panelRaised, backdropOpacity * 0.72))

    if settings.showClutch then drawClutch(origin, scale, state) end

    local cellX = Layout.electronicsX
    local tcValue = state.tcLevel and (settings.showTcAbsLevels and tostring(state.tcLevel) or 'ON') or '—'
    local absValue = state.absLevel and (settings.showTcAbsLevels and tostring(state.tcLevel) or 'ON') or '—'
    drawCell(origin, scale, cellX, 'TC', tcValue, state.tcActive == true, state.tcActive and C.amber or C.primary,
      nil, coreSurface, raisedSurface)
    cellX = cellX + Layout.electronicsWidth + Layout.electronicsGap
    drawCell(origin, scale, cellX, 'ABS', absValue, state.absActive == true, state.absActive and C.amber or C.primary,
      nil, coreSurface, raisedSurface)
    cellX = cellX + Layout.electronicsWidth + Layout.electronicsGap
    local lightsShown = settings.showLights and state.lightsAvailable
    drawCell(origin, scale, cellX, 'LIGHTS', lightsShown and 'ON' or '—', lightsShown and state.headlights == true,
      state.highBeams and C.amber or C.cyan, lightsShown and function(centerPosition, iconScale)
        drawHeadlightIcon(centerPosition, iconScale, state)
      end or nil, coreSurface, raisedSurface)
    cellX = cellX + Layout.electronicsWidth + Layout.electronicsGap
    local pitValue = state.pitLimiter ~= nil and (state.pitLimiter and 'ON' or '—') or (state.pitLane and 'P' or '—')
    drawCell(origin, scale, cellX, 'PIT', pitValue, state.pitLimiter == true or state.pitLane,
      state.pitLimiter and C.amber or C.primary, nil, coreSurface, raisedSurface)
  end

  if analogMode then
    drawWarningBezelCut(center, scale, state, outerSurface)
  else
    drawDigitalRpmBezelCut(center, scale, state, settings, outerSurface)
  end
  drawScrews(center, scale)

  if settings.debug then drawDebug(origin, scale, state) end

  ui.popDWriteFont()
  ui.popStyleVar(1)
end

return M
