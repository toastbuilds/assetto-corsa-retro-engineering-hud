package.path = './?.lua;' .. package.path
local Sectors = require('modules/leaderboard/src/sectors')
local passed = 0

local function equal(actual, expected, message)
  assert(actual == expected, (message or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end

local function row(index, values)
  local out = {index = index, driver = 'Driver ' .. index, carID = 'car-' .. index,
    classID = 'GT3', lapCount = 0, currentSector = 0, connected = true, sectorCount = 3}
  for key, value in pairs(values or {}) do out[key] = value end
  return out
end

local function seeded(index, class, times)
  return row(index, {classID = class, lapCount = 1, bestLapSplits = times,
    bestLapTimeMs = times[1] + times[2] + times[3]})
end

local function roles(r, expected)
  equal(#r.sectors, #expected, 'actual sector indicators')
  local active = 0
  for s = 1, #expected do
    equal(r.sectors[s].role, expected[s], 'sector ' .. s)
    equal(type(r.sectors[s].active), 'boolean', 'active flag')
    if r.sectors[s].active then active = active + 1 end
  end
  if type(r.currentSector) == 'number' and r.currentSector >= 0 and r.currentSector < #expected
      and r.currentSector == math.floor(r.currentSector) then
    equal(active, 1, 'one active sector')
    equal(r.sectors[r.currentSector + 1].active, true, 'SDK sector is zero-based')
  else
    equal(active, 0, 'bad sector has no active indicator')
  end
end

local function pb(state, index, expected)
  for s = 1, 3 do equal(state.cars[index].pb[s], expected[s], 'PB sector ' .. s) end
end

local function test(name, run)
  local ok, err = pcall(run)
  assert(ok, name .. ': ' .. tostring(err))
  passed = passed + 1
end

test('default General, three neutral indicators and reset', function()
  local state, r = Sectors.new(), row(0)
  Sectors.update(state, {})
  Sectors.update(state, {r})
  equal(r.sectorReferenceLabel, 'GENERAL')
  roles(r, {'NEUTRAL', 'NEUTRAL', 'NEUTRAL'})
  Sectors.reset(state)
  equal(next(state.cars), nil)
end)

test('purple reference best, green own PB, amber slower; ties', function()
  local state = Sectors.new()
  local fastest = seeded(0, 'GT3', {10000, 20000, 30000})
  local r = seeded(1, 'GT3', {12000, 24000, 36000})
  r.lastSplits, r.isLastLapValid = {10000, 23000, 37000}, true
  Sectors.update(state, {r, fastest}, {})
  roles(r, {'PURPLE', 'GREEN', 'AMBER'})
  pb(state, 1, {10000, 23000, 36000})
  r.currentSector, r.currentLapValid, r.currentSplits = 2, true, {10000, 23000}
  Sectors.update(state, {fastest, r}, {})
  roles(r, {'PURPLE', 'GREEN', 'AMBER'})
end)

test('live improvements never enter PB until a complete valid lap', function()
  local state, r = Sectors.new(), seeded(0, 'GT3', {12000, 24000, 36000})
  r.currentSector, r.currentLapValid, r.currentSplits = 2, true, {9000, 19000}
  Sectors.update(state, {r})
  roles(r, {'PURPLE', 'PURPLE', 'NEUTRAL'})
  pb(state, 0, {12000, 24000, 36000})
  r.lapCount, r.currentSector = 2, 0
  r.lastSplits, r.isLastLapValid = {9000, 19000, 29000}, true
  Sectors.update(state, {r})
  pb(state, 0, {9000, 19000, 29000})
  roles(r, {'PURPLE', 'PURPLE', 'PURPLE'})
end)

test('first valid sectors bootstrap purple but unknown sectors stay neutral', function()
  local state, r = Sectors.new(), row(0, {currentSector = 1, currentSplits = {15000}})
  Sectors.update(state, {r})
  roles(r, {'NEUTRAL', 'NEUTRAL', 'NEUTRAL'})
  r.currentLapValid = true
  Sectors.update(state, {r})
  roles(r, {'PURPLE', 'NEUTRAL', 'NEUTRAL'})
  pb(state, 0, {})
end)

test('General/Class switch recolors current AND retained completed results', function()
  local state = Sectors.new()
  local other = seeded(0, 'GT3', {10000, 20000, 30000})
  local r = seeded(1, 'GT4', {15000, 25000, 35000})
  r.lastSplits, r.isLastLapValid = {15000, 25000, 35000}, true
  Sectors.update(state, {r, other}, {})
  roles(r, {'GREEN', 'GREEN', 'GREEN'})
  Sectors.update(state, {r, other}, {sectorReference = 'Class'})
  equal(r.sectorReferenceLabel, 'GT4')
  roles(r, {'PURPLE', 'PURPLE', 'PURPLE'})
  r.currentSector, r.currentSplits, r.currentLapValid = 1, {15000}, true
  Sectors.update(state, {r, other}, {sectorReference = 'General'})
  equal(r.sectorReferenceLabel, 'GENERAL')
  roles(r, {'GREEN', 'GREEN', 'GREEN'})
end)

test('unknown classes use labelled General and contribute to General records', function()
  for _, unknown in ipairs({'UNKNOWN', '', ' unknown ', false}) do
    local state = Sectors.new()
    local fastest = seeded(0, unknown, {10000, 20000, 30000})
    local r = seeded(1, 'GT4', {15000, 25000, 35000})
    r.currentSector, r.currentSplits, r.currentLapValid = 1, {14000}, true
    Sectors.update(state, {r, fastest}, {})
    equal(r.sectors[1].role, 'GREEN')
    fastest.currentSector, fastest.currentSplits, fastest.currentLapValid = 1, {11000}, true
    Sectors.update(state, {r, fastest}, {sectorReference = 'Class'})
    equal(fastest.sectorReferenceLabel, 'GENERAL (UNKNOWN CLASS)')
    equal(fastest.sectors[1].role, 'AMBER')
  end
  local state, r = Sectors.new(), row(0)
  r.classID = nil
  Sectors.update(state, {r}, {sectorReference = 'Class'})
  equal(r.sectorReferenceLabel, 'GENERAL (UNKNOWN CLASS)')
end)

test('unknown live split never inherits a completed lap color or time', function()
  local state = Sectors.new()
  local r = row(0, {lapCount = 1, lastSplits = {10000, 20000, 30000}, isLastLapValid = true})
  Sectors.update(state, {r})
  roles(r, {'PURPLE', 'PURPLE', 'PURPLE'})
  r.currentSector, r.currentSplits = 1, {11000}
  Sectors.update(state, {r})
  roles(r, {'NEUTRAL', 'PURPLE', 'PURPLE'})
  equal(r.sectors[1].timeMs, 11000)
  r.currentSplits = {0}
  Sectors.update(state, {r})
  equal(r.sectors[1].role, 'NEUTRAL')
  equal(r.sectors[1].timeMs, nil, 'missing CURRENT split cannot borrow old time')
  r.currentSplits = nil
  Sectors.update(state, {r})
  equal(r.sectors[1].timeMs, nil)
end)

test('live true to unknown becomes neutral even after colored samples', function()
  local state, r = Sectors.new(), seeded(0, 'GT3', {10000, 20000, 30000})
  r.currentSector, r.currentSplits, r.currentLapValid = 1, {9000}, true
  Sectors.update(state, {r})
  equal(r.sectors[1].role, 'PURPLE')
  r.currentLapValid = nil
  Sectors.update(state, {r})
  equal(r.sectors[1].role, 'NEUTRAL')
  pb(state, 0, {10000, 20000, 30000})
end)

test('unknown completed lap waits for confirmation and copies mutable arrays', function()
  local state, r = Sectors.new(), row(0, {currentSector = 2, currentSplits = {9000, 19000}})
  Sectors.update(state, {r})
  local last = {9000, 19000, 29000}
  r.lapCount, r.currentSector, r.lastSplits = 1, 0, last
  Sectors.update(state, {r})
  roles(r, {'NEUTRAL', 'NEUTRAL', 'NEUTRAL'})
  pb(state, 0, {})
  last[1], r.lastSplits = 1, nil
  r.isLastLapValid = true
  Sectors.update(state, {r})
  roles(r, {'PURPLE', 'PURPLE', 'PURPLE'})
  equal(r.sectors[1].timeMs, 9000, 'pending lap must own its split snapshot')
  pb(state, 0, {9000, 19000, 29000})
end)

test('incomplete valid lap waits for all three splits before any PB commit', function()
  local state = Sectors.new()
  local r = row(0, {lapCount = 1, isLastLapValid = true, lastSplits = {9000, 19000, 0}})
  Sectors.update(state, {r})
  pb(state, 0, {})
  r.lastSplits, r.isLastLapValid = {9000, 19000, 29000}, nil
  Sectors.update(state, {r})
  pb(state, 0, {9000, 19000, 29000})
  r.lastSplits[1] = 1
  Sectors.update(state, {r})
  equal(r.sectors[1].timeMs, 9000, 'confirmed lap is immutable')
  pb(state, 0, {9000, 19000, 29000})
end)

test('same-sector true to false marks only the affected sector and excludes WHOLE lap', function()
  local state, r = Sectors.new(), seeded(0, 'GT3', {10000, 20000, 30000})
  r.currentSector, r.currentSplits, r.currentLapValid = 1, {9000}, true
  Sectors.update(state, {r})
  r.currentLapValid = false
  Sectors.update(state, {r})
  roles(r, {'PURPLE', 'RED', 'NEUTRAL'})
  r.currentSector, r.currentSplits = 2, {9000, 19000}
  Sectors.update(state, {r})
  roles(r, {'PURPLE', 'RED', 'NEUTRAL'})
  r.lapCount, r.currentSector, r.currentLapValid = 2, 0, true
  r.lastSplits, r.isLastLapValid = {9000, 19000, 29000}, false
  Sectors.update(state, {r})
  roles(r, {'PURPLE', 'RED', 'PURPLE'})
  pb(state, 0, {10000, 20000, 30000})
end)

test('observed invalidation overrides a contradictory true last-lap flag', function()
  local state, r = Sectors.new(), row(0, {currentSector = 2, currentLapValid = false})
  Sectors.update(state, {r})
  r.currentLapValid = true
  Sectors.update(state, {r})
  roles(r, {'RED', 'RED', 'RED'})
  r.lapCount, r.currentSector = 1, 0
  r.lastSplits, r.isLastLapValid = {9000, 19000, 29000}, true
  Sectors.update(state, {r})
  roles(r, {'RED', 'RED', 'RED'})
  pb(state, 0, {})
end)

test('ambiguous invalidation: initial false, sector jump, unknown gap', function()
  for _, mode in ipairs({'initial', 'jump', 'unknown', 'missing-sector'}) do
    local state, r = Sectors.new(), row(0, {currentSector = 0, currentLapValid = true})
    if mode ~= 'initial' then Sectors.update(state, {r}) end
    if mode == 'jump' then r.currentSector = 2 end
    if mode == 'unknown' then
      r.currentLapValid = nil
      Sectors.update(state, {r})
    elseif mode == 'missing-sector' then
      r.currentSector = nil
      Sectors.update(state, {r})
      r.currentSector = 0
    end
    r.currentLapValid = false
    Sectors.update(state, {r})
    roles(r, {'RED', 'RED', 'RED'})
    r.lapCount, r.currentSector, r.currentLapValid = 1, 0, nil
    r.lastSplits, r.isLastLapValid = {9000, 19000, 29000}, false
    Sectors.update(state, {r})
    roles(r, {'RED', 'RED', 'RED'})
    pb(state, 0, {})
  end
end)

test('remote validity unknown until last-lap invalid flag; all red', function()
  local state, r = Sectors.new(), row(1, {currentSector = 2, currentSplits = {9000, 19000}})
  Sectors.update(state, {r})
  roles(r, {'NEUTRAL', 'NEUTRAL', 'NEUTRAL'})
  r.lapCount, r.currentSector, r.lastSplits = 1, 0, {9000, 19000, 29000}
  Sectors.update(state, {r})
  roles(r, {'NEUTRAL', 'NEUTRAL', 'NEUTRAL'})
  r.isLastLapValid = false
  Sectors.update(state, {r})
  roles(r, {'RED', 'RED', 'RED'})
  pb(state, 1, {})
end)

test('last-lap invalidity cannot bleed into new valid current-lap slots', function()
  local state = Sectors.new()
  local r = row(0, {lapCount = 1, lastSplits = {9000, 19000, 29000}, isLastLapValid = false})
  Sectors.update(state, {r})
  roles(r, {'RED', 'RED', 'RED'})
  r.currentSector, r.currentSplits, r.currentLapValid = 1, {10000}, true
  Sectors.update(state, {r})
  roles(r, {'PURPLE', 'RED', 'RED'})
  pb(state, 0, {})
end)

test('lap zero ignores SDK default last-lap validity and stale lastSplits', function()
  local state = Sectors.new()
  local r = row(0, {lastSplits = {9000, 19000, 29000}, isLastLapValid = false})
  Sectors.update(state, {r})
  roles(r, {'NEUTRAL', 'NEUTRAL', 'NEUTRAL'})
  r.isLastLapValid = true
  Sectors.update(state, {r})
  pb(state, 0, {})
end)

test('never consume SDK unrestricted bestSplits or incomplete bestLapSplits', function()
  local state = Sectors.new()
  local r = row(0, {bestSplits = {1, 2, 3}, bestLapSplits = {10000, 20000, 0}, bestLapTimeMs = 60000})
  Sectors.update(state, {r})
  pb(state, 0, {})
  r.bestLapSplits = {1, 2, 3}
  Sectors.update(state, {r})
  pb(state, 0, {})
  r.bestLapSplits = {10000, 20000, 30000}
  Sectors.update(state, {r})
  pb(state, 0, {10000, 20000, 30000})
end)

test('optional last-lap time rejects stale splits until matching data arrives', function()
  local state = Sectors.new()
  local r = row(0, {lapCount = 1, isLastLapValid = true,
    lastSplits = {10000, 20000, 30000}, lastLapTimeMs = 57000})
  Sectors.update(state, {r})
  pb(state, 0, {})
  r.lastSplits = {9000, 19000, 29000}
  Sectors.update(state, {r})
  pb(state, 0, {9000, 19000, 29000})
end)

test('pending unconfirmed lap cannot be confirmed with the next laps flag', function()
  local state, r = Sectors.new(), row(0, {lapCount = 1, lastSplits = {1000, 2000, 3000}})
  Sectors.update(state, {r})
  pb(state, 0, {})
  r.lapCount, r.lastSplits, r.isLastLapValid = 2, {10000, 20000, 30000}, true
  Sectors.update(state, {r})
  pb(state, 0, {10000, 20000, 30000})
end)

test('lap jumps do not transfer unrelated invalidation to latest completed lap', function()
  local state, r = Sectors.new(), row(0, {currentLapValid = false})
  Sectors.update(state, {r})
  r.lapCount, r.currentLapValid = 3, nil
  r.lastSplits, r.isLastLapValid = {10000, 20000, 30000}, true
  Sectors.update(state, {r})
  roles(r, {'PURPLE', 'PURPLE', 'PURPLE'})
  pb(state, 0, {10000, 20000, 30000})
end)

test('lap rewind resets PB and removes old references before rendering any row', function()
  local state = Sectors.new()
  local fast = seeded(0, 'GT3', {10000, 20000, 30000})
  local r = seeded(1, 'GT3', {12000, 24000, 36000})
  Sectors.update(state, {r, fast})
  fast.lapCount, fast.bestLapSplits, fast.bestLapTimeMs = 0, nil, nil
  r.currentSector, r.currentSplits, r.currentLapValid = 1, {11000}, true
  Sectors.update(state, {r, fast})
  equal(r.sectors[1].role, 'PURPLE')
  pb(state, 0, {})
end)

test('driver/car replacement and reconnect reset identity without string collisions', function()
  for _, mode in ipairs({'driver', 'car', 'signal', 'connection'}) do
    local state, r = Sectors.new(), seeded(0, 'GT3', {10000, 20000, 30000})
    Sectors.update(state, {r})
    r.bestLapSplits, r.bestLapTimeMs = nil, nil
    if mode == 'driver' then r.driver = 'Replacement'
    elseif mode == 'car' then r.carID = 'replacement'
    elseif mode == 'signal' then r.reconnected = true
    else
      r.connected = false
      Sectors.update(state, {r})
      r.connected = true
    end
    Sectors.update(state, {r})
    pb(state, 0, {})
  end
  local state, r = Sectors.new(), seeded(0, 'GT3', {10000, 20000, 30000})
  r.driver, r.carID = 'a/b', 'c'
  Sectors.update(state, {r})
  r.driver, r.carID, r.bestLapSplits, r.bestLapTimeMs = 'a', 'b/c', nil, nil
  Sectors.update(state, {r})
  pb(state, 0, {})
end)

test('changing class rebuilds class references immediately', function()
  local state = Sectors.new()
  local fast = seeded(0, 'GT3', {10000, 20000, 30000})
  local r = seeded(1, 'GT4', {15000, 25000, 35000})
  r.currentSector, r.currentSplits, r.currentLapValid = 1, {14000}, true
  Sectors.update(state, {r, fast}, {sectorReference = 'Class'})
  equal(r.sectors[1].role, 'PURPLE')
  fast.classID = 'GT4'
  Sectors.update(state, {r, fast}, {sectorReference = 'Class'})
  equal(r.sectors[1].role, 'GREEN')
end)

test('simultaneous completed laps produce identical colors in either row order', function()
  for _, reverse in ipairs({false, true}) do
    local state = Sectors.new()
    local fast = row(0, {lapCount = 1, isLastLapValid = true, lastSplits = {10000, 20000, 30000}})
    local slow = row(1, {lapCount = 1, isLastLapValid = true, lastSplits = {11000, 21000, 31000}})
    Sectors.update(state, reverse and {slow, fast} or {fast, slow})
    roles(fast, {'PURPLE', 'PURPLE', 'PURPLE'})
    roles(slow, {'GREEN', 'GREEN', 'GREEN'})
  end
end)

test('malformed times and validity never enter PB or invent known validity', function()
  for _, bad in ipairs({0, -1, math.huge, -math.huge, 0/0, 'bad', false}) do
    local state = Sectors.new()
    local r = row(0, {lapCount = 1, isLastLapValid = true, lastSplits = {bad, 20000, 30000},
      bestLapSplits = {10000, bad, 30000}, currentSector = 1, currentSplits = {bad}, currentLapValid = true})
    Sectors.update(state, {r})
    equal(r.sectors[1].timeMs, nil)
    equal(r.sectors[1].role, 'NEUTRAL')
    pb(state, 0, {})
  end
  for _, bad in ipairs({0, 1, 'true', 'false'}) do
    local state = Sectors.new()
    local r = row(0, {lapCount = 1, currentSector = 1, currentSplits = {10000},
      currentLapValid = bad, isLastLapValid = bad, lastSplits = {10000, 20000, 30000}})
    Sectors.update(state, {r})
    roles(r, {'NEUTRAL', 'NEUTRAL', 'NEUTRAL'})
    pb(state, 0, {})
  end
end)

test('malformed lap/sector samples stay neutral and cannot commit a lap', function()
  for _, bad in ipairs({-1, 0.5, math.huge, 0/0, 'bad'}) do
    local state = Sectors.new()
    local r = row(0, {lapCount = bad, currentSector = 1, currentSplits = {10000}, currentLapValid = true,
      lastSplits = {10000, 20000, 30000}, isLastLapValid = true})
    Sectors.update(state, {r})
    roles(r, {'NEUTRAL', 'NEUTRAL', 'NEUTRAL'})
    pb(state, 0, {})
    r.lapCount, r.currentSector = 1, bad
    Sectors.update(state, {r})
    roles(r, {'NEUTRAL', 'NEUTRAL', 'NEUTRAL'})
    pb(state, 0, {})
  end
end)

test('Touristenfahrten one-sector valid and invalid laps have exactly one indicator', function()
  local state = Sectors.new()
  local r = row(0, {sectorCount = 1, currentSplits = {0}, currentLapValid = true})
  Sectors.update(state, {r})
  roles(r, {'NEUTRAL'})
  r.lapCount, r.lastSplits, r.lastLapTimeMs, r.isLastLapValid = 1, {90000}, 90000, true
  Sectors.update(state, {r})
  roles(r, {'PURPLE'})
  pb(state, 0, {90000})
  r.currentLapValid = false
  Sectors.update(state, {r})
  roles(r, {'RED'})
  r.lapCount, r.lastSplits, r.lastLapTimeMs, r.isLastLapValid = 2, {85000}, 85000, false
  r.currentLapValid = nil
  Sectors.update(state, {r})
  roles(r, {'RED'})
  pb(state, 0, {90000})
end)

test('one-sector remote validity remains unknown until completed confirmation', function()
  local state = Sectors.new()
  local r = row(1, {sectorCount = 1, currentSplits = {0}})
  Sectors.update(state, {r})
  roles(r, {'NEUTRAL'})
  r.lapCount, r.lastSplits = 1, {90000}
  Sectors.update(state, {r})
  roles(r, {'NEUTRAL'})
  pb(state, 1, {})
  r.isLastLapValid = true
  Sectors.update(state, {r})
  roles(r, {'PURPLE'})
  pb(state, 1, {90000})
end)

test('two-sector practice supports independent PBs and active second sector', function()
  local state = Sectors.new()
  local fast = row(0, {sectorCount = 2, bestLapSplits = {10000, 20000}, bestLapTimeMs = 30000})
  local r = row(1, {sectorCount = 2, lapCount = 1, lastSplits = {12000, 22000}, isLastLapValid = true})
  Sectors.update(state, {r, fast})
  roles(r, {'GREEN', 'GREEN'})
  pb(state, 1, {12000, 22000})
  r.currentSector, r.currentSplits, r.currentLapValid = 1, {11000, 0}, true
  Sectors.update(state, {r, fast})
  roles(r, {'GREEN', 'GREEN'})
  pb(state, 1, {12000, 22000})
end)

test('fallback count uses zero-filled array LENGTH, never positive time count', function()
  for _, count in ipairs({1, 2, 3}) do
    local zeros = {}
    for s = 1, count do zeros[s] = 0 end
    local state, r = Sectors.new(), row(0, {currentSplits = zeros})
    r.sectorCount = nil
    Sectors.update(state, {r})
    equal(#r.sectors, count)
    equal(r.sectors[1].active, true)
    pb(state, 0, {})
  end
  local state, r = Sectors.new(), row(0, {currentSplits = {0}, lastSplits = {0, 0}, bestLapSplits = {0, 0, 0}})
  r.sectorCount = nil
  Sectors.update(state, {r})
  roles(r, {'NEUTRAL', 'NEUTRAL', 'NEUTRAL'})
end)

test('authoritative one-sector count overrides stale three-slot arrays', function()
  local state = Sectors.new()
  local r = row(0, {sectorCount = 1, lapCount = 1, currentSplits = {0, 0, 0},
    lastSplits = {90000, 0, 0}, lastLapTimeMs = 90000, isLastLapValid = true})
  Sectors.update(state, {r})
  roles(r, {'PURPLE'})
  pb(state, 0, {90000})
  r.currentSector = 1
  Sectors.update(state, {r})
  roles(r, {'NEUTRAL'})
end)

test('known affected sector stays red while completed validity is still pending', function()
  local state, r = Sectors.new(), seeded(0, 'GT3', {10000, 20000, 30000})
  r.currentSector, r.currentLapValid = 1, true
  Sectors.update(state, {r})
  r.currentLapValid = false
  Sectors.update(state, {r})
  r.lapCount, r.currentSector, r.currentLapValid = 2, 0, nil
  r.lastSplits, r.isLastLapValid = {9000, 19000, 29000}, nil
  Sectors.update(state, {r})
  roles(r, {'NEUTRAL', 'RED', 'NEUTRAL'})
  pb(state, 0, {10000, 20000, 30000})
  r.isLastLapValid = true
  Sectors.update(state, {r})
  roles(r, {'PURPLE', 'RED', 'PURPLE'})
  pb(state, 0, {10000, 20000, 30000})
end)

test('invalid sectors cannot contaminate other drivers General or Class references', function()
  for _, mode in ipairs({'General', 'Class'}) do
    local state = Sectors.new()
    local invalid = row(0, {lapCount = 1, lastSplits = {1000, 2000, 3000}, isLastLapValid = false})
    local r = seeded(1, 'GT3', {12000, 24000, 36000})
    r.currentSector, r.currentSplits, r.currentLapValid = 1, {11000}, true
    Sectors.update(state, {r, invalid}, {sectorReference = mode})
    equal(r.sectors[1].role, 'PURPLE')
    pb(state, 0, {})
  end
end)

test('two-sector seeds and completed laps require both actual sectors', function()
  local state = Sectors.new()
  local r = row(0, {sectorCount = 2, lapCount = 1, bestLapSplits = {9000, 0},
    lastSplits = {10000, 0}, isLastLapValid = true})
  Sectors.update(state, {r})
  pb(state, 0, {})
  r.bestLapSplits = {9000, 21000}
  Sectors.update(state, {r})
  pb(state, 0, {9000, 21000})
  r.lastSplits = {10000, 20000}
  Sectors.update(state, {r})
  pb(state, 0, {9000, 20000})
  roles(r, {'AMBER', 'PURPLE'})
end)

test('same-lap sector rewind makes invalidation ambiguous but cannot erase it', function()
  local state, r = Sectors.new(), row(0, {currentSector = 2, currentLapValid = true})
  Sectors.update(state, {r})
  r.currentLapValid = false
  Sectors.update(state, {r})
  roles(r, {'NEUTRAL', 'NEUTRAL', 'RED'})
  r.currentSector, r.currentLapValid = 0, true
  Sectors.update(state, {r})
  roles(r, {'RED', 'RED', 'RED'})
  r.lapCount, r.lastSplits, r.isLastLapValid = 1, {9000, 19000, 29000}, true
  Sectors.update(state, {r})
  pb(state, 0, {})
end)

test('no count evidence or explicit zero hides indicators instead of inventing three', function()
  local state, r = Sectors.new(), row(0)
  r.sectorCount = nil
  Sectors.update(state, {r})
  roles(r, {})
  r.sectorCount, r.currentSplits, r.lastSplits = 0, {0, 0, 0}, {10000, 20000, 30000}
  r.lapCount, r.isLastLapValid = 1, true
  Sectors.update(state, {r})
  roles(r, {})
  pb(state, 0, {})
  for _, bad in ipairs({-1, 0.5, math.huge, 0/0, 'bad', false}) do
    r.sectorCount = bad
    Sectors.update(state, {r})
    roles(r, {})
    pb(state, 0, {})
  end
end)

test('sector count change resets incompatible records and caps display at three', function()
  local state, r = Sectors.new(), seeded(0, 'GT3', {10000, 20000, 30000})
  Sectors.update(state, {r})
  r.sectorCount, r.bestLapSplits, r.bestLapTimeMs = 1, nil, nil
  Sectors.update(state, {r})
  roles(r, {'NEUTRAL'})
  pb(state, 0, {})
  r.sectorCount, r.currentSplits = 4, {0, 0, 0, 0}
  Sectors.update(state, {r})
  roles(r, {'NEUTRAL', 'NEUTRAL', 'NEUTRAL'})
end)

print('Leaderboard sectors: ' .. passed .. ' standalone regression cases passed')
