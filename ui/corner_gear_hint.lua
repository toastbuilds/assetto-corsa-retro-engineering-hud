local M = {}

function M.visual(state, settings)
  if settings and settings.cornerGearHint == false then return nil end
  local hint = state and state.cornerGearHint
  if type(hint) ~= 'table' or type(hint.gear) ~= 'number' then return nil end
  if hint.gear == state.gear or hint.gear < 1 then return nil end
  if hint.braking and (not settings or settings.animateShiftAlert ~= false)
      and math.floor((state.clock or 0) / 0.14) % 2 == 1 then return nil end
  return {
    gear = hint.gear,
    direction = hint.direction == 'up' and 'up' or 'down',
    overspeed = hint.overspeed == true
  }
end

-- x/y and size use each gauge's authored coordinates. Render callbacks apply
-- the gauge's normal origin, scale and text treatment.
function M.draw(state, settings, x, y, size, colors, drawLine, drawText)
  local hint = M.visual(state, settings)
  if not hint then return false end
  local color = hint.overspeed and colors.red or colors.primary
  local arrowX, stem = x - size * 0.34, size * 0.34
  local tipY = y + (hint.direction == 'up' and -stem or stem)
  local neckY = y + (hint.direction == 'up' and stem * 0.12 or -stem * 0.12)
  local wing = size * 0.25
  local endY = y + (hint.direction == 'up' and stem * 0.42 or -stem * 0.42)
  local width = math.max(1, size * 0.085)
  drawLine(arrowX, neckY, arrowX, tipY, color, width)
  drawLine(arrowX, tipY, arrowX - wing, endY, color, width)
  drawLine(arrowX, tipY, arrowX + wing, endY, color, width)
  drawText(tostring(hint.gear), size * 0.76, x + size * 0.28, y, color)
  return true
end

return M
