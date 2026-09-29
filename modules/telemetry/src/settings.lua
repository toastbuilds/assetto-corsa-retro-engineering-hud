local M = {}
local SettingsUI = require('src/settings_ui')

M.values = ac.storage({
  version = 3,
  hudScale = 0.86,
  instrumentOpacity = 1.0,
  backdropOpacity = 0.72,
  graphWidth = 420,
  graphExpanded = true,
  layout = 'auto',
  showThrottleTrace = true,
  showBrakeTrace = true,
  showClutchTrace = true,
  showFfbTrace = true,
  showHandbrake = false,
  showLegend = false,
  showTicksGrid = true,
  theme = 'dark'
}, 'retro-ui.telemetry.')

local function clamp(value, minimum, maximum)
  value = tonumber(value) or minimum
  return math.max(minimum, math.min(maximum, value))
end

if (M.values.version or 1) < 2 then
  -- The compact strip intentionally removes the old header/legend stack.
  M.values.showLegend = false
  M.values.graphWidth = math.max(M.values.graphWidth or 420, 420)
  M.values.version = 2
end

if (M.values.version or 1) < 3 then
  -- Keep the existing side-aware composition as the default after migration.
  M.values.layout = 'auto'
  M.values.version = 3
end

local function normalize()
  local values = M.values
  values.hudScale = clamp(values.hudScale, 0.60, 1.20)
  values.instrumentOpacity = clamp(values.instrumentOpacity, 0.45, 1.00)
  values.backdropOpacity = clamp(values.backdropOpacity, 0.18, 0.95)
  values.graphWidth = math.floor(clamp(values.graphWidth, 320, 900) + 0.5)
  values.graphExpanded = values.graphExpanded ~= false
  if values.layout ~= 'left' and values.layout ~= 'right' then
    values.layout = 'auto'
  end
  values.showThrottleTrace = values.showThrottleTrace ~= false
  values.showBrakeTrace = values.showBrakeTrace ~= false
  values.showClutchTrace = values.showClutchTrace ~= false
  values.showFfbTrace = values.showFfbTrace ~= false
  values.showHandbrake = values.showHandbrake == true
  values.showLegend = values.showLegend ~= false
  values.showTicksGrid = values.showTicksGrid ~= false
  values.theme = values.theme == 'light' and 'light' or 'dark'
end

normalize()

local function checkbox(label, key)
  if ui.checkbox(label, M.values[key]) then
    M.values[key] = not M.values[key]
  end
end

local function percentageSlider(label, key, minimum, maximum)
  local value, changed = ui.slider(label, M.values[key] * 100,
    minimum * 100, maximum * 100, '%.0f%%', 1)
  if changed then M.values[key] = value / 100 end
end

local function slider(label, key, minimum, maximum, format)
  local value, changed = ui.slider(label, M.values[key], minimum, maximum, format, 1)
  if changed then M.values[key] = value end
end

local function resetVisualSettings()
  M.values.hudScale = 0.86
  M.values.instrumentOpacity = 1.0
  M.values.backdropOpacity = 0.72
end

function M.draw()
  normalize()
  ui.header('Telemetry')
  SettingsUI.section('telemetry', 'appearance', 'Appearance', true, function()
    slider('HUD scale', 'hudScale', 0.60, 1.20, '%.2fx')
    percentageSlider('Instrument opacity', 'instrumentOpacity', 0.45, 1)
    percentageSlider('Backdrop opacity', 'backdropOpacity', 0.18, 0.95)
    SettingsUI.resetAppearance('telemetry', resetVisualSettings)
  end)
  SettingsUI.section('telemetry', 'layout', 'Layout', true, function()
    slider('Graph width', 'graphWidth', 320, 900, '%.0f px')
    checkbox('Oscilloscope expanded', 'graphExpanded')
    SettingsUI.choice('telemetry', 'layout', 'Arrangement', M.values.layout,
      { { label = 'Auto', value = 'auto' }, { label = 'Left', value = 'left' },
        { label = 'Right', value = 'right' } },
      function(value) M.values.layout = value end)
  end)
  SettingsUI.section('telemetry', 'traces', 'Live cluster and traces', true, function()
    checkbox('Accelerator trace', 'showThrottleTrace')
    checkbox('Brake trace', 'showBrakeTrace')
    checkbox('Clutch trace', 'showClutchTrace')
    checkbox('FFB trace', 'showFfbTrace')
    checkbox('Handbrake', 'showHandbrake')
    checkbox('Legend', 'showLegend')
    checkbox('Ticks and grid', 'showTicksGrid')
  end)
  SettingsUI.section('telemetry', 'advanced', 'Advanced', false, function()
    ui.textWrapped('The oscilloscope keeps five seconds of history. Graph width changes its density, not the buffer.')
    SettingsUI.resetAll('telemetry', function()
      resetVisualSettings()
      M.values.graphWidth, M.values.layout = 420, 'auto'
      M.values.graphExpanded = true
      M.values.showThrottleTrace, M.values.showBrakeTrace = true, true
      M.values.showClutchTrace, M.values.showFfbTrace = true, true
      M.values.showHandbrake, M.values.showLegend, M.values.showTicksGrid = false, false, true
    end, 'Restore every Telemetry setting?')
  end)
end

return M
