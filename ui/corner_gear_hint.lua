local M = {}

local presentations = {
  analog = {
    concentric = 'side', shelf = 'side', spoke = 'side',
    snap = 'selector'
  },
  digital = {
    original = 'stacked', column = 'stacked', floating = 'stacked',
    offset = 'stacked', orbit = 'stacked',
    bridge = 'side', core_capsule = 'side', radial = 'side',
    snap = 'selector'
  }
}

local tuning = {
  analog = {
    concentric={currentX=-0.22,hintX=0.45,hintSize=25,digitScale=1.12},
    shelf={currentX=-0.26,hintX=0.46,hintSize=26,digitScale=1.12},
    spoke={currentX=-0.20,hintX=0.43,hintSize=27,digitScale=1.12},
    snap={currentX=-0.22,hintX=0.42,hintSize=29,digitScale=1.08}
  },
  digital = {
    column={currentY=-0.10,hintY=0.29,hintSize=24,digitScale=1.12},
    bridge={currentX=-0.22,hintX=0.42,hintSize=29,digitScale=1.12},
    core_capsule={currentX=-0.44,hintX=0.50,hintSize=28,digitScale=1.12},
    radial={currentX=-0.20,hintX=0.42,hintSize=28,digitScale=1.12},
    snap={currentX=-0.22,hintX=0.42,hintSize=29,digitScale=1.08}
  }
}

function M.presentation(instrument, variant)
  if instrument == 'gt7' then return 'gt7' end
  local group = presentations[instrument]
  return group and group[variant or 'original'] or nil
end

-- Returns the current-gear and recommendation placements in a dial's design
-- coordinates. Call only for a supported presentation with a visible cue.
function M.placements(instrument, variant, x, y, size)
  local presentation = M.presentation(instrument, variant)
  if not presentation then return nil end
  local id=variant or 'original'
  local custom=tuning[instrument] and tuning[instrument][id] or nil
  if presentation == 'stacked' then
    local hintSize=custom and custom.hintSize or math.max(14,math.min(22,size*0.36))
    return presentation,
      {x=x, y=y+size*(custom and custom.currentY or -0.16), size=size*0.68},
      {x=x, y=y+size*(custom and custom.hintY or 0.44), size=hintSize,
        digitSize=hintSize*(custom and custom.digitScale or 1.12)}
  elseif presentation == 'side' or presentation == 'selector' then
    local hintSize=custom and custom.hintSize or math.max(14,math.min(24,size*0.35))
    return presentation,
      {x=x+size*(custom and custom.currentX or -0.20), y=y, size=size*0.78},
      {x=x+size*(custom and custom.hintX or 0.40), y=y, size=hintSize,
        digitSize=hintSize*(custom and custom.digitScale or 1.12)}
  elseif presentation == 'gt7' then
    return presentation,
      {x=x-size*0.20, y=y, size=size*0.72},
      {x=x+size*0.34, y=y, size=math.max(24,math.min(30,size*0.30)),digitSize=33.6}
  end
  return nil
end

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
function M.draw(state, settings, x, y, size, colors, drawLine, drawText, digitSize)
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
  drawText(tostring(hint.gear), digitSize or size * 0.76, x + size * 0.28, y, color)
  return true
end

return M
