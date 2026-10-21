-- Reuse the established CSP draw recorder and regression suite.
local harness = dofile('tests/gt7_layouts.lua')
local Telemetry = require('src/telemetry')
local Presentation = require('src/instrument_state')
local Config = require('src/instrument_config')
local Needle = require('ui/instrument_needle')
local Theme = require('src/theme')
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
state.throttle, state.turboBoost = 0, 0.001
state.boostNeedleNormalized = state.turboBoost / state.turboDisplayMax
assert(Presentation.boost(state, settings) < -0.45, 'residual boost near zero must allow vacuum')
state.gt7Instruments = nil
Presentation.update(state, settings, 1 / 60)
assert(state.gt7Instruments.vacuum > 0 and state.gt7Instruments.vacuum < 0.1,
  'vacuum must begin gradually rather than jump to its minimum')
for _ = 1, 120 do Presentation.update(state, settings, 1 / 60) end
assert(state.gt7Instruments.boostNeedleValue < -0.45, 'residual telemetry must settle into vacuum')
state.turboBoost = 0.03
state.boostNeedleNormalized = state.turboBoost / state.turboDisplayMax
for _ = 1, 120 do Presentation.update(state, settings, 1 / 60) end
assert(state.gt7Instruments.vacuum < 0.00001, 'measured boost must release simulated vacuum')
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

-- Observe actual needle primitives, including open paths and filled hub parts.
assert(#Config.needleOrder == 24 and #Config.needleChoices == 24)
local signatures = {}
local seenIds = {}
for i, id in ipairs(Config.needleOrder) do
  assert(not seenIds[id] and Config.needleChoices[i].value == id)
  seenIds[id] = true
  assert(Config.needleNames[id]:sub(1, 3) == id:upper(), 'labels must identify the asset card')
  for _, part in ipairs(Config.needles[id].geometry.polygons) do
    local pts = part.points
    for j, a in ipairs(pts) do
      local b, c = pts[j % #pts + 1], pts[(j + 1) % #pts + 1]
      local turn = (b[1]-a[1])*(c[2]-b[2]) - (b[2]-a[2])*(c[1]-b[1])
      assert(turn >= -0.000001, id .. ' must use convex fills')
    end
  end
end
local originalLine, originalFill, originalCircle = ui.drawLine, ui.pathFillConvex, ui.drawCircle
local originalPath = ui.pathLineTo
local originalStroke, originalCircleFill = ui.pathStroke, ui.drawCircleFilled
local signature, points
ui.drawLine = function(a, b, color, width)
  signature[#signature + 1] = string.format('L%.3f,%.3f,%.3f,%.3f,%.3f', a.x, a.y, b.x, b.y, width)
  originalLine(a, b, color, width)
end
ui.pathLineTo = function(p) points[#points + 1] = string.format('%.3f,%.3f', p.x, p.y); originalPath(p) end
ui.pathFillConvex = function(color)
  signature[#signature + 1] = 'P' .. table.concat(points, ';'); points = {}; originalFill(color)
end
ui.pathStroke = function(color, closed, width)
  signature[#signature + 1] = 'S' .. tostring(closed) .. ':' .. tostring(width) .. ':' .. table.concat(points, ';')
  points = {}; originalStroke(color, closed, width)
end
ui.drawCircleFilled = function(p, radius, color, n)
  signature[#signature + 1] = string.format('F%.3f,%.3f,%.3f', p.x, p.y, radius)
  originalCircleFill(p, radius, color, n)
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
ui.pathStroke, ui.drawCircleFilled = originalStroke, originalCircleFill

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
-- Analog redline uses digital blocks while numbered labels remain in front.
local oldFraction = state.rpmGaugeNormalized
local colors = Theme.get('dark')
for _, sample in ipairs({{0.5, colors.redDim}, {1, colors.red}}) do
  state.rpmGaugeNormalized = sample[1]
  local count = 0
  local lastRedlineBlock = 0
  local numberOnTop = 0
  local calls = harness.draw('classic', {gt7RpmNeedleMode='analog'})
  for index, call in ipairs(calls) do
    if call.kind == 'polygon' and #call.points == 4 then
      local segment = true
      for _, p in ipairs(call.points) do
        local distance = math.sqrt((p.x-1265)^2 + (p.y-258)^2)
        if distance < Config.dial.segmentRadius-Config.dial.segmentDepth-0.01
            or distance > Config.dial.segmentRadius+0.01 then segment = false end
      end
      if segment then
        count = count + 1
        lastRedlineBlock = index
        assert(call.color.r == sample[2].r and call.color.g == sample[2].g and call.color.b == sample[2].b)
      end
    end
    if call.kind == 'text' and (call.text == '7' or call.text == '8') then numberOnTop = index end
  end
  assert(count >= 2, 'analog redline requires digital blocks')
  assert(numberOnTop > lastRedlineBlock, 'analog redline must keep scale numbers in front of its blocks')
end
state.rpmGaugeNormalized = oldFraction
for _, x in ipairs({175,1265}) do
  local count = 0
  for _, call in ipairs(analog) do
    if call.kind == 'circle_fill' and near(call.radius, Config.dial.innerDotRadius) then
      local distance = math.sqrt((call.a.x-x)^2 + (call.a.y-258)^2)
      if near(distance, Config.dial.innerRadius - Config.dial.innerTickLength / 2) then count = count + 1 end
    end
    assert(not (call.kind == 'arc' and near(call.a.x,x) and near(call.a.y,258)
      and near(call.radius,Config.dial.innerRadius)), 'analog inner scale must not be a continuous line')
  end
  assert(count >= 9, 'inner scale dots must follow numeric graduations')
end
state.fuel, state.maxFuel = nil, nil
assert(contains(harness.draw('classic'), 'N/A'), 'missing fuel must be distinct from an empty tank')
state.available, state.rpm, state.turboAvailable = true, 5200, false
state.aeroLoadNormalized = 0.5
assert(contains(harness.draw('classic'), 'AERO'))
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
assert(Settings.current().gt7SpeedNeedleStyle == 'b02' and Settings.current().gt7RpmNeedleStyle == 'b06')
package.loaded['src/gt7_settings'] = nil
Settings = require('src/gt7_settings')
assert(Settings.current().gt7SpeedNeedleStyle == 'b02', 'new styles must survive storage proxy reload')
Settings.values.gt7RpmNeedleStyle = 'invalid'
assert(Settings.current().gt7RpmNeedleStyle == 'b01' and Settings.current().gt7SpeedNeedleStyle == 'b02')

for old, id in pairs(Config.needleAliases) do
  Settings.values.gt7SpeedNeedleStyle, Settings.values.gt7RpmNeedleStyle = old, old
  assert(Settings.current().gt7SpeedNeedleStyle == id and Settings.current().gt7RpmNeedleStyle == id,
    'legacy selections must migrate: ' .. old)
  assert(Config.needlePreset(old) == Config.needles[id], 'legacy callers must resolve aliases')
end
local DialSettings = require('src/settings')
Settings.values.gt7SpeedNeedleMode, Settings.values.gt7RpmNeedleMode = 'analog', 'analog'
harness.pendingButtons['>  Personalization##dial.personalization'] = true
for i, id in ipairs(Config.needleOrder) do
  harness.pendingSliders['##gt7.speedNeedleStyle'] = i
  harness.pendingSliders['##gt7.rpmNeedleStyle'] = (#Config.needleOrder - i + 1)
  Settings.draw()
  DialSettings.values.instrumentMode = 'analog'
  harness.pendingSliders['##dial.needleStyle'] = i
  DialSettings.draw()
  local current = Settings.current()
  assert(current.gt7SpeedNeedleStyle == id and current.gt7RpmNeedleStyle == Config.needleOrder[25-i])
  assert(DialSettings.values.analogNeedleStyle == id, 'standalone selector must use the catalog')
  package.loaded['src/gt7_settings'], package.loaded['src/settings'] = nil, nil
  DialSettings = require('src/settings')
  Settings = require('src/gt7_settings')
  assert(DialSettings.values.analogNeedleStyle == id and Settings.current().gt7SpeedNeedleStyle == id
    and Settings.current().gt7RpmNeedleStyle == Config.needleOrder[25-i], 'all selections must persist independently')
end
DialSettings.values.analogNeedleStyle = 'invalid'
package.loaded['src/settings'] = nil
DialSettings = require('src/settings')
assert(DialSettings.values.analogNeedleStyle == 'a01')
harness.pendingButtons['Reset appearance##dial'] = true
DialSettings.draw()
assert(DialSettings.values.analogNeedleStyle == 'a01' and Settings.current().gt7SpeedNeedleStyle == 'd06')
DialSettings.values.analogNeedleStyle = 'c03'
harness.pendingButtons['>  Advanced##dial.advanced'] = true
harness.pendingButtons['Reset all##dial'] = true
DialSettings.draw()
assert(DialSettings.values.analogNeedleStyle == 'c03', 'reset must await its existing confirmation')
harness.pendingButtons['Confirm reset##dial'] = true
DialSettings.draw()
assert(DialSettings.values.analogNeedleStyle == 'a01')
harness.pendingButtons['Reset appearance##gt7'] = true
Settings.draw()
assert(Settings.current().gt7SpeedNeedleStyle == 'b01' and Settings.current().gt7RpmNeedleStyle == 'b01')
Settings.values.gt7SpeedNeedleStyle, Settings.values.gt7RpmNeedleStyle = 'c03', 'd05'
harness.pendingButtons['Reset all##gt7'] = true
Settings.draw()
harness.pendingButtons['Confirm reset##gt7'] = true
Settings.draw()
assert(Settings.current().gt7SpeedNeedleStyle == 'b01' and Settings.current().gt7RpmNeedleStyle == 'b01')

-- Check actual filled primitives at known hole centers, in rotated coordinates.
local holes = {a02={{40,0},{0,0}}, a05={{35,0},{-23,0}}, a06={{35,0}},
  b02={{40,0},{-17,0}}, b03={{107,0}}, b05={{18,0},{50,0},{-17,0}},
  c01={{40,0},{-30,0}}, c02={{-25,0}}, c03={{-39,0},{-30,0},{-21,0}},
  c06={{40,0},{-28,0}}, d01={{45,0},{-25,0}}, d02={{45,0},{-25,0}},
  d03={{0,0},{-25,0}}, d04={{40,0},{0,0},{-25,0}},
  d05={{101.5,0},{40,0},{-25,0}}, d06={{40,0},{-25,0}}}
local function covers(call, point)
  if call.kind == 'circle_fill' then
    return (point.x-call.a.x)^2 + (point.y-call.a.y)^2 <= call.radius^2
  end
  if call.kind ~= 'polygon' then return false end
  for i, a in ipairs(call.points) do
    local b = call.points[i % #call.points + 1]
    if (b.x-a.x)*(point.y-a.y) - (b.y-a.y)*(point.x-a.x) < -0.000001 then return false end
  end
  return true
end
local standaloneCases = 0
for _, id in ipairs(Config.needleOrder) do
  for _, fraction in ipairs({0,0.5,1}) do
    local angle = require('src/layout').rpmStart + math.rad(240) * fraction
    for _, theme in ipairs({'dark','light'}) do
      for _, lights in ipairs({false,true}) do
        local palette = Theme.get(theme)
        local tint = fraction == 1 and palette.red or (fraction == 0.5 and palette.amber or nil)
        local calls = harness.drawNeedle(vec2(180,180), 1, angle, Config.needles[id], palette, lights and 1 or 0, tint)
        for _, hole in ipairs(holes[id] or {}) do
          local point = vec2(180 + hole[1]*math.cos(angle)-hole[2]*math.sin(angle),
            180 + hole[1]*math.sin(angle)+hole[2]*math.cos(angle))
          for _, call in ipairs(calls) do assert(not covers(call, point), id .. ' must leave its holes empty') end
        end
        local backlight = require('ui/instrument_illumination').resolve(palette, theme, lights and 1 or 0)
        local illuminated = harness.drawNeedle(vec2(180,180), 1, angle, Config.needles[id], palette,
          lights and 1 or 0, tint, backlight)
        for _, hole in ipairs(holes[id] or {}) do
          local point = vec2(180 + hole[1]*math.cos(angle)-hole[2]*math.sin(angle),
            180 + hole[1]*math.sin(angle)+hole[2]*math.cos(angle))
          for _, call in ipairs(illuminated) do
            assert(not covers(call, point), id .. ' backlight must preserve real holes')
          end
        end
        if lights then assert(#illuminated > #calls, id .. ' must add emission layers')
        else assert(#illuminated == #calls, 'OFF must not add needle layers') end
        state.analogNeedleNormalized, state.headlights = fraction, lights
        state.rpmWarning, state.rpmRedline = fraction >= 0.5, fraction == 1
        for _, window in ipairs({{300,300},{460,460},{740,420}}) do
          local drawn = harness.drawDial({analogNeedleStyle=id, theme=theme}, state, window)
          for _, call in ipairs(drawn) do
            local function inside(p, radius)
              if p then
                radius = radius or 0
                assert(p.x-radius >= 0 and p.y-radius >= 0 and p.x+radius <= window[1]
                  and p.y+radius <= window[2], 'standalone primitives must fit')
              end
            end
            inside(call.a, call.radius); inside(call.b)
            for _, p in ipairs(call.points or {}) do inside(p) end
          end
          standaloneCases = standaloneCases + 1
        end
      end
    end
  end
end
state.rpmWarning, state.rpmRedline = false, false

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

-- AERO hand inertia scales with the size of the telemetry change.
state.available, state.turboAvailable, state.aeroLoadNormalized = true, false, 0
state.gt7Instruments = nil
Presentation.update(state, settings, 1 / 60)
assert(state.gt7Instruments.aeroNeedleValue == 0, 'AERO hand must initialize at its current value')
state.aeroLoadNormalized = 0.1
Presentation.update(state, settings, 1 / 60)
local smallJump = state.gt7Instruments.aeroNeedleValue
state.gt7Instruments.aeroNeedleValue = 0
state.aeroLoadNormalized = 0.8
Presentation.update(state, settings, 1 / 60)
local largeJump = state.gt7Instruments.aeroNeedleValue
assert(smallJump / 0.1 > largeJump / 0.8 and largeJump > 0,
  'larger AERO changes must move the hand more gradually')
for _ = 1, 240 do Presentation.update(state, settings, 1 / 60) end
assert(near(state.gt7Instruments.aeroNeedleValue, 0.8), 'AERO hand must settle at the live telemetry value')
state.turboAvailable = true
Presentation.update(state, settings, 1 / 60)
assert(state.gt7Instruments.aeroNeedleValue == nil, 'AERO hand state must clear when the channel is unavailable')

print('Instruments: 24 geometries, real holes, migrations, independent sliders, persistence, resets; '
  .. cases .. ' GT7 and ' .. standaloneCases .. ' standalone drawing cases passed')
return harness
