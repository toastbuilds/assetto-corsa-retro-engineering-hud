package.path = './?.lua;./?/init.lua;' .. package.path

local Vec = {}
Vec.__index = Vec
function vec2(x, y) return setmetatable({ x = x or 0, y = y or 0 }, Vec) end
function Vec.__add(a, b) return vec2(a.x + b.x, a.y + b.y) end
function Vec.__sub(a, b) return vec2(a.x - b.x, a.y - b.y) end
function Vec.__mul(a, b)
  if type(a) == 'number' then return vec2(a * b.x, a * b.y) end
  return vec2(a.x * b, a.y * b)
end

function rgbm(r, g, b, mult) return { r = r, g = g, b = b, mult = mult } end

local stores, drawnText, rectangles = {}, {}, {}
ac = { storage = function(defaults, prefix)
  local store = stores[prefix] or {}
  stores[prefix] = store
  for key, value in pairs(defaults) do if store[key] == nil then store[key] = value end end
  return store
end }

local width, height = 1280, 220
local function noop() end
ui = {
  windowWidth = function() return width end,
  windowHeight = function() return height end,
  measureDWriteText = function(text, size) return vec2(#tostring(text) * size * 0.55, size) end,
  dwriteDrawText = function(value) drawnText[#drawnText + 1] = tostring(value) end,
  pushStyleVarAlpha = noop, popStyleVar = noop, pushDWriteFont = noop, popDWriteFont = noop,
  pathClear = noop, pathLineTo = noop, pathFillConvex = noop, pathStroke = noop, pathArcTo = noop,
  drawLine = noop, drawRect = noop,
  drawRectFilled = function(a,b) rectangles[#rectangles+1]={a=a,b=b} end,
  drawCircleFilled = noop, drawCircle = noop,
}

local Settings = require('modules/dash/src/settings')
local Dash = require('modules/dash/main')
local PedalHistory = require('src/pedal_history')
local GeneralSettings = require('src/general_settings')
local Instruments = require('modules/dash/src/instruments')
local nineThousandMarks=Instruments.rpmMarks({rpmGaugeLimiter=9000})
assert(nineThousandMarks[2]==1 and nineThousandMarks[#nineThousandMarks]==9,
  'car-specific RPM scales should retain whole-thousand labels')

assert(Settings.current().style == 'rpm-top')
Settings.values.sideShowSteering = false
Settings.values.rpmTopShowPedals = false
assert(Settings.current().sideShowSteering == false)
assert(Settings.current().rpmTopShowPedals == false)

local history = PedalHistory.new()
PedalHistory.update(history, 1 / 30, 0.7, 0.3)
local state = {
  available = true, speedText = '139', speedUnit = 'km/h', gearText = '2', gear = 2,
  rpm = 6200, rpmDisplayLimiter = 8000, rpmGaugeNormalized = 0.775, rpmRedlineFraction = 0.96,
  fuel = 12.4, maxFuel = 60, fuelNormalized = 12.4 / 60,
  turboAvailable = true, turboBoost = 2.1, turboDisplayMax = 2.5,
  brake = 0.3, throttle = 0.7, steeringInput = 0.2, steeringAngle = 108, steeringAvailable = true,
  focusedCarIndex = 0, pedalHistory = history,
  tcSupported = true, tcActive = false, absSupported = true, absActive = false,
  pitLane = false, pitLaneAvailable = true, pitLimiter = false, lightsAvailable = true, headlights = true,
  engineLifeLeft = 1000, engineWarning = false, hybrid = { charge = 0.65 },
}

Dash.windowMain(state)
local foundConvertedBoost = false
for _, value in ipairs(drawnText) do
  if value == '30.5 psi' then foundConvertedBoost = true end
end
assert(foundConvertedBoost, 'boost should use the shared pressure unit')
for _, value in ipairs(drawnText) do
  assert(not value:find('6200',1,true), 'RPM bar should not repeat the numeric RPM readout')
end
local tallRpmBlocks, pedalTop, pedalBottom = false, math.huge, -math.huge
for _, rectangle in ipairs(rectangles) do
  if rectangle.a.x>=402 and rectangle.b.x<=878 and rectangle.a.y==32 then
    tallRpmBlocks = tallRpmBlocks or rectangle.b.y-rectangle.a.y>=20
  end
  if rectangle.a.x==21 and rectangle.b.x==35 then
    pedalTop=math.min(pedalTop,rectangle.a.y)
    pedalBottom=math.max(pedalBottom,rectangle.b.y)
  end
end
assert(tallRpmBlocks and pedalBottom-pedalTop>150,
  'RPM blocks and pedal columns must retain the requested taller geometry')

state.turboBoost,state.throttle=0,0.2
local vacuum=Instruments.boost(state,'psi')
assert(vacuum.available and vacuum.simulated and vacuum.value<0 and vacuum.fraction<vacuum.zero,
  'closed-throttle turbo vacuum should illuminate the negative side of zero')
assert(vacuum.valueText=='~-5.8 psi' and Instruments.pressureText(vacuum.value,'kPa')=='-40',
  'estimated vacuum should be marked and converted in every pressure unit')
state.turboAvailable=false
assert(not Instruments.boost(state,'bar').available, 'naturally aspirated cars must not gain simulated boost')
state.turboAvailable,state.turboBoost,state.throttle=true,2.1,0.7

Settings.values.style = 'side-tach'
Dash.windowMain(state)
width, height = 900, 160
Settings.values.sideShowSteering = true
Settings.values.sideShowPedals = true
Settings.values.sideShowIndicators = true
Dash.windowMain(state)

state.available = false
state.hybrid = nil
Dash.windowMain(state)

GeneralSettings.values.theme = 'light'
Dash.windowMain(state)

print('Dashboard layouts, settings, availability and unit formatting passed')
