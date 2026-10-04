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
  showTemperatureLegend = true
}, 'retro-ui.condition.')

function M.setLegendMode(mode)
  if mode == 'temperature' or mode == 'grip' or mode == 'none' then
    M.values.legendMode = mode
  end
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
  ui.header('Condition')
  SettingsUI.section('condition', 'basics', 'Basics', true, function()
    SettingsUI.choice('condition', 'temperatureDisplay', 'Tyre temperature', M.values.temperatureDisplay,
      {{label='Core + surface zones', value='general'}, {label='Core + surface uniform', value='uniform'},
       {label='Surface zones', value='surface'}}, function(mode) M.values.temperatureDisplay = mode end)
    SettingsUI.choice('condition', 'legendMode', 'Legend', M.values.legendMode,
      {{label='Temperature', value='temperature'}, {label='Grip', value='grip'},
       {label='None', value='none'}}, M.setLegendMode)
  end)
  SettingsUI.section('condition', 'personalization', 'Personalization', false, function()
    local value, changed = ui.slider('Life number size', M.values.lifeTextSize, 12, 36, '%.0f px', 1)
    if changed then M.values.lifeTextSize = math.floor(value + 0.5) end
    SettingsUI.choice('condition', 'lifeWeight', 'Life number weight', M.values.lifeTextWeight,
      {{label='Regular', value='Regular'}, {label='Bold', value='Bold'}}, function(weight) M.values.lifeTextWeight = weight end)
    if M.values.temperatureDisplay ~= 'surface' then
      value, changed = ui.slider('Core weight', TyreTemperature.coreWeight(M.values.temperatureCoreWeight) * 100,
        0, 100, '%.0f%%', 1)
      if changed then M.values.temperatureCoreWeight = TyreTemperature.coreWeight(math.floor(value + 0.5) / 100) end
      local core = TyreTemperature.coreWeight(M.values.temperatureCoreWeight) * 100
      ui.text(string.format('%.0f%% core / %.0f%% surface', core, 100 - core))
    end
  end)
  ui.textWrapped('Move and resize this window with the Assetto Corsa app controls.')
  ui.separator()
  SettingsUI.resetAppearance('condition', resetAppearance)
  SettingsUI.resetAll('condition', resetAppearance, 'Restore all local Condition settings? Global settings are managed in General.')
end

function M.current()
  return GeneralSettings.apply({
    lifeTextSize = M.values.lifeTextSize,
    lifeTextWeight = M.values.lifeTextWeight,
    temperatureDisplay = M.values.temperatureDisplay,
    temperatureCoreWeight = TyreTemperature.coreWeight(M.values.temperatureCoreWeight),
    legendMode = M.values.legendMode,
    showTemperatureLegend = M.values.legendMode == 'temperature'
  })
end

return M
