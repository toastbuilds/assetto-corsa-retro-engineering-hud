local M = {}
local SettingsUI = require('src/settings_ui')
local InstrumentConfig = require('src/instrument_config')
local GeneralSettings = require('src/general_settings')
local DialVariants = require('src/dial_variants')

M.lastChange = 'Ready'

-- Legacy shared fields are retained for one-time migration and older GT7
-- installs. Renderers consume current(), with General as the sole authority.
M.values = ac.storage({
  layoutVersion = 1,
  hudScale = 0.72,
  opacity = 1.0,
  backgroundOpacity = 0.72,
  speedUnit = 'km/h',
  temperatureUnit = 'C',
  sharedUnitsVersion = 0,
  instrumentMode = 'digital',
  analogVariant = 'original',
  theme = 'dark',
  analogAuxiliaryMode = 'auto',
  analogNeedleStyle = 'a01',
  gt7SpeedNeedleMode = 'digital',
  gt7RpmNeedleMode = 'digital',
  gt7LowerPanelMode = 'limit',
  gt7ProximityRadar = true,
  gt7RadarStyle = 'arcs',
  rpmWarningFraction = 0.86,
  rpmRedlineFraction = 0.96,
  fallbackRpm = 8000,
  showClutch = true,
  showLights = true,
  showTcAbsLevels = true,
  showSteering = true,
  animateIndicators = true,
  animateFlagAlert = true,
  animateShiftAlert = true,
  animateRedlineAlert = true,
  debug = false
})

-- Existing installs have a saved v0.1 scale. Keep a user-selected smaller
-- value, but migrate oversized values to the compact v0.2 presentation once.
if (M.values.layoutVersion or 1) < 3 then
  M.values.hudScale = math.min(M.values.hudScale or 0.72, 0.72)
  M.values.backgroundOpacity = math.max(M.values.backgroundOpacity or 0.72, 0.72)
  M.values.layoutVersion = 3
end

M.values.theme = M.values.theme == 'light' and 'light' or 'dark'
M.values.analogNeedleStyle = InstrumentConfig.normalizeNeedleStyle(M.values.analogNeedleStyle, 'a01')
if M.values.instrumentMode == 'gt7_retro' then M.values.instrumentMode = 'digital' end

-- A previous settings build could leave both RPM thresholds at 100%. That
-- makes the shift band look permanently dim and prevents the core from ever
-- reaching its amber/red states before the limiter. Restore the intended
-- staged range once, while retaining every other user preference.
if (M.values.layoutVersion or 1) < 4 then
  if (M.values.rpmWarningFraction or 0) >= 0.999 then
    M.values.rpmWarningFraction = 0.86
  end
  if (M.values.rpmRedlineFraction or 0) >= 0.999 then
    M.values.rpmRedlineFraction = 0.96
  end
  M.values.animateShiftAlert = true
  M.values.animateRedlineAlert = true
  M.values.layoutVersion = 4
end

-- v5 adds a third renderer without changing the meaning of either existing
-- stored value. Keep digital/analog selections intact and only repair values
-- left by an unknown or older experimental build.
if (M.values.layoutVersion or 1) < 5 then
  local mode = M.values.instrumentMode
  if mode ~= 'digital' and mode ~= 'analog' and mode ~= 'gt7_retro' then
    M.values.instrumentMode = 'digital'
  end
  M.values.layoutVersion = 5
end

-- v6 adds independent GT7 Retro needle response modes. New fields default to
-- the previous direct response so existing installations do not change feel.
local function validNeedleMode(value)
  return value == 'analog' and 'analog' or 'digital'
end

M.values.gt7SpeedNeedleMode = validNeedleMode(M.values.gt7SpeedNeedleMode)
M.values.gt7RpmNeedleMode = validNeedleMode(M.values.gt7RpmNeedleMode)
if (M.values.layoutVersion or 1) < 6 then M.values.layoutVersion = 6 end

local function validGt7LowerPanelMode(value)
  if value == 'pedal_history' or value == 'ffb' or value == 'limit' or value == 'invisible' then return value end
  return 'limit'
end

M.values.gt7LowerPanelMode = validGt7LowerPanelMode(M.values.gt7LowerPanelMode)
if (M.values.layoutVersion or 1) < 7 then M.values.layoutVersion = 7 end

-- v8 makes the GT7 Retro lower instrument a grip-limit meter by default.
-- FFB remains selectable, but existing installs should receive the new HUD
-- behavior rather than silently retaining the superseded default.
if (M.values.layoutVersion or 1) < 8 then
  M.values.gt7LowerPanelMode = 'limit'
  M.values.layoutVersion = 8
end

-- v9 adds an invisible lower metrics panel for overlays such as a radar.
-- Keep existing installations visually unchanged by default.
if (M.values.layoutVersion or 1) < 9 then M.values.layoutVersion = 9 end

M.values.analogVariant = DialVariants.normalize(M.values.analogVariant)
if (M.values.layoutVersion or 1) < 10 then M.values.layoutVersion = 10 end

if M.values.gt7RadarStyle ~= 'arcs' then M.values.gt7RadarStyle = 'lights' end

local function checkbox(label, key)
  if ui.checkbox(label, M.values[key]) then
    M.values[key] = not M.values[key]
    M.lastChange = label
  end
end

local function slider(label, key, minimum, maximum, format)
  local value, changed = ui.slider(label, M.values[key], minimum, maximum, format, 1)
  if changed then
    M.values[key] = value
    M.lastChange = label
  end
end

local function resetVisualSettings()
  M.values.analogVariant = 'original'
  M.values.analogNeedleStyle = 'a01'
  M.values.hudScale = 0.72
  M.lastChange = 'Visual settings reset'
end

local instrumentModes = {
  { value = 'digital', label = 'Digital dial' },
  { value = 'analog', label = 'Analog dial' }
}

function M.current()
  local variant = DialVariants.normalize(M.values.analogVariant)
  if M.values.analogVariant ~= variant then M.values.analogVariant = variant end
  local values = {}
  for _, key in ipairs({'hudScale', 'instrumentMode', 'analogVariant', 'analogAuxiliaryMode', 'analogNeedleStyle',
      'showClutch', 'showLights', 'showTcAbsLevels', 'showSteering', 'debug'}) do
    values[key] = M.values[key]
  end
  return GeneralSettings.apply(values)
end

function M.draw()
  ui.header('Dial')
  SettingsUI.section('dial', 'basics', 'Basics', true, function()
    slider('HUD scale', 'hudScale', 0.55, 1.15, '%.2fx')
    SettingsUI.choice('dial', 'mode', 'Dial mode', M.values.instrumentMode,
      instrumentModes, function(value) M.values.instrumentMode = value end)
    if M.values.instrumentMode == 'analog' then
      SettingsUI.choice('dial', 'variant', 'Variant', M.values.analogVariant,
        DialVariants.choices, function(value) M.values.analogVariant = value end)
    end
  end)
  SettingsUI.section('dial', 'personalization', 'Personalization', false, function()
    if M.values.instrumentMode == 'analog' then
      SettingsUI.needle('dial', 'needleStyle', 'RPM needle', M.values.analogNeedleStyle,
        InstrumentConfig, function(value) M.values.analogNeedleStyle = value end)
      SettingsUI.choice('dial', 'lower', 'Auxiliary gauge', M.values.analogAuxiliaryMode,
        {{label='Auto', value='auto'}, {label='Turbo', value='turbo'},
         {label='Electric', value='electric'}, {label='Fuel', value='fuel'}, {label='Off', value='off'}},
        function(value) M.values.analogAuxiliaryMode = value end)
    end
    checkbox('Show steering marker', 'showSteering')
    checkbox('Show clutch', 'showClutch')
    checkbox('Show lights', 'showLights')
    checkbox('Show TC / ABS levels', 'showTcAbsLevels')
  end)
  SettingsUI.section('dial', 'advanced', 'Advanced', false, function()
    checkbox('Developer debug view', 'debug')
  end)
  ui.separator()
  SettingsUI.resetAppearance('dial', resetVisualSettings)
  SettingsUI.resetAll('dial', function()
    resetVisualSettings()
    M.values.instrumentMode, M.values.analogAuxiliaryMode = 'digital', 'auto'
    for _, key in ipairs({'showSteering', 'showClutch', 'showLights', 'showTcAbsLevels'}) do
      M.values[key] = true
    end
    M.values.debug = false
  end, 'Restore all local Dial settings? Global settings are managed in General.')
end

return M
