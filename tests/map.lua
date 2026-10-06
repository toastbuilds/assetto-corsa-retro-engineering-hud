package.path = './?.lua;./?/init.lua;' .. package.path

-- Standalone CSP doubles: this suite does not load another suite or the root app.
local Vec2 = {}
Vec2.__index = Vec2
function Vec2.__add(a, b) return vec2(a.x + b.x, a.y + b.y) end
function Vec2.__sub(a, b) return vec2(a.x - b.x, a.y - b.y) end
function Vec2.__mul(a, b)
  if type(a) == 'number' then return vec2(a * b.x, a * b.y) end
  return vec2(a.x * b, a.y * b)
end
function Vec2.__div(a, b) return vec2(a.x / b, a.y / b) end
function vec2(x, y) return setmetatable({x = x or 0, y = y or 0}, Vec2) end
function vec3(x, y, z) return {x = x, y = y, z = z} end
function rgbm(r, g, b, mult) return {r = r, g = g, b = b, mult = mult} end
local function noop() end
local function near(a, b) assert(math.abs(a - b) < 0.00001, tostring(a) .. ' ~= ' .. tostring(b)) end
local function sameColor(a, b) return a.r == b.r and a.g == b.g and a.b == b.b end

local stores, field, player = {}, {}, nil
local now, sessionType = 0, 1
local sim = {currentSessionIndex = 0, trackLengthM = 1000}
local function trackWorld(spline)
  return vec3(150 * math.cos(spline * 2 * math.pi), 0, 100 * math.sin(spline * 2 * math.pi))
end
ac = {
  SessionType = {Race = 1}, FlagType = {},
  storage = function(defaults, prefix)
    local target = stores[prefix] or {}
    stores[prefix] = target
    for key, value in pairs(defaults) do if target[key] == nil then target[key] = value end end
    return target
  end,
  getCar = function(index) assert(index == 0); return player end,
  getSim = function() return sim end,
  getSession = function(index) assert(index == 0); return {type = sessionType} end,
  getTrackFullID = function() return 'map-test' end,
  trackCoordinateToWorld = function(coordinate) return trackWorld(coordinate.z) end
}
ac.iterateCars = setmetatable({leaderboard = function() return ipairs(field) end}, {
  __call = function() return ipairs(field) end
})

local fills, rings, texts, routePoints = {}, {}, {}, {}
local clips, styles = 0, 0
local clicks, combos, checks = {}, {}, {}
ui = {
  time = function() return now end,
  getCursor = function() return vec2(0, 0) end,
  windowSize = function() return vec2(460, 460) end,
  pushClipRect = function() clips = clips + 1 end,
  popClipRect = function() clips = clips - 1 end,
  pushStyleVarAlpha = function() styles = styles + 1 end,
  popStyleVar = function(count) styles = styles - count end,
  drawCircleFilled = function(center, radius, color)
    fills[#fills + 1] = {center = center, radius = radius, color = color}
  end,
  drawCircle = function(center, radius, color)
    rings[#rings + 1] = {center = center, radius = radius, color = color}
  end,
  drawLine = noop, pathClear = noop, pathStroke = noop,
  pathLineTo = function(point) routePoints[#routePoints + 1] = point end,
  pushDWriteFont = noop, popDWriteFont = noop,
  measureDWriteText = function(text, size) return vec2(#text * size * 0.6, size) end,
  dwriteDrawText = function(text, size, point) texts[#texts + 1] = {text = text, size = size, point = point} end,
  header = noop, separator = noop, textWrapped = noop, text = noop, sameLine = noop,
  availableSpaceX = function() return 460 end,
  ComboFlags = {None = 0},
  combo = function(id, value)
    local selected = combos[id]; combos[id] = nil
    return selected or value, selected ~= nil
  end,
  checkbox = function(label) local clicked = checks[label]; checks[label] = nil; return clicked or false end,
  button = function(label) local clicked = clicks[label]; clicks[label] = nil; return clicked or false end,
  slider = function(_, value) return value, false end
}

local Markers = require('modules/map/src/markers')
local Settings = require('modules/map/src/settings')
local General = require('src/general_settings')
local Theme = require('src/theme')
local Geometry = require('modules/map/src/geometry')
local Map = require('modules/map/main')

for position = 1, 12 do
  local spline = 0.4 + position / 100
  field[position] = {
    index = position == 6 and 0 or position, racePosition = position,
    lapCount = 7, splinePosition = spline, position = trackWorld(spline), look = vec3(1, 0, 0),
    isConnected = true, isActive = true, isInPitlane = false, wheelsOutside = 0
  }
end
player = field[6]
field[1].lapCount = 9
field[2].isHidingLabels = true
field[3].lapCount = 8
field[4].lapCount = 6
field[9].isActive = false -- A connected car stays on the map even when inactive.
field[10].isConnected = false
assert(not Markers.visible(field[2]) and not Markers.visible(field[10]))
assert(Markers.visible(field[9]))
assert(not Markers.visible(nil) and not Markers.visible({index = -1}))
assert(not Markers.visible({index = 1.5}) and not Markers.visible({index = 0/0}))
assert(not Markers.visible({index = 0, isConnected = false}))
assert(not Markers.visible(setmetatable({}, {__index = function() error('unavailable car') end})))
-- Optional CSP fields can be absent or throw without crashing; index must exist.
local missingFields = setmetatable({index = 8}, {__index = function() error('unavailable field') end})
assert(Markers.visible(missingFields))

local collected = Markers.collect()
assert(#collected == 10 and Markers.player(collected) == player)
local positions, ordered = Markers.positions(collected, true)
assert(positions[0] == 6 and positions[3] == 3 and positions[12] == 12)
assert(positions[2] == nil and positions[10] == nil)
local selected = Markers.numbered(positions, ordered, player, 'selected')
local expectedSelected = {[1] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true, [12] = true}
for index, position in pairs(positions) do assert((selected[index] ~= nil) == (expectedSelected[position] == true)) end
assert(Markers.numbered(positions, ordered, player, 'all') == positions)
for _, localPosition in ipairs({1, 2, 11, 12}) do
  local edgePlayer = field[localPosition]
  local edge = Markers.numbered(positions, ordered, edgePlayer, 'selected')
  for index, position in pairs(positions) do
    local expected = position == 1 or position == 12
      or (positions[edgePlayer.index] and math.abs(position - localPosition) <= 2)
    assert((edge[index] ~= nil) == (expected == true))
  end
end
local noPlayer = Markers.numbered(positions, ordered, nil, 'selected')
assert(noPlayer[1] == 1 and noPlayer[12] == 12 and noPlayer[0] == nil)

-- Race sorting keeps official numbers; nonrace order comes from the leaderboard.
local shuffled = {field[12], player, field[3], field[1], field[4]}
local racePositions, raceOrder = Markers.positions(shuffled, true)
assert(raceOrder[1] == field[1] and raceOrder[5] == field[12] and racePositions[0] == 6)
local practicePositions, practiceOrder = Markers.positions(shuffled, false)
assert(practiceOrder[1] == field[12] and practicePositions[12] == 1 and practicePositions[0] == 2)
local invalidPositions = {{index = 20, racePosition = 0, lapCount = 1},
  {index = 21, racePosition = 0/0, lapCount = 2}}
local fallbackPositions = Markers.positions(invalidPositions, true)
assert(fallbackPositions[21] == 1 and fallbackPositions[20] == 2)

-- Collect deduplicates and falls back when the leaderboard API is unavailable.
local savedField, leaderboard = field, ac.iterateCars.leaderboard
field = {savedField[1], savedField[1], savedField[2], savedField[10]}
assert(#Markers.collect() == 2) -- Leader plus separately fetched local car.
ac.iterateCars.leaderboard = function() error('leaderboard unavailable') end
field = savedField
assert(#Markers.collect() == 10)
ac.iterateCars.leaderboard = function() return ipairs({}) end
assert(#Markers.collect() == 10)
ac.iterateCars.leaderboard = leaderboard

assert(Markers.colorRole(player, player, {[0] = 1}, true) == 'amber')
assert(Markers.colorRole(field[1], player, positions, true) == 'flagPurple')
assert(Markers.colorRole(field[3], player, positions, true) == 'cyan')
assert(Markers.colorRole(field[4], player, positions, true) == 'cyanDim')
assert(Markers.colorRole(field[5], player, positions, true) == 'green')
for _, spline in ipairs({0, 0.01, 0.99, 1}) do
  assert(Markers.colorRole({index = 30, lapCount = 7, splinePosition = spline}, player, positions, true) == 'green')
end
for _, laps in ipairs({-1, 1.5, 0/0, math.huge, 'invalid'}) do
  assert(Markers.colorRole({index = 30, lapCount = laps}, player, positions, true) == 'cyan')
end
assert(Markers.colorRole({index = 30}, player, positions, true) == 'cyan')
assert(Markers.colorRole(field[4], nil, positions, true) == 'cyan')
for _, car in ipairs({field[3], field[4], field[5]}) do
  assert(Markers.colorRole(car, player, positions, false) == 'cyan')
end
assert(Markers.colorRole(field[1], player, positions, false) == 'flagPurple')
assert(Markers.colorRole(field[12], player, practicePositions, false) == 'flagPurple')

player.wheelsOutside = 4
near(Markers.offTrackPulse(player, true, 0), 0)
near(Markers.offTrackPulse(player, true, 0.3), 0.5)
near(Markers.offTrackPulse(player, true, 0.6), 1)
near(Markers.offTrackPulse(player, true, 1.2), 0)
assert(Markers.offTrackPulse(player, false, 0.6) == nil)
player.isInPitlane = true
assert(Markers.offTrackPulse(player, true, 0.6) == nil)
player.isInPitlane = false
for _, wheels in ipairs({0, 1, 2, 3, 5, 0/0}) do
  player.wheelsOutside = wheels
  assert(Markers.offTrackPulse(player, true, 0.6) == nil)
end
assert(Markers.offTrackPulse(nil, true, 0.6) == nil)
assert(Markers.offTrackPulse(missingFields, true, 0.6) == nil)
player.wheelsOutside = 4
field[2].wheelsOutside, field[3].wheelsOutside, field[4].wheelsOutside, field[10].wheelsOutside = 4, 4, 4, 4
field[4].isInPitlane = true
assert(Markers.offTrackPulse(field[2], true, 0.6) == nil)
assert(Markers.offTrackPulse(field[10], true, 0.6) == nil)

local values = Settings.current()
assert(values.numberMode == 'selected' and values.showOffTrack == true)
values.numberMode, values.showOffTrack = 'invalid', nil
assert(Settings.current().numberMode == 'selected' and values.showOffTrack == true)
values.numberMode, values.showOffTrack = 'all', false
assert(Settings.current().numberMode == 'all' and values.showOffTrack == false)
clicks['>  Personalization##map.personalization'] = true
checks['Off-track warning rings'] = true
combos['##map.numberMode'] = 0
Map.windowSettings()
assert(values.numberMode == 'selected' and values.showOffTrack == true)
values.miniRadius, values.miniOrientation = 777, 'fixed'
combos['##map.mode'], combos['##map.numberMode'] = 1, 1
checks['Off-track warning rings'] = true
Map.windowSettings()
assert(values.mode == 'mini' and values.numberMode == 'all' and values.showOffTrack == false)
combos['##map.mode'] = 0
Map.windowSettings()
assert(values.mode == 'full' and values.numberMode == 'all' and values.showOffTrack == false)
values.mode = 'mini'
clicks['Reset appearance##map'] = true
Map.windowSettings()
assert(values.mode == 'mini' and values.miniRadius == 777 and values.miniOrientation == 'fixed')
assert(values.numberMode == 'selected' and values.showOffTrack == true)
clicks['Reset all##map'], clicks['Confirm reset##map'] = true, true
Map.windowSettings()
assert(values.mode == 'full' and values.miniRadius == 500 and values.miniOrientation == 'heading')

General.values.backgroundOpacity = 0
local function render()
  fills, rings, texts, routePoints = {}, {}, {}, {}
  Map.windowMain()
  assert(clips == 0 and styles == 0, 'drawing stacks must balance')
end
local function checkDrawing(theme, race, numberMode)
  General.values.theme = theme
  sessionType = race and ac.SessionType.Race or 2
  values.numberMode, values.showOffTrack = numberMode, true
  now = 0
  render()
  local palette = Theme.get(theme)
  local accents = {}
  for _, fill in ipairs(fills) do
    if not sameColor(fill.color, palette.void) then accents[#accents + 1] = fill end
  end
  assert(#accents == 10, 'hidden and disconnected cars must not be drawn')
  local roles = race and {'flagPurple', 'cyan', 'cyanDim', 'green', 'green', 'green', 'green', 'green', 'green', 'amber'}
    or {'flagPurple', 'cyan', 'cyan', 'cyan', 'cyan', 'cyan', 'cyan', 'cyan', 'cyan', 'amber'}
  for i, role in ipairs(roles) do assert(sameColor(accents[i].color, palette[role]), 'wrong marker color: ' .. role) end
  local shown = {}
  for _, text in ipairs(texts) do shown[tonumber(text.text)] = true end
  local displayPositions, displayOrder = Markers.positions(collected, race)
  local wanted = Markers.numbered(displayPositions, displayOrder, player, numberMode)
  local count = 0
  for _, position in pairs(wanted) do assert(shown[position]); count = count + 1 end
  assert(#texts == count, 'number mode must apply to every map view')
  assert(#rings == 2, 'only the local and eligible remote car should have warning rings')
  for _, ring in ipairs(rings) do assert(sameColor(ring.color, palette.amber)); near(ring.color.mult, 0.45) end
  local lowRadius = rings[1].radius
  now = 0.6
  render()
  near(rings[1].radius - lowRadius, 1.5 * values.markerScale)
  near(rings[1].color.mult, 0.9)
  values.showOffTrack = false
  render()
  assert(#rings == 0 and #texts == count, 'disabling warnings must preserve numbering')
end

local drawings = 0
for _, view in ipairs({'full', 'heading', 'fixed'}) do
  values.mode = view == 'full' and 'full' or 'mini'
  values.miniOrientation = view == 'fixed' and 'fixed' or 'heading'
  values.miniRadius = 500
  for _, theme in ipairs({'dark', 'light'}) do
    for _, race in ipairs({true, false}) do
      for _, numberMode in ipairs({'selected', 'all'}) do
        checkDrawing(theme, race, numberMode)
        drawings = drawings + 3
      end
    end
  end
end

-- Check the existing full rotation, both mini orientations and inverse zoom.
local geometry = Geometry.ensure(sim)
values.mode, values.showOffTrack = 'full', true
render()
local padding = math.max(18, 21 * values.markerScale + 4,
  values.carDotSize + 5 * values.markerScale, 3.5 * values.pathWidth + 3)
local bounds = geometry.bounds
local scale = math.min((460 - 2 * padding) / (bounds.maxY - bounds.minY),
  (460 - 2 * padding) / (bounds.maxX - bounds.minX))
local first = geometry.points[1]
near(routePoints[1].x, 230 - (first.v - (bounds.minY + bounds.maxY) / 2) * scale)
near(routePoints[1].y, 230 + (first.u - (bounds.minX + bounds.maxX) / 2) * scale)
values.mode, values.miniRadius = 'mini', 200
for _, orientation in ipairs({'heading', 'fixed'}) do
  values.miniOrientation = orientation
  render()
  local zoomed = routePoints[1]
  local origin = Geometry.carPosition(player)
  local miniScale = 460 * 0.46 / 200
  if orientation == 'heading' then
    near(zoomed.x, 230 + (first.z - origin.z) * miniScale)
    near(zoomed.y, 460 * 0.59 - (first.x - origin.x) * miniScale)
  else
    local x, y = Geometry.project(origin)
    near(zoomed.x, 230 - (first.v - y) * miniScale)
    near(zoomed.y, 460 * 0.59 - (first.u - x) * miniScale)
  end
  values.miniRadius = 400
  render()
  near(routePoints[1].x - 230, (zoomed.x - 230) / 2)
  near(routePoints[1].y - 460 * 0.59, (zoomed.y - 460 * 0.59) / 2)
  values.miniRadius = 200
end

print('Map: selection, lap colors, filtering, warning pulses, settings/reset, rotation/zoom and ' .. drawings .. ' drawings passed')
