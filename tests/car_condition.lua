package.path = './?.lua;./?/init.lua;' .. package.path

local Vec2 = {}
Vec2.__index = Vec2
function Vec2.__add(a, b) return vec2(a.x + b.x, a.y + b.y) end
function Vec2.__sub(a, b) return vec2(a.x - b.x, a.y - b.y) end
function Vec2.__div(a, b) return vec2(a.x / b, a.y / b) end
function vec2(x, y) return setmetatable({ x = x, y = y }, Vec2) end
function rgbm(r, g, b, mult) return { r = r, g = g, b = b, mult = mult } end

local width, height = 320, 280
local texts, rectangles, gradients, pathColors
local fontStack = {}
local function noop() end
ui = {
  windowWidth = function() return width end,
  windowHeight = function() return height end,
  measureDWriteText = function(text, size) return vec2(#text * size * 0.6, size) end,
  dwriteDrawText = function(text, size, position)
    local measured = ui.measureDWriteText(text, size)
    assert(position.x >= 0 and position.y >= 0
      and position.x + measured.x <= width + 0.001
      and position.y + measured.y <= height + 0.001, 'text must fit the window: ' .. text)
    texts[#texts + 1] = { text = text, position = position, size = size, font = fontStack[#fontStack] }
  end,
  drawRectFilled = function(a, b, color)
    rectangles[#rectangles + 1] = { a = a, b = b, color = color }
  end,
  drawRectFilledMultiColor = function(a, b, topLeft, topRight, bottomRight, bottomLeft)
    assert(a.x >= 0 and a.y >= 0 and b.x <= width and b.y <= height,
      'gradient must fit the window')
    assert(topLeft.r == bottomLeft.r and topRight.r == bottomRight.r,
      'temperature gradient must run across tyre width')
    gradients[#gradients + 1] = { a = a, b = b, left = topLeft, right = topRight }
  end,
  drawRect = noop, drawLine = noop, drawCircle = noop, drawCircleFilled = noop,
  drawTriangleFilled = noop, pathClear = noop, pathLineTo = noop,
  pathFillConvex = function(color) pathColors[#pathColors + 1] = color end,
  pathStroke = noop,
  pushDWriteFont = function(font) fontStack[#fontStack + 1] = font end,
  popDWriteFont = function() assert(#fontStack > 0); fontStack[#fontStack] = nil end,
  pushStyleVarAlpha = noop, popStyleVar = noop
}

local Condition = require('ui/car_condition')
local state = { clock = 0, condition = {
  available = true, body = {}, engineDamage = 0, gearboxDamage = 0, wheels = {}
} }
for i, remaining in ipairs({ 0.96, 0.92, 0.78, 0.64 }) do
  state.condition.wheels[i] = {
    available = true, wearAvailable = true, remaining = remaining,
    temperatureRatio = 0.7 + (i - 1) * 0.26, conditionSeverity = 1 - remaining
  }
end

local function draw(theme, settings)
  texts, rectangles, gradients, pathColors = {}, {}, {}, {}
  settings = settings or {}
  -- Existing zone scenarios explicitly exercise the optional surface mode.
  if settings.temperatureDisplay == nil then settings.temperatureDisplay = 'surface' end
  settings.theme, settings.opacity = theme or 'dark', 1
  Condition.draw(state, settings)
  assert(#fontStack == 0, 'life font changes must restore the surrounding font')
end

for _, size in ipairs({ {320, 280}, {240, 210}, {240, 260}, {640, 560} }) do
  width, height = size[1], size[2]
  for _, theme in ipairs({ 'dark', 'light' }) do
    draw(theme)
    local found = {}
    for _, item in ipairs(texts) do found[item.text] = true end
    for _, value in ipairs({ '96', '92', '78', '64' }) do
      assert(found[value], 'each wheel must display its remaining life')
    end
  end
end

width, height = 320, 280
local wheel = state.condition.wheels[1]
wheel.wearAvailable = false
draw()
local missing = false
for _, item in ipairs(texts) do if item.text == '--' then missing = true end end
assert(missing, 'missing wear telemetry must not appear as a measured zero')
wheel.wearAvailable = true
wheel.remaining = 1
draw() -- The widest label, 100, must also fit.

local function surface(temperature, ratio)
  wheel.temperature, wheel.temperatureRatio = temperature, ratio
  draw()
  return rectangles[1].color
end
for _, boundary in ipairs({ 78, 95 }) do
  local before = surface(boundary - 0.001, nil)
  local after = surface(boundary + 0.001, nil)
  for _, channel in ipairs({ 'r', 'g', 'b' }) do
    assert(math.abs(before[channel] - after[channel]) < 0.001,
      'absolute temperature fallback must remain continuous')
  end
end
wheel.optimumTemperatureMin, wheel.optimumTemperatureMax = 75, 85
for _, temperature in ipairs({ 50, 65, 75, 85, 88, 90, 95 }) do
  local before, after = surface(temperature - 0.00001, nil), surface(temperature + 0.00001, nil)
  for _, channel in ipairs({ 'r', 'g', 'b' }) do
    assert(math.abs(before[channel] - after[channel]) < 0.001,
      'thermal palette must interpolate at every stop')
  end
end
local darkBlue, cold, optimum, yellow, orange, hot = surface(50, nil), surface(65, nil),
  surface(80, nil), surface(88, nil), surface(90, nil), surface(95, nil)
assert(darkBlue.b > darkBlue.r and darkBlue.b < cold.b, 'very cold tyres must appear dark blue')
assert(cold.b > cold.r and cold.b > cold.g, 'cold tyres must appear blue')
assert(optimum.g > optimum.r * 1.5 and optimum.g > optimum.b * 1.5,
  '75-85 C GT3 tyres must appear green')
assert(yellow.r > 0.9 and yellow.g > 0.7 and yellow.b < 0.3, '88 C GT3 tyres must appear yellow')
assert(orange.r > 0.9 and orange.g < 0.6 and orange.b < 0.2,
  '90 C GT3 tyres must appear orange, not optimal')
assert(hot.r > hot.g * 1.45, 'overheated tyres must appear red')
local lowerEdge, upperEdge = surface(75, nil), surface(85, nil)
assert(lowerEdge.g == optimum.g and upperEdge.g == optimum.g,
  'both boundaries of the GT3 optimal window must remain green')
wheel.optimumTemperatureMin, wheel.optimumTemperatureMax = nil, nil
local roadOptimum, raceOptimum = surface(85, 1), surface(110, 1)
for _, channel in ipairs({ 'r', 'g', 'b' }) do
  assert(roadOptimum[channel] == raceOptimum[channel],
    'temperature colors must respect each tyre optimum instead of fixed thresholds')
end
-- Other compounds can still use their own working windows.
wheel.optimumTemperatureMin, wheel.optimumTemperatureMax = 80, 100
local gt3Optimal = surface(80, 0.8)
assert(gt3Optimal.g > gt3Optimal.r * 1.5 and gt3Optimal.g > gt3Optimal.b * 1.5,
  '80 C inside the compound optimum window must be green, not pale blue')
wheel.optimumTemperatureMin, wheel.optimumTemperatureMax = nil, nil
wheel.isBlown = true
draw()
assert(rectangles[1].color.r > rectangles[1].color.g * 1.45,
  'puncture must retain the red flashing surface')
state.condition.available = false
draw()
assert(texts[1].text == 'NO CAR DATA', 'missing car data must retain its empty state')

state.condition.available = true
wheel.isBlown = false
for _, tyre in ipairs(state.condition.wheels) do
  tyre.temperature = 80
  tyre.optimumTemperatureMin, tyre.optimumTemperatureMax = 75, 85
  tyre.temperatureInside, tyre.temperatureMiddle, tyre.temperatureOutside = 95, 80, 65
end
local function centralHalves()
  local result = {}
  local scale = math.min(width / 320, height / 280)
  for _, gradient in ipairs(gradients) do
    if gradient.b.y - gradient.a.y > 10 * scale then result[#result + 1] = gradient end
  end
  return result
end
for _, size in ipairs({ {320, 280}, {240, 210}, {240, 260}, {640, 560} }) do
  width, height = size[1], size[2]
  for _, theme in ipairs({ 'dark', 'light' }) do
    draw(theme)
    local halves = centralHalves()
    assert(#halves == 8, 'each tyre must draw a left-to-center and center-to-right gradient')
    for i = 1, 4 do
      local left, right = halves[i * 2 - 1], halves[i * 2]
      assert(left.right.g > left.right.r * 1.5 and right.left.g == left.right.g,
        'middle zone must remain green at the join')
      if i == 1 or i == 3 then
        assert(left.left.b > left.left.r and right.right.r > right.right.g * 1.45,
          'left wheels must show outside blue on left and inside red on right')
      else
        assert(left.left.r > left.left.g * 1.45 and right.right.b > right.right.r,
          'right wheels must show inside red on left and outside blue on right')
      end
      assert(left.left.mult == 0.88 and right.right.mult == 0.88,
        'gradient must retain tyre opacity')
    end
  end
end
width, height = 320, 280
-- Preserve a hot center even when both shoulders are cold.
wheel.temperatureInside, wheel.temperatureMiddle, wheel.temperatureOutside = 65, 95, 65
draw()
local halves = centralHalves()
assert(halves[1].left.b > halves[1].left.r and halves[1].right.r > halves[1].right.g * 1.45
  and halves[2].right.b > halves[2].right.r, 'gradient must preserve the independent middle reading')
-- Identical zones use a solid fill; missing zones use the core fallback.
wheel.temperatureInside, wheel.temperatureMiddle, wheel.temperatureOutside = 95, 95, 95
draw()
assert(#centralHalves() == 6 and rectangles[1].color.r > rectangles[1].color.g * 1.45,
  'equal surface zones must remain uniformly hot despite a cooler core')
wheel.temperatureOutside = nil
draw()
assert(#centralHalves() == 6 and rectangles[1].color.g > rectangles[1].color.r * 1.5,
  'an incomplete surface must use the uniform core temperature')
-- All zone colors share the wheel reference, not a reference inferred per zone.
wheel.optimumTemperatureMin, wheel.optimumTemperatureMax, wheel.optimumTemperature = nil, nil, nil
wheel.temperature, wheel.temperatureRatio = 80, 1
wheel.temperatureInside, wheel.temperatureMiddle, wheel.temperatureOutside = 90, 80, 55
draw()
halves = centralHalves()
assert(halves[1].left.b > halves[1].left.r and halves[2].right.r > halves[2].right.g * 1.45,
  'all zones must use the optimum inferred from the core reading')
wheel.optimumTemperatureMin, wheel.optimumTemperatureMax = 75, 85
wheel.temperatureInside, wheel.temperatureMiddle, wheel.temperatureOutside = 80, 65, 50
wheel.dirty = 1
draw()
local black, white = false, false
for _, color in ipairs(pathColors) do
  black = black or (color.r == 0 and color.g == 0 and color.b == 0)
  white = white or (color.r == 1 and color.g == 1 and color.b == 1)
end
assert(black and white, 'surface marks must adapt their contrast to their local gradient color')
wheel.isBlown = true
state.clock = 0
draw()
assert(#centralHalves() == 6 and rectangles[1].color.r > rectangles[1].color.g * 1.45,
  'lit puncture must replace the gradient with uniform red')
state.clock = 0.2
draw()
assert(#centralHalves() == 8, 'unlit puncture must restore the surface gradient')
wheel.isBlown = false
wheel.dirty = 0
for _, size in ipairs({ {320, 280}, {240, 210}, {640, 560} }) do
  width, height = size[1], size[2]
  for _, numberSize in ipairs({12, 24, 36}) do
    draw('dark', {lifeTextSize = numberSize, lifeTextWeight = 'Bold', showTemperatureLegend = false})
    local lifeFound = false
    for _, item in ipairs(texts) do
      assert(item.text ~= 'COLD' and item.text ~= 'OPT' and item.text ~= 'HOT',
        'hiding temperature scale must hide its labels')
      if item.text == '100' and item.font == 'Consolas;Weight=Bold' then
        lifeFound = true
        assert(item.size <= numberSize * width / 320,
          'life size must follow the configured size and fit its column')
      elseif item.text == 'FL' then
        assert(item.font == 'Consolas;Weight=Regular', 'weight setting must only affect life numbers')
      end
    end
    assert(lifeFound and #centralHalves() == 8,
      'life controls and hidden legend must preserve the surface gradients')
  end
end
width, height = 320, 280
draw('light', {lifeTextSize = 12, lifeTextWeight = 'Regular', showTemperatureLegend = true})
local legendFound, smallLife = false, false
for _, item in ipairs(texts) do
  legendFound = legendFound or item.text == 'COLD'
  smallLife = smallLife or (item.text == '100' and item.size == 12 and item.font == 'Consolas;Weight=Regular')
end
assert(legendFound and smallLife, 'legend and regular smaller life numbers must be selectable')
for _, tyre in ipairs(state.condition.wheels) do
  tyre.temperature, tyre.temperatureCore = 80, 80
  tyre.optimumTemperatureMin, tyre.optimumTemperatureMax = 75, 85
  tyre.temperatureInside, tyre.temperatureMiddle, tyre.temperatureOutside = 50, 65, 75
end
draw('dark', {temperatureDisplay = 'general'})
halves = centralHalves()
assert(#halves == 8 and halves[1].left.g > halves[1].left.r * 1.5
  and halves[1].right.g > halves[1].right.r * 1.5,
  'general zones must preserve a gradient with optimal outside and middle despite cooler shoulders')
assert(halves[2].right.g > halves[2].right.b,
  'core weighting must reduce the cold shoulder color')
assert(halves[3].left.g > halves[3].left.b and halves[4].right.g > halves[4].right.r * 1.5,
  'weighted zones must preserve the mirrored right-wheel orientation')
draw('dark', {temperatureDisplay = 'uniform'})
assert(#gradients == 0 and rectangles[1].color.g > rectangles[1].color.r * 1.5,
  'uniform mode must retain the blended general temperature')
wheel.temperatureInside, wheel.temperatureMiddle, wheel.temperatureOutside = 65, 120, 65
draw('dark', {temperatureDisplay = 'general'})
halves = centralHalves()
assert(halves[1].left.g > halves[1].left.r * 1.5
  and halves[1].right.r > halves[1].right.g
  and halves[2].right.g > halves[2].right.r * 1.5,
  'weighted gradient must preserve a hot middle independently of both shoulders')
wheel.temperatureCore, wheel.temperature = 95, 95
wheel.temperatureInside, wheel.temperatureMiddle, wheel.temperatureOutside = 80, 80, 80
draw('dark', {temperatureDisplay = 'general'})
assert(rectangles[1].color.r > rectangles[1].color.g * 1.45,
  'hot core must remain hot despite optimal surface readings')
wheel.temperatureCore, wheel.temperature = nil, 80
wheel.temperatureInside, wheel.temperatureMiddle, wheel.temperatureOutside = 95, 95, 95
draw('dark', {temperatureDisplay = 'general'})
assert(rectangles[1].color.r > rectangles[1].color.g * 1.45,
  'missing core must use the actual surface average')
wheel.temperatureCore, wheel.temperature = 80, 80
wheel.temperatureInside, wheel.temperatureMiddle, wheel.temperatureOutside = 50, 65, 95
draw('dark', {temperatureDisplay = 'surface'})
assert(#gradients > 0, 'surface mode must remain selectable independently of the general reading')
for _, tyre in ipairs(state.condition.wheels) do
  tyre.temperatureCore, tyre.temperature = 95, 95
  tyre.temperatureInside, tyre.temperatureMiddle, tyre.temperatureOutside = 80, 80, 80
end
for _, mode in ipairs({'general','uniform'}) do
  draw('dark', {temperatureDisplay=mode, temperatureCoreWeight=0})
  assert(rectangles[1].color.g > rectangles[1].color.r * 1.5,
    '0% core must render the optimum surface temperature')
  draw('dark', {temperatureDisplay=mode, temperatureCoreWeight=1})
  assert(rectangles[1].color.r > rectangles[1].color.g * 1.45,
    '100% core must render the overheated core temperature')
end
for _, tyre in ipairs(state.condition.wheels) do
  tyre.temperatureCore, tyre.temperature = 80, 80
  tyre.temperatureInside, tyre.temperatureMiddle, tyre.temperatureOutside = 50, 65, 95
end
texts, rectangles, gradients, pathColors = {}, {}, {}, {}
Condition.draw(state, {theme = 'dark', opacity = 1})
assert(#centralHalves() == 8, 'weighted zone gradient must be the default when no mode is specified')
print('Car condition: life, temperature, four-wheel zone orientation, center readings, fallback, contrast and punctures passed')
