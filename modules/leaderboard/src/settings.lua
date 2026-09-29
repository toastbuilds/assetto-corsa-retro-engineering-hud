local M = {}
local SettingsUI = require('src/settings_ui')
local Classes = require('modules/leaderboard/src/classes')

M.values = ac.storage({
  settingsVersion = 1,
  hudScale = 0.84,
  instrumentOpacity = 1.0,
  backdropOpacity = 0.72,
  fallbackTheme = 'dark',
  automaticClasses = true,
  showClass = true,
  showCompound = false,
  showFlags = true,
  scrollLongNames = false,
  maxRows = 5,
  intervalRefresh = 0.25,
  showFuel = true,
  fuelReserve = 2.0,
  showLapEstimate = true,
  temperatureUnit = 'C',
  lockWindow = false,
  lockX = -1,
  lockY = -1,
  debug = false
}, 'retro-ui.leaderboard.')

local function clamp(value, minimum, maximum)
  return math.max(minimum, math.min(maximum, value))
end

local function checkbox(label, key)
  if ui.checkbox(label, M.values[key] == true) then M.values[key] = not M.values[key] end
end

local function slider(label, key, minimum, maximum, format)
  local value, changed = ui.slider(label, M.values[key] or minimum, minimum, maximum, format, 1)
  if changed then M.values[key] = value end
end

local function percentageSlider(label, key, minimum, maximum)
  local value, changed = ui.slider(label, (M.values[key] or minimum) * 100,
    minimum * 100, maximum * 100, '%.0f%%', 1)
  if changed then M.values[key] = value / 100 end
end

local function resetVisualSettings()
  M.values.hudScale = 0.84
  M.values.instrumentOpacity = 1.0
  M.values.backdropOpacity = 0.72
  M.values.fallbackTheme = 'dark'
end

local function resetAll()
  local ok, err = Classes.resetAll()
  if not ok then return false, err end
  resetVisualSettings()
  M.values.automaticClasses, M.values.showClass, M.values.showFlags = true, true, true
  M.values.showCompound, M.values.scrollLongNames = false, false
  M.values.maxRows, M.values.intervalRefresh = 5, 0.25
  M.values.showFuel, M.values.fuelReserve, M.values.showLapEstimate = true, 2, true
  M.values.lockWindow, M.values.debug = false, false
  return true
end

function M.normalize()
  M.values.hudScale = clamp(tonumber(M.values.hudScale) or 0.84, 0.55, 1.20)
  M.values.instrumentOpacity = clamp(tonumber(M.values.instrumentOpacity) or 1, 0, 1)
  M.values.backdropOpacity = clamp(tonumber(M.values.backdropOpacity) or 0.72, 0.18, 0.95)
  M.values.maxRows = math.floor(clamp(tonumber(M.values.maxRows) or 5, 3, 5) + 0.5)
  M.values.intervalRefresh = clamp(tonumber(M.values.intervalRefresh) or 0.25, 0.10, 1.00)
  M.values.fuelReserve = math.max(0, tonumber(M.values.fuelReserve) or 2)
  M.values.fallbackTheme = M.values.fallbackTheme == 'light' and 'light' or 'dark'
  M.values.temperatureUnit = M.values.temperatureUnit == 'F' and 'F' or 'C'
  M.values.lockX = tonumber(M.values.lockX) or -1
  M.values.lockY = tonumber(M.values.lockY) or -1
end

function M.draw()
  M.normalize()
  ui.header('Leaderboard')
  SettingsUI.section('leaderboard', 'appearance', 'Appearance', true, function()
    slider('HUD scale', 'hudScale', 0.55, 1.20, '%.2fx')
    percentageSlider('Backdrop opacity', 'backdropOpacity', 0.18, 0.95)
    percentageSlider('Instrument opacity', 'instrumentOpacity', 0.55, 1.00)
    SettingsUI.resetAppearance('leaderboard', resetVisualSettings)
  end)
  SettingsUI.section('leaderboard', 'rows', 'Columns and rows', true, function()
    checkbox('Show class', 'showClass')
    checkbox('Show tyre compound', 'showCompound')
    checkbox('Show flag indicator', 'showFlags')
    checkbox('Scroll long driver names', 'scrollLongNames')
    slider('Maximum rows', 'maxRows', 3, 5, '%.0f rows')
    slider('Interval refresh', 'intervalRefresh', 0.10, 1.00, '%.2fs')
  end)
  SettingsUI.section('leaderboard', 'fuel', 'Fuel calculator', true, function()
    checkbox('Show fuel calculator', 'showFuel')
    if M.values.showFuel then slider('Fuel reserve', 'fuelReserve', 0, 20, '%.1f L') end
    checkbox('Timed-race lap estimate', 'showLapEstimate')
  end)
  SettingsUI.section('leaderboard', 'advanced', 'Advanced', false, function()
    checkbox('Automatic class detection', 'automaticClasses')
    checkbox('Lock overlay position', 'lockWindow')
    checkbox('Developer debug view', 'debug')
    SettingsUI.resetAll('leaderboard', resetAll,
      'Restore all Leaderboard settings and class assignments? classes.ini will be backed up in Documents first. Lap records and CSP window position stay unchanged.')
  end)
end

return M
