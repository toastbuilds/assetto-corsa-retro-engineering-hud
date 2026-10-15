local Theme = require('modules/leaderboard/src/theme')
local GeneralSettings = require('src/general_settings')
local Classes = require('modules/leaderboard/src/classes')

local M = {}
local FONT = Theme.fonts.utility
local EMPHASIS_FONT = 'Consolas;Weight=Bold'
local ROW_HEIGHT = 56

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

-- Keep every column inside its own measured bounds, including custom class
-- names, compounds and the longer labels used by personal sessions.
local function fittedText(value, size, position, width, color)
  value = tostring(value or '')
  local measured = ui.measureDWriteText(value, size)
  text(value, size * math.min(1, width / math.max(1, measured.x)), position, color)
end

local function driverText(value, size, position, width, color, scroll, now)
  value = tostring(value or '')
  if value == '' then value = 'UNKNOWN DRIVER' end
  ui.pushDWriteFont(EMPHASIS_FONT)
  local measured = ui.measureDWriteText(value, size)
  ui.pushClipRect(position, position + vec2(width, measured.y))
  if measured.x > width and scroll then
    local span = measured.x + 28 * size / 24
    local offset = (now * 32 * size / 24) % span
    text(value, size, position - vec2(offset, 0), color)
    text(value, size, position + vec2(span - offset, 0), color)
  else
    if measured.x > width then
      -- Remove complete UTF-8 characters so truncation never splits a name.
      while #value > 0 and ui.measureDWriteText(value .. '...', size).x > width do
        local last = #value
        while last > 1 and value:byte(last) >= 128 and value:byte(last) < 192 do last = last - 1 end
        value = value:sub(1, last - 1)
      end
      value = value .. '...'
    end
    text(value, size, position, color)
  end
  ui.popClipRect()
  ui.popDWriteFont()
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

local function textRole(palette, name, alpha)
  return Theme.textColor(palette, name, alpha)
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

local function finiteNumber(value)
  value = tonumber(value)
  return value and value == value and value ~= math.huge and value ~= -math.huge and value or nil
end

local function formatMs(value)
  value = finiteNumber(value)
  if not value or value <= 0 then return '--.---' end
  local milliseconds = math.floor(value + 0.5)
  return string.format('%02d:%02d.%03d', math.floor(milliseconds / 60000),
    math.floor(milliseconds / 1000) % 60, milliseconds % 1000)
end

local function formatGap(value)
  value = finiteNumber(value)
  if value == nil then return '--.---' end
  return string.format('%s%.3f', value >= 0 and '+' or '-', math.floor(math.abs(value) + 0.5) / 1000)
end

local function rowStateColor(row, palette)
  if row.status == 'RET' then return textRole(palette, 'red') end
  if row.status == 'OFF' then return textRole(palette, 'secondary') end
  if row.status == 'PIT' then return textRole(palette, 'cyan') end
  if row.status == 'FIN' then return textRole(palette, 'green') end
  return textRole(palette, 'primary')
end

local function flagPulse(label, now)
  -- A 1.2 Hz opacity pulse is conspicuous without high-frequency flashing or
  -- large-area movement. CLEAR remains steady so only active race flags call attention.
  if not label or label == '' then return 1 end
  return 0.62 + 0.38 * (0.5 + 0.5 * math.sin((now or ui.time()) * math.pi * 2.4))
end

local function isAlertFlag(label)
  return label ~= nil and label ~= '' and label ~= 'GREEN' and label ~= 'CLEAR'
end

local function drawFlagAlert(origin, width, top, header, palette, scale, opacity, now)
  local flagColors = { yellow = 'flagYellow', red = 'red', blue = 'blue', white = 'white' }
  local colorName = flagColors[header.flagRole] or 'flagYellow'
  local pulse = flagPulse(header.flagLabel, now)
  local tl = vec2(origin.x + 22 * scale, top)
  local br = vec2(origin.x + (width - 22) * scale, top + 31 * scale)
  chamferRect(tl, br, 4 * scale, role(palette, colorName, 0.76 + 0.20 * pulse), role(palette, colorName, 1), 1.1 * scale)

  local label = tostring(header.flagLabel) .. ' FLAG   '
  local textColor = colorName == 'white' and role(palette, 'void', 1)
    or colorName == 'flagYellow' and rgbm(0.07, 0.055, 0.025, 1) or role(palette, 'white', 1)
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
  fittedText(h.typeLabel or 'WAIT', 29 * scale, origin + vec2(36 * scale, 34 * scale), 99 * scale, role(palette, 'primary', textOpacity))
  ui.drawLine(origin + vec2(145 * scale, 29 * scale), origin + vec2(145 * scale, 70 * scale), role(palette, 'outlineSoft', 0.98), 1 * scale)
  fittedText('TIME  ' .. (h.timeText or '--:--'), 18 * scale, origin + vec2(170 * scale, 38 * scale), 181 * scale, role(palette, 'primary', textOpacity))
  fittedText('LAP  ' .. (h.currentLapText or '--'), 18 * scale, origin + vec2(365 * scale, 38 * scale), 290 * scale, role(palette, 'primary', textOpacity))
  if snapshot.final == true then
    centered('FINAL', 13 * scale, origin + vec2(296 * scale, 87 * scale), textRole(palette, 'green', textOpacity))
  elseif snapshot.personal == true then
    centered('PERSONAL', 13 * scale, origin + vec2(296 * scale, 87 * scale), textRole(palette, 'secondary', labelOpacity))
  end
  if settings.showFlags ~= false then
    local flagColors = { green = 'green', yellow = 'flagYellow', red = 'red', blue = 'blue', white = 'white' }
    local flagColor = flagColors[h.flagRole] or 'green'
    local pulse = flagPulse(h.flagLabel, ui.time())
    local flagTL, flagBR = origin + vec2(32 * scale, 74 * scale), origin + vec2(230 * scale, 99 * scale)
    chamferRect(flagTL, flagBR, 4 * scale, role(palette, flagColor, (0.14 + 0.26 * pulse) * surfaceOpacity), role(palette, flagColor, 0.58 + 0.40 * pulse), 0.9 * scale)
    text('FLAG', 12 * scale, origin + vec2(42 * scale, 81 * scale), textRole(palette, 'secondary', labelOpacity))
    emphasizedText(h.flagLabel or 'CLEAR', 15 * scale, origin + vec2(92 * scale, 78 * scale), textRole(palette, flagColor, 1))
  end

  local lapTL, lapBR = origin + vec2(360 * scale, 72 * scale), origin + vec2(665 * scale, 100 * scale)
  chamferRect(lapTL, lapBR, 6 * scale, role(palette, 'panelRaised', surfaceOpacity), role(palette, 'amber', 0.96), 1.2 * scale)
  centered(h.lapsText or 'LAPS: --', 19 * scale, vec2((lapTL.x + lapBR.x) / 2, lapTL.y + 14 * scale), role(palette, 'amber', textOpacity))

  local fuelX, fuelY, fuelW, fuelH = origin.x + (width - 375) * scale, origin.y + 21 * scale, 350 * scale, 80 * scale
  if settings.showFuel == false then
    text(settings.lockWindow and 'LOCK' or 'MOVE', 9 * scale, origin + vec2((width - 54) * scale, 92 * scale), textRole(palette, 'secondary', opacity))
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
  local labels = { 'FUEL', 'AVG', 'EST' }
  local values = { fuel.available and (fuel.fuelText or 'N/A') or 'N/A', fuel.averageText or '--', fuel.estimatedLapsText or '--' }
  for i = 1, 3 do
    local cy = fuelY + (14 + (i - 1) * 26) * scale
    local labelSize, valueSize = 16 * scale, 24 * scale
    local measured = ui.measureDWriteText(values[i], valueSize)
    valueSize = valueSize * math.min(1, 196 * scale / math.max(1, measured.x))
    text(labels[i], labelSize, vec2(fuelX + 88 * scale, cy - ui.measureDWriteText(labels[i], labelSize).y / 2), textRole(palette, 'secondary', labelOpacity))
    text(values[i], valueSize, vec2(fuelX + 144 * scale, cy - ui.measureDWriteText(values[i], valueSize).y / 2), role(palette, 'primary', textOpacity))
  end
end

local sectorRoles = { PURPLE = 'flagPurple', GREEN = 'green', AMBER = 'amber', RED = 'red', NEUTRAL = 'secondary' }

local function drawSectors(left, top, row, snapshot, palette, scale, opacity)
  local sectors = row.sectors or {}
  -- Track layouts can have fewer than three sectors. Only draw entries
  -- actually presented by data, within its declared count and the UI cap.
  local count = math.floor(clamp(finiteNumber(row.sectorCount) or #sectors, 0, math.min(3, #sectors)))
  for i = 1, count do
    local sector = sectors[i]
    local colorRole = sectorRoles[sector.role] or 'secondary'
    if colorRole == 'flagPurple' and not palette.flagPurple then colorRole = palette.purple and 'purple' or 'secondary' end
    local color = role(palette, colorRole, opacity)
    local x, y = left + (346 + (i - 1) * 40) * scale, top + 11 * scale
    local active = sector.active == true and row.status ~= 'FIN' and snapshot.final ~= true
    chamferRect(vec2(x, y), vec2(x + 36 * scale, y + 30 * scale), 3 * scale,
      role(palette, 'panelRaised', 0.92 * opacity), active and color or role(palette, 'outlineDim', opacity), (active and 1.1 or 0.7) * scale)
    ui.pushDWriteFont(EMPHASIS_FONT)
    centered('S' .. i, 16 * scale, vec2(x + 18 * scale, y + 15 * scale), textRole(palette, colorRole, opacity))
    ui.popDWriteFont()
    if active then ui.drawCircleFilled(vec2(x + 32 * scale, y + 5 * scale), 2 * scale, color, 12) end
  end
end

local function signedDelta(value)
  value = finiteNumber(value)
  if value == nil then return '--' end
  value = math.floor(math.abs(value) + 0.5) * (value < 0 and -1 or 1)
  return string.format(value > 0 and '+%d' or '%d', value)
end

local function deltaColor(value, palette, opacity)
  value = finiteNumber(value) or 0
  return textRole(palette, value > 0 and 'green' or value < 0 and 'red' or 'secondary', opacity)
end

local function drawPositionBadge(x, y, size, value, palette, scale, isLocal)
  local accent = isLocal and role(palette, 'amber', 1) or role(palette, 'primary', 0.90)
  chamferRect(vec2(x, y), vec2(x + size, y + size), 5 * scale,
    isLocal and role(palette, 'amberDim', 0.92) or role(palette, 'panelRaised', 0.92), accent, 1.1 * scale)
  centered(value, 22 * scale, vec2(x + size / 2, y + size / 2), isLocal and role(palette, 'amber', 1) or role(palette, 'primary', 1))
end

local function drawRow(origin, scale, width, top, row, snapshot, settings, palette, opacity, now)
  local left, right = origin.x + 22 * scale, origin.x + (width - 22) * scale
  local bottom = top + (ROW_HEIGHT - 4) * scale
  local fill = row.isLocal and role(palette, 'amberDim', 0.55 * opacity) or role(palette, 'panel', 0.92 * opacity)
  chamferRect(vec2(left, top), vec2(right, bottom), 4 * scale, fill, role(palette, 'outlineDim', 0.78), 0.75 * scale)
  local flagRole = row.flagCauseKind == 'yellow' and 'flagYellow'
    or row.flagCauseKind == 'blue' and 'blue' or nil
  if flagRole and settings.showFlags ~= false then
    local pulse = 0.5 + 0.5 * math.sin(now * math.pi * 2.4)
    local alpha = (GeneralSettings.values.theme == 'light' and 0.18 or 0.22) + 0.08 * pulse
    chamferRect(vec2(left, top), vec2(right, bottom), 4 * scale,
      role(palette, flagRole, alpha * opacity),
      role(palette, flagRole, (0.65 + 0.30 * pulse) * opacity), 1.1 * scale)
  end
  if row.isLocal then ui.drawRectFilled(vec2(left + 2 * scale, top + 2 * scale), vec2(left + 4 * scale, bottom - 2 * scale), role(palette, 'amber', 0.95), 1 * scale) end

  drawPositionBadge(left + 10 * scale, top + 6 * scale, 40 * scale, row.position or '--', palette, scale, row.isLocal)
  local stateColor = rowStateColor(row, palette)
  local race = snapshot.header and snapshot.header.typeLabel == 'RACE'
  driverText(row.driver, 24 * scale, vec2(left + 104 * scale, top + 13 * scale), (race and 308 or 230) * scale,
    row.isLocal and textRole(palette, 'amber') or stateColor, settings.scrollLongNames, now)

  if settings.showClass ~= false then
    local classColor = Classes.colors[row.classID] or 'secondary'
    fittedText(row.classID and row.classID ~= 'UNKNOWN' and Classes.display(row.classID) or '--', 23 * scale,
      vec2(left + (race and 424 or 474) * scale, top + 14 * scale), (race and 78 or 58) * scale,
      Theme.textColor(palette, row.classID == 'UNKNOWN' and 'secondary' or classColor, opacity))
  end
  if settings.showCompound and row.tyreCompound and row.tyreCompound ~= '' then
    fittedText(row.tyreCompound, 14 * scale, vec2(left + (race and 510 or 540) * scale, top + 19 * scale),
      (race and 80 or 50) * scale, textRole(palette, 'cyan', opacity))
  end

  fittedText(row.status or '--', 23 * scale, vec2(left + 600 * scale, top + 14 * scale), 74 * scale, stateColor)
  if race then
    local change = finiteNumber(row.positionChangeDelta)
    local untilTime = finiteNumber(row.positionChangeUntil)
    local delta = change and change ~= 0 and untilTime and untilTime > now
      and change or finiteNumber(row.lapPositionDelta)
    -- One signed value beside the position: recent change first, otherwise
    -- the completed-lap balance. No explanatory line or unchanged-position 0.
    if delta and delta ~= 0 then
      ui.pushDWriteFont(EMPHASIS_FONT)
      fittedText(signedDelta(delta), 17 * scale,
        vec2(left + 58 * scale, top + 17 * scale),
        38 * scale, deltaColor(delta, palette, opacity))
      ui.popDWriteFont()
    end
    if not row.isLocal then
      fittedText(row.interval or '--', 23 * scale, vec2(left + 690 * scale, top + 14 * scale),
        128 * scale, textRole(palette, 'cyan', opacity))
    end
    fittedText(formatMs(row.lastLapTimeMs), 23 * scale, vec2(left + 834 * scale, top + 14 * scale),
      148 * scale, role(palette, 'primary', opacity))
  else
    drawSectors(left, top, row, snapshot, palette, scale, opacity)
    local best, reference = finiteNumber(row.bestLapTimeMs), finiteNumber(snapshot.sessionBest)
    local gap = best and best > 0 and reference and reference > 0 and best - reference or nil
    if gap ~= 0 then
      fittedText(formatGap(gap), 19 * scale, vec2(left + 690 * scale, top + 16 * scale),
        128 * scale, textRole(palette, 'amber', opacity))
    end
    local bestRole = row.sessionBest and 'flagPurple' or row.improvement and 'green' or 'primary'
    fittedText(formatMs(best), 19 * scale, vec2(left + 834 * scale, top + 16 * scale),
      148 * scale, textRole(palette, bestRole, opacity))
  end

end

local function drawDataState(origin, scale, snapshot, palette, opacity, visibleRows)
  if visibleRows > 0 then return end
  local y = origin.y + 154 * scale
  if snapshot.error then
    text('DATA ERROR', 12 * scale, origin + vec2(38 * scale, 154 * scale), role(palette, 'red', opacity))
    fittedText(snapshot.error, 10 * scale, origin + vec2(38 * scale, 173 * scale), 964 * scale, role(palette, 'red', opacity))
  else
    local label = snapshot.session and 'NO ACTIVE CARS' or 'WAITING FOR SESSION DATA'
    text(label, 12 * scale, vec2(origin.x + 38 * scale, y), textRole(palette, 'secondary', opacity))
  end
end

function M.draw(snapshot, settings, visual)
  snapshot = snapshot or {}
  settings, visual = settings or {}, visual or {}
  local palette = visual.palette or Theme.get(settings.theme)
  local width, height = ui.windowWidth(), ui.windowHeight()
  if width <= 0 or height <= 0 then return end
  local rows = snapshot.shownRows or {}
  if snapshot.personal == true then
    local personalRow = snapshot.localRow
    if not personalRow then
      for _, row in ipairs(snapshot.rows or rows) do
        if row.isLocal then personalRow = row break end
      end
    end
    if not personalRow then
      for _, row in ipairs(rows) do
        if row.isLocal then personalRow = row break end
      end
    end
    rows = personalRow and { personalRow } or (#rows == 1 and rows or {})
  end
  local limit = math.floor(clamp(finiteNumber(settings.maxRows) or 5, 3, 10) + 0.5)
  local visibleRows = math.min(#rows, snapshot.personal == true and 1 or limit)
  local alertActive = settings.showFlags ~= false and isAlertFlag(snapshot.header and snapshot.header.flagLabel)
  -- Reserve the flag strip even while clear, so its appearance never changes
  -- the centering, scale or position of the header and driver rows.
  local layoutHeight = 115 + math.max(1, visibleRows) * ROW_HEIGHT + 64
  -- Fit all selected rows and the alert into the available window, even when
  -- ten rows require a scale below the normal HUD preference minimum.
  local scale = math.min(math.max(0.55, finiteNumber(settings.hudScale) or 0.84), width / 1040, height / layoutHeight)
  local contentWidth, contentHeight = 1040 * scale, layoutHeight * scale
  local origin = vec2((width - contentWidth) / 2, (height - contentHeight) / 2)
  local opacity = 1 -- Per-element alpha; overall opacity is applied once below.
  local backdrop = 0.72 * 0.72 -- Keep the authored material strength.
  local now = ui.time()

  ui.pushStyleVarAlpha(visual.instrumentOpacity or 1)
  ui.pushDWriteFont(FONT)
  local enteredAt = finiteNumber(snapshot.enteredAt)
  local reveal = enteredAt and clamp((now - enteredAt) / 0.35, 0, 1) or 1
  local clipTop = origin.y + contentHeight * 0.5 - contentHeight * reveal * 0.5
  ui.pushClipRect(vec2(0, clipTop), vec2(width, clipTop + contentHeight * reveal))
  drawFrame(origin, contentWidth / scale, contentHeight / scale, palette, scale, backdrop)
  drawHeader(origin, scale, contentWidth / scale, snapshot, settings, palette, backdrop)
  local rowTop = origin.y + 115 * scale
  local rowHeight = ROW_HEIGHT * scale
  for i = 1, visibleRows do
    drawRow(origin, scale, contentWidth / scale, rowTop + (i - 1) * rowHeight, rows[i], snapshot, settings, palette, opacity, now)
  end
  if alertActive then
    drawFlagAlert(origin, contentWidth / scale, rowTop + math.max(1, visibleRows) * rowHeight + 5 * scale, snapshot.header, palette, scale, opacity, now)
  end
  drawDataState(origin, scale, snapshot, palette, opacity, visibleRows)
  ui.popClipRect()
  ui.popDWriteFont()
  ui.popStyleVar(1)
end

return M
