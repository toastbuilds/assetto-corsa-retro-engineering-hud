local M = {}
local Timing = require('modules/relative/src/timing')
local Relative = require('modules/relative/src/relative')
local Classes = require('modules/relative/src/classes')
local Theme = require('modules/relative/src/theme')
local Display = require('modules/relative/src/display')
local Weather = require('modules/relative/src/weather')
local Sectors = require('modules/relative/src/sectors')
local Records = require('modules/relative/src/records')
local GlobalSettings = require('src/settings')
local SettingsUI = require('src/settings_ui')
local FlagCause = require('src/flag_cause')

local settings = ac.storage({
  ahead = 3, behind = 3, mode = 0, showOverall = true, showClassPosition = false,
  showClassText = false, showNumber = true, showDriver = true, showGap = true,
  showPitIndicator = true, showLapDifference = true, showPits = true,
  showHeader = true, classMarkerWidth = 4,
  decimals = 1, maximumGap = 30, smoothing = 0.40, uiScale = 1.0, fontSize = 18,
  showRelative = true, showWeather = true, showTemperatures = true, showSectors = true,
  showRecords = true,
  temperatureUnit = 'C',
  automaticClasses = true, debug = false, visualStyleVersion = 0,
  backgroundColor = rgb(0.043, 0.035, 0.027), backgroundOpacity = 0.72,
  instrumentOpacity = 1, overallOpacity = 1,
  approachColor = rgb(1.00, 0.58, 0.12),
  showApproaching = true, approachRange = 8.0, approachRate = 0.20,
  classColorHY = Classes.colors.HY:clone(), classColorLMP1 = Classes.colors.LMP1:clone(),
  classColorLMP2 = Classes.colors.LMP2:clone(), classColorLMP3 = Classes.colors.LMP3:clone(),
  classColorGT3 = Classes.colors.GT3:clone(), classColorGT4 = Classes.colors.GT4:clone(),
  classColorGTE = Classes.colors.GTE:clone(), classColorTCR = Classes.colors.TCR:clone(),
  classColorTC = Classes.colors.TC:clone(), classColorCUP = Classes.colors.CUP:clone(),
  classColorUNKNOWN = Classes.colors.UNKNOWN:clone()
}, 'retro-ui.relative.')

-- Move the old default navy backdrop to the shared warm instrument palette,
-- while preserving a colour the user had already customized.
if (settings.visualStyleVersion or 0) < 1 then
  local color = settings.backgroundColor
  if color and math.abs(color.r - 0.025) < 0.001
      and math.abs(color.g - 0.030) < 0.001
      and math.abs(color.b - 0.045) < 0.001 then
    settings.backgroundColor = rgb(0.043, 0.035, 0.027)
  end
  settings.visualStyleVersion = 1
end

local function visualStyle()
  local overallOpacity = math.max(0, math.min(1, tonumber(settings.overallOpacity) or 1))
  return {
    palette = Theme.get(GlobalSettings.values.theme),
    backdropOpacity = settings.backgroundOpacity or 0.72,
    instrumentOpacity = (settings.instrumentOpacity or 1) * overallOpacity
  }
end

local timing = Timing.new()
local sectors = Sectors.new()
local records = Records.new()
local cars, player, shownAhead, shownBehind = {}, nil, {}, {}
local weatherSnapshot = {}
local telemetryError
local metadata, relativeMemory, approachMemory = {}, {}, {}
local telemetryAccumulator, previousSession, previousPlayerLap = 0, nil, nil
local classIDs = { 'HY', 'LMP1', 'LMP2', 'LMP3', 'GT3', 'GT4', 'GTE', 'TCR', 'TC', 'CUP', 'UNKNOWN' }

local function shorten(value, count)
  value = value or 'Unknown driver'
  return #value > count and value:sub(1, count - 1) .. '...' or value
end

local function classColor(classID)
  return settings['classColor' .. classID] or Classes.colors[classID] or Classes.colors.UNKNOWN
end

local function optionalField(source, key)
  if not source then return nil end
  local ok, value = pcall(function() return source[key] end)
  if ok then return value end
  return nil
end

local function textAt(value, size, x, y, color)
  ui.dwriteDrawText(tostring(value), size, vec2(x, y), color)
end

local function chamferRect(tl, br, fill, stroke, scale, chamfer, strokeWidth)
  local c = (chamfer or 7) * scale
  local function path()
    ui.pathClear()
    ui.pathLineTo(vec2(tl.x + c, tl.y)); ui.pathLineTo(vec2(br.x - c, tl.y))
    ui.pathLineTo(vec2(br.x, tl.y + c)); ui.pathLineTo(vec2(br.x, br.y - c))
    ui.pathLineTo(vec2(br.x - c, br.y)); ui.pathLineTo(vec2(tl.x + c, br.y))
    ui.pathLineTo(vec2(tl.x, br.y - c)); ui.pathLineTo(vec2(tl.x, tl.y + c))
  end
  path(); ui.pathFillConvex(fill)
  path(); ui.pathStroke(stroke, true, (strokeWidth or 1) * scale)
end

local function panel(x1, y1, x2, y2, palette, opacity, scale)
  chamferRect(vec2(x1, y1), vec2(x2, y2),
    Theme.withAlpha(palette.panel, 0.96 * opacity),
    Theme.withAlpha(palette.outline, 0.86 * opacity), scale)
end

local function drawRow(row, isPlayer, visual, x1, x2, y, fontSize, rowHeight, now)
  local color = classColor(row.classID)
  local palette = visual.palette
  local opacity = visual.instrumentOpacity
  local markerWidth = math.max(2, math.floor(settings.classMarkerWidth
    * fontSize / settings.fontSize + 0.5))
  local start = vec2(x1, y)
  local finish = vec2(x2, y + rowHeight - 2)
  local lapState = Relative.lapState(row, player)
  local flagColor = row.flagCauseKind == 'yellow' and palette.flagYellow
    or row.flagCauseKind == 'blue' and palette.blue or nil
  local flagPulse = flagColor and (0.5 + 0.5 * math.sin(now * math.pi * 2.4)) or 0
  local previousAlert = lapState ~= nil or row.approaching

  ui.drawRectFilled(start, finish, Theme.withAlpha(palette.panel, 0.92 * opacity))
  if isPlayer then
    ui.drawRectFilled(start, finish, Theme.withAlpha(palette.amberDim, 0.78 * opacity))
  elseif lapState == 'lapping_player' then
    ui.drawRectFilled(start, finish, Theme.fromRgb(palette.lapper, 0.28 * opacity))
  elseif lapState == 'being_lapped' then
    ui.drawRectFilled(start, finish, Theme.fromRgb(palette.lapped, 0.24 * opacity))
  elseif row.approaching then
    ui.drawRectFilled(start, finish, Theme.fromRgb(settings.approachColor, 0.34 * opacity))
  elseif row.filteredGap and math.abs(row.filteredGap) < 0.5 then
    ui.drawRectFilled(start, finish, Theme.fromRgb(color, 0.16 * opacity))
  end
  if flagColor and not previousAlert then
    local alpha = (palette == Theme.palettes.light and 0.18 or 0.22) + 0.08 * flagPulse
    ui.drawRectFilled(start, finish, Theme.withAlpha(flagColor, alpha * opacity))
  end

  ui.drawRectFilled(start, vec2(start.x + markerWidth, finish.y), Theme.fromRgb(color, 0.95 * opacity))
  if flagColor and previousAlert then
    ui.drawRect(start, finish, Theme.withAlpha(flagColor, (0.65 + 0.30 * flagPulse) * opacity),
      0, nil, 2 * fontSize / settings.fontSize)
  end
  ui.pushClipRect(vec2(x1 + markerWidth + 3, y), finish)
  textAt(Display.rowText(row, isPlayer, player, settings, x2 - x1, fontSize),
    fontSize, x1 + markerWidth + 7, y + math.max(1, (rowHeight - fontSize) / 2 - 1),
    Theme.withAlpha(palette.primary, opacity))
  ui.popClipRect()
end

local function drawSun(x, y, scale, color)
  ui.drawCircleFilled(vec2(x, y), 3.3 * scale, color, 12)
  for i = 0, 7 do
    local angle = i * math.pi / 4
    local dx, dy = math.cos(angle), math.sin(angle)
    ui.drawLine(vec2(x + dx * 5.2 * scale, y + dy * 5.2 * scale),
      vec2(x + dx * 7.6 * scale, y + dy * 7.6 * scale), color, scale)
  end
end

local function drawCloud(x, y, scale, color)
  ui.drawRectFilled(vec2(x - 5.5 * scale, y - 0.5 * scale),
    vec2(x + 6 * scale, y + 4 * scale), color)
  ui.drawCircleFilled(vec2(x - 2.5 * scale, y - 0.5 * scale), 3.3 * scale, color, 12)
  ui.drawCircleFilled(vec2(x + 2.5 * scale, y - 2 * scale), 4.1 * scale, color, 12)
end

local function drawDrop(x, y, scale, color)
  ui.pathClear()
  ui.pathLineTo(vec2(x, y - 6 * scale))
  ui.pathLineTo(vec2(x - 4 * scale, y + 1 * scale))
  ui.pathLineTo(vec2(x - 3.5 * scale, y + 4 * scale))
  ui.pathLineTo(vec2(x, y + 6 * scale))
  ui.pathLineTo(vec2(x + 3.5 * scale, y + 4 * scale))
  ui.pathLineTo(vec2(x + 4 * scale, y + 1 * scale))
  ui.pathFillConvex(color)
end

local function weatherColor(kind, palette, opacity)
  local role = (kind == 'sun' or kind == 'partly_cloudy') and 'amber'
    or (kind == 'rain' or kind == 'snow') and 'cyan'
    or kind == 'storm' and 'red' or 'secondary'
  return Theme.withAlpha(palette[role], opacity)
end

local function drawWeatherIcon(kind, x, y, scale, palette, opacity)
  kind = kind or 'unknown'
  local color = weatherColor(kind, palette, opacity)
  if kind == 'sun' then
    drawSun(x, y, scale, color)
  elseif kind == 'partly_cloudy' then
    drawSun(x - 3 * scale, y - 2 * scale, 0.65 * scale, color)
    drawCloud(x + 2 * scale, y + 2 * scale, scale, Theme.withAlpha(palette.secondary, opacity))
  elseif kind == 'unknown' then
    ui.drawCircle(vec2(x, y), 6 * scale, color, 12, scale)
    ui.drawLine(vec2(x - 3 * scale, y + 3 * scale), vec2(x + 3 * scale, y - 3 * scale), color, scale)
  elseif kind == 'wind' then
    for i = -1, 1 do
      ui.drawLine(vec2(x - 6 * scale, y + i * 4 * scale),
        vec2(x + (i == 0 and 7 or 3) * scale, y + i * 4 * scale), color, scale)
    end
  else
    drawCloud(x, y - 2 * scale, scale, color)
    if kind == 'rain' or kind == 'storm' then
      ui.drawLine(vec2(x - 3 * scale, y + 4 * scale), vec2(x - 5 * scale, y + 8 * scale), color, scale)
      ui.drawLine(vec2(x + 3 * scale, y + 4 * scale), vec2(x + 1 * scale, y + 8 * scale), color, scale)
      if kind == 'storm' then
        ui.drawLine(vec2(x + 6 * scale, y + 3 * scale), vec2(x + 3 * scale, y + 7 * scale), color, scale)
      end
    elseif kind == 'snow' then
      ui.drawCircleFilled(vec2(x - 3 * scale, y + 7 * scale), scale, color, 8)
      ui.drawCircleFilled(vec2(x + 3 * scale, y + 7 * scale), scale, color, 8)
    elseif kind == 'fog' then
      ui.drawLine(vec2(x - 6 * scale, y + 6 * scale), vec2(x + 6 * scale, y + 6 * scale), color, scale)
      ui.drawLine(vec2(x - 4 * scale, y + 9 * scale), vec2(x + 4 * scale, y + 9 * scale), color, scale)
    end
  end
end

local function drawThermometer(x, y, scale, color)
  ui.drawLine(vec2(x, y - 6 * scale), vec2(x, y + 2 * scale), color, 2 * scale)
  ui.drawCircleFilled(vec2(x, y + 4 * scale), 3 * scale, color, 10)
end

local function drawRoad(x, y, scale, color)
  ui.drawLine(vec2(x - 2 * scale, y - 6 * scale), vec2(x - 6 * scale, y + 6 * scale), color, scale)
  ui.drawLine(vec2(x + 2 * scale, y - 6 * scale), vec2(x + 6 * scale, y + 6 * scale), color, scale)
  ui.drawLine(vec2(x, y - 4 * scale), vec2(x, y - 1 * scale), color, scale)
  ui.drawLine(vec2(x, y + 2 * scale), vec2(x, y + 6 * scale), color, scale)
end

local function drawEnvironment(visual, x1, x2, y, scale)
  local palette, opacity = visual.palette, visual.instrumentOpacity
  local hasNext = settings.showWeather and weatherSnapshot.upcoming
    and not weatherSnapshot.stable
  local airText = Weather.temperatureText(weatherSnapshot.air, GlobalSettings.values.temperatureUnit)
  local trackText = Weather.temperatureText(weatherSnapshot.track, GlobalSettings.values.temperatureUnit)
  local rainText = Weather.rainText(weatherSnapshot.rain)
  local conditionWidth = settings.showWeather and (hasNext and 60 or 28) or 0
  local groups = {}
  if settings.showTemperatures then
    groups[#groups + 1] = { text = airText, kind = 'air', conditions = settings.showWeather }
    groups[#groups + 1] = { text = trackText, kind = 'track' }
  elseif settings.showWeather then
    groups[#groups + 1] = { conditions = true }
  end
  if settings.showWeather then groups[#groups + 1] = { text = rainText, kind = 'rain' } end
  if #groups == 0 then return end
  local cellWidth = (x2 - x1 - 16 * scale) / #groups
  local maximumWidth = 1
  for _, group in ipairs(groups) do
    group.width = (group.conditions and conditionWidth or 0)
      + (group.text and 26 + ui.measureDWriteText(group.text, 18).x or 0)
    maximumWidth = math.max(maximumWidth, group.width)
  end
  local start = x1 + 8 * scale
  local cy = y + 24 * scale
  scale = scale * math.min(1, (cellWidth - 8 * scale) / (maximumWidth * scale))
  local fontSize, iconScale = 18 * scale, 1.25 * scale
  local textY = cy - fontSize / 2
  for i, group in ipairs(groups) do
    local center = start + (i - 0.5) * cellWidth
    local x = center - group.width * scale / 2
    if group.conditions then
      drawWeatherIcon(weatherSnapshot.currentIcon, x + 11 * scale, cy, iconScale, palette, opacity)
      if hasNext then
        local arrow = Theme.withAlpha(palette.secondary, opacity)
        ui.drawLine(vec2(x + 24 * scale, cy), vec2(x + 36 * scale, cy), arrow, scale)
        ui.drawLine(vec2(x + 32 * scale, cy - 3 * scale), vec2(x + 36 * scale, cy), arrow, scale)
        ui.drawLine(vec2(x + 32 * scale, cy + 3 * scale), vec2(x + 36 * scale, cy), arrow, scale)
        drawWeatherIcon(weatherSnapshot.upcomingIcon, x + 48 * scale, cy, iconScale, palette, opacity)
      end
      x = x + conditionWidth * scale
    end
    if group.text then
      if group.kind == 'air' then
        drawThermometer(x + 10 * scale, cy, iconScale, Theme.withAlpha(palette.secondary, opacity))
      elseif group.kind == 'track' then
        drawRoad(x + 10 * scale, cy, iconScale, Theme.withAlpha(palette.cyan, opacity))
      else
        drawDrop(x + 10 * scale, cy, iconScale, Theme.withAlpha(palette.cyan, opacity))
      end
      textAt(group.text, fontSize, x + 26 * scale, textY, Theme.withAlpha(palette.primary, opacity))
    end
  end
end

local function drawTimingConditions(visual, x1, x2, y, height, scale)
  local palette, opacity = visual.palette, visual.instrumentOpacity
  panel(x1, y, x2, y + height, palette, opacity, scale)
  if settings.showSectors then
    local snapshot = sectors:snapshot(player and player.classID)
    local cellWidth = (x2 - x1 - 16 * scale) / 3
    local roles = { record = 'purple', improved = 'green', slower = 'amber', invalid = 'red' }
    for number = 1, 3 do
      local cx = x1 + 8 * scale + (number - 1) * cellWidth
      local status = snapshot.status[number]
      local color = palette[roles[status] or 'outlineDim']
      local active = snapshot.current == number
      local tl, br = vec2(cx, y + 4 * scale), vec2(cx + cellWidth - 4 * scale, y + 28 * scale)
      chamferRect(tl, br, Theme.withAlpha(status and color or palette.panelRaised, 0.14 * opacity),
        Theme.withAlpha(active and palette.primary or palette.outlineDim, opacity), scale, 3)
      ui.drawRectFilled(vec2(cx + 3 * scale, y + 24 * scale),
        vec2(br.x - 3 * scale, y + 27 * scale), Theme.withAlpha(color, opacity))
      local label = 'S' .. number .. (status == 'invalid' and '  X' or '')
      local labelWidth = ui.measureDWriteText(label, 12 * scale).x
      local labelX = cx + (cellWidth - 4 * scale - labelWidth) / 2
      textAt(label, 12 * scale, labelX, y + 7 * scale,
        Theme.withAlpha(active and palette.primary or status and color or palette.secondary, opacity))
      if active then
        ui.drawCircleFilled(vec2(labelX + labelWidth + 7 * scale, y + 14 * scale),
          2 * scale, Theme.withAlpha(palette.primary, opacity), 8)
      end
    end
  end
  if settings.showWeather or settings.showTemperatures then
    local environmentY = y + (settings.showSectors and 32 * scale or 0)
    if settings.showSectors then
      ui.drawLine(vec2(x1 + 8 * scale, environmentY), vec2(x2 - 8 * scale, environmentY),
        Theme.withAlpha(palette.outlineDim, opacity), scale)
    end
    drawEnvironment(visual, x1, x2, environmentY, scale)
  end
end

local function drawRecords(visual, x1, x2, y, scale)
  local palette, opacity = visual.palette, visual.instrumentOpacity
  local mid = (x1 + x2) / 2
  panel(x1, y, x2, y + 44 * scale, palette, opacity, scale)
  ui.drawLine(vec2(mid, y + 5 * scale), vec2(mid, y + 39 * scale),
    Theme.withAlpha(palette.outlineDim, opacity), scale)
  for i, item in ipairs({
    { label = 'SESSION RECORD', value = records.sessionBest, color = palette.green },
    { label = 'TRACK RECORD', value = records.trackBest, color = palette.purple }
  }) do
    local left, right = i == 1 and x1 or mid, i == 1 and mid or x2
    ui.pushClipRect(vec2(left + 4 * scale, y + 3 * scale), vec2(right - 4 * scale, y + 41 * scale))
    textAt(item.label, 10 * scale, left + 12 * scale, y + 4 * scale,
      Theme.withAlpha(palette.secondary, opacity))
    ui.drawRectFilled(vec2(left + 12 * scale, y + 21 * scale),
      vec2(left + 15 * scale, y + 36 * scale), Theme.withAlpha(item.color, opacity))
    local value = Records.timeText(item.value)
    local size = 20 * scale
    local textWidth = ui.measureDWriteText(value, size).x
    size = size * math.min(1, (right - left - 32 * scale) / math.max(1, textWidth))
    textAt(value, size, left + 23 * scale, y + 17 * scale,
      Theme.withAlpha(item.value and palette.primary or palette.secondary, opacity))
    ui.popClipRect()
  end
end

local function drawRelative(visual, x1, x2, top, bottom, scale)
  local palette = visual.palette
  local opacity = visual.instrumentOpacity
  local now = ui.time()
  panel(x1, top, x2, bottom, palette, opacity, scale)
  local innerX1, innerX2 = x1 + 7 * scale, x2 - 7 * scale
  local y = top + 9 * scale
  if settings.showRecords then
    drawRecords(visual, innerX1, innerX2, y, scale)
    y = y + 48 * scale
  end

  if telemetryError then
    textAt('TELEMETRY ERROR', 16 * scale, innerX1 + 6 * scale, y,
      Theme.withAlpha(palette.red, opacity))
    return
  end
  if not player then
    textAt('WAITING FOR TELEMETRY', 16 * scale, innerX1 + 6 * scale, y,
      Theme.withAlpha(palette.primary, opacity))
    return
  end

  local requiredChars = 2 + (settings.showOverall and 3 or 0)
    + (settings.showClassPosition and 3 or 0) + (settings.showClassText and 6 or 0)
    + (settings.showNumber and 4 or 0) + (settings.showDriver and 8 or 0)
    + (settings.showGap and 7 or 0) + 8
  local fontSize = math.max(10, math.min(settings.fontSize * scale,
    (innerX2 - innerX1 - 34) / (requiredChars * 0.56)))
  local rowHeight = math.max(22 * scale, math.floor(fontSize * 1.45)) + 2 * scale
  if settings.showHeader then
    ui.pushClipRect(vec2(innerX1, y), vec2(innerX2, y + fontSize + 3 * scale))
    textAt(Display.headerText(settings, innerX2 - innerX1, fontSize), fontSize,
      innerX1 + 9 * scale, y, Theme.withAlpha(palette.secondary, opacity))
    ui.popClipRect()
    y = y + fontSize + 4 * scale
  end
  local slots = math.max(1, math.floor((bottom - 8 * scale - y) / rowHeight))
  local extra = slots - 1
  local aheadCount = math.min(#shownAhead, math.ceil(extra / 2))
  local behindCount = math.min(#shownBehind, extra - aheadCount)
  aheadCount = math.min(#shownAhead, extra - behindCount)
  ui.pushClipRect(vec2(innerX1, y), vec2(innerX2, bottom - 7 * scale))
  for i = #shownAhead - aheadCount + 1, #shownAhead do
    drawRow(shownAhead[i], false, visual, innerX1, innerX2, y, fontSize, rowHeight, now)
    y = y + rowHeight
  end
  drawRow(player, true, visual, innerX1, innerX2, y, fontSize, rowHeight, now)
  y = y + rowHeight
  for i = 1, behindCount do
    drawRow(shownBehind[i], false, visual, innerX1, innerX2, y, fontSize, rowHeight, now)
    y = y + rowHeight
  end
  ui.popClipRect()
end

local function drawMain()
  local visual = visualStyle()
  local palette = visual.palette
  local opacity = visual.instrumentOpacity
  local width, height = ui.windowWidth(), ui.windowSize().y
  local relativeMinimum = 9
    + (settings.showRecords and 48 or 0)
    + (settings.showHeader and settings.fontSize + 4 or 0)
    + math.max(22, settings.fontSize * 1.45) + 10
  local showBottom = settings.showSectors or settings.showWeather or settings.showTemperatures
  local bottomUnits = (settings.showSectors and 32 or 0)
    + ((settings.showWeather or settings.showTemperatures) and 48 or 0)
  local minimumUnits = 26
    + (showBottom and bottomUnits + 7 or 0)
    + (settings.showRelative and relativeMinimum or 0)
  local scale = math.max(0.7, math.min(1.3, settings.uiScale or 1,
    height / minimumUnits, width / 420))
  ui.drawRectFilled(vec2(), ui.windowSize(), Theme.withAlpha(palette.void, visual.backdropOpacity * opacity))
  local frameTopLeft = vec2(7 * scale, 7 * scale)
  local frameBottomRight = vec2(width - 7 * scale, height - 7 * scale)
  chamferRect(frameTopLeft, frameBottomRight,
    Theme.withAlpha(palette.surface, 0.94 * opacity),
    Theme.withAlpha(palette.metal, 0.88 * opacity), scale, 10, 1.5)
  local inset = vec2(5 * scale, 5 * scale)
  chamferRect(frameTopLeft + inset, frameBottomRight - inset,
    Theme.withAlpha(palette.void, visual.backdropOpacity * 0.66 * opacity),
    Theme.withAlpha(palette.outlineDim, 0.86 * opacity), scale, 7, 0.8)
  local x1, x2 = 13 * scale, width - 13 * scale
  local bottomHeight = showBottom and bottomUnits * scale or 0
  local bottomY = height - 13 * scale - bottomHeight
  if settings.showRelative then
    drawRelative(visual, x1, x2, 13 * scale,
      bottomY - (showBottom and 7 * scale or 0), scale)
  end
  if showBottom then
    if not settings.showRelative then bottomY = 13 * scale end
    drawTimingConditions(visual, x1, x2, bottomY, bottomHeight, scale)
  end
end

local function updateApproachAlerts(now, dt)
  for _, row in ipairs(cars) do
    local state = approachMemory[row.index] or {}
    if row.filteredGap and state.gap and dt > 0 then
      local rawRate = (state.gap - row.filteredGap) / dt
      local alpha = 1 - math.exp(-dt / 0.35)
      state.rate = state.rate and state.rate + (rawRate - state.rate) * alpha or rawRate
    end
    state.gap, state.lastSeen = row.filteredGap, now
    approachMemory[row.index] = state
    row.closingRate = state.rate or 0
    row.approaching = settings.showApproaching and not row.inPitlane and row.filteredGap
      and row.filteredGap > 0 and row.filteredGap <= settings.approachRange
      and row.closingRate >= settings.approachRate and Classes.isFaster(row.classID, player.classID)
  end
  for index, state in pairs(approachMemory) do
    if state.lastSeen < now - 5 then approachMemory[index] = nil end
  end
end

local function metadataFor(car)
  local cached = metadata[car.index]
  local id = car:id()
  if cached and cached.id == id then return cached end
  local name = car:name()
  local classID, source = Classes.detect(id, name, settings.automaticClasses)
  cached = {
    id = id,
    name = name,
    driver = car:driverName(),
    number = car:driverNumber(),
    classID = classID,
    classSource = source
  }
  metadata[car.index] = cached
  ac.log('[MulticlassRelative] ' .. id .. ' -> ' .. classID .. ' (' .. source:lower() .. ')')
  return cached
end

local function updateTelemetry(dt)
  dt = dt or 0
  telemetryAccumulator = telemetryAccumulator + dt
  if telemetryAccumulator < 0.10 then return end
  local interval = telemetryAccumulator
  telemetryAccumulator = 0
  local sim, now = ac.getSim(), ui.time()
  local flagKind, flagIndex = FlagCause.resolve(sim)
  local conditions = optionalField(sim, 'weatherConditions')
  if not conditions and ac.getConditionsSet then
    local ok, value = pcall(ac.getConditionsSet)
    if ok then conditions = value end
  end
  weatherSnapshot = Weather.snapshot(sim, conditions, ac.WeatherType)
  local idOK, trackID = pcall(ac.getTrackFullID, '[]')
  local nameOK, trackName = pcall(ac.getTrackName)
  local playerCar = ac.getCar(0)
  local carOK, playerCarID = pcall(function() return playerCar:id() end)
  local contextChanged = records:setTrack(idOK and trackID or nil, nameOK and trackName or '',
    carOK and playerCarID or nil)
  local playerLap = playerCar and optionalField(playerCar, 'lapCount')
  local restarted = previousPlayerLap and playerLap and playerLap < previousPlayerLap
    and not optionalField(sim, 'isReplayActive')
  if contextChanged or restarted or (previousSession ~= nil and sim.currentSessionIndex ~= previousSession) then
    timing:reset(); sectors:reset(); metadata = {}; relativeMemory = {}; approachMemory = {}; previousPlayerLap = nil
    records:resetSession()
    ac.log('[MulticlassRelative] Session changed; timing history reset')
  end
  previousSession = sim.currentSessionIndex
  cars, player = {}, nil
  for _, car in ac.iterateCars() do
    -- CSP documents iterateCars() as the full grid iterator. isConnected is
    -- authoritative online; isActive keeps offline/AI entries usable.
    if car.index == 0 or car.isConnected or car.isActive then
      local lap, spline = math.max(0, car.lapCount or 0), math.max(0, math.min(1, car.splinePosition or 0))
      local static = metadataFor(car)
      local inPit = car.isInPitlane or car.isInPit
      local state, teleported = timing:update(car.index, now, lap, spline, inPit)
      local currentLapValid
      if optionalField(car, 'physicsAvailable') then currentLapValid = optionalField(car, 'isLapValid') end
      sectors:update(car.index, static.classID, {
        carID = static.id, lapCount = lap,
        currentSector = optionalField(car, 'currentSector'),
        previousSectorTime = optionalField(car, 'previousSectorTime')
          or optionalField(car, 'lastSectorTime'),
        previousLapTimeMs = optionalField(car, 'previousLapTimeMs'),
        isLastLapValid = optionalField(car, 'isLastLapValid'),
        lapTimeMs = optionalField(car, 'lapTimeMs'),
        isLapValid = currentLapValid,
        inPit = inPit, teleported = teleported
      }, now)
      if car.index == 0 then
        records:update({
          index = car.index, carID = static.id,
          bestLapTimeMs = optionalField(car, 'bestLapTimeMs'),
          previousLapTimeMs = optionalField(car, 'previousLapTimeMs'),
          isLastLapValid = optionalField(car, 'isLastLapValid'),
          teleported = teleported, replay = optionalField(sim, 'isReplayActive')
        })
      end
      local row = {
        index = car.index, driver = static.driver, number = static.number, carID = static.id,
        classID = static.classID, classSource = static.classSource, overall = car.racePosition or 0,
        lap = lap, spline = spline, progress = state.progress, inPitlane = inPit,
        connected = car.isConnected, speedKmh = car.speedKmh or 0
      }
      if row.index ~= 0 and row.index == flagIndex then row.flagCauseKind = flagKind end
      table.insert(cars, row)
      if car.index == 0 then player = row end
    end
  end
  previousPlayerLap = player and player.lap or previousPlayerLap
  timing:prune(now)
  sectors:prune(now)
  if player then
    table.sort(cars, function(a, b) return a.progress > b.progress end)
    -- Keep class data live regardless of presentation settings: filtering,
    -- positions, colours and approach warnings all depend on it.
    local positions = {}
    for _, row in ipairs(cars) do
      positions[row.classID] = (positions[row.classID] or 0) + 1
      row.classPosition = positions[row.classID]
    end
    shownAhead, shownBehind = Relative.build(cars, player, timing, now, settings, interval, relativeMemory)
    Relative.pruneMemory(relativeMemory, now)
    updateApproachAlerts(now, interval)
  end
end

function M.update(dt)
  if telemetryError then return end
  local ok, err = pcall(function()
    Relative.clampSettings(settings)
    updateTelemetry(dt)
  end)
  if not ok then
    telemetryError = tostring(err)
    ac.error('[MulticlassRelative] update error: ' .. telemetryError)
  end
end

function M.windowMain(_)
  local ok, err = pcall(drawMain)
  if not ok then
    local message = tostring(err)
    ac.error('[MulticlassRelative] draw error: ' .. message)
    ui.text('MULTICLASS RELATIVE')
    ui.text('DRAW ERROR')
    ui.text(message)
  end
end

function M.getTemperatureUnit() return settings.temperatureUnit end

local function resetAppearance()
  settings.uiScale, settings.overallOpacity = 1, 1
  settings.backgroundOpacity, settings.instrumentOpacity = 0.72, 1
  settings.fontSize, settings.classMarkerWidth = 18, 4
  settings.approachColor = rgb(1, 0.58, 0.12)
  for _, classID in ipairs(classIDs) do
    settings['classColor' .. classID] = Classes.colors[classID]:clone()
  end
end

local function resetAll()
  local ok, err = Classes.resetAll()
  if not ok then return false, err end
  resetAppearance()
  settings.ahead, settings.behind, settings.mode = 3, 3, 0
  settings.showOverall, settings.showClassPosition, settings.showClassText = true, false, false
  settings.showNumber, settings.showDriver, settings.showGap = true, true, true
  settings.showPitIndicator, settings.showLapDifference, settings.showPits = true, true, true
  settings.showHeader, settings.showRelative = true, true
  settings.showWeather, settings.showTemperatures, settings.showSectors = true, true, true
  settings.showRecords = true
  settings.decimals, settings.maximumGap, settings.smoothing = 1, 30, 0.4
  settings.automaticClasses, settings.debug = true, false
  settings.showApproaching, settings.approachRange, settings.approachRate = true, 8, 0.2
  metadata, relativeMemory, approachMemory = {}, {}, {}
  sectors:reset()
  return true
end

function M.windowSettings()
  ui.header('Relative')
  SettingsUI.section('relative', 'appearance', 'Appearance', true, function()
    settings.uiScale = ui.slider('Panel scale', settings.uiScale, 0.70, 1.30, '%.2fx')
    local opacity, changed = ui.slider('Overall opacity', (settings.overallOpacity or 1) * 100,
      0, 100, '%.0f%%', 1)
    if changed then settings.overallOpacity = opacity / 100 end
    settings.backgroundOpacity = ui.slider('Backdrop opacity', settings.backgroundOpacity, 0.18, 0.95, '%.2f')
    settings.instrumentOpacity = ui.slider('Instrument opacity', settings.instrumentOpacity, 0.45, 1, '%.2f')
    settings.fontSize = ui.slider('Font size', settings.fontSize, 12, 32, '%.0f px')
    settings.classMarkerWidth = ui.slider('Class marker width', settings.classMarkerWidth, 2, 8, '%.0f px')
    SettingsUI.resetAppearance('relative', resetAppearance)
  end)
  SettingsUI.section('relative', 'grid', 'Grid and columns', true, function()
    if ui.checkbox('Show relative', settings.showRelative) then settings.showRelative = not settings.showRelative end
    settings.ahead = ui.slider('Cars ahead', settings.ahead, 1, 10, '%.0f')
    settings.behind = ui.slider('Cars behind', settings.behind, 1, 10, '%.0f')
    SettingsUI.choice('relative', 'mode', 'Cars', settings.mode,
      { { label = 'All cars', value = 0 }, { label = 'Same class', value = 1 } },
      function(value) settings.mode = value end)
    for _, item in ipairs({
      { 'Overall position', 'showOverall' }, { 'Class position', 'showClassPosition' },
      { 'Class name', 'showClassText' }, { 'Car number', 'showNumber' },
      { 'Driver name', 'showDriver' }, { 'Gap', 'showGap' },
      { 'Pit indicator', 'showPitIndicator' }, { 'Lap difference', 'showLapDifference' },
      { 'Cars in pits', 'showPits' }, { 'Header', 'showHeader' }
    }) do
      if ui.checkbox(item[1], settings[item[2]]) then settings[item[2]] = not settings[item[2]] end
    end
  end)
  SettingsUI.section('relative', 'conditions', 'Weather, sectors and timing', true, function()
    for _, item in ipairs({ { 'Weather', 'showWeather' }, { 'Air and track temperatures', 'showTemperatures' },
        { 'Sector colors', 'showSectors' }, { 'Session and track records', 'showRecords' } }) do
      if ui.checkbox(item[1], settings[item[2]]) then settings[item[2]] = not settings[item[2]] end
    end
    ui.textWrapped('Sector colors: purple = class best, green = personal best, amber = slower, red/X = invalid. The outline and dot mark the active sector.')
    ui.textWrapped('Session record: your fastest valid lap this session. Track record: your fastest locally recorded lap across sessions with this car on this track layout.')
    settings.decimals = ui.slider('Gap decimals', settings.decimals, 1, 3, '%.0f')
    settings.maximumGap = ui.slider('Maximum gap', settings.maximumGap, 5, 90, '%.0fs')
    settings.smoothing = ui.slider('Gap smoothing', settings.smoothing, 0.05, 1.5, '%.2fs')
  end)
  SettingsUI.section('relative', 'classes', 'Classes and warnings', false, function()
    if ui.checkbox('Automatic class detection', settings.automaticClasses) then
      settings.automaticClasses = not settings.automaticClasses
      metadata = {}; sectors:reset()
    end
    if ui.checkbox('Faster-class warning', settings.showApproaching) then settings.showApproaching = not settings.showApproaching end
    if settings.showApproaching then
      settings.approachRange = ui.slider('Warning range', settings.approachRange, 2, 20, '%.1fs')
      settings.approachRate = ui.slider('Minimum closing rate', settings.approachRate, 0.05, 2, '%.2f s/s')
    end
    ui.text('Warning color'); ui.sameLine(); ui.colorButton('##approach', settings.approachColor, ui.ColorPickerFlags.PickerHueBar)
    for _, classID in ipairs(classIDs) do
      ui.text(classID); ui.sameLine(110)
      ui.colorButton('##classColor' .. classID, classColor(classID), ui.ColorPickerFlags.PickerHueBar)
    end
  end)
  SettingsUI.section('relative', 'advanced', 'Advanced', false, function()
    if ui.checkbox('Developer debug view', settings.debug) then settings.debug = not settings.debug end
    ui.text('Detected cars: click to change their class.')
    if #cars == 0 then ui.text('No cars detected in the current session.') end
    local choices = { 'UNKNOWN', 'HY', 'LMP1', 'LMP2', 'LMP3', 'GT3', 'GT4', 'GTE', 'TCR', 'TC', 'CUP' }
    for _, row in ipairs(cars) do
      if ui.button(shorten(row.carID, 27) .. ' -> ' .. row.classID .. '##class' .. row.index) then
        local n = 1
        for i, value in ipairs(choices) do if value == row.classID then n = i % #choices + 1 end end
        Classes.setOverride(row.carID, choices[n]); metadata[row.index] = nil
        sectors:reset()
      end
    end
    SettingsUI.resetAll('relative', resetAll,
      'Restore all Relative settings and class assignments? classes.ini will be backed up in Documents first. Lap records and CSP window position stay unchanged.')
  end)
end

return M
