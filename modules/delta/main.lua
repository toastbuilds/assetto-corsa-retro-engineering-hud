local GeneralSettings = require('src/general_settings')
local M = {}
local Constants = require('modules/delta/src/constants')
local Display = require('modules/delta/src/display')
local Settings = require('modules/delta/src/settings')
local State = require('modules/delta/src/state')
local Theme = require('modules/delta/src/theme')
local ThemeSync = require('modules/delta/src/theme_sync')

local APP_TITLE = 'Retro UI Delta Bar'
local state = State.new(Settings.values)
local themeSync = ThemeSync.new()
local initialized = false
local initializationError = nil
local initializationStatus = 'WAITING FOR TELEMETRY'
local nextInitializationAttempt = 0
local lastReportedError = nil
local appWindow = nil
local appWindowName = nil
local appWindowCheckedAt = -10
local lastResizeScale = nil
local lastPlacementPosition = nil
local lastAutoPlacement = false
local pinApplied = false

local function numberOr(value, fallback)
  value = tonumber(value)
  return value or fallback
end

local function errorText(value)
  local message = tostring(value)
  if type(debug) == 'table' and type(debug.traceback) == 'function' then
    return debug.traceback(message, 2)
  end
  return message
end

local function reportRuntimeError(stage, value)
  local message = '[' .. APP_TITLE .. '] ' .. stage .. ': ' .. tostring(value)
  if message == lastReportedError then return end
  lastReportedError = message
  if type(ac.error) == 'function' then
    pcall(ac.error, message)
  elseif type(ac.log) == 'function' then
    pcall(ac.log, message)
  end
end

local function count0(values)
  if values == nil then return 0 end
  local lengthOk, length = pcall(function() return #values end)
  if lengthOk and type(length) == 'number' and length > 0 then
    return math.floor(length)
  end
  if type(values) ~= 'table' then return 0 end
  if type(table.nkeys) == 'function' then
    local ok, count = pcall(table.nkeys, values)
    if ok and count then return count end
  end
  return 0
end

local function findWindow()
  local now = ui.time()
  if appWindow and now - appWindowCheckedAt < 1 then return appWindow end
  appWindowCheckedAt = now
  appWindow, appWindowName = nil, nil
  local ok, windows = pcall(ac.getAppWindows)
  if not ok or windows == nil then return nil end
  for i = 0, count0(windows) - 1 do
    local item = windows[i]
    if item and (item.title == APP_TITLE or item.name == APP_TITLE) then
      appWindowName = item.name
      if appWindowName then
        local accessOk, accessed = pcall(ac.accessAppWindow, appWindowName)
        if accessOk then appWindow = accessed end
      end
      break
    end
  end
  return appWindow
end

local function desiredSize()
  local scale = Settings.values.scale or 1
  local height
  if Settings.values.barOnly then
    height = 126
  elseif Settings.values.minimized then
    height = 100
  elseif Settings.values.showDetails == false then
    height = 126
  else
    height = 180
  end
  local uiInfo = ac.getUI()
  local uiScale = uiInfo and tonumber(uiInfo.uiScale) or 1
  return vec2(720 * scale * uiScale, height * scale * uiScale)
end

local function screenPosition(size)
  local sim = ac.getSim()
  local uiInfo = ac.getUI()
  local uiScale = uiInfo and tonumber(uiInfo.uiScale) or 1
  local screen = vec2(numberOr(sim.windowWidth, size.x), numberOr(sim.windowHeight, size.y))
  local padding = 50
  local top = 63
  local x = math.max(0, (screen.x - size.x) / 2)
  local y
  if Settings.values.position == Constants.Position.TOP then
    y = top
  elseif Settings.values.position == Constants.Position.BOTTOM then
    y = screen.y - size.y - padding
  else
    y = (screen.y - size.y) / 2
  end
  return vec2(math.max(0, x), math.max(0, y)) / uiScale
end

local function applyWindowLayout()
  local win = findWindow()
  if not win then return end
  local size = desiredSize()
  local scale = Settings.values.scale or 1
  if Settings.values.autoResize and (lastResizeScale == nil or math.abs(lastResizeScale - scale) > 0.001) then
    pcall(function() win:resize(size) end)
    lastResizeScale = scale
  end
  if Settings.values.autoPlacement and (not lastAutoPlacement or lastPlacementPosition ~= Settings.values.position) then
    pcall(function() win:move(screenPosition(size)) end)
    lastPlacementPosition = Settings.values.position
  end
  lastAutoPlacement = Settings.values.autoPlacement == true
  if not pinApplied then
    pcall(function() win:setPinned(Settings.values.locked == true) end)
    pinApplied = true
  end
end

local function initialize()
  if initialized then return end
  local now = ui.time()
  if now < nextInitializationAttempt then return end
  Settings.normalize()
  local ok, err = xpcall(function()
    return state:initialize()
  end, function(value)
    return errorText(value)
  end)
  if not ok then
    initializationError = tostring(err)
    initializationStatus = 'APP ERROR: ' .. initializationError:sub(1, 34)
    reportRuntimeError('initialization', initializationError)
    nextInitializationAttempt = now + 1
    return
  end
  if err ~= true then
    initializationError = nil
    initializationStatus = err or 'WAITING FOR TELEMETRY'
    nextInitializationAttempt = now + 0.25
    return
  end
  initialized = true
  initializationError = nil
  initializationStatus = 'READY'
  lastReportedError = nil
  pcall(function() ac.onSessionStart(function() state:onSessionStart() end) end)
  pcall(function() ac.onRelease(function() state:save() end, nil) end)
end

function M.update(dt)
  initialize()
  if initialized then
    local ok, err = pcall(function() state:update(dt) end)
    if not ok then reportRuntimeError('update', errorText(err)) end
  end
  applyWindowLayout()
end

function M.windowMain(_)
  initialize()
  local visualName, backdropOpacity, instrumentOpacity = themeSync:visual(ui.time())
  local visual = {
    palette = GeneralSettings.palette(Theme.get(visualName)),
    backdropOpacity = backdropOpacity,
    instrumentOpacity = instrumentOpacity
  }
  local snapshot = initialized and state:snapshot() or {
    mode = Constants.Modes.SESSION_LAP,
    modeLabel = Constants.ModeLabels[Constants.Modes.SESSION_LAP],
    modeShortLabel = Constants.ModeShortLabels[Constants.Modes.SESSION_LAP],
    timeDelta = nil,
    speedDelta = 0,
    star = '',
    sector = 0,
    sectorCount = 1,
    lapNumber = 0,
    message = initializationStatus,
    notification1 = nil,
    notification2 = nil
  }
  local events = Display.draw(snapshot, Settings.values, visual)
  if events and events.modeDelta ~= 0 and initialized then state:changeMode(events.modeDelta) end
end

function M.windowSettings(_)
  Settings.draw()
  lastResizeScale = nil
  if Settings.values.autoPlacement then lastPlacementPosition = nil end
  pinApplied = false
end

function M.windowShow(_) end
function M.windowHide(_) end

return M
