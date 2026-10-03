local SettingsUI = require('src/settings_ui')
local Audio = require('modules/timer/src/audio')

local Settings = {}
local previewFailed = false

local DEFAULTS = {
  scale = 1.0,
  backgroundOpacity = 0.70,
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
  v.backgroundOpacity = clamp(v.backgroundOpacity, 0, 1, DEFAULTS.backgroundOpacity)
  v.freezeDuration = clamp(v.freezeDuration, 1.0, 8.0, DEFAULTS.freezeDuration)
  v.audioEnabled = v.audioEnabled ~= false
  v.autoPlacement = v.autoPlacement ~= false
  v.locked = v.locked == true
end

local function slider(label, key, minimum, maximum, format)
  local value, changed = ui.slider(label, Settings.values[key], minimum, maximum, format, 1)
  if changed then Settings.values[key] = value end
end

local function percentSlider(label, key)
  local value, changed = ui.slider(label, Settings.values[key] * 100, 0, 100, '%.0f%%', 1)
  if changed then Settings.values[key] = value / 100 end
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
    percentSlider('Background opacity', 'backgroundOpacity')
    slider('Result hold', 'freezeDuration', 1.0, 8.0, '%.1f s')
    checkbox('Lap and sector sounds', 'audioEnabled')
    if ui.button('Test sector sound##timer.test-sector-sound') then previewFailed = not Audio.playSectorRecord() end
    if ui.button('Test lap sound##timer.test-lap-sound') then previewFailed = not Audio.playLapCompleted() end
    if previewFailed then ui.textWrapped('Could not play the record sound. Reload Retro UI and try again.') end
  end)
  SettingsUI.section('timer', 'personalization', 'Personalization', false, function()
    checkbox('Auto-placement', 'autoPlacement')
    checkbox('Stay visible when mouse leaves', 'locked')
  end)
  SettingsUI.section('timer', 'advanced', 'Advanced', false, function()
    ui.textWrapped('The lap sound plays on every completed lap. The sector sound plays for each new absolute sector record in the current session.')
    ui.textWrapped('Result deltas compare with the session record before the crossing. BEST appears only for a valid session record.')
  end)
  ui.separator()
  SettingsUI.resetAppearance('timer', function()
    Settings.values.scale = DEFAULTS.scale
    Settings.values.backgroundOpacity = DEFAULTS.backgroundOpacity
  end)
  SettingsUI.resetAll('timer', function()
    for key, value in pairs(DEFAULTS) do Settings.values[key] = value end
  end, 'Restore all local Timer settings? Global theme and opacity settings are retained.')
  Settings.normalize()
end

return Settings
