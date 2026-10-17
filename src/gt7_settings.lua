local DialSettings = require('src/settings')
local SettingsUI = require('src/settings_ui')
local Layout = require('src/gt7_retro_layout')
local InstrumentConfig = require('src/instrument_config')
local DialStyles = require('src/gt7_dial_styles')
local GeneralSettings = require('src/general_settings')
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
  -- Kept as legacy/last-preset metadata so older installs can migrate once.
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
  gt7SpeedDialStyle = 'original',
  gt7RpmDialStyle = 'original',
  gt7SpeedAuxiliaryStyle = 'original',
  gt7RpmAuxiliaryStyle = 'original',
  gt7SimulateVacuum = true,
  gt7VacuumMinimum = InstrumentConfig.vacuumMinimum,
  gt7LowerPanelMode = 'limit',
  gt7ProximityRadar = true,
  gt7SlipstreamBackground = true,
  -- Legacy preference. Versions 2.2 and later store presentation separately.
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
  M.values.gt7SlipstreamBackground = M.values.gt7SlipstreamBackground ~= false
  local normalized = Layout.normalize(M.values)
  setComposition(normalized)
  if not presetIds[M.values.gt7Layout] then M.values.gt7Layout = 'classic' end
  M.values.gt7SpeedNeedleMode = M.values.gt7SpeedNeedleMode == 'analog' and 'analog' or 'digital'
  M.values.gt7RpmNeedleMode = M.values.gt7RpmNeedleMode == 'analog' and 'analog' or 'digital'
  for _, key in ipairs({ 'gt7SpeedNeedleStyle', 'gt7RpmNeedleStyle' }) do
    M.values[key] = InstrumentConfig.normalizeNeedleStyle(M.values[key])
  end
  M.values.gt7SpeedDialStyle = DialStyles.normalize(M.values.gt7SpeedDialStyle,
    M.values.gt7SpeedNeedleMode, 'speed')
  M.values.gt7RpmDialStyle = DialStyles.normalize(M.values.gt7RpmDialStyle,
    M.values.gt7RpmNeedleMode, 'rpm')
  M.values.gt7SpeedAuxiliaryStyle = DialStyles.normalizeAuxiliary(M.values.gt7SpeedAuxiliaryStyle)
  M.values.gt7RpmAuxiliaryStyle = DialStyles.normalizeAuxiliary(M.values.gt7RpmAuxiliaryStyle)
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
    'hudScale', 'gt7DialScale', 'gt7DialSpacing', 'gt7IndicatorScale', 'gt7Layout',
    'gt7SpeedStyle', 'gt7GearStyle', 'gt7SteeringStyle', 'gt7RpmBarVisible',
    'gt7PedalPosition', 'gt7PedalStyle', 'gt7RadarPresentation',
    'gt7FlagPresentation', 'gt7LowerFrameStyle',
    'gt7SpeedNeedleMode', 'gt7RpmNeedleMode', 'gt7SpeedDialStyle', 'gt7RpmDialStyle', 'gt7LowerPanelMode',
    'gt7SpeedAuxiliaryStyle', 'gt7RpmAuxiliaryStyle',
    'gt7SpeedNeedleStyle', 'gt7RpmNeedleStyle', 'gt7SimulateVacuum', 'gt7VacuumMinimum',
    'gt7ProximityRadar', 'gt7SlipstreamBackground', 'gt7RadarStyle', 'showSteering', 'showLights', 'debug'
  }) do
    values[key] = M.values[key]
  end
  values.instrumentMode = 'gt7_retro'
  values.gt7InstrumentsEnabled = true
  return GeneralSettings.apply(values)
end

local presets = {
  {id='classic', label='Classic'}, {id='modern', label='Modern'},
  {id='outer_pedals', label='Outer Pedals'}, {id='steering_dial', label='Steering Dial'}
}

function M.currentPreset()
  sanitizeComposition()
  local function matches(id)
    local expected = Layout.preset(id, M.values)
    for _, key in ipairs(compositionKeys) do
      if M.values[key] ~= expected[key] then return false end
    end
    return true
  end
  if matches(M.values.gt7Layout) then return M.values.gt7Layout end
  for _, preset in ipairs(presets) do if matches(preset.id) then return preset.id end end
  return 'custom'
end

local function resetAppearance()
  M.values.hudScale, M.values.gt7DialScale, M.values.gt7DialSpacing = 0.72, 1, 0
  M.values.gt7IndicatorScale = 1
  M.values.gt7SpeedNeedleStyle, M.values.gt7RpmNeedleStyle = 'b01', 'b01'
  M.values.gt7SpeedDialStyle, M.values.gt7RpmDialStyle = 'original', 'original'
  M.values.gt7SpeedAuxiliaryStyle, M.values.gt7RpmAuxiliaryStyle = 'original', 'original'
end

function M.draw()
  ui.header('GT7')
  SettingsUI.section('gt7', 'basics', 'Basics', true, function()
    local width = ui.availableSpaceX()
    local columns = width >= 540 and 4 or (width >= 280 and 2 or 1)
    for i, preset in ipairs(presets) do
      if (i - 1) % columns ~= 0 then ui.sameLine() end
      if ui.button(preset.label .. '##gt7.preset.' .. preset.id,
          vec2((width - (columns - 1) * 8) / columns, 0)) then M.applyPreset(preset.id) end
    end
    local current, name = M.currentPreset(), 'Custom'
    for _, preset in ipairs(presets) do if preset.id == current then name = preset.label end end
    ui.text('Composition: ' .. name)
    slider('HUD scale', 'hudScale', 0.55, 1.15, '%.2fx')
    local modes = {{label='Digital', value='digital'}, {label='Analog', value='analog'}}
    SettingsUI.choice('gt7', 'speedNeedle', 'Speed dial mode', M.values.gt7SpeedNeedleMode,
      modes, function(value)
        M.values.gt7SpeedNeedleMode = value
        M.values.gt7SpeedDialStyle = DialStyles.normalize(M.values.gt7SpeedDialStyle, value, 'speed')
      end)
    SettingsUI.choice('gt7', 'rpmNeedle', 'RPM dial mode', M.values.gt7RpmNeedleMode,
      modes, function(value)
        M.values.gt7RpmNeedleMode = value
        M.values.gt7RpmDialStyle = DialStyles.normalize(M.values.gt7RpmDialStyle, value, 'rpm')
      end)
  end)
  SettingsUI.section('gt7', 'personalization', 'Personalization', false, function()
    SettingsUI.section('gt7', 'dials', 'Side dials', true, function()
      choice('speedDialStyle', 'Speed dial style',
        DialStyles.choices(M.values.gt7SpeedNeedleMode, 'speed'))
      checkbox('Show slipstream background', 'gt7SlipstreamBackground')
      ui.textWrapped('The theme-colored background grows with relative slipstream strength. It uses air-density physics after learning a clean-air reference, or estimates the wake from traffic position when physics is unavailable, including replays and remote cars. It is not a power-gain percentage.')
      choice('rpmDialStyle', 'RPM dial style',
        DialStyles.choices(M.values.gt7RpmNeedleMode, 'rpm'))
      choice('speedAuxiliaryStyle', 'Fuel gauge style', DialStyles.auxiliary)
      choice('rpmAuxiliaryStyle', 'Turbo / AERO / battery gauge style', DialStyles.auxiliary)
      if M.values.gt7SpeedNeedleMode == 'analog' then
        SettingsUI.needle('gt7', 'speedNeedleStyle', 'Speed needle', M.values.gt7SpeedNeedleStyle,
          InstrumentConfig, function(value) M.values.gt7SpeedNeedleStyle = value end)
      end
      if M.values.gt7RpmNeedleMode == 'analog' then
        SettingsUI.needle('gt7', 'rpmNeedleStyle', 'RPM needle', M.values.gt7RpmNeedleStyle,
          InstrumentConfig, function(value) M.values.gt7RpmNeedleStyle = value end)
      end
      slider('Side dial scale', 'gt7DialScale', 0.75, 1.25, '%.2fx')
      slider('Side dial spacing', 'gt7DialSpacing', 0, 160, '%.0f px')
      slider('Status indicator scale', 'gt7IndicatorScale', 0.65, 1.5, '%.2fx')
      checkbox('Show lights', 'showLights')
    end)
    SettingsUI.section('gt7', 'center', 'Center and pedals', false, function()
      choice('speedStyle', 'Center speed design',
        {{label='Classic', value='classic'}, {label='Modern', value='modern'}, {label='Large', value='large'}})
      choice('gearStyle', 'Gear display design',
        {{label='Classic', value='classic'}, {label='Modern', value='modern'}, {label='Raised', value='high'}})
      checkbox('Show steering marker', 'showSteering')
      if M.values.showSteering then
        choice('steeringStyle', 'Steering display',
          {{label='Simple line', value='classic'}, {label='Graduated line', value='modern'}, {label='Dial', value='dial'}})
      end
      checkbox('Show horizontal RPM bar', 'gt7RpmBarVisible')
      choice('pedalPosition', 'Pedal position', {{label='Inner', value='inner'}, {label='Outer', value='outer'}})
      choice('pedalStyle', 'Pedal design',
        {{label='Rectangular', value='classic'}, {label='Wide top', value='modern'}})
    end)
    SettingsUI.section('gt7', 'lowerPanel', 'Lower panel', false, function()
      SettingsUI.choice('gt7', 'lower', 'Content', M.values.gt7LowerPanelMode,
        {{label='Grip limit', value='limit'}, {label='FFB', value='ffb'},
         {label='Pedal history', value='pedal_history'}, {label='Hidden', value='invisible'}},
        function(value) M.values.gt7LowerPanelMode = value end)
      if M.values.gt7LowerPanelMode ~= 'invisible' then
        choice('lowerFrameStyle', 'Frame design',
          {{label='Compact rounded', value='classic'}, {label='Angular', value='modern'}, {label='Wide angular', value='wide'}})
      end
    end)
    SettingsUI.section('gt7', 'radar', 'Radar and flags', false, function()
      checkbox('Side proximity radar', 'gt7ProximityRadar')
      if M.values.gt7ProximityRadar then
        choice('radarPresentation', 'Radar display',
          {{label='Arcs', value='arcs'}, {label='Classic lights', value='classic_lights'},
           {label='Bars', value='modern_bars'}, {label='3-light column', value='column_3'},
           {label='9-light column', value='column_9'}})
      end
      choice('flagPresentation', 'Flag display',
        {{label='Classic lights', value='classic_lights'}, {label='Continuous strips', value='modern_strips'},
         {label='3-light column', value='column_3'}, {label='9-light column', value='column_9'}})
    end)
  end)
  SettingsUI.section('gt7', 'advanced', 'Advanced', false, function()
    checkbox('Developer debug view', 'debug')
    checkbox('Simulate vacuum near zero boost', 'gt7SimulateVacuum')
    if M.values.gt7SimulateVacuum then
      slider('Simulated vacuum minimum', 'gt7VacuumMinimum', -1, -0.1, '%.2f bar')
      ui.textWrapped('Vacuum is estimated from throttle while the engine runs; positive boost is measured.')
    end
  end)
  ui.separator()
  SettingsUI.resetAppearance('gt7', resetAppearance)
  SettingsUI.resetAll('gt7', function()
    resetAppearance()
    M.values.gt7SpeedNeedleMode, M.values.gt7RpmNeedleMode = 'digital', 'digital'
    M.values.gt7SimulateVacuum, M.values.gt7VacuumMinimum = true, InstrumentConfig.vacuumMinimum
    M.values.gt7LowerPanelMode, M.values.gt7RadarStyle, M.values.gt7ProximityRadar = 'limit', 'arcs', true
    M.values.gt7SlipstreamBackground = true
    M.values.showSteering, M.values.showLights, M.values.debug = true, true, false
    M.applyPreset('classic')
  end, 'Restore all local GT7 settings? Global settings are managed in General.')
end

return M
