local Theme = require('modules/timing/src/theme')
local TimingUI = require('modules/timing/src/ui')

local Display = {}
local FONT = Theme.fonts.utility

local function inside(mouse, tl, br)
  return mouse.x >= tl.x and mouse.x <= br.x and mouse.y >= tl.y and mouse.y <= br.y
end

local function drawBadge(tl, width, height, label, fill, stroke, textColor, scale)
  TimingUI.chamferRect(tl, tl + vec2(width, height), 7 * scale, fill, stroke, 1.3 * scale)
  TimingUI.centeredText(label, 10 * scale, tl + vec2(width / 2, height / 2), textColor)
end

function Display.draw(snapshot, settings, visual)
  local colors = visual.palette
  local width, height = ui.windowWidth(), ui.windowHeight()
  local scale = math.max(0.35, math.min(settings.scale or 1, (width - 12) / 560, (height - 12) / 106))
  local events = { toggleLock = false }
  local mouse = type(ui.mouseLocalPos) == 'function' and ui.mouseLocalPos() or vec2(-1, -1)
  local contentTop = 5 * scale
  local finalHeight = snapshot.finalLap and 25 * scale or 0
  local timerWidth = 250 * scale
  local timerHeight = 58 * scale
  local timerTop = contentTop + finalHeight + 6 * scale
  local timerTL = vec2((width - timerWidth) / 2, timerTop)
  local timerBR = timerTL + vec2(timerWidth, timerHeight)

  ui.pushStyleVarAlpha(visual.instrumentOpacity or 1)
  ui.pushDWriteFont(FONT)

  if snapshot.finalLap then
    local badgeWidth = 132 * scale
    local badgeTL = vec2((width - badgeWidth) / 2, contentTop)
    drawBadge(badgeTL, badgeWidth, 20 * scale, 'FINAL LAP', colors.redDim, colors.red, colors.primary, scale)
  end

  local result = snapshot.result
  local time = result and result.time or snapshot.currentLapTime
  local timeColor = snapshot.invalid and colors.red or colors.primary
  if result then timeColor = TimingUI.statusColor(colors, result.status) end

  TimingUI.chamferRect(timerTL, timerBR, 8 * scale,
    Theme.withAlpha(colors.panelRaised, 0.70), Theme.withAlpha(colors.outlineSoft, 0.58), 1.1 * scale)
  TimingUI.centeredText(TimingUI.formatTime(time), 33 * scale,
    vec2(width / 2, timerTop + timerHeight / 2), timeColor)

  if result then
    local badgeHeight = timerHeight
    local badgeWidth = math.min(122 * scale, width * 0.22)
    local gap = 6 * scale
    local statusColor = TimingUI.statusColor(colors, result.status)
    local statusFill = TimingUI.statusDimColor(colors, result.status)
    drawBadge(vec2(timerTL.x - gap - badgeWidth, timerTop), badgeWidth, badgeHeight, TimingUI.statusLabel(result.status),
      statusFill, statusColor, statusColor, scale)
    drawBadge(vec2(timerBR.x + gap, timerTop), badgeWidth, badgeHeight,
      TimingUI.formatDelta(result.delta), Theme.withAlpha(colors.panelRaised, 0.70), statusColor, statusColor, scale)
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
