local M = {}
local SettingsUI = require('src/settings_ui')
local InstrumentConfig = require('src/instrument_config')

M.lastChange = 'Ready'

M.values = ac.storage({
  layoutVersion = 1,
  hudScale = 0.72,
  opacity = 1.0,
  backgroundOpacity = 0.72,
  speedUnit = 'km/h',
  temperatureUnit = 'C',
  sharedUnitsVersion = 0,
  instrumentMode = 'digital',
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

if M.values.gt7RadarStyle ~= 'arcs' then M.values.gt7RadarStyle = 'lights' end

local function normalizeRpmThresholds()
  local redline = math.max(0.82, math.min(M.values.rpmRedlineFraction or 0.96, 1.0))
  local warning = math.max(0.70, math.min(M.values.rpmWarningFraction or 0.86, 0.98))
  M.values.rpmRedlineFraction = redline
  M.values.rpmWarningFraction = math.min(warning, redline - 0.04)
end

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

-- CSP sliders work with fractions for opacity and RPM thresholds, but their
-- printf formatter does not turn 0.86 into 86%. Draw those controls in human
-- readable percentage points and convert back before persisting them.
local function percentageSlider(label, key, minimum, maximum)
  local value, changed = ui.slider(label, (M.values[key] or minimum) * 100,
    minimum * 100, maximum * 100, '%.0f%%', 1)
  if changed then
    M.values[key] = value / 100
    M.lastChange = label
  end
end

local function resetVisualSettings()
  M.values.analogNeedleStyle = 'a01'
  M.values.hudScale = 0.72
  M.values.backgroundOpacity = 0.72
  M.values.opacity = 1.0
  M.lastChange = 'Visual settings reset'
end

local instrumentModes = {
  { value = 'digital', label = 'Digital dial' },
  { value = 'analog', label = 'Analog dial' }
}

function M.draw()
  ui.header('Dial')
  SettingsUI.section('dial', 'appearance', 'Appearance', true, function()
    slider('HUD scale', 'hudScale', 0.55, 1.15, '%.2fx')
    percentageSlider('Backdrop opacity', 'backgroundOpacity', 0.18, 0.82)
    percentageSlider('Instrument opacity', 'opacity', 0.55, 1.0)
    SettingsUI.resetAppearance('dial', resetVisualSettings)
  end)
  SettingsUI.section('dial', 'gauge', 'Gauge and display', true, function()
    SettingsUI.choice('dial', 'mode', 'Instrument mode', M.values.instrumentMode,
      instrumentModes, function(value) M.values.instrumentMode = value end)
    if M.values.instrumentMode == 'analog' then
      SettingsUI.choice('dial', 'needleStyle', 'RPM needle style', M.values.analogNeedleStyle,
        InstrumentConfig.needleChoices, function(value) M.values.analogNeedleStyle = value end)
      SettingsUI.choice('dial', 'lower', 'Analog lower gauge', M.values.analogAuxiliaryMode,
        { { label = 'Auto', value = 'auto' }, { label = 'Turbo', value = 'turbo' },
          { label = 'Fuel', value = 'fuel' }, { label = 'Off', value = 'off' } },
        function(value) M.values.analogAuxiliaryMode = value end)
    end
    checkbox('Show steering marker', 'showSteering')
    checkbox('Show clutch', 'showClutch')
    checkbox('Show lights', 'showLights')
    checkbox('Show TC / ABS levels', 'showTcAbsLevels')
  end)
  SettingsUI.section('dial', 'alerts', 'RPM and alerts', true, function()
    percentageSlider('Warning threshold', 'rpmWarningFraction', 0.70, 0.98)
    percentageSlider('Redline threshold', 'rpmRedlineFraction', 0.82, 1.0)
    normalizeRpmThresholds()
    slider('Fallback RPM', 'fallbackRpm', 4000, 16000, '%.0f rpm')
    checkbox('Blink turn indicators', 'animateIndicators')
    checkbox('Blink race flag alert', 'animateFlagAlert')
    checkbox('Blink shift zone', 'animateShiftAlert')
    checkbox('Blink redline alert', 'animateRedlineAlert')
  end)
  SettingsUI.section('dial', 'advanced', 'Advanced', false, function()
    checkbox('Developer debug view', 'debug')
    SettingsUI.resetAll('dial', function()
      resetVisualSettings()
      M.values.instrumentMode, M.values.analogAuxiliaryMode = 'digital', 'auto'
      M.values.rpmWarningFraction, M.values.rpmRedlineFraction, M.values.fallbackRpm = 0.86, 0.96, 8000
      for _, key in ipairs({ 'showSteering', 'showClutch', 'showLights', 'showTcAbsLevels',
          'animateIndicators', 'animateFlagAlert', 'animateShiftAlert', 'animateRedlineAlert' }) do
        M.values[key] = true
      end
      M.values.debug = false
    end, 'Restore every Dial setting? Shared theme and units will stay as they are.')
  end)
end

return M
