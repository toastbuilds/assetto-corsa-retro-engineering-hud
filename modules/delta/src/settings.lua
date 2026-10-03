local Settings = {}
local SettingsUI = require('src/settings_ui')

local DEFAULTS = {
  layoutVersion = 1,
  scale = 1.0,
  notificationDuration = 8.0,
  animationDuration = 0.20,
  minimized = false,
  showDetails = true,
  barOnly = false,
  position = 1,
  locked = false,
  autoResize = true,
  autoPlacement = true,
  saveOnClose = false,
  practiceMode = 0,
  qualifyMode = 0,
  raceMode = 0,
  showSectorNotifications = true,
  showLapNotifications = true,
  showRecordNotifications = true
}

local function clamp(value, minimum, maximum, fallback)
  value = tonumber(value)
  if not value then return fallback end
  return math.max(minimum, math.min(maximum, value))
end

local function makeValues()
  local ok, values = pcall(ac.storage, DEFAULTS, 'retro-ui.delta.')
  if ok and type(values) == 'table' then return values end
  local copy = {}
  for key, value in pairs(DEFAULTS) do copy[key] = value end
  return copy
end

Settings.values = makeValues()
Settings.lastChange = 'READY'

function Settings.normalize()
  local v = Settings.values
  v.scale = clamp(v.scale, 0.65, 1.50, DEFAULTS.scale)
  v.notificationDuration = clamp(v.notificationDuration, 2, 40, DEFAULTS.notificationDuration)
  v.animationDuration = clamp(v.animationDuration, 0.08, 0.60, DEFAULTS.animationDuration)
  v.position = math.floor(clamp(v.position, 0, 2, DEFAULTS.position))
  v.practiceMode = math.floor(clamp(v.practiceMode, 0, 6, 0))
  v.qualifyMode = math.floor(clamp(v.qualifyMode, 0, 6, 0))
  v.raceMode = math.floor(clamp(v.raceMode, 0, 6, 0))
  v.minimized = v.minimized == true
  v.showDetails = v.showDetails ~= false
  v.barOnly = v.barOnly == true
  v.locked = v.locked == true
  v.autoResize = v.autoResize ~= false
  v.autoPlacement = v.autoPlacement ~= false
  v.saveOnClose = v.saveOnClose == true
  v.showSectorNotifications = v.showSectorNotifications ~= false
  v.showLapNotifications = v.showLapNotifications ~= false
  v.showRecordNotifications = v.showRecordNotifications ~= false
end

local function slider(label, key, minimum, maximum, format)
  local value, changed = ui.slider(label, Settings.values[key], minimum, maximum, format, 1)
  if changed then
    Settings.values[key] = value
    Settings.lastChange = label
  end
end

local function checkbox(label, key)
  if ui.checkbox(label, Settings.values[key]) then
    Settings.values[key] = not Settings.values[key]
    Settings.lastChange = label
  end
end

local modeChoices = {
  [0] = "DON'T CHANGE",
  'SESSION LAP',
  'SESSION OPTIMAL',
  'FASTEST LAP',
  'FASTEST OPTIMAL',
  'PREVIOUS LAP',
  'MULTIPLAYER LAP'
}

local function sessionMode(label, key)
  ui.text(label)
  local value, changed = ui.combo('##' .. key, Settings.values[key], ui.ComboFlags.None, modeChoices)
  if changed then
    Settings.values[key] = value
    Settings.lastChange = label
  end
end

function Settings.draw()
  Settings.normalize()
  ui.header('Delta')
  SettingsUI.section('delta', 'basics', 'Basics', true, function()
    slider('HUD scale', 'scale', 0.65, 1.50, '%.2fx')
    checkbox('Bar only', 'barOnly')
    if not Settings.values.barOnly then
      checkbox('Minimized mode', 'minimized')
      checkbox('Show detail section', 'showDetails')
    end
  end)
  SettingsUI.section('delta', 'personalization', 'Personalization', false, function()
    SettingsUI.section('delta', 'layout', 'Window', true, function()
      SettingsUI.choice('delta', 'position', 'Position', Settings.values.position,
        {{label='Upper', value=0}, {label='Centered', value=1}, {label='Lower', value=2}},
        function(value) Settings.values.position = value end)
      checkbox('Stay visible when mouse leaves', 'locked')
      checkbox('Auto-resize', 'autoResize')
      checkbox('Auto-placement', 'autoPlacement')
    end)
    SettingsUI.section('delta', 'notifications', 'Notifications', false, function()
      checkbox('Sector notifications', 'showSectorNotifications')
      checkbox('Lap notifications', 'showLapNotifications')
      checkbox('Multiplayer record notifications', 'showRecordNotifications')
      slider('Notification duration', 'notificationDuration', 2, 40, '%.1f s')
      slider('Animation duration', 'animationDuration', 0.08, 0.60, '%.2f s')
    end)
    SettingsUI.section('delta', 'sessions', 'Default mode by session', false, function()
      sessionMode('Practice', 'practiceMode')
      sessionMode('Qualify', 'qualifyMode')
      sessionMode('Race', 'raceMode')
    end)
  end)
  SettingsUI.section('delta', 'advanced', 'Advanced', false, function()
    checkbox('Save timing data on close', 'saveOnClose')
  end)
  ui.separator()
  SettingsUI.resetAppearance('delta', function() Settings.values.scale = DEFAULTS.scale end)
  SettingsUI.resetAll('delta', function()
    for key, value in pairs(DEFAULTS) do if key ~= 'layoutVersion' then Settings.values[key] = value end end
    Settings.lastChange = 'Settings reset'
  end, 'Restore all local Delta settings? Saved laps, window position and global settings are retained.')
  Settings.normalize()
end

return Settings
