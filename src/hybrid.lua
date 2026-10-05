local U = require('src/utils')
local M = {}

local function finite(value)
  return type(value) == 'number' and value == value and math.abs(value) < math.huge
end

-- Battery charge rate is a separate fallback, in percentage points/second.
-- kersMaxKJ is a lap allowance, not a reliable battery capacity: do not use it
-- to fabricate regenerative kW when the wheel channel omits recovery torque.
local function updateChargeRate(h, car, dt)
  local sim = ac.getSim and ac.getSim() or nil
  local reset = U.read(car, 'resetCounter', nil)
  local session = U.read(sim, 'currentSessionIndex', nil)
  local time = U.read(sim, 'time', nil)
  local valid = h.charge ~= nil and dt > 0 and dt <= 0.25
    and U.read(car, 'index', 0) == 0 and not U.read(sim, 'isReplayActive', false)
    and h.sampleReset == reset and h.sampleSession == session
    and not (finite(time) and finite(h.sampleTime) and time < h.sampleTime)
  if not valid or h.sampleCharge == nil or math.abs(h.charge - h.sampleCharge) > 0.05 then
    h.sampleCharge, h.sampleElapsed, h.chargeRecoveryRate = h.charge, 0, nil
  else
    h.sampleElapsed = h.sampleElapsed + dt
    if h.sampleElapsed >= 0.1 then
      local rise = h.charge - h.sampleCharge
      h.chargeRecoveryRate = rise > 0.000001 and rise * 100 / h.sampleElapsed or nil
      h.sampleCharge, h.sampleElapsed = h.charge, 0
    end
  end
  h.sampleReset, h.sampleSession, h.sampleTime = reset, session, time
end

-- Power is mechanical electric power at the wheels, never a battery charge
-- derivative (which also contains losses and simultaneous energy recovery).
function M.update(state, car, dt, physics)
  dt = math.max(dt or 0, 0)
  local index = U.read(car, 'index', 0)
  local id = ac.getCarID and ac.getCarID(index) or index
  local present = U.read(car, 'kersPresent', false) == true
    or (U.number(U.read(car, 'kersMaxKJ', nil), 0) > 0)
    or U.read(car, 'hasCockpitERSDelivery', false) == true
  if not present then state.hybrid = nil; return end
  local previous = state.hybrid
  local h = previous and previous.id == id and previous or { id = id, maximumKw = 50, recoveryKw = 50 }
  state.hybrid = h
  local charge = U.read(car, 'kersCharge', nil)
  h.charge = finite(charge) and U.clamp(charge, 0, 1) or nil
  h.charging = U.read(car, 'kersCharging', false) == true
  updateChargeRate(h, car, dt)
  h.powerKw, h.delivery = nil, nil

  if physics == nil and ac.getCarPhysics and U.read(car, 'physicsAvailable', true) ~= false then
    local ok, result = pcall(ac.getCarPhysics, index)
    if ok then physics = result end
  end
  local physicsWheels = U.read(physics, 'wheels', nil)
  local wheels = U.read(car, 'wheels', nil)
  if physicsWheels and wheels and U.read(physics, 'isAvailable', false)
      and U.read(car, 'physicsAvailable', true) ~= false then
    local total, complete, populated = 0, true, false
    for i = 0, 3 do
      local torque = U.read(U.read(physicsWheels, i, nil), 'electricTorque', nil)
      local speed = U.read(U.read(wheels, i, nil), 'angularSpeed', nil)
      if not finite(torque) or not finite(speed) then complete = false; break end
      populated = populated or math.abs(torque) > 0.001
      total = total + torque * speed / 1000
    end
    -- Some mods leave the entire electric-torque channel at zero. Establish
    -- that it is populated before presenting those zeros as measured kW.
    if complete and (populated or h.measuredTorque) then
      h.measuredTorque = true
      h.powerKw = total
      h.maximumKw = math.max(h.maximumKw, math.ceil(math.max(total, 0) / 50) * 50)
      h.recoveryKw = math.max(h.recoveryKw, math.ceil(math.max(-total, 0) / 50) * 50)
    end
  end
  local input = U.read(car, 'kersInput', nil)
  if h.powerKw == nil and finite(input) then h.delivery = U.clamp(input, 0, 1) end
  local target = h.powerKw and h.powerKw / (h.powerKw < 0 and h.recoveryKw or h.maximumKw)
    or h.delivery
  h.batteryRecovery = (h.charging or h.chargeRecoveryRate ~= nil)
    and (h.powerKw == nil or h.powerKw == 0
      or (h.powerKw > 0 and U.number(U.read(car, 'brake', nil), 0) > 0.01))
  if h.batteryRecovery then
    h.maximumRecoveryRate = math.max(h.maximumRecoveryRate or 1, h.chargeRecoveryRate or 0)
    target = h.chargeRecoveryRate and -math.max(0.125, h.chargeRecoveryRate / h.maximumRecoveryRate) or -0.125
  end
  if target == nil then h.needle = nil
  elseif h.needle == nil or dt <= 0 or target == 0 or h.needle * target < 0 then h.needle = target
  else h.needle = h.needle + (target - h.needle) * (1 - math.exp(-math.min(dt, 0.1) / 0.07)) end
end

function M.forGauge(state, mode)
  if state.available == false or not state.hybrid then return nil end
  if mode == 'electric' or mode == nil or mode == 'auto' then
    return state.hybrid
  end
  return nil
end

return M
