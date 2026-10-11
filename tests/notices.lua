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
local fuel
local state = State.new()
local function tick(dt)
  state:update(dt or 0.1, car, sim, condition, traffic, settings, rates, fuel)
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
assert(tick(30).kind == 'repair', 'Repair lasts the damaged lap, not a timer')
car.lapCount = 11
assert(tick() == nil, 'Continuing past the finish line dismisses repair')
assert(tick(10) == nil, 'Unchanged accepted damage must not repeat')
condition.available = false
tick()
condition.available = true
assert(tick() == nil, 'A temporary telemetry loss must not rearm accepted damage')
condition.wheels[1].suspensionDamage = 0.2
assert(tick().kind == 'repair', 'New damage can trigger a fresh warning')
car.lapCount = 12
assert(tick() == nil, 'A new repair is also dismissed after its lap')
condition.wheels[1].suspensionDamage = 0
assert(tick() == nil)
fuel = {available=true, estimatedLaps=4, fuel=9}
car.lapCount = 13
assert(tick() == nil, 'More than three complete fuel laps do not warn')
fuel.estimatedLaps, fuel.fuel = 3, 7
assert(tick() == nil, 'The fuel reminder waits for a finish-line crossing')
car.lapCount = 14
notice = tick()
assert(notice.title == 'BOX IN 3 LAPS' and notice.value == '~0 s')
assert(notice.detail == '~3 FULL LAPS OF FUEL', 'The detail uses fuel autonomy, not a planned pit lap')
assert(tick(4.8).kind == 'pit', 'The crossing reminder remains during its five-second window')
sim.isPaused = true
assert(tick(10).kind == 'pit', 'Pause does not consume a pit reminder')
sim.isPaused = false
assert(tick(0.3) == nil, 'Early pit reminders disappear after five seconds')
fuel.estimatedLaps, fuel.fuel = 2, 5
assert(tick() == nil, 'Mid-lap autonomy changes must not restart the timer')
car.lapCount = 15
assert(tick().title == 'BOX IN 2 LAPS')
assert(tick(5.1) == nil)
fuel.estimatedLaps, fuel.fuel = 1, 3
car.lapCount = 16
assert(tick().title == 'BOX THIS LAP', 'The last complete lap of fuel asks to pit this lap')
assert(tick(30).title == 'BOX THIS LAP', 'The final reminder stays visible')
fuel.estimatedLaps, fuel.fuel = 0, 1
assert(tick().kind == 'pit', 'The final reminder persists when fuel drops below a complete lap')
sim.raceFlagType, sim.raceFlagCause = 12, 2
assert(tick().kind == 'blue', 'Blue flags take precedence over routine pit reminders')
condition.wheels[1].suspensionDamage = 0.25
assert(tick().kind == 'repair', 'New significant damage takes precedence over blue flags')
sim.raceFlagType = nil
car.lapCount = 17
assert(tick(0.5).title == 'BOX THIS LAP', 'Accepted damage must not silence low-fuel reminders')
condition.available = false
assert(tick().value == '--', 'Unavailable damage telemetry is not a zero-second repair')
condition.available = true
fuel.estimatedLaps, fuel.fuel = 5, 12
assert(tick() == nil, 'Refuelling clears the permanent reminder immediately')
fuel.estimatedLaps, fuel.fuel = 3, 7
car.lapCount = 18
assert(tick().kind == 'pit', 'A new stint can produce a fresh crossing reminder')
fuel.available = false
assert(tick() == nil, 'Unavailable fuel telemetry clears the warning')
fuel.available, fuel.estimatedLaps = true, nil
car.lapCount = 19
assert(tick() == nil, 'Unknown consumption does not invent a remaining-lap estimate')
fuel.estimatedLaps, fuel.fuel = 1, 3
fuel.finishAvailable, fuel.fuelNeeded = true, 2
car.lapCount = 20
assert(tick() == nil, 'Enough fuel to finish must not request an unnecessary stop')
fuel.finishAvailable = false
car.lapCount = 21
assert(tick().kind == 'pit')
car.isInPitlane = true
assert(tick() == nil and state.pitFuelLaps == nil, 'Pit entry clears all notices')
condition.wheels[1].suspensionDamage = 0
car.isInPitlane = false
assert(tick() == nil, 'Pit exit waits for another crossing')
car.lapCount = 22
assert(tick().value == '~0 s', 'A healthy car has zero estimated repair time')
sim.isReplayActive = true
assert(tick() == nil and state.pitFuelLaps == nil, 'Live notices must not survive entering replay')
sim.isReplayActive = false
tick()
car.lapCount = 23
assert(tick().kind == 'pit')
sim.currentSessionIndex = 2
assert(tick() == nil, 'Session changes clear fuel reminders')
car.lapCount = 24
assert(tick().kind == 'pit')
sim.currentSessionTime = 0
assert(tick() == nil, 'Restarts clear fuel reminders')
car.lapCount = 25
assert(tick().kind == 'pit')
car.resetCounter = 1
assert(tick() == nil, 'Teleport/reset clears reminders')
car.isRaceFinished = true
assert(tick() == nil, 'Finished races must not show reminders')
car.isRaceFinished = false
fuel = nil
settings.repairEnabled = false
condition.wheels[1].suspensionDamage = 0.5
assert(tick() == nil, 'Disabled repairs do not show warnings')
settings.repairEnabled = true
assert(tick().kind == 'repair', 'Enabling notices while damaged must show the warning')
local before = state.clock
sim.isPaused = true
tick(10)
assert(state.clock == before, 'Pause must not consume a repair warning')

-- Feed the same measured-consumption engine used by the live leaderboard.
local Fuel = require('modules/leaderboard/src/fuel')
local fuelCar = {fuel=9,maxFuel=30,lapCount=0,isLastLapValid=true,previousLapTimeMs=90000}
local fuelSim = {currentSessionIndex=0,isSessionStarted=true}
local fuelState, fuelNotices = Fuel.new(), State.new()
local healthy = {available=true,body={},wheels={},engineDamage=0,gearboxDamage=0}
ac.getCar = function() return fuelCar end
ui = {time=function() return 0 end}
local function fuelTick()
  local measured = Fuel.update(fuelState, {sim=fuelSim}, {fuelReserve=1})
  fuelNotices:update(0.1, fuelCar, fuelSim, healthy, nil, settings, rates, measured)
  return fuelNotices.notice
end
assert(fuelTick() == nil, 'No measured lap means no fabricated fuel reminder')
fuelCar.fuel = 7
assert(fuelTick() == nil)
fuelCar.lapCount = 1
assert(fuelTick().title == 'BOX IN 3 LAPS' and fuelState.average == 2,
  'Observed consumption and reserve must drive the finish-line reminder')
fuelCar.fuel = 4
fuelTick()
fuelCar.lapCount = 2
assert(fuelTick().title == 'BOX THIS LAP', 'The next measured lap can leave only one complete lap of fuel')

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
print('Race Notices: flag attribution, priority, lap-based repair dismissal, fuel-driven crossing reminders, refuelling, resets, replay, pause and estimates passed')
