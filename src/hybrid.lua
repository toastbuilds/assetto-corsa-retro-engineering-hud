local U = require('src/utils')
local M = {}

local function finite(value)
  return type(value) == 'number' and value == value and math.abs(value) < math.huge
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
  if target == nil then h.needle = nil
  elseif h.needle == nil or dt <= 0 then h.needle = target
  else h.needle = h.needle + (target - h.needle) * (1 - math.exp(-math.min(dt, 0.1) / 0.07)) end
end

function M.forGauge(state, mode)
  if state.available == false or not state.hybrid then return nil end
  if mode == 'electric' or ((mode == nil or mode == 'auto') and not state.turboAvailable) then
    return state.hybrid
  end
  return nil
end

return M
