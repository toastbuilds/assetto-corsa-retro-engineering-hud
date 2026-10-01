local Theme = require('modules/timing/src/theme')
local TimingUI = require('modules/timing/src/ui')

local Display = {}
local FONT = Theme.fonts.utility

local function inside(mouse, tl, br)
  return mouse.x >= tl.x and mouse.x <= br.x and mouse.y >= tl.y and mouse.y <= br.y
end

local function drawRow(row, y, width, height, colors, scale, current)
  local tl = vec2(8 * scale, y)
  local br = vec2(width - 8 * scale, y + height)
  local status = row.status or (row.invalid and 'invalid' or 'current')
  local accent = current and (row.invalid and colors.red or colors.cyan) or TimingUI.statusColor(colors, status)
  local fill = current and colors.panelRaised or colors.panel
  if not current then fill = TimingUI.statusDimColor(colors, status) end
  local stroke = accent
  if current then
    local pulse = 0.70 + 0.20 * ((math.sin((type(ui.time) == 'function' and ui.time() or 0) * 3.2) + 1) / 2)
    stroke = Theme.withAlpha(accent, pulse)
  end
  TimingUI.chamferRect(tl, br, 7 * scale, fill, stroke, (current and 1.6 or 1.1) * scale)

  local numberWidth = 48 * scale
  TimingUI.chamferRect(tl, vec2(tl.x + numberWidth, br.y), 6 * scale,
    colors.surface, colors.outlineDim, 1 * scale)
  TimingUI.centeredText(string.format('%02d', row.number or 0), 13 * scale,
    vec2(tl.x + numberWidth / 2, y + height / 2), current and colors.cyan or colors.primary)
  TimingUI.leftText(TimingUI.formatTime(row.time), 17 * scale,
    vec2(tl.x + numberWidth + 14 * scale, y + 9 * scale),
    current and (row.invalid and colors.red or colors.primary) or accent)
  if row.inPits then
    TimingUI.centeredText('P', 11 * scale, vec2(br.x - 20 * scale, y + height / 2), colors.amber)
  end
end

function Display.draw(snapshot, settings, visual)
  local colors = visual.palette
  local width, height = ui.windowWidth(), ui.windowHeight()
  local authoredHeight = 38 + (settings.rows or 10) * 34
  local scale = math.max(0.35, math.min(settings.scale or 1, (width - 8) / 330, (height - 8) / authoredHeight))
  local events = { toggleLock = false }
  local mouse = type(ui.mouseLocalPos) == 'function' and ui.mouseLocalPos() or vec2(-1, -1)
  local rowHeight = 30 * scale
  local rowGap = 4 * scale

  ui.pushStyleVarAlpha(visual.instrumentOpacity or 1)
  ui.pushDWriteFont(FONT)
  TimingUI.leftText('LAPS', 10 * scale, vec2(10 * scale, 7 * scale), colors.amber)
  TimingUI.leftText('NEWEST FIRST', 8 * scale, vec2(width - 94 * scale, 9 * scale), colors.secondary)

  local y = 27 * scale
  local visibleRows = settings.rows or 10
  if snapshot.current then
    drawRow(snapshot.current, y, width, rowHeight, colors, scale, true)
    y = y + rowHeight + rowGap
    visibleRows = visibleRows - 1
  end
  for i = 1, math.min(visibleRows, #snapshot.history) do
    drawRow(snapshot.history[i], y, width, rowHeight, colors, scale, false)
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
