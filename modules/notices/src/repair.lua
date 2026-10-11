local U = require('src/utils')
local M = {}

local function finite(value)
  value = tonumber(value)
  if value and value == value and math.abs(value) < math.huge then return value end
end

local function damage(value)
  return U.clamp(finite(value) or 0, 0, 1)
end

function M.damage(condition)
  local result = { body = 0, suspension = 0, engine = 0, gearbox = 0,
    front = 0, rear = 0, blown = false, available = condition and condition.available == true }
  if not result.available then return result end
  for _, side in ipairs({ 'front', 'rear', 'left', 'right' }) do
    result.body = math.max(result.body, damage(U.read(condition.body, side)))
  end
  for i = 1, 4 do
    local wheel = U.read(condition.wheels, i)
    local amount = damage(U.read(wheel, 'suspensionDamage'))
    result.suspension = math.max(result.suspension, amount)
    if i <= 2 then result.front = math.max(result.front, amount)
    else result.rear = math.max(result.rear, amount) end
    result.blown = result.blown or U.read(wheel, 'isBlown', false) == true
  end
  result.engine, result.gearbox = damage(condition.engineDamage), damage(condition.gearboxDamage)
  return result
end

function M.rates(carIndex)
  if not ac.INIConfig or not ac.INIConfig.carData then return {} end
  local ok, result = pcall(function()
    local config = ac.INIConfig.carData(carIndex or 0, 'car.ini')
    if not config then return {} end
    local rates = {}
    for key, field in pairs({ body = 'BODY_REPAIR_TIME_SEC',
        suspension = 'SUSP_REPAIR_TIME_SEC', engine = 'ENGINE_REPAIR_TIME_SEC' }) do
      local value = finite(config:get('PIT_STOP', field, -1))
      if value and value >= 0 then rates[key] = value end
    end
    return rates
  end)
  return ok and result or {}
end

-- Kunos car.ini documents each rate as seconds per 10% damage. This is an
-- approximation using the worst body zone and suspension corner, assuming
-- full repairs. Fuel, tyre changes, travel and mod-specific repair logic are excluded.
function M.estimate(amounts, rates)
  if not amounts.available then return nil end
  if amounts.gearbox > 0.001 or amounts.blown then return nil end
  local seconds = 0
  for _, key in ipairs({ 'body', 'suspension', 'engine' }) do
    if amounts[key] > 0.001 then
      if rates[key] == nil then return nil end
      seconds = seconds + amounts[key] * 10 * rates[key]
    end
  end
  return seconds
end

function M.format(seconds)
  if seconds == nil then return '--' end
  seconds = math.ceil(math.max(0, seconds))
  if seconds < 60 then return '~' .. seconds .. ' s' end
  return string.format('~%d:%02d', math.floor(seconds / 60), seconds % 60)
end

return M
