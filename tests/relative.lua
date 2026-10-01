package.path = './?.lua;./?/init.lua;' .. package.path

local stored = {}
ac = {
  storage = setmetatable({}, { __call = function(_, defaults, prefix)
    stored[prefix] = stored[prefix] or {}
    for key, value in pairs(defaults) do
      if stored[prefix][key] == nil then stored[prefix][key] = value end
    end
    return stored[prefix]
  end })
}

local Records = require('modules/relative/src/records')
local function updateRecord(record, sample, carID)
  sample.index, sample.carID = 0, carID or 'gt3'
  record:update(sample)
end
stored['retro-ui.relative.track.v1.spa[]gp'] = { best = 100000 }
local records = Records.new()
records:setTrack('spa[]gp', 'Spa', 'gt3')
assert(records.sessionBest == nil and records.trackBest == nil)
updateRecord(records, { bestLapTimeMs = 138462 })
updateRecord(records, { bestLapTimeMs = 136903 })
assert(records.sessionBest == 136903 and records.trackBest == 136903)
records:update({ index = 1, carID = 'gt3', bestLapTimeMs = 100000 })
records:update({ index = 0, carID = 'prototype', bestLapTimeMs = 100000 })
assert(records.sessionBest == 136903 and records.trackBest == 136903, 'rivals and other models must not change personal records')
assert(stored['retro-ui.relative.track.v1.spa[]gp'].best == 100000, 'legacy grid history must remain intact and unused')
updateRecord(records, { previousLapTimeMs = 120000, isLastLapValid = false, bestLapTimeMs = 120000 })
updateRecord(records, { previousLapTimeMs = 120000 })
updateRecord(records, { previousLapTimeMs = 120000, isLastLapValid = true, teleported = true })
updateRecord(records, { bestLapTimeMs = 110000, replay = true })
assert(records.trackBest == 136903, 'invalid, missing-validity, teleport and replay laps must not replace records')
updateRecord(records, { bestLapTimeMs = 0 / 0 })
updateRecord(records, { bestLapTimeMs = math.huge })
updateRecord(records, { bestLapTimeMs = -1 })
assert(records.trackBest == 136903)
records:resetSession()
updateRecord(records, { bestLapTimeMs = 140000 })
assert(records.sessionBest == 140000 and records.trackBest == 136903)
local reloaded = Records.new()
reloaded:setTrack('spa[]gp', 'Spa', 'gt3')
assert(reloaded.trackBest == 136903 and reloaded.sessionBest == nil, 'track record must survive app reload')
reloaded:setTrack('spa[]short', 'Spa Short', 'gt3')
assert(reloaded.trackBest == nil, 'layouts must have independent records')
reloaded:setTrack('spa[]gp', 'Spa', 'gt3')
updateRecord(reloaded, { previousLapTimeMs = 135001, isLastLapValid = true })
assert(reloaded.trackBest == 135001)
reloaded:setTrack('spa[]gp', 'Spa', 'prototype')
assert(reloaded.trackBest == nil and reloaded.sessionBest == nil, 'car changes must reset both references')
updateRecord(reloaded, { bestLapTimeMs = 110000 }, 'prototype')
reloaded:setTrack('spa[]gp', 'Spa', 'gt3')
assert(reloaded.trackBest == 135001 and reloaded.sessionBest == nil, 'returning to a car must load only its history')
reloaded:setTrack('spa[]gp', 'Spa', nil)
reloaded:update({ index = 0, bestLapTimeMs = 100000 })
assert(reloaded.trackBest == nil and reloaded.sessionBest == nil, 'missing car identity must not create a shared record')
assert(Records.timeText(138462) == '2:18.462')
assert(Records.timeText(59999) == '0:59.999')
assert(Records.timeText(60000) == '1:00.000')
assert(Records.timeText(nil) == '-:--.---')

local Sectors = require('modules/relative/src/sectors')
local sectors = Sectors.new()
local function sample(lap, sector, time, extra)
  local s = { carID = 'car', lapCount = lap, currentSector = sector,
    lapTimeMs = 1000, previousSectorTime = time, isLapValid = true }
  for key, value in pairs(extra or {}) do s[key] = value end
  return s
end
sectors:update(1, 'GT3', sample(0, 0), 0)
sectors:update(1, 'GT3', sample(0, 1, 29000), 1)
sectors:update(0, 'GT3', sample(0, 0), 0)
sectors:update(0, 'GT3', sample(0, 1, 30000), 1)
assert(sectors:snapshot('GT3').status[1] == 'improved')
sectors:update(0, 'GT3', sample(0, 2, 31000), 2)
sectors:update(0, 'GT3', sample(1, 0, 33000, { previousLapTimeMs = 94000, isLastLapValid = true }), 3)
sectors:update(0, 'GT3', sample(1, 1, 28000), 4)
assert(sectors:snapshot('GT3').status[1] == 'record')
sectors:update(0, 'GT3', sample(1, 2, 32000), 5)
assert(sectors:snapshot('GT3').status[2] == 'slower')
sectors:update(0, 'GT3', sample(2, 0, 33000, { previousLapTimeMs = 93000, isLastLapValid = false }), 6)
assert(sectors:snapshot('GT3').status[3] == 'invalid', 'last-lap validity must reject the finishing sector')
sectors:update(0, 'GT3', sample(2, 1, 10000, { isLapValid = false }), 7)
assert(sectors:snapshot('GT3').status[1] == 'invalid')
assert(sectors:snapshot('GT3').best[1] == 28000)
sectors:reset()
assert(next(sectors:snapshot('GT3').status) == nil)

-- Exercise the real panel with CSP drawing and telemetry stand-ins. Capture
-- primitives so resizing and optional sections can be checked without a game.
local Vec = {}
Vec.__index = Vec
function Vec.__add(a, b) return vec2(a.x + b.x, a.y + b.y) end
function Vec.__sub(a, b) return vec2(a.x - b.x, a.y - b.y) end
function vec2(x, y) return setmetatable({ x = x or 0, y = y or 0 }, Vec) end
function rgbm(r, g, b, a) return { r = r, g = g, b = b, mult = a or 1 } end
function rgb(r, g, b)
  return { r = r, g = g, b = b, clone = function(self) return rgb(self.r, self.g, self.b) end }
end
__dirname = '.'
local globalSettings = require('src/general_settings').values
local sim = { currentSessionIndex = 0, ambientTemperature = 24, roadTemperature = 31,
  rainIntensity = 0, weatherConditions = { currentType = 1, upcomingType = 1 } }
local trackID, trackName = 'render[]gp', 'Spa-Francorchamps'
local cars = {}
local function car(index, driver, best, spline)
  return { index = index, isActive = true, isConnected = true, lapCount = 2, splinePosition = spline,
    physicsAvailable = true, isLapValid = true, currentSector = 0, lapTimeMs = 5000,
    bestLapTimeMs = best, racePosition = index == 0 and 11 or index + 7, speedKmh = 150,
    id = function() return 'test_gt3_' .. index end, name = function() return 'GT3' end,
    driverName = function() return driver end, driverNumber = function() return index + 7 end }
end
cars[1] = car(0, 'LUBBO', 140000, 0.5)
for i, driver in ipairs({ 'M. Rossi', 'A. Costa', 'J. Miller', 'D. Garcia', 'S. Martin', 'L. Moreau' }) do
  cars[i + 1] = car(i, driver, 138462 + i * 100, i <= 3 and 0.5 + (4 - i) * 0.005 or 0.5 - (i - 3) * 0.005)
end
ac.getSim = function() return sim end
ac.getCar = function() return cars[1] end
ac.getTrackFullID = function() return trackID end
ac.getTrackName = function() return trackName end
ac.iterateCars = function() return ipairs(cars) end
ac.INIConfig = { load = function() return { get = function() return '' end } end }
ac.WeatherType = { Clear = 1 }
ac.log = function() end
local errors = {}
ac.error = function(message) errors[#errors + 1] = message end

local width, height, now = 560, 420, 0
local calls, path, clips = {}, {}, {}
local function capture(kind, data)
  data.kind = kind
  data.clip = clips[#clips]
  calls[#calls + 1] = data
end
local function noop() end
ui = {
  pushStyleVarAlpha = function() end, popStyleVar = function() end,
  windowWidth = function() return width end,
  windowSize = function() return vec2(width, height) end,
  time = function() return now end,
  measureDWriteText = function(value, size) return vec2(#tostring(value) * size * 0.56, size) end,
  pathClear = function() path = {} end,
  pathLineTo = function(point) path[#path + 1] = point end,
  pathFillConvex = function(color) capture('polygon', { points = path, color = color }) end,
  pathStroke = function(color, _, thickness) capture('outline', { points = path, color = color, thickness = thickness }) end,
  drawRectFilled = function(tl, br, color) capture('rect', { tl = tl, br = br, color = color }) end,
  drawRect = function(tl, br, color) capture('border', { tl = tl, br = br, color = color }) end,
  drawLine = function(tl, br, color, thickness) capture('line', { tl = tl, br = br, color = color, thickness = thickness }) end,
  drawCircleFilled = function(center, radius, color) capture('circle', { center = center, radius = radius, color = color }) end,
  drawCircle = function(center, radius, color) capture('ring', { center = center, radius = radius, color = color }) end,
  dwriteDrawText = function(value, size, pos, color) capture('text', { text = value, size = size, pos = pos, color = color }) end,
  pushClipRect = function(tl, br) clips[#clips + 1] = { tl = tl, br = br } end,
  popClipRect = function() table.remove(clips) end,
  text = function(value) error('Unexpected fallback text: ' .. value) end,
  textWrapped = noop, header = noop, checkbox = function() return false end,
  slider = function(_, value) return value, false end
}
local panel = require('modules/relative/main')
local settings = stored['retro-ui.relative.']
local function tick()
  now = now + 0.1
  panel.update(0.1)
  assert(#errors == 0, table.concat(errors, '\n'))
end
local function render()
  calls, clips = {}, {}
  panel.windowMain()
  assert(#errors == 0, table.concat(errors, '\n'))
  assert(#clips == 0, 'drawing clips must be balanced')
  local texts = {}
  for _, c in ipairs(calls) do
    if c.kind == 'text' then
      texts[c.text] = c
      local bound = c.clip
      if not bound then
        assert(c.pos.x >= 0 and c.pos.y >= 0 and c.pos.x < width and c.pos.y + c.size <= height,
          'unclipped text must fit the window: ' .. c.text)
      end
    end
  end
  return texts
end
tick()
local texts = render()
assert(texts['SESSION RECORD'] and texts['TRACK RECORD'] and texts['S1'] and texts['S2'] and texts['S3'])
assert(texts['S1'].pos.y > texts['SESSION RECORD'].pos.y, 'sector bar must be below records')
local rowCount = 0
for value in pairs(texts) do if value:find('LUBBO') or value:find('Rossi') or value:find('Costa')
  or value:find('Miller') or value:find('Garcia') or value:find('Martin') or value:find('Moreau') then rowCount = rowCount + 1 end end
assert(rowCount == 7, 'default size must keep all seven relative rows')
cars[1].isLapValid, cars[1].currentSector, cars[1].previousSectorTime = false, 1, 10000
tick()
assert(render()['S1  X'], 'false validity must reach the sector tracker through optionalField')

local trackStore = stored['retro-ui.relative.personal.v2.render[]gp[#]test_gt3_0']
assert(trackStore.best == 140000, 'faster AI laps must be ignored by the live panel')
sim.currentSessionIndex = 1
for _, c in ipairs(cars) do c.bestLapTimeMs = 145000 end
tick()
texts = render()
assert(texts['2:25.000'] and texts['2:20.000'], 'session switch must preserve the personal track record')
cars[1].id = function() return 'test_gt4_player' end
cars[1].bestLapTimeMs = 150000
tick()
texts = render()
assert(texts['2:30.000'] and not texts['2:20.000'], 'switching cars must not display the previous model record')
assert(stored['retro-ui.relative.personal.v2.render[]gp[#]test_gt4_player'].best == 150000)
cars[1].id = function() return 'test_gt3_0' end
cars[1].bestLapTimeMs = 146000
tick()
texts = render()
assert(texts['2:26.000'] and texts['2:20.000'], 'returning to a model must restore its personal track record')
trackID, trackName = 'render[]short', 'Spa Short'
for _, c in ipairs(cars) do c.bestLapTimeMs = 0 end
tick()
assert(stored['retro-ui.relative.personal.v2.render[]short[#]test_gt3_0'].best == 0)
assert(render()['-:--.---'])

local cases = 0
for _, theme in ipairs({ 'dark', 'light' }) do
  globalSettings.theme = theme
  for _, size in ipairs({ { 400, 300 }, { 560, 420 }, { 800, 540 } }) do
    width, height = size[1], size[2]
    for mask = 0, 15 do
      settings.showSectors = mask % 2 == 1
      settings.showWeather = math.floor(mask / 2) % 2 == 1
      settings.showTemperatures = math.floor(mask / 4) % 2 == 1
      settings.showRecords = math.floor(mask / 8) % 2 == 1
      render()
      cases = cases + 1
    end
  end
end

-- Leave a representative actual draw trace available for an optional preview.
width, height = 560, 420
globalSettings.theme = 'dark'
settings.showSectors, settings.showWeather, settings.showTemperatures, settings.showRecords = true, true, true, true
trackID, trackName = 'render[]gp', 'Spa-Francorchamps'
cars[1].isLapValid, cars[1].currentSector = true, 0
for _, c in ipairs(cars) do c.bestLapTimeMs, c.lapCount = 138462, 3 end
tick()
for _, c in ipairs(cars) do c.splinePosition = c.splinePosition + 0.001 end
tick()
cars[1].currentSector, cars[1].previousSectorTime = 1, 30000
tick()
cars[1].currentSector, cars[1].previousSectorTime = 2, 31000
tick()
render()
relativeDrawCalls = calls
print('relative: records, validity, seven-row layout and ' .. cases .. ' drawing cases passed')
