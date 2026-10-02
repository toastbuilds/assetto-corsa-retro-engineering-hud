local SettingsUI = require('src/settings_ui')
local Edition = require('src/edition')

local Settings = {}

local DEFAULTS = {
  scale = 1.0,
  rows = 10,
  animateLapChanges = true,
  autoPlacement = true,
  locked = false
}

local function clamp(value, minimum, maximum, fallback)
  value = tonumber(value)
  if not value then return fallback end
  return math.max(minimum, math.min(maximum, value))
end

local function makeValues()
  local ok, values = pcall(ac.storage, DEFAULTS, 'retro-ui.laps.')
  if ok and type(values) == 'table' then return values end
  local copy = {}
  for key, value in pairs(DEFAULTS) do copy[key] = value end
  return copy
end

Settings.values = makeValues()

function Settings.normalize()
  local v = Settings.values
  v.scale = clamp(v.scale, 0.65, 1.50, DEFAULTS.scale)
  v.rows = math.floor(clamp(v.rows, 5, 10, DEFAULTS.rows) + 0.5)
  v.animateLapChanges = v.animateLapChanges ~= false
  v.autoPlacement = v.autoPlacement ~= false
  v.locked = v.locked == true
end

local function slider(label, key, minimum, maximum, format)
  local value, changed = ui.slider(label, Settings.values[key], minimum, maximum, format, 1)
  if changed then Settings.values[key] = value end
end

local function checkbox(label, key)
  if ui.checkbox(label, Settings.values[key]) then Settings.values[key] = not Settings.values[key] end
end

function Settings.draw()
  Settings.normalize()
  ui.header('Laps')
  SettingsUI.section('laps', 'basics', 'Basics', true, function()
    slider('HUD scale', 'scale', 0.65, 1.50, '%.2fx')
    slider('Visible rows', 'rows', 5, 10, '%.0f')
  end)
  SettingsUI.section('laps', 'personalization', 'Personalization', false, function()
    checkbox('Auto-placement', 'autoPlacement')
    checkbox('Pin / lock window', 'locked')
    if Edition.premium then checkbox('Animate lap changes', 'animateLapChanges') end
  end)
  SettingsUI.section('laps', 'advanced', 'Advanced', false, function()
    ui.textWrapped('The first row shows track progress, colored by projected lap pace. Completed laps show their times, newest first.')
  end)
  ui.separator()
  SettingsUI.resetAppearance('laps', function() Settings.values.scale = DEFAULTS.scale end)
  SettingsUI.resetAll('laps', function()
    for key, value in pairs(DEFAULTS) do Settings.values[key] = value end
  end, 'Restore all local Laps settings? Global theme and opacity settings are retained.')
  Settings.normalize()
end

return Settings
