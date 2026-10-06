package.path = './?.lua;' .. package.path

local startCallback, releaseCallback, disposed, registrations
disposed, registrations = 0, 0
ac = {
  onSessionStart = function(callback)
    registrations = registrations + 1
    startCallback = callback
    return { dispose = function() disposed = disposed + 1 end }
  end,
  onRelease = function(callback) releaseCallback = callback end,
}
local Stint = require('src/tyre_stint')
local function near(actual, expected, message)
  assert(math.abs(actual - expected) < 0.000001,
    (message or 'distance') .. ': expected ' .. expected .. ', got ' .. actual)
end
local function car(virtual, wear)
  local result = { index = 0, compoundIndex = 0, lapCount = 0, splinePosition = 0.4,
    distanceDrivenSessionKm = 100, speedKmh = 180, wheels = {} }
  for i = 0, 3 do result.wheels[i] = { tyreVirtualKM = virtual or 0, tyreWear = wear or 0 } end
  return result
end
local function tyres(value, virtual, wear)
  for i = 0, 3 do
    value.wheels[i].tyreVirtualKM = virtual
    value.wheels[i].tyreWear = wear
  end
end
local sim = { currentSessionIndex = 0, trackLengthM = 5000 }
local function update(state, value, dt) return Stint.update(state, value, sim, dt or 1) end
local function fields(value)
  assert(type(value) == 'table')
  for _, key in ipairs({'laps', 'km', 'resetGeneration'}) do
    assert(type(value[key]) == 'number' and value[key] >= 0 and value[key] < math.huge, key)
  end
  assert(type(value.approximate) == 'boolean' and type(value.observedOnly) == 'boolean')
end

local state, value = Stint.new(), car()
fields(state.snapshot)
assert(state.snapshot.resetGeneration == 0)
local result = update(state, value)
assert(result.laps == 0 and not result.approximate and not result.observedOnly)
value.distanceDrivenSessionKm = 100.05
value.splinePosition = 0.98
update(state, value)
value.distanceDrivenSessionKm = 100.08
value.splinePosition = 0.02
value.isLapValid, value.isInPitlane = false, true
result = update(state, value)
assert(result.laps == 1, 'partial invalid outlap must count its finish crossing, including pitlane')
value.lapCount = 1
assert(update(state, value).laps == 1, 'a delayed counter must not count the crossing twice')
near(result.km, 0.08)
value.splinePosition = 0.95
update(state, value)
value.lapCount = 2
assert(update(state, value).laps == 2, 'counter can precede spline wrap')
value.splinePosition = 0.01
assert(update(state, value).laps == 2, 'delayed spline wrap must not double count')
value.splinePosition = 0.5
update(state, value)
value.lapCount = 4
assert(update(state, value).laps == 4, 'all counter crossings count even when sampling skips laps')

state, value = Stint.new(), car()
value.lapCount = nil
value.splinePosition = 0.95
update(state, value)
value.splinePosition = 0.01
assert(update(state, value).laps == 1, 'spline supplies crossings when lapCount is missing')
value.splinePosition = 0.1
assert(update(state, value).laps == 1)
state, value = Stint.new(), car()
value.splinePosition = 0.95
update(state, value)
for n = 1, 2 do
  value.splinePosition = 0.01
  assert(update(state, value).laps == n)
  value.splinePosition = 0.5
  update(state, value)
  value.splinePosition = 0.95
  update(state, value)
end
value.lapCount = 2
assert(update(state, value).laps == 2, 'a counter catching up multiple delayed crossings must not double count')

-- Backfill uses each wheel's measured virtual/real ratio, including axle differences.
state, value = Stint.new(), car(20, 0.2)
value.lapCount = 7
local scales = {2, 2, 4, 4}
for i = 0, 3 do value.wheels[i].tyreVirtualKM = 10 * scales[i + 1] end
result = update(state, value)
assert(result.observedOnly and result.approximate and result.km == 0 and result.laps == 0)
for n = 1, 3 do
  value.distanceDrivenSessionKm = 100 + n * 0.05
  for i = 0, 3 do value.wheels[i].tyreVirtualKM = (10 + n * 0.05) * scales[i + 1] end
  result = update(state, value)
  if n < 3 then assert(result.observedOnly, 'one or two intervals cannot establish a rate') end
end
near(result.km, 10.15, 'calibrated prior distance')
assert(result.laps == 2 and result.approximate and not result.observedOnly)
local generation = result.resetGeneration
value.justJumped, value.lapCount = true, 0
value.distanceDrivenSessionKm = 150
result = update(state, value)
near(result.km, 10.15, 'teleport must exclude odometer increment')
assert(result.laps == 2 and result.resetGeneration == generation, 'used set survives car reset')
value.justJumped = false
value.distanceDrivenSessionKm = 150.05
near(update(state, value).km, 10.2, 'distance resumes from the teleport destination')
near(update(state, nil).km, 10.2, 'nil car retains previously calibrated age')
value.distanceDrivenSessionKm = 200
for i = 0, 3 do value.wheels[i].tyreVirtualKM = 200 * scales[i + 1] end
near(update(state, value).km, 10.2, 'reconnection does not estimate or count the missing distance again')
value.distanceDrivenSessionKm = 200.05
near(update(state, value).km, 10.25, 'calibrated age resumes with observed travel only')

state, value = Stint.new(), car(10, 0.3)
value.resetCounter, value.splinePosition = 4, 0.99
update(state, value)
value.distanceDrivenSessionKm = 100.05
update(state, value)
generation = state.snapshot.resetGeneration
value.resetCounter, value.splinePosition, value.lapCount = 5, 0.01, 1
value.distanceDrivenSessionKm = 100.09
result = update(state, value)
near(result.km, 0.05, 'resetCounter catches a reset even when its distance increment looks plausible')
assert(result.resetGeneration == generation and result.laps == 0 and result.approximate,
  'missed justJumped retains the used set and excludes a false finish crossing')
value.distanceDrivenSessionKm = 100.14
near(update(state, value).km, 0.1, 'resetCounter rebaselines for the next genuine distance increment')
tyres(value, 4, 0.12)
value.resetCounter = 6
result = update(state, value)
assert(result.resetGeneration == generation, 'a reset onto still-used tyres must not imply a fresh set')
near(result.km, 0.1)

-- Wear disabled and unavailable virtual distance still support observed travel.
state, value = Stint.new(), car()
tyres(value, nil, 0)
result = Stint.update(state, value, nil, 1)
assert(result.observedOnly and result.approximate)
for n = 1, 5 do
  value.distanceDrivenSessionKm = 100 + n * 0.05
  result = Stint.update(state, value, nil, 1)
end
near(result.km, 0.25)
assert(result.observedOnly, 'zero wear does not imply a known fresh set')
state, value = Stint.new(), car(50, 0)
update(state, value)
for n = 1, 4 do
  value.distanceDrivenSessionKm = 100 + n * 0.05
  result = update(state, value)
end
near(result.km, 0.2)
assert(result.observedOnly, 'constant virtual distance must not be converted by an arbitrary multiplier')

-- Replacement detection requires a coherent set; pits alone do not reset it.
state, value = Stint.new(), car(10, 0.3)
update(state, value)
value.distanceDrivenSessionKm = 100.05
value.isInPit, value.isInPitlane = true, true
update(state, value)
generation = state.snapshot.resetGeneration
value.wheels[0].tyreVirtualKM, value.wheels[0].tyreWear = 0, 0
result = update(state, value)
assert(result.resetGeneration == generation and result.approximate)
near(result.km, 0.05, 'one-wheel drop must retain observed distance')
-- Restore before resetting all four wheels together.
tyres(value, 10, 0.3)
update(state, value)
tyres(value, 0, 0)
result = update(state, value)
assert(result.resetGeneration == generation + 1 and result.km == 0 and result.laps == 0)
assert(not result.approximate and not result.observedOnly, 'same-compound fresh set is known')
tyres(value, 2, 0.1)
value.distanceDrivenSessionKm = 100.1
update(state, value)
value.compoundIndex = 1
result = update(state, value)
assert(result.resetGeneration == generation + 2 and result.observedOnly and result.km == 0)
state, value = Stint.new(), car(0, 0.4)
tyres(value, nil, 0.4)
update(state, value)
generation = state.snapshot.resetGeneration
tyres(value, nil, 0)
assert(update(state, value).resetGeneration == generation + 1, 'coherent wear reset works without virtual telemetry')

-- Discontinuities preserve known age but never bridge distance or laps.
state, value = Stint.new(), car()
update(state, value)
value.distanceDrivenSessionKm = 100.05
update(state, value)
value.distanceDrivenSessionKm = 0
value.lapCount = 0
near(update(state, value).km, 0.05, 'odometer rollback retains age')
value.distanceDrivenSessionKm = 20
near(update(state, value).km, 0.05, 'unflagged implausible odometer jump is excluded')
value.distanceDrivenSessionKm = 20.05
near(update(state, value).km, 0.1)
result = update(state, nil)
fields(result)
value.distanceDrivenSessionKm, value.lapCount = 30, 20
near(update(state, value).km, 0.1, 'nil car rebaselines without bridging the gap')
assert(state.snapshot.laps == 0 and state.snapshot.approximate)
value.distanceDrivenSessionKm = 30.05
near(update(state, value).km, 0.15)
value.distanceDrivenSessionKm = nil
value.distanceDrivenTotalKm = 1000
near(update(state, value).km, 0.15, 'switching odometers must rebaseline')
value.distanceDrivenTotalKm = 1000.05
near(update(state, value).km, 0.2, 'total odometer fallback measures travel')

state, value = Stint.new(), car()
value.position = {x = 0, y = 0, z = 0}
value.splinePosition = 0.99
update(state, value)
value.position.x, value.splinePosition = 1000, 0.01
value.distanceDrivenSessionKm = 100.001
result = update(state, value)
assert(result.km == 0 and result.laps == 0 and result.approximate, 'position teleport excludes a false finish wrap')

-- Replay seeks are separate from continuous fast playback and pauses.
state, value = Stint.new(), car(20, 0.2)
update(state, value)
generation = state.snapshot.resetGeneration
sim.isReplayActive, sim.replayCurrentFrame = true, 100
sim.replayFrameMs, sim.replayPlaybackRate = 100, 1
result = update(state, value, 0.1)
assert(result.resetGeneration == generation + 1 and result.km == 0)
sim.replayCurrentFrame = 101
value.distanceDrivenSessionKm = 100.005
near(update(state, value, 0.1).km, 0.005)
sim.replayPlaybackRate, sim.replayCurrentFrame = 4, 131
value.distanceDrivenSessionKm = 100.155
result = update(state, value, 0.75)
assert(result.resetGeneration == generation + 1, 'continuous fast playback retains history')
near(result.km, 0.155, 'accelerated replay still measures actual odometer distance')
sim.replayPlaybackRate = 0
assert(update(state, value, 0.1).resetGeneration == generation + 1, 'pause retains history')
sim.replayPlaybackRate, sim.replayCurrentFrame = 1, 90
result = update(state, value, 0.1)
assert(result.resetGeneration == generation + 2 and result.km == 0 and result.laps == 0)
assert(state.calibration.samples == 0, 'rewind clears calibration history')
sim.replayCurrentFrame = 300
value.lapCount = 40
result = update(state, value, 0.1)
assert(result.resetGeneration == generation + 3 and result.laps == 0, 'forward seek must not manufacture crossings')
sim.isReplayActive = false
result = update(state, value)
assert(result.resetGeneration == generation + 4 and result.km == 0, 'replay exit starts a new observation')
sim.currentSessionIndex = 1
assert(update(state, value).resetGeneration == generation + 5, 'session index change clears history')
sim.time = 5000
update(state, value)
sim.time = 1000
assert(update(state, value).resetGeneration == generation + 6, 'simulation time rewind clears history')
sim.time = nil

-- Zero physics channels in replay or on a remote car do not prove freshness.
local replaySim = {isReplayActive = true, replayCurrentFrame = 100,
  replayFrameMs = 100, replayPlaybackRate = 1, currentSessionIndex = 0}
local replayState, replayCar = Stint.new(), car()
result = Stint.update(replayState, replayCar, replaySim, 0.1)
assert(result.approximate and result.observedOnly, 'replay zeros cannot receive an exact fresh marker')
for n = 1, 4 do
  replaySim.replayCurrentFrame = 100 + n
  replayCar.distanceDrivenSessionKm = 100 + n * 0.005
  tyres(replayCar, n * 0.01, 0)
  result = Stint.update(replayState, replayCar, replaySim, 0.1)
end
assert(result.observedOnly, 'a replay zero baseline cannot backfill unknown prior age')
near(result.km, 0.02)
replayState, replayCar = Stint.new(), car(10, 0.2)
update(replayState, replayCar)
generation = replayState.snapshot.resetGeneration
replayCar.physicsAvailable = false
tyres(replayCar, 0, 0)
result = update(replayState, replayCar)
assert(result.resetGeneration == generation and result.approximate,
  'losing physics data must not manufacture a tyre replacement')
replayState, replayCar = Stint.new(), car()
replayCar.physicsAvailable = false
result = Stint.update(replayState, replayCar, nil, 1)
assert(result.approximate and result.observedOnly, 'remote-car zeros cannot prove freshness')
state, value = Stint.new(), car(10, 0.2)
update(state, value)
generation = state.snapshot.resetGeneration
update(state, nil)
value.compoundIndex = 2
assert(update(state, value).resetGeneration == generation + 1, 'compound changes during telemetry loss still reset the set')
update(state, nil)
value.index = 1
assert(update(state, value).resetGeneration == generation + 2, 'car identity survives a nil-car frame')

-- A changed wear multiplier cannot be calibrated from inconsistent samples.
state, value = Stint.new(), car(20, 0.2)
update(state, value)
for n = 1, 3 do
  value.distanceDrivenSessionKm = 100 + n * 0.05
  tyres(value, 20 + (n == 1 and 0.1 or n == 2 and 0.5 or 0.6), 0.2)
  result = update(state, value)
end
assert(result.observedOnly and result.approximate)
near(result.km, 0.15, 'inconsistent virtual rates retain measured distance')
-- Fresh replay entry clears prior live observations while preserving uncertainty.
state, value = Stint.new(), car()
update(state, value)
value.distanceDrivenSessionKm = 100.05
update(state, value)
generation = state.snapshot.resetGeneration
result = Stint.update(state, value, replaySim, 0.1)
assert(result.resetGeneration == generation + 1 and result.km == 0
  and result.observedOnly and result.approximate)
Stint.update(state, value, nil, 0.1)
assert(state.snapshot.resetGeneration == generation + 1, 'missing sim is not a replay exit')
result = update(state, value)
assert(result.resetGeneration == generation + 2, 'explicit replay exit clears observation history')

assert(registrations == 1, 'states share one session subscription')
local other = Stint.new()
generation = state.snapshot.resetGeneration
local otherGeneration = other.snapshot.resetGeneration
startCallback(1, true)
assert(state.snapshot.resetGeneration == generation + 1 and state.snapshot.km == 0,
  'same-index restart callback immediately clears the published snapshot')
assert(other.snapshot.resetGeneration == otherGeneration + 1)
result = update(state, value)
assert(result.resetGeneration == generation + 1, 'first update after callback must not reset twice')
releaseCallback()
releaseCallback()
assert(disposed == 1, 'release disposes the subscription once')
startCallback(1, true)
assert(state.snapshot.resetGeneration == generation + 1, 'late callback after release is ignored')

local functionDisposed, functionRelease = 0, nil
ac = {
  onSessionStart = function() return function() functionDisposed = functionDisposed + 1 end end,
  onRelease = function(callback) functionRelease = callback end,
}
Stint.new()
functionRelease()
assert(functionDisposed == 1, 'SDK function disposables are cleaned up on release')

-- Minimal and hostile mocks never need storage or callback implementations.
for _, api in ipairs({{}, {
  onSessionStart = function() error('unavailable') end,
  onRelease = function() error('unavailable') end,
}}) do
  ac = api
  local minimal = Stint.new()
  fields(minimal.snapshot)
  fields(Stint.update(minimal, nil, nil, nil))
  fields(Stint.update(minimal, {}, nil, 0))
  local invalid = car(math.huge, 0/0)
  invalid.distanceDrivenSessionKm = 0/0
  fields(Stint.update(minimal, invalid, nil, -1))
  fields(Stint.update(minimal, setmetatable({}, {__index = function() error('missing') end}), nil, 1))
end
ac = nil
fields(Stint.update(Stint.new(), nil, nil, nil))
print('Tyre stint: crossings, real distance, replacements, calibration, missing data, jumps, replay, sessions and cleanup passed')
