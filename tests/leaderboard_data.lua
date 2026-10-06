package.path = './?.lua;' .. package.path
local now = 0
ui = {time = function() return now end}
local sim = {currentSessionIndex = 0, time = 0, isSessionStarted = false, sessionTimeLeft = 600000}
local session = {type = 1, laps = 10}
local cars = {}
ac = {SessionType = {Race = 1, Practice = 2, Qualify = 3, Hotlap = 4, TimeAttack = 5},
  FlagType = {Finished = 13}, getSim = function() return sim end,
  getSession = function() return session end, getCar = function(index)
    for _, car in ipairs(cars) do if car.index == index then return car end end
  end, iterateCars = {leaderboard = function() return ipairs(cars) end}}
package.loaded['modules/leaderboard/src/classes'] = {detect = function(id)
  return id:find('gt3') and 'GT3' or 'UNKNOWN', 'TEST'
end}
local Data = require('modules/leaderboard/src/leaderboard_data')
local settings = {maxRows = 5, positionChangeDuration = 40, sectorReference = 'General'}
local function car(index, position)
  return {index = index, racePosition = position, lapCount = 0, splinePosition = 0,
    isActive = true, isConnected = true, driverName = function() return 'Driver ' .. index end,
    id = function() return 'gt3_' .. index end, name = function() return 'GT3' end}
end
local function tick(state, seconds)
  now = now + (seconds or 0.1); sim.time = now * 1000
  return Data.update(state, settings)
end
local function row(snapshot, index)
  for _, value in ipairs(snapshot.rows) do if value.index == index then return value end end
end
-- Selection must use session order, reserve leader and player, and fill near
-- the player symmetrically, including both ends of the grid.
local ordered = {}
for i = 1, 20 do ordered[i] = {index = i, racePosition = 21 - i} end
for limit = 3, 10 do
  for player = 1, 20 do
    local selected = Data.selectRows(ordered, ordered[player], limit)
    assert(#selected == limit and selected[1] == ordered[1])
    local found, seen, last = false, {}, 0
    for _, value in ipairs(selected) do
      assert(value.index > last and not seen[value.index]); last = value.index; seen[last] = true
      found = found or value == ordered[player]
    end
    assert(found)
    if player > limit and player < 20 - limit then
      local above, below = 0, 0
      for _, value in ipairs(selected) do
        if value.index ~= 1 then
          if value.index < player then above = above + 1 end
          if value.index > player then below = below + 1 end
        end
      end
      assert(math.abs(above - below) <= 1)
    end
  end
end
assert(#Data.selectRows(ordered, ordered[10]) == 5)
assert(#Data.selectRows(ordered, nil, 100) == 10)
assert(#Data.selectRows(ordered, nil, 1) == 3)
-- Observe the grid, then report transient changes independently of the
-- cumulative balance, which updates only on crossings.
cars = {car(0, 5), car(1, 1), car(2, 2), car(3, 3), car(4, 4)}
local state = Data.new()
local snapshot = tick(state)
assert(snapshot.historyReset and snapshot.localRow.balanceLabel == 'START')
sim.isSessionStarted = true
snapshot = tick(state)
assert(not snapshot.historyReset)
cars[1].racePosition, cars[4].racePosition = 3, 5
snapshot = tick(state)
assert(snapshot.localRow.positionChangeDelta == 2 and snapshot.localRow.lapPositionDelta == 0)
local untilTime = snapshot.localRow.positionChangeUntil
assert(math.abs(untilTime - now - 40) < 0.001)
cars[1].lapCount = 1
snapshot = tick(state)
assert(snapshot.localRow.lapPositionDelta == 2 and snapshot.localRow.balanceLabel == 'START')
cars[1].racePosition, cars[3].racePosition = 2, 3
snapshot = tick(state)
assert(snapshot.localRow.lapPositionDelta == 2 and snapshot.localRow.positionChangeDelta == 1)
cars[1].lapCount = 2
snapshot = tick(state)
assert(snapshot.localRow.lapPositionDelta == 3, 'balance must accumulate from the grid, not reset every lap')
snapshot = tick(state, 40)
assert(snapshot.localRow.positionChangeDelta == nil)
settings.positionChangeDuration = 7
cars[1].racePosition = 3
snapshot = tick(state)
assert(snapshot.localRow.positionChangeDelta == -1 and snapshot.localRow.positionChangeUntil == now + 7)
-- Late connection and reconnect establish an explicitly labelled new base.
local late = Data.new()
snapshot = tick(late)
assert(snapshot.localRow.balanceLabel == 'CONNECTION' and snapshot.localRow.lapPositionDelta == 0)
cars[1].racePosition, cars[1].lapCount = 2, 3
snapshot = tick(late)
assert(snapshot.localRow.lapPositionDelta == 1)
cars[3].isConnected = false; tick(late)
cars[3].isConnected = true
snapshot = tick(late)
assert(row(snapshot, 2).reconnected and row(snapshot, 2).balanceLabel == 'CONNECTION')
-- Winner's checkered flag and the player's FIN cannot stop other pilots.
cars[1].isRaceFinished, sim.raceFlagType = true, 13
snapshot = tick(state)
assert(snapshot.localRow.status == 'FIN' and not snapshot.final)
local frozenBalance = snapshot.localRow.lapPositionDelta
cars[1].racePosition, cars[1].lapCount = 5, 4
cars[3].racePosition, cars[3].lapCount = 2, 4
snapshot = tick(state)
assert(snapshot.localRow.lapPositionDelta == frozenBalance and snapshot.localRow.status == 'FIN')
assert(row(snapshot, 2).lapCount == 4 and not snapshot.final)
sim.isSessionFinished = true
snapshot = tick(state)
local finalRows = snapshot.rows
assert(snapshot.final)
cars[3].racePosition = 4
snapshot = tick(state)
assert(snapshot.rows == finalRows and row(snapshot, 2).position == 2)
-- Same-session restart and replay seeks invalidate final/history state.
cars[1].lapCount, cars[1].isRaceFinished = 0, false
sim.isSessionFinished, sim.isSessionStarted, sim.raceFlagType = false, false, nil
snapshot = tick(state)
assert(snapshot.historyReset and not snapshot.final and snapshot.localRow.lapPositionDelta == 0)
sim.isReplayActive, sim.replayFrameMs, sim.replayCurrentFrame, sim.dt = true, 20, 100, 0.02
snapshot = tick(state)
assert(snapshot.historyReset and snapshot.timeline.replay)
sim.replayCurrentFrame = 101
snapshot = tick(state)
assert(not snapshot.historyReset)
sim.replayCurrentFrame = 500
snapshot = tick(state)
assert(snapshot.historyReset)
sim.replayCurrentFrame = 10
snapshot = tick(state)
assert(snapshot.historyReset)
-- SDK splits start at zero. Physics-unavailable validity is UNKNOWN even
-- when its placeholder isLapValid flag is false and cuts appear nonzero.
local function splits(a, b, c) return setmetatable({[0] = a, b, c}, {__len = function() return 3 end}) end
sim.isReplayActive, session.type = false, 2
cars[1].physicsAvailable, cars[1].isLapValid, cars[1].lapCutsCount = false, false, 9
cars[1].currentSector, cars[1].currentSplits = 1, splits(29000, 0, 0)
cars[1].bestLapTimeMs, cars[1].bestLapSplits = 90000, splits(30000, 30000, 30000)
snapshot = tick(state)
assert(snapshot.localRow.currentLapValid == nil and snapshot.localRow.sectors[1].role == 'NEUTRAL')
assert(snapshot.localRow.bestLapSplits[1] == 30000 and snapshot.localRow.bestLapSplits[3] == 30000)
cars[1].physicsAvailable, cars[1].isLapValid, cars[1].lapCutsCount = true, true, 0
snapshot = tick(state)
assert(snapshot.localRow.currentLapValid == true and snapshot.localRow.sectors[1].role == 'PURPLE')
cars[1].lapCutsCount = 1
snapshot = tick(state)
assert(snapshot.localRow.currentLapValid == false)
session.type = 3
snapshot = tick(state)
assert(snapshot.header.typeLabel == 'QUAL' and snapshot.localRow.sectors)
sim.lapSplits = setmetatable({[0] = 0}, {__len = function() return 1 end})
cars[1].currentSector = 0
snapshot = tick(state)
assert(snapshot.localRow.sectorCount == 1 and #snapshot.localRow.sectors == 1,
  'actual track count must override placeholder arrays with three entries')
sim.lapSplits = nil
cars[1].currentSplits, cars[1].lastSplits, cars[1].bestLapSplits = nil, nil, nil
snapshot = tick(state)
assert(snapshot.localRow.sectorCount == 0 and #snapshot.localRow.sectors == 0)
for _, mode in ipairs({4, 5}) do
  session.type = mode
  snapshot = tick(state)
  assert(snapshot.personal and #snapshot.rows == 1 and #snapshot.shownRows == 1 and snapshot.localRow.index == 0)
end
ac.iterateCars.leaderboard = function()
  local remoteOnly = {cars[2], cars[3]}
  return ipairs(remoteOnly)
end
snapshot = tick(state)
assert(snapshot.personal and #snapshot.shownRows == 1 and snapshot.localRow.index == 0,
  'personal mode must still show player before a leaderboard entry exists')
ac.iterateCars.leaderboard = function() return ipairs(cars) end
-- Missing session objects remain a useful snapshot instead of losing cars.
session = nil
snapshot = tick(state)
assert(snapshot.header.typeLabel == 'WAIT' and #snapshot.rows == 5)

-- Exercise the actual module pipeline, including measured intervals and
-- fuel-reset propagation, while substituting only app services/render output.
session = {type = 2}
sim.isSessionStarted, sim.isSessionFinished, sim.isReplayActive = true, false, false
cars[1].fuel, cars[1].maxFuel, cars[1].lapCount = 30, 100, 0
cars[1].lapCutsCount, cars[1].isLapValid = 0, true
cars[1].currentSector, cars[1].currentSplits = 0, splits(0, 0, 0)
local errors, rendered = {}, nil
ac.error = function(value) errors[#errors + 1] = value end
package.loaded['modules/leaderboard/src/settings'] = {values = settings, normalize = function() end}
package.loaded['modules/leaderboard/src/theme_sync'] = {init = function() end, visual = function() return {} end}
package.loaded['modules/leaderboard/ui/leaderboard'] = {draw = function(value) rendered = value end}
package.loaded['src/general_settings'] = {values = {temperatureUnit = 'C'}}
package.loaded['src/window_anchor'] = {isAnchored = function() return false end}
local Main = require('modules/leaderboard/main')
Main.update(0.1); Main.windowMain()
assert(rendered and not rendered.error and rendered.localRow.sectorCount == 3 and rendered.fuel.available)
assert(rendered.localRow.interval == '-' and rendered.fuel.fuelText == '30.0 L')
cars[1].fuel = 27
Main.update(0.1)
cars[1].lapCount, cars[1].isLastLapValid, cars[1].previousLapTimeMs = 1, true, 90000
cars[1].lastSplits = splits(30000, 30000, 30000)
Main.update(0.1); Main.windowMain()
assert(rendered.fuel.average == 3 and rendered.localRow.sectors[1].role == 'PURPLE')
sim.isReplayActive, sim.replayFrameMs, sim.replayCurrentFrame = true, 20, 500
Main.update(0.1); Main.windowMain()
assert(rendered.historyReset and rendered.fuel.average == nil)
sim.replayCurrentFrame = 501
Main.update(0.1); Main.windowMain()
assert(not rendered.historyReset and not rendered.error and #errors == 0)
print('Leaderboard data: selection, notification, cumulative balance, connections, FIN/final, resets, SDK validity and personal modes passed')
print('Leaderboard integration: actual data/sectors/intervals/fuel pipeline and replay fuel reset passed')
