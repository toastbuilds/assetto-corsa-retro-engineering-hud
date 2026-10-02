local Theme = require('modules/timing/src/theme')
local TimingUI = require('modules/timing/src/ui')

local Display = {}
local FONT = Theme.fonts.utility

local function inside(mouse, tl, br)
  return mouse.x >= tl.x and mouse.x <= br.x and mouse.y >= tl.y and mouse.y <= br.y
end

local function drawBadge(tl, width, height, label, fill, stroke, textColor, scale, textSize)
  TimingUI.chamferRect(tl, tl + vec2(width, height), 8 * scale, fill, stroke, 1.1 * scale)
  local size = (textSize or 10) * scale
  local measured = ui.measureDWriteText(label, size)
  size = size * math.min(1, (width - 10 * scale) / math.max(1, measured.x),
    (height - 8 * scale) / math.max(1, measured.y))
  TimingUI.centeredText(label, size, tl + vec2(width / 2, height / 2), textColor)
end

local function withBackgroundOpacity(color, opacity)
  return Theme.withAlpha(color, (tonumber(color.mult) or 1) * opacity)
end

function Display.draw(snapshot, settings, visual)
  local colors = visual.palette
  local backgroundOpacity = math.max(0, math.min(1, tonumber(settings.backgroundOpacity) or 0.70))
  local width, height = ui.windowWidth(), ui.windowHeight()
  local scale = math.max(0.35, math.min(settings.scale or 1, width / 320, height / 94))
  local events = { toggleLock = false }
  local mouse = type(ui.mouseLocalPos) == 'function' and ui.mouseLocalPos() or vec2(-1, -1)
  local contentTop = 5 * scale
  local finalHeight = snapshot.finalLap and 25 * scale or 0
  local result = snapshot.result
  local showBest = result and result.valid ~= false and result.status == 'session_best'
  local bestWidth = 64 * scale
  local deltaWidth = 88 * scale
  local gap = 5 * scale
  local timerTop = contentTop + finalHeight + 6 * scale
  local timerHeight = height - timerTop - 2 * scale
  local timerTL = vec2(6 * scale + (showBest and bestWidth + gap or 0), timerTop)
  local timerBR = vec2(width - 6 * scale - (result and deltaWidth + gap or 0), timerTop + timerHeight)
  local timerWidth = timerBR.x - timerTL.x

  ui.pushStyleVarAlpha(visual.instrumentOpacity or 1)
  ui.pushDWriteFont(FONT)

  if snapshot.finalLap then
    local badgeWidth = 132 * scale
    local badgeTL = vec2((width - badgeWidth) / 2, contentTop)
    drawBadge(badgeTL, badgeWidth, 20 * scale, 'FINAL LAP',
      withBackgroundOpacity(colors.redDim, backgroundOpacity),
      withBackgroundOpacity(colors.red, backgroundOpacity), colors.primary, scale)
  end

  local time = result and result.time or snapshot.currentLapTime
  local timeColor = snapshot.invalid and colors.red or colors.primary
  if result then timeColor = TimingUI.statusColor(colors, result.status) end

  TimingUI.chamferRect(timerTL, timerBR, 8 * scale,
    withBackgroundOpacity(colors.panelRaised, backgroundOpacity),
    withBackgroundOpacity(colors.outlineSoft, backgroundOpacity), 1.1 * scale)
  local timeText = TimingUI.formatTime(time)
  local timeSize = timerHeight
  local pitPadding = snapshot.inPits and 18 * scale or 0
  local measured = ui.measureDWriteText(timeText, timeSize)
  timeSize = timeSize * math.min(1, (timerWidth - 16 * scale - pitPadding) / math.max(1, measured.x),
    (timerHeight - 8 * scale) / math.max(1, measured.y))
  TimingUI.centeredText(timeText, timeSize,
    vec2((timerTL.x + timerBR.x + pitPadding) / 2, timerTop + timerHeight / 2), timeColor)

  if result then
    local resultBadgeHeight = timerHeight
    local badgeTop = timerTop
    if showBest then
      drawBadge(vec2(6 * scale, badgeTop), bestWidth, resultBadgeHeight, 'BEST',
        withBackgroundOpacity(colors.purpleDim, backgroundOpacity),
        withBackgroundOpacity(colors.purple, backgroundOpacity), colors.purple, scale, 20)
    end
    local deltaStatus = (result.valid == false or result.status == 'invalid') and 'invalid'
      or (result.delta ~= nil and result.delta < 0 and 'session_best') or 'slower'
    local deltaColor = deltaStatus == 'invalid' and colors.red
      or (result.delta == nil and colors.secondary) or TimingUI.statusColor(colors, deltaStatus)
    drawBadge(vec2(timerBR.x + gap, badgeTop), deltaWidth, resultBadgeHeight,
      TimingUI.formatDelta(result.delta), withBackgroundOpacity(colors.panelRaised, backgroundOpacity),
      withBackgroundOpacity(deltaColor, backgroundOpacity), deltaColor, scale, 20)
  end

  if snapshot.inPits then
    TimingUI.leftText('P', 10 * scale, timerTL + vec2(10 * scale, 9 * scale), colors.amber)
  end

  if type(ui.mouseClicked) == 'function' and ui.MouseButton
      and ui.mouseClicked(ui.MouseButton.Right) and inside(mouse, vec2(0, 0), vec2(width, height)) then
    events.toggleLock = true
  end
  ui.popDWriteFont()
  ui.popStyleVar(1)
  return events
end

return Display
