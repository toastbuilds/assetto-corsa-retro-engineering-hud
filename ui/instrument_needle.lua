local Theme = require('src/theme')
local U = require('src/utils')
local M = {}

-- Local longitudinal/lateral coordinates allow all presets to share transforms.
-- Open bodies are assembled from convex pieces, not fake background cutouts.
function M.draw(center, scale, angle, preset, palette, light, alertColor)
  local length = preset.length
  local width = preset.width / 2
  local effectiveScale = scale * preset.scale
  angle = angle + preset.offset
  local dx, dy = math.cos(angle), math.sin(angle)
  local function p(x, y)
    return center + vec2((x * dx - y * dy) * effectiveScale, (x * dy + y * dx) * effectiveScale)
  end
  local color = alertColor or palette[preset.color]
  local edge = palette[preset.edge]
  local function polygon(points, fill)
    ui.pathClear()
    for _, v in ipairs(points) do ui.pathLineTo(p(v[1], v[2])) end
    ui.pathFillConvex(fill or color)
    ui.pathClear()
    for _, v in ipairs(points) do ui.pathLineTo(p(v[1], v[2])) end
    ui.pathStroke(edge, true, preset.borderWidth * effectiveScale)
  end
  local function line(x1, y1, x2, y2, thickness, tint)
    ui.drawLine(p(x1, y1), p(x2, y2), tint or color, thickness * effectiveScale)
  end
  local function ring(x, radius)
    ui.drawCircle(p(x, 0), radius * effectiveScale, color, 20, 1.3 * effectiveScale)
  end
  ui.pushStyleVarAlpha(preset.opacity)
  if light > 0 and preset.glow > 0 then
    line(0, 0, length, 0, preset.width + 3,
      Theme.withAlpha(palette[preset.illumination], light * preset.glow))
  end
  local body = preset.body
  if body == 'cutout' or body == 'twin' then
    local inner = body == 'twin' and width * 0.72 or width * 0.40
    polygon({ {0, -width}, {length, -preset.tipWidth}, {length * 0.75, -preset.tipWidth}, {12, -inner} })
    polygon({ {12, inner}, {length * 0.75, preset.tipWidth}, {length, preset.tipWidth}, {0, width} })
    polygon({ {length * 0.75, -preset.tipWidth}, {length, -preset.tipWidth},
      {length, preset.tipWidth}, {length * 0.75, preset.tipWidth} })
    if body == 'twin' then line(22, -inner, 22, inner, 1) end
  elseif body == 'loop' then
    line(0, -width, length, 0, 1.1)
    line(length, 0, 0, width, 1.1)
  elseif body == 'line' then
    line(0, 0, length - (preset.tip and 8 or 0), 0, preset.width)
  elseif body == 'paddle' then
    polygon({ {0, -width}, {18, -width}, {length, -preset.tipWidth},
      {length, preset.tipWidth}, {18, width}, {0, width} })
    line(8, 0, 25, 0, 2, palette.metalDim)
  else
    polygon({ {0, -width}, {length, -preset.tipWidth}, {length, preset.tipWidth}, {0, width} })
  end
  if preset.tip == 'ring' then ring(length - 4, 5)
  elseif preset.tip == 'arrow' then
    polygon({ {length - 16, -8}, {length, 0}, {length - 16, 8} })
  end
  local tail, tailWidth = preset.counterweightLength, preset.counterweightWidth / 2
  if preset.counterweight == 'ring' then
    line(-tail + 4, 0, 0, 0, 1); ring(-tail, 4)
  elseif preset.counterweight == 'disc' then
    line(-tail, 0, 0, 0, 1.5)
    ui.drawCircleFilled(p(-tail, 0), tailWidth * effectiveScale, color, 20)
  elseif preset.counterweight == 'slot' then
    line(-tail, -tailWidth, 0, -tailWidth, 1)
    line(-tail, tailWidth, 0, tailWidth, 1)
    line(-tail, -tailWidth, -tail, tailWidth, 1)
  elseif preset.counterweight == 'diamond' then
    polygon({ {-tail, 0}, {-tail / 2, -tailWidth * 2}, {0, 0}, {-tail / 2, tailWidth * 2} })
  elseif preset.counterweight == 'block' then
    line(-tail, 0, 0, 0, 2)
    polygon({ {-tail, -tailWidth}, {-tail + 12, -tailWidth}, {-tail + 12, tailWidth}, {-tail, tailWidth} })
  else
    polygon({ {-tail, -tailWidth}, {0, -tailWidth}, {0, tailWidth}, {-tail, tailWidth} })
  end
  local radius = preset.hubRadius * effectiveScale
  ui.drawCircleFilled(center + vec2(0, 1.5 * effectiveScale), radius + 2 * effectiveScale, palette.void, 24)
  ui.drawCircleFilled(center, radius, palette.panelRaised, 24)
  ui.drawCircle(center, radius, palette.metal, 24, 1.5 * effectiveScale)
  ui.drawCircle(center, radius - 2 * effectiveScale, palette.outline, 24, 0.8 * effectiveScale)
  if preset.hubShape ~= 'open' then
    ui.drawCircleFilled(center, radius * 0.56, palette[preset.hubCenter], 24)
    ui.drawCircle(center, radius * 0.56, palette.primary, 24, 0.6 * effectiveScale)
    line(-radius * 0.24 / effectiveScale, 0, radius * 0.24 / effectiveScale, 0, 0.8, palette.metalDim)
  end
  ui.popStyleVar(1)
end

return M
