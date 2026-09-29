local Settings = {}
local SettingsUI = require('src/settings_ui')

local DEFAULTS = {
  layoutVersion = 1,
  scale = 1.0,
  opacity = 1.0,
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
  v.opacity = clamp(v.opacity, 0.45, 1.0, DEFAULTS.opacity)
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

local function percentSlider(label, key, minimum, maximum)
  local value, changed = ui.slider(label, (Settings.values[key] or minimum) * 100,
    minimum * 100, maximum * 100, '%.0f%%', 1)
  if changed then
    Settings.values[key] = value / 100
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
  SettingsUI.section('delta', 'appearance', 'Appearance', true, function()
    slider('Scale', 'scale', 0.65, 1.50, '%.2fx')
    percentSlider('Instrument opacity', 'opacity', 0.45, 1)
    SettingsUI.resetAppearance('delta', function()
      Settings.values.scale, Settings.values.opacity = DEFAULTS.scale, DEFAULTS.opacity
    end)
  end)
  SettingsUI.section('delta', 'layout', 'Layout and window', true, function()
    checkbox('Bar only', 'barOnly')
    checkbox('Minimized mode', 'minimized')
    if not Settings.values.barOnly then checkbox('Show detail section', 'showDetails') end
    SettingsUI.choice('delta', 'position', 'Position', Settings.values.position,
      { { label = 'Upper', value = 0 }, { label = 'Centered', value = 1 }, { label = 'Lower', value = 2 } },
      function(value) Settings.values.position = value end)
    checkbox('Pin / lock window', 'locked')
    checkbox('Auto-resize', 'autoResize')
    checkbox('Auto-placement', 'autoPlacement')
  end)
  SettingsUI.section('delta', 'notifications', 'Notifications', true, function()
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
  SettingsUI.section('delta', 'advanced', 'Advanced', false, function()
    checkbox('Save timing data on close', 'saveOnClose')
    SettingsUI.resetAll('delta', function()
      for key, value in pairs(DEFAULTS) do
        if key ~= 'layoutVersion' then Settings.values[key] = value end
      end
      Settings.lastChange = 'Settings reset'
    end, 'Restore every Delta setting? Saved lap records and CSP window position will stay unchanged.')
  end)
  Settings.normalize()
end

return Settings
