local DialSettings = require('src/settings')
local SettingsUI = require('src/settings_ui')
local GeneralSettings = require('src/general_settings')
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

local function checkbox(label, key)
  if ui.checkbox(label, M.values[key]) then M.values[key] = not M.values[key] end
end

function M.current()
  -- ac.storage exposes values through indexed access in CSP. Its proxy is not
  -- guaranteed to enumerate stored fields with pairs().
  local values = {}
  for _, key in ipairs({
    'hudScale', 'gt7SpeedNeedleMode', 'gt7RpmNeedleMode', 'gt7LowerPanelMode',
    'gt7ProximityRadar', 'gt7RadarStyle', 'showSteering', 'showLights', 'debug'
  }) do
    values[key] = M.values[key]
  end
  values.instrumentMode = 'gt7_retro'
  return GeneralSettings.apply(values)
end

function M.draw()
  ui.header('GT7 Classic')
  SettingsUI.section('gt7', 'basics', 'Basics', true, function()
    slider('HUD scale', 'hudScale', 0.55, 1.15, '%.2fx')
    local modes = {{label='Digital', value='digital'}, {label='Analog', value='analog'}}
    SettingsUI.choice('gt7', 'speedNeedle', 'Speed dial mode', M.values.gt7SpeedNeedleMode,
      modes, function(value) M.values.gt7SpeedNeedleMode = value end)
    SettingsUI.choice('gt7', 'rpmNeedle', 'RPM dial mode', M.values.gt7RpmNeedleMode,
      modes, function(value) M.values.gt7RpmNeedleMode = value end)
  end)
  SettingsUI.section('gt7', 'personalization', 'Personalization', false, function()
    SettingsUI.choice('gt7', 'lower', 'Lower panel content', M.values.gt7LowerPanelMode,
      {{label='Grip limit', value='limit'}, {label='FFB', value='ffb'},
       {label='Pedal history', value='pedal_history'}, {label='Hidden', value='invisible'}},
      function(value) M.values.gt7LowerPanelMode = value end)
    checkbox('Show steering marker', 'showSteering')
    checkbox('Show lights', 'showLights')
    checkbox('Side proximity radar', 'gt7ProximityRadar')
    if M.values.gt7ProximityRadar then
      SettingsUI.choice('gt7', 'radarStyle', 'Radar display', M.values.gt7RadarStyle,
        {{label='Arcs', value='arcs'}, {label='Lights', value='lights'}},
        function(value) M.values.gt7RadarStyle = value end)
    end
  end)
  SettingsUI.section('gt7', 'advanced', 'Advanced', false, function()
    checkbox('Developer debug view', 'debug')
  end)
  ui.separator()
  SettingsUI.resetAppearance('gt7', function() M.values.hudScale = 0.72 end)
  SettingsUI.resetAll('gt7', function()
    M.values.hudScale = 0.72
    M.values.gt7SpeedNeedleMode, M.values.gt7RpmNeedleMode = 'digital', 'digital'
    M.values.gt7LowerPanelMode, M.values.gt7RadarStyle, M.values.gt7ProximityRadar = 'limit', 'arcs', true
    M.values.showSteering, M.values.showLights, M.values.debug = true, true, false
  end, 'Restore all local GT7 settings? Global settings are managed in General.')
end

return M
