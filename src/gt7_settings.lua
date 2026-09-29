local DialSettings = require('src/settings')
local SettingsUI = require('src/settings_ui')
local M = {}

M.values = ac.storage({
  version = 0,
  hudScale = 0.72,
  opacity = 1,
  backgroundOpacity = 0.72,
  speedUnit = 'km/h',
  gt7SpeedNeedleMode = 'digital',
  gt7RpmNeedleMode = 'digital',
  gt7LowerPanelMode = 'limit',
  gt7ProximityRadar = true,
  gt7RadarStyle = 'arcs',
  rpmWarningFraction = 0.86,
  rpmRedlineFraction = 0.96,
  fallbackRpm = 8000,
  showSteering = true,
  showLights = true,
  animateIndicators = true,
  animateFlagAlert = true,
  animateShiftAlert = true,
  animateRedlineAlert = true,
  debug = false
}, 'retro-ui.gt7.')

if (M.values.version or 0) < 1 then
  for _, key in ipairs({ 'hudScale', 'opacity', 'backgroundOpacity', 'speedUnit',
    'gt7SpeedNeedleMode', 'gt7RpmNeedleMode', 'gt7LowerPanelMode',
    'gt7ProximityRadar', 'gt7RadarStyle', 'rpmWarningFraction',
    'rpmRedlineFraction', 'fallbackRpm', 'showSteering', 'showLights',
    'animateIndicators', 'animateFlagAlert', 'animateShiftAlert',
    'animateRedlineAlert', 'debug' }) do
    if DialSettings.values[key] ~= nil then M.values[key] = DialSettings.values[key] end
  end
  M.values.version = 1
end

local function slider(label, key, low, high, format)
  local value, changed = ui.slider(label, M.values[key], low, high, format, 1)
  if changed then M.values[key] = value end
end

local function percent(label, key, low, high)
  local value, changed = ui.slider(label, M.values[key] * 100, low * 100, high * 100, '%.0f%%', 1)
  if changed then M.values[key] = value / 100 end
end

local function checkbox(label, key)
  if ui.checkbox(label, M.values[key]) then M.values[key] = not M.values[key] end
end

function M.current()
  -- ac.storage exposes values through indexed access in CSP. Its proxy is not
  -- guaranteed to enumerate stored fields with pairs().
  local values = {}
  for _, key in ipairs({
    'hudScale', 'opacity', 'backgroundOpacity', 'speedUnit',
    'gt7SpeedNeedleMode', 'gt7RpmNeedleMode', 'gt7LowerPanelMode',
    'gt7ProximityRadar', 'gt7RadarStyle', 'rpmWarningFraction',
    'rpmRedlineFraction', 'fallbackRpm', 'showSteering', 'showLights',
    'animateIndicators', 'animateFlagAlert', 'animateShiftAlert',
    'animateRedlineAlert', 'debug'
  }) do
    values[key] = M.values[key]
  end
  values.theme = DialSettings.values.theme
  values.speedUnit = DialSettings.values.speedUnit
  values.instrumentMode = 'gt7_retro'
  return values
end

function M.draw()
  ui.header('GT7')
  SettingsUI.section('gt7', 'appearance', 'Appearance', true, function()
    slider('HUD scale', 'hudScale', 0.55, 1.15, '%.2fx')
    percent('Backdrop opacity', 'backgroundOpacity', 0.18, 0.82)
    percent('Instrument opacity', 'opacity', 0.55, 1)
    SettingsUI.resetAppearance('gt7', function()
      M.values.hudScale, M.values.backgroundOpacity, M.values.opacity = 0.72, 0.72, 1
    end)
  end)
  SettingsUI.section('gt7', 'gauges', 'Gauges and layout', true, function()
    local needles = { { label = 'Digital', value = 'digital' }, { label = 'Analog', value = 'analog' } }
    SettingsUI.choice('gt7', 'speedNeedle', 'Speed needle', M.values.gt7SpeedNeedleMode,
      needles, function(value) M.values.gt7SpeedNeedleMode = value end)
    SettingsUI.choice('gt7', 'rpmNeedle', 'RPM needle', M.values.gt7RpmNeedleMode,
      needles, function(value) M.values.gt7RpmNeedleMode = value end)
    SettingsUI.choice('gt7', 'lower', 'Lower panel', M.values.gt7LowerPanelMode,
      { { label = 'Grip limit', value = 'limit' }, { label = 'FFB', value = 'ffb' },
        { label = 'Pedal history', value = 'pedal_history' }, { label = 'Hidden', value = 'invisible' } },
      function(value) M.values.gt7LowerPanelMode = value end)
    checkbox('Show steering marker', 'showSteering')
    checkbox('Show lights', 'showLights')
  end)
  SettingsUI.section('gt7', 'radar', 'Radar', true, function()
    checkbox('Side proximity radar', 'gt7ProximityRadar')
    if M.values.gt7ProximityRadar then
      SettingsUI.choice('gt7', 'radarStyle', 'Radar style', M.values.gt7RadarStyle,
        { { label = 'Arcs', value = 'arcs' }, { label = 'Lights', value = 'lights' } },
        function(value) M.values.gt7RadarStyle = value end)
    end
  end)
  SettingsUI.section('gt7', 'rpm', 'RPM and alerts', false, function()
    percent('Warning threshold', 'rpmWarningFraction', 0.70, 0.98)
    percent('Redline threshold', 'rpmRedlineFraction', 0.82, 1)
    M.values.rpmWarningFraction = math.min(M.values.rpmWarningFraction, M.values.rpmRedlineFraction - 0.04)
    slider('Fallback RPM', 'fallbackRpm', 4000, 16000, '%.0f rpm')
    checkbox('Blink turn indicators', 'animateIndicators')
    checkbox('Blink race flag alert', 'animateFlagAlert')
    checkbox('Blink shift zone', 'animateShiftAlert')
    checkbox('Blink redline alert', 'animateRedlineAlert')
  end)
  SettingsUI.section('gt7', 'advanced', 'Advanced', false, function()
    checkbox('Developer debug view', 'debug')
    SettingsUI.resetAll('gt7', function()
      M.values.hudScale, M.values.backgroundOpacity, M.values.opacity = 0.72, 0.72, 1
      M.values.gt7SpeedNeedleMode, M.values.gt7RpmNeedleMode = 'digital', 'digital'
      M.values.gt7LowerPanelMode, M.values.gt7RadarStyle, M.values.gt7ProximityRadar = 'limit', 'arcs', true
      M.values.rpmWarningFraction, M.values.rpmRedlineFraction, M.values.fallbackRpm = 0.86, 0.96, 8000
      for _, key in ipairs({ 'showSteering', 'showLights', 'animateIndicators',
          'animateFlagAlert', 'animateShiftAlert', 'animateRedlineAlert' }) do M.values[key] = true end
      M.values.debug = false
    end, 'Restore every GT7 setting? Shared theme and units will stay as they are.')
  end)
end

return M
