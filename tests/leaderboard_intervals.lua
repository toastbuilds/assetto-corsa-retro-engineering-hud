package.path = './?.lua;' .. package.path
local Intervals = require('modules/leaderboard/src/intervals')
local Timeline = require('modules/leaderboard/src/timeline')

local function near(actual, expected, message)
  assert(actual ~= nil and math.abs(actual - expected) < 0.00000001,
    (message or 'timestamp mismatch') .. ': ' .. tostring(actual) .. ' ~= ' .. tostring(expected))
end

local function world(sdk, replay, startPlayer, startOther, failGate)
  local w = {wall = 9000, handlers = {}, disposed = 0, registered = 0}
  ui = {time = function() return w.wall end}
  ac = {}
  if sdk then
    ac.onTrackPointCrossed = function(index, progress, callback)
      assert(index == -1, 'shared SDK gates must observe all cars')
      local gate = math.floor(progress * 100 + 0.5)
      if gate == failGate then error('unsupported SDK gate') end
      local entry = {callback = callback, active = true}
      w.handlers[gate], w.registered = entry, w.registered + 1
      return function()
        assert(entry.active, 'subscription disposed twice')
        entry.active = false
        if w.handlers[gate] == entry then w.handlers[gate] = nil end
        w.disposed = w.disposed + 1
      end
    end
  end
  w.sim = {time = 100000, currentSessionTime = 10000, currentSessionIndex = 0,
    isReplayActive = replay == true, replayCurrentFrame = 0, replayFrameMs = 10,
    replayPlaybackRate = 1, dt = 0, isPaused = false, trackLengthM = 6000}
  w.player = {index = 0, driver = 'Player', carID = 'test', active = true,
    connected = true, status = 'LIVE', position = 2, currentLapTimeMs = 19000,
    speedMs = 55, car = {isConnected = true, isActive = true, isInPitlane = false}}
  w.other = {index = 1, driver = 'Other', carID = 'test', active = true,
    connected = true, status = 'LIVE', position = 1, currentLapTimeMs = 12000,
    speedMs = 90, car = {isConnected = true, isActive = true, isInPitlane = false}}
  w.state, w.settings = Intervals.new(), {intervalRefresh = 0.1}
  local function position(row, progress)
    row.progress, row.lapCount, row.splinePosition = progress, math.floor(progress), progress % 1
  end
  function w:step(seconds, playerProgress, otherProgress, flags)
    flags = flags or {}
    self.wall = self.wall + (flags.wallSeconds or seconds / math.max(1, math.abs(self.sim.replayPlaybackRate)))
    self.sim.time = self.sim.time + seconds * 1000
    self.sim.currentSessionTime = self.sim.currentSessionTime + seconds * 1000
    self.sim.dt = seconds
    if self.sim.isReplayActive then
      self.sim.replayCurrentFrame = self.sim.replayCurrentFrame + seconds * 1000 / self.sim.replayFrameMs
    end
    if playerProgress then position(self.player, playerProgress) end
    if otherProgress then position(self.other, otherProgress) end
    self.snapshot = {sim = self.sim, rows = {self.player, self.other}, localRow = self.player,
      timeline = Timeline.sample(self.sim), historyReset = flags.historyReset,
      resetToken = flags.resetToken, final = flags.final, header = {isTimed = true}}
    Intervals.update(self.state, self.snapshot, self.settings)
  end
  function w:fire(index, gate, seconds)
    local entry = assert(self.handlers[gate], 'missing SDK subscription')
    assert(entry.active)
    entry.callback(index, seconds * 1000)
  end
  w:step(0, startPlayer or 0.499, startOther or 0.499)
  return w
end

local function observedPair(replay, behind, wrap)
  local base = wrap and 0.995 or 0.495
  local w = world(false, replay, base, base)
  if behind then
    w:step(0.2, base + 0.008, base + 0.004)
    w:step(0.2, base + 0.012, base + 0.008)
  else
    w:step(0.2, base + 0.004, base + 0.008)
    near(w.other.intervalSeconds, 0.1, 'leading history can resolve a gap before shared gates')
    w:step(0.2, base + 0.008, base + 0.012)
  end
  near(w.other.intervalSeconds, behind and -0.2 or 0.2)
  assert(w.other.intervalSource == 'history')
  return w
end

-- CMRT-style live history works before a shared 1%-lap gate is reached.
do
  local w = world(true, false, 0.401, 0.401)
  w:step(0.2, 0.403, 0.405)
  near(w.other.intervalSeconds, 0.1, 'dense history must not wait for shared gates')
  assert(w.other.intervalSource == 'history')
  w = world(true, false, 0.1, 0.2)
  w:step(0.2, 0.101, 0.201)
  near(w.other.intervalSeconds, 600 / 55, 'missing history uses distance and trailing speed')
  assert(w.other.intervalSource == 'estimated')
  assert(w.other.interval == '~+10.9s', 'speed estimates must be identifiable')
  w.player.speedMs = 0
  w:step(0.2, 0.102, 0.202)
  near(w.other.intervalSeconds, 600 / 18, 'stationary speed must remain finite')
  w = world(true, false, 0.98, 1.02)
  w:step(0.2, 0.981, 1.021)
  near(w.other.intervalSeconds, 240 / 55, 'finish-line fallback uses unwrapped distance')
  w = world(true, false, 0.995, 0.995)
  w.sim.isOnlineRace = true
  w:step(0.2, 0.999, 0.003)
  w:step(0.2, 1.003, 0.007)
  near(w.other.intervalSeconds, 0.2, 'online remote lapCount stuck at zero must preserve finish crossings')
  assert(w.other.intervalSource == 'history')
  w.other.car.justJumped = true
  w:step(0.01, 1.004, 0.008)
  assert(w.other.interval == '--', 'online lap inference must not survive a pit teleport')
  w = world(false, false, 0.2, 0.1)
  w:step(0.2, 0.201, 0.101)
  near(w.other.intervalSeconds, -600 / 90, 'behind estimate uses the trailing opponent speed')
  assert(w.other.intervalSource == 'estimated')
  w.sim.trackLengthM = nil
  w:step(0.2, 0.202, 0.102)
  assert(w.other.interval == '--', 'missing track length cannot create a speed estimate')
end

-- SDK timestamps, not render time, lap clocks, speeds or UI wall time.
do
  local w = world(true)
  assert(w.registered == 100 and w.state.sdkActive)
  assert(w.other.interval == '--' and w.player.interval == '-')
  w:fire(1, 50, 100.123456)
  w:fire(0, 50, 100.234567)
  w:step(0.5, 0.503, 0.504)
  near(w.other.intervalSeconds, 0.111111, 'SDK sub-millisecond timestamps')
  assert(w.other.interval == '+0.1s' and w.other.intervalSource == 'sdk')
  w.player.currentLapTimeMs, w.other.currentLapTimeMs = 1, 900000
  w.player.speedMs, w.other.speedMs = 0, 1000
  w:step(0.5, 0.505, 0.506)
  near(w.other.intervalSeconds, 0.111111, 'interval must not age since one car crossed')

  -- An individual finish and a global Finished flag do not freeze intervals.
  w.other.status, w.other.car.isRaceFinished, w.sim.raceFlagType = 'FIN', true, 'Finished'
  w:fire(1, 51, 101.111)
  w:fire(0, 51, 101.233)
  w:step(0.5, 0.513, 0.514)
  near(w.other.intervalSeconds, 0.122, 'individual FIN remains measured')

  -- First final snapshot computes even inside the refresh interval, then freezes.
  w:fire(1, 52, 101.51)
  w:fire(0, 52, 101.54)
  w:step(0.05, 0.523, 0.524, {final = true})
  near(w.other.intervalSeconds, 0.03)
  assert(w.disposed == 100 and w.state.finalFrozen)
  w:step(130, 0.523, 0.524, {final = true})
  near(w.other.intervalSeconds, 0.03, 'frozen final cache survives aging')
  w:step(0.1, 0.524, 0.525)
  assert(w.other.interval == '--', 'leaving final results seeds fresh observations')
end

do
  local w = world(true, false, 0.495, 0.495)
  w:step(0.2, 0.499, 0.503)
  near(w.other.intervalSeconds, 0.1, 'silent SDK uses continuous position history')
  w:step(0.2, 0.503, 0.507)
  near(w.other.intervalSeconds, 0.2, 'silent SDK must retain measured position history')
  assert(w.other.intervalSource == 'history')

  -- Physics callbacks can arrive after an observation recorded the same gate.
  w:fire(1, 50, 100.123456)
  w:fire(0, 50, 100.234567)
  w:step(0.2, 0.504, 0.508)
  near(w.other.intervalSeconds, 0.111111, 'SDK timestamps replace observed crossings')
  assert(w.other.intervalSource == 'sdk')
end

do
  local w = world(true)
  w:fire(0, 51, 100.1)
  w:fire(1, 52, 100.2)
  w:step(0.5, 0.499, 0.499)
  assert(w.other.intervalSource == 'estimated', 'different SDK gates cannot be paired')
  near(w.other.intervalSeconds, 0, 'equal progress has zero estimated separation')
end

do
  local w = world(true, false, 0.995, 0.995)
  w:fire(1, 0, 100.123)
  w:fire(0, 0, 100.234)
  w:step(0.5, 1.003, 1.004)
  near(w.other.intervalSeconds, 0.111, 'SDK finish-line wrap uses the correct lap')
  assert(w.state.cars[0].crossings[100] and w.state.cars[1].crossings[100])
end

-- Missing history falls back to distance/speed; lap clocks do not seed gaps.
do
  local w = world(false, false, 0.1, 0.2)
  w:step(0.2, 0.101, 0.201)
  near(w.other.intervalSeconds, 600 / 55)
  assert(w.other.intervalSource == 'estimated')
  w.player.currentLapTimeMs, w.other.currentLapTimeMs = 1, 900000
  w:step(0.2, 0.102, 0.202)
  near(w.other.intervalSeconds, 600 / 55, 'unrelated lap clocks cannot seed a gap')
  observedPair(false)
  local partial = world(true, false, 0.495, 0.495, 10)
  assert(not partial.state.sdkActive and partial.disposed == 10)
  partial:step(0.2, 0.499, 0.503)
  partial:step(0.2, 0.503, 0.507)
  near(partial.other.intervalSeconds, 0.2, 'SDK registration failure uses position history')
  assert(partial.other.intervalSource == 'history')
end

-- Replay frame time is independent of both UI time and the live SDK epoch.
do
  local w = observedPair(true)
  assert(w.snapshot.timeline.clock == 'replay' and w.snapshot.timeline.time == 0.4)
  near(w.snapshot.timeline.sdkTime, 100.4)
  assert(w.other.interval == '+0.2s')
  w.sim.isPaused, w.sim.replayPlaybackRate = true, 0
  w:step(0, nil, nil, {wallSeconds = 1000})
  near(w.other.intervalSeconds, 0.2, 'paused replay retains crossing history')
  w.sim.isPaused, w.sim.replayPlaybackRate = false, 4
  local generation = w.state.generation
  w:step(0.4, 0.511, 0.515)
  assert(w.state.generation == generation, 'accelerated replay is continuous')
  assert(w.other.intervalSeconds ~= nil)
  local behind = observedPair(true, true)
  assert(behind.other.interval == '-0.2s')
  observedPair(true, false, true)
  local sdkReplay = world(true, true)
  assert(sdkReplay.registered == 0, 'replay must not use live SDK callbacks')
end

-- Seeks in either direction, mode changes, session clocks and explicit resets.
do
  local w = observedPair(true)
  w.sim.replayCurrentFrame = w.sim.replayCurrentFrame + 400
  w:step(0.1, 0.504, 0.508)
  assert(w.other.interval == '--' and next(w.state.cars[0].crossings) == nil,
    'forward seek cannot interpolate across skipped frames')
  w.sim.replayCurrentFrame = 5
  w:step(0.1, 0.504, 0.508)
  assert(w.other.interval == '--', 'rewind discards future crossings')
  w.sim.isReplayActive = false
  w:step(0.1, 0.505, 0.509)
  assert(w.other.interval == '--', 'leaving replay clears its epoch')
end

for _, kind in ipairs({'historyReset', 'resetToken', 'sessionIndex', 'sessionTime', 'manual'}) do
  local w = observedPair(false)
  local flags = {}
  if kind == 'historyReset' then flags.historyReset = true end
  if kind == 'resetToken' then flags.resetToken = 1 end
  if kind == 'sessionIndex' then w.sim.currentSessionIndex = 1 end
  if kind == 'sessionTime' then w.sim.currentSessionTime = 1000 end
  if kind == 'manual' then Intervals.reset(w.state, 0) end
  w:step(0.01, 0.504, 0.508, flags)
  assert(w.other.interval == '--', kind .. ' must clear the refresh cache immediately')
  assert(next(w.state.cars[0].crossings) == nil, kind .. ' must clear crossing history')
end

do
  local w = world(true)
  local oldCallback = w.handlers[50].callback
  w:fire(1, 50, 100.1)
  w:fire(0, 50, 100.2)
  w:step(0.5, 0.503, 0.504)
  w:step(0.01, 0.504, 0.505, {historyReset = true})
  assert(w.disposed == 100 and w.registered == 200)
  oldCallback(0, 100700)
  assert(#w.state.sdkEvents == 0, 'old callback generations cannot repopulate reset history')
  local resetSnapshot = w.snapshot
  local generation = w.state.generation
  Intervals.update(w.state, resetSnapshot, w.settings)
  assert(w.state.generation == generation, 'reusing one reset snapshot clears only once')
end

-- Reconnects, replacement identities, missing cars, pits and teleports clear pairs.
for _, kind in ipairs({'reconnected', 'connected', 'active', 'carConnected', 'identity',
  'pit', 'jump', 'backward', 'forward', 'invalid', 'missing'}) do
  local w = observedPair(false)
  if kind == 'reconnected' then w.other.reconnected = true end
  if kind == 'connected' then w.other.connected = false end
  if kind == 'active' then w.other.active = false end
  if kind == 'carConnected' then w.other.car.isConnected = false end
  if kind == 'identity' then w.other.driver = 'Replacement' end
  if kind == 'pit' then w.other.car.isInPitlane = true end
  if kind == 'jump' then w.other.car.justJumped = true end
  if kind == 'backward' then w.other.progress = 0.4 end
  if kind == 'forward' then w.other.progress = 0.9 end
  if kind == 'invalid' then w.other.progress = math.huge end
  if kind == 'missing' then
    w.snapshot.rows = {w.player}
    Intervals.update(w.state, w.snapshot, w.settings)
  end
  w:step(0.01)
  assert(w.other.interval == '--' and w.other.intervalSeconds == nil,
    kind .. ' must discard prior measurements inside the refresh window')
end

do
  local w = observedPair(false)
  w.other.connected = false
  w:step(0.01)
  w.other.connected = true
  w:step(0.01)
  assert(w.other.interval == '--', 'reconnect must not interpolate across disconnection')
  w:step(0.2, 0.509, 0.513)
  w:step(0.2, 0.513, 0.517)
  assert(w.other.intervalSeconds ~= nil, 'new shared crossings restore intervals')
  w:step(0.01, 0.514, 0.512)
  assert(w.other.interval == '--', 'overtake or reversing invalidates the old order')
end

-- Lap labels convey observed lap separation, never a time estimate.
do
  local w = world(false, false, 0.1, 1.2)
  assert(w.other.interval == 'L +1' and w.other.intervalSeconds == nil)
  w = world(false, false, 2.2, 0.1)
  assert(w.other.interval == 'L -2' and w.other.intervalSource == nil)
end

-- Missing clocks, invalid replay metadata and clock changes cannot manufacture history.
do
  local w = world(false)
  local sample = Timeline.sample(w.sim)
  near(sample.time, 100)
  near(sample.sessionTime, 10)
  w.sim.time = nil
  local fallback = Timeline.sample(w.sim)
  assert(fallback.clock == 'session' and fallback.time == 10)
  assert(Timeline.discontinuous(sample, fallback, w.sim), 'live clock changes reset history')
  w.sim.currentSessionTime = nil
  assert(Timeline.sample(w.sim).measuredClock == false)
  w.snapshot.timeline = Timeline.sample(w.sim)
  Intervals.update(w.state, w.snapshot, w.settings)
  assert(next(w.state.cars) == nil, 'wall time alone cannot record crossings')
end

do
  local w = world(false, true)
  w.sim.replayFrameMs = 0
  w.snapshot.timeline = Timeline.sample(w.sim)
  Intervals.update(w.state, w.snapshot, w.settings)
  assert(w.other.interval == '--' and next(w.state.cars) == nil,
    'replay without a valid frame clock cannot record crossings')
  Intervals.update(w.state, nil, w.settings)
  assert(next(w.state.cars) == nil and next(w.state.cache) == nil)
end

print('Leaderboard intervals: SDK precision, shared crossings, replay interpolation, finish freeze, '
  .. 'seeks, restarts, reconnects, disposal, continuous history and speed fallback passed')
