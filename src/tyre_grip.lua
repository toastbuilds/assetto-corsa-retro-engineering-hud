local U = require('src/utils')
local M = {}
local cache = {}
local function finite(value)
  return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end
local function curves(car)
  local index = U.read(car,'index',0)
  local compound = U.read(car,'compoundIndex',nil)
  if not finite(compound) or compound < 0 then return nil end
  local id = ac.getCarID and ac.getCarID(index) or nil
  if not id then return nil end
  local key = tostring(id) .. ':' .. tostring(compound)
  if cache[key] ~= nil then return cache[key] or nil end
  local result = {}
  if ac.INIConfig and ac.INIConfig.carData then
    local ok,config = pcall(ac.INIConfig.carData,index,'tyres.ini')
    if ok and config then
      local suffix = compound > 0 and '_' .. tostring(compound) or ''
      for _,axle in ipairs({'FRONT','REAR'}) do
        local loaded,lut = pcall(function() return config:tryGetLut(axle .. suffix,'WEAR_CURVE') end)
        if loaded and lut then
          local valid = pcall(function()
            assert(finite(lut:getPointInput(0)) and finite(lut:getPointOutput(0)))
            assert(finite(lut:getPointInput(1)) and finite(lut:getPointOutput(1)))
          end)
          if valid then result[axle] = lut end
        end
      end
    end
  end
  cache[key] = result
  return result
end
function M.average(car)
  local loaded = curves(car)
  if not loaded then return nil end
  local sum = 0
  for index=0,3 do
    local wheel = U.read(U.read(car,'wheels',nil),index,nil)
    local distance = U.read(wheel,'tyreVirtualKM',nil)
    local curve = loaded[index < 2 and 'FRONT' or 'REAR']
    if not curve or not finite(distance) or distance < 0 then return nil end
    -- CMRT's installed tyre module converts virtual kilometres by a factor of 10.
    -- WEAR_CURVE outputs grip percentages (100, 98, ...), not remaining tread.
    local ok,grip = pcall(function() return curve:get(distance * 10) end)
    if not ok or not finite(grip) then return nil end
    sum = sum + grip
  end
  return sum / 4
end
return M
