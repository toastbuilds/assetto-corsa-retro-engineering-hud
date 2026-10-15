local U = require('src/utils')
local M = {}

function M.channel(state, settings, key)
  if settings.pedalDisplay == 'classic' then return nil end
  return state.pedalLayers and state.pedalLayers[key] or nil
end

function M.fraction(value, index, count)
  return U.clamp((value or 0) * count - index + 1, 0, 1)
end

-- The original input sits behind the same-width, estimated output trace.
function M.rect(a, b, input, output, color, neutral, inactive, horizontal)
  if inactive then ui.drawRectFilled(a, b, inactive) end
  local function fill(value, ink, inner)
    if not value or value <= 0 then return end
    value = U.clamp(value, 0, 1)
    local x, y = inner and (b.x - a.x) * 0.15 or 0, inner and (b.y - a.y) * 0.15 or 0
    local tl = horizontal and vec2(a.x, a.y + y) or vec2(a.x + x, b.y - (b.y - a.y) * value)
    local br = horizontal and vec2(a.x + (b.x - a.x) * value, b.y - y) or vec2(b.x - x, b.y)
    ui.drawRectFilled(tl, br, ink)
  end
  fill(input, neutral, false)
  fill(output, color, false)
end

return M
