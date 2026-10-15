local Theme = require('src/theme')
local General = require('src/general_settings')
local TimingUI = require('modules/timing/src/ui')
local M = { width = 660, height = 96 }

local function polygon(points, color)
  ui.pathClear()
  for _, point in ipairs(points) do ui.pathLineTo(point) end
  ui.pathFillConvex(color)
end

local function icon(kind, tl, scale, color)
  local function p(x, y) return tl + vec2(x, y) * scale end
  if kind == 'blue' then
    ui.drawLine(p(17, 62), p(28, 16), color, 3 * scale)
    polygon({ p(27, 18), p(41, 14), p(38, 40), p(22, 43) }, color)
    polygon({ p(41, 14), p(53, 19), p(48, 44), p(38, 40) }, color)
    polygon({ p(53, 19), p(68, 19), p(63, 44), p(48, 44) }, color)
  elseif kind == 'repair' then
    ui.drawLine(p(24, 57), p(53, 28), color, 12 * scale)
    ui.drawCircleFilled(p(23, 58), 7 * scale, color, 20)
    -- An open wrench head uses strokes rather than a concave convex-fill path.
    for _, segment in ipairs({ {47,31,42,23}, {42,23,49,14}, {49,14,56,12},
        {47,31,57,37}, {57,37,66,29}, {66,29,68,20} }) do
      ui.drawLine(p(segment[1], segment[2]), p(segment[3], segment[4]), color, 7 * scale)
    end
  elseif kind == 'battle' then
    for _, shift in ipairs({ 0, 11 }) do
      ui.drawLine(p(22, 29 + shift), p(42, 13 + shift), color, 3 * scale)
      ui.drawLine(p(42, 13 + shift), p(62, 29 + shift), color, 3 * scale)
    end
    ui.drawRect(p(27, 44), p(57, 66), color, 3 * scale, nil, 2 * scale)
    ui.drawLine(p(32, 49), p(52, 49), color, 2 * scale)
    for _, x in ipairs({ 22, 62 }) do
      ui.drawLine(p(x, 46), p(x, 53), color, 4 * scale)
      ui.drawLine(p(x, 58), p(x, 65), color, 4 * scale)
    end
  else
    ui.drawLine(p(17, 62), p(17, 23), color, 4 * scale)
    ui.drawLine(p(67, 62), p(67, 23), color, 4 * scale)
    polygon({ p(13, 24), p(42, 10), p(71, 24) }, color)
    ui.drawLine(p(23, 29), p(61, 29), color, 2 * scale)
    ui.drawLine(p(23, 35), p(61, 35), color, 2 * scale)
    polygon({ p(27, 49), p(32, 41), p(52, 41), p(57, 49) }, color)
    ui.drawRectFilled(p(25, 49), p(59, 58), color)
    ui.drawLine(p(29, 58), p(29, 63), color, 4 * scale)
    ui.drawLine(p(55, 58), p(55, 63), color, 4 * scale)
  end
end

local function fitted(text, size, tl, width, color, bold)
  ui.pushDWriteFont(bold and 'Consolas;Weight=Bold' or Theme.fonts.utility)
  local measured = ui.measureDWriteText(text, size)
  size = size * math.min(1, width / math.max(1, measured.x))
  ui.dwriteDrawText(text, size, tl, color)
  ui.popDWriteFont()
end

function M.draw(notice, settings)
  if not notice then return end
  local width, height = ui.windowWidth(), ui.windowHeight()
  local scale = math.min(width / M.width, height / M.height)
  if scale <= 0 then return end
  local origin = vec2((width - M.width * scale) / 2, (height - M.height * scale) / 2)
  local function p(x, y) return origin + vec2(x, y) * scale end
  local colors = Theme.get(General.values.theme)
  local opacity = General.values.opacity
  local function ink(color, alpha) return Theme.withAlpha(color, opacity * (alpha or color.mult or 1)) end
  local accent = notice.kind == 'blue' and (colors.flagBlue or colors.shiftBlue)
    or notice.kind == 'battle' and notice.side == 'ahead' and colors.green
    or (notice.kind == 'repair' or notice.kind == 'battle' and notice.urgent) and colors.red or colors.amber
  TimingUI.chamferRect(p(3, 3), p(657, 93), 9 * scale,
    ink(colors.panel, General.background(colors.panel.mult)), ink(colors.outline), scale)
  ui.drawLine(p(91, 17), p(91, 77), ink(colors.outlineSoft), scale)
  ui.drawLine(p(502, 17), p(502, 77), ink(colors.outlineSoft), scale)
  polygon({ p(7, 86), p(653, 86), p(647, 92), p(13, 92) }, ink(accent))
  icon(notice.kind, p(5, 9), scale, ink(accent))
  -- No eyebrow/header: the two message lines have the entire plate height.
  fitted(notice.title, 29 * scale, p(108, 16), 378 * scale, ink(colors.primary), true)
  fitted(notice.detail, 15 * scale, p(108, 55), 378 * scale, ink(colors.primary), false)
  ui.pushDWriteFont('Consolas;Weight=Bold')
  local valueSize = 31 * scale
  local valueWidth = ui.measureDWriteText(notice.value, valueSize).x
  valueSize = valueSize * math.min(1, 128 * scale / math.max(1, valueWidth))
  TimingUI.centeredText(notice.value, valueSize, p(580, 35), ink(notice.kind == 'battle' and accent or colors.primary))
  ui.popDWriteFont()
  ui.pushDWriteFont(Theme.fonts.utility)
  TimingUI.centeredText(notice.label, 13 * scale, p(580, 66), ink(colors.secondary))
  ui.popDWriteFont()
end

return M
