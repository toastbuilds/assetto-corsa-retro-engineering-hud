-- Reuse the established CSP draw recorder and regression suite.
local harness = dofile('tests/gt7_layouts.lua')
local Telemetry = require('src/telemetry')
local Presentation = require('src/instrument_state')
local Config = require('src/instrument_config')
local Needle = require('ui/instrument_needle')
local Theme = require('src/theme')
local Preview = require('src/instrument_preview')
local Settings = require('src/gt7_settings')
local state = harness.state
state.available, state.maxFuel, state.rpmText = true, 50, '5200'
local settings = { gt7SpeedNeedleMode = 'analog', gt7RpmNeedleMode = 'analog',
  gt7SimulateVacuum = true, gt7VacuumMinimum = -0.5, fallbackRpm = 8000,
  speedUnit = 'km/h', rpmWarningFraction = 0.86, rpmRedlineFraction = 0.96 }
local function near(a, b) return math.abs(a - b) < 0.00001 end

-- Neither presentation modes nor presets are allowed to retarget the springs.
local speed, rpm, boost = state.gt7SpeedNeedleNormalized, state.gt7RpmNeedleNormalized, state.boostNeedleNormalized
Presentation.update(state, settings, 0)
settings.gt7SpeedNeedleMode, settings.gt7RpmNeedleMode = 'digital', 'digital'
state.headlights, state.lightsAvailable = true, true
Presentation.update(state, settings, 0.05)
assert(state.gt7Instruments.speedDigital > 0 and state.gt7Instruments.speedDigital < 1)
assert(state.gt7Instruments.light > 0 and state.gt7Instruments.light < 1,
  'vehicle lights must interpolate instead of switching instantly')
for _ = 1, 30 do Presentation.update(state, settings, 1 / 60) end
assert(state.gt7Instruments.light == 1 and state.gt7Instruments.speedDigital == 1)
assert(state.gt7SpeedNeedleNormalized == speed and state.gt7RpmNeedleNormalized == rpm
  and state.boostNeedleNormalized == boost, 'visual changes must preserve existing spring values')
state.headlights = false
for _ = 1, 30 do Presentation.update(state, settings, 1 / 60) end
assert(state.gt7Instruments.light == 0)
state.headlights, state.lightsAvailable = true, false
Presentation.update(state, settings, 0.5)
assert(state.gt7Instruments.light == 0, 'missing light telemetry must stay OFF')

state.turboBoost, state.throttle, state.rpm = 0, 0, 3000
local value, minimum, maximum, simulated = Presentation.boost(state, settings)
assert(value == -0.5 and minimum == -0.5 and maximum == 1.5 and simulated)
state.throttle = 0.5
assert(Presentation.boost(state, settings) == -0.25)
state.throttle = 1
assert(Presentation.boost(state, settings) == 0)
state.turboBoost = 0.03
assert(Presentation.boost(state, settings) == 0.03, 'even a small positive measured boost takes priority')
state.turboBoost, state.rpm = 0, 0
assert(Presentation.boost(state, settings) == 0, 'stopped engines must not generate vacuum')
state.rpm, state.throttle = 3000, 0
settings.gt7SimulateVacuum = false
assert(Presentation.boost(state, settings) == 0)
settings.gt7SimulateVacuum = true
state.gt7Instruments = nil
for _ = 1, 100 do Presentation.update(state, settings, 1 / 60) end
assert(near(state.gt7Instruments.vacuum, 0.5) and state.gt7Instruments.boostSimulated)
state.turboAvailable = false
Presentation.update(state, settings, 1 / 60)
assert(state.gt7Instruments.vacuum == 0 and state.gt7Instruments.vacuumVelocity == 0)

-- Observe actual needle primitives: nine shapes, but identical value/angle.
local signatures = {}
local originalLine, originalFill, originalCircle = ui.drawLine, ui.pathFillConvex, ui.drawCircle
local originalPath = ui.pathLineTo
local signature, points
ui.drawLine = function(a, b, color, width)
  signature[#signature + 1] = string.format('L%.3f,%.3f,%.3f,%.3f,%.3f', a.x, a.y, b.x, b.y, width)
  originalLine(a, b, color, width)
end
ui.pathLineTo = function(p) points[#points + 1] = string.format('%.3f,%.3f', p.x, p.y); originalPath(p) end
ui.pathFillConvex = function(color)
  signature[#signature + 1] = 'P' .. table.concat(points, ';'); points = {}; originalFill(color)
end
ui.drawCircle = function(p, radius, color, n, width)
  signature[#signature + 1] = string.format('C%.3f,%.3f,%.3f', p.x, p.y, radius)
  originalCircle(p, radius, color, n, width)
end
for _, id in ipairs(Config.needleOrder) do
  signature, points = {}, {}
  Needle.draw(vec2(0, 0), 1, 0, Config.needlePreset(id), Theme.colors, 0)
  local key = table.concat(signature, '|')
  assert(not signatures[key], id .. ' must have genuinely different geometry')
  signatures[key] = true
end
ui.drawLine, ui.pathFillConvex, ui.drawCircle, ui.pathLineTo = originalLine, originalFill, originalCircle, originalPath

-- Missing/low fuel, warning zones, center values and all frame compositions.
local function contains(calls, value)
  for _, call in ipairs(calls) do if call.kind == 'text' and call.text == value then return true end end
end
state.rpm, state.rpmText, state.speedText, state.speedValue = 5200, '5200', '139', 139
state.turboAvailable, state.turboBoost, state.gt7Instruments = true, 0.7, nil
state.fuel, state.maxFuel, state.fuelNormalized = 30, 50, 0.6
local digital = harness.draw('classic', { gt7SpeedNeedleMode = 'digital', gt7RpmNeedleMode = 'digital' })
assert(contains(digital, '139') and contains(digital, '5200') and contains(digital, 'RPM'))
local analog = harness.draw('classic', { gt7SpeedNeedleMode = 'analog', gt7RpmNeedleMode = 'analog' })
assert(not contains(analog, '5200'), 'Analog must present the principal value through the hand and scale')
for _, x in ipairs({175, 1265}) do
  local container, printedScale, rimCount, ledCount = nil, nil, 0, 0
  for _, call in ipairs(analog) do
    if call.kind == 'arc' and near(call.a.x, x) and near(call.a.y, 258 + Config.sub.offsetY) then
      if near(call.radius, Config.sub.housingRadius) then container = call end
      if near(call.radius, Config.sub.analogRadius) then printedScale = call end
    end
    if call.kind == 'circle' and near(call.a.x, x) and near(call.a.y, 258) and call.radius >= 158 then
      assert(call.radius == 174 or call.radius == 166 or call.radius == 158, 'retain the original bezel radii')
      rimCount = rimCount + 1
    end
    if call.kind == 'polygon' and #call.points == 4 then
      local segment = true
      for _, p in ipairs(call.points) do
        local distance = math.sqrt((p.x-x)^2 + (p.y-258-Config.sub.offsetY)^2)
        if distance < Config.sub.analogRadius-Config.sub.segmentDepth-0.01 or distance > Config.sub.analogRadius+0.01 then
          segment = false
        end
      end
      if segment then ledCount = ledCount + 1 end
    end
  end
  assert(container and printedScale and near(container.a.y, printedScale.a.y),
    'fuel/boost analog scale must be concentric with its housing')
  assert(rimCount == 3, 'new instrument layers must not add rings to the original bezel')
  assert(ledCount == Config.sub.segmentCount, 'fuel/boost fill must cover the printed scale at the same radius')
end
-- Analog redline stays segmented, and only lights at the real threshold.
local oldFraction = state.rpmGaugeNormalized
local colors = Theme.get('dark')
for _, sample in ipairs({{0.5, colors.redDim}, {1, colors.red}}) do
  state.rpmGaugeNormalized = sample[1]
  local count = 0
  local calls = harness.draw('classic', {gt7RpmNeedleMode='analog'})
  for _, call in ipairs(calls) do
    if call.kind == 'polygon' and #call.points == 4 then
      local segment = true
      for _, p in ipairs(call.points) do
        local distance = math.sqrt((p.x-1265)^2 + (p.y-258)^2)
        if distance < Config.dial.segmentRadius-Config.dial.segmentDepth-0.01
            or distance > Config.dial.segmentRadius+0.01 then segment = false end
      end
      if segment then
        count = count + 1
        assert(call.color.r == sample[2].r and call.color.g == sample[2].g and call.color.b == sample[2].b)
      end
    end
  end
  assert(count >= 2, 'analog redline requires visible digital blocks')
end
state.rpmGaugeNormalized = oldFraction
for _, x in ipairs({175,1265}) do
  local count = 0
  for _, call in ipairs(analog) do
    if call.kind == 'circle_fill' and near(call.radius, Config.dial.innerDotRadius) then
      local distance = math.sqrt((call.a.x-x)^2 + (call.a.y-258)^2)
      if near(distance, Config.dial.innerRadius) then count = count + 1 end
    end
    assert(not (call.kind == 'arc' and near(call.a.x,x) and near(call.a.y,258)
      and near(call.radius,Config.dial.innerRadius)), 'analog inner scale must not be a continuous line')
  end
  assert(count >= 9, 'inner scale dots must follow numeric graduations')
end
state.fuel, state.maxFuel = nil, nil
assert(contains(harness.draw('classic'), 'N/A'), 'missing fuel must be distinct from an empty tank')
state.turboAvailable = false
assert(contains(harness.draw('classic'), 'NAT ASP'))
state.fuel, state.maxFuel, state.fuelNormalized = 5, 50, 0.1
state.turboAvailable = true
local cases = 0
for _, id in ipairs(Config.needleOrder) do
  for _, frame in ipairs({ 'classic', 'modern', 'outer_pedals', 'steering_dial' }) do
    for _, theme in ipairs({ 'dark', 'light' }) do
      for _, mode in ipairs({ 'analog', 'digital' }) do
        for _, lights in ipairs({ false, true }) do
          state.headlights, state.lightsAvailable = lights, true
          local calls = harness.draw(frame, { gt7SpeedNeedleMode = mode, gt7RpmNeedleMode = mode,
            gt7SpeedNeedleStyle = id, gt7RpmNeedleStyle = id, theme = theme,
            gt7SimulateVacuum = true, gt7VacuumMinimum = -0.5 }, state, {720, 360})
          for _, call in ipairs(calls) do
            local pts = call.points or {}
            local function check(p)
              if p then assert(p.x >= 0 and p.x <= 720 and p.y >= 0 and p.y <= 360,
                'instruments must stay inside the fitted HUD') end
            end
            check(call.a); check(call.b)
            for _, p in ipairs(pts) do check(p) end
          end
          cases = cases + 1
        end
      end
    end
  end
end

Settings.values.gt7SpeedNeedleStyle, Settings.values.gt7RpmNeedleStyle = 'skeleton', 'paddle'
assert(Settings.current().gt7SpeedNeedleStyle == 'skeleton' and Settings.current().gt7RpmNeedleStyle == 'paddle')
package.loaded['src/gt7_settings'] = nil
Settings = require('src/gt7_settings')
assert(Settings.current().gt7SpeedNeedleStyle == 'skeleton', 'new styles must survive storage proxy reload')
Settings.values.gt7RpmNeedleStyle = 'invalid'
assert(Settings.current().gt7RpmNeedleStyle == 'classic' and Settings.current().gt7SpeedNeedleStyle == 'skeleton')

-- Visual controls preserve calibration and central geometry, and fit every frame.
local Geometry = require('src/instrument_layout')
local Layouts = require('src/gt7_retro_layout')
for _, frame in ipairs({'classic', 'modern', 'outer_pedals', 'steering_dial'}) do
  local base = Layouts.resolve(Layouts.preset(frame))
  for _, factor in ipairs({0.75, 1, 1.25}) do
    for _, spacing in ipairs({0, 80, 160}) do
      local options = {gt7DialScale=factor, gt7DialSpacing=spacing,
        gt7IndicatorScale=spacing == 160 and 1.5 or (spacing == 80 and 0.65 or 1)}
      local adjusted = Geometry.resolve(base, options)
      if options.gt7IndicatorScale > 1 then
        assert(adjusted.statusY - 23 * options.gt7IndicatorScale > base.pedalTop + base.pedalHeight,
          'enlarged lower indicators must clear the pedal bars')
      end
      assert(adjusted.speedCenterX == base.speedCenterX and adjusted.gearCenterX == base.gearCenterX)
      assert(adjusted.gaugeStart == base.gaugeStart and adjusted.gaugeEnd == base.gaugeEnd)
      assert(adjusted.rightCenterX - adjusted.leftCenterX ==
        base.rightCenterX - base.leftCenterX + 2 * (base.dialRadius * (factor - 1) + spacing))
      for _, call in ipairs(harness.draw(frame, options, state, {720,360})) do
        local function inside(p)
          if p then assert(p.x >= 0 and p.x <= 720 and p.y >= 0 and p.y <= 360, 'scaled/spaced HUD must fit') end
        end
        inside(call.a); inside(call.b)
        for _, p in ipairs(call.points or {}) do inside(p) end
      end
    end
  end
end
Settings.values.gt7DialScale, Settings.values.gt7DialSpacing, Settings.values.gt7IndicatorScale = 1.2, 80, 1.5
package.loaded['src/gt7_settings'] = nil
Settings = require('src/gt7_settings')
assert(Settings.current().gt7DialScale == 1.2 and Settings.current().gt7DialSpacing == 80 and Settings.current().gt7IndicatorScale == 1.5)

-- The preview feeds the same telemetry processor, without touching live state.
local liveSpeed = state.speedValue
Preview.controls.enabled, Preview.controls.lights = true, true
Preview.controls.rpm, Preview.controls.speed, Preview.controls.boost = 0.9, 1, -0.25
for _ = 1, 60 do Preview.update(1 / 60, settings, state) end
local sample = assert(Preview.getState())
assert(sample ~= state and state.speedValue == liveSpeed)
assert(sample.rpmWarning and sample.headlights and sample.gt7Instruments.light == 1)
assert(sample.gt7Instruments.boostValue == -0.25 and sample.gt7Instruments.boostSimulated)
Preview.controls.missingFuel = true
Preview.update(1 / 60, settings, state)
assert(sample.fuel == nil and sample.maxFuel == nil)
Preview.controls.missingFuel = false
for _, input in ipairs({ {0, 0, 1, 0}, {0.5, 0.5, 0.5, 0.7}, {1, 1, 0.1, -0.5} }) do
  Preview.controls.speed, Preview.controls.rpm, Preview.controls.fuel, Preview.controls.boost =
    input[1], input[2], input[3], input[4]
  for _ = 1, 100 do Preview.update(1 / 60, settings, state) end
  sample = Preview.getState()
  assert(sample.speedValue == math.floor(state.speedGaugeMaximum * input[1] + 0.5))
  assert(sample.rpm == state.rpmDisplayLimiter * input[2] and near(sample.fuelNormalized, input[3]))
  assert(near(sample.gt7Instruments.boostValue, input[4]))
  assert(sample.rpmRedline == (input[2] >= settings.rpmRedlineFraction))
  for _, mode in ipairs({ 'analog', 'digital' }) do
    local calls = harness.draw('classic', { gt7SpeedNeedleMode = mode, gt7RpmNeedleMode = mode,
      gt7SimulateVacuum = true, gt7VacuumMinimum = -0.5 }, sample, {575, 240})
    assert(#calls > 0, 'minimum HUD size must support empty/mid/full instruments')
  end
end
Preview.controls.enabled = false
Preview.update(1 / 60, settings, state)
assert(Preview.getState() == nil and Preview.settings(settings) == settings)

print('Instruments: shared values, transitions, signed boost, nine geometries, persistence, isolated preview and '
  .. cases .. ' drawing cases passed')
return harness
