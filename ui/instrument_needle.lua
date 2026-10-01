local Config = require('src/instrument_config')
local Light = require('ui/instrument_illumination')
local M = {}

-- Catalog geometry is prepared once. Only the local transform changes per frame.
function M.draw(center, scale, angle, preset, palette, light, alertColor, backlight)
  local s = scale * preset.scale
  angle = angle + preset.offset
  local dx, dy = math.cos(angle), math.sin(angle)
  local function p(x, y)
    return center + vec2((x * dx - y * dy) * s, (x * dy + y * dx) * s)
  end
  local color = alertColor or palette[preset.color]
  local base = color
  local style = backlight and (preset.hubShape == 'mini' and backlight.subNeedle or backlight.needle)
  local halo = Light.halo(base, style)
  local core = style and Light.mix(Light.color(base, style),
    alertColor and Light.color(base, style) or style.coreColor, style.core)
  local lit = math.max(0, math.min(1, light or 0)) * preset.glow
  if style then
    color = Light.color(base, style)
  elseif lit > 0 and not alertColor then
    local illumination = palette[preset.illumination]
    color = rgbm(color.r + (illumination.r - color.r) * lit,
      color.g + (illumination.g - color.g) * lit,
      color.b + (illumination.b - color.b) * lit, color.mult)
  end
  local function tint(role)
    return role == 'edge' and palette[preset.edge] or (role and palette[role] or color)
  end
  local function path(points)
    ui.pathClear()
    for _, v in ipairs(points) do ui.pathLineTo(p(v[1], v[2])) end
  end
  local function hubTint(baseColor)
    return Light.color(baseColor, backlight and backlight.hub)
  end
  local g = preset.geometry
  ui.pushStyleVarAlpha(preset.opacity)
  if preset.hubShape == 'mini' then
    -- Keep the original fuel/boost hand, including its hub and backlight.
    local primary = style and color or base
    if halo then
      for _, points in ipairs(g) do
        path(points); ui.pathStroke(halo, true, (preset.borderWidth + 2 * style.radius) * s)
      end
    elseif not style and (light or 0) > 0 and preset.glow > 0 then
      local c = palette[preset.illumination]
      ui.drawLine(p(0, 0), p(preset.length, 0), rgbm(c.r, c.g, c.b, light * preset.glow),
        (preset.width + 3) * s)
    end
    for _, points in ipairs(g) do
      path(points); ui.pathFillConvex(primary)
      path(points); ui.pathStroke(palette[preset.edge], true, preset.borderWidth * s)
    end
    if style and style.core > 0 then
      for _, points in ipairs(preset.cores) do path(points); ui.pathFillConvex(core) end
    end
    local r = preset.hubRadius
    ui.drawCircleFilled(center + vec2(0, 1.5 * s), (r + 2) * s, palette.void, 24)
    ui.drawCircleFilled(center, r * s, palette.panelRaised, 24)
    ui.drawCircle(center, r * s, hubTint(palette.metal), 24, 1.5 * s)
    ui.drawCircle(center, (r - 2) * s, palette.outline, 24, 0.8 * s)
    ui.drawCircleFilled(center, r * 0.56 * s, palette[preset.hubCenter], 24)
    ui.drawCircle(center, r * 0.56 * s, hubTint(palette.primary), 24, 0.6 * s)
    ui.drawLine(p(-r * 0.24, 0), p(r * 0.24, 0), palette.metalDim, 0.8 * s)
    ui.popStyleVar(1)
    return
  end
  if halo then
    for _, part in ipairs(g.outlines) do
      if not part.hole then
        path(part.points)
        ui.pathStroke(halo, part.closed, (part.width + 2 * style.radius) * s)
      end
    end
    for _, part in ipairs(g.circles) do
      if not part.fill then
        ui.drawCircle(p(part.x, 0), part.radius * s, halo, 32, (part.width + 2 * style.radius) * s)
      end
    end
  end
  for _, part in ipairs(g.polygons) do
    path(part.points)
    ui.pathFillConvex(tint(part.role))
  end
  for _, part in ipairs(g.outlines) do
    path(part.points)
    ui.pathStroke(tint(part.role), part.closed, part.width * s)
  end
  for _, part in ipairs(g.circles) do
    if part.fill then ui.drawCircleFilled(p(part.x, 0), part.radius * s, tint(part.role), 32)
    else ui.drawCircle(p(part.x, 0), part.radius * s, tint(part.role), 32, part.width * s) end
  end
  if style and style.core > 0 then
    for _, points in ipairs(g.cores) do path(points); ui.pathFillConvex(core) end
    for _, part in ipairs(g.outlines) do
      if not part.role then
        path(part.points)
        ui.pathStroke(core, part.closed, part.width * Config.illumination.needleCoreWidth * s)
      end
    end
    for _, part in ipairs(g.circles) do
      if not part.role then
        if part.fill then
          ui.drawCircleFilled(p(part.x, 0), math.max(0, part.radius - preset.coreInset) * s, core, 32)
        else
          ui.drawCircle(p(part.x, 0), part.radius * s, core, 32,
            part.width * Config.illumination.needleCoreWidth * s)
        end
      end
    end
  end

  local r, hub = preset.hubRadius, preset.hubShape
  if hub ~= 'open' then
    ui.drawCircleFilled(center + vec2(0, 1.5 * s), (r + 2) * s, palette.void, 32)
    ui.drawCircleFilled(center, r * s, palette.panelRaised, 32)
  end
  ui.drawCircle(center, r * s, hubTint(hub == 'rivet' and palette.outline or palette.metal), 32, 1.1 * s)
  if hub == 'open' then
    -- Arms terminate at the ring, leaving the center genuinely open.
    ui.drawCircle(center, (r - 1.7) * s, color, 32, 1.1 * s)
  elseif hub == 'rivet' then
    ui.drawCircleFilled(center, r * 0.29 * s, color, 24)
  elseif hub == 'cap' then
    ui.drawCircleFilled(center, r * 0.70 * s, palette.metalDim, 32)
    ui.drawCircle(center, r * 0.70 * s, hubTint(palette.primary), 32, 0.75 * s)
    ui.drawLine(p(-r * 0.48, -r * 0.48), p(r * 0.48, r * 0.48), palette.metal, 0.9 * s)
  elseif hub == 'faceted' then
    path(preset.hubGeometry)
    ui.pathFillConvex(palette.metalDim)
    path(preset.hubGeometry)
    ui.pathStroke(palette.metal, true, 0.8 * s)
    path(preset.hubMarker)
    ui.pathFillConvex(color)
  elseif hub == 'weight' then
    path(preset.hubGeometry)
    ui.pathFillConvex(palette.metal)
    path(preset.hubGeometry)
    ui.pathStroke(palette.outline, true, 1.4 * s)
    ui.drawCircleFilled(p(-preset.counterweightLength, 0), 4 * s, palette.metal, 24)
    ui.drawCircle(p(-preset.counterweightLength, 0), 4 * s, hubTint(palette.primary), 24, 0.6 * s)
  else
    ui.drawCircle(center, (r - 2) * s, palette.outline, 32, 0.8 * s)
    local core = hub == 'small_rivet' and 0.32 or 0.56
    ui.drawCircleFilled(center, r * core * s, palette[preset.hubCenter], 24)
    ui.drawCircle(center, r * core * s, hubTint(palette.primary), 24, 0.6 * s)
    ui.drawLine(p(-r * 0.24, 0), p(r * 0.24, 0), palette.metalDim, 0.8 * s)
    if hub == 'riveted' then
      for _, v in ipairs(preset.hubRivets) do
        ui.drawCircleFilled(p(v[1], v[2]), 1.1 * s, color, 12)
      end
    end
  end
  ui.popStyleVar(1)
end

return M
