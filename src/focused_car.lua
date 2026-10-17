local U = require('src/utils')
local M = {}

function M.resolve(sim)
  if sim == nil and ac.getSim then
    local ok, result = pcall(ac.getSim)
    if ok then sim = result end
  end

  local index = tonumber(U.read(sim, 'focusedCar', nil))
  if index == nil then index = 0 end
  index = math.floor(index)
  if index < 0 then return nil, index end

  local ok, car = pcall(ac.getCar, index)
  if ok and car ~= nil then return car, index end
  return nil, index
end

function M.identity(car, index)
  index = index or U.read(car, 'index', nil)
  if car == nil then return 'none/' .. tostring(index or '?') end

  local parts = {tostring(index or 0)}
  if ac.getCarID and index ~= nil then
    local ok, id = pcall(ac.getCarID, index)
    if ok and id ~= nil then parts[#parts + 1] = tostring(id) end
  end
  local sessionID = U.read(car, 'sessionID', nil)
  if sessionID ~= nil then parts[#parts + 1] = tostring(sessionID) end
  return table.concat(parts, '/')
end

return M
