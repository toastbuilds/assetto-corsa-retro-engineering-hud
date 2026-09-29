local M = {}

M.lastChange = 'Ready'

M.values = ac.storage({
  layoutVersion = 1,
  hudScale = 0.72,
  opacity = 1.0,
  backgroundOpacity = 0.72,
  speedUnit = 'km/h',
  instrumentMode = 'digital',
  theme = 'dark',
  analogAuxiliaryMode = 'auto',
  gt7SpeedNeedleMode = 'digital',
  gt7RpmNeedleMode = 'digital',
  gt7LowerPanelMode = 'limit',
  gt7ProximityRadar = true,
  gt7RadarStyle = 'lights',
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
  M.values.hudScale = 0.72
  M.values.backgroundOpacity = 0.72
  M.values.opacity = 1.0
  M.values.theme = 'dark'
  M.lastChange = 'Visual settings reset'
end

local function themeLabel()
  return M.values.theme == 'light' and 'Light' or 'Dark'
end

local function nextAnalogAuxiliaryMode()
  local modes = { 'auto', 'turbo', 'fuel', 'off' }
  local current = M.values.analogAuxiliaryMode or 'auto'
  for i, mode in ipairs(modes) do
    if mode == current then
      M.values.analogAuxiliaryMode = modes[i % #modes + 1]
      return
    end
  end
  M.values.analogAuxiliaryMode = 'auto'
end

local function nextNeedleMode(key)
  M.values[key] = M.values[key] == 'analog' and 'digital' or 'analog'
end

local function needleModeLabel(key)
  return M.values[key] == 'analog' and 'Analog' or 'Digital'
end

local function nextGt7LowerPanelMode()
  local modes = { 'limit', 'ffb', 'pedal_history', 'invisible' }
  for i, mode in ipairs(modes) do
    if M.values.gt7LowerPanelMode == mode then
      M.values.gt7LowerPanelMode = modes[i % #modes + 1]
      return
    end
  end
  M.values.gt7LowerPanelMode = modes[1]
end

local function gt7LowerPanelModeLabel()
  if M.values.gt7LowerPanelMode == 'invisible' then return 'Invisible' end
  if M.values.gt7LowerPanelMode == 'pedal_history' then return 'Pedal history' end
  if M.values.gt7LowerPanelMode == 'ffb' then return 'FFB gauge' end
  return 'LIMIT gauge'
end

local function gt7RadarStyleLabel()
  return M.values.gt7RadarStyle == 'arcs' and 'Arcs' or 'Arrow + dots'
end

local instrumentModes = {
  { value = 'digital', label = 'Digital dial' },
  { value = 'analog', label = 'Analog dial' },
  { value = 'gt7_retro', label = 'GT7 Retro' }
}

local function instrumentModeLabel()
  for _, mode in ipairs(instrumentModes) do
    if M.values.instrumentMode == mode.value then return mode.label end
  end
  return instrumentModes[1].label
end

local function nextInstrumentMode()
  for i, mode in ipairs(instrumentModes) do
    if M.values.instrumentMode == mode.value then
      M.values.instrumentMode = instrumentModes[i % #instrumentModes + 1].value
      return
    end
  end
  M.values.instrumentMode = instrumentModes[1].value
end

function M.draw()
  ui.header('Retro Engineering HUD')
  ui.text('v1.1  /  three instrument layouts')
  ui.separator()

  slider('HUD scale', 'hudScale', 0.55, 1.15, '%.2fx')
  percentageSlider('Backdrop opacity', 'backgroundOpacity', 0.18, 0.82)
  percentageSlider('Instrument opacity', 'opacity', 0.55, 1.0)

  if ui.button('Reset visual settings') then
    resetVisualSettings()
  end

  if ui.button('Theme: ' .. themeLabel()) then
    M.values.theme = M.values.theme == 'light' and 'dark' or 'light'
    M.lastChange = 'Theme'
  end

  if ui.button('Speed unit: ' .. M.values.speedUnit) then
    M.values.speedUnit = M.values.speedUnit == 'km/h' and 'mph' or 'km/h'
    M.lastChange = 'Speed unit'
  end

  if ui.button('Instrument mode: ' .. instrumentModeLabel()) then
    nextInstrumentMode()
    M.lastChange = 'Instrument mode'
  end

  if M.values.instrumentMode == 'analog' then
    if ui.button('Analog lower gauge: ' .. string.upper(M.values.analogAuxiliaryMode or 'auto')) then
      nextAnalogAuxiliaryMode()
      M.lastChange = 'Analog lower gauge'
    end
  elseif M.values.instrumentMode == 'gt7_retro' then
    if ui.button('Speed dial needle: ' .. needleModeLabel('gt7SpeedNeedleMode')) then
      nextNeedleMode('gt7SpeedNeedleMode')
      M.lastChange = 'GT7 speed needle'
    end
    if ui.button('RPM dial needle: ' .. needleModeLabel('gt7RpmNeedleMode')) then
      nextNeedleMode('gt7RpmNeedleMode')
      M.lastChange = 'GT7 RPM needle'
    end
    checkbox('GT7 side proximity radar', 'gt7ProximityRadar')
    if M.values.gt7ProximityRadar ~= false
        and ui.button('Radar style: ' .. gt7RadarStyleLabel()) then
      M.values.gt7RadarStyle = M.values.gt7RadarStyle == 'arcs' and 'lights' or 'arcs'
      M.lastChange = 'GT7 radar style'
    end
    if ui.button('Lower panel: ' .. gt7LowerPanelModeLabel()) then
      nextGt7LowerPanelMode()
      M.lastChange = 'GT7 lower panel'
    end
  end

  ui.separator()
  ui.text('RPM behavior')
  percentageSlider('Warning threshold', 'rpmWarningFraction', 0.70, 0.98)
  percentageSlider('Redline threshold', 'rpmRedlineFraction', 0.82, 1.0)
  normalizeRpmThresholds()
  slider('Fallback RPM', 'fallbackRpm', 4000, 16000, '%.0f rpm')

  ui.separator()
  ui.text('Display')
  checkbox('Show steering marker', 'showSteering')
  checkbox('Show clutch', 'showClutch')
  checkbox('Show lights', 'showLights')
  checkbox('Show TC / ABS levels', 'showTcAbsLevels')
  checkbox('Blink turn indicators', 'animateIndicators')
  checkbox('Blink race flag alert', 'animateFlagAlert')
  checkbox('Blink shift zone', 'animateShiftAlert')
  checkbox('Blink redline alert', 'animateRedlineAlert')
  checkbox('Developer debug view', 'debug')

  ui.separator()
  ui.text('Last change: ' .. M.lastChange)
  if M.values.instrumentMode == 'gt7_retro' then
    ui.textWrapped('Resize GT7 Retro by dragging the app window borders or corners. Its panoramic aspect ratio is preserved. The side radar has Arrow + dots and Arcs styles. Each adds a light as a car gets closer; all three blink when a car is alongside. It ignores cars ahead. Disable it to restore turn and flag indicators. The lower panel can show LIMIT, FFB, pedal history or remain Invisible for another overlay.')
  else
    ui.textWrapped('The dial is transparent outside its circular surface. Adjust its compact scale and frosted backdrop here; resize or move it through the normal AC app controls.')
  end
end

return M
