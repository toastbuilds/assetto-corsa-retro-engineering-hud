local M = {}

local function read(object, key)
  if object == nil then return nil end
  local ok, value = pcall(function() return object[key] end)
  return ok and value or nil
end

function M.resolve(sim)
  local flag = tonumber(read(sim, 'raceFlagType'))
  local flags = ac.FlagType
  local kind
  if flag == (tonumber(read(flags, 'Caution')) or 2) then
    kind = 'yellow'
  elseif flag == (tonumber(read(flags, 'FasterCar')) or 12) then
    kind = 'blue'
  else
    return nil, nil
  end

  local index = tonumber(read(sim, 'raceFlagCause'))
  -- CSP uses -1 when no car caused the flag; index 0 is the player's car.
  if index == nil or index ~= index or index == math.huge
      or index < 0 or index ~= math.floor(index) then
    return nil, nil
  end
  return kind, index
end

return M
