local Theme = require('modules/timing/src/theme')
local TimingUI = require('modules/timing/src/ui')

local Display = {}
local FONT = Theme.fonts.utility
local CARBON_OUTLINE = rgbm(0x13 / 255, 0x10 / 255, 0x0D / 255, 1)
local CREAM_OUTLINE = rgbm(0xF2 / 255, 0xDB / 255, 0xAE / 255, 1)

local OUTLINE_OFFSETS = {
  vec2(-1, 0), vec2(1, 0), vec2(0, -1), vec2(0, 1),
  vec2(-0.7, -0.7), vec2(0.7, -0.7), vec2(-0.7, 0.7), vec2(0.7, 0.7)
}

local function linearChannel(value)
  if value <= 0.04045 then return value / 12.92 end
  return ((value + 0.055) / 1.055) ^ 2.4
end

local function outlineFor(color)
  local luminance = linearChannel(color.r) * 0.2126
    + linearChannel(color.g) * 0.7152 + linearChannel(color.b) * 0.0722
  return luminance < 0.36 and CREAM_OUTLINE or CARBON_OUTLINE
end

local function drawOutlinedText(text, size, center, color, scale)
  text = tostring(text)
  local measured = ui.measureDWriteText(text, size)
  -- Consolas digits occupy less than the measured line box. Centre their ink,
  -- including the outline, instead of leaving the time visually above centre.
  local position = center - measured / 2 + vec2(0, size * 0.15)
  local spread = math.max(0.75, scale)
  local outline = outlineFor(color)
  for _, offset in ipairs(OUTLINE_OFFSETS) do
    ui.dwriteDrawText(text, size, position + offset * spread, outline)
  end
  ui.dwriteDrawText(text, size, position, color)
end

local function drawBadge(tl, width, height, label, fill, stroke, textColor, scale, textSize, outlineValue)
  TimingUI.chamferRect(tl, tl + vec2(width, height), 8 * scale, fill, stroke, 1.1 * scale)
  local size = (textSize or 10) * scale
  local measured = ui.measureDWriteText(label, size)
  size = size * math.min(1, (width - 10 * scale) / math.max(1, measured.x),
    (height - 8 * scale) / math.max(1, measured.y))
  local center = tl + vec2(width / 2, height / 2)
  if outlineValue then drawOutlinedText(label, size, center, textColor, scale)
  else TimingUI.centeredText(label, size, center + vec2(0, size * 0.15), textColor) end
end

local function withBackgroundOpacity(color, opacity)
  return Theme.withAlpha(color, (tonumber(color.mult) or 1) * opacity)
end

function Display.draw(snapshot, settings, visual)
  local colors = visual.palette
  local backgroundOpacity = math.max(0, math.min(1, tonumber(settings.backgroundOpacity) or 0.70))
  local width, height = ui.windowWidth(), ui.windowHeight()
  local scale = math.max(0.35, math.min(settings.scale or 1, width / 480, height / 94))
  local contentTop = 5 * scale
  local result = snapshot.result
  local showBest = result and result.valid ~= false and result.status == 'session_best'
  local bestWidth = 64 * scale
  local deltaWidth = 88 * scale
  local gap = 5 * scale
  local timerTop = contentTop + 6 * scale
  local resultBadgeHeight = 24 * scale
  local timerHeight = height - timerTop - resultBadgeHeight - gap - 2 * scale
  local timerTL = vec2(6 * scale + bestWidth + gap, timerTop)
  local timerBR = vec2(width - 6 * scale - deltaWidth - gap, timerTop + timerHeight)
  local timerWidth = timerBR.x - timerTL.x

  ui.pushStyleVarAlpha(visual.instrumentOpacity or 1)
  ui.pushDWriteFont(FONT)

  if snapshot.finalLap then
    local badgeWidth = width - 12 * scale
    local badgeTL = vec2(6 * scale, timerBR.y + gap)
    drawBadge(badgeTL, badgeWidth, resultBadgeHeight, 'FINAL LAP',
      withBackgroundOpacity(colors.redDim, backgroundOpacity),
      withBackgroundOpacity(colors.red, backgroundOpacity), colors.primary, scale, 15)
  end

  local time = result and result.time or snapshot.currentLapTime
  local invalidLap = result and (result.valid == false or result.status == 'invalid') or snapshot.invalid == true
  local timeColor = invalidLap and colors.primary
    or (result and TimingUI.statusColor(colors, result.status) or colors.primary)

  TimingUI.chamferRect(timerTL, timerBR, 8 * scale,
    withBackgroundOpacity(colors.panelRaised, backgroundOpacity),
    withBackgroundOpacity(colors.outlineSoft, backgroundOpacity), 1.1 * scale)
  local timeText = TimingUI.formatTime(time)
  local timeSize = timerHeight
  local pitPadding = snapshot.inPits and 18 * scale or 0
  -- Measure a fixed envelope, so sectors, laps and result badges never resize the clock.
  local measured = ui.measureDWriteText('88:88.888', timeSize)
  local hasInvalidMarker = invalidLap and timeText:find('%d') ~= nil
  local markerReserve = ui.measureDWriteText('*', timeSize * 0.34).x + 3 * scale
  timeSize = timeSize * math.min(1, (timerWidth - 34 * scale - markerReserve) / math.max(1, measured.x),
    (timerHeight - 8 * scale) / math.max(1, measured.y))
  local textMeasured = ui.measureDWriteText(timeText, timeSize)
  local actualMarkerReserve = hasInvalidMarker
    and (ui.measureDWriteText('*', timeSize * 0.34).x + 3 * scale) or 0
  local timeCenter = vec2((timerTL.x + timerBR.x + pitPadding) / 2 - actualMarkerReserve / 2,
    timerTop + timerHeight / 2)
  local resultAge = result and math.max(0, (snapshot.clock or result.createdAt or 0) - (result.createdAt or 0)) or 0
  local flash = result and math.floor(resultAge / 0.25) % 2 ~= 0
  ui.pushStyleVarAlpha(flash and 0.25 or 1)
  drawOutlinedText(timeText, timeSize, timeCenter, timeColor, scale)
  if hasInvalidMarker then
    local markerSize = timeSize * 0.34
    local markerMeasured = ui.measureDWriteText('*', markerSize)
    local markerCenter = vec2(timeCenter.x + textMeasured.x / 2 + markerMeasured.x / 2 + 2 * scale,
      timeCenter.y - textMeasured.y / 2 + markerMeasured.y / 2 * 0.7)
    drawOutlinedText('*', markerSize, markerCenter, timeColor, scale)
  end
  ui.popStyleVar(1)

  if result then
    local badgeTop = timerTop
    if showBest then
      drawBadge(vec2(6 * scale, badgeTop), bestWidth, timerHeight, 'BEST',
        withBackgroundOpacity(colors.purpleDim, backgroundOpacity),
        withBackgroundOpacity(colors.purple, backgroundOpacity), colors.purple, scale, 26)
    end
    local deltaStatus = (result.valid == false or result.status == 'invalid') and 'invalid'
      or (result.delta ~= nil and result.delta < 0 and 'session_best') or 'slower'
    local deltaColor = deltaStatus == 'invalid' and colors.secondary
      or (result.delta == nil and colors.secondary) or TimingUI.statusColor(colors, deltaStatus)
    drawBadge(vec2(timerBR.x + gap, badgeTop), deltaWidth, timerHeight,
      TimingUI.formatDelta(result.delta), withBackgroundOpacity(colors.panelRaised, backgroundOpacity),
      withBackgroundOpacity(deltaColor, backgroundOpacity), deltaColor, scale, 26, true)
  end

  if snapshot.inPits then
    TimingUI.leftText('P', 10 * scale, timerTL + vec2(10 * scale, 9 * scale), colors.amber)
  end

  ui.popDWriteFont()
  ui.popStyleVar(1)
end

return Display
