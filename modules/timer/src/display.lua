local Theme = require('modules/timing/src/theme')
local TimingUI = require('modules/timing/src/ui')

local Display = {}
local FONT = Theme.fonts.utility
local CARBON_OUTLINE = rgbm(0x13 / 255, 0x10 / 255, 0x0D / 255, 1)
local CREAM_OUTLINE = rgbm(0xF2 / 255, 0xDB / 255, 0xAE / 255, 1)

local OUTLINE_OFFSETS = {
  vec2(-1, 0), vec2(1, 0), vec2(0, -1), vec2(0, 1),
  vec2(-0.7, -0.7), vec2(0.7, -0.7), vec2(-0.7, 0.7), vec2(0.7, 0.7)
}
local WHEEL = { slots = {}, lastTime = nil, lastText = nil, lastFrame = nil }
local WHEEL_STIFFNESS = 180
local WHEEL_DAMPING = 27

local function linearChannel(value)
  if value <= 0.04045 then return value / 12.92 end
  return ((value + 0.055) / 1.055) ^ 2.4
end

local function outlineFor(color)
  local luminance = linearChannel(color.r) * 0.2126
    + linearChannel(color.g) * 0.7152 + linearChannel(color.b) * 0.0722
  return luminance < 0.36 and CREAM_OUTLINE or CARBON_OUTLINE
end

local function drawOutlinedText(text, size, center, color, scale)
  text = tostring(text)
  local measured = ui.measureDWriteText(text, size)
  local position = center - measured / 2
  local spread = math.max(0.75, scale)
  local outline = outlineFor(color)
  for _, offset in ipairs(OUTLINE_OFFSETS) do
    ui.dwriteDrawText(text, size, position + offset * spread, outline)
  end
  ui.dwriteDrawText(text, size, position, color)
end

local function wheelFrame(timeMs, text)
  local now = type(ui.time) == 'function' and tonumber(ui.time()) or nil
  local dt = now and WHEEL.lastFrame and now - WHEEL.lastFrame or 1 / 60
  if dt <= 0 then dt = 1 / 60 end

  local reset = WHEEL.lastTime == nil or #text ~= #(WHEEL.lastText or '')
    or dt > 0.20 or timeMs < WHEEL.lastTime - 500 or timeMs > WHEEL.lastTime + 500
  if reset then WHEEL.slots = {} end

  WHEEL.lastFrame = now
  WHEEL.lastTime = timeMs
  WHEEL.lastText = text
  return math.min(dt, 0.10), reset
end

local function wheelTarget(timeMs, text, index)
  local decimal = text:find('.', 1, true)
  local colon = text:find(':', 1, true)
  if not decimal then return nil end

  local unit
  if colon and index < colon then
    unit = 60000 * 10 ^ (colon - index - 1)
  elseif index < decimal then
    unit = 1000 * 10 ^ (decimal - index - 1)
  else
    unit = 100 * 10 ^ (-(index - decimal - 1))
  end
  return timeMs / unit
end

local function springWheel(index, target, dt, reset)
  local slot = WHEEL.slots[index]
  if reset or not slot then
    slot = { value = target, velocity = 0 }
    WHEEL.slots[index] = slot
    return target
  end

  local steps = math.max(1, math.ceil(dt * 120))
  local step = dt / steps
  for _ = 1, steps do
    local acceleration = (target - slot.value) * WHEEL_STIFFNESS - slot.velocity * WHEEL_DAMPING
    slot.velocity = slot.velocity + acceleration * step
    slot.value = slot.value + slot.velocity * step
  end
  if math.abs(target - slot.value) < 0.0005 and math.abs(slot.velocity) < 0.01 then
    slot.value, slot.velocity = target, 0
  end
  return slot.value
end

local function drawWheelTime(text, timeMs, size, center, color, scale)
  local total = ui.measureDWriteText(text, size)
  local origin = center - total / 2
  local digitHeight = ui.measureDWriteText('0', size).y
  local dt, reset = wheelFrame(timeMs, text)

  for index = 1, #text do
    local character = text:sub(index, index)
    local prefix = text:sub(1, index - 1)
    local prefixWidth = #prefix > 0 and ui.measureDWriteText(prefix, size).x or 0
    local characterSize = ui.measureDWriteText(character, size)
    local characterCenter = vec2(origin.x + prefixWidth + characterSize.x / 2, center.y)
    local target = character:match('%d') and wheelTarget(timeMs, text, index) or nil

    if target then
      local left = origin.x + prefixWidth
      local top = center.y - digitHeight / 2
      local wheelValue = springWheel(index, target, dt, reset)
      local wrappedValue = wheelValue - math.floor(wheelValue / 10) * 10
      local lowerDigit = math.floor(wrappedValue)
      local fraction = wrappedValue - lowerDigit

      ui.pushClipRect(vec2(left, top), vec2(left + characterSize.x, top + digitHeight))
      for row = lowerDigit, lowerDigit + 1 do
        local digit = tostring(row % 10)
        local digitCenter = vec2(characterCenter.x,
          center.y + (row - wrappedValue) * digitHeight)
        drawOutlinedText(digit, size, digitCenter, color, scale)
      end
      ui.popClipRect()
    else
      drawOutlinedText(character, size, characterCenter, color, scale)
    end
  end
end

local function inside(mouse, tl, br)
  return mouse.x >= tl.x and mouse.x <= br.x and mouse.y >= tl.y and mouse.y <= br.y
end

local function drawBadge(tl, width, height, label, fill, stroke, textColor, scale, textSize, outlineValue)
  TimingUI.chamferRect(tl, tl + vec2(width, height), 8 * scale, fill, stroke, 1.1 * scale)
  local size = (textSize or 10) * scale
  local measured = ui.measureDWriteText(label, size)
  size = size * math.min(1, (width - 10 * scale) / math.max(1, measured.x),
    (height - 8 * scale) / math.max(1, measured.y))
  local center = tl + vec2(width / 2, height / 2)
  if outlineValue then drawOutlinedText(label, size, center, textColor, scale)
  else TimingUI.centeredText(label, size, center, textColor) end
end

local function withBackgroundOpacity(color, opacity)
  return Theme.withAlpha(color, (tonumber(color.mult) or 1) * opacity)
end

function Display.draw(snapshot, settings, visual)
  local colors = visual.palette
  local backgroundOpacity = math.max(0, math.min(1, tonumber(settings.backgroundOpacity) or 0.70))
  local width, height = ui.windowWidth(), ui.windowHeight()
  local scale = math.max(0.35, math.min(settings.scale or 1, width / 320, height / 94))
  local events = { toggleLock = false }
  local mouse = type(ui.mouseLocalPos) == 'function' and ui.mouseLocalPos() or vec2(-1, -1)
  local contentTop = 5 * scale
  local finalHeight = snapshot.finalLap and 25 * scale or 0
  local result = snapshot.result
  local showBest = result and result.valid ~= false and result.status == 'session_best'
  local bestWidth = 64 * scale
  local deltaWidth = 88 * scale
  local gap = 5 * scale
  local timerTop = contentTop + finalHeight + 6 * scale
  local timerHeight = height - timerTop - 2 * scale
  local timerTL = vec2(6 * scale + (showBest and bestWidth + gap or 0), timerTop)
  local timerBR = vec2(width - 6 * scale - (result and deltaWidth + gap or 0), timerTop + timerHeight)
  local timerWidth = timerBR.x - timerTL.x

  ui.pushStyleVarAlpha(visual.instrumentOpacity or 1)
  ui.pushDWriteFont(FONT)

  if snapshot.finalLap then
    local badgeWidth = 132 * scale
    local badgeTL = vec2((width - badgeWidth) / 2, contentTop)
    drawBadge(badgeTL, badgeWidth, 20 * scale, 'FINAL LAP',
      withBackgroundOpacity(colors.redDim, backgroundOpacity),
      withBackgroundOpacity(colors.red, backgroundOpacity), colors.primary, scale)
  end

  local time = result and result.time or snapshot.currentLapTime
  local invalidLap = result and (result.valid == false or result.status == 'invalid') or snapshot.invalid == true
  local timeColor = invalidLap and colors.primary
    or (result and TimingUI.statusColor(colors, result.status) or colors.primary)

  TimingUI.chamferRect(timerTL, timerBR, 8 * scale,
    withBackgroundOpacity(colors.panelRaised, backgroundOpacity),
    withBackgroundOpacity(colors.outlineSoft, backgroundOpacity), 1.1 * scale)
  local timeText = TimingUI.formatTime(time)
  local timeSize = timerHeight
  local pitPadding = snapshot.inPits and 18 * scale or 0
  local measured = ui.measureDWriteText(timeText, timeSize)
  local hasInvalidMarker = invalidLap and timeText:find('%d') ~= nil
  local markerReserve = hasInvalidMarker and (ui.measureDWriteText('*', timeSize * 0.34).x + 3 * scale) or 0
  timeSize = timeSize * math.min(1, (timerWidth - 16 * scale - pitPadding - markerReserve) / math.max(1, measured.x),
    (timerHeight - 8 * scale) / math.max(1, measured.y))
  local textMeasured = ui.measureDWriteText(timeText, timeSize)
  local actualMarkerReserve = hasInvalidMarker
    and (ui.measureDWriteText('*', timeSize * 0.34).x + 3 * scale) or 0
  local timeCenter = vec2((timerTL.x + timerBR.x + pitPadding) / 2 - actualMarkerReserve / 2,
    timerTop + timerHeight / 2)
  if not result and tonumber(time) and tonumber(time) > 0 and timeText:find('%d') then
    drawWheelTime(timeText, tonumber(time), timeSize, timeCenter, timeColor, scale)
  else
    drawOutlinedText(timeText, timeSize, timeCenter, timeColor, scale)
  end
  if hasInvalidMarker then
    local markerSize = timeSize * 0.34
    local markerMeasured = ui.measureDWriteText('*', markerSize)
    local markerCenter = vec2(timeCenter.x + textMeasured.x / 2 + markerMeasured.x / 2 + 2 * scale,
      timeCenter.y - textMeasured.y / 2 + markerMeasured.y / 2 * 0.7)
    drawOutlinedText('*', markerSize, markerCenter, timeColor, scale)
  end

  if result then
    local resultBadgeHeight = timerHeight
    local badgeTop = timerTop
    if showBest then
      drawBadge(vec2(6 * scale, badgeTop), bestWidth, resultBadgeHeight, 'BEST',
        withBackgroundOpacity(colors.purpleDim, backgroundOpacity),
        withBackgroundOpacity(colors.purple, backgroundOpacity), colors.purple, scale, 20)
    end
    local deltaStatus = (result.valid == false or result.status == 'invalid') and 'invalid'
      or (result.delta ~= nil and result.delta < 0 and 'session_best') or 'slower'
    local deltaColor = deltaStatus == 'invalid' and colors.secondary
      or (result.delta == nil and colors.secondary) or TimingUI.statusColor(colors, deltaStatus)
    drawBadge(vec2(timerBR.x + gap, badgeTop), deltaWidth, resultBadgeHeight,
      TimingUI.formatDelta(result.delta), withBackgroundOpacity(colors.panelRaised, backgroundOpacity),
      withBackgroundOpacity(deltaColor, backgroundOpacity), deltaColor, scale, 20, true)
  end

  if snapshot.inPits then
    TimingUI.leftText('P', 10 * scale, timerTL + vec2(10 * scale, 9 * scale), colors.amber)
  end

  if type(ui.mouseClicked) == 'function' and ui.MouseButton
      and ui.mouseClicked(ui.MouseButton.Right) and inside(mouse, vec2(0, 0), vec2(width, height)) then
    events.toggleLock = true
  end
  ui.popDWriteFont()
  ui.popStyleVar(1)
  return events
end

return Display
