package.path = './?.lua;./?/init.lua;' .. package.path

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
assert(timerSnapshot.audioEventId == 1, 'session-best sector must create one audio event')
assert(timer:update())
assert(timer:snapshot().audioEventId == 1, 'same sector result must not replay audio')

player.currentSector = 2
player.previousSectorTime = 32000
player.lapTimeMs = 63000
assert(timer:update())
timerSnapshot = timer:snapshot()
assert(timerSnapshot.result.status == 'personal_best')
assert(timerSnapshot.audioEventId == 1, 'personal best below the session record must stay silent')

player.isLapValid = false
assert(timer:update())
assert(timer:snapshot().invalid == true, 'live invalidation must be immediate')
now = 3.01
assert(timer:snapshot().result == nil, 'frozen result must expire after configured duration')

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

print('Timing apps: sector/lap transitions, records, audio events, invalidation, pits, freeze, final lap and resets passed')
