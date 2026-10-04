package.path = './?.lua;./?/init.lua;' .. package.path
if TEST_EDITION == 'free' then
  package.preload['src/edition'] = assert(loadfile('free-edition/src/edition.lua'))
end

local now = 0
ui = {
  time = function() return now end
}

local sim = {
  currentSessionIndex = 0,
  isLive = true,
  lapSplits = { 0.33, 0.66, 0.95 },
  raceFlagType = 1
}
local session = { type = 1, isTimedRace = false, laps = 5 }
local player = {}
local rival = {}
local cars = { player, rival }

local iterateCars = setmetatable({}, {
  __call = function() return ipairs(cars) end
})
iterateCars.leaderboard = function() return ipairs(cars) end

ac = {
  SessionType = { Race = 1 },
  FlagType = { Green = 1, OneLapLeft = 14 },
  iterateCars = iterateCars,
  getSim = function() return sim end,
  getSession = function() return session end,
  getCar = function(index) return cars[index + 1] end,
  getTrackFullID = function() return 'timing-test[]gp' end,
  getTrackName = function() return 'Timing Test' end
}

local TimerState = require('modules/timer/src/state')
local LapsState = require('modules/laps/src/state')

local function resetCar(car, index, bestLap, bestSplits)
  for key in pairs(car) do car[key] = nil end
  car.index = index
  car.lapCount = 0
  car.currentSector = 0
  car.splinePosition = 0.10
  car.lapTimeMs = 0
  car.previousLapTimeMs = 0
  car.previousSectorTime = 0
  car.bestLapTimeMs = bestLap or 0
  car.bestSplits = bestSplits
  car.isLapValid = true
  car.isCurrentLapValid = true
  car.isInPitlane = false
  car.wheelsOutside = 0
end

local function resetWorld(playerBest, rivalBest, playerSplits, rivalSplits)
  now = 0
  sim.currentSessionIndex = 0
  sim.isLive = true
  sim.isReplayActive = false
  sim.replayCurrentFrame = nil
  sim.replayFrameMs = nil
  sim.replayPlaybackRate = nil
  sim.raceFlagType = 1
  session.type = ac.SessionType.Race
  session.isTimedRace = false
  session.laps = 5
  resetCar(player, 0, playerBest, playerSplits)
  resetCar(rival, 1, rivalBest, rivalSplits)
end

-- Timer: a player session-best sector creates one audio event, repeated frames
-- do not duplicate it, and a PB that is not session-best stays silent.
resetWorld(94000, 93000,
  { [0] = 33000, [1] = 34000, [2] = 27000 },
  { [0] = 32000, [1] = 30000, [2] = 28000 })
local timer = TimerState.new({ freezeDuration = 3 })
assert(timer:update())
player.currentSector = 1
player.previousSectorTime = 31000
player.lapTimeMs = 31000
assert(timer:update())
local timerSnapshot = timer:snapshot()
assert(timerSnapshot.result and timerSnapshot.result.kind == 'sector')
assert(timerSnapshot.result.status == 'session_best')
assert(timerSnapshot.result.delta == -1000, 'sector delta must use the old session record, not the personal best')
assert(timerSnapshot.sectorRecordEventId == 1 and timerSnapshot.lapRecordEventId == 0,
  'session-best sector must trigger only the sector record sound')
assert(timer:update())
assert(timer:snapshot().sectorRecordEventId == 1, 'same sector result must not replay audio')

player.currentSector = 2
player.previousSectorTime = 32000
player.lapTimeMs = 63000
assert(timer:update())
timerSnapshot = timer:snapshot()
assert(timerSnapshot.result.status == 'personal_best')
assert(timerSnapshot.result.delta == 2000,
  'a personal improvement can still have a positive gap to the session sector record')
assert(timerSnapshot.sectorRecordEventId == 1, 'personal best below the session record must stay silent')

player.isLapValid = false
assert(timer:update())
assert(timer:snapshot().invalid == true, 'live invalidation must be immediate')
now = 3.01
assert(timer:snapshot().result == nil, 'frozen result must expire after configured duration')

-- Result expiry must use the update delta even if the UI clock stops advancing.
resetWorld(94000, 93000,
  { [0] = 33000, [1] = 34000, [2] = 27000 },
  { [0] = 32000, [1] = 30000, [2] = 28000 })
local frozenUiTime = now
timer = TimerState.new({ freezeDuration = 3 })
assert(timer:update(0.016))
player.currentSector = 1
player.previousSectorTime = 31000
player.lapTimeMs = 31000
assert(timer:update(0.016))
assert(timer:snapshot().result ~= nil)
for _ = 1, 190 do assert(timer:update(0.016)) end
assert(now == frozenUiTime and timer:snapshot().result == nil,
  'a frozen UI clock must not leave the last sector result on screen indefinitely')

-- Timer: crossing the line replaces the sector result with the lap result.
resetWorld(92000, 90000,
  { [0] = 30000, [1] = 31000, [2] = 31000 },
  { [0] = 29000, [1] = 30000, [2] = 31000 })
player.currentSector = 2
player.splinePosition = 0.90
timer = TimerState.new({ freezeDuration = 3 })
assert(timer:update())
player.currentSector = 0
player.lapCount = 1
player.splinePosition = 0.02
player.previousLapTimeMs = 91000
player.lastSplits = { [2] = 32000 }
assert(timer:update())
timerSnapshot = timer:snapshot()
assert(timerSnapshot.result and timerSnapshot.result.kind == 'lap')
assert(timerSnapshot.result.status == 'personal_best')
assert(timerSnapshot.result.time == 91000)
assert(timerSnapshot.result.delta == 1000, 'lap delta must compare with the session lap record')

-- A new session lap record triggers the distinct lap record sound only once.
resetWorld(94000, 93000,
  { [0] = 30000, [1] = 31000, [2] = 30000 },
  { [0] = 31000, [1] = 32000, [2] = 28000 })
player.currentSector = 2
player.splinePosition = 0.90
timer = TimerState.new({ freezeDuration = 3 })
assert(timer:update())
player.lapCount = 1
player.previousLapTimeMs = 91000
player.lastSplits = { [2] = 30000 }
player.splinePosition = 0.02
player.lapTimeMs = 500
assert(timer:update())
timerSnapshot = timer:snapshot()
assert(timerSnapshot.result.status == 'session_best')
assert(timerSnapshot.lapRecordEventId == 1 and timerSnapshot.sectorRecordEventId == 0,
  'session lap record event counters differ: lap=' .. tostring(timerSnapshot.lapRecordEventId)
    .. ', sector=' .. tostring(timerSnapshot.sectorRecordEventId)
    .. ', status=' .. tostring(timerSnapshot.result and timerSnapshot.result.status))
assert(timer:update())
assert(timer:snapshot().lapRecordEventId == 1, 'same lap record must not replay its sound')

-- Fixed-lap races show FINAL LAP for the whole last lap without relying on a flag.
resetWorld(92000, 90000,
  { [0] = 30000, [1] = 31000, [2] = 31000 },
  { [0] = 29000, [1] = 30000, [2] = 31000 })
session.laps = 3
player.lapCount = 2
timer = TimerState.new({ freezeDuration = 3 })
assert(timer:update())
assert(timer:snapshot().finalLap == true, 'fixed-lap fallback must detect the final lap')

-- Laps: current row reflects pits and invalidation, history is newest-first,
-- and session-best takes precedence over personal-best.
resetWorld(92000, 90000, nil, nil)
local laps = LapsState.new()
assert(laps:update())
player.isInPitlane = true
player.lapTimeMs = 45000
assert(laps:update())
assert(laps:snapshot().current.inPits == true)

player.isInPitlane = false
player.lapCount = 1
player.splinePosition = 0.02
player.lapTimeMs = 500
player.previousLapTimeMs = 91000
assert(laps:update())
local lapsSnapshot = laps:snapshot()
assert(#lapsSnapshot.history == 1 and lapsSnapshot.history[1].number == 1)
assert(lapsSnapshot.history[1].inPits == true, 'pit marker must persist into history')
assert(lapsSnapshot.history[1].status == 'personal_best')
assert(lapsSnapshot.current.number == 2, 'crossing the line must create the next live row')

player.lapCount = 2
player.previousLapTimeMs = 89000
player.splinePosition = 0.03
assert(laps:update())
lapsSnapshot = laps:snapshot()
assert(#lapsSnapshot.history == 2)
assert(lapsSnapshot.history[1].number == 2 and lapsSnapshot.history[1].status == 'session_best')
assert(lapsSnapshot.history[2].number == 1, 'lap history must remain newest-first')

player.isLapValid = false
player.lapTimeMs = 12000
assert(laps:update())
assert(laps:snapshot().current.invalid == true, 'current lap invalidation must be immediate')
player.lapCount = 3
player.previousLapTimeMs = 88000
player.splinePosition = 0.04
assert(laps:update())
lapsSnapshot = laps:snapshot()
assert(lapsSnapshot.history[1].status == 'invalid')
assert(lapsSnapshot.sessionBest == 89000, 'invalid lap must not replace session best')

-- Session changes and lap-count rewinds reset app-local history/state.
player.isLapValid = true
player.isCurrentLapValid = true
player.lapCount = 0
player.previousLapTimeMs = 0
player.bestLapTimeMs = 95000
rival.bestLapTimeMs = 94000
sim.currentSessionIndex = 1
assert(laps:update())
lapsSnapshot = laps:snapshot()
assert(#lapsSnapshot.history == 0 and lapsSnapshot.current.number == 1)
assert(lapsSnapshot.personalBest == 95000 and lapsSnapshot.sessionBest == 94000)

resetWorld(92000, 90000, nil, nil)
sim.isLive = false
player.lapCount = 11
player.lapTimeMs = 50559
timer = TimerState.new({ freezeDuration = 3 })
laps = LapsState.new()
assert(timer:update() and laps:update())
assert(timer:snapshot().currentLapTime == laps:snapshot().current.time,
  'Timer must publish the same current time as Laps while the simulation is not live')
assert(timer:snapshot().lapNumber == 12)
sim.isReplayActive = true
player.currentSector = 1
player.previousSectorTime = 10000
player.lapTimeMs = 52000
assert(timer:update())
assert(timer:snapshot().currentLapTime == 52000 and timer:snapshot().sectorRecordEventId == 0
  and timer:snapshot().lapRecordEventId == 0)
player.lapCount = 12
player.previousLapTimeMs = 50000
player.lapTimeMs = 500
player.currentSector = 0
assert(timer:update())
assert(timer:snapshot().currentLapTime == 500 and timer:snapshot().sectorRecordEventId == 0
  and timer:snapshot().lapRecordEventId == 0,
  'replay lap transitions must update the time without announcing records')
assert(timer.personalBestLap == 92000 and timer.sessionBestLap == 90000)
sim.isReplayActive = false
sim.isLive = true
assert(timer:update())
assert(timer:snapshot().sectorRecordEventId == 0 and timer:snapshot().lapRecordEventId == 0,
  'leaving replay must not announce a stale lap result')

resetWorld(92000, 90000, nil, nil)
player.splinePosition = 0.25
player.lapTimeMs = 23000
player.estimatedLapTimeMs = 89000
laps = LapsState.new()
assert(laps:update())
assert(laps:snapshot().current.progress == 0.25 and laps:snapshot().current.status == 'session_best')
player.estimatedLapTimeMs = 91000
assert(laps:update())
assert(laps:snapshot().current.status == 'personal_best')
player.estimatedLapTimeMs = 95000
assert(laps:update())
assert(laps:snapshot().current.status == 'slower')
player.estimatedLapTimeMs = nil
assert(laps:update())
assert(laps:snapshot().current.status == 'current', 'missing pace telemetry must not invent a record')
player.isLapValid = false
player.estimatedLapTimeMs = 80000
assert(laps:update())
assert(laps:snapshot().current.status == 'invalid', 'invalidity must override projected record pace')
player.splinePosition = 0.98
assert(laps:update())
player.lapCount = 1
player.previousLapTimeMs = 93000
player.splinePosition = 0.01
player.isLapValid = true
assert(laps:update())
assert(laps:snapshot().current.progress == 0.01 and laps:snapshot().current.number == 2,
  'crossing the line must restart progress on the next current row')
assert(laps:snapshot().transitionStartedAt ~= nil, 'a live lap completion must start the row transition')
sim.currentSessionIndex = 1
assert(laps:update())
assert(laps:snapshot().transitionStartedAt == nil, 'session resets must not animate a lap completion')
sim.isReplayActive = true
player.lapCount = 2
assert(laps:update())
assert(laps:snapshot().transitionStartedAt == nil, 'replay seeks must not start live lap transitions')

for _, replay in ipairs({ false, true }) do
  for _, splineFirst in ipairs({ false, true }) do
    resetWorld(92000, 90000, nil, nil)
    sim.isReplayActive = replay
    sim.isLive = not replay
    player.lapCount = 1
    player.previousLapTimeMs = 96010
    player.splinePosition = 0.98
    player.lapTimeMs = 141656
    laps = LapsState.new()
    assert(laps:update())
    if splineFirst then
      player.splinePosition = 0.01
      player.lapTimeMs = 200
      assert(laps:update())
      assert(#laps:snapshot().history == 0,
        'a spline wrap before the counter must not commit the stale previous lap')
    end
    player.lapCount = 2
    player.previousLapTimeMs = 141656
    assert(laps:update())
    player.splinePosition = 0.02
    player.lapTimeMs = 500
    assert(laps:update())
    assert(laps:update())
    lapsSnapshot = laps:snapshot()
    assert(#lapsSnapshot.history == 1 and lapsSnapshot.history[1].number == 2
      and lapsSnapshot.history[1].time == 141656 and lapsSnapshot.current.number == 3,
      'staggered counter/spline updates and repeated frames must record a lap exactly once')
    assert(lapsSnapshot.transitionStartedAt ~= nil, 'continuous playback must animate a real lap completion')
    player.splinePosition = 0.98
    assert(laps:update())
    player.lapCount = 3
    player.splinePosition = 0.01
    assert(laps:update())
    lapsSnapshot = laps:snapshot()
    assert(#lapsSnapshot.history == 2 and lapsSnapshot.history[1].number == 3
      and lapsSnapshot.history[2].number == 2 and lapsSnapshot.history[1].time == 141656,
      'different laps with identical times must both be retained')
  end
end

resetWorld(92000, 90000, nil, nil)
sim.isReplayActive = true
sim.isLive = false
sim.replayCurrentFrame = 100
sim.replayFrameMs = 100
sim.replayPlaybackRate = 1
laps = LapsState.new()
assert(laps:update())
now = 0.1
sim.replayCurrentFrame = 101
player.lapCount = 1
player.previousLapTimeMs = 93000
assert(laps:update())
assert(#laps:snapshot().history == 1)
now = 1.1
sim.replayPlaybackRate = 4
sim.replayCurrentFrame = 131
assert(laps:update())
assert(#laps:snapshot().history == 1, 'continuous accelerated replay must not be mistaken for a seek')
sim.replayPlaybackRate = 0
now = 2.1
assert(laps:update())
assert(#laps:snapshot().history == 1, 'pausing a replay must retain its lap history')
sim.replayPlaybackRate = 1
sim.replayCurrentFrame = 90
assert(laps:update())
assert(#laps:snapshot().history == 0 and laps:snapshot().current.number == 2
  and laps:snapshot().transitionStartedAt == nil, 'rewinding within a replay lap must discard future history')
sim.replayCurrentFrame = 300
player.lapCount = 2
assert(laps:update())
assert(#laps:snapshot().history == 0 and laps:snapshot().current.number == 3,
  'a replay seek must not label stale telemetry as a completed lap')
sim.replayCurrentFrame = 301
player.lapCount = 5
assert(laps:update())
assert(#laps:snapshot().history == 0 and laps:snapshot().current.number == 6,
  'skipping lap counters must reset rather than invent missing laps')

local Vector = {}
Vector.__index = Vector
function vec2(horizontal, vertical)
  return setmetatable({ x = horizontal or 0, y = vertical or 0 }, Vector)
end
function Vector.__add(first, second) return vec2(first.x + second.x, first.y + second.y) end
function Vector.__sub(first, second) return vec2(first.x - second.x, first.y - second.y) end
function Vector.__mul(first, second)
  if type(first)=='number' then return vec2(first*second.x,first*second.y) end
  return vec2(first.x*second,first.y*second)
end
function Vector.__div(vector, divisor) return vec2(vector.x / divisor, vector.y / divisor) end
function rgbm(red, green, blue, alpha) return { r = red, g = green, b = blue, mult = alpha } end
ac.storage = function(defaults) return defaults end

local drawnText, drawnPanels, drawnMarkers, currentPath = {}, {}, {}, {}
local drawAlpha, alphaStack = 1, {}
local windowWidth, windowHeight = 220, 379
ui.windowWidth = function() return windowWidth end
ui.windowHeight = function() return windowHeight end
ui.pushStyleVarAlpha = function(alpha)
  alphaStack[#alphaStack + 1] = drawAlpha
  drawAlpha = drawAlpha * alpha
end
ui.popStyleVar = function(count)
  for index = 1, count or 1 do drawAlpha = table.remove(alphaStack) end
end
ui.pushDWriteFont = function() end
ui.popDWriteFont = function() end
ui.measureDWriteText = function(value, size) return vec2(#value * size * 0.6, size * 1.35) end
ui.dwriteDrawText = function(value, size, position, color)
  drawnText[#drawnText + 1] = { value = value, size = size, position = position, color = color, alpha = drawAlpha }
end
ui.pathClear = function() currentPath = {} end
ui.pathLineTo = function(point) currentPath[#currentPath + 1] = point end
ui.pathFillConvex = function(color)
  local minimum, maximum = vec2(math.huge, math.huge), vec2(-math.huge, -math.huge)
  for _, point in ipairs(currentPath) do
    minimum.x, minimum.y = math.min(minimum.x, point.x), math.min(minimum.y, point.y)
    maximum.x, maximum.y = math.max(maximum.x, point.x), math.max(maximum.y, point.y)
  end
  drawnPanels[#drawnPanels + 1] = { minimum = minimum, maximum = maximum, color = color }
end
ui.pathStroke = function() end
ui.drawRectFilled = function(minimum, maximum, color)
  drawnMarkers[#drawnMarkers + 1] = { minimum = minimum, maximum = maximum, color = color }
end

local shadeActive, shadeCount = false,0
ui.beginGradientShade = function() assert(not shadeActive); shadeActive=true end
ui.endGradientShade = function(first,last,top,bottom,multiply)
 assert(shadeActive and multiply==true)
 assert(first.x==last.x and last.y>first.y,'fade must be vertical')
 assert(top.r==1 and top.g==1 and top.b==1 and top.mult==1)
 assert(bottom.r==1 and bottom.g==1 and bottom.b==1 and bottom.mult==0.2,'preserve RGB, multiply alpha to 20 percent')
 shadeActive=false; shadeCount=shadeCount+1
end
local LapsDisplay = require('modules/laps/src/display')
local Theme = require('modules/timing/src/theme')
local renderSnapshot = {
  current = { number = 123, time = 21293, progress = 0.42, status = 'personal_best', inPits = true, invalid = false },
  history = {}
}
local statuses = { 'session_best', 'personal_best', 'slower', 'invalid' }
for index = 1, 9 do
  local status = statuses[(index - 1) % #statuses + 1]
  renderSnapshot.history[index] = {
    number = 123 - index, time = 120000 + index * 1234,
    inPits = true, status = status, invalid = status == 'invalid'
  }
end

local drawingCases = 0
for _, themeName in ipairs({ 'dark', 'light' }) do
  local colors = Theme.get(themeName)
  for _, rows in ipairs({ 5, 10 }) do
    for _, scale in ipairs({ 0.65, 1, 1.5 }) do
      for _, narrow in ipairs({ false, true }) do
        local settings = { rows = rows, scale = scale }
        local authored = LapsDisplay.size(settings)
        windowWidth = narrow and 143 or authored.x * scale
        windowHeight = authored.y * scale
        drawnText, drawnPanels, drawnMarkers = {}, {}, {}
        shadeCount=0
        LapsDisplay.draw(renderSnapshot, settings, { palette = colors, instrumentOpacity = 1 })
        assert(not shadeActive and shadeCount==(rows==5 and 1 or 0),'shade only the last visible history row when more exists')
        assert(#drawnPanels == rows * 2 and #drawnMarkers == rows - 1 + 16)
        local rowIndex = 0
        for _, text in ipairs(drawnText) do
          local measured = ui.measureDWriteText(text.value, text.size)
          assert(text.value ~= '21.293', 'the current row must show progress instead of elapsed time')
          assert(text.value ~= 'LAPS' and text.value ~= 'LIVE', 'lap list must not have a redundant heading')
          assert(text.position.x >= 0 and text.position.y >= 0
            and text.position.x + measured.x <= windowWidth + 0.001
            and text.position.y + measured.y <= windowHeight + 0.001,
            'all Laps labels must fit the app window: ' .. text.value)
          if text.value:match('^%d+$') then rowIndex = rowIndex + 1 end
          if rowIndex > 0 then
            local panel = drawnPanels[rowIndex * 2 - 1]
            local center = (panel.minimum.y + panel.maximum.y) / 2
            assert(math.abs(text.position.y + measured.y / 2 - center) < 0.001,
              'lap number, time and pit marker must share the row center')
          end
        end
        for panelIndex, panel in ipairs(drawnPanels) do
          if panelIndex == 1 then
            assert(panel.color == colors.panelRaised, 'the unfilled progress track must remain neutral')
          elseif panelIndex % 2 == 0 then
            assert(panel.color == colors.surface, 'lap number cells must retain their neutral background')
          else
            local base = panelIndex == 1 and colors.panelRaised or colors.panel
            assert(panel.color.mult == base.mult, 'band tint must preserve background opacity')
            assert(panel.color.r ~= base.r or panel.color.g ~= base.g or panel.color.b ~= base.b,
              'the time band must be tinted with its semantic color')
          end
        end
        for markerIndex, marker in ipairs(drawnMarkers) do
          if markerIndex <= 16 then
            local band = drawnPanels[1]
            assert(marker.minimum.x > band.minimum.x and marker.maximum.x < band.maximum.x,
              'progress segments must fit inside the current band')
            if markerIndex > 1 then
              assert(marker.minimum.x > drawnMarkers[markerIndex - 1].maximum.x,
                'progress segments must remain visually separated')
            end
          else
            assert(marker.maximum.x - marker.minimum.x <= windowWidth * 0.02,
              'historical markers must retain their narrow accent')
          end
        end
        local activeCount = 0
        for segmentIndex = 1, 16 do
          if drawnMarkers[segmentIndex].color == drawnMarkers[1].color then activeCount = activeCount + 1 end
        end
        assert(activeCount == 7, '42 percent progress must light seven of sixteen segments')
        assert(drawAlpha == 1 and #alphaStack == 0, 'Laps must balance nested row opacity')
        drawingCases = drawingCases + 1
      end
    end
  end
end

windowWidth, windowHeight = 220, 379
renderSnapshot.history = {}
local inactiveColor
for _, progress in ipairs({ 0, 0.5, 1 }) do
  renderSnapshot.current.progress = progress
  drawnText, drawnPanels, drawnMarkers = {}, {}, {}
  LapsDisplay.draw(renderSnapshot, { rows = 10, scale = 1 }, { palette = Theme.get('dark'), instrumentOpacity = 1 })
  assert(#drawnMarkers == 16, 'the segmented track must remain visible at every progress value')
  if progress == 0 then inactiveColor = drawnMarkers[1].color end
  local activeCount = 0
  for _, segment in ipairs(drawnMarkers) do
    if segment.color.r ~= inactiveColor.r or segment.color.g ~= inactiveColor.g or segment.color.b ~= inactiveColor.b then
      activeCount = activeCount + 1
    end
  end
  assert(activeCount == progress * 16, 'empty, half and full tracks must light zero, eight and sixteen segments')
end

local Edition = require('src/edition')
local playedSounds = {}
local playedVolumes = {}
local playbackPositions = {}
ac.AudioChannel = { Main = 1 }
ac.getAudioVolume = function() return 0.25 end
ui.MediaPlayer = setmetatable({ supported = function() return true end }, {
  __call = function(_, path)
    return {
      setVolume = function(_, volume) playedVolumes[#playedVolumes + 1] = volume end,
      setCurrentTime = function(_, position) playbackPositions[#playbackPositions + 1] = position end,
      play = function() playedSounds[#playedSounds + 1] = path end
    }
  end
})
local RecordAudio = require('modules/timer/src/audio')
assert(RecordAudio.playLapRecord() and RecordAudio.playSectorRecord())
assert(#playedSounds == 2 and playedSounds[1] == 'assets/notification-d4s3s.wav'
  and playedSounds[2] == 'assets/notification-qqv87.wav',
  'completed laps and sector records must use their distinct audio files')
assert(playedVolumes[1] == 1 and playedVolumes[2] == 1,
  'record playback must not apply an extra reduction on top of the game audio mix')
local workingMediaPlayer = ui.MediaPlayer
ui.MediaPlayer = setmetatable({}, { __call = function() error('temporary audio initialization failure') end })
local retryAudio = assert(loadfile('modules/timer/src/audio.lua'))()
local started, audioError = retryAudio.playLapRecord()
assert(started == false and audioError:find('temporary audio initialization failure', 1, true),
  'constructor failures must be returned so sound previews can report them')
ui.MediaPlayer = workingMediaPlayer
assert(retryAudio.playLapRecord(), 'a temporary initialization failure must not permanently disable the sound')
renderSnapshot.history = { { number = 122, time = 120000, status = 'slower' } }
local function drawTransition(atTime, enabled)
  now = atTime
  drawnText, drawnPanels, drawnMarkers = {}, {}, {}
  LapsDisplay.draw(renderSnapshot, { rows = 10, scale = 1 },
    { palette = Theme.get('dark'), instrumentOpacity = 1, animateLapChanges = enabled })
  assert(drawAlpha == 1 and #alphaStack == 0)
  local current, completed
  for _, text in ipairs(drawnText) do
    if text.value == '123' then current = text end
    if text.value == '122' then completed = text end
  end
  assert(current and completed, 'Missing transition lap numbers')
  return current, completed
end
renderSnapshot.transitionStartedAt = nil
local restingRow, restingHistory = drawTransition(10, true)
renderSnapshot.transitionStartedAt = 10
local enteringRow, enteringHistory = drawTransition(10, true)
local halfwayRow, halfwayHistory = drawTransition(10.24, true)
local arrivingRow = drawTransition(10.39, true)
local settledRow, settledHistory = drawTransition(10.50, true)
assert(settledRow.position.y == restingRow.position.y and settledRow.alpha == restingRow.alpha,
  'the completed transition must restore exact resting geometry and opacity')
assert(settledHistory.position.y == restingHistory.position.y)
if Edition.premium then
  assert(enteringHistory.position.y == restingRow.position.y,
    'the completed lap must start at its previous current-row position instead of jumping')
  assert(enteringHistory.position.y < halfwayHistory.position.y
    and halfwayHistory.position.y < settledHistory.position.y)
  assert(enteringRow.alpha == 0 and halfwayRow.alpha == 0
    and arrivingRow.alpha > 0 and arrivingRow.alpha < settledRow.alpha,
    'the new progress row must fade in only after the completed row clears it')
else
  assert(enteringRow.position.y == restingRow.position.y and enteringRow.alpha == restingRow.alpha,
    'Free must update the lap rows immediately without Premium motion')
  assert(enteringHistory.position.y == restingHistory.position.y)
end
local disabledRow = drawTransition(10, false)
assert(disabledRow.position.y == restingRow.position.y and disabledRow.alpha == restingRow.alpha,
  'disabling lap motion must display final geometry immediately')
if Edition.premium then
  for _, frameRate in ipairs({ 30, 60, 144 }) do
    local previousY = enteringHistory.position.y
    for frame = 1, math.ceil(0.48 * frameRate) do
      local _, historicalRow = drawTransition(10 + frame / frameRate, true)
      assert(historicalRow.position.y >= previousY and historicalRow.position.y <= restingHistory.position.y,
        'row motion must remain monotonic and settle without overshoot at different frame rates')
      previousY = historicalRow.position.y
    end
    assert(previousY == restingHistory.position.y)
  end
end

-- Limits and transitions must keep exactly one fade on the last historical row.
for _,limit in ipairs({1,2,5,10}) do
 for _,count in ipairs({0,1,5,12}) do
  renderSnapshot.history={}
  for index=1,count do renderSnapshot.history[index]={number=123-index,time=90000,status='slower'} end
  for _,transition in ipairs({false,true}) do
   renderSnapshot.transitionStartedAt=transition and 10 or nil
   now=10.2; shadeCount=0
   LapsDisplay.draw(renderSnapshot,{rows=limit,scale=1},
    {palette=Theme.get('dark'),instrumentOpacity=0.4,animateLapChanges=true})
   assert(not shadeActive and shadeCount==((count>limit-1 and limit>1) and 1 or 0))
   assert(drawAlpha==1 and #alphaStack==0)
  end
 end
end
if TEST_LAPS_ONLY then
 print('Laps: '..drawingCases..' drawings, full/hidden history, row limits, alpha multiplication and transitions passed')
 return
end

local TimerDisplay = require('modules/timer/src/display')
local timerDrawingCases = 0
for _, themeName in ipairs({'dark','light'}) do
for _, scale in ipairs({ 0.65, 1, 1.5 }) do
  windowWidth, windowHeight = 320 * scale, 94 * scale
  for _, finalLap in ipairs({ false, true }) do
    for _, resultActive in ipairs({ false, true }) do
      for _, inPits in ipairs({ false, true }) do
        drawnText, drawnPanels, drawnMarkers = {}, {}, {}
        local snapshot = { currentLapTime = 139000, finalLap = finalLap, inPits = inPits }
        if resultActive then snapshot.result = { time = 139000, status = 'personal_best', delta = -1234 } end
        TimerDisplay.draw(snapshot, { scale = scale, backgroundOpacity = 0.7 },
          { palette = Theme.get(themeName), instrumentOpacity = 1 })
        local panel = drawnPanels[finalLap and 2 or 1]
        local foundTime = false
        for _, text in ipairs(drawnText) do
          if text.value == '2:19.000' then
            foundTime = true
            local measured = ui.measureDWriteText(text.value, text.size)
            assert(text.size > (resultActive and 28 or 33) * scale, 'Timer digits must grow to use available space')
            assert(text.position.x >= panel.minimum.x and text.position.x + measured.x <= panel.maximum.x
              and text.position.y >= panel.minimum.y and text.position.y + measured.y <= panel.maximum.y,
              'large Timer digits must fit the plate, including pits and FINAL LAP')
          end
        end
        assert(foundTime)
        timerDrawingCases = timerDrawingCases + 1
      end
    end
  end
end

end

for _, themeName in ipairs({'dark','light'}) do
for _, scale in ipairs({ 0.65, 1, 1.5 }) do
  windowWidth, windowHeight = 320 * scale, 94 * scale
  for _, finalLap in ipairs({ false, true }) do
    for _, outcome in ipairs({
      { status = 'session_best', delta = -1000, valid = true },
      { status = 'personal_best', delta = 2000, valid = true },
      { status = 'slower', delta = 99990, valid = true },
      { status = 'invalid', delta = -1000, valid = false },
      { status = 'slower', valid = true }
    }) do
      for _, opacity in ipairs({ 0, 0.7 }) do
        drawnText, drawnPanels, drawnMarkers = {}, {}, {}
        local colors = Theme.get(themeName)
        local result = { kind = 'sector', time = 31000, status = outcome.status,
          delta = outcome.delta, valid = outcome.valid }
        TimerDisplay.draw({ result = result, finalLap = finalLap },
          { scale = scale, backgroundOpacity = opacity }, { palette = colors, instrumentOpacity = 1 })
        local mainPanelIndex = finalLap and 2 or 1
        local mainPanel = drawnPanels[mainPanelIndex]
        for panelIndex = mainPanelIndex + 1, #drawnPanels do
          assert(drawnPanels[panelIndex].minimum.y == mainPanel.minimum.y
            and drawnPanels[panelIndex].maximum.y == mainPanel.maximum.y,
            'sector result sections must have the same height and vertical alignment as the central timer')
        end
        local bestCount, deltaCount = 0, 0
        local deltaText = require('modules/timing/src/ui').formatDelta(outcome.delta)
        for _, text in ipairs(drawnText) do
          local measured = ui.measureDWriteText(text.value, text.size)
          local contained = false
          for _, panel in ipairs(drawnPanels) do
            if text.position.x >= panel.minimum.x - 0.001
                and text.position.x + measured.x <= panel.maximum.x + 0.001
                and text.position.y >= panel.minimum.y - 0.001
                and text.position.y + measured.y <= panel.maximum.y + 0.001 then
              contained = true
            end
          end
          assert(contained, 'sector result labels must fit their panels at every supported scale')
          assert(text.value ~= 'PB' and text.value ~= 'VALID' and text.value ~= 'INVALID',
            'the left context must be reserved for a valid session record')
          if text.value == 'BEST' then
            bestCount = bestCount + 1
            assert(text.size >= 19 * scale and text.color == colors.purple)
          elseif text.value == deltaText and not ((text.color.r==0x13/255 and text.color.g==0x10/255 and text.color.b==0x0D/255)
              or (text.color.r==0xF2/255 and text.color.g==0xDB/255 and text.color.b==0xAE/255)) then
            deltaCount = deltaCount + 1
            local expectedColor = not outcome.valid and colors.secondary or outcome.delta == nil and colors.secondary
              or outcome.delta < 0 and colors.purple or colors.amber
            assert(text.size >= 18 * scale and text.color == expectedColor,
              'large relative text must reflect the gap to the session record, including invalid laps')
          end
        end
        assert(bestCount == (outcome.valid and outcome.status == 'session_best' and 1 or 0))
        assert(deltaCount == 1)
        if opacity == 0 then
          for _, panel in ipairs(drawnPanels) do
            assert(panel.color.mult == 0, 'text-only mode must also hide result panel backgrounds')
          end
        end
      end
    end
  end
end

end

local visibleCheckboxes = {}
ui.header = function() end
ui.separator = function() end
ui.availableSpaceX = function() return windowWidth end
ui.button = function(label) return label == '>  Personalization##laps.personalization' end
ui.slider = function(_, value) return value, false end
ui.checkbox = function(label)
  visibleCheckboxes[label] = true
  return label == 'Animate lap changes'
end
local LapsSettings = require('modules/laps/src/settings')
LapsSettings.draw()
assert((visibleCheckboxes['Animate lap changes'] == true) == Edition.premium,
  'the lap transition switch must be offered only in Premium')
if Edition.premium then
  assert(LapsSettings.values.animateLapChanges == false, 'the Premium switch must persist disabled motion')
end

local TimerSettings = require('modules/timer/src/settings')
TimerSettings.values.audioEnabled = false
ui.checkbox = function() return false end
ui.textWrapped = function() end
for _, preview in ipairs({
  { label = 'Test sector sound##timer.test-sector-sound', path = 'assets/notification-qqv87.wav' },
  { label = 'Test lap sound##timer.test-lap-sound', path = 'assets/notification-d4s3s.wav' },
  { label = 'Test lap sound##timer.test-lap-sound', path = 'assets/notification-d4s3s.wav' }
}) do
  ui.button = function(label) return label == preview.label end
  local playedBefore = #playedSounds
  local rewoundBefore = #playbackPositions
  TimerSettings.draw()
  assert(#playedSounds == playedBefore + 1 and playedSounds[#playedSounds] == preview.path,
    'each preview button must play exactly its own sound, even with automatic alerts disabled')
  assert(#playbackPositions == rewoundBefore + 1 and playbackPositions[#playbackPositions] == 0,
    'a preview must restart the sound so repeated clicks remain audible')
  assert(TimerSettings.values.audioEnabled == false, 'previewing must not enable automatic record alerts')
end
local playLapCompleted = RecordAudio.playLapCompleted
RecordAudio.playLapCompleted = function() return false, 'audio failed' end
local previewNotice
ui.textWrapped = function(message) previewNotice = message end
TimerSettings.draw()
assert(previewNotice and previewNotice:find('Could not play the record sound', 1, true),
  'failed previews must give visible feedback instead of silently doing nothing')
RecordAudio.playLapCompleted = playLapCompleted
previewNotice = nil
TimerSettings.draw()
assert(previewNotice == nil, 'a successful preview must clear the previous failure notice')

print('Timing apps: transitions, records, audio, validity, pits, freeze, final lap, resets and '
  .. drawingCases .. ' segmented Laps and ' .. timerDrawingCases .. ' Timer drawings; '
  .. (Edition.premium and 'Premium motion' or 'Free immediate updates') .. ' passed')
