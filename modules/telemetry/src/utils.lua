local M = {}

function M.clamp(value, minimum, maximum)
  value = tonumber(value) or 0
  if value < minimum then return minimum end
  if value > maximum then return maximum end
  return value
end

function M.number(value, fallback)
  if type(value) == 'number' then return value end
  local converted = tonumber(value)
  return converted or fallback
end

-- CSP properties can differ between versions. Read them defensively so an
-- optional field never prevents the independent app from rendering.
function M.read(object, key, fallback)
  if object == nil then return fallback end
  local ok, value = pcall(function() return object[key] end)
  if ok and value ~= nil then return value end
  return fallback
end

function M.withAlpha(color, alpha)
  return rgbm(color.r, color.g, color.b, M.clamp(alpha, 0, 1))
end

function M.round(value)
  value = tonumber(value) or 0
  return math.floor(value + 0.5)
end

return M
