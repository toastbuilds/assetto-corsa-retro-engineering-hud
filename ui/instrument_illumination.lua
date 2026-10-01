local Config = require('src/instrument_config')
local Theme = require('src/theme')
local M = {}
local I = Config.illumination
local cache = setmetatable({}, {__mode = 'k'})
local segmentPositions = setmetatable({}, {__mode = 'k'})

function M.mix(a, b, amount)
  if amount <= 0 then return a end
  return rgbm(a.r + (b.r - a.r) * amount, a.g + (b.g - a.g) * amount,
    a.b + (b.b - a.b) * amount, a.mult)
end

-- One settled style set per palette. Both instruments reuse its colors and
-- style tables; interpolation only rebuilds colors during a light transition.
function M.resolve(C, theme, light)
  local current = cache[C]
  if current and current.light == light then return current end
  local targets = Theme.dialBacklight[theme] or Theme.dialBacklight.dark
  local strength = theme == 'light' and I.lightThemeStrength or 1
  local haloStrength = theme == 'light' and I.lightThemeHalo or 1
  current = current or {}
  current.light, current.targets = light, targets
  local roles = {primary='warm', secondary='amber', amber='amber', backlight='warm',
    cyan='cyan', shiftBlue='cyan', shiftBlueDim='cyanDim', red='red', redDim='red',
    metal='amber', outline='amber', outlineSoft='amber'}
  for name, token in pairs(I) do
    if type(token) == 'table' and token.intensity then
      local style = current[name] or { colors = {}, halos = {} }
      style.radius, style.core = token.radius, token.core and light * token.core * strength or 0
      style.opacity = light * token.opacity * haloStrength
      for role, target in pairs(roles) do
        local base = C[role]
        style.colors[base] = M.mix(base, targets[target], light * token.intensity * strength)
        style.halos[base] = Theme.withAlpha(targets[target], style.opacity)
      end
      style.coreColor = targets.core
      current[name] = style
    end
  end
  current.ambient = Theme.withAlpha(targets.ambient, light * I.ambient.opacity * haloStrength)
  current.ringCold = Theme.withAlpha(C.cyan, light * strength)
  current.ringWarm = Theme.withAlpha(targets.amber, light * strength * I.ring.warmRatio)
  current.ringHalo = Theme.withAlpha(C.cyan, light * I.ring.haloOpacity * haloStrength)
  cache[C] = current
  return current
end

function M.color(base, style)
  return style and style.colors[base] or base
end

function M.halo(base, style)
  return style and style.opacity > 0 and style.halos[base] or nil
end

function M.text(value, size, center, base, maxWidth, style, scale)
  local measured = ui.measureDWriteText(value, size)
  if maxWidth and measured.x > maxWidth then
    size = size * maxWidth / measured.x
    measured = ui.measureDWriteText(value, size)
  end
  local position = center - measured / 2
  local halo = M.halo(base, style)
  if halo then
    local spread = style.radius * scale
    -- Two faint opposing copies supply diffusion without four text passes.
    ui.dwriteDrawText(value, size, vec2(position.x - spread, position.y - spread / 2), halo)
    ui.dwriteDrawText(value, size, vec2(position.x + spread, position.y + spread / 2), halo)
  end
  ui.dwriteDrawText(value, size, position, M.color(base, style))
end

function M.line(a, b, base, width, style, scale)
  local halo = M.halo(base, style)
  if halo then ui.drawLine(a, b, halo, width + 2 * style.radius * scale) end
  ui.drawLine(a, b, M.color(base, style), width)
end

function M.segment(center, scale, points, base, style)
  -- Main blocks are shared by speed and RPM, so keep two bounded transforms.
  -- Weak keys release old scale geometries when a car/layout changes.
  local views = segmentPositions[points]
  if not views then views = {}; segmentPositions[points] = views end
  local positions
  for _, view in ipairs(views) do
    if view.x == center.x and view.y == center.y and view.scale == scale then positions = view.points; break end
  end
  if not positions then
    positions = {}
    for _, p in ipairs(points) do positions[#positions + 1] = center + vec2(p[1] * scale, p[2] * scale) end
    if #views >= 2 then table.remove(views, 1) end
    views[#views + 1] = {x = center.x, y = center.y, scale = scale, points = positions}
  end
  ui.pathClear()
  for _, p in ipairs(positions) do ui.pathLineTo(p) end
  local halo = M.halo(base, style)
  if halo then
    ui.pathStroke(halo, true, 2 * style.radius * scale)
    ui.pathClear()
    for _, p in ipairs(positions) do ui.pathLineTo(p) end
  end
  ui.pathFillConvex(M.color(base, style))
end

function M.ambient(center, scale, styles, sub)
  if styles.ambient.mult <= 0 then return end
  local radius = sub and I.ambient.subRadius or I.ambient.centerRadius
  for i = I.ambient.layers, 1, -1 do
    ui.drawCircleFilled(center, radius * i / I.ambient.layers * scale, styles.ambient, 32)
  end
end

return M
