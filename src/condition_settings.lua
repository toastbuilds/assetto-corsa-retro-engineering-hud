local M = {}
local SettingsUI = require('src/settings_ui')
local TyreTemperature = require('src/tyre_temperature')
local GeneralSettings = require('src/general_settings')
M.values = ac.storage({
  lifeTextSize = 24,
  lifeTextWeight = 'Regular',
  temperatureDisplay = 'general',
  temperatureCoreWeight = TyreTemperature.coreWeight(nil),
  legendMode = '',
  showTemperatureLegend = true,
  numericMetric = 'life', pressureReadout = 'current', temperatureReadout = 'core',
  keepDetailsOpen = false, fallbackPressureFront = 26, fallbackPressureRear = 26,
  fallbackTemperatureMin = 80, fallbackTemperatureMax = 90, fallbackGT3Min = 75, fallbackGT3Max = 85,
  settingsVersion = 2
}, 'retro-ui.condition.')

function M.setLegendMode(mode)
  if mode == 'temperature' or mode == 'grip' or mode == 'none' then
    M.values.legendMode = mode
  end
end

function M.normalize()
  local v = M.values
  if v.numericMetric ~= 'pressure' and v.numericMetric ~= 'temperature' then v.numericMetric = 'life' end
  v.pressureReadout = v.pressureReadout == 'delta' and 'delta' or 'current'
  if v.temperatureReadout ~= 'surface' and v.temperatureReadout ~= 'blend' then v.temperatureReadout = 'core' end
  local function clamp(key, low, high, fallback)
    local value = tonumber(v[key])
    v[key] = value and value == value and math.max(low, math.min(high, value)) or fallback
  end
  clamp('fallbackPressureFront', 5, 80, 26)
  clamp('fallbackPressureRear', 5, 80, 26)
  clamp('fallbackTemperatureMin', 0, 200, 80)
  clamp('fallbackTemperatureMax', v.fallbackTemperatureMin, 250, 90)
  clamp('fallbackGT3Min', 0, 200, 75)
  clamp('fallbackGT3Max', v.fallbackGT3Min, 250, 85)
end
if M.values.legendMode == '' then
  M.values.legendMode = M.values.showTemperatureLegend == false and 'none' or 'temperature'
end

local function resetAppearance()
  M.values.lifeTextSize = 24
  M.values.lifeTextWeight = 'Regular'
  M.values.temperatureDisplay = 'general'
  M.values.temperatureCoreWeight = TyreTemperature.coreWeight(nil)
  M.values.showTemperatureLegend = true
  M.values.legendMode = 'temperature'
end

function M.draw()
  M.normalize()
  ui.header('Condition')
  SettingsUI.section('condition', 'basics', 'Basics', true, function()
    SettingsUI.choice('condition', 'numericMetric', 'Wheel readout', M.values.numericMetric,
      {{label='Remaining life', value='life'}, {label='Pressure', value='pressure'},
       {label='Temperature', value='temperature'}}, function(v) M.values.numericMetric = v end)
    if M.values.numericMetric == 'pressure' then
      SettingsUI.choice('condition', 'pressureReadout', 'Pressure readout', M.values.pressureReadout,
        {{label='Current', value='current'}, {label='Delta to ideal', value='delta'}}, function(v) M.values.pressureReadout = v end)
    elseif M.values.numericMetric == 'temperature' then
      SettingsUI.choice('condition', 'temperatureReadout', 'Temperature readout', M.values.temperatureReadout,
        {{label='Core', value='core'}, {label='Surface average', value='surface'},
         {label='Configured core/surface mix', value='blend'}}, function(v) M.values.temperatureReadout = v end)
    end
    if ui.checkbox('Keep tyre detail open', M.values.keepDetailsOpen) then
      M.values.keepDetailsOpen = not M.values.keepDetailsOpen
    end
    SettingsUI.choice('condition', 'temperatureDisplay', 'Tyre temperature', M.values.temperatureDisplay,
      {{label='Core + surface zones', value='general'}, {label='Core + surface uniform', value='uniform'},
       {label='Surface zones', value='surface'}}, function(mode) M.values.temperatureDisplay = mode end)
    SettingsUI.choice('condition', 'legendMode', 'Legend', M.values.legendMode,
      {{label='Temperature', value='temperature'}, {label='Grip', value='grip'},
       {label='None', value='none'}}, M.setLegendMode)
  end)
  SettingsUI.section('condition', 'personalization', 'Personalization', false, function()
    local value, changed = ui.slider('Wheel number size', M.values.lifeTextSize, 12, 36, '%.0f px', 1)
    if changed then M.values.lifeTextSize = math.floor(value + 0.5) end
    SettingsUI.choice('condition', 'lifeWeight', 'Wheel number weight', M.values.lifeTextWeight,
      {{label='Regular', value='Regular'}, {label='Bold', value='Bold'}}, function(weight) M.values.lifeTextWeight = weight end)
    if M.values.temperatureDisplay ~= 'surface' or M.values.temperatureReadout == 'blend' then
      value, changed = ui.slider('Core weight', TyreTemperature.coreWeight(M.values.temperatureCoreWeight) * 100,
        0, 100, '%.0f%%', 1)
      if changed then M.values.temperatureCoreWeight = TyreTemperature.coreWeight(math.floor(value + 0.5) / 100) end
      local core = TyreTemperature.coreWeight(M.values.temperatureCoreWeight) * 100
      ui.text(string.format('%.0f%% core / %.0f%% surface', core, 100 - core))
    end
  end)
  SettingsUI.section('condition', 'references', 'Estimated references', false, function()
    ui.textWrapped('Real car/compound data takes priority. A ~ marks estimated references. Pressure is authored in psi, temperature in Celsius.')
    for _, item in ipairs({
      {'Front ideal pressure', 'fallbackPressureFront', 5, 80, '%.1f psi'},
      {'Rear ideal pressure', 'fallbackPressureRear', 5, 80, '%.1f psi'},
      {'Thermal minimum', 'fallbackTemperatureMin', 0, 200, '%.0f C'},
      {'Thermal maximum', 'fallbackTemperatureMax', 0, 250, '%.0f C'},
      {'GT3 thermal minimum', 'fallbackGT3Min', 0, 200, '%.0f C'},
      {'GT3 thermal maximum', 'fallbackGT3Max', 0, 250, '%.0f C'}
    }) do
      local value, changed = ui.slider(item[1], M.values[item[2]], item[3], item[4], item[5], 1)
      if changed then M.values[item[2]] = value end
    end
  end)
  ui.textWrapped('Move and resize this window with the Assetto Corsa app controls.')
  ui.separator()
  SettingsUI.resetAppearance('condition', resetAppearance)
  SettingsUI.resetAll('condition', function()
    resetAppearance()
    M.values.numericMetric, M.values.pressureReadout, M.values.temperatureReadout = 'life', 'current', 'core'
    M.values.keepDetailsOpen = false
    M.values.fallbackPressureFront, M.values.fallbackPressureRear = 26, 26
    M.values.fallbackTemperatureMin, M.values.fallbackTemperatureMax = 80, 90
    M.values.fallbackGT3Min, M.values.fallbackGT3Max = 75, 85
  end, 'Restore all local Condition settings? Global settings are managed in General.')
end

function M.current()
  M.normalize()
  return GeneralSettings.apply({
    lifeTextSize = M.values.lifeTextSize,
    lifeTextWeight = M.values.lifeTextWeight,
    temperatureDisplay = M.values.temperatureDisplay,
    temperatureCoreWeight = TyreTemperature.coreWeight(M.values.temperatureCoreWeight),
    legendMode = M.values.legendMode,
    showTemperatureLegend = M.values.legendMode == 'temperature',
    numericMetric = M.values.numericMetric, pressureReadout = M.values.pressureReadout,
    temperatureReadout = M.values.temperatureReadout, keepDetailsOpen = M.values.keepDetailsOpen,
    fallbackPressureFront = M.values.fallbackPressureFront, fallbackPressureRear = M.values.fallbackPressureRear,
    fallbackTemperatureMin = M.values.fallbackTemperatureMin, fallbackTemperatureMax = M.values.fallbackTemperatureMax,
    fallbackGT3Min = M.values.fallbackGT3Min, fallbackGT3Max = M.values.fallbackGT3Max
  })
end

return M
