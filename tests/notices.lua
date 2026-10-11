package.path = './?.lua;./?/init.lua;' .. package.path
local defaults = {}
ac = {
  FlagType = { FasterCar = 12 },
  storage = function(values)
    for key, value in pairs(values) do defaults[key] = value end
    return defaults
  end,
  INIConfig = { carData = function(_, file)
    assert(file == 'car.ini')
    return { get = function(_, section, key)
      assert(section == 'PIT_STOP')
      return ({ BODY_REPAIR_TIME_SEC = 20, SUSP_REPAIR_TIME_SEC = 30,
        ENGINE_REPAIR_TIME_SEC = 2 })[key]
    end }
  end }
}
local State = require('modules/notices/src/state')
local Repair = require('modules/notices/src/repair')
local Settings = require('modules/notices/src/settings')
local settings = Settings.values
local rates = Repair.rates(0)
local car = { lapCount = 10, resetCounter = 0 }
local sim = { currentSessionIndex = 1, currentSessionTime = 10000, isSessionStarted = true }
local condition = { available = true, body = {}, wheels = {}, engineDamage = 0, gearboxDamage = 0 }
for i = 1, 4 do condition.wheels[i] = { suspensionDamage = 0 } end
local traffic = { player = { progress = 10.5 }, cars = {
  { index = 2, classID = 'LMP2', gap = 1.8, measured = true, behind = true, progress = 11.4 },
  { index = 3, classID = 'HY', gap = 1.0, measured = false, behind = true, progress = 11.45 }
} }
local state = State.new()
local function tick(dt)
  state:update(dt or 0.1, car, sim, condition, traffic, settings, rates)
  return state.notice
end

assert(tick() == nil, 'No flags or damage must leave the window empty, even without a Blue enum')
sim.raceFlagType, sim.raceFlagCause = 12, 2
local notice = tick()
assert(notice.kind == 'blue' and notice.detail == 'LMP2 APPROACHING' and notice.value == '1.8 s',
  'Official cause must win over a closer car')
traffic.cars[1].measured = false
assert(tick().value == '~1.8 s', 'Estimated traffic gaps must be identified')
traffic.cars[1].classID = 'UNKNOWN'
assert(tick().detail == 'FASTER CAR APPROACHING', 'Unknown classes must not be fabricated')
sim.raceFlagCause = -1
assert(tick().detail == 'HY APPROACHING', 'Cause fallback must choose an observed lapping car behind')
traffic.cars[1].progress, traffic.cars[2].progress = 10.4, 10.45
assert(tick().value == '--', 'Faster class alone must not attribute an official flag')
sim.raceFlagType = nil
assert(tick(0.5) == nil, 'Flag clear must release the short hold')

condition.wheels[1].suspensionDamage = 0.1
notice = tick()
assert(notice.kind == 'repair' and notice.detail == 'FRONT SUSPENSION DAMAGE')
assert(state.pitLap == 12, '10 completed laps means current lap 11 and a request for lap 12')
assert(tick(30).kind == 'repair', 'Repair lasts the damaged lap, not a timer')
car.lapCount = 11
assert(tick() == nil and state.pitLap == nil,
  'Continuing past the finish line dismisses repair and its automatic stop')
assert(tick(10) == nil, 'Unchanged accepted damage must not repeat')
condition.available = false
tick()
condition.available = true
assert(tick() == nil, 'A temporary telemetry loss must not rearm accepted damage')
condition.wheels[1].suspensionDamage = 0.2
assert(tick().kind == 'repair' and state.pitLap == 13, 'New damage can request a fresh stop')
car.lapCount = 12
assert(tick() == nil and state.pitLap == nil, 'A new repair is also dismissed after its lap')
condition.wheels[1].suspensionDamage = 0
assert(tick() == nil)
assert(state:requestPit(car, false, 17))
assert(tick() == nil, 'A scheduled reminder waits for a finish-line crossing')
assert(not state:requestPit(car, false, 12) and state.pitLap == 17, 'Past targets must not replace a plan')
car.lapCount = 13
notice = tick()
assert(notice.title == 'BOX IN 3 LAPS' and notice.value == '~0 s')
assert(tick(4.8).kind == 'pit', 'The crossing reminder remains during its five-second window')
sim.isPaused = true
assert(tick(10).kind == 'pit', 'Pause does not consume a pit reminder')
sim.isPaused = false
assert(tick(0.3) == nil, 'Early pit reminders disappear after five seconds')
car.lapCount = 14
assert(tick().title == 'BOX IN 2 LAPS')
assert(tick(5.1) == nil)
car.lapCount = 15
assert(tick().title == 'BOX NEXT LAP')
assert(tick(30).title == 'BOX NEXT LAP', 'The last lap before the stop keeps its reminder visible')
car.lapCount = 16
assert(tick().title == 'BOX THIS LAP', 'The planned pit lap begins at the crossing')
assert(tick(30).title == 'BOX THIS LAP', 'The final reminder stays visible')
sim.raceFlagType, sim.raceFlagCause = 12, 2
assert(tick().kind == 'blue', 'Blue flags take precedence over routine pit reminders')
condition.wheels[1].suspensionDamage = 0.25
assert(tick().kind == 'repair', 'New significant damage takes precedence over blue flags')
sim.raceFlagType = nil
car.lapCount = 17
assert(tick(0.5).title == 'BOX THIS LAP' and state.pitLap == 17,
  'Accepting damage must preserve a manually scheduled stop')
state:cancelPit()
assert(tick() == nil, 'Cancel must not immediately recreate an automatic pit request')
condition.wheels[1].suspensionDamage = 0.3
assert(tick().kind == 'repair' and state.pitLap == 19, 'New damage can request another stop')
car.isInPitlane = true
assert(tick() == nil and state.pitLap == nil, 'Pit entry clears all notices and requests')
condition.wheels[1].suspensionDamage = 0
car.isInPitlane = false
assert(tick() == nil, 'Repaired cars must not retain an old warning')
assert(state:requestPit(car))
assert(tick() == nil, 'An immediate request also waits for the next crossing')
car.lapCount = car.lapCount + 1
assert(tick().value == '~0 s', 'An undamaged manual stop has zero repair time')
condition.available = false
assert(tick().value == '--', 'Unavailable damage telemetry is not a zero-second repair')
condition.available = true
sim.isReplayActive = true
assert(tick() == nil and state.pitLap == nil, 'Live notices must not survive entering replay')
sim.isReplayActive = false
tick()
state:requestPit(car)
sim.currentSessionIndex = 2
assert(tick() == nil and state.pitLap == nil, 'Session changes clear manual plans')
state:requestPit(car)
sim.currentSessionTime = 0
assert(tick() == nil and state.pitLap == nil, 'Restarts with increasing sim time still clear plans')
state:requestPit(car)
car.resetCounter = 1
assert(tick() == nil and state.pitLap == nil, 'Teleport/reset clears plans')
state:requestPit(car)
car.isRaceFinished = true
assert(tick() == nil, 'Finished races must not show reminders')
car.isRaceFinished = false
settings.repairEnabled = false
condition.wheels[1].suspensionDamage = 0.5
assert(tick() == nil, 'Disabled repairs do not schedule automatic stops')
settings.repairEnabled = true
assert(tick().kind == 'repair', 'Enabling notices while damaged must show the warning')
local before = state.clock
sim.isPaused = true
tick(10)
assert(state.clock == before, 'Pause must not consume a repair warning')

local amounts = Repair.damage({ available = true, body = { front = 0.2, rear = 0.1 },
  wheels = {{ suspensionDamage = 0.1 }}, engineDamage = 0.3, gearboxDamage = 0 })
assert(math.abs(Repair.estimate(amounts, rates) - 76) < 0.00001, 'Rates are seconds per 10% damage')
assert(Repair.estimate(amounts, {}) == nil, 'Unknown car rates must not invent an estimate')
amounts.blown = true
assert(Repair.estimate(amounts, rates) == nil, 'Tyre replacement is outside repair-time estimate')
assert(Repair.format(76) == '~1:16' and Repair.format(nil) == '--')
defaults.scale, defaults.engineDamageThreshold = math.huge, -3
Settings.normalize()
assert(defaults.scale == 1 and defaults.engineDamageThreshold == 0.01)
print('Race Notices: flag attribution, priority, lap-based repair dismissal, scheduled crossing reminders, cancel, resets, replay, pause and estimates passed')
