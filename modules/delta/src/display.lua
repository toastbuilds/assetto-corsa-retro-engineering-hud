local Constants = require('modules/delta/src/constants')
local LapData = require('modules/delta/src/lap_data')
local Theme = require('modules/delta/src/theme')

local Display = {}
local FONT = Theme.fonts.utility
local BAR_MAX_DELTA_SECONDS = 5.0
local BAR_HEIGHT = 28
local BADGE_WIDTH = 156
local BADGE_HEIGHT = 32
local BADGE_TEXT_SIZE = 21
local BADGE_GAP = 6
local TOAST_HEIGHT = 34
local TOAST_GAP = 5

local function clamp(value, minimum, maximum)
  return math.max(minimum, math.min(maximum, value))
end

local function point(tl, x, y)
  return tl + vec2(x, y)
end

local function inside(mouse, tl, br)
  return mouse.x >= tl.x and mouse.x <= br.x and mouse.y >= tl.y and mouse.y <= br.y
end

local function notificationActive(notification, now, settings)
  if not notification or notification.kind ~= 'lap' then return false end
  local elapsed = now - (notification.createdAt or now)
  return elapsed >= 0 and elapsed <= (settings.notificationDuration or 8)
end

local function centeredText(text, size, center, color)
  local measured = ui.measureDWriteText(text, size)
  ui.dwriteDrawText(text, size, center - measured / 2, color)
end

local function leftText(text, size, pos, color)
  ui.dwriteDrawText(text, size, pos, color)
end

local function deltaText(data)
  local star = type(data.star) == 'string' and data.star or ''
  if data.timeDelta ~= nil then return LapData.timeDeltaToString(data.timeDelta) .. star end
  return '--.--' .. star
end

local function chamferRect(tl, br, chamfer, fill, stroke, strokeWidth)
  local c = math.min(chamfer, math.min((br.x - tl.x) / 3, (br.y - tl.y) / 3))
  local function path()
    ui.pathClear()
    ui.pathLineTo(point(tl, c, 0))
    ui.pathLineTo(point(tl, br.x - tl.x - c, 0))
    ui.pathLineTo(point(tl, br.x - tl.x, c))
    ui.pathLineTo(point(tl, br.x - tl.x, br.y - tl.y - c))
    ui.pathLineTo(point(tl, br.x - tl.x - c, br.y - tl.y))
    ui.pathLineTo(point(tl, c, br.y - tl.y))
    ui.pathLineTo(point(tl, 0, br.y - tl.y - c))
    ui.pathLineTo(point(tl, 0, c))
  end
  path()
  ui.pathFillConvex(fill)
  path()
  ui.pathStroke(stroke, true, strokeWidth)
end

local function drawArrow(center, direction, color, scale)
  local width = 8 * scale
  local height = 8 * scale
  local tip = center + vec2(direction * width, 0)
  local upper = center + vec2(-direction * width, -height)
  local lower = center + vec2(-direction * width, height)
  ui.drawLine(upper, tip, color, 2 * scale)
  ui.drawLine(tip, lower, color, 2 * scale)
end

local function deltaColor(colors, delta)
  if delta == nil then return colors.primary end
  if delta < -1 then return colors.green end
  if delta > 1 then return colors.red end
  return delta < 0 and colors.cyan or (delta > 0 and colors.amber or colors.primary)
end

local function trendColor(colors, speedDelta)
  speedDelta = tonumber(speedDelta) or 0
  local intensity = clamp(math.abs(speedDelta) / 5, 0, 1)
  if speedDelta >= 0 then return Theme.blend(colors.cyan, colors.green, intensity) end
  return Theme.blend(colors.amber, colors.red, intensity)
end

local function activeStripeColor(colors, timeDelta, speedDelta)
  local delta = tonumber(timeDelta)
  local activity = clamp(math.abs(tonumber(speedDelta) or 0) / 5, 0, 1)
  local magnitude = clamp(math.abs(delta or 0) / 2, 0, 1)
  local intensity = math.max(activity, magnitude * 0.55)
  if delta ~= nil and delta < 0 then return Theme.blend(colors.cyan, colors.green, intensity) end
  if delta ~= nil then return Theme.blend(colors.amber, colors.red, intensity) end
  return trendColor(colors, speedDelta)
end

local function drawScaleTicks(tl, width, height, colors, scale)
  local centerX = tl.x + width / 2
  for i = -8, 8 do
    local x = centerX + i * width / 16
    local tickHeight = i == 0 and height * 0.80 or (i % 4 == 0 and height * 0.50 or height * 0.28)
    local color = i == 0 and colors.primary or colors.divider
    ui.drawLine(vec2(x, tl.y + (height - tickHeight) / 2), vec2(x, tl.y + (height + tickHeight) / 2), color, (i == 0 and 1.6 or 1) * scale)
  end
end

local function drawButton(tl, br, label, isHovered, isPressed, colors, scale)
  local fill = colors.panelRaised
  local stroke = colors.outlineSoft
  local textColor = colors.amber
  if isHovered then
    fill = isPressed and colors.metalDim or colors.metal
    stroke = colors.cyan
    textColor = colors.primary
  end
  chamferRect(tl, br, 5 * scale, fill, stroke, (isHovered and 1.8 or 1.2) * scale)
  centeredText(label, 18 * scale, (tl + br) / 2, textColor)
end

local function drawDeltaBar(tl, width, height, data, colors, scale)
  local br = tl + vec2(width, height)
  chamferRect(tl, br, 7 * scale, colors.surface, colors.outlineSoft, 1.4 * scale)
  local inner = tl + vec2(3 * scale, 3 * scale)
  local innerWidth = width - 6 * scale
  local innerHeight = height - 6 * scale
  chamferRect(inner, inner + vec2(innerWidth, innerHeight), 5 * scale, colors.panel, colors.outlineDim, 1 * scale)
  drawScaleTicks(inner, innerWidth, innerHeight, colors, scale)
  local centerX = inner.x + innerWidth / 2
  local delta = tonumber(data.timeDelta)
  if delta then
    local half = innerWidth / 2 - 3 * scale
    local amount = clamp(math.abs(delta) / 1000 / BAR_MAX_DELTA_SECONDS, 0, 1) * half
    local fill = activeStripeColor(colors, data.timeDelta, data.speedDelta)
    local fillTL = delta < 0 and vec2(centerX, inner.y + 3 * scale) or vec2(centerX - amount, inner.y + 3 * scale)
    local fillBR = delta < 0 and vec2(centerX + amount, inner.y + innerHeight - 3 * scale) or vec2(centerX, inner.y + innerHeight - 3 * scale)
    if amount > 0 then ui.drawRectFilled(fillTL, fillBR, Theme.withAlpha(fill, 0.88)) end
  end
  ui.drawLine(vec2(centerX, inner.y), vec2(centerX, inner.y + innerHeight), colors.primary, 2 * scale)
  leftText('−', 10 * scale, vec2(inner.x + 8 * scale, inner.y + innerHeight + 2 * scale), colors.cyan)
  leftText('+', 10 * scale, vec2(inner.x + innerWidth - 14 * scale, inner.y + innerHeight + 2 * scale), colors.red)
end

local function drawDeltaBadge(centerX, y, data, colors, scale)
  local width = BADGE_WIDTH * scale
  local height = BADGE_HEIGHT * scale
  local tl = vec2(centerX - width / 2, y)
  local br = tl + vec2(width, height)
  local delta = tonumber(data.timeDelta)
  local accent = delta == nil and colors.outlineSoft or activeStripeColor(colors, data.timeDelta, data.speedDelta)
  chamferRect(tl, br, 7 * scale, colors.panelRaised, Theme.withAlpha(accent, 0.92), 1.5 * scale)
  centeredText(deltaText(data), BADGE_TEXT_SIZE * scale, vec2(centerX, y + height / 2), deltaColor(colors, delta))
end

local function drawReadout(tl, width, height, data, colors, scale)
  local br = tl + vec2(width, height)
  chamferRect(tl, br, 8 * scale, colors.panelRaised, colors.outline, 1.6 * scale)
  local color = deltaColor(colors, data.timeDelta)
  centeredText(deltaText(data), 29 * scale, tl + vec2(width / 2, height * 0.52), color)
  if data.timeDelta and math.abs(data.speedDelta or 0) > 0.15 then
    local trend = data.speedDelta >= 0 and 'GAINING' or 'LOSING'
    centeredText(trend, 8 * scale, tl + vec2(width / 2, height - 8 * scale), trendColor(colors, data.speedDelta))
  else
    centeredText(data.message or 'LIVE DELTA', 8 * scale, tl + vec2(width / 2, height - 8 * scale), colors.secondary)
  end
end

local function drawSecondary(tl, width, height, data, colors, scale)
  local br = tl + vec2(width, height)
  chamferRect(tl, br, 6 * scale, colors.panel, colors.outlineDim, 1.1 * scale)
  local sector = (data.sector or 0) + 1
  local lap = data.lapNumber or 0
  leftText(string.format('S%02d / %02d', sector, math.max(1, data.sectorCount or 1)), 9 * scale, tl + vec2(10 * scale, 13 * scale), colors.amber)
  leftText(string.format('LAP %02d', lap + 1), 9 * scale, tl + vec2(10 * scale, 29 * scale), colors.cyan)
  local current = data.currentLapTime and LapData.timeToString(data.currentLapTime)
    or (data.currentLap and LapData.timeToString(data.currentLap.laptime) or '--.---')
  local personal = data.personalSector and LapData.timeToString(data.personalSector.time) or '--.---'
  local session = data.sessionSector and LapData.timeToString(data.sessionSector.time) or '--.---'
  leftText('CUR  ' .. current, 9 * scale, tl + vec2(width * 0.48, 13 * scale), colors.primary)
  leftText('PB   ' .. personal, 9 * scale, tl + vec2(width * 0.48, 29 * scale), colors.cyan)
  leftText('SES  ' .. session, 9 * scale, tl + vec2(width * 0.72, 29 * scale), colors.green)
end

local function notificationText(notification)
  if notification.kind == 'sector' then
    return string.format('SECTOR %02d', (notification.sector or 0) + 1), LapData.timeToString(notification.sectorTime) .. (notification.valid and '' or '*'), notification.sectorDelta
  end
  if notification.kind == 'lap' then
    return string.format('LAP %02d', (notification.lapNumber or 0) + 1), LapData.timeToString(notification.lapTime) .. (notification.valid and '' or '*'), notification.lapDelta
  end
  return 'NEW RECORD', notification.driverName or 'Unknown driver', nil
end

local function drawNotification(notification, centerX, y, width, height, now, settings, colors, scale)
  if not notification then return end
  local elapsed = now - (notification.createdAt or now)
  local total = settings.notificationDuration or 8
  local motion = settings.animationDuration or 0.2
  if elapsed > total then return end
  local open = clamp(elapsed / motion, 0, 1)
  local close = clamp((total - elapsed) / motion, 0, 1)
  local visible = math.min(open, close)
  if visible <= 0 then return end
  local fullTL = vec2(centerX - width / 2, y)
  local fullBR = fullTL + vec2(width, height)
  local clipWidth = width * visible
  local clipTL = vec2(centerX - clipWidth / 2, y)
  local clipBR = vec2(centerX + clipWidth / 2, y + height)
  ui.pushClipRect(clipTL, clipBR)
  chamferRect(fullTL, fullBR, 6 * scale, colors.panelRaised, colors.outlineSoft, 1.2 * scale)
  local label, value, delta = notificationText(notification)
  local valueSize = notification.kind == 'lap' and BADGE_TEXT_SIZE or 14
  leftText(label, 11 * scale, fullTL + vec2(12 * scale, 10 * scale), colors.amber)
  leftText(value, valueSize * scale, fullTL + vec2(width * 0.38, 8 * scale), notification.valid == false and colors.red or colors.primary)
  if delta ~= nil then leftText(LapData.timeDeltaToString(delta), valueSize * scale, fullTL + vec2(width * 0.72, 8 * scale), deltaColor(colors, delta)) end
  ui.popClipRect()
end

function Display.draw(snapshot, settings, visual, pinned)
  local colors = visual.palette
  local opacity = visual.instrumentOpacity or 1
  local now = ui.time()
  local mouse = ui.mouseLocalPos()
  local width, height = ui.windowWidth(), ui.windowHeight()
  local barOnly = settings.barOnly == true
  local showDetails = settings.showDetails ~= false
  local lapToast = barOnly and snapshot.notification1 or nil
  if not notificationActive(lapToast, now, settings) then lapToast = nil end
  local compact = not barOnly and settings.minimized == true and not inside(mouse, vec2(0, 0), vec2(width, height))
  local contentHeight = barOnly and 112 or (compact and 72 or (showDetails and 164 or 104))
  local scale = math.min(settings.scale or 1, (width - 16) / 720, (height - 16) / contentHeight)
  scale = math.max(0.35, scale)
  local events = { modeDelta = 0, toggleLock = false }

  ui.pushStyleVarAlpha(opacity)
  ui.pushDWriteFont(FONT)

  if barOnly then
    local hovered = inside(mouse, vec2(0, 0), vec2(width, height))
    local buttonW = hovered and 42 * scale or 0
    local buttonGap = hovered and 18 * scale or 0
    local barHeight = BAR_HEIGHT * scale
    local badgeGap = BADGE_GAP * scale
    local badgeHeight = BADGE_HEIGHT * scale
    local toastHeight = TOAST_HEIGHT * scale
    local toastGap = TOAST_GAP * scale
    local groupHeight = barHeight + badgeGap + badgeHeight
    local barTop = (height - groupHeight) / 2 + toastHeight + toastGap
    local barTL = vec2(buttonW + buttonGap + 8 * scale, barTop)
    local barBR = vec2(width - buttonW - buttonGap - 8 * scale, barTL.y + barHeight)
    drawDeltaBar(barTL, barBR.x - barTL.x, barBR.y - barTL.y, snapshot, colors, scale)
    drawDeltaBadge(width / 2, barBR.y + badgeGap, snapshot, colors, scale)
    if lapToast then
      local toastWidth = math.min(width - 16 * scale, 360 * scale)
      local toastY = barTL.y - (toastHeight + toastGap)
      drawNotification(lapToast, width / 2, toastY, toastWidth, toastHeight, now, settings, colors, scale)
    end
    if hovered then
      centeredText(snapshot.modeShortLabel or 'SESSION LAP', 8 * scale,
        vec2(width / 2, 8 * scale), colors.secondary)
      local buttonLeftTL = vec2(8 * scale, barTL.y)
      local buttonLeftBR = buttonLeftTL + vec2(buttonW, barBR.y - barTL.y)
      local buttonRightBR = vec2(width - 8 * scale, barBR.y)
      local buttonRightTL = buttonRightBR - vec2(buttonW, barBR.y - barTL.y)
      local leftHovered = inside(mouse, buttonLeftTL, buttonLeftBR)
      local rightHovered = inside(mouse, buttonRightTL, buttonRightBR)
      drawButton(buttonLeftTL, buttonLeftBR, '<', leftHovered,
        leftHovered and ui.mouseDown(ui.MouseButton.Left), colors, scale)
      drawButton(buttonRightTL, buttonRightBR, '>', rightHovered,
        rightHovered and ui.mouseDown(ui.MouseButton.Left), colors, scale)
      if ui.mouseClicked(ui.MouseButton.Left) then
        if leftHovered then events.modeDelta = -1 end
        if rightHovered then events.modeDelta = 1 end
      end
    end
  elseif compact then
    local readoutWidth = math.min(width - 24, 250 * scale)
    local readoutHeight = 56 * scale
    local readoutTL = vec2((width - readoutWidth) / 2, (height - readoutHeight) / 2)
    drawReadout(readoutTL, readoutWidth, readoutHeight, snapshot, colors, scale)
  else
    local mainHeight = (showDetails and 154 or 96) * scale
    local mainTop = settings.position == Constants.Position.TOP and 10
      or (settings.position == Constants.Position.BOTTOM and height - mainHeight - 10 or (height - mainHeight) / 2)
    mainTop = clamp(mainTop, 6, math.max(6, height - mainHeight - 6))
    local panelTL = vec2(8, mainTop)
    local panelBR = vec2(width - 8, mainTop + mainHeight)
    chamferRect(panelTL, panelBR, 10 * scale, colors.panel, colors.outline, 1.6 * scale)
    centeredText(snapshot.modeLabel or 'SESSION  LAP', 10 * scale, vec2(width / 2, panelTL.y + 18 * scale), colors.primary)

    local buttonW = 42 * scale
    local barTL = vec2(panelTL.x + buttonW + 18 * scale, panelTL.y + 40 * scale)
    local barBR = vec2(panelBR.x - buttonW - 18 * scale, panelTL.y + 68 * scale)
    local buttonLeftTL = vec2(panelTL.x + 10 * scale, barTL.y)
    local buttonLeftBR = buttonLeftTL + vec2(buttonW, barBR.y - barTL.y)
    local buttonRightBR = vec2(panelBR.x - 10 * scale, barBR.y)
    local buttonRightTL = buttonRightBR - vec2(buttonW, barBR.y - barTL.y)
    local leftHovered = inside(mouse, buttonLeftTL, buttonLeftBR)
    local rightHovered = inside(mouse, buttonRightTL, buttonRightBR)
    local leftPressed = leftHovered and ui.mouseDown(ui.MouseButton.Left)
    local rightPressed = rightHovered and ui.mouseDown(ui.MouseButton.Left)
    drawButton(buttonLeftTL, buttonLeftBR, '<', leftHovered, leftPressed, colors, scale)
    drawButton(buttonRightTL, buttonRightBR, '>', rightHovered, rightPressed, colors, scale)
    drawDeltaBar(barTL, barBR.x - barTL.x, barBR.y - barTL.y, snapshot, colors, scale)
    if ui.mouseClicked(ui.MouseButton.Left) then
      if leftHovered then events.modeDelta = -1 end
      if rightHovered then events.modeDelta = 1 end
    end

    if showDetails then
      local readoutTL = vec2(panelTL.x + 14 * scale, panelTL.y + 78 * scale)
      local readoutWidth = math.max(160 * scale, width * 0.34)
      drawReadout(readoutTL, readoutWidth, 62 * scale, snapshot, colors, scale)
      local secondaryTL = vec2(readoutTL.x + readoutWidth + 8 * scale, readoutTL.y)
      drawSecondary(secondaryTL, math.max(140 * scale, panelBR.x - secondaryTL.x - 14 * scale), 62 * scale, snapshot, colors, scale)
      local sectorText = string.format('SECTOR %02d  /  %s', (snapshot.sector or 0) + 1, snapshot.modeShortLabel or '')
      leftText(sectorText, 8 * scale, panelTL + vec2(16 * scale, mainHeight - 11 * scale), colors.secondary)
    end

    local notificationWidth = math.min(width - 28 * scale, 570 * scale)
    local notificationHeight = 30 * scale
    local notificationY = settings.position == Constants.Position.TOP and panelBR.y + 4 * scale or panelTL.y - notificationHeight - 4 * scale
    if settings.position == Constants.Position.TOP then
      drawNotification(snapshot.notification2, width / 2, notificationY + notificationHeight + 4 * scale, notificationWidth, notificationHeight, now, settings, colors, scale)
      drawNotification(snapshot.notification1, width / 2, notificationY, notificationWidth, notificationHeight, now, settings, colors, scale)
    else
      drawNotification(snapshot.notification2, width / 2, notificationY - notificationHeight - 4 * scale, notificationWidth, notificationHeight, now, settings, colors, scale)
      drawNotification(snapshot.notification1, width / 2, notificationY, notificationWidth, notificationHeight, now, settings, colors, scale)
    end
  end

  if ui.mouseClicked(ui.MouseButton.Right) and inside(mouse, vec2(0, 0), vec2(width, height)) then events.toggleLock = true end
  ui.popDWriteFont()
  ui.popStyleVar(1)
  return events
end

return Display
