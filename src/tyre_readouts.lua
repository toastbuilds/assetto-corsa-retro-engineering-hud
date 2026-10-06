-- Wheel measurements stay in CSP units (psi and Celsius) until presentation.
local U = require('src/utils')
local Temperature = require('src/tyre_temperature')
local M = {}
local pressureKey, pressureCache

function M.finite(value)
  return type(value) == 'number' and value == value and math.abs(value) < math.huge
end

local function positive(value)
  return M.finite(value) and value > 0 and value or nil
end

function M.idealPressures(car)
  local index, compound = U.read(car, 'index', 0), U.read(car, 'compoundIndex', 0)
  local id = ac.getCarID and ac.getCarID(index) or index
  local key = tostring(id) .. ':' .. tostring(compound)
  if key == pressureKey then return pressureCache end
  pressureKey, pressureCache = key, {}
  if not ac.INIConfig or not ac.INIConfig.carData then return pressureCache end
  local ok, result = pcall(function()
    local config = ac.INIConfig.carData(index, 'tyres.ini')
    if not config then return {} end
    local suffix = compound > 0 and '_' .. tostring(compound) or ''
    return {
      front = positive(tonumber(config:get('FRONT' .. suffix, 'PRESSURE_IDEAL', -1))),
      rear = positive(tonumber(config:get('REAR' .. suffix, 'PRESSURE_IDEAL', -1)))
    }
  end)
  if ok then pressureCache = result end
  return pressureCache
end

function M.references(wheel, gt3, settings, front)
  settings = settings or {}
  wheel = wheel or {}
  local minimum, maximum = wheel.optimumTemperatureMin, wheel.optimumTemperatureMax
  local thermalEstimated = not (M.finite(minimum) and M.finite(maximum) and maximum >= minimum)
  if thermalEstimated then
    if gt3 then
      minimum, maximum = settings.fallbackGT3Min or 75, settings.fallbackGT3Max or 85
    elseif positive(wheel.optimumTemperature) then
      minimum, maximum = wheel.optimumTemperature - 5, wheel.optimumTemperature + 5
    else
      minimum, maximum = settings.fallbackTemperatureMin or 80, settings.fallbackTemperatureMax or 90
    end
  end
  local ideal = positive(wheel.idealPressure)
  return {
    minimum = minimum, maximum = maximum, thermalEstimated = thermalEstimated,
    idealPressure = ideal or (front and settings.fallbackPressureFront or settings.fallbackPressureRear) or 26,
    pressureEstimated = ideal == nil
  }
end

function M.pressure(value, unit)
  if not M.finite(value) then return nil end
  return unit == 'bar' and value * 0.0689475729 or unit == 'kPa' and value * 6.89475729 or value
end

function M.temperature(value, unit)
  if not M.finite(value) then return nil end
  return unit == 'F' and value * 1.8 + 32 or value
end

function M.numericTemperature(wheel, source, weight)
  if not wheel then return nil end
  local core = M.finite(wheel.temperatureCore) and wheel.temperatureCore or nil
  if source == nil or source == 'core' then return core end
  local sum, count = 0, 0
  for _, field in ipairs({'temperatureInside', 'temperatureMiddle', 'temperatureOutside'}) do
    if M.finite(wheel[field]) then sum, count = sum + wheel[field], count + 1 end
  end
  local surface = count > 0 and sum / count or nil
  if source == 'surface' then return surface end
  weight = Temperature.coreWeight(weight)
  if weight == 0 then return surface end
  if weight == 1 then return core end
  if core and surface then return core * weight + surface * (1 - weight) end
  return nil
end

function M.formatPressure(value, unit, signed)
  value = M.pressure(value, unit)
  if value == nil then return nil end
  local decimals = unit == 'bar' and 2 or unit == 'kPa' and 0 or 1
  if math.abs(value) < 0.5 * 10 ^ (-decimals) then value = 0 end
  return string.format((signed and '%+.' or '%.') .. decimals .. 'f', value)
end

function M.wheel(wheel, settings, gt3, front)
  if not wheel or not wheel.available then return nil end
  local mode = settings.numericMetric or 'life'
  if mode == 'pressure' then
    if not positive(wheel.pressure) then return nil end
    local delta = settings.pressureReadout == 'delta'
    local reference = M.references(wheel, gt3, settings, front)
    local value = wheel.pressure - (delta and reference.idealPressure or 0)
    local text = M.formatPressure(value, settings.pressureUnit, delta)
    return (delta and reference.pressureEstimated and '~' or '') .. text,
      (delta and 'DELTA ' or '') .. (settings.pressureUnit or 'psi')
  elseif mode == 'temperature' then
    local value = M.temperature(M.numericTemperature(wheel, settings.temperatureReadout,
      settings.temperatureCoreWeight), settings.temperatureUnit)
    if value ~= nil then return string.format('%.0f', value), settings.temperatureUnit == 'F' and 'F' or 'C' end
  elseif wheel.wearAvailable and M.finite(wheel.remaining) then
    return string.format('%d', U.round(U.clamp(wheel.remaining, 0, 1) * 100)), '%'
  end
  return nil
end

return M
