local Theme = require('src/theme')
local Light = require('ui/instrument_illumination')
local M = {}
M.__index = M

function M.new(width, height, visual)
  local sx, sy = width / 1280, height / 220
  return setmetatable({ sx = sx, sy = sy, scale = math.min(sx, sy), palette = visual.palette,
    lighting = Light.resolve(visual.palette, visual.theme or 'dark', visual.light or 0),
    light = visual.light or 0 }, M)
end

function M:p(x, y) return vec2(x * self.sx, y * self.sy) end

function M:ink(role, alpha, kind)
  local base = self.palette[role]
  local color = kind and Light.color(base, self.lighting[kind]) or base
  return Theme.withAlpha(color, alpha or 1)
end

function M:line(x1, y1, x2, y2, role, width, alpha)
  ui.drawLine(self:p(x1, y1), self:p(x2, y2), self:ink(role, alpha), (width or 1) * self.scale)
end

function M:text(value, size, x, y, role, align, kind)
  value = tostring(value)
  local position = self:p(x, y)
  local pixels = size * self.scale
  if align then
    local measured = ui.measureDWriteText(value, pixels).x
    position.x = position.x - measured * (align == 'right' and 1 or 0.5)
  end
  local style = kind and self.lighting[kind]
  local halo = style and Light.halo(self.palette[role], style)
  if halo then
    local spread = style.radius * self.scale
    ui.dwriteDrawText(value, pixels, position + vec2(-spread, -spread * 0.5), halo)
    ui.dwriteDrawText(value, pixels, position + vec2(spread, spread * 0.5), halo)
  end
  ui.dwriteDrawText(value, pixels, position, self:ink(role, 1, kind))
end

function M:polygon(points, fill, stroke, width)
  local function path()
    ui.pathClear()
    for _, point in ipairs(points) do ui.pathLineTo(self:p(point[1], point[2])) end
  end
  if fill then path(); ui.pathFillConvex(fill) end
  if stroke then path(); ui.pathStroke(stroke, true, (width or 1) * self.scale) end
end

function M:frame(x, y, width, height, cut, fill, stroke)
  self:polygon({{x+cut,y},{x+width-cut,y},{x+width,y+cut},{x+width,y+height-cut},
    {x+width-cut,y+height},{x+cut,y+height},{x,y+height-cut},{x,y+cut}}, fill, stroke)
end

function M:rect(x, y, width, height, role, alpha, lit)
  local color = self:ink(role, alpha, lit and 'segment' or nil)
  ui.drawRectFilled(self:p(x, y), self:p(x + width, y + height), color)
  if lit then
    local halo = Light.halo(self.palette[role], self.lighting.segment)
    if halo then ui.drawRect(self:p(x, y), self:p(x + width, y + height), halo, 0, nil, 2 * self.scale) end
  end
end

function M:symbol(draw, x, y, size, role, illuminated)
  local center, scale = self:p(x, y), size * self.scale
  local style = illuminated and self.lighting.icon
  local halo = style and Light.halo(self.palette[role], style)
  if halo then draw(center, scale * 1.08, halo, 0.3) end
  draw(center, scale, self:ink(role, 1, illuminated and 'icon' or nil))
end

function M:ellipse(cx, cy, rx, ry, first, last, role, width, alpha)
  ui.pathClear()
  for i = 0, 64 do
    local angle = first + (last - first) * i / 64
    ui.pathLineTo(self:p(cx + math.cos(angle) * rx, cy + math.sin(angle) * ry))
  end
  ui.pathStroke(self:ink(role, alpha), false, width * self.scale)
end

function M:arcBlock(cx, cy, rx, ry, depth, first, last, role, active)
  local function point(xr, yr, angle)
    return {cx + math.cos(angle) * xr, cy + math.sin(angle) * yr}
  end
  self:polygon({point(rx,ry,first),point(rx,ry,last),point(rx-depth,ry-depth,last),point(rx-depth,ry-depth,first)},
    self:ink(role, active and 1 or 0.70, active and 'segment' or nil))
end

return M
