local M = {}
local SettingsUI = require('src/settings_ui')
local Classes = require('modules/leaderboard/src/classes')
local WindowAnchor = require('src/window_anchor')

M.values = ac.storage({
  settingsVersion = 1,
  hudScale = 0.84,
  automaticClasses = true,
  showClass = true,
  showCompound = false,
  showFlags = true,
  showConnection = true,
  scrollLongNames = false,
  maxRows = 5,
  sectorReference = 'General',
  positionChangeDuration = 40,
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

WindowAnchor.initialize('leaderboard', {
  anchored = M.values.lockWindow,
  x = M.values.lockX,
  y = M.values.lockY
})

local function clamp(value, minimum, maximum)
  return math.max(minimum, math.min(maximum, value))
end

local function checkbox(label, key)
  if ui.checkbox(label, M.values[key] == true) then M.values[key] = not M.values[key] end
end

local function anchorCheckbox()
  local anchored = WindowAnchor.isAnchored('leaderboard')
  if ui.checkbox('Lock in place (right-click HUD to toggle)', anchored) then
    local nextValue = not anchored
    if WindowAnchor.setAnchored('leaderboard', nextValue) then M.values.lockWindow = nextValue end
  end
end

local function slider(label, key, minimum, maximum, format)
  local value, changed = ui.slider(label, M.values[key] or minimum, minimum, maximum, format, 1)
  if changed then M.values[key] = value end
end

local function resetVisualSettings()
  M.values.hudScale = 0.84
end

local function resetAll()
  local ok, err = Classes.resetAll()
  if not ok then return false, err end
  resetVisualSettings()
  M.values.automaticClasses, M.values.showClass, M.values.showFlags = true, true, true
  M.values.showCompound, M.values.scrollLongNames = false, false
  M.values.showConnection = true
  M.values.maxRows, M.values.intervalRefresh = 5, 0.25
  M.values.sectorReference, M.values.positionChangeDuration = 'General', 40
  M.values.showFuel, M.values.fuelReserve, M.values.showLapEstimate = true, 2, true
  M.values.debug = false
  return true
end

function M.normalize()
  M.values.hudScale = clamp(tonumber(M.values.hudScale) or 0.84, 0.55, 1.20)
  M.values.maxRows = math.floor(clamp(tonumber(M.values.maxRows) or 5, 3, 10) + 0.5)
  M.values.sectorReference = M.values.sectorReference == 'Class' and 'Class' or 'General'
  M.values.positionChangeDuration = clamp(tonumber(M.values.positionChangeDuration) or 40, 1, 120)
  M.values.intervalRefresh = clamp(tonumber(M.values.intervalRefresh) or 0.25, 0.10, 1.00)
  M.values.fuelReserve = math.max(0, tonumber(M.values.fuelReserve) or 2)
  M.values.temperatureUnit = M.values.temperatureUnit == 'F' and 'F' or 'C'
  M.values.showConnection = M.values.showConnection ~= false
  M.values.lockX = tonumber(M.values.lockX) or -1
  M.values.lockY = tonumber(M.values.lockY) or -1
end

function M.draw()
  M.normalize()
  M.values.lockWindow = WindowAnchor.isAnchored('leaderboard')
  ui.header('Leaderboard')
  SettingsUI.section('leaderboard', 'basics', 'Basics', true, function()
    slider('HUD scale', 'hudScale', 0.55, 1.20, '%.2fx')
    slider('Maximum rows', 'maxRows', 3, 10, '%.0f rows')
    checkbox('Show fuel calculator', 'showFuel')
  end)
  SettingsUI.section('leaderboard', 'personalization', 'Personalization', false, function()
    ui.header('Columns')
    checkbox('Show class', 'showClass')
    checkbox('Show tyre compound', 'showCompound')
    checkbox('Show flag indicator', 'showFlags')
    checkbox('Show online connection quality', 'showConnection')
    checkbox('Scroll long driver names', 'scrollLongNames')
    slider('Interval refresh', 'intervalRefresh', 0.10, 1.00, '%.2fs')
    SettingsUI.choice('leaderboard', 'sectorReference', 'Sector comparison', M.values.sectorReference,
      {{value = 'General', label = 'General'}, {value = 'Class', label = 'Class'}},
      function(value) M.values.sectorReference = value end)
    slider('Position change visibility', 'positionChangeDuration', 1, 120, '%.0fs')
    if M.values.showFuel then
      ui.header('Fuel calculator')
      slider('Fuel reserve', 'fuelReserve', 0, 20, '%.1f L')
      checkbox('Timed-race lap estimate', 'showLapEstimate')
      ui.textWrapped('TANK is fuel as a percentage of tank capacity. RANGE is complete laps of fuel after subtracting your reserve, using the median consumption of up to five valid observed laps. FINISH is the estimated surplus or shortfall in litres at the finish, including your reserve.')
    end
  end)
  SettingsUI.section('leaderboard', 'advanced', 'Advanced', false, function()
    checkbox('Automatic class detection', 'automaticClasses')
    anchorCheckbox()
    checkbox('Developer debug view', 'debug')
    ui.textWrapped('Connection bars use smoothed ping: 5 at 60 ms or less, 4 up to 100, 3 up to 150, 2 up to 250, otherwise 1. Dim bars mean no data. AI and replays have no connection indicator.')
  end)
  ui.separator()
  SettingsUI.resetAppearance('leaderboard', resetVisualSettings)
  SettingsUI.resetAll('leaderboard', resetAll,
    'Restore local Leaderboard settings and class assignments? classes.ini is backed up in Documents first. Saved laps, window position and global settings are retained.')
end

return M
