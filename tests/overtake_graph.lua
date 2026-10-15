package.path = './?.lua;./?/init.lua;' .. package.path

local History = require('modules/notices/src/gap_history')
local history = History.new()
for i = 0, 600 do history:add(i / 100, 10 - i / 100, false) end
local frozen = history:snapshot(6)
assert(#history.points <= 512 and math.abs(frozen.points[1].progress - 2) < 0.000001,
  'The graph retains and clips a bounded four-lap window')
assert(math.abs(frozen.points[1].gap - 8) < 0.000001)
history.points[#history.points].gap = 999
assert(frozen.points[#frozen.points].gap == 4, 'An event owns a frozen copy of its graph')

local partial = History.new()
partial:add(3.5, 2, false)
partial:add(3.6, nil)
partial:add(3.7, 1, true)
local partialGraph = partial:snapshot(4)
assert(partialGraph.points[1].progress == 3.5 and #partialGraph.points == 2,
  'Partial history remains in its real position instead of filling four laps')
assert(partialGraph.points[2].breakBefore and partialGraph.points[2].estimated,
  'Unavailable intervals break the curve; estimated samples retain their source')

ac = {SessionType = {Race = 1}}
local State = require('modules/notices/src/state')
local state = State.new()
local sim = {currentSessionIndex = 1, isSessionStarted = true}
local player = {index = 0, driver = 'PLAYER', racePosition = 2, progress = 0}
local rival = {index = 1, driver = 'RIVAL', carID = 'gt3', racePosition = 1, progress = 0,
  intervalSource = 'history', car = {wheelsOutside = 0}}
local settings = {overtakeEnabled = true, engineDamageThreshold = 0.2,
  suspensionDamageThreshold = 0.05, bodyDamageThreshold = 0.2}
for i = 0, 100 do
  local pass = i == 100
  player.progress, player.racePosition = i / 20, pass and 1 or 2
  rival.racePosition, rival.intervalSeconds = pass and 2 or 1, pass and -0.1 or 12 - i / 10
  rival.car.wheelsOutside = i == 98 and 4 or 0
  sim.currentSessionTime = i * 500
  state:update(0.5, {lapCount = 0}, sim, nil, nil, settings, {}, nil, nil,
    {sim = sim, session = {type = 1}, rows = {player, rival}, localRow = player,
      timeline = {time = i / 2, measuredClock = true}, historyReset = i == 0})
end
local notice = state.notice
assert(notice and notice.incident == 'offtrack' and notice.value == 'OFF TRACK')
local points = notice.gapHistory.points
assert(notice.gapHistory.endProgress == 5 and points[1].progress == 1
  and points[#points].gap == -0.1 and points[1].gap > 0,
  'The event includes four laps and its actual signed pass interval, even after an incident')
local sawIncident = false
for _, point in ipairs(points) do sawIncident = sawIncident or point.incident == 'offtrack' end
assert(sawIncident, 'The graph retains the incident context that cleared the pace history')

-- A quick repass keeps the signed history from when this rival was behind,
-- while the first summary and the queued one own different frozen snapshots.
for i = 101, 104 do
  local ahead = i == 103
  player.progress, player.racePosition = i / 20, ahead and 2 or 1
  rival.racePosition, rival.intervalSeconds = ahead and 1 or 2, ahead and 1 or -0.3
  rival.car.wheelsOutside = 0
  sim.currentSessionTime = i * 500
  state:update(0.5, {lapCount = 0}, sim, nil, nil, settings, {}, nil, nil,
    {sim = sim, session = {type = 1}, rows = {player, rival}, localRow = player,
      timeline = {time = i / 2, measuredClock = true}})
end
local queued = state.overtakeQueue[1].notice.gapHistory
assert(queued.endProgress == 5.2 and notice.gapHistory.endProgress == 5,
  'A queued repass cannot move the active summary graph forward')
local sawBehind = false
for _, point in ipairs(queued.points) do
  sawBehind = sawBehind or point.progress > 5 and point.progress < 5.2 and point.gap < 0
end
assert(sawBehind, 'Four-lap history includes this rival being behind before a repass')

local harness = dofile('tests/gt7_layouts.lua')
local Display = require('modules/notices/src/display')
local General = require('src/general_settings')
assert(Display.heightFor(notice, {}) == 96 and Display.heightFor(notice, {expandedOvertake = true}) == 264)
assert(Display.heightFor({kind = 'blue'}, {expandedOvertake = true}) == 96,
  'Only overtake summaries expand')
local graphCases = {notice.gapHistory, partialGraph, {points = {}, endProgress = 4}}
for _, theme in ipairs({'dark', 'light'}) do
  General.values.theme = theme
  for _, size in ipairs({{660,264}, {420,168}}) do
    for _, graph in ipairs(graphCases) do
      notice.gapHistory = graph
      local calls = harness.drawRenderer(Display, notice, {expandedOvertake = true}, size)
      local sawGraph = false
      for _, call in ipairs(calls) do
        sawGraph = sawGraph or call.kind == 'text' and call.text:find('GAP TO RIVAL', 1, true) ~= nil
        if call.kind == 'line' then
          for _, point in ipairs({call.a, call.b}) do
            assert(point.x >= 0 and point.x <= size[1] and point.y >= 0 and point.y <= size[2],
              'Graph lines must fit both normal and compact windows')
          end
        end
      end
      assert(sawGraph, 'Expanded summaries render their history, including empty-history feedback')
    end
  end
end
print('Overtake graph: four-lap clipping, bounded/frozen history, missing data, incident context and 12 render scenarios passed')
