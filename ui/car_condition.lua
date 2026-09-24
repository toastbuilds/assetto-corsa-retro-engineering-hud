local Theme = require('src/theme')
local Layout = require('src/car_condition_layout')
local U = require('src/utils')

local M = {}
local C = Theme.colors

local function point(origin, scale, x, y)
  return origin + vec2(x * scale, y * scale)
end

local function withAlpha(color, alpha)
  return Theme.withAlpha(color, U.clamp(alpha, 0, 1))
end

local function mix(a, b, amount)
  amount = U.clamp(amount, 0, 1)
  return rgbm(
    a.r + (b.r - a.r) * amount,
    a.g + (b.g - a.g) * amount,
    a.b + (b.b - a.b) * amount,
    (a.mult or 1) + ((b.mult or 1) - (a.mult or 1)) * amount)
end

local function centeredText(text, size, center, color)
  local measured = ui.measureDWriteText(text, size)
  ui.dwriteDrawText(text, size, center - measured / 2, color)
end

local function drawLine(a, b, color, width)
  ui.drawLine(a, b, color, width)
end

local function drawPolygon(origin, scale, coordinates, fill, stroke, width)
  ui.pathClear()
  for _, coordinate in ipairs(coordinates) do
    ui.pathLineTo(point(origin, scale, coordinate[1], coordinate[2]))
  end
  ui.pathFillConvex(fill)
  ui.pathClear()
  for _, coordinate in ipairs(coordinates) do
    ui.pathLineTo(point(origin, scale, coordinate[1], coordinate[2]))
  end
  ui.pathStroke(stroke, true, width * scale)
end

local function damageColor(value)
  value = U.clamp(value or 0, 0, 1)
  if value >= Layout.conditionDanger then return C.red end
  if value >= Layout.conditionWarn then return C.amber end
  if value > 0.04 then return C.flagYellow end
  return C.outlineDim
end

local function damageFill(value)
  value = U.clamp(value or 0, 0, 1)
  if value <= 0.04 then return C.panelRaised end
  return withAlpha(damageColor(value), 0.20 + value * 0.34)
end

local function temperatureColor(wheel)
  if not wheel or not wheel.temperatureRatio then return C.metalDim end
  local temperature = wheel.temperature
  if temperature and temperature >= Layout.tyreHotTemperature then
    return C.red
  end
  local ratio = wheel.temperatureRatio
  if temperature and temperature >= Layout.tyreWarmTemperature then
    ratio = math.max(ratio, Layout.tyreOptimumLowRatio)
  end
  if ratio <= Layout.tyreColdRatio then return C.cyan end
  if ratio < Layout.tyreOptimumLowRatio then
    return mix(C.cyan, C.green,
      (ratio - Layout.tyreColdRatio) / (Layout.tyreOptimumLowRatio - Layout.tyreColdRatio))
  end
  if ratio <= Layout.tyreOptimumHighRatio then return C.green end
  if ratio < Layout.tyreHotRatio then
    return mix(C.green, C.amber,
      (ratio - Layout.tyreOptimumHighRatio) / (Layout.tyreHotRatio - Layout.tyreOptimumHighRatio))
  end
  return mix(C.amber, C.red, U.clamp((ratio - Layout.tyreHotRatio) / 0.24, 0, 1))
end

local function conditionColor(wheel)
  if not wheel or not wheel.available then return C.outlineDim end
  if wheel.isBlown or (wheel.conditionSeverity or 0) >= Layout.conditionDanger then return C.red end
  if (wheel.conditionSeverity or 0) >= Layout.conditionWarn then return C.amber end
  return C.green
end

local dirtSpeckles = {
  { -0.55, -0.78 }, { 0.43, -0.73 }, { -0.12, -0.61 }, { 0.68, -0.45 },
  { -0.48, -0.34 }, { 0.15, -0.18 }, { -0.65, 0.02 }, { 0.48, 0.16 },
  { -0.22, 0.34 }, { 0.62, 0.55 }, { -0.50, 0.71 }, { 0.10, 0.80 }
}

local dirtPatchShapes = {
  { { -0.92, -0.34 }, { -0.20, -0.94 }, { 0.78, -0.52 }, { 0.70, 0.46 }, { -0.28, 0.88 }, { -0.96, 0.24 } },
  { { -0.84, -0.12 }, { -0.38, -0.86 }, { 0.58, -0.66 }, { 0.94, 0.12 }, { 0.30, 0.82 }, { -0.68, 0.60 } },
  { { -0.90, -0.48 }, { 0.06, -0.90 }, { 0.88, -0.18 }, { 0.52, 0.82 }, { -0.48, 0.74 }, { -0.96, 0.06 } }
}

local grainMarks = {
  { -0.34, -0.76 }, { 0.30, -0.58 }, { -0.12, -0.40 }, { 0.22, -0.22 },
  { -0.30, -0.04 }, { 0.08, 0.14 }, { 0.32, 0.32 }, { -0.16, 0.50 },
  { 0.22, 0.68 }, { -0.28, 0.78 }
}

local blisterSpots = {
  { -0.42, -0.70 }, { 0.30, -0.58 }, { -0.08, -0.34 }, { 0.44, -0.12 },
  { -0.40, 0.12 }, { 0.12, 0.30 }, { 0.46, 0.53 }, { -0.24, 0.71 }
}

local function drawDirtPatch(origin, scale, x, y, radius, shape, color)
  ui.pathClear()
  for _, vertex in ipairs(shape) do
    ui.pathLineTo(point(origin, scale,
      x + vertex[1] * radius, y + vertex[2] * radius))
  end
  ui.pathFillConvex(color)
end

local function drawTyreSurfaceEffects(origin, scale, x, y, wheel)
  if not wheel or not wheel.available then return end

  local halfWidth = Layout.tyreWidth / 2 - 3
  local halfHeight = Layout.tyreHeight / 2 - 4
  local dirty = U.clamp(wheel.dirty or 0, 0, 1)
  local grain = U.clamp(wheel.grain or 0, 0, 1)
  local blister = U.clamp(wheel.blister or 0, 0, 1)

  -- Dirt uses filled angular patches: a deliberately different silhouette
  -- from grain scratches and the outlined circular blistering.
  local dirtCount = math.floor(dirty * #dirtSpeckles + 0.5)
  if dirty >= 0.05 then dirtCount = math.max(dirtCount, 1) end
  for i = 1, dirtCount do
    local mark = dirtSpeckles[i]
    local centerX = x + mark[1] * halfWidth
    local centerY = y + mark[2] * halfHeight
    local radius = 1.25 + dirty * 0.75 + (i % 3) * 0.18
    local shape = dirtPatchShapes[(i - 1) % #dirtPatchShapes + 1]
    drawDirtPatch(origin, scale, centerX, centerY, radius + 1.05, shape,
      withAlpha(C.secondary, 0.20 + dirty * 0.18))
    drawDirtPatch(origin, scale, centerX, centerY, radius, shape,
      withAlpha(C.outline, 0.52 + dirty * 0.24))
  end

  -- Grain is shown with short diagonal scuffs, not a color shift that could
  -- be mistaken for tyre temperature.
  local grainCount = math.floor(grain * #grainMarks + 0.5)
  for i = 1, grainCount do
    local mark = grainMarks[i]
    local centerX = x + mark[1] * halfWidth
    local centerY = y + mark[2] * halfHeight
    drawLine(point(origin, scale, centerX - 2.5, centerY + 1.8),
      point(origin, scale, centerX + 2.5, centerY - 1.8),
      withAlpha(C.amber, 0.24 + grain * 0.34), 0.9 * scale)
  end

  -- Blistering appears as large, bright raised spots. The warm core makes
  -- them legible over both cold and hot temperature fills.
  local blisterCount = math.floor(blister * #blisterSpots + 0.5)
  for i = 1, blisterCount do
    local spot = blisterSpots[i]
    local center = point(origin, scale,
      x + spot[1] * halfWidth, y + spot[2] * halfHeight)
    local radius = (2.4 + blister * 0.9) * scale
    ui.drawCircleFilled(center, radius + 1.4 * scale,
      withAlpha(C.amber, 0.14 + blister * 0.20), 12)
    ui.drawCircleFilled(center, radius, withAlpha(C.red, 0.42 + blister * 0.28), 12)
    ui.drawCircle(center, radius, withAlpha(C.primary, 0.64 + blister * 0.24), 12, 1.15 * scale)
  end
end

local function drawTyre(origin, scale, x, y, name, wheel, state)
  local halfWidth = Layout.tyreWidth / 2
  local halfHeight = Layout.tyreHeight / 2
  local topLeft = point(origin, scale, x - halfWidth, y - halfHeight)
  local bottomRight = point(origin, scale, x + halfWidth, y + halfHeight)
  local tempColor = temperatureColor(wheel)
  local stateColor = conditionColor(wheel)
  local punctureLit = wheel and wheel.isBlown
    and math.floor(state.clock / Layout.punctureBlinkPeriod) % 2 == 0

  ui.drawRectFilled(topLeft, bottomRight,
    withAlpha(punctureLit and C.red or tempColor, wheel and wheel.available and 0.88 or 0.42),
    4 * scale)
  drawTyreSurfaceEffects(origin, scale, x, y, wheel)
  ui.drawRect(topLeft, bottomRight, stateColor, 4 * scale, nil, 2.4 * scale)

  -- Remaining tread is a separate state channel so temperature never hides wear.
  local railX = x < Layout.carCenterX and x - halfWidth - 5 or x + halfWidth + 3
  local railTop = point(origin, scale, railX, y - halfHeight)
  local railBottom = point(origin, scale, railX + 2, y + halfHeight)
  ui.drawRectFilled(railTop, railBottom, C.inactive)
  local remaining = wheel and wheel.wearAvailable and U.clamp(wheel.remaining, 0, 1) or 0
  local fillTop = y + halfHeight - Layout.tyreHeight * remaining
  ui.drawRectFilled(point(origin, scale, railX, fillTop), railBottom, stateColor)

  if wheel and wheel.isBlown then
    drawLine(point(origin, scale, x - 7, y - 13), point(origin, scale, x + 7, y + 13), C.primary, 2 * scale)
    drawLine(point(origin, scale, x + 7, y - 13), point(origin, scale, x - 7, y + 13), C.primary, 2 * scale)
  end

  -- Temperature is communicated by the tyre fill color; keep the compact
  -- condition app free of a numeric temperature readout.
  centeredText(name, 11 * scale,
    point(origin, scale, x, y - halfHeight - 12), C.primary)
end

local function drawBody(origin, scale, condition)
  local front = condition.body.front or 0
  local rear = condition.body.rear or 0
  local left = condition.body.left or 0
  local right = condition.body.right or 0

  drawPolygon(origin, scale, {
    { 120, 24 }, { 143, 37 }, { 154, 73 }, { 151, 196 },
    { 139, 222 }, { 101, 222 }, { 89, 196 }, { 86, 73 }, { 97, 37 }
  }, C.panel, C.metal, 2)

  drawPolygon(origin, scale, {
    { 120, 29 }, { 139, 41 }, { 147, 69 }, { 93, 69 }, { 101, 41 }
  }, damageFill(front), damageColor(front), 1.4)
  drawPolygon(origin, scale, {
    { 93, 73 }, { 106, 70 }, { 106, 194 }, { 96, 207 }, { 91, 193 }
  }, damageFill(left), damageColor(left), 1.4)
  drawPolygon(origin, scale, {
    { 147, 73 }, { 134, 70 }, { 134, 194 }, { 144, 207 }, { 149, 193 }
  }, damageFill(right), damageColor(right), 1.4)
  drawPolygon(origin, scale, {
    { 96, 207 }, { 106, 192 }, { 134, 192 }, { 144, 207 }, { 136, 217 }, { 104, 217 }
  }, damageFill(rear), damageColor(rear), 1.4)

  drawPolygon(origin, scale, {
    { 106, 78 }, { 134, 78 }, { 139, 107 }, { 134, 162 },
    { 106, 162 }, { 101, 107 }
  }, C.surface, C.outlineSoft, 1.2)

  local engineDamage = condition.engineDamage or 0
  local gearboxDamage = condition.gearboxDamage or 0
  centeredText('ENG', 10 * scale, point(origin, scale, 120, 102), damageColor(engineDamage))
  centeredText(string.format('%d', U.round((1 - engineDamage) * 100)), 15 * scale,
    point(origin, scale, 120, 120), damageColor(engineDamage))
  centeredText('GBX', 9 * scale, point(origin, scale, 120, 148), damageColor(gearboxDamage))
  centeredText(string.format('%d', U.round((1 - gearboxDamage) * 100)), 12 * scale,
    point(origin, scale, 120, 164), damageColor(gearboxDamage))

  ui.drawTriangleFilled(point(origin, scale, 120, 12), point(origin, scale, 114, 20),
    point(origin, scale, 126, 20), C.secondary)
end

local function drawLegend(origin, scale)
  local y = 246
  local items = {
    { x = 42, label = 'COLD', color = C.cyan },
    { x = 120, label = 'OPT', color = C.green },
    { x = 196, label = 'HOT', color = C.red }
  }
  for _, item in ipairs(items) do
    ui.drawCircleFilled(point(origin, scale, item.x - 19, y), 3.5 * scale, item.color, 12)
    centeredText(item.label, 9 * scale, point(origin, scale, item.x + 5, y), C.secondary)
  end
end

function M.draw(state, settings)
  C = Theme.get(settings.theme)
  local width = ui.windowWidth()
  local height = ui.windowHeight()
  local scale = math.min(width / Layout.width, height / Layout.height)
  local origin = vec2((width - Layout.width * scale) / 2, (height - Layout.height * scale) / 2)
  local condition = state.condition

  ui.pushStyleVarAlpha(settings.opacity or 1)
  ui.pushDWriteFont(Theme.fonts.utility)

  if not condition or not condition.available then
    centeredText('NO CAR DATA', 14 * scale, point(origin, scale, 120, 130), C.secondary)
  else
    drawBody(origin, scale, condition)
    drawTyre(origin, scale, Layout.leftWheelX, Layout.frontWheelY, 'FL', condition.wheels[1], state)
    drawTyre(origin, scale, Layout.rightWheelX, Layout.frontWheelY, 'FR', condition.wheels[2], state)
    drawTyre(origin, scale, Layout.leftWheelX, Layout.rearWheelY, 'RL', condition.wheels[3], state)
    drawTyre(origin, scale, Layout.rightWheelX, Layout.rearWheelY, 'RR', condition.wheels[4], state)
    drawLegend(origin, scale)
  end

  ui.popDWriteFont()
  ui.popStyleVar(1)
end

return M
