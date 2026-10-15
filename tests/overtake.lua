package.path = './?.lua;./?/init.lua;' .. package.path

ac = {SessionType = {Race = 1}, FlagType = {FasterCar = 12}}
local Tracker = require('modules/notices/src/overtake')
local tracker = Tracker.new()
local sim = {currentSessionIndex = 4, isSessionStarted = true}
local session = {type = ac.SessionType.Race}
local player = {index = 0, driver = 'PLAYER', carID = 'player', racePosition = 2,
  progress = 0, status = 'L 1', active = true, connected = true}
local rival = {index = 1, driver = 'RIVAL', carID = 'gt3_rival', carName = 'GT3 Coupe',
  classID = 'GT3', racePosition = 1, progress = 0.01, status = 'LIVE',
  active = true, connected = false, isAI = true, intervalSource = 'history'}

local function update(index, crossed, options)
  options = options or {}
  local time = index * 0.5
  local progress = index / 10
  player.progress = progress
  player.racePosition = crossed and 1 or 2
  rival.progress = progress + 0.01
  rival.racePosition = crossed and 2 or 1
  rival.intervalSeconds = crossed and -0.1 or 5 - 0.6 * progress
  if options.gap ~= nil then rival.intervalSeconds = options.gap end
  rival.intervalSource = options.estimated and 'estimated' or 'history'
  if options.status then rival.status = options.status else rival.status = 'LIVE' end
  rival.justJumped = options.justJumped == true
  rival.car = {wheelsOutside = options.wheelsOutside or 0}
  sim.raceFlagType = options.flagCause ~= nil and 2 or nil
  sim.raceFlagCause = options.flagCause
  local snapshot = {
    sim = sim, session = session, localRow = player, rows = {player, rival},
    timeline = {time = time, measuredClock = true},
    historyReset = options.historyReset == true, final = false
  }
  return Tracker.update(tracker, snapshot, true)
end

-- Build more than one lap of approach history against this exact AI rival.
for i = 0, 19 do
  assert(#update(i, false, {historyReset = i == 0}) == 0)
end
local event = update(20, true)[1]
assert(event and event.kind == 'overtake', 'An official player/rival position swap emits an event')
assert(event.driver == 'RIVAL' and event.carName == 'GT3 Coupe' and event.classID == 'GT3')
assert(event.fromPosition == 2 and event.toPosition == 1)
assert(math.abs(event.closingRate - 0.6) < 0.00001 and not event.estimated,
  'The same rival history measures positive seconds gained per lap')

-- A second pass can mark its approach estimate when interval data was estimated.
Tracker.reset(tracker)
for i = 0, 19 do
  local events = update(i, false, {historyReset = i == 0, estimated = true})
  assert(#events == 0)
end
event = update(20, true, {estimated = true})[1]
assert(event and event.estimated and math.abs(event.closingRate - 0.6) < 0.00001,
  'Estimated interval history is labelled on the event')

-- A position improvement caused by the rival pitting is not an overtake.
Tracker.reset(tracker)
update(0, false, {historyReset = true})
local skipped = update(1, true, {status = 'PIT'})
assert(#skipped == 0, 'Pit entry is not reported as a pass')

-- A changed baseline or teleport never becomes a pass notification.
Tracker.reset(tracker)
update(0, false, {historyReset = true})
assert(#update(1, true, {historyReset = true}) == 0, 'History resets re-prime without emitting')
Tracker.reset(tracker)
update(0, false, {historyReset = true})
assert(#update(1, true, {justJumped = true}) == 0, 'A teleported rival cannot generate a pass')

-- A large gap can collapse after a rival-specific incident, without a long battle.
Tracker.reset(tracker)
update(0, false, {historyReset = true, gap = 10})
update(1, false, {flagCause = 1, gap = 10})
update(2, false, {gap = 4})
event = update(3, true)[1]
assert(event and event.incident == 'yellow' and event.closingRate == nil,
  'Remember the rival yellow flag after it clears and do not describe incident gains as pace')

Tracker.reset(tracker)
for i = 0, 19 do update(i, false, {historyReset = i == 0}) end
update(20, false, {flagCause = 1})
event = update(21, true)[1]
assert(event and event.incident == 'yellow' and event.closingRate == nil,
  'A recent incident discards even a previously available multi-lap pace estimate')

for _, cause in ipairs({-1, 2}) do
  Tracker.reset(tracker)
  update(0, false, {historyReset = true})
  update(1, false, {flagCause = cause})
  event = update(2, true)[1]
  assert(event and event.incident == nil, 'Unknown or other-car yellow causes do not implicate the rival')
end

Tracker.reset(tracker)
update(0, false, {historyReset = true})
update(1, false, {wheelsOutside = 4})
update(2, false)
event = update(3, true)[1]
assert(event and event.incident == 'offtrack', 'Remember a full track exit even after the rival rejoins')

Tracker.reset(tracker)
update(0, false, {historyReset = true})
update(1, false, {wheelsOutside = 3})
event = update(2, true)[1]
assert(event and event.incident == nil, 'A partial track excursion does not count as a full track exit')

Tracker.reset(tracker)
update(0, false, {historyReset = true})
update(1, false, {flagCause = 1, wheelsOutside = 4})
update(2, false, {wheelsOutside = 4})
event = update(3, true)[1]
assert(event and event.incident == 'yellow', 'Official attribution takes priority over a track exit')

Tracker.reset(tracker)
update(0, false, {historyReset = true})
update(1, false, {flagCause = 1})
for i = 2, 41 do update(i, false) end
event = update(42, true)[1]
assert(event and event.incident == nil and event.closingRate == nil,
  'Context expires after 20 seconds and contaminated approach history cannot reappear')

Tracker.reset(tracker)
update(0, false, {historyReset = true})
update(1, false, {flagCause = 1})
update(2, false, {historyReset = true})
event = update(3, true)[1]
assert(event and event.incident == nil, 'A reset clears previous incident attribution')

Tracker.reset(tracker)
update(0, false, {historyReset = true})
update(1, false, {flagCause = 1})
rival.driver = 'NEW DRIVER'
update(2, false)
event = update(3, true)[1]
assert(event and event.incident == nil, 'Incident context cannot transfer to a new driver in the same slot')
rival.driver = 'RIVAL'

-- Race Notices formats the event, displays it for four seconds and holds it
-- behind higher-priority warnings.
local State = require('modules/notices/src/state')
local function makeRow(index, driver, carID, carName, classID, pos)
  return {index = index, driver = driver, carID = carID, carName = carName,
    classID = classID, racePosition = pos, progress = 0, status = 'LIVE',
    active = true, connected = true, intervalSeconds = 4, intervalSource = 'history'}
end

local noticeSim = {currentSessionIndex = 11, currentSessionTime = 0, isSessionStarted = true}
local noticeSession = {type = ac.SessionType.Race}
local noticePlayer = makeRow(0, 'PLAYER', 'player', 'PLAYER CAR', 'GT3', 2)
local noticeRival = makeRow(1, 'A. SATO', 'gt3_sato', 'FERRARI 296', 'GT3', 1)
local noticeCar = {lapCount = 0, resetCounter = 0}
local healthy = {available = true, body = {}, wheels = {
  {}, {}, {}, {}
}, engineDamage = 0, gearboxDamage = 0}
local noticeSettings = {
  overtakeEnabled = true, repairEnabled = false, blueEnabled = false, pitEnabled = false,
  battleEnabled = false, attackEnabled = false,
  bodyDamageThreshold = 0.2, suspensionDamageThreshold = 0.05, engineDamageThreshold = 0.2
}
local function raceSnapshot(time, playerPosition, rivalPosition, playerProgress, gap, extraRows, reset)
  noticeSim.currentSessionTime = time * 1000
  noticePlayer.racePosition, noticePlayer.progress = playerPosition, playerProgress
  noticeRival.racePosition, noticeRival.progress = rivalPosition, playerProgress + 0.01
  noticeRival.intervalSeconds = gap
  local rows = {noticePlayer, noticeRival}
  for _, row in ipairs(extraRows or {}) do rows[#rows + 1] = row end
  return {sim = noticeSim, session = noticeSession, localRow = noticePlayer, rows = rows,
    timeline = {time = time, measuredClock = true}, historyReset = reset == true, final = false}
end

local noticeState = State.new()
for i = 0, 19 do
  local progress = i / 10
  local snapshot = raceSnapshot(i * 0.5, 2, 1, progress, 5 - 0.6 * progress, nil, i == 0)
  noticeState:update(0.5, noticeCar, noticeSim, healthy, nil, noticeSettings, {}, nil, nil, snapshot)
  assert(noticeState.notice == nil)
end
local passSnapshot = raceSnapshot(10, 1, 2, 2, -0.1)
noticeState:update(0.5, noticeCar, noticeSim, healthy, nil, noticeSettings, {}, nil, nil, passSnapshot)
assert(noticeState.notice.kind == 'overtake'
  and noticeState.notice.title == 'OVERTAKE P2 > P1'
  and noticeState.notice.detail == 'A. SATO | GT3 | FERRARI 296'
  and noticeState.notice.value == '+0.6' and noticeState.notice.label == 'S/LAP',
  'The Race Notices summary carries identity, official place change and same-rival pace')
for i = 1, 7 do
  local snapshot = raceSnapshot(10 + i * 0.5, 1, 2, 2, -0.1)
  noticeState:update(0.5, noticeCar, noticeSim, healthy, nil, noticeSettings, {}, nil, nil, snapshot)
  assert(noticeState.notice.kind == 'overtake', 'The overtake summary remains visible for four seconds')
end
local afterDuration = raceSnapshot(14, 1, 2, 2, -0.1)
noticeState:update(0.5, noticeCar, noticeSim, healthy, nil, noticeSettings, {}, nil, nil, afterDuration)
assert(noticeState.notice == nil, 'The overtake summary expires after four visible seconds')

-- Incident context survives the event formatter and replaces the pace readout.
for _, kind in ipairs({'yellow', 'offtrack'}) do
  local incidentState = State.new()
  for i = 0, 3 do
    noticeSim.raceFlagType = kind == 'yellow' and i == 1 and 2 or nil
    noticeSim.raceFlagCause = 1
    noticeRival.car = {wheelsOutside = kind == 'offtrack' and i == 1 and 4 or 0}
    local snapshot = raceSnapshot(i * 0.5, i == 3 and 1 or 2, i == 3 and 2 or 1,
      i / 10, i == 3 and -0.1 or 10 - i * 3, nil, i == 0)
    incidentState:update(0.5, noticeCar, noticeSim, healthy, nil, noticeSettings, {}, nil, nil, snapshot)
  end
  assert(incidentState.notice.incident == kind
    and incidentState.notice.value == (kind == 'yellow' and 'YELLOW' or 'OFF TRACK')
    and incidentState.notice.label == (kind == 'yellow' and 'RIVAL FLAG' or 'TRACK EXIT'),
    'Summaries show the observed incident context instead of seconds per lap')
end
noticeSim.raceFlagType, noticeSim.raceFlagCause = nil, nil
noticeRival.car = nil

-- Keep four distinct passes behind a blue flag: the bounded FIFO drops the
-- oldest and presents the remaining events in order when the flag clears.
local queueState = State.new()
local queueSim = {currentSessionIndex = 12, currentSessionTime = 0,
  isSessionStarted = true, raceFlagType = 12, raceFlagCause = -1}
local queuePlayer = makeRow(0, 'PLAYER', 'player', 'PLAYER CAR', 'GT3', 5)
local queueRows = {queuePlayer}
local opponentNames = {'ONE', 'TWO', 'THREE', 'FOUR'}
for i = 1, 4 do
  local opponent = makeRow(i, opponentNames[i], 'car_' .. i, 'CAR ' .. i, 'GT3', i)
  if i == 1 then opponent.isAI, opponent.connected = true, false end
  queueRows[#queueRows + 1] = opponent
end
local queueCar = {lapCount = 0, resetCounter = 0}
local queueSettings = {
  overtakeEnabled = true, repairEnabled = false, blueEnabled = true, pitEnabled = false,
  battleEnabled = false, attackEnabled = false,
  bodyDamageThreshold = 0.2, suspensionDamageThreshold = 0.05, engineDamageThreshold = 0.2
}
local positions = {[0] = 5, [1] = 1, [2] = 2, [3] = 3, [4] = 4}
local function queueSnapshot(time, reset)
  queueSim.currentSessionTime = time * 1000
  queuePlayer.racePosition, queuePlayer.progress = positions[0], time / 10
  for i = 1, 4 do
    queueRows[i + 1].racePosition = positions[i]
    queueRows[i + 1].progress = queuePlayer.progress + i / 100
    queueRows[i + 1].intervalSeconds = positions[i] < positions[0] and 2 or -0.2
  end
  return {sim = queueSim, session = noticeSession, localRow = queuePlayer, rows = queueRows,
    timeline = {time = time, measuredClock = true}, historyReset = reset == true, final = false}
end
local queueTime = 0
local queueInitial = queueSnapshot(queueTime, true)
queueState:update(0.1, queueCar, queueSim, healthy, nil, queueSettings, {}, nil, nil, queueInitial)
assert(queueState.notice.kind == 'blue')
for _, rivalPosition in ipairs({4, 3, 2, 1}) do
  local oldPlayerPosition = positions[0]
  positions[0] = oldPlayerPosition - 1
  positions[rivalPosition] = oldPlayerPosition
  queueTime = queueTime + 0.1
  local snapshot = queueSnapshot(queueTime)
  queueState:update(0.1, queueCar, queueSim, healthy, nil, queueSettings, {}, nil, nil, snapshot)
  assert(queueState.notice.kind == 'blue', 'Blue flags keep priority over queued passes')
end
assert(#queueState.overtakeQueue == 3, 'The waiting FIFO is bounded to three summaries')
queueSim.raceFlagType = nil
queueTime = queueTime + 0.5
local firstQueued = queueSnapshot(queueTime)
queueState:update(0.5, queueCar, queueSim, healthy, nil, queueSettings, {}, nil, nil, firstQueued)
assert(queueState.notice.kind == 'overtake' and queueState.notice.title == 'OVERTAKE P4 > P3',
  'FIFO discards the oldest overflow event and preserves order')

-- Pending events older than twelve seconds expire instead of surfacing stale.
local expiryState = State.new()
local expirySim = {currentSessionIndex = 13, currentSessionTime = 0,
  isSessionStarted = true, raceFlagType = 12, raceFlagCause = -1}
local expiryPlayer = makeRow(0, 'PLAYER', 'player', 'PLAYER CAR', 'GT3', 2)
local expiryRival = makeRow(1, 'RIVAL', 'rival', 'CAR', 'GT3', 1)
local expiryCar = {lapCount = 0, resetCounter = 0}
local function expirySnapshot(time, playerPosition, rivalPosition, reset)
  expirySim.currentSessionTime = time * 1000
  expiryPlayer.racePosition, expiryPlayer.progress = playerPosition, time / 10
  expiryRival.racePosition, expiryRival.progress = rivalPosition, expiryPlayer.progress + 0.01
  expiryRival.intervalSeconds = rivalPosition < playerPosition and 3 or -0.1
  return {sim = expirySim, session = noticeSession, localRow = expiryPlayer,
    rows = {expiryPlayer, expiryRival}, timeline = {time = time, measuredClock = true},
    historyReset = reset == true, final = false}
end
local expirySettings = {
  overtakeEnabled = true, repairEnabled = false, blueEnabled = true, pitEnabled = false,
  battleEnabled = false, attackEnabled = false,
  bodyDamageThreshold = 0.2, suspensionDamageThreshold = 0.05, engineDamageThreshold = 0.2
}
expiryState:update(0.1, expiryCar, expirySim, healthy, nil, expirySettings, {}, nil, nil,
  expirySnapshot(0, 2, 1, true))
expiryState:update(0.1, expiryCar, expirySim, healthy, nil, expirySettings, {}, nil, nil,
  expirySnapshot(0.1, 1, 2))
assert(#expiryState.overtakeQueue == 1)
expiryState:update(12.1, expiryCar, expirySim, healthy, nil, expirySettings, {}, nil, nil,
  expirySnapshot(12.2, 1, 2))
assert(#expiryState.overtakeQueue == 0, 'A pending summary expires after twelve seconds')
expirySim.raceFlagType = nil
expiryState:update(0.5, expiryCar, expirySim, healthy, nil, expirySettings, {}, nil, nil,
  expirySnapshot(12.7, 1, 2))
assert(expiryState.notice == nil, 'Expired summaries do not appear after an urgent notice clears')

print('Overtake: detection, same-rival pace, incident attribution/expiry, display, priority, FIFO and false-pass filters passed')
