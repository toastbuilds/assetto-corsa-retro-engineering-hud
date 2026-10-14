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

local BattleAlert = require('modules/notices/src/battle')
local rear = {driver='COSTA',position=6,rate=-0.6,gapSeconds=0.8,status='LIVE',physicallyBehind=true}
local battle = {behind=rear}
local warning = BattleAlert.notice(battle)
assert(warning.kind == 'battle' and warning.urgent and warning.value == '~1.3')
assert(warning.detail == 'P6 COSTA / LOSING 0.6 s/LAP')
rear.rate, rear.gapSeconds = -1, 5
assert(BattleAlert.notice(battle) == nil, 'Exactly 1 s/lap alone must not trigger the fast-closing rule')
rear.rate = -1.01
assert(not BattleAlert.notice(battle).urgent, 'More than 1 s/lap warns even when the rival is far away')
rear.rate, rear.gapSeconds = -0.5, 1
assert(BattleAlert.notice(battle) == nil, 'Exactly two laps to catch is outside the imminent rule')
rear.gapSeconds = 0.8
assert(BattleAlert.notice(battle).urgent, '0.5 s/lap and under two laps to catch triggers')
rear.rate = -0.49
assert(BattleAlert.notice(battle) == nil, 'A closing rate below 0.5 must not warn')
rear.rate = 0.6
assert(BattleAlert.notice(battle) == nil, 'Gaining on the rear car must clear the alert')
battle.behind, battle.ahead = nil, rear
assert(BattleAlert.notice(battle) == nil, 'The car ahead must never generate this alert')
battle.behind, battle.ahead = rear, nil
rear.rate = nil
assert(BattleAlert.notice(battle) == nil, 'Incomplete lap history must not invent a threat')
rear.rate, rear.gapSeconds = -0.6, nil
assert(BattleAlert.notice(battle) == nil, 'A missing gap must not invent a catch forecast')
rear.gapSeconds, rear.physicallyBehind = 0.8, false
assert(BattleAlert.notice(battle) == nil, 'A class rival physically ahead is not a rear threat')
rear.physicallyBehind, rear.status = true, 'PIT'
assert(BattleAlert.notice(battle) == nil, 'A rival in pits must not generate a threat')
rear.status, battle.final = 'LIVE', true
assert(BattleAlert.notice(battle) == nil, 'Final results must not generate battle alerts')
battle.final, rear.estimated = false, true
assert(BattleAlert.notice(battle).detail:find('LOSING ~0.6', 1, true), 'Estimated closing rates must be identified')
local rearState, rearCar, rearSim = State.new(), {lapCount=0}, {currentSessionIndex=0,isSessionStarted=true}
local function rearTick(rearFuel)
  rearState:update(0.5, rearCar, rearSim, healthy, nil, settings, rates, rearFuel, battle)
  return rearState.notice
end
assert(rearTick().kind == 'battle', 'Eligible rear threats enter the actual notices queue')
settings.battleEnabled = false
assert(rearTick() == nil, 'Rear battle notices can be disabled independently')
settings.battleEnabled = true
rearCar.lapCount = 1
assert(rearTick({available=true,estimatedLaps=1,fuel=3}).kind == 'pit', 'Fuel reminders retain priority over battle alerts')
rearSim.raceFlagType = 12
assert(rearTick().kind == 'blue', 'Official blue flags retain priority over battle alerts')

local front = {driver='MARTIN',position=4,rate=0.6,gapSeconds=2.1,status='LIVE',physicallyBehind=false}
local attacks = {attackEnabled=true,battleEnabled=true}
local opportunity = {ahead=front}
local attack = BattleAlert.notice(opportunity, attacks)
assert(attack.side == 'ahead' and attack.title == 'ATTACK OPPORTUNITY' and not attack.urgent)
assert(attack.value == '~3.5' and attack.detail == 'P4 MARTIN / GAINING 0.6 s/LAP')
front.rate, front.gapSeconds = 0.5, 2
assert(BattleAlert.notice(opportunity, attacks) == nil, 'Exactly four laps is outside the attack horizon')
front.gapSeconds = 1.99
assert(BattleAlert.notice(opportunity, attacks), 'Attack horizon extends beyond the rear two-lap threshold')
front.rate = 0.49
assert(BattleAlert.notice(opportunity, attacks) == nil, 'Attack needs at least 0.5 s/lap gained')
front.rate, front.gapSeconds = 2, 9
assert(BattleAlert.notice(opportunity, attacks) == nil, 'Fast gains cannot bypass the four-lap attack horizon')
front.rate, front.gapSeconds = -0.6, 2.1
assert(BattleAlert.notice(opportunity, attacks) == nil, 'Losing to the car ahead is not an attack opportunity')
front.rate, front.physicallyBehind = 0.6, true
assert(BattleAlert.notice(opportunity, attacks) == nil, 'A class rival physically behind is not an attack target')
front.physicallyBehind, front.status = false, 'PIT'
assert(BattleAlert.notice(opportunity, attacks) == nil, 'Pitting targets must not generate attack notices')
front.status, opportunity.final = 'LIVE', true
assert(BattleAlert.notice(opportunity, attacks) == nil, 'Final results suppress attack notices')
opportunity.final, front.estimated = false, true
assert(BattleAlert.notice(opportunity, attacks).detail:find('GAINING ~0.6', 1, true))
rear.rate, rear.gapSeconds, rear.estimated = -0.6, 0.8, false
battle.final, battle.ahead = false, front
assert(BattleAlert.notice(battle, attacks).side == 'behind', 'Rear warnings retain priority over attacks')
attacks.battleEnabled = false
assert(BattleAlert.notice(battle, attacks).side == 'ahead', 'Rear toggle must not disable attacks')
attacks.attackEnabled = false
assert(BattleAlert.notice(battle, attacks) == nil, 'Attack toggle disables attack notices independently')
settings.battleEnabled, settings.attackEnabled = false, true
rearSim.raceFlagType = 0
assert(rearTick().side == 'ahead', 'Attack opportunities enter the actual notices queue')
rearSim.raceFlagType = 12
assert(rearTick().kind == 'blue', 'Blue flags retain priority over attack opportunities')
rearSim.raceFlagType = 0
rearCar.lapCount = 2
assert(rearTick({available=true,estimatedLaps=1,fuel=3}).kind == 'pit', 'Fuel reminders retain priority over attacks')
rearTick()
settings.attackEnabled = false
assert(rearTick() == nil, 'Disabled attacks must clear the actual notices queue')

local BattleState = require('modules/notices/src/pace')
ac.SessionType = {Race=2}
local liveBattle = BattleState.new()
local livePlayer = {index=0,classID='GT3',progress=0,status='LIVE'}
local liveRear = {index=1,driver='COSTA',carID='gt3',classID='GT3',status='LIVE',intervalSource='history'}
for i=0,10 do
  livePlayer.progress = i/10
  liveRear.intervalSeconds = -(1.4 - 0.6 * livePlayer.progress)
  liveBattle:update({localRow=livePlayer,rows={livePlayer,liveRear},session={type=2},
    timeline={time=i*0.5},historyReset=i==0})
  if i<10 then assert(BattleAlert.notice(liveBattle.snapshot)==nil, 'Live data needs a full observed lap') end
end
assert(BattleAlert.notice(liveBattle.snapshot).value == '~1.3', 'Live Battle gap and rate must reach the notice forecast')
liveRear.intervalSeconds = 0.8
liveBattle:update({localRow=livePlayer,rows={livePlayer,liveRear},session={type=2},timeline={time=5.5}})
assert(BattleAlert.notice(liveBattle.snapshot)==nil, 'A physically passed rival clears the live rear alert')

local liveAttack = BattleState.new()
local liveFront = {index=2,driver='MARTIN',carID='gt3',classID='GT3',status='LIVE',intervalSource='history'}
for i=0,10 do
  livePlayer.progress = i/10
  liveFront.intervalSeconds = 2.7 - 0.6 * livePlayer.progress
  liveAttack:update({localRow=livePlayer,rows={liveFront,livePlayer},session={type=2},
    timeline={time=i*0.5},historyReset=i==0})
  if i<10 then assert(BattleAlert.notice(liveAttack.snapshot,{attackEnabled=true})==nil,
    'Attack needs a full observed lap of live data') end
end
assert(BattleAlert.notice(liveAttack.snapshot,{attackEnabled=true}).value == '~3.5',
  'Live class rival ahead reaches the four-lap attack forecast without a separate panel')
liveAttack:update({localRow=livePlayer,rows={liveFront,livePlayer},session={type=2},
  timeline={time=5.5},historyReset=true})
assert(BattleAlert.notice(liveAttack.snapshot,{attackEnabled=true})==nil, 'History resets clear attack forecasts')

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
print('Race Notices: flags, priorities, repairs, fuel, rear threats, four-lap attacks, live pace, resets and estimates passed')
