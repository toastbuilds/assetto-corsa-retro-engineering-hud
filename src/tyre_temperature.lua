local U = require('src/utils')
local Layout = require('src/car_condition_layout')
local M = {}
local cacheKey, cachedWindows
local profileCarId, profileIsGT3
local surfaceFields = { 'temperatureInside', 'temperatureMiddle', 'temperatureOutside' }

local function gt3Name(value)
  return type(value) == 'string' and value:lower():find('%f[%w]gt3%f[%W]') ~= nil
end

local function isGT3(carId)
  if profileCarId == carId then return profileIsGT3 end
  profileCarId, profileIsGT3 = carId, gt3Name(carId)
  if ac.getFolder and ac.FolderID and io.load and JSON and JSON.parse then
    local ok, metadata = pcall(function()
      local path = ac.getFolder(ac.FolderID.ContentCars) .. '/' .. carId .. '/ui/ui_car.json'
      return JSON.parse(io.load(path))
    end)
    if ok and type(metadata) == 'table' then
      local street = metadata.class == 'street'
      local identified = gt3Name(metadata.name) or gt3Name(metadata.class) or profileIsGT3
      for _, tag in ipairs(type(metadata.tags) == 'table' and metadata.tags or {}) do
        street = street or tag == 'street'
        identified = identified or gt3Name(tag)
      end
      profileIsGT3 = identified and not street
    end
  end
  return profileIsGT3
end

function M.isGT3(car)
  local carId = car
  if type(car) ~= 'string' then
    local index = U.read(car, 'index', 0)
    carId = ac.getCarID and ac.getCarID(index) or tostring(index)
  end
  return isGT3(tostring(carId))
end

local function finite(value)
  return type(value) == 'number' and value == value
    and value ~= math.huge and value ~= -math.huge
end

function M.coreWeight(value)
  return finite(value) and U.clamp(value, 0, 1) or Layout.tyreGeneralCoreWeight
end

function M.generalTemperature(wheel, coreWeight)
  local sum, count = 0, 0
  for _, field in ipairs(surfaceFields) do
    local value = wheel[field]
    if finite(value) then sum, count = sum + value, count + 1 end
  end
  local core = wheel.temperatureCore
  if finite(core) then
    if count == 0 then return core end
    local weight = M.coreWeight(coreWeight)
    return core * weight + (sum / count) * (1 - weight)
  end
  if count > 0 then return sum / count end
  return finite(wheel.temperature) and wheel.temperature or nil
end

function M.zoneTemperature(wheel, surfaceTemperature, coreWeight)
  if not finite(surfaceTemperature) then return M.generalTemperature(wheel, coreWeight) end
  if not finite(wheel.temperatureCore) then return surfaceTemperature end
  local weight = M.coreWeight(coreWeight)
  return wheel.temperatureCore * weight + surfaceTemperature * (1 - weight)
end

local function crossing(a, b, grip)
  return a.temperature + (b.temperature - a.temperature)
    * (grip - a.grip) / (b.grip - a.grip)
end

local function optimumWindow(lut)
  if not lut then return nil end
  local points, peak, peakIndex = {}, 0, nil
  for i = 0, 1023 do
    local temperature, grip = lut:getPointInput(i), lut:getPointOutput(i)
    if not finite(temperature) or not finite(grip) then break end
    points[#points + 1] = { temperature = temperature, grip = grip }
  end
  if #points < 2 then return nil end
  table.sort(points, function(a, b) return a.temperature < b.temperature end)
  for i, point in ipairs(points) do
    if point.grip > peak then peak, peakIndex = point.grip, i end
  end
  if not peakIndex then return nil end
  -- Include the contiguous range delivering at least 99% of peak thermal grip.
  local threshold = peak * 0.99
  local first, last = peakIndex, peakIndex
  while first > 1 and points[first - 1].grip >= threshold do first = first - 1 end
  while last < #points and points[last + 1].grip >= threshold do last = last + 1 end
  local minimum, maximum = points[first].temperature, points[last].temperature
  if first > 1 then minimum = crossing(points[first - 1], points[first], threshold) end
  if last < #points then maximum = crossing(points[last], points[last + 1], threshold) end
  if minimum <= 0 or maximum < minimum then return nil end
  return { minimum = minimum, maximum = maximum }
end

function M.windows(car)
  local index = U.read(car, 'index', 0)
  local compound = U.read(car, 'compoundIndex', 0)
  local carId = ac.getCarID and ac.getCarID(index) or tostring(index)
  local key = tostring(carId) .. ':' .. tostring(compound)
  if cacheKey == key then return cachedWindows end
  cacheKey, cachedWindows = key, nil
  if not ac.INIConfig or not ac.INIConfig.carData then return nil end
  local ok, windows = pcall(function()
    local config = ac.INIConfig.carData(index, 'tyres.ini')
    if not config then return nil end
    local suffix = compound > 0 and '_' .. tostring(compound) or ''
    return {
      front = optimumWindow(config:tryGetLut('THERMAL_FRONT' .. suffix, 'PERFORMANCE_CURVE')),
      rear = optimumWindow(config:tryGetLut('THERMAL_REAR' .. suffix, 'PERFORMANCE_CURVE'))
    }
  end)
  if ok then cachedWindows = windows end
  return cachedWindows
end

return M
