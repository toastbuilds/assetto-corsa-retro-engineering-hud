package.path = './?.lua;./?/init.lua;' .. package.path

local Vec2 = {}
Vec2.__index = Vec2
function Vec2.__add(a, b) return vec2(a.x + b.x, a.y + b.y) end
function Vec2.__sub(a, b) return vec2(a.x - b.x, a.y - b.y) end
function Vec2.__mul(a, b)
  if type(a) == 'number' then return vec2(a * b.x, a * b.y) end
  return vec2(a.x * b, a.y * b)
end
function Vec2.__div(a, b) return vec2(a.x / b, a.y / b) end
function vec2(x, y) return setmetatable({ x = x or 0, y = y or 0 }, Vec2) end
function rgbm(r, g, b, mult) return { r = r, g = g, b = b, mult = mult } end

local stores = { [''] = { layoutVersion = 9, sharedUnitsVersion = 1 } }
ac = { getSim = function() return {} end, storage = function(defaults, prefix)
  prefix = prefix or ''
  local stored = stores[prefix] or {}
  stores[prefix] = stored
  for key, value in pairs(defaults) do if stored[key] == nil then stored[key] = value end end
  -- CSP's storage proxy is readable but need not enumerate stored fields.
  return setmetatable({}, { __index = stored, __newindex = stored,
    __pairs = function() return next, {}, nil end })
end }

local width, height = 1440, 500
local calls, path, arc = {}, {}, nil
local fonts, alphaDepth = 0, 0
local pendingCombos, pendingButtons, pendingSliders, comboCalls = {}, {}, {}, {}
local function noop() end
local function record(kind, values)
  values.kind = kind
  calls[#calls + 1] = values
end
ui = {
  ComboFlags = { None = 0 },
  windowWidth = function() return width end,
  windowHeight = function() return height end,
  measureDWriteText = function(text, size) return vec2(#tostring(text) * size * 0.55, size) end,
  dwriteDrawText = function(text, size, position, color)
    assert(size > 0 and size == size, 'text size must be finite and positive')
    record('text', { text = text, size = size, a = position, color = color })
  end,
  drawLine = function(a, b, color, thickness)
    record('line', { a = a, b = b, color = color, thickness = thickness })
  end,
  drawCircle = function(center, radius, color, _, thickness)
    record('circle', { a = center, radius = radius, color = color, thickness = thickness })
  end,
  drawCircleFilled = function(center, radius, color)
    record('circle_fill', { a = center, radius = radius, color = color })
  end,
  drawRect = function(a, b, color, rounding, _, thickness)
    record('rect', { a = a, b = b, color = color, rounding = rounding, thickness = thickness })
  end,
  drawRectFilled = function(a, b, color, rounding)
    record('rect_fill', { a = a, b = b, color = color, rounding = rounding })
  end,
  pathClear = function() path, arc = {}, nil end,
  pathLineTo = function(position) path[#path + 1] = position end,
  pathArcTo = function(center, radius, startAngle, endAngle)
    arc = { a = center, radius = radius, startAngle = startAngle, endAngle = endAngle }
  end,
  pathFillConvex = function(color)
    local area = 0
    for i, p in ipairs(path) do
      local following = path[i % #path + 1]
      area = area + p.x * following.y - following.x * p.y
    end
    assert(area > 0, 'mirrored shapes must retain clockwise convex-fill winding')
    record('polygon', { points = path, color = color })
  end,
  pathStroke = function(color, closed, thickness)
    if arc then
      record('arc', { a = arc.a, radius = arc.radius, startAngle = arc.startAngle,
        endAngle = arc.endAngle, color = color, thickness = thickness })
    else
      record('path', { points = path, color = color, closed = closed, thickness = thickness })
    end
  end,
  pushDWriteFont = function() fonts = fonts + 1 end,
  popDWriteFont = function() fonts = fonts - 1 end,
  pushStyleVarAlpha = function() alphaDepth = alphaDepth + 1 end,
  popStyleVar = function() alphaDepth = alphaDepth - 1 end,
  header = noop, separator = noop, text = noop, textWrapped = noop, sameLine = noop,
  time = function() return 0 end,
  availableSpaceX = function() return 640 end,
  checkbox = function() return false end,
  slider = function(label, value)
    local selected = pendingSliders[label]
    pendingSliders[label] = nil
    return selected or value, selected ~= nil
  end,
  combo = function(label, index)
    comboCalls[label] = true
    local value = pendingCombos[label]
    pendingCombos[label] = nil
    return value or index, value ~= nil
  end,
  button = function(label)
    local pressed = pendingButtons[label]
    pendingButtons[label] = nil
    return pressed or false
  end
}

local Layouts = require('src/gt7_retro_layout')
local Theme = require('src/theme')
local Telemetry = require('src/telemetry')
local PedalHistory = require('src/pedal_history')
local Renderer = require('ui/gt7_retro')
local DialSettings = require('src/settings')
local Settings = require('src/gt7_settings')
local GeneralSettings = require('src/general_settings')
local ids = { 'classic', 'modern', 'outer_pedals', 'steering_dial' }

assert(Settings.current().gt7Layout == 'classic', 'existing installs must default to Classic')
Settings.values.gt7Layout = 'unknown'
assert(Settings.current().gt7Layout == 'classic' and Layouts.get('unknown').frameStyle == 'classic',
  'unknown stored values must safely select Classic')
local componentKeys = {
  'gt7SpeedStyle', 'gt7GearStyle', 'gt7SteeringStyle', 'gt7RpmBarVisible',
  'gt7PedalPosition', 'gt7PedalStyle', 'gt7RadarPresentation',
  'gt7FlagPresentation', 'gt7LowerFrameStyle'
}
local function expectComponents(actual, expected, message)
  for _, key in ipairs(componentKeys) do
    assert(actual[key] == expected[key], message .. ': ' .. key)
  end
end

-- Exercise the one-time legacy migration for every former full-layout value.
local legacyStore = stores['retro-ui.gt7.']
for _, id in ipairs(ids) do
  legacyStore.gt7Layout = id
  legacyStore.gt7RadarStyle = id == 'classic' and 'lights' or 'arcs'
  legacyStore.gt7LowerPanelMode = 'pedal_history'
  legacyStore.gt7SpeedNeedleMode = 'analog'
  legacyStore.compositionVersion = 0
  package.loaded['src/gt7_settings'] = nil
  Settings = require('src/gt7_settings')
  local expected = Layouts.preset(id, { gt7RadarStyle = legacyStore.gt7RadarStyle })
  expectComponents(Settings.current(), expected, 'legacy migration must map ' .. id)
  assert(Settings.values.gt7LowerPanelMode == 'pedal_history'
    and Settings.values.gt7SpeedNeedleMode == 'analog',
    'composition migration must preserve independent preferences')
end

Settings.values.gt7SpeedStyle = 'bogus'
Settings.values.gt7GearStyle = 'modern'
Settings.values.gt7PedalStyle = 'modern'
local sanitized = Settings.current()
assert(sanitized.gt7SpeedStyle == 'classic' and sanitized.gt7GearStyle == 'modern'
  and sanitized.gt7PedalStyle == 'modern',
  'unknown component values must reset only the affected component')

Settings.values.gt7LowerPanelMode = 'pedal_history'
Settings.values.gt7RadarStyle = 'lights'
Settings.values.gt7SpeedNeedleMode = 'analog'
pendingButtons['>  Personalization##gt7.personalization'] = true
pendingButtons['>  Radar and flags##gt7.radar'] = true
pendingButtons['>  Center and pedals##gt7.center'] = true
for index, id in ipairs(ids) do
  local label = ({'Classic', 'Modern', 'Outer Pedals', 'Steering Dial'})[index]
  pendingButtons[label .. '##gt7.preset.' .. id] = true
  comboCalls = {}
  Settings.draw()
  local current = Settings.current()
  assert(current.gt7Layout == id, 'preset selector must apply ' .. id)
  expectComponents(current, Layouts.preset(id, current), 'preset composition must match ' .. id)
  assert(Settings.values.gt7LowerPanelMode == 'pedal_history'
    and Settings.values.gt7SpeedNeedleMode == 'analog' and Settings.values.gt7RadarStyle == 'lights',
    'applying presets must preserve independent settings')
  assert(comboCalls['##gt7.radarPresentation'] and comboCalls['##gt7.flagPresentation'],
    'Premium must always expose independent radar and flag selectors')
end

Settings.applyPreset('modern')
local beforeEdit = Settings.current()
pendingCombos['##gt7.speedStyle'] = 0
Settings.draw()
local afterEdit = Settings.current()
assert(afterEdit.gt7SpeedStyle == 'classic', 'component selector must update its own section')
for _, key in ipairs(componentKeys) do
  if key ~= 'gt7SpeedStyle' then
    assert(afterEdit[key] == beforeEdit[key], 'editing speed must not modify ' .. key)
  end
end

Settings.applyPreset('modern')
local beforeAppearanceReset = Settings.current()
pendingButtons['Reset appearance##gt7'] = true
Settings.draw()
expectComponents(Settings.current(), beforeAppearanceReset,
  'appearance reset must preserve composition selections')
package.loaded['src/gt7_settings'] = nil
Settings = require('src/gt7_settings')
expectComponents(Settings.current(), beforeAppearanceReset,
  'composition preferences must survive reload')
assert(Settings.current().gt7LowerPanelMode == 'pedal_history', 'independent preferences must survive reload')
GeneralSettings.values.speedUnit, GeneralSettings.values.theme = 'mph', 'light'
assert(Settings.current().speedUnit == 'mph' and Settings.current().theme == 'light',
  'shared units and theme must still apply')
pendingButtons['>  Advanced##gt7.advanced'] = true
pendingButtons['Reset all##gt7'] = true
Settings.draw()
assert(Settings.values.gt7Layout == 'modern', 'reset must wait for confirmation')
pendingButtons['Confirm reset##gt7'] = true
Settings.draw()
assert(Settings.current().gt7Layout == 'classic' and Settings.values.gt7LowerPanelMode == 'limit'
  and GeneralSettings.values.speedUnit == 'mph' and GeneralSettings.values.theme == 'light',
  'confirmed reset must restore GT7 defaults and preserve shared settings')
expectComponents(Settings.current(), Layouts.preset('classic', Settings.current()),
  'confirmed reset must restore Classic composition')

local state = Telemetry.new()
state.speedText, state.speedUnit, state.gearText = '139', 'km/h', '2'
state.speedValue, state.speedGaugeMaximum, state.speedGaugeStep = 139, 320, 40
state.rpm, state.rpmNormalized, state.rpmGaugeNormalized = 5200, 0.65, 0.65
state.rpmDisplayLimiter, state.rpmGaugeLimiter = 8000, 8000
state.gt7SpeedNeedleNormalized, state.gt7RpmNeedleNormalized = 139 / 320, 0.65
state.throttle, state.brake, state.fuelNormalized, state.fuel = 0.82, 0.36, 0.6, 35
state.proximityRadarAvailable, state.indicatorPhase = true, true
state.turboAvailable, state.turboBoost, state.turboDisplayMax = true, 0.7, 1.5
state.boostNeedleNormalized = 0.7 / 1.5
for i = 1, 180 do PedalHistory.update(state.pedalHistory, 1 / 30,
  math.max(0, math.sin(i / 24)), math.max(0, math.sin(i / 17)) * 0.4) end

local function draw(id, overrides, drawState, window)
  local settings = { gt7Layout = id, theme = 'dark', speedUnit = 'km/h',
    hudScale = 0.72, opacity = 1, backgroundOpacity = 0.72,
    gt7SpeedNeedleMode = 'analog', gt7RpmNeedleMode = 'analog', gt7RadarStyle = 'arcs',
    gt7LowerPanelMode = 'pedal_history', gt7ProximityRadar = true, showSteering = true, showLights = true }
  for key, value in pairs(Layouts.preset(id, settings)) do settings[key] = value end
  for key, value in pairs(overrides or {}) do settings[key] = value end
  local layout = Layouts.resolve(settings)
  width, height = layout.width, layout.height
  if window then width, height = window[1], window[2] end
  calls = {}
  Renderer.draw(drawState or state, settings)
  assert(fonts == 0 and alphaDepth == 0, 'drawing must balance fonts and styles')
  return calls
end

local function equalColor(a, b)
  return a and b and a.r == b.r and a.g == b.g and a.b == b.b
end
local function bounds(call)
  if call.a and call.b then return call.a.x, call.a.y, call.b.x, call.b.y end
  local left, top, right, bottom = math.huge, math.huge, -math.huge, -math.huge
  for _, p in ipairs(call.points or {}) do
    left, top, right, bottom = math.min(left, p.x), math.min(top, p.y), math.max(right, p.x), math.max(bottom, p.y)
  end
  return left, top, right, bottom
end
local function near(a, b) return math.abs(a - b) < 0.001 end
local function lampColors(layout, side)
  local x = side == 'left' and layout.verticalLampLeftX or layout.verticalLampRightX
  local result = {}
  for _, call in ipairs(calls) do
    if call.kind == 'circle_fill' and near(call.a.x, x) and near(call.radius, layout.flagLampRadius) then
      result[#result + 1] = { color = call.color, y = call.a.y }
    end
  end
  assert(#result == layout.verticalLampCount, 'exactly one column must be drawn per side')
  return result
end
local function expectLamps(layout, side, filled, color)
  for i, lamp in ipairs(lampColors(layout, side)) do
    assert(near(lamp.y, layout.verticalLampBottom - (i - 1) * layout.verticalLampSpacing),
      'lamps must fill bottom to top')
    assert(equalColor(lamp.color, i <= filled and color or Theme.colors.outlineDim),
      'unexpected ' .. side .. ' lamp color at level ' .. i)
  end
end
local function indicatorColor(layout, side)
  local tipX = side == 'left' and layout.indicatorLeftX - 13 or layout.indicatorRightX + 13
  for _, call in ipairs(calls) do
    if call.kind == 'polygon' and #call.points == 3
        and near(call.points[1].x, tipX) and near(call.points[1].y, layout.indicatorY) then return call.color end
  end
  error('turn indicator must remain present')
end

for _, id in ipairs({ 'outer_pedals', 'steering_dial' }) do
  local layout = Layouts.get(id)
  state.raceFlagType, state.clock, state.leftIndicator, state.rightIndicator = 2, 0, true, false
  state.radarRightLevel = 0
  for level = 0, 3 do
    state.radarLeftLevel = level
    draw(id, { gt7RadarStyle = 'arcs' })
    expectLamps(layout, 'left', level > 0 and level * layout.verticalLampCount / 3 or layout.verticalLampCount,
      level == 0 and Theme.colors.flagYellow or (level == 3 and Theme.colors.red or Theme.colors.amber))
    expectLamps(layout, 'right', layout.verticalLampCount, Theme.colors.flagYellow)
    assert(indicatorColor(layout, 'left') == Theme.colors.amber
      and indicatorColor(layout, 'right') == Theme.colors.outlineDim, 'radar must not replace turn signals')
  end
  state.clock = layout.radarBlinkPeriod
  draw(id)
  expectLamps(layout, 'left', 0, Theme.colors.red)
  expectLamps(layout, 'right', layout.verticalLampCount, Theme.colors.flagYellow)
  state.clock = 0
  draw(id, { gt7ProximityRadar = false })
  expectLamps(layout, 'left', layout.verticalLampCount, Theme.colors.flagYellow)
  state.proximityRadarAvailable = false
  draw(id)
  expectLamps(layout, 'left', layout.verticalLampCount, Theme.colors.flagYellow)
  state.proximityRadarAvailable = true
  state.radarRightLevel, state.hazardLights = 2, true
  draw(id)
  expectLamps(layout, 'right', layout.verticalLampCount * 2 / 3, Theme.colors.amber)
  assert(indicatorColor(layout, 'left') == Theme.colors.amber
    and indicatorColor(layout, 'right') == Theme.colors.amber, 'hazards must remain independent')
  state.indicatorPhase = false
  draw(id)
  assert(indicatorColor(layout, 'left') == Theme.colors.outlineDim
    and indicatorColor(layout, 'right') == Theme.colors.outlineDim, 'turn blink must remain independent')
  draw(id, { animateIndicators = false })
  assert(indicatorColor(layout, 'left') == Theme.colors.amber, 'turn animation toggle must still work')
  state.radarLeftLevel, state.radarRightLevel = 0, 0
  state.clock = layout.flagBlinkPeriod
  draw(id)
  expectLamps(layout, 'left', 0, Theme.colors.flagYellow)
  draw(id, { animateFlagAlert = false })
  expectLamps(layout, 'left', layout.verticalLampCount, Theme.colors.flagYellow)
  state.indicatorPhase, state.hazardLights, state.clock, state.raceFlagType = true, false, 0, nil
end

local modern = Layouts.get('modern')
local function topFlagStrip(side)
  local x = side == 'left' and modern.centerLeft + 14 or modern.centerRight - 14
  local top, bottom = modern.centerTop + 40, modern.centerTop + 67
  local base, tiles, outline = nil, {}, nil
  for _, call in ipairs(calls) do
    if call.kind == 'rect_fill' or call.kind == 'rect' then
      local left, y1, right, y2 = bounds(call)
      if near(left, x - 2) and near(right, x + 2) and near(y1, top) and near(y2, bottom) then
        if call.kind == 'rect_fill' then base = call else outline = call end
      elseif call.kind == 'rect_fill' and left >= x - 2 and right <= x + 2
          and y1 >= top and y2 <= bottom then tiles[#tiles + 1] = call end
    end
  end
  return assert(base, 'upper flag strip must always be lit'), tiles, assert(outline, 'flag strip must retain its outline')
end
local flagCases = {
  { role = 'green' }, { flag = 0, role = 'green' }, { flag = 1, role = 'green' },
  { flag = 2, role = 'flagYellow' }, { flag = 3, role = 'flagYellow', pattern = 'slippery' },
  { flag = 4, role = 'red' }, { flag = 5, role = 'flagBlack' },
  { flag = 6, role = 'flagWhite' }, { flag = 7, role = 'flagWhite' },
  { flag = 8, role = 'flagBlack' }, { flag = 9, role = 'flagBlack', pattern = 'mechanical' },
  { flag = 10, role = 'flagWhite', pattern = 'split' }, { flag = 11, role = 'green' },
  { flag = 12, role = 'shiftBlue' }, { flag = 13, role = 'flagWhite', pattern = 'checkered' },
  { flag = 14, role = 'flagWhite' }, { flag = 15, role = 'red' },
  { flag = 16, role = 'flagPurple' }, { flag = 999, role = 'green' }
}
state.radarLeftLevel, state.radarRightLevel = 3, 2
for _, theme in ipairs({ 'dark', 'light' }) do
  local palette = Theme.get(theme)
  for _, case in ipairs(flagCases) do
    state.raceFlagType = case.flag
    for _, clock in ipairs({ 0, modern.flagBlinkPeriod, modern.flagBlinkPeriod * 2 }) do
      state.clock = clock
      draw('modern', { theme = theme, animateFlagAlert = true, showLights = false })
      for _, side in ipairs({ 'left', 'right' }) do
        local strip, tiles, outline = topFlagStrip(side)
        assert(strip.color == palette[case.role] and strip.color.mult == 1,
          'upper flag strips must show the current flag steadily, despite blink phase or radar')
        assert(outline.color == (case.role == 'flagBlack' and palette.flagWhite or strip.color),
          'black flags must remain visible with a lit white outline')
        if case.pattern == 'checkered' then
          assert(#tiles == 9, 'finished flag must draw nine alternating black checker tiles per strip')
          for i, tile in ipairs(tiles) do
            local left, top, right, bottom = bounds(tile)
            local x = side == 'left' and modern.centerLeft + 14 or modern.centerRight - 14
            local row, column = i - 1, (i - 1) % 2
            assert(tile.color == palette.flagBlack and near(left, x - 2 + column * 2)
              and near(right - left, 2) and near(top, modern.centerTop + 40 + row * 3)
              and near(bottom - top, 3), 'checker tiles must alternate in two columns')
          end
        elseif case.pattern == 'slippery' then
          assert(#tiles == 5, 'slippery flag must display alternating red and yellow stripes')
          for _, tile in ipairs(tiles) do assert(tile.color == palette.red) end
        elseif case.pattern == 'split' then
          assert(#tiles == 1 and tiles[1].color == palette.flagBlack, 'unsportsmanlike flag must show black and white halves')
        elseif case.pattern ~= 'mechanical' then
          assert(#tiles == 0, 'solid flags must not inherit the previous flag pattern')
        end
      end
    end
  end
end
state.raceFlagType, state.clock, state.radarLeftLevel, state.radarRightLevel = nil, 0, 0, 0
state.radarLeftLevel, state.radarRightLevel = 3, 0
state.raceFlagType, state.leftIndicator = 2, true
local classic = Layouts.get('classic')
local function classicFlagCount(layout, side)
  local x = side == 'left' and layout.indicatorLeftX + layout.flagLampSideOffset
    or layout.indicatorRightX - layout.flagLampSideOffset
  local count = 0
  for _, call in ipairs(calls) do
    if call.kind == 'circle_fill' and near(call.a.x, x) and near(call.radius, layout.flagLampRadius) then
      count = count + 1
    end
  end
  return count
end
local function radarArcCount(layout, side, color)
  local x = side == 'left' and layout.radarArcLeftX or layout.radarArcRightX
  local count = 0
  for _, call in ipairs(calls) do
    if call.kind == 'arc' and near(call.a.x, x) and near(call.a.y, layout.radarArcY)
        and (not color or call.color == color) then count = count + 1 end
  end
  return count
end
local function columnCount(layout, side)
  local x = side == 'left' and layout.sections.alerts.columnLeftX or layout.sections.alerts.columnRightX
  local count = 0
  for _, call in ipairs(calls) do
    if call.kind == 'circle_fill' and near(call.a.x, x) and near(call.radius, layout.flagLampRadius) then
      count = count + 1
    end
  end
  return count
end

-- During proximity, radar owns only the affected side for the entire event,
-- including the dark half of its blink. The other side keeps its flag.
for _, clock in ipairs({ 0, classic.radarBlinkPeriod }) do
  state.clock = clock
  draw('classic', { gt7RadarPresentation = 'arcs', gt7FlagPresentation = 'classic_lights' })
  assert(classicFlagCount(classic, 'left') == 0 and classicFlagCount(classic, 'right') == 2,
    'radar must replace the flag only on the traffic side throughout the blink')
  assert(radarArcCount(classic, 'left') >= 3,
    'radar arcs must reserve their side during both blink phases')
  assert(radarArcCount(classic, 'left', Theme.colors.red) == (clock == 0 and 3 or 0),
    'alongside radar arcs must blink without restoring the flag')
  assert(indicatorColor(classic, 'left') == Theme.colors.amber,
    'turn indicators must remain independent from radar')
end

state.clock, state.radarRightLevel = 0, 2
draw('classic', { gt7RadarPresentation = 'arcs', gt7FlagPresentation = 'classic_lights' })
assert(classicFlagCount(classic, 'left') == 0 and classicFlagCount(classic, 'right') == 0
  and radarArcCount(classic, 'left') >= 3 and radarArcCount(classic, 'right') >= 3,
  'traffic on both sides must replace both shared-space flags')

state.radarRightLevel = 0
for _, style in ipairs({ 'arcs', 'classic_lights', 'modern_bars', 'column_3', 'column_9' }) do
  draw('classic', { gt7RadarPresentation = style, gt7FlagPresentation = 'classic_lights' })
  assert(classicFlagCount(classic, 'left') == 0 and classicFlagCount(classic, 'right') == 2,
    'every radar presentation must reserve only the side with traffic: ' .. style)
  assert(indicatorColor(classic, 'left') == Theme.colors.amber,
    'every radar presentation must preserve turn signals: ' .. style)
end

state.radarLeftLevel = 0
for _, style in ipairs({ 'column_3', 'column_9' }) do
  local expected = style == 'column_9' and 9 or 3
  draw('classic', { gt7RadarPresentation = 'arcs', gt7FlagPresentation = style })
  local layout = Layouts.resolve(Layouts.preset('classic'))
  assert(columnCount(layout, 'left') == expected and columnCount(layout, 'right') == expected,
    style .. ' flags must render independently on both sides')
  state.radarLeftLevel = 2
  draw('classic', { gt7RadarPresentation = 'arcs', gt7FlagPresentation = style })
  assert(columnCount(layout, 'left') == 0 and columnCount(layout, 'right') == expected,
    style .. ' flag must yield only on the traffic side')
  state.radarLeftLevel = 0
end

state.radarLeftLevel = 3
draw('classic', { gt7RadarPresentation = 'arcs', gt7FlagPresentation = 'classic_lights', gt7ProximityRadar = false })
assert(classicFlagCount(classic, 'left') == 2 and classicFlagCount(classic, 'right') == 2
  and radarArcCount(classic, 'left') == 0, 'disabled radar must leave flags in control')
state.proximityRadarAvailable = false
draw('classic', { gt7RadarPresentation = 'arcs', gt7FlagPresentation = 'classic_lights' })
assert(classicFlagCount(classic, 'left') == 2 and radarArcCount(classic, 'left') == 0,
  'unavailable radar must leave flags in control')
state.proximityRadarAvailable, state.radarLeftLevel, state.radarRightLevel = true, 0, 0
state.raceFlagType, state.clock = nil, 0

local function pedals(side)
  local x = side == 'left' and modern.brakeX or modern.throttleX
  local result = {}
  for _, call in ipairs(calls) do
    if call.kind == 'polygon' then
      local left, top, right, bottom = bounds(call)
      if top >= modern.pedalTop - 0.001 and bottom <= modern.pedalTop + modern.pedalHeight + 0.001
          and left >= x - 10 and right <= x + modern.pedalWidth + 10 then
        result[#result + 1] = { left = left, right = right, color = call.color }
      end
    end
  end
  assert(#result == 12, 'Modern must retain twelve segments per pedal')
  return result
end
for _, theme in ipairs({ 'dark', 'light' }) do
  local palette = Theme.get(theme)
  for _, intervention in ipairs({ { tc = false, abs = false }, { tc = true, abs = false },
      { tc = false, abs = true }, { tc = true, abs = true }, {} }) do
    state.tcActive, state.absActive = intervention.tc, intervention.abs
    state.absLevel = 0 -- Disabled ABS alone must not color the intervention blocks.
    for _, value in ipairs({ 0, 0.5, 0.9, 1 }) do
      state.brake, state.throttle = value, value
      draw('modern', { theme = theme })
      for _, side in ipairs({ 'left', 'right' }) do
        local active = side == 'left' and intervention.abs == true or side == 'right' and intervention.tc == true
        local interventionColor = side == 'left' and palette.flagWhite or palette.red
        local pedalColor = side == 'left' and palette.red or palette.cyan
        for i, segment in ipairs(pedals(side)) do
          local expected = active and i > 10 and interventionColor
            or (i <= math.floor(value * 12 + 0.5) and pedalColor or palette.inactive)
          assert(segment.color == expected,
            'only the two wider blocks must fill with the intervention color, independently of pedal input')
        end
      end
      for _, call in ipairs(calls) do
        if call.kind == 'text' and (call.text == 'ABS' or call.text == 'TC') then
          assert(call.a.y > modern.pedalTop, 'the extra pedal-top indicator row must be removed')
        elseif call.kind == 'polygon' then
          local left, top, right, bottom = bounds(call)
          assert(not (top >= modern.pedalTop - 30 and bottom <= modern.pedalTop - 8
            and ((left >= modern.brakeX - 10 and right <= modern.brakeX + modern.pedalWidth)
              or (left >= modern.throttleX and right <= modern.throttleX + modern.pedalWidth + 10))),
            'no extra assist panel may remain above either pedal')
        end
      end
    end
  end
end
state.absLevel, state.absActive, state.tcActive = nil, true, true
state.brake, state.throttle = 0, 0
for _, id in ipairs(ids) do
  local layout = Layouts.get(id)
  for _, theme in ipairs({ 'dark', 'light' }) do
    local palette = Theme.get(theme)
    draw(id, { theme = theme })
    for _, side in ipairs({ 'left', 'right' }) do
      local blocks = {}
      if id == 'modern' then
        for _, segment in ipairs(pedals(side)) do blocks[#blocks + 1] = segment end
      else
        local x = side == 'left' and layout.brakeX or layout.throttleX
        for _, call in ipairs(calls) do
          if call.kind == 'rect_fill' and near(call.a.x, x)
              and call.a.y >= layout.pedalTop - 0.001
              and call.b.y <= layout.pedalTop + layout.pedalHeight + 0.001 then
            blocks[#blocks + 1] = call
          end
        end
      end
      assert(#blocks == 12, id .. ' must retain twelve blocks per pedal')
      local assistColor = side == 'left' and palette.flagWhite or palette.red
      for index, block in ipairs(blocks) do
        assert(block.color == (index > 10 and assistColor or palette.inactive),
          id .. ' must show ABS/TC cut on the top two blocks in both themes')
      end
    end
  end
end
state.absActive, state.tcActive = nil, nil
for _, value in ipairs({ 0, 10.5 / 12 - 0.001, 10.5 / 12 + 0.001, 11.5 / 12 - 0.001, 11.5 / 12 + 0.001, 1 }) do
  state.brake, state.throttle = value, value
  draw('modern')
  for _, side in ipairs({ 'left', 'right' }) do
    local x = side == 'left' and modern.brakeX or modern.throttleX
    for i, segment in ipairs(pedals(side)) do
      local extra = i > 10 and 10 or 0
      assert(segment.left == x - (side == 'left' and extra or 0)
        and segment.right == x + modern.pedalWidth + (side == 'right' and extra or 0),
        'only the upper two blocks must grow away from the center')
      assert(equalColor(segment.color, i <= math.floor(value * 12 + 0.5)
        and (side == 'left' and Theme.colors.red or Theme.colors.cyan) or Theme.colors.inactive),
        'pedal activation must reach the wider blocks at the right threshold')
    end
  end
end
state.brake, state.throttle = 0.36, 0.82
assert(modern.brakeX - 10 > modern.leftCenterX + modern.dialRadius + 6
  and modern.throttleX + modern.pedalWidth + 10 < modern.rightCenterX - modern.dialRadius - 6,
  'wider segments must clear both dials')
local outer = Layouts.get('outer_pedals')
assert(outer.brakeX + outer.pedalWidth < outer.leftCenterX - outer.dialRadius - 6
  and outer.throttleX > outer.rightCenterX + outer.dialRadius + 6,
  'outer pedals must lie outside both dials with clearance')

assert(Layouts.frameFor({}) == 'classic', 'Classic must be the fallback frame')
assert(Layouts.frameFor({ gt7PedalPosition = 'outer' }) == 'outer_pedals',
  'outer pedals must select the Outer Pedals frame when center sections are Classic')
assert(Layouts.frameFor({ gt7GearStyle = 'modern', gt7PedalPosition = 'outer' }) == 'modern',
  'Modern center variants must take priority over outer pedals')
assert(Layouts.frameFor({ gt7SpeedStyle = 'large', gt7GearStyle = 'modern' }) == 'steering_dial'
  and Layouts.frameFor({ gt7SteeringStyle = 'dial', gt7PedalPosition = 'outer' }) == 'steering_dial',
  'large speed or steering dial must take highest frame priority')

local cachedSettings = Layouts.preset('modern')
local cachedA = Layouts.resolve(cachedSettings)
local cachedB = Layouts.resolve(cachedSettings)
assert(cachedA == cachedB, 'resolver must reuse geometry while selections are unchanged')
cachedSettings.gt7RpmBarVisible = true
local cachedC = Layouts.resolve(cachedSettings)
assert(cachedC ~= cachedA and cachedC.showRpmBar,
  'resolver must rebuild only when a composition selection changes')

local mixedSettings = Layouts.preset('classic')
mixedSettings.gt7SteeringStyle = 'dial'
mixedSettings.gt7RpmBarVisible = true
mixedSettings.gt7PedalPosition = 'outer'
mixedSettings.gt7PedalStyle = 'modern'
mixedSettings.gt7RadarPresentation = 'column_9'
mixedSettings.gt7FlagPresentation = 'column_3'
local mixed = Layouts.resolve(mixedSettings)
assert(mixed.frameStyle == 'steering_dial' and mixed.width == 1560,
  'dial plus outer pedals must use a widened Steering Dial frame')
assert(mixed.sections.steering.style == 'dial' and mixed.sections.pedals.position == 'outer'
  and mixed.sections.pedals.style == 'modern' and mixed.sections.rpm.visible,
  'automatic frame selection must preserve every component choice')
assert(mixed.brakeX - mixed.pedalUpperExtraWidth >= 0
  and mixed.throttleX + mixed.pedalWidth + mixed.pedalUpperExtraWidth <= mixed.width,
  'outer modern pedals must remain fully inside the resolved design space')
assert(mixed.speedCenterX + mixed.speedReadoutWidth / 2 < mixed.steeringCenterX - mixed.steeringRadius
  and mixed.gearPodCenterX - mixed.gearPodHalfWidth > mixed.steeringCenterX + mixed.steeringRadius,
  'Steering Dial frame must reserve separate horizontal slots for speed, steering and gear')
assert(mixed.rpmTop + mixed.rpmHeight < mixed.steeringCenterY - mixed.steeringRadius
  and mixed.historyTop > mixed.steeringCenterY + mixed.steeringRadius,
  'RPM, steering and lower-panel spaces must remain vertically separated')

state.absActive, state.tcActive, state.brake, state.throttle = true, true, 0.2, 0.2
draw('classic', {
  gt7SteeringStyle = 'dial', gt7RpmBarVisible = true,
  gt7PedalPosition = 'outer', gt7PedalStyle = 'modern',
  gt7RadarPresentation = 'column_9', gt7FlagPresentation = 'column_3'
})
for _, side in ipairs({ 'left', 'right' }) do
  local x = side == 'left' and mixed.brakeX or mixed.throttleX
  local blocks = {}
  for _, call in ipairs(calls) do
    if call.kind == 'polygon' then
      local left, top, right, bottom = bounds(call)
      if top >= mixed.pedalTop - 0.001 and bottom <= mixed.pedalTop + mixed.pedalHeight + 0.001
          and left >= x - mixed.pedalUpperExtraWidth - 0.001
          and right <= x + mixed.pedalWidth + mixed.pedalUpperExtraWidth + 0.001 then
        blocks[#blocks + 1] = call
      end
    end
  end
  assert(#blocks == 12, 'outer modern pedals must retain twelve blocks')
  local interventionColor = side == 'left' and Theme.colors.flagWhite or Theme.colors.red
  for i, block in ipairs(blocks) do
    if i > 10 then assert(block.color == interventionColor,
      'outer modern pedal top blocks must retain ABS/TC intervention colors') end
  end
end
state.absActive, state.tcActive, state.brake, state.throttle = nil, nil, 0.36, 0.82

for _, window in ipairs({ {460, 460}, {900, 360}, {1200, 420} }) do
  draw('classic', {
    gt7SteeringStyle = 'dial', gt7RpmBarVisible = true,
    gt7PedalPosition = 'outer', gt7PedalStyle = 'modern',
    gt7RadarPresentation = 'column_9', gt7FlagPresentation = 'column_3'
  }, state, window)
  for _, call in ipairs(calls) do
    local points = {}
    if call.a then points[#points + 1] = call.a end
    if call.b then points[#points + 1] = call.b end
    for _, pointValue in ipairs(call.points or {}) do points[#points + 1] = pointValue end
    for _, pointValue in ipairs(points) do
      assert(pointValue.x >= -0.01 and pointValue.x <= window[1] + 0.01
        and pointValue.y >= -0.01 and pointValue.y <= window[2] + 0.01,
        'mixed composition primitives must stay inside fitted small windows')
    end
  end
end

local steeringLayout = Layouts.get('steering_dial')
local function steeringNeedle()
  for _, call in ipairs(calls) do
    if call.kind == 'line' and call.color == Theme.colors.cyan and call.thickness == 4
        and near(call.a.x, steeringLayout.steeringCenterX)
        and near(call.a.y, steeringLayout.steeringCenterY) then return call end
  end
end
for _, value in ipairs({ -2, -1, 0, 1, 2 }) do
  state.steeringInput = value
  draw('steering_dial')
  local needle = assert(steeringNeedle(), 'steering dial must draw a needle')
  local clamped = math.max(-1, math.min(1, value))
  assert(near(needle.b.x, steeringLayout.steeringCenterX + clamped * steeringLayout.steeringRadius)
    and near(needle.b.y, steeringLayout.steeringCenterY - (clamped == 0 and steeringLayout.steeringRadius or 0)),
    'steering dial must clamp to a centered semicircle')
end
draw('steering_dial', { showSteering = false })
assert(not steeringNeedle(), 'steering toggle must hide the needle')
assert(indicatorColor(steeringLayout, 'left'), 'hiding steering must preserve turn indicators')
state.steeringInput = 0

local function rpmBlocks(layout)
  local count = 0
  for _, call in ipairs(calls) do
    if call.kind == 'rect_fill' and near(call.a.y, layout.rpmTop)
        and near(call.b.y, layout.rpmTop + layout.rpmHeight)
        and call.a.x >= layout.rpmLeft and call.b.x <= layout.rpmRight + 0.001 then count = count + 1 end
  end
  return count
end
for _, id in ipairs(ids) do
  local layout = Layouts.get(id)
  draw(id)
  assert(rpmBlocks(layout) == (id == 'modern' and 0 or layout.rpmSegments), 'RPM bar visibility must match layout')
  draw(id, { gt7LowerPanelMode = 'invisible' })
  for _, call in ipairs(calls) do
    if call.kind == 'polygon' or call.kind == 'rect_fill' then
      local _, top = bounds(call)
      assert(not near(top, layout.historyTop), 'Hidden must remove the entire lower panel')
    end
  end
end
local classicCalls = #draw('classic')
assert(#draw('invalid') == classicCalls and Layouts.width == 1440
  and Layouts.radarRange == 18 and Layouts.get('classic').gearPodCenterX == 875,
  'new compositions must not mutate Classic or telemetry constants')

local scenarios = 0
for _, id in ipairs(ids) do
  for _, lower in ipairs({ 'limit', 'ffb', 'pedal_history', 'invisible' }) do
    for _, theme in ipairs({ 'dark', 'light' }) do
      for _, unit in ipairs({ 'km/h', 'mph' }) do
        for _, needle in ipairs({ 'digital', 'analog' }) do
          for _, window in ipairs({ {460, 460}, {900, 360}, {1200, 420} }) do
            state.speedText, state.speedUnit, state.gearText = '1234', unit, unit == 'mph' and 'R' or 'N'
            draw(id, { gt7LowerPanelMode = lower, theme = theme, speedUnit = unit,
              gt7SpeedNeedleMode = needle, gt7RpmNeedleMode = needle == 'analog' and 'digital' or 'analog',
              hudScale = window[1] == 460 and 0.55 or (window[1] == 900 and 1.15 or 0.72) }, state, window)
            scenarios = scenarios + 1
          end
        end
      end
    end
  end
end
state.speedText, state.speedUnit, state.gearText = '139', 'km/h', '2'
state.rpmWarning, state.rpmRedline = true, true
for _, id in ipairs(ids) do draw(id) end
state.rpmWarning, state.rpmRedline = false, false
local history = state.pedalHistory
state.pedalHistory, state.proximityRadarAvailable = nil, false
for _, id in ipairs(ids) do draw(id) end
state.pedalHistory, state.proximityRadarAvailable = history, true

print('GT7 layouts: settings, persistence, pedal geometry, radar/flags, steering and ' .. scenarios .. ' drawing scenarios passed')
local function drawDial(overrides, drawState, window)
  local options = {instrumentMode='analog', analogNeedleStyle='a01', analogAuxiliaryMode='auto',
    hudScale=0.72, opacity=1, backgroundOpacity=0.72, theme='dark', showSteering=true,
    showLights=true, showClutch=true, showTcAbsLevels=true}
  for key, value in pairs(overrides or {}) do options[key] = value end
  width, height = 620, 620
  if window then width, height = window[1], window[2] end
  calls = {}
  require('ui/dial').draw(drawState or state, options)
  assert(fonts == 0 and alphaDepth == 0, 'dial drawing must balance fonts and styles')
  return calls
end
local function drawNeedle(center, scale, angle, preset, palette, lights, alert, backlight)
  calls = {}
  require('ui/instrument_needle').draw(center, scale, angle, preset, palette, lights, alert, backlight)
  assert(alphaDepth == 0, 'needle drawing must balance styles')
  return calls
end
local function drawRenderer(renderer, drawState, options, window)
  width,height=window[1],window[2]
  calls={}
  renderer.draw(drawState,options)
  assert(fonts==0 and alphaDepth==0,'drawing must balance fonts and styles')
  return calls
end
return { draw=draw, drawDial=drawDial, drawNeedle=drawNeedle, drawRenderer=drawRenderer, state=state,
  pendingCombos=pendingCombos, pendingButtons=pendingButtons, pendingSliders=pendingSliders }
