local Theme = require('modules/timing/src/theme')
local TimingUI = require('modules/timing/src/ui')
local Edition = require('src/edition')

local Display = {}
local FONT = Theme.fonts.utility
local PROGRESS_SEGMENTS = 16
local TRANSITION_DURATION = 0.48

local function smoothStep(progress)
  return progress * progress * progress * (progress * (progress * 6 - 15) + 10)
end

function Display.size(settings)
  return vec2(220, 9 + (settings.rows or 10) * 37)
end

local function inside(mouse, tl, br)
  return mouse.x >= tl.x and mouse.x <= br.x and mouse.y >= tl.y and mouse.y <= br.y
end

local function drawRow(row, y, width, height, colors, scale, current)
  local tl = vec2(6 * scale, y)
  local br = vec2(width - 6 * scale, y + height)
  local status = row.invalid and 'invalid' or row.status or 'current'
  local accent = status == 'current' and colors.cyan or TimingUI.statusColor(colors, status)
  local fill = current and colors.panelRaised or colors.panel
  if not current then
    local tinted = Theme.blend(fill, accent, 0.16)
    fill = rgbm(tinted.r, tinted.g, tinted.b, fill.mult)
  end
  local numberWidth = 46 * scale
  local timeTL = vec2(tl.x + numberWidth + 4 * scale, y)
  TimingUI.chamferRect(timeTL, br, 5 * scale, fill, colors.outlineDim, scale)
  TimingUI.chamferRect(tl, vec2(tl.x + numberWidth, br.y), 5 * scale,
    colors.surface, colors.outlineDim, 1 * scale)
  local centerY = y + height / 2
  TimingUI.centeredText(string.format('%02d', row.number or 0), 17 * scale,
    vec2(tl.x + numberWidth / 2, centerY), colors.primary)
  if current then
    local progress = math.max(0, math.min(1, tonumber(row.progress) or 0))
    local progressTL = timeTL + vec2(5 * scale, 5 * scale)
    local progressBR = br - vec2((row.inPits and 26 or 5) * scale, 5 * scale)
    local pulse = 0.80 + 0.15 * ((math.sin((type(ui.time) == 'function' and ui.time() or 0) * 3.2) + 1) / 2)
    local tinted = Theme.blend(fill, accent, 0.36 * pulse)
    local activeColor = rgbm(tinted.r, tinted.g, tinted.b, fill.mult)
    local inactiveTint = Theme.blend(fill, colors.metalDim, 0.25)
    local inactiveColor = rgbm(inactiveTint.r, inactiveTint.g, inactiveTint.b, fill.mult)
    local segmentGap = 2 * scale
    local segmentWidth = (progressBR.x - progressTL.x - (PROGRESS_SEGMENTS - 1) * segmentGap) / PROGRESS_SEGMENTS
    local filled = math.ceil(progress * PROGRESS_SEGMENTS)
    for segmentIndex = 1, PROGRESS_SEGMENTS do
      local left = progressTL.x + (segmentIndex - 1) * (segmentWidth + segmentGap)
      ui.drawRectFilled(vec2(left, progressTL.y), vec2(left + segmentWidth, progressBR.y),
        segmentIndex <= filled and activeColor or inactiveColor)
    end
  else
    ui.drawRectFilled(vec2(timeTL.x + 7 * scale, centerY - 7 * scale),
      vec2(timeTL.x + 10 * scale, centerY + 7 * scale), accent)
    local timeText = TimingUI.formatTime(row.time)
    local timeSize = 18 * scale
    local textLeft = timeTL.x + 19 * scale
    local textRight = br.x - (row.inPits and 32 or 12) * scale
    local measured = ui.measureDWriteText(timeText, timeSize)
    if measured.x > textRight - textLeft then
      timeSize = timeSize * (textRight - textLeft) / measured.x
      measured = ui.measureDWriteText(timeText, timeSize)
    end
    TimingUI.leftText(timeText, timeSize, vec2(textLeft, centerY - measured.y / 2),
      row.invalid and colors.red or colors.primary)
  end
  if row.inPits then
    TimingUI.centeredText('P', 15 * scale, vec2(br.x - 16 * scale, centerY), colors.amber)
  end
end

function Display.draw(snapshot, settings, visual)
  local colors = visual.palette
  local width, height = ui.windowWidth(), ui.windowHeight()
  local authored = Display.size(settings)
  local scale = math.max(0.35, math.min(settings.scale or 1, width / authored.x, height / authored.y))
  local events = { toggleLock = false }
  local mouse = type(ui.mouseLocalPos) == 'function' and ui.mouseLocalPos() or vec2(-1, -1)
  local rowHeight = 34 * scale
  local rowGap = 3 * scale
  local remaining = 0
  if Edition.premium and visual.animateLapChanges and snapshot.transitionStartedAt ~= nil then
    local elapsed = (type(ui.time) == 'function' and ui.time() or 0) - snapshot.transitionStartedAt
    if elapsed >= 0 and elapsed < TRANSITION_DURATION then
      remaining = 1 - smoothStep(elapsed / TRANSITION_DURATION)
    end
  end

  ui.pushStyleVarAlpha(visual.instrumentOpacity or 1)
  ui.pushDWriteFont(FONT)

  local y = 6 * scale
  local visibleRows = settings.rows or 10
  if snapshot.current then
    ui.pushStyleVarAlpha(smoothStep(math.max(0, 1 - remaining / 0.15)))
    drawRow(snapshot.current, y, width, rowHeight, colors, scale, true)
    ui.popStyleVar(1)
    y = y + rowHeight + rowGap
    visibleRows = visibleRows - 1
  end
  for i = 1, math.min(visibleRows, #snapshot.history) do
    drawRow(snapshot.history[i], y - (rowHeight + rowGap) * remaining, width, rowHeight, colors, scale, false)
    y = y + rowHeight + rowGap
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
