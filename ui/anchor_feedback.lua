local Theme = require('src/theme')
local GeneralSettings = require('src/general_settings')
local M = {}

-- A brief instrument registration mark: jaws settle around a fixed datum,
-- then open when movement is enabled. No persistent overlay or input widget.
function M.draw(size, anchored, age)
  if not size or size.x < 100 or size.y < 32 then return end
  local palette = Theme.get(GeneralSettings.values.theme)
  local fade = math.min(1, math.max(0, (1.15 - age) / 0.3))
  local alpha = fade * GeneralSettings.values.opacity
  local accent = Theme.withAlpha(anchored and palette.amber or palette.cyan, alpha)
  local scale = math.min(1, size.x / 180, size.y / 70)
  local center = vec2(size.x / 2, 22 * scale)
  local progress = math.min(1, age / 0.24)
  local eased = 1 - (1 - progress) ^ 3
  local opening = anchored and (1 - eased) or eased
  local halfWidth, halfHeight = (57 + 8 * opening) * scale, (12 + 3 * opening) * scale
  local length = 7 * scale
  ui.drawRectFilled(center - vec2(56, 11) * scale, center + vec2(56, 11) * scale,
    Theme.withAlpha(palette.panel, alpha * GeneralSettings.background(0.94)), 2 * scale)
  for _, sx in ipairs({-1, 1}) do
    for _, sy in ipairs({-1, 1}) do
      local corner = center + vec2(sx * halfWidth, sy * halfHeight)
      ui.drawLine(corner, corner - vec2(sx * length, 0), accent, 1.5 * scale)
      ui.drawLine(corner, corner - vec2(0, sy * length), accent, 1.5 * scale)
    end
  end
  local datum = center - vec2(39, 0) * scale
  local gap = anchored and 0 or 3 * eased
  ui.drawLine(datum - vec2(6 + gap, 0) * scale, datum - vec2(2 + gap, 0) * scale, accent, scale)
  ui.drawLine(datum + vec2(2 + gap, 0) * scale, datum + vec2(6 + gap, 0) * scale, accent, scale)
  ui.drawLine(datum - vec2(0, 6) * scale, datum - vec2(0, 2) * scale, accent, scale)
  ui.drawLine(datum + vec2(0, 2) * scale, datum + vec2(0, 6) * scale, accent, scale)
  ui.drawCircleFilled(datum, 1.5 * scale, accent)
  ui.pushDWriteFont(Theme.fonts.utility)
  ui.dwriteDrawText(anchored and 'FIXED' or 'MOVE', 12 * scale,
    center - vec2(23, 8) * scale, accent)
  ui.popDWriteFont()
end

return M
