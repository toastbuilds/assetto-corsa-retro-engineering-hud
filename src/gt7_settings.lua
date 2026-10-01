local DialSettings = require('src/settings')
local SettingsUI = require('src/settings_ui')
local Layout = require('src/gt7_retro_layout')
local InstrumentConfig = require('src/instrument_config')
local InstrumentPreview = require('src/instrument_preview')
local M = {}

local COMPOSITION_VERSION = 1
local compositionKeys = {
  'gt7SpeedStyle', 'gt7GearStyle', 'gt7SteeringStyle', 'gt7RpmBarVisible',
  'gt7PedalPosition', 'gt7PedalStyle', 'gt7RadarPresentation',
  'gt7FlagPresentation', 'gt7LowerFrameStyle'
}
local presetIds = {
  classic = true, modern = true, outer_pedals = true, steering_dial = true
}

M.values = ac.storage({
  version = 0,
  compositionVersion = 0,
  hudScale = 0.72,
  gt7DialScale = 1,
  gt7DialSpacing = 0,
  gt7IndicatorScale = 1,
  opacity = 1,
  backgroundOpacity = 0.72,
  speedUnit = 'km/h',
  -- Kept as legacy/last-preset metadata so older Premium installs can migrate
  -- once and Free can continue reading its own familiar value.
  gt7Layout = 'classic',
  gt7SpeedStyle = 'classic',
  gt7GearStyle = 'classic',
  gt7SteeringStyle = 'classic',
  gt7RpmBarVisible = true,
  gt7PedalPosition = 'inner',
  gt7PedalStyle = 'classic',
  gt7RadarPresentation = 'arcs',
  gt7FlagPresentation = 'classic_lights',
  gt7LowerFrameStyle = 'classic',
  gt7SpeedNeedleMode = 'digital',
  gt7RpmNeedleMode = 'digital',
  gt7SpeedNeedleStyle = 'b01',
  gt7RpmNeedleStyle = 'b01',
  gt7SimulateVacuum = true,
  gt7VacuumMinimum = InstrumentConfig.vacuumMinimum,
  gt7LowerPanelMode = 'limit',
  gt7ProximityRadar = true,
  -- Legacy Free-compatible preference. Premium 2.2 never stores new
  -- presentation values in this field.
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

function M.legacySelections(id, radarStyle)
  return Layout.preset(presetIds[id] and id or 'classic', { gt7RadarStyle = radarStyle })
end

local function setComposition(values)
  for _, key in ipairs(compositionKeys) do M.values[key] = values[key] end
end

if (M.values.compositionVersion or 0) < COMPOSITION_VERSION then
  setComposition(M.legacySelections(M.values.gt7Layout, M.values.gt7RadarStyle))
  M.values.gt7Layout = presetIds[M.values.gt7Layout] and M.values.gt7Layout or 'classic'
  M.values.compositionVersion = COMPOSITION_VERSION
end

local function sanitizeComposition()
  local normalized = Layout.normalize(M.values)
  setComposition(normalized)
  if not presetIds[M.values.gt7Layout] then M.values.gt7Layout = 'classic' end
  for _, key in ipairs({ 'gt7SpeedNeedleStyle', 'gt7RpmNeedleStyle' }) do
    M.values[key] = InstrumentConfig.normalizeNeedleStyle(M.values[key])
  end
end
sanitizeComposition()

function M.applyPreset(id)
  id = presetIds[id] and id or 'classic'
  setComposition(Layout.preset(id, M.values))
  M.values.gt7Layout = id
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

local function choice(key, label, choices)
  local storageKey = 'gt7' .. key:sub(1, 1):upper() .. key:sub(2)
  SettingsUI.choice('gt7', key, label, M.values[storageKey], choices,
    function(value) M.values[storageKey] = value end)
end

function M.current()
  sanitizeComposition()
  -- ac.storage exposes values through indexed access in CSP. Its proxy is not
  -- guaranteed to enumerate stored fields with pairs().
  local values = {}
  for _, key in ipairs({
    'hudScale', 'gt7DialScale', 'gt7DialSpacing', 'gt7IndicatorScale', 'opacity', 'backgroundOpacity', 'speedUnit', 'gt7Layout',
    'gt7SpeedStyle', 'gt7GearStyle', 'gt7SteeringStyle', 'gt7RpmBarVisible',
    'gt7PedalPosition', 'gt7PedalStyle', 'gt7RadarPresentation',
    'gt7FlagPresentation', 'gt7LowerFrameStyle',
    'gt7SpeedNeedleMode', 'gt7RpmNeedleMode', 'gt7LowerPanelMode',
    'gt7SpeedNeedleStyle', 'gt7RpmNeedleStyle', 'gt7SimulateVacuum', 'gt7VacuumMinimum',
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
  values.gt7InstrumentsEnabled = true
  return values
end

function M.draw()
  ui.header('GT7 Premium')
  SettingsUI.section('gt7', 'appearance', 'Appearance', true, function()
    slider('HUD scale', 'hudScale', 0.55, 1.15, '%.2fx')
    slider('Side dial scale', 'gt7DialScale', 0.75, 1.25, '%.2fx')
    slider('Side dial spacing', 'gt7DialSpacing', 0, 160, '%.0f px')
    slider('Lower indicator scale', 'gt7IndicatorScale', 0.65, 1.5, '%.2fx')
    percent('Backdrop opacity', 'backgroundOpacity', 0.18, 0.82)
    percent('Instrument opacity', 'opacity', 0.55, 1)
    SettingsUI.resetAppearance('gt7', function()
      M.values.hudScale, M.values.backgroundOpacity, M.values.opacity = 0.72, 0.72, 1
      M.values.gt7DialScale, M.values.gt7DialSpacing = 1, 0
      M.values.gt7IndicatorScale = 1
      M.values.gt7SpeedNeedleStyle, M.values.gt7RpmNeedleStyle = 'b01', 'b01'
    end)
  end)
  SettingsUI.section('gt7', 'gauges', 'Components and presets', true, function()
    SettingsUI.choice('gt7', 'layout', 'Apply preset', M.values.gt7Layout,
      { { label = 'Classic', value = 'classic' }, { label = 'Modern', value = 'modern' },
        { label = 'Outer Pedals', value = 'outer_pedals' },
        { label = 'Steering Dial', value = 'steering_dial' } },
      M.applyPreset)

    choice('speedStyle', 'Center speed',
      { { label = 'Classic', value = 'classic' }, { label = 'Modern', value = 'modern' },
        { label = 'Large Steering Dial', value = 'large' } })
    choice('gearStyle', 'Gear',
      { { label = 'Classic', value = 'classic' }, { label = 'Modern', value = 'modern' },
        { label = 'High Steering Dial', value = 'high' } })
    choice('steeringStyle', 'Steering',
      { { label = 'Classic line', value = 'classic' }, { label = 'Modern graduated line', value = 'modern' },
        { label = 'Steering Dial', value = 'dial' } })
    checkbox('Horizontal RPM bar', 'gt7RpmBarVisible')
    choice('pedalPosition', 'Pedal position',
      { { label = 'Inner', value = 'inner' }, { label = 'Outer', value = 'outer' } })
    choice('pedalStyle', 'Pedal design',
      { { label = 'Classic rectangles', value = 'classic' },
        { label = 'Modern wide-top blocks', value = 'modern' } })
    choice('lowerFrameStyle', 'Lower panel appearance',
      { { label = 'Classic compact rounded', value = 'classic' },
        { label = 'Modern angular', value = 'modern' },
        { label = 'Steering Dial wide angular', value = 'wide' } })

    local needles = { { label = 'Digital', value = 'digital' }, { label = 'Analog', value = 'analog' } }
    SettingsUI.choice('gt7', 'speedNeedle', 'Speed dial mode', M.values.gt7SpeedNeedleMode,
      needles, function(value) M.values.gt7SpeedNeedleMode = value end)
    SettingsUI.choice('gt7', 'rpmNeedle', 'RPM dial mode', M.values.gt7RpmNeedleMode,
      needles, function(value) M.values.gt7RpmNeedleMode = value end)
    choice('speedNeedleStyle', 'Speed needle style', InstrumentConfig.needleChoices)
    choice('rpmNeedleStyle', 'RPM needle style', InstrumentConfig.needleChoices)
    SettingsUI.choice('gt7', 'lower', 'Lower panel content', M.values.gt7LowerPanelMode,
      { { label = 'Grip limit', value = 'limit' }, { label = 'FFB', value = 'ffb' },
        { label = 'Pedal history', value = 'pedal_history' }, { label = 'Hidden', value = 'invisible' } },
      function(value) M.values.gt7LowerPanelMode = value end)
    checkbox('Show steering marker', 'showSteering')
    checkbox('Show lights', 'showLights')
  end)
  SettingsUI.section('gt7', 'radar', 'Radar and flags', true, function()
    checkbox('Side proximity radar', 'gt7ProximityRadar')
    choice('radarPresentation', 'Radar presentation',
      { { label = 'Arcs', value = 'arcs' }, { label = 'Classic lights', value = 'classic_lights' },
        { label = 'Modern bars', value = 'modern_bars' }, { label = '3-light column', value = 'column_3' },
        { label = '9-light column', value = 'column_9' } })
    choice('flagPresentation', 'Flags',
      { { label = 'Classic lights', value = 'classic_lights' },
        { label = 'Modern continuous strips', value = 'modern_strips' },
        { label = '3-light column', value = 'column_3' },
        { label = '9-light column', value = 'column_9' } })
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
    checkbox('Simulate vacuum when boost is zero', 'gt7SimulateVacuum')
    slider('Simulated vacuum minimum', 'gt7VacuumMinimum', -1, -0.1, '%.2f bar')
    ui.textWrapped('CSP provides positive boost. Vacuum is an estimate from throttle while the engine runs; positive boost remains measured.')
    InstrumentPreview.draw(M.values)
    SettingsUI.resetAll('gt7', function()
      M.values.hudScale, M.values.backgroundOpacity, M.values.opacity = 0.72, 0.72, 1
      M.values.gt7DialScale, M.values.gt7DialSpacing = 1, 0
      M.values.gt7IndicatorScale = 1
      M.values.gt7SpeedNeedleMode, M.values.gt7RpmNeedleMode = 'digital', 'digital'
      M.values.gt7SpeedNeedleStyle, M.values.gt7RpmNeedleStyle = 'b01', 'b01'
      M.values.gt7SimulateVacuum, M.values.gt7VacuumMinimum = true, InstrumentConfig.vacuumMinimum
      InstrumentPreview.reset()
      M.values.gt7LowerPanelMode, M.values.gt7RadarStyle, M.values.gt7ProximityRadar = 'limit', 'arcs', true
      M.values.rpmWarningFraction, M.values.rpmRedlineFraction, M.values.fallbackRpm = 0.86, 0.96, 8000
      for _, key in ipairs({ 'showSteering', 'showLights', 'animateIndicators',
          'animateFlagAlert', 'animateShiftAlert', 'animateRedlineAlert' }) do M.values[key] = true end
      M.values.debug = false
      M.applyPreset('classic')
    end, 'Restore every GT7 setting? Shared theme and units will stay as they are.')
  end)
end

return M
