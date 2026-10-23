local GeneralSettings = require('src/general_settings')
local Theme = require('src/theme')
local Layout = require('src/car_condition_layout')
local U = require('src/utils')
local TyreTemperature = require('src/tyre_temperature')
local Readouts = require('src/tyre_readouts')

local M = {}
local C = Theme.colors
local effectBlack = rgbm(0, 0, 0, 1)
local effectWhite = rgbm(1, 1, 1, 1)
local lifeFonts = { Regular = 'Consolas;Weight=Regular', Bold = 'Consolas;Weight=Bold' }
local legendY = 12
local carOffsetY = 20
local lifeOutlineOffsets = {
  {-1,0},{1,0},{0,-1},{0,1},
  {-0.7,-0.7},{0.7,-0.7},{-0.7,0.7},{0.7,0.7}
}
local thermalStops = {
  { position = 0, color = rgbm(0.08, 0.16, 0.44, 1) },
  { position = 1, color = rgbm(0.20, 0.47, 0.85, 1) },
  { position = 2, color = rgbm(0.34, 0.78, 0.32, 1) },
  { position = 3, color = rgbm(1, 0.82, 0.16, 1) },
  { position = 4, color = rgbm(0.98, 0.43, 0.12, 1) },
  { position = 5, color = rgbm(0.85, 0.20, 0.16, 1) }
}

local function point(origin, scale, x, y)
  return origin + vec2(x * scale, y * scale)
end

local function withAlpha(color, alpha)
  return Theme.withAlpha(color, U.clamp(alpha, 0, 1))
end

local function linearChannel(value)
  if value <= 0.04045 then return value / 12.92 end
  return ((value + 0.055) / 1.055) ^ 2.4
end

local function luminance(color)
  return linearChannel(color.r) * 0.2126
    + linearChannel(color.g) * 0.7152
    + linearChannel(color.b) * 0.0722
end

local function contrastRatio(a, b)
  local lighter = math.max(luminance(a), luminance(b))
  local darker = math.min(luminance(a), luminance(b))
  return (lighter + 0.05) / (darker + 0.05)
end

local function tyreEffectColor(surface)
  -- Choose a readable effect color on both cold blue and warm fills.
  if contrastRatio(surface, effectBlack) >= contrastRatio(surface, effectWhite) then
    return effectBlack
  end
  return effectWhite
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

local function outlinedLife(text, size, center, scale)
  local measured = ui.measureDWriteText(text, size)
  local position = center - measured / 2
  local spread = math.max(0.75, scale)
  for _, offset in ipairs(lifeOutlineOffsets) do
    ui.dwriteDrawText(text, size,
      position + vec2(offset[1] * spread, offset[2] * spread), effectBlack)
  end
  ui.dwriteDrawText(text, size, position, C.primary)
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

local function thermalColor(position)
  for i = 2, #thermalStops do
    local previous, current = thermalStops[i - 1], thermalStops[i]
    if position <= current.position then
      return mix(previous.color, current.color,
        (position - previous.position) / (current.position - previous.position))
    end
  end
  return thermalStops[#thermalStops].color
end

local function temperatureWindow(wheel, settings, gt3, front)
  local reference = Readouts.references(wheel, gt3, settings, front)
  return reference.minimum, reference.maximum
end

local function temperaturePosition(temperature, minimum, maximum)
  local position = 2
  if temperature < minimum - Layout.tyreBlueOffset then
    position = (temperature - (minimum - Layout.tyreDarkBlueOffset))
      / (Layout.tyreDarkBlueOffset - Layout.tyreBlueOffset)
  elseif temperature < minimum then
    position = 1 + (temperature - (minimum - Layout.tyreBlueOffset)) / Layout.tyreBlueOffset
  elseif temperature > maximum + Layout.tyreOrangeOffset then
    position = 4 + (temperature - maximum - Layout.tyreOrangeOffset)
      / (Layout.tyreRedOffset - Layout.tyreOrangeOffset)
  elseif temperature > maximum + Layout.tyreYellowOffset then
    position = 3 + (temperature - maximum - Layout.tyreYellowOffset)
      / (Layout.tyreOrangeOffset - Layout.tyreYellowOffset)
  elseif temperature > maximum then
    position = 2 + (temperature - maximum) / Layout.tyreYellowOffset
  end
  return position
end

local function temperatureColor(temperature, minimum, maximum)
  if temperature == nil then return C.metalDim end
  return thermalColor(temperaturePosition(temperature, minimum, maximum))
end

local function conditionColor(wheel)
  if not wheel or not wheel.available then return C.outlineDim end
  if wheel.isBlown or (wheel.conditionSeverity or 0) >= Layout.conditionDanger then return C.red end
  if (wheel.conditionSeverity or 0) >= Layout.conditionWarn then return C.amber end
  return C.outlineSoft
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

local function drawTyreSurfaceEffects(origin, scale, x, y, wheel, effectColorAt)
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
    local effectColor = effectColorAt(centerX)
    local radius = 1.25 + dirty * 0.75 + (i % 3) * 0.18
    local shape = dirtPatchShapes[(i - 1) % #dirtPatchShapes + 1]
    drawDirtPatch(origin, scale, centerX, centerY, radius + 1.05, shape,
      withAlpha(effectColor, 0.16 + dirty * 0.16))
    drawDirtPatch(origin, scale, centerX, centerY, radius, shape,
      withAlpha(effectColor, 0.54 + dirty * 0.24))
  end

  -- Grain is shown with short diagonal scuffs, not a color shift that could
  -- be mistaken for tyre temperature.
  local grainCount = math.floor(grain * #grainMarks + 0.5)
  for i = 1, grainCount do
    local mark = grainMarks[i]
    local centerX = x + mark[1] * halfWidth
    local centerY = y + mark[2] * halfHeight
    local effectColor = effectColorAt(centerX)
    drawLine(point(origin, scale, centerX - 2.5, centerY + 1.8),
      point(origin, scale, centerX + 2.5, centerY - 1.8),
      withAlpha(effectColor, 0.50 + grain * 0.32), 1.1 * scale)
  end

  -- Blistering keeps its circular form while using the same contrast color
  -- as dirt and grain, so temperature remains the only color channel.
  local blisterCount = math.floor(blister * #blisterSpots + 0.5)
  for i = 1, blisterCount do
    local spot = blisterSpots[i]
    local effectColor = effectColorAt(x + spot[1] * halfWidth)
    local center = point(origin, scale,
      x + spot[1] * halfWidth, y + spot[2] * halfHeight)
    local radius = (2.4 + blister * 0.9) * scale
    ui.drawCircleFilled(center, radius + 1.4 * scale,
      withAlpha(effectColor, 0.14 + blister * 0.20), 12)
    ui.drawCircleFilled(center, radius, withAlpha(effectColor, 0.38 + blister * 0.30), 12)
    ui.drawCircle(center, radius, withAlpha(effectColor, 0.68 + blister * 0.24), 12, 1.15 * scale)
  end
end

local function sameColor(a, b)
  return a.r == b.r and a.g == b.g and a.b == b.b
end

local function tyreColorAt(x, left, middle, right, colorLeft, colorMiddle, colorRight)
  if x <= middle then return mix(colorLeft, colorMiddle, (x - left) / (middle - left)) end
  return mix(colorMiddle, colorRight, (x - middle) / (right - middle))
end

local function drawTyreGradient(origin, scale, x, y, colorAt, alpha)
  local left, right = x - Layout.tyreWidth / 2, x + Layout.tyreWidth / 2
  local top, bottom = y - Layout.tyreHeight / 2, y + Layout.tyreHeight / 2
  local radius = 4
  local middleColor = withAlpha(colorAt(x), alpha)
  local function band(y1, y2, inset)
    local leftColor, rightColor = withAlpha(colorAt(left + inset), alpha),
      withAlpha(colorAt(right - inset), alpha)
    ui.drawRectFilledMultiColor(point(origin, scale, left + inset, y1),
      point(origin, scale, x, y2), leftColor, middleColor, middleColor, leftColor)
    ui.drawRectFilledMultiColor(point(origin, scale, x, y1),
      point(origin, scale, right - inset, y2), middleColor, rightColor, rightColor, middleColor)
  end
  band(top + radius, bottom - radius, 0)
  -- Native multicolor rectangles have no rounding: clip the two end caps
  -- into small bands following the existing four-unit corner radius.
  local rows = math.max(4, math.min(16, math.ceil(radius * scale)))
  local step = radius / rows
  for i = 0, rows - 1 do
    local distance = radius - (i + 0.5) * step
    local inset = radius - math.sqrt(radius * radius - distance * distance)
    band(top + i * step, top + (i + 1) * step, inset)
    band(bottom - (i + 1) * step, bottom - i * step, inset)
  end
end

local function drawTyre(origin, scale, x, y, name, wheel, state, settings)
  local halfWidth = Layout.tyreWidth / 2
  local halfHeight = Layout.tyreHeight / 2
  local topLeft = point(origin, scale, x - halfWidth, y - halfHeight)
  local bottomRight = point(origin, scale, x + halfWidth, y + halfHeight)
  local colorLeft, colorMiddle, colorRight = C.metalDim, C.metalDim, C.metalDim
  if wheel and wheel.available then
    local minimum, maximum = temperatureWindow(wheel, settings, state.condition.isGT3, y == Layout.frontWheelY)
    local temperature
    if settings.temperatureDisplay == 'surface' then temperature = wheel.temperature
    else temperature = TyreTemperature.generalTemperature(wheel, settings.temperatureCoreWeight) end
    colorMiddle = temperatureColor(temperature, minimum, maximum)
    colorLeft, colorRight = colorMiddle, colorMiddle
    if settings.temperatureDisplay ~= 'uniform'
      and wheel.temperatureInside and wheel.temperatureMiddle and wheel.temperatureOutside then
      local function zoneColor(value)
        if settings.temperatureDisplay ~= 'surface' then
          value = TyreTemperature.zoneTemperature(wheel, value, settings.temperatureCoreWeight)
        end
        return temperatureColor(value, minimum, maximum)
      end
      colorMiddle = zoneColor(wheel.temperatureMiddle)
      local inside = zoneColor(wheel.temperatureInside)
      local outside = zoneColor(wheel.temperatureOutside)
      if x < Layout.carCenterX then colorLeft, colorRight = outside, inside
      else colorLeft, colorRight = inside, outside end
    end
  end
  local stateColor = conditionColor(wheel)
  local punctureLit = wheel and wheel.isBlown
    and math.floor(state.clock / Layout.punctureBlinkPeriod) % 2 == 0
  if punctureLit then colorLeft, colorMiddle, colorRight = C.red, C.red, C.red end
  local function colorAt(sampleX)
    return tyreColorAt(sampleX, x - halfWidth, x, x + halfWidth,
      colorLeft, colorMiddle, colorRight)
  end
  local alpha = wheel and wheel.available and 0.88 or 0.42
  if sameColor(colorLeft, colorMiddle) and sameColor(colorMiddle, colorRight) then
    ui.drawRectFilled(topLeft, bottomRight, withAlpha(colorMiddle, alpha), 4 * scale)
  else
    drawTyreGradient(origin, scale, x, y, colorAt, alpha)
  end
  drawTyreSurfaceEffects(origin, scale, x, y, wheel,
    function(sampleX) return tyreEffectColor(colorAt(sampleX)) end)
  ui.drawRect(topLeft, bottomRight, stateColor, 4 * scale, nil, 2.4 * scale)

  -- Remaining tread stays separate from temperature and uses the same
  -- individually lit blocks as the pedal inspired segmented bar concept.
  local segmentCount = Layout.tyreLifeSegments
  local segmentGap = Layout.tyreLifeSegmentGap
  local railWidth = Layout.tyreLifeRailWidth
  local railX = x < Layout.carCenterX and x - halfWidth - 15 or x + halfWidth + 3
  local railTop = point(origin, scale, railX - 2, y - halfHeight - 2)
  local railBottom = point(origin, scale, railX + railWidth + 2, y + halfHeight + 2)
  ui.drawRect(railTop, railBottom, C.outline, 3 * scale, nil, 1.1 * scale)
  local remaining = wheel and wheel.wearAvailable and U.clamp(wheel.remaining, 0, 1) or 0
  local litSegments = math.floor(remaining * segmentCount + 0.5)
  local segmentHeight = (Layout.tyreHeight - segmentGap * (segmentCount - 1)) / segmentCount
  for segment = 1, segmentCount do
    local bottom = y + halfHeight - (segment - 1) * (segmentHeight + segmentGap)
    local top = bottom - segmentHeight
    ui.drawRectFilled(point(origin, scale, railX, top),
      point(origin, scale, railX + railWidth, bottom),
      segment <= litSegments and C.primary or C.inactive, 0.7 * scale)
  end
  local lifeX = x < Layout.carCenterX and 34 or Layout.width - 34
  local value, unit = Readouts.wheel(wheel, settings, state.condition.isGT3, y == Layout.frontWheelY)
  if value then
    ui.pushDWriteFont(lifeFonts[settings.lifeTextWeight] or lifeFonts.Regular)
    local size = U.clamp(settings.lifeTextSize or 24, 12, 36) * scale
    local measured = ui.measureDWriteText(value, size)
    local availableWidth = 60 * scale
    if measured.x > availableWidth then size = size * availableWidth / measured.x end
    outlinedLife(value, size, point(origin, scale, lifeX, y), scale)
    ui.popDWriteFont()
    centeredText(unit, 9 * scale, point(origin, scale, lifeX, y + 22), C.secondary)
  end

  if wheel and wheel.isBlown then
    drawLine(point(origin, scale, x - 7, y - 13), point(origin, scale, x + 7, y + 13), C.primary, 2 * scale)
    drawLine(point(origin, scale, x + 7, y - 13), point(origin, scale, x - 7, y + 13), C.primary, 2 * scale)
  end

  centeredText(name, 11 * scale,
    point(origin, scale, x, y - halfHeight - 12), C.primary)
end

local function drawBody(origin, scale, condition)
  origin = origin + vec2((Layout.carCenterX - 120) * scale, 0)
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

local function drawStateDrop(origin, scale, fraction)
  local x = 24 + (Layout.width - 48) * U.clamp(fraction, 0, 1)
  local y = legendY
  drawPolygon(origin, scale, {
    {x,y-11},{x+2.5,y-10.3},{x+4,y-8.5},{x+4,y-6.5},{x+2.7,y-4.5},
    {x,y-1},{x-2.7,y-4.5},{x-4,y-6.5},{x-4,y-8.5},{x-2.5,y-10.3}
  }, C.primary, tyreEffectColor(C.primary), 1)
end

local function drawLegend(origin, scale, condition, settings)
  local left, right, y = 24, Layout.width - 24, legendY
  local segments = 96
  for i = 0, segments - 1 do
    local fraction = i / (segments - 1)
    local position = fraction <= 0.5 and fraction * 4 or 2 + (fraction - 0.5) * 6
    ui.drawRectFilled(point(origin, scale, left + (right - left) * i / segments, y),
      point(origin, scale, left + (right - left) * (i + 1) / segments, y + 7),
      thermalColor(position))
  end
  ui.drawRect(point(origin, scale, left, y), point(origin, scale, right, y + 7),
    C.metal, 0, nil, scale)
  local position = 0
  for i = 1, 4 do
    local wheel = condition.wheels[i]
    if not wheel or not wheel.available then return end
    local temperature
    if settings.temperatureDisplay == 'surface' then temperature = wheel.temperature
    else temperature = TyreTemperature.generalTemperature(wheel, settings.temperatureCoreWeight) end
    if temperature == nil then return end
    local minimum, maximum = temperatureWindow(wheel,settings,condition.isGT3,i<=2)
    position = position + U.clamp(temperaturePosition(temperature, minimum, maximum), 0, 5) / 4
  end
  drawStateDrop(origin, scale, position <= 2 and position / 4 or 0.5 + (position - 2) / 6)
end

local function gripStage(remaining, thresholds)
  if not thresholds then return 'HIGH' end
  if remaining > (thresholds.HIGH or 100) then return 'HIGH' end
  if remaining > (thresholds.MEDIUM or 66) then return 'MEDIUM' end
  if remaining > (thresholds.LOW or 33) then return 'LOW' end
  return 'EOL'
end

local function stageColor(stage)
  if stage == 'HIGH' then return C.green end
  if stage == 'MEDIUM' then return C.flagYellow end
  if stage == 'LOW' then return C.amber end
  return C.red
end

local function drawGripPanel(origin, scale, condition, settings, detailHeight)
  local grip = condition.gripDetails
  drawPolygon(origin, scale, {
    {16,32},{Layout.width-16,32},{Layout.width-8,40},{Layout.width-8,detailHeight+24},
    {Layout.width-16,detailHeight+32},{16,detailHeight+32},{8,detailHeight+24},{8,40}
  }, C.panel, C.outline, 1)
  local function detailText(value, size, x, centerY, color, rightAligned, bold)
    if bold then ui.pushDWriteFont(lifeFonts.Bold) end
    size = size * scale
    local measured = ui.measureDWriteText(value, size)
    local maximum = (rightAligned and 162 or Layout.width-48) * scale
    if measured.x > maximum then
      size = size * maximum / measured.x
      measured = ui.measureDWriteText(value, size)
    end
    local position = point(origin, scale, x, centerY)
      - vec2(rightAligned and measured.x or 0, measured.y/2)
    ui.dwriteDrawText(value, size, position, color)
    if bold then ui.popDWriteFont() end
  end
  detailText('TYRE DETAIL',20,24,55,C.primary,false,true)
  local compound = condition.compound or (grip and grip.compound)
  if compound then
    if ui.measureDWriteText(compound,18*scale).x > (Layout.width-48)*scale then
      local truncated = compound
      repeat truncated=truncated:sub(1,-2)
      until #truncated==0 or ui.measureDWriteText(truncated..'...',18*scale).x <= (Layout.width-48)*scale
      compound=truncated..'...'
    end
    detailText(compound,18,24,81,C.primary)
  end
  local stint = condition.stint
  if stint then
    local prefix = stint.approximate and '~' or ''
    detailText('STINT',16,24,108,C.secondary)
    if stint.laps ~= nil and stint.km ~= nil then
      detailText(string.format('%s%d L / %s%.1f KM', prefix, stint.laps, prefix, stint.km),
        18,296,108,C.primary,true,true)
    end
    if stint.observedOnly then detailText('FROM OBSERVATION',13,24,130,C.amber)
    elseif stint.approximate then detailText('~ ESTIMATED STINT',13,24,130,C.amber) end
  end
  local function axleReference(front)
    local name, index = front and 'front' or 'rear', front and 1 or 3
    local wheel = condition.wheels[index]
    if not wheel or not wheel.available then wheel = condition.wheels[index+1] end
    wheel = wheel or {}
    local window = condition.temperatureWindows and condition.temperatureWindows[name]
    return Readouts.references({
      optimumTemperatureMin = window and window.minimum or wheel.optimumTemperatureMin,
      optimumTemperatureMax = window and window.maximum or wheel.optimumTemperatureMax,
      optimumTemperature = wheel.optimumTemperature,
      idealPressure = condition.idealPressures and condition.idealPressures[name] or wheel.idealPressure
    },condition.isGT3,settings,front)
  end
  local front, rear = axleReference(true), axleReference(false)
  detailText('IDEAL PRESSURE',16,24,157,C.secondary)
  for i,reference in ipairs({front,rear}) do
    local y = 179+(i-1)*23
    detailText(i==1 and 'FRONT' or 'REAR',14,24,y,C.secondary)
    detailText((reference.pressureEstimated and '~' or '')
      ..Readouts.formatPressure(reference.idealPressure,settings.pressureUnit)
      ..' '..(settings.pressureUnit or 'psi'),18,296,y,C.primary,true)
  end
  for i,reference in ipairs({front,rear}) do
    local y = 229+(i-1)*23
    detailText(i==1 and 'THERMAL F' or 'THERMAL R',14,24,y,C.secondary)
    local unit = settings.temperatureUnit == 'F' and 'F' or 'C'
    local minimum = Readouts.temperature(reference.minimum,settings.temperatureUnit)
    local maximum = Readouts.temperature(reference.maximum,settings.temperatureUnit)
    detailText(string.format('%s%.0f-%.0f %s',reference.thermalEstimated and '~' or '',minimum,maximum,unit),
      18,296,y,C.primary,true)
  end
  if front.pressureEstimated or rear.pressureEstimated or front.thermalEstimated or rear.thermalEstimated then
    detailText('~ ESTIMATED REFERENCE',12,24,274,C.amber)
  end
  if grip and grip.details then
    detailText('STAGE',16,38,298,C.secondary)
    detailText('KM',16,186,298,C.secondary,true)
    detailText('LAPS',16,296,298,C.secondary,true)
    drawLine(point(origin,scale,24,310),point(origin,scale,296,310),C.outlineSoft,scale)
    for index,threshold in ipairs(grip.details) do
      local y=325+(index-1)*30
      ui.drawRectFilled(point(origin,scale,24,y-4),point(origin,scale,30,y+4),stageColor(threshold.name))
      detailText(threshold.name,16,38,y,C.primary)
      if grip.wearDisabled then detailText('No tyre wear',20,296,y,C.primary,true)
      else
        if threshold.km then detailText(string.format('%.1f',threshold.km),20,186,y,C.primary,true) end
        detailText(threshold.laps and string.format('%.1f',threshold.laps) or '--',20,296,y,C.primary,true)
      end
    end
    drawLine(point(origin,scale,24,431),point(origin,scale,296,431),C.outlineSoft,scale)
    detailText('AVG GRIP',16,24,447,C.primary)
    if grip.average then detailText(string.format('%.1f%%',grip.average),24,296,447,C.primary,true,true) end
  end
end

local function drawGripDetails(origin,scale,condition,settings)
  if not ui.transparentWindow or not ui.windowPos then return end
  local inside = false
  if ui.mouseLocalPos then
    local mouse = ui.mouseLocalPos()
    inside = mouse.x>=origin.x+16*scale and mouse.x<=origin.x+(Layout.width-16)*scale
      and mouse.y>=origin.y+(legendY-8)*scale and mouse.y<=origin.y+(legendY+16)*scale
  end
  if not inside and not settings.keepDetailsOpen and not condition.detailOpen then return end
  local screen = ac.getUI and U.read(ac.getUI(),'windowSize',nil) or nil
  local detailHeight = condition.gripDetails and condition.gripDetails.details and 438 or 260
  -- Keep the whole overlay visible even with a large parent or a small screen.
  local panelScale = scale
  if screen then panelScale=math.min(scale,screen.x/(Layout.width-14),screen.y/detailHeight) end
  local size=vec2((Layout.width-14)*panelScale,detailHeight*panelScale)
  local position=ui.windowPos()+origin+vec2(7*scale,(legendY-14)*scale-size.y)
  position.x=math.max(0,screen and math.min(position.x,screen.x-size.x) or position.x)
  position.y=math.max(0,screen and math.min(position.y,screen.y-size.y) or position.y)
  ui.transparentWindow('##condition-grip-profile',position,size,true,false,function()
    drawGripPanel(vec2(-7*panelScale,-32*panelScale),panelScale,condition,settings,detailHeight)
  end)
end

local function drawGrip(origin,scale,grip)
  local left,right,y=24,Layout.width-24,legendY
  local remaining=grip and grip.remaining or nil
  local thresholds=grip and grip.progressThresholds or nil
  local segments=64
  for index=0,segments-1 do
    local x1=left+(right-left)*index/segments
    local x2=left+(right-left)*(index+1)/segments
    local progress=100-(index+0.5)*100/segments
    local stage=gripStage(progress,thresholds)
    local color=remaining and progress<=remaining and stageColor(stage) or C.inactive
    ui.drawRectFilled(point(origin,scale,x1,y),point(origin,scale,x2,y+7),color)
  end
  if thresholds then
    for _,name in ipairs({'HIGH','MEDIUM','LOW','EOL'}) do
      local value=thresholds[name]
      local x=left+(right-left)*(1-U.clamp(value/100,0,1))
      drawLine(point(origin,scale,x,y-1),point(origin,scale,x,y+8),stageColor(name),1.2*scale)
    end
  end
  if remaining then
    drawStateDrop(origin,scale,1-remaining/100)
  end
end

function M.draw(state, settings)
  C = GeneralSettings.palette(Theme.get(settings.theme, 'condition'), settings.backgroundOpacity)
  local width = ui.windowWidth()
  local height = ui.windowHeight()
  local scale = math.min(width / Layout.width, height / Layout.height)
  local origin = vec2((width - Layout.width * scale) / 2, (height - Layout.height * scale) / 2)
  local condition = state.condition

  ui.pushStyleVarAlpha(settings.opacity or 1)
  ui.pushDWriteFont(Theme.fonts.utility)

  if not condition or not condition.available then
    centeredText('NO CAR DATA', 14 * scale,
      point(origin, scale, Layout.carCenterX, Layout.height / 2), C.secondary)
  else
    local carOrigin = origin + vec2(0, carOffsetY * scale)
    drawBody(carOrigin, scale, condition)
    drawTyre(carOrigin, scale, Layout.leftWheelX, Layout.frontWheelY, 'FL', condition.wheels[1], state, settings)
    drawTyre(carOrigin, scale, Layout.rightWheelX, Layout.frontWheelY, 'FR', condition.wheels[2], state, settings)
    drawTyre(carOrigin, scale, Layout.leftWheelX, Layout.rearWheelY, 'RL', condition.wheels[3], state, settings)
    drawTyre(carOrigin, scale, Layout.rightWheelX, Layout.rearWheelY, 'RR', condition.wheels[4], state, settings)
    local mode = settings.legendMode or (settings.showTemperatureLegend == false and 'none' or 'temperature')
    if mode == 'temperature' then drawLegend(origin,scale,condition,settings)
    elseif mode == 'grip' then drawGrip(origin,scale,condition.gripDetails) end
    drawGripDetails(origin,scale,condition,settings)
  end

  ui.popDWriteFont()
  ui.popStyleVar(1)
end

return M
