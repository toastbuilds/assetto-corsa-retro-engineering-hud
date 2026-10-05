local U = require('src/utils')
local Light = require('ui/instrument_illumination')
local Theme = require('src/theme')
local M = {}

local profiles = {
  standalone = {
    powerRadius = 206, powerWidth = 18, powerStart = math.rad(65), powerEnd = math.rad(115),
    batteryRadius = 252, batteryWidth = 7, batteryStart = math.rad(50), batteryEnd = math.rad(130),
    reverse = true, labelX = 92, labelY = 157, valueY = 177, batteryY = 226,
    labelSize = 14, valueSize = 21, chargeSize = 20, iconScale = 0.8
  },
  gt7 = {
    powerRadius = 51, powerWidth = 8, powerStart = math.rad(205), powerEnd = math.rad(335),
    batteryRadius = 68, batteryWidth = 4, batteryStart = math.rad(190), batteryEnd = math.rad(350),
    labelX = 42, labelY = 5, valueY = -18, batteryY = 28,
    labelSize = 10, valueSize = 17, chargeSize = 16, iconScale = 0.55
  }
}

local function arc(center, radius, first, last, width, color, scale, style)
  ui.pathClear()
  ui.pathArcTo(center, radius * scale, first, last, 5)
  ui.pathStroke(Light.color(color, style), false, width * scale)
end

local function batteryIcon(center, scale, color)
  local function p(x, y) return center + vec2(x * scale, y * scale) end
  ui.drawRect(p(-11, -6), p(8, 6), color, scale, nil, 1.5 * scale)
  ui.drawLine(p(10, -3), p(10, 3), color, 2 * scale)
  ui.drawLine(p(-7, 0), p(-1, 0), color, 1.3 * scale)
  ui.drawLine(p(-4, -3), p(-4, 3), color, 1.3 * scale)
  ui.drawLine(p(2, 0), p(5, 0), color, 1.3 * scale)
end

-- Triptych option C: independent bipolar CHG/PWR arc plus a thinner state-
-- of-charge arc at the bezel. Both views share identical telemetry semantics.
function M.draw(center, scale, hybrid, palette, theme, lights, profile)
  local p = profiles[profile]
  local L = Theme.dialBacklight and Light.resolve(palette, theme, lights or 0) or {}
  local function text(value, size, x, y, color, style)
    Light.text(value, size * scale, center + vec2(x * scale, y * scale), color, nil, style, scale)
  end
  local fraction = hybrid.needle
  for i = 1, 16 do
    local f = (i - 0.5) / 16
    local signed = (p.reverse and 1 - f or f) * 2 - 1
    local active = fraction ~= nil and ((signed > 0 and fraction > 0 and signed <= fraction)
      or (signed < 0 and fraction < 0 and signed >= fraction))
    local span = (p.powerEnd - p.powerStart) / 16
    arc(center, p.powerRadius, p.powerStart + (i - 1 + 0.12) * span,
      p.powerStart + (i - 0.12) * span, p.powerWidth,
      active and (signed < 0 and palette.green or palette.cyan) or palette.inactive,
      scale, active and L.subSegment or nil)
  end
  local batteryColor = hybrid.charge and hybrid.charge <= 0.15 and palette.red or palette.green
  for i = 1, 32 do
    local span = (p.batteryEnd - p.batteryStart) / 32
    local j = p.reverse and 33 - i or i
    local active = hybrid.charge ~= nil and i <= math.floor(hybrid.charge * 32 + 0.5)
    arc(center, p.batteryRadius, p.batteryStart + (j - 1 + 0.15) * span,
      p.batteryStart + (j - 0.15) * span, p.batteryWidth,
      active and batteryColor or palette.inactive, scale, active and L.subSegment or nil)
  end
  text('CHG', p.labelSize, -p.labelX, p.labelY, palette.green, L.label)
  text('PWR', p.labelSize, p.labelX, p.labelY, palette.cyan, L.label)
  local value = hybrid.powerKw ~= nil and string.format('%.0f kW', hybrid.powerKw)
    or hybrid.delivery ~= nil and string.format('ERS %.0f%%', hybrid.delivery * 100) or 'ERS --'
  if hybrid.batteryRecovery then
    value = hybrid.chargeRecoveryRate and string.format('-%.1f%%/s', hybrid.chargeRecoveryRate) or 'CHG'
  end
  text(value, p.valueSize, 0, p.valueY,
    (hybrid.batteryRecovery or hybrid.powerKw and hybrid.powerKw < 0) and palette.green or palette.cyan, L.value)
  local charge = hybrid.charge ~= nil and string.format('%.0f%%', hybrid.charge * 100) or '--%'
  local measured = ui.measureDWriteText(charge, p.chargeSize * scale)
  local groupWidth = 25 * p.iconScale * scale + 8 * scale + measured.x
  local left = center.x - groupWidth / 2
  batteryIcon(vec2(left + 11 * p.iconScale * scale, center.y + p.batteryY * scale),
    p.iconScale * scale, Light.color(palette.primary, L.icon))
  Light.text(charge, p.chargeSize * scale,
    vec2(center.x + (25 * p.iconScale + 8) * scale / 2, center.y + p.batteryY * scale),
    palette.primary, nil, L.value, scale)
end

return M
