local M = {}

local function read(car, key)
  if not car then return nil end
  local ok, value = pcall(function() return car[key] end)
  if ok then return value end
end

local function number(value)
  value = tonumber(value)
  return value and value == value and math.abs(value) < math.huge and value or nil
end

function M.index(car)
  local index = number(read(car, 'index'))
  return index and index >= 0 and index == math.floor(index) and index or nil
end

function M.visible(car)
  local index = M.index(car)
  if index == nil or read(car, 'isHidingLabels') == true then return false end
  return read(car, 'isConnected') ~= false
end

function M.collect()
  local result, seen = {}, {}
  local function append(car)
    local index = M.index(car)
    if not M.visible(car) or seen[index] then return end
    seen[index] = true
    result[#result + 1] = car
  end
  local ok = pcall(function()
    for _, car in ac.iterateCars.leaderboard() do append(car) end
  end)
  if not ok or #result == 0 then
    pcall(function()
      for _, car in ac.iterateCars() do append(car) end
    end)
  end
  if not seen[0] then pcall(function() append(ac.getCar(0)) end) end
  return result
end

function M.player(list)
  for _, car in ipairs(list) do
    if M.index(car) == 0 then return car end
  end
  local ok, player = pcall(function() return ac.getCar(0) end)
  return ok and player or nil
end

local function racePosition(car)
  local position = number(read(car, 'racePosition'))
  return position and position >= 1 and position == math.floor(position) and position or nil
end

function M.positions(list, race)
  local ordered = {}
  for _, car in ipairs(list) do
    if M.visible(car) then ordered[#ordered + 1] = car end
  end
  if race then
    table.sort(ordered, function(a, b)
      local aPos, bPos = racePosition(a) or math.huge, racePosition(b) or math.huge
      if aPos ~= bPos then return aPos < bPos end
      local aProgress = (number(read(a, 'lapCount')) or 0) + (number(read(a, 'splinePosition')) or 0)
      local bProgress = (number(read(b, 'lapCount')) or 0) + (number(read(b, 'splinePosition')) or 0)
      if aProgress ~= bProgress then return aProgress > bProgress end
      return M.index(a) < M.index(b)
    end)
  end
  local positions = {}
  for rank, car in ipairs(ordered) do
    -- Keep official race numbers even when hidden cars leave gaps in the field.
    positions[M.index(car)] = race and racePosition(car) or rank
    if positions[M.index(car)] == nil then positions[M.index(car)] = rank end
  end
  return positions, ordered
end

function M.numbered(positions, ordered, player, numberMode)
  if numberMode == 'all' then return positions end
  local index = M.index(player)
  local playerPosition = index and positions[index] or nil
  local last = ordered[#ordered]
  local lastIndex = M.index(last)
  local selected = {}
  for carIndex, position in pairs(positions) do
    if carIndex == index or carIndex == lastIndex or position == 1
      or (playerPosition and math.abs(position - playerPosition) <= 2) then
      selected[carIndex] = position
    end
  end
  return selected
end

local function completedLaps(car)
  -- lapCount counts completed laps; spline progress must not affect lap colors.
  local laps = number(read(car, 'lapCount'))
  return laps and laps >= 0 and laps == math.floor(laps) and laps or nil
end

function M.colorRole(car, player, positions, race)
  local index = M.index(car)
  if index == 0 then return 'amber' end
  if index ~= nil and positions[index] == 1 then return 'flagPurple' end
  if race then
    local laps, playerLaps = completedLaps(car), completedLaps(player)
    if laps and playerLaps then
      if laps > playerLaps then return 'cyan' end
      if laps < playerLaps then return 'cyanDim' end
      return 'green'
    end
  end
  return 'cyan'
end

function M.offTrackPulse(car, enabled, now)
  if enabled == false or not M.visible(car) or read(car, 'isInPitlane') == true
    or number(read(car, 'wheelsOutside')) ~= 4 then return nil end
  return (1 - math.cos((number(now) or 0) * math.pi * 2 / 1.2)) / 2
end

return M
