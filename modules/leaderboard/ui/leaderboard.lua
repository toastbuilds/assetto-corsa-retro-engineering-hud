local Theme = require('modules/leaderboard/src/theme')
local Classes = require('modules/leaderboard/src/classes')

local M = {}
local FONT = Theme.fonts.utility
local EMPHASIS_FONT = 'Consolas;Weight=Bold'

local function clamp(value, minimum, maximum)
  return math.max(minimum, math.min(maximum, value))
end

local function text(value, size, position, color)
  ui.dwriteDrawText(tostring(value or ''), size, position, color)
end

local function emphasizedText(value, size, position, color)
  ui.pushDWriteFont(EMPHASIS_FONT)
  text(value, size, position, color)
  ui.popDWriteFont()
end

local function centered(value, size, center, color)
  local measured = ui.measureDWriteText(tostring(value or ''), size)
  text(value, size, center - measured / 2, color)
end

local function chamferRect(tl, br, chamfer, fill, stroke, strokeWidth)
  local c = math.min(chamfer, math.min((br.x - tl.x) / 3, (br.y - tl.y) / 3))
  local function path()
    ui.pathClear()
    ui.pathLineTo(vec2(tl.x + c, tl.y)); ui.pathLineTo(vec2(br.x - c, tl.y))
    ui.pathLineTo(vec2(br.x, tl.y + c)); ui.pathLineTo(vec2(br.x, br.y - c))
    ui.pathLineTo(vec2(br.x - c, br.y)); ui.pathLineTo(vec2(tl.x + c, br.y))
    ui.pathLineTo(vec2(tl.x, br.y - c)); ui.pathLineTo(vec2(tl.x, tl.y + c))
  end
  path(); ui.pathFillConvex(fill)
  path(); ui.pathStroke(stroke, true, strokeWidth)
end

local function role(palette, name, alpha)
  return Theme.withAlpha(palette[name] or palette.primary, alpha or 1)
end

local function drawScrew(center, palette, scale)
  ui.drawCircleFilled(center, 4 * scale, role(palette, 'panelRaised', 0.96), 16)
  ui.drawCircle(center, 4 * scale, role(palette, 'outlineSoft', 0.92), 16, 0.9 * scale)
  ui.drawLine(center - vec2(1.8 * scale, 1.8 * scale), center + vec2(1.8 * scale, 1.8 * scale), role(palette, 'outline', 0.9), 0.9 * scale)
end

local function drawFrame(origin, width, height, palette, scale, opacity)
  local tl, br = origin + vec2(7 * scale, 7 * scale), origin + vec2((width - 7) * scale, (height - 7) * scale)
  chamferRect(tl, br, 10 * scale, role(palette, 'surface', opacity), role(palette, 'metal', 0.88), 1.5 * scale)
  chamferRect(tl + vec2(5 * scale, 5 * scale), br - vec2(5 * scale, 5 * scale), 7 * scale,
    role(palette, 'void', opacity * 0.66), role(palette, 'outlineDim', 0.86), 0.8 * scale)
  drawScrew(tl + vec2(14 * scale, 14 * scale), palette, scale)
  drawScrew(vec2(br.x - 14 * scale, tl.y + 14 * scale), palette, scale)
  drawScrew(vec2(tl.x + 14 * scale, br.y - 14 * scale), palette, scale)
  drawScrew(br - vec2(14 * scale, 14 * scale), palette, scale)
end

local function formatMs(value)
  value = tonumber(value)
  if not value or value <= 0 then return '--.---' end
  local seconds = value > 1000 and value / 1000 or value
  return string.format('%02d:%06.3f', math.floor(seconds / 60), seconds % 60)
end

local function formatGap(value)
  value = tonumber(value)
  if not value or value <= 0 then return '--.---' end
  local seconds = value > 1000 and value / 1000 or value
  return string.format('+%.3f', seconds)
end

local function shorten(value, maxLength, scroll, now)
  value = tostring(value or '')
  if #value <= maxLength then return value end
  if scroll then
    local span = #value + 4
    local offset = math.floor((now or 0) * 3) % span
    local extended = value .. '    ' .. value
    return extended:sub(offset + 1, offset + maxLength)
  end
  return value:sub(1, math.max(1, maxLength - 1)) .. '…'
end

local function rowStateColor(row, palette)
  if row.status == 'RET' then return role(palette, 'red', 0.90) end
  if row.status == 'OFF' then return role(palette, 'secondary', 0.90) end
  if row.status == 'PIT' then return role(palette, 'cyan', 0.95) end
  if row.status == 'FIN' then return role(palette, 'green', 0.95) end
  return role(palette, 'primary', 1)
end

local function flagPulse(label, now)
  -- A 1.2 Hz opacity pulse is conspicuous without high-frequency flashing or
  -- large-area movement. CLEAR remains steady so only active race flags call attention.
  if not label or label == '' then return 1 end
  return 0.62 + 0.38 * (0.5 + 0.5 * math.sin((now or ui.time()) * math.pi * 2.4))
end

local function isAlertFlag(label)
  return label ~= nil and label ~= '' and label ~= 'GREEN'
end

local function drawFlagAlert(origin, width, top, header, palette, scale, opacity, now)
  local flagColors = { yellow = 'flagYellow', red = 'red', blue = 'blue', white = 'white' }
  local colorName = flagColors[header.flagRole] or 'flagYellow'
  local pulse = flagPulse(header.flagLabel, now)
  local tl = vec2(origin.x + 22 * scale, top)
  local br = vec2(origin.x + (width - 22) * scale, top + 31 * scale)
  chamferRect(tl, br, 4 * scale, role(palette, colorName, 0.76 + 0.20 * pulse), role(palette, colorName, 1), 1.1 * scale)

  local label = tostring(header.flagLabel) .. ' FLAG   '
  local textColor = colorName == 'flagYellow' and rgbm(0.07, 0.055, 0.025, 1) or role(palette, 'white', 1)
  local textSize = 20 * scale
  local measured = ui.measureDWriteText(label, textSize)
  local span = (measured.x or 150 * scale) + 26 * scale
  local offset = (now * 40 * scale) % span
  ui.pushClipRect(tl + vec2(4 * scale, 2 * scale), br - vec2(4 * scale, 2 * scale))
  for x = tl.x - span - offset, br.x + span, span do
    emphasizedText(label, textSize, vec2(x, tl.y + 4 * scale), textColor)
  end
  ui.popClipRect()
end

local function drawHeader(origin, scale, width, snapshot, settings, palette, opacity)
  local headerTL, headerBR = origin + vec2(18 * scale, 16 * scale), origin + vec2((width - 18) * scale, 108 * scale)
  -- Header telemetry remains legible over a bright track even when the shared
  -- HUD intentionally lowers its general backdrop opacity.
  local surfaceOpacity = math.max(0.92, opacity)
  local textOpacity = math.max(0.98, opacity)
  local labelOpacity = math.max(0.94, opacity)
  chamferRect(headerTL, headerBR, 7 * scale, role(palette, 'panel', surfaceOpacity), role(palette, 'outline', 0.96), 1.3 * scale)
  chamferRect(headerTL + vec2(4 * scale, 4 * scale), headerBR - vec2(4 * scale, 4 * scale), 4 * scale,
    role(palette, 'void', surfaceOpacity * 0.96), role(palette, 'outlineDim', 0.90), 0.8 * scale)

  local h = snapshot.header or {}
  text(h.typeLabel or 'WAIT', 29 * scale, origin + vec2(36 * scale, 34 * scale), role(palette, 'primary', textOpacity))
  ui.drawLine(origin + vec2(145 * scale, 29 * scale), origin + vec2(145 * scale, 70 * scale), role(palette, 'outlineSoft', 0.98), 1 * scale)
  text('TIME  ' .. (h.timeText or '--:--'), 18 * scale, origin + vec2(170 * scale, 38 * scale), role(palette, 'primary', textOpacity))
  text('LAP  ' .. (h.currentLapText or '--'), 18 * scale, origin + vec2(365 * scale, 38 * scale), role(palette, 'primary', textOpacity))
  if settings.showFlags == false then
    text('AIR  ' .. (h.ambientText or '--'), 14 * scale, origin + vec2(36 * scale, 78 * scale), role(palette, 'secondary', labelOpacity))
    text('TARMAC  ' .. (h.trackText or '--'), 14 * scale, origin + vec2(225 * scale, 78 * scale), role(palette, 'cyan', textOpacity))
  else
    local flagColors = { green = 'green', yellow = 'flagYellow', red = 'red', blue = 'blue', white = 'white' }
    local flagColor = flagColors[h.flagRole] or 'green'
    local pulse = flagPulse(h.flagLabel, ui.time())
    local flagTL, flagBR = origin + vec2(32 * scale, 74 * scale), origin + vec2(230 * scale, 99 * scale)
    chamferRect(flagTL, flagBR, 4 * scale, role(palette, flagColor, (0.14 + 0.26 * pulse) * surfaceOpacity), role(palette, flagColor, 0.58 + 0.40 * pulse), 0.9 * scale)
    text('FLAG', 12 * scale, origin + vec2(42 * scale, 81 * scale), role(palette, 'secondary', labelOpacity))
    emphasizedText(h.flagLabel or 'CLEAR', 15 * scale, origin + vec2(92 * scale, 78 * scale), role(palette, flagColor, 0.72 + 0.28 * pulse))
    text('AIR  ' .. (h.ambientText or '--'), 13 * scale, origin + vec2(255 * scale, 79 * scale), role(palette, 'secondary', labelOpacity))
    text('TARMAC  ' .. (h.trackText or '--'), 13 * scale, origin + vec2(375 * scale, 79 * scale), role(palette, 'cyan', textOpacity))
  end

  local lapTL, lapBR = origin + vec2(525 * scale, 29 * scale), origin + vec2(715 * scale, 78 * scale)
  chamferRect(lapTL, lapBR, 6 * scale, role(palette, 'panelRaised', surfaceOpacity), role(palette, 'amber', 0.96), 1.2 * scale)
  centered(h.lapsText or 'LAPS: --', 19 * scale, vec2((lapTL.x + lapBR.x) / 2, lapTL.y + 25 * scale), role(palette, 'amber', textOpacity))

  local fuelX, fuelY, fuelW, fuelH = origin.x + (width - 250) * scale, origin.y + 21 * scale, 225 * scale, 72 * scale
  if settings.showFuel == false then
    text(settings.lockWindow and 'LOCK' or 'MOVE', 9 * scale, origin + vec2((width - 54) * scale, 92 * scale), role(palette, 'secondary', opacity))
    return
  end
  chamferRect(vec2(fuelX, fuelY), vec2(fuelX + fuelW, fuelY + fuelH), 6 * scale,
    role(palette, 'panelRaised', surfaceOpacity), role(palette, 'outlineSoft', 0.96), 1.1 * scale)
  -- Minimal geometric pump and a segmented gauge: high signal, no decorative image asset.
  local ix, iy = fuelX + 17 * scale, fuelY + 22 * scale
  ui.drawLine(vec2(ix, iy), vec2(ix + 12 * scale, iy), role(palette, 'amber', textOpacity), 2 * scale)
  ui.drawLine(vec2(ix, iy), vec2(ix, iy + 20 * scale), role(palette, 'amber', textOpacity), 2 * scale)
  ui.drawLine(vec2(ix, iy + 20 * scale), vec2(ix + 12 * scale, iy + 20 * scale), role(palette, 'amber', textOpacity), 2 * scale)
  ui.drawLine(vec2(ix + 12 * scale, iy), vec2(ix + 16 * scale, iy + 5 * scale), role(palette, 'amber', textOpacity), 1.4 * scale)
  ui.drawLine(vec2(ix + 16 * scale, iy + 5 * scale), vec2(ix + 16 * scale, iy + 12 * scale), role(palette, 'amber', textOpacity), 1.4 * scale)
  local gaugeLeft, gaugeTop = fuelX + 51 * scale, fuelY + 6 * scale
  ui.drawRectFilled(vec2(gaugeLeft, gaugeTop), vec2(gaugeLeft + 23 * scale, gaugeTop + 60 * scale), role(palette, 'void', 0.98))
  for i = 0, 7 do
    local filled = snapshot.fuel and snapshot.fuel.available and snapshot.fuel.maxFuel and snapshot.fuel.fuel
      and snapshot.fuel.fuel / math.max(0.1, snapshot.fuel.maxFuel) >= (i + 1) / 8
    local barColor = filled and role(palette, 'amber', textOpacity) or role(palette, 'metal', labelOpacity)
    ui.drawRectFilled(vec2(fuelX + 54 * scale, fuelY + (8 + i * 7) * scale),
      vec2(fuelX + 72 * scale, fuelY + (14 + i * 7) * scale), barColor)
  end
  local fuel = snapshot.fuel or {}
  text('FUEL', 13 * scale, vec2(fuelX + 88 * scale, fuelY + 10 * scale), role(palette, 'secondary', labelOpacity))
  text(fuel.available and (fuel.fuelText or 'N/A') or 'N/A', 16 * scale, vec2(fuelX + 166 * scale, fuelY + 8 * scale), role(palette, 'primary', textOpacity))
  ui.drawLine(vec2(fuelX + 85 * scale, fuelY + 31 * scale), vec2(fuelX + fuelW - 10 * scale, fuelY + 31 * scale), role(palette, 'outlineDim', 0.92), 0.8 * scale)
  text('AVG', 12 * scale, vec2(fuelX + 88 * scale, fuelY + 36 * scale), role(palette, 'secondary', labelOpacity))
  text(fuel.averageText or '--', 14 * scale, vec2(fuelX + 166 * scale, fuelY + 34 * scale), role(palette, fuel.average and 'amber' or 'primary', textOpacity))
  text('EST', 12 * scale, vec2(fuelX + 88 * scale, fuelY + 55 * scale), role(palette, 'secondary', labelOpacity))
  text(fuel.estimatedLapsText or '--', 14 * scale, vec2(fuelX + 166 * scale, fuelY + 53 * scale), role(palette, 'primary', textOpacity))
end

local function currentSectorText(row)
  if not row.currentSplits then return '--' end
  local index = math.max(1, (tonumber(row.currentSector) or 0) + 1)
  local value = row.currentSplits[index]
  return value and ('S' .. tostring(index) .. ' ' .. formatMs(value)) or '--'
end

local function drawPositionBadge(x, y, size, value, palette, scale, isLocal)
  local accent = isLocal and role(palette, 'amber', 1) or role(palette, 'primary', 0.90)
  chamferRect(vec2(x, y), vec2(x + size, y + size), 5 * scale,
    isLocal and role(palette, 'amberDim', 0.92) or role(palette, 'panelRaised', 0.92), accent, 1.1 * scale)
  centered(value, 22 * scale, vec2(x + size / 2, y + size / 2), isLocal and role(palette, 'amber', 1) or role(palette, 'primary', 1))
end

local function drawRow(origin, scale, width, top, row, snapshot, settings, palette, opacity, now)
  local left, right = origin.x + 22 * scale, origin.x + (width - 22) * scale
  local bottom = top + 56 * scale
  local fill = row.isLocal and role(palette, 'amberDim', 0.55 * opacity) or role(palette, 'panel', 0.92 * opacity)
  chamferRect(vec2(left, top), vec2(right, bottom), 4 * scale, fill, role(palette, 'outlineDim', 0.78), 0.75 * scale)
  local flagRole = row.flagCauseKind == 'yellow' and 'flagYellow'
    or row.flagCauseKind == 'blue' and 'blue' or nil
  if flagRole then
    local pulse = 0.5 + 0.5 * math.sin(now * math.pi * 2.4)
    local alpha = (palette == Theme.palettes.light and 0.18 or 0.22) + 0.08 * pulse
    chamferRect(vec2(left, top), vec2(right, bottom), 4 * scale,
      role(palette, flagRole, alpha * opacity),
      role(palette, flagRole, (0.65 + 0.30 * pulse) * opacity), 1.1 * scale)
  end
  if row.isLocal then ui.drawRectFilled(vec2(left + 2 * scale, top + 2 * scale), vec2(left + 4 * scale, bottom - 2 * scale), role(palette, 'amber', 0.95), 1 * scale) end

  drawPositionBadge(left + 10 * scale, top + 8 * scale, 40 * scale, row.position or '--', palette, scale, row.isLocal)
  local stateColor = rowStateColor(row, palette)
  emphasizedText(shorten(row.driver ~= '' and row.driver or 'UNKNOWN DRIVER', 25, settings.scrollLongNames, now), 24 * scale,
    vec2(left + 104 * scale, top + 15 * scale), row.isLocal and role(palette, 'amber', 1) or stateColor)

  if settings.showClass then
    local classColor = Classes.colors[row.classID] or role(palette, 'secondary', 1)
    text(Classes.display(row.classID), 23 * scale, vec2(left + 465 * scale, top + 16 * scale),
      row.classID == 'UNKNOWN' and role(palette, 'secondary', opacity) or Theme.withAlpha(classColor, opacity))
  end
  if settings.showCompound and row.tyreCompound ~= '' then
    text(shorten(row.tyreCompound, 7, false, now), 14 * scale, vec2(left + 535 * scale, top + 21 * scale), role(palette, 'cyan', opacity))
  end

  text(row.status or '--', 23 * scale, vec2(left + 585 * scale, top + 16 * scale), stateColor)
  local race = snapshot.header and snapshot.header.typeLabel == 'RACE'
  if race then
    text(row.interval or '--', 23 * scale, vec2(left + 680 * scale, top + 16 * scale), role(palette, 'cyan', opacity))
    text(formatMs(row.lastLapTimeMs), 23 * scale, vec2(left + 820 * scale, top + 16 * scale), role(palette, 'primary', opacity))
  else
    text(currentSectorText(row), 19 * scale, vec2(left + 640 * scale, top + 18 * scale), role(palette, 'cyan', opacity))
    text(formatGap(row.bestLapTimeMs and snapshot.sessionBest and row.bestLapTimeMs - snapshot.sessionBest), 19 * scale,
      vec2(left + 780 * scale, top + 18 * scale), role(palette, 'amber', opacity))
    text(formatMs(row.bestLapTimeMs), 19 * scale, vec2(left + 900 * scale, top + 18 * scale), role(palette, 'primary', opacity))
  end

  if row.lapPositionDelta and row.lapPositionDelta ~= 0 then
    local gained = row.lapPositionDelta > 0
    -- Keep the completed-lap movement in the open middle column, rather than
    -- cramming it beside the position badge.  If class is enabled, shift it
    -- just right of the class label so the two telemetry values remain legible.
    local lapDeltaX = settings.showClass and 530 or 465
    emphasizedText((gained and '▲' or '▼') .. tostring(math.abs(row.lapPositionDelta)), 23 * scale,
      vec2(left + lapDeltaX * scale, top + 16 * scale), role(palette, gained and 'green' or 'red', opacity))
  end

  if row.improvement then text(row.improvement, 12 * scale, vec2(right - 50 * scale, top + 7 * scale), role(palette, 'green', opacity)) end
  if row.sessionBest then text('SB', 12 * scale, vec2(right - 30 * scale, top + 25 * scale), role(palette, 'amber', opacity)) end
end

local function drawDataState(origin, scale, snapshot, palette, opacity)
  local rows = snapshot.shownRows or {}
  if #rows > 0 then return end
  local y = origin.y + 154 * scale
  if snapshot.error then
    text('DATA ERROR', 12 * scale, origin + vec2(38 * scale, 154 * scale), role(palette, 'red', opacity))
    text(shorten(snapshot.error, 112, false, ui.time()), 10 * scale, origin + vec2(38 * scale, 173 * scale), role(palette, 'red', opacity))
  else
    local label = snapshot.session and 'NO ACTIVE CARS' or 'WAITING FOR SESSION DATA'
    text(label, 12 * scale, vec2(origin.x + 38 * scale, y), role(palette, 'secondary', opacity))
  end
end

function M.draw(snapshot, settings, visual)
  snapshot = snapshot or {}
  local palette = visual.palette
  local width, height = ui.windowWidth(), ui.windowHeight()
  local scale = math.min(tonumber(settings.hudScale) or 0.84, width / 1040, height / 470)
  scale = math.max(0.55, scale)
  local contentWidth, contentHeight = 1040 * scale, 470 * scale
  local origin = vec2((width - contentWidth) / 2, (height - contentHeight) / 2)
  local opacity = clamp((visual.instrumentOpacity or 1) * (settings.instrumentOpacity or 1), 0, 1)
  local backdrop = clamp((visual.backdropOpacity or 0.72) * (settings.backdropOpacity or 0.72), 0, 1)
  local now = ui.time()

  ui.pushStyleVarAlpha(opacity)
  ui.pushDWriteFont(FONT)
  local reveal = clamp((now - (snapshot.enteredAt or now)) / 0.35, 0, 1)
  local clipTop = origin.y + contentHeight * 0.5 - contentHeight * reveal * 0.5
  ui.pushClipRect(vec2(0, clipTop), vec2(width, clipTop + contentHeight * reveal))
  drawFrame(origin, contentWidth / scale, contentHeight / scale, palette, scale, backdrop)
  drawHeader(origin, scale, contentWidth / scale, snapshot, settings, palette, backdrop)
  local rows = snapshot.shownRows or {}
  local rowTop = origin.y + 115 * scale
  local rowHeight = 60 * scale
  local alertActive = isAlertFlag(snapshot.header and snapshot.header.flagLabel)
  local visibleRows = math.min(#rows, math.floor(tonumber(settings.maxRows) or 6))
  visibleRows = math.min(visibleRows, 5)
  for i = 1, visibleRows do
    drawRow(origin, scale, contentWidth / scale, rowTop + (i - 1) * rowHeight, rows[i], snapshot, settings, palette, opacity, now)
  end
  if alertActive then
    drawFlagAlert(origin, contentWidth / scale, rowTop + visibleRows * rowHeight + 5 * scale, snapshot.header, palette, scale, opacity, now)
  end
  drawDataState(origin, scale, snapshot, palette, opacity)
  ui.popClipRect()
  ui.popDWriteFont()
  ui.popStyleVar(1)

  if ui.mouseClicked(ui.MouseButton.Right) then settings.lockWindow = not settings.lockWindow end
end

return M
