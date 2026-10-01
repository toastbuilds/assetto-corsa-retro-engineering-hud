local SettingsUI = require('src/settings_ui')

local Settings = {}

local DEFAULTS = {
  scale = 1.0,
  freezeDuration = 3.0,
  audioEnabled = true,
  autoPlacement = true,
  locked = false
}

local function clamp(value, minimum, maximum, fallback)
  value = tonumber(value)
  if not value then return fallback end
  return math.max(minimum, math.min(maximum, value))
end

local function makeValues()
  local ok, values = pcall(ac.storage, DEFAULTS, 'retro-ui.timer.')
  if ok and type(values) == 'table' then return values end
  local copy = {}
  for key, value in pairs(DEFAULTS) do copy[key] = value end
  return copy
end

Settings.values = makeValues()

function Settings.normalize()
  local v = Settings.values
  v.scale = clamp(v.scale, 0.65, 1.50, DEFAULTS.scale)
  v.freezeDuration = clamp(v.freezeDuration, 1.0, 8.0, DEFAULTS.freezeDuration)
  v.audioEnabled = v.audioEnabled ~= false
  v.autoPlacement = v.autoPlacement ~= false
  v.locked = v.locked == true
end

local function slider(label, key, minimum, maximum, format)
  local value, changed = ui.slider(label, Settings.values[key], minimum, maximum, format, 1)
  if changed then Settings.values[key] = value end
end

local function checkbox(label, key)
  if ui.checkbox(label, Settings.values[key]) then
    Settings.values[key] = not Settings.values[key]
  end
end

function Settings.draw()
  Settings.normalize()
  ui.header('Timer')
  SettingsUI.section('timer', 'basics', 'Basics', true, function()
    slider('HUD scale', 'scale', 0.65, 1.50, '%.2fx')
    slider('Result hold', 'freezeDuration', 1.0, 8.0, '%.1f s')
    checkbox('Sector record sound', 'audioEnabled')
  end)
  SettingsUI.section('timer', 'personalization', 'Personalization', false, function()
    checkbox('Auto-placement', 'autoPlacement')
    checkbox('Pin / lock window', 'locked')
  end)
  SettingsUI.section('timer', 'advanced', 'Advanced', false, function()
    ui.textWrapped('The sound is used only when you set a new absolute sector record for the current session.')
  end)
  ui.separator()
  SettingsUI.resetAppearance('timer', function() Settings.values.scale = DEFAULTS.scale end)
  SettingsUI.resetAll('timer', function()
    for key, value in pairs(DEFAULTS) do Settings.values[key] = value end
  end, 'Restore all local Timer settings? Global theme and opacity settings are retained.')
  Settings.normalize()
end

return Settings
