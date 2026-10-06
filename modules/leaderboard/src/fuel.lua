local M = {}

local function number(value)
  value = tonumber(value)
  return value and value == value and value or nil
end

local function read(object, key)
  if object == nil then return nil end
  local ok, value = pcall(function() return object[key] end)
  if ok then return value end
  return nil
end

local function validFuel(fuel, maxFuel)
  if not fuel or fuel < 0 then return false end
  if maxFuel and maxFuel > 0 and maxFuel < 1000 and fuel > maxFuel + 0.25 then return false end
  return true
end

local function median(values)
  if #values == 0 then return nil end
  local sorted = {}
  for i = 1, #values do sorted[i] = values[i] end
  table.sort(sorted)
  local middle = math.floor(#sorted / 2) + 1
  if #sorted % 2 == 1 then return sorted[middle] end
  return (sorted[middle - 1] + sorted[middle]) / 2
end

local function addSample(state, used)
  if not used or used <= 0 then return end
  if #state.samples >= 5 then table.remove(state.samples, 1) end
  state.samples[#state.samples + 1] = used
  state.average = median(state.samples)
end

local function resetLapBase(state, lap, fuel)
  state.currentLap = lap
  state.fuelAtLapStart = fuel
  state.lastFuel = fuel
  state.sawRefuel = false
end

function M.new()
  return {
    sessionIndex = nil, currentLap = nil, fuelAtLapStart = nil, lastFuel = nil,
    samples = {}, average = nil, sawRefuel = false, lastValidLap = false,
    fuel = nil, maxFuel = nil, available = false, lastUsed = nil
  }
end

function M.reset(state, sessionIndex)
  state.sessionIndex = sessionIndex
  state.currentLap, state.fuelAtLapStart, state.lastFuel = nil, nil, nil
  state.samples, state.average, state.sawRefuel, state.lastUsed = {}, nil, false, nil
end

function M.update(state, snapshot, settings)
  local sim = snapshot and snapshot.sim
  local sessionIndex = number(read(sim, 'currentSessionIndex')) or 0
  if state.sessionIndex ~= sessionIndex then M.reset(state, sessionIndex) end

  local car
  pcall(function() car = ac.getCar(0) end)
  local fuel = number(read(car, 'fuel'))
  local maxFuel = number(read(car, 'maxFuel'))
  state.fuel, state.maxFuel, state.available = fuel, maxFuel, validFuel(fuel, maxFuel)
  if not state.available then
    state.fuelText, state.averageText, state.estimatedLapsText, state.finishText = 'N/A', '--', '--', '--'
    state.fuelNeeded, state.finishAvailable, state.estimatedLaps = nil, false, nil
    return state
  end

  local lap = number(read(car, 'lapCount')) or number(read(car, 'sessionLapCount'))
  local validLapFlag = read(car, 'isLastLapValid')
  local validLapTime = number(read(car, 'previousLapTimeMs'))
  local now = ui.time()
  if state.currentLap == nil or lap == nil then
    if state.currentLap == nil and lap ~= nil then resetLapBase(state, lap, fuel) end
  else
    -- A rise is a refuel event. It resets only the current measurement base;
    -- the previous valid consumption median intentionally survives.
    if state.lastFuel and fuel > state.lastFuel + 0.05 then
      resetLapBase(state, lap, fuel)
      state.sawRefuel = true
    elseif lap > state.currentLap then
      local used = state.fuelAtLapStart and state.lastFuel and state.fuelAtLapStart - state.lastFuel or nil
      local compatible = used and used > 0.01 and used <= (maxFuel and maxFuel > 0 and maxFuel or 200) + 0.25
      local valid = validLapFlag == true and compatible and (validLapTime == nil or validLapTime > 0)
      if valid then
        addSample(state, used)
        state.lastUsed = used
        state.lastValidLap = true
      end
      -- A jump means a restart/teleport or missing samples, so never infer the
      -- missing laps. Start measuring from the sample we can actually trust.
      resetLapBase(state, lap, fuel)
      state.sawRefuel = false
    elseif lap < state.currentLap then
      M.reset(state, sessionIndex)
      resetLapBase(state, lap, fuel)
    end
  end
  state.lastFuel = fuel

  state.fuelText = string.format('%.1f L', fuel)
  state.averageText = state.average and string.format('%.1f L/LAP', state.average) or '--'
  local reserve = math.max(0, number(settings.fuelReserve) or 0)
  if state.average and state.average > 0 then
    state.estimatedLaps = math.max(0, math.floor(math.max(0, fuel - reserve) / state.average))
    state.estimatedLapsText = tostring(state.estimatedLaps) .. ' LAPS'
  else
    state.estimatedLaps, state.estimatedLapsText = nil, '--'
  end

  local remaining = snapshot and snapshot.lapsRemaining
  if state.average and state.average > 0 and remaining ~= nil and remaining >= 0 then
    state.fuelNeeded = remaining * state.average + reserve
    state.finishText = string.format('%+.1f L', fuel - state.fuelNeeded)
    state.finishAvailable = true
  else
    state.fuelNeeded, state.finishText, state.finishAvailable = nil, '--', false
  end
  state.updatedAt = now
  return state
end

return M
