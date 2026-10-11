local Theme = require('src/theme')
local General = require('src/general_settings')
local TimingUI = require('modules/timing/src/ui')
local M = { width = 420, height = 360 }

function M.draw(snapshot, settings)
  local width, height = ui.windowWidth(), ui.windowHeight()
  local scale = math.min(width / M.width, height / M.height)
  if scale <= 0 then return end
  local origin = vec2((width - M.width * scale) / 2, (height - M.height * scale) / 2)
  local function p(x, y) return origin + vec2(x, y) * scale end
  local c = Theme.get(General.values.theme)
  local function ink(color, alpha) return Theme.withAlpha(color, General.values.opacity * (alpha or color.mult or 1)) end
  local function text(value, x, y, size, role, maxWidth, right)
    ui.pushDWriteFont(Theme.fonts.utility)
    size = size * scale
    size = size * math.min(1, (maxWidth or 370) * scale / math.max(1, ui.measureDWriteText(value, size).x))
    local at = p(x, y)
    if right then at.x = at.x - ui.measureDWriteText(value, size).x end
    ui.dwriteDrawText(value, size, at, ink(c[role or 'primary']))
    ui.popDWriteFont()
  end
  TimingUI.chamferRect(p(3, 3), p(417, 357), 9 * scale,
    ink(c.panel, General.background(c.panel.mult)), ink(c.outline), scale)
  text('BATTLE', 20, 13, 24)
  text(snapshot and snapshot.classID or 'CLASS', 398, 17, 16, 'cyan', 100, true)
  ui.drawLine(p(20, 48), p(400, 48), ink(c.outlineSoft), scale)
  if not snapshot or snapshot.message then
    text(snapshot and snapshot.message or 'WAITING FOR RACE DATA', 22, 147, 17, 'secondary')
    return
  end
  local function rival(row, side, top)
    text(side, 22, top, 12, 'secondary')
    if not row then text(side == 'AHEAD' and 'CLASS LEADER' or 'NO CAR BEHIND', 22, top + 28, 19, 'secondary'); return end
    TimingUI.chamferRect(p(22, top + 24), p(75, top + 58), 3 * scale, ink(c.panelRaised), ink(c.outlineSoft), scale)
    text('P' .. row.position, 31, top + 29, 19, 'primary', 38)
    text(row.driver, 87, top + 28, 21, 'primary', 178)
    text(row.value, 398, top + 23, 28, 'primary', 120, true)
    text(row.trend, 22, top + 68, 15, row.role, 376)
    if settings.showGraphs and #row.points > 1 then
      local points = row.points
      local low, high = math.huge, -math.huge
      for _, point in ipairs(points) do low, high = math.min(low, point.gap), math.max(high, point.gap) end
      high = math.max(high, low + 0.3)
      local span = math.max(0.001, points[#points].progress - points[1].progress)
      local function at(point) return p(24 + (point.progress - points[1].progress) / span * 235,
        top + 115 - (point.gap - low) / (high - low) * 20) end
      for i = 2, #points do ui.drawLine(at(points[i - 1]), at(points[i]), ink(c[row.role]), 1.5 * scale) end
      text(row.laps > 0 and ('LAST ' .. row.laps .. (row.laps == 1 and ' LAP' or ' LAPS')) or 'LIVE GAP',
        398, top + 99, 11, 'secondary', 116, true)
    end
  end
  rival(snapshot.ahead, 'AHEAD', 57)
  TimingUI.chamferRect(p(17, 182), p(403, 216), 4 * scale, ink(c.amberDim), ink(c.outline), scale)
  text('P' .. snapshot.position, 29, 187, 21, 'primary', 53)
  text(snapshot.final and 'YOU / FINISHED' or 'YOU', 87, 189, 18)
  text(snapshot.classID, 389, 190, 16, 'cyan', 85, true)
  rival(snapshot.behind, 'BEHIND', 225)
end
return M
