local M = {}
local SettingsUI = require('src/settings_ui')
M.values = ac.storage({
  opacity = 1,
  lifeTextSize = 24,
  lifeTextWeight = 'Regular',
  showTemperatureLegend = true
}, 'retro-ui.condition.')

local function resetAppearance()
  M.values.opacity = 1
  M.values.lifeTextSize = 24
  M.values.lifeTextWeight = 'Regular'
  M.values.showTemperatureLegend = true
end

function M.draw()
  ui.header('Condition')
  SettingsUI.section('condition', 'appearance', 'Appearance', true, function()
    local value, changed = ui.slider('Instrument opacity', M.values.opacity * 100, 45, 100, '%.0f%%', 1)
    if changed then M.values.opacity = value / 100 end
    value, changed = ui.slider('Life number size', M.values.lifeTextSize, 12, 36, '%.0f px', 1)
    if changed then M.values.lifeTextSize = math.floor(value + 0.5) end
    SettingsUI.choice('condition', 'lifeWeight', 'Life number weight', M.values.lifeTextWeight,
      { { label = 'Regular', value = 'Regular' }, { label = 'Bold', value = 'Bold' } },
      function(weight) M.values.lifeTextWeight = weight end)
    if ui.checkbox('Show temperature scale', M.values.showTemperatureLegend) then
      M.values.showTemperatureLegend = not M.values.showTemperatureLegend
    end
    SettingsUI.resetAppearance('condition', resetAppearance)
  end)
  SettingsUI.section('condition', 'advanced', 'Advanced', false, function()
    ui.textWrapped('Move and resize this window with the Assetto Corsa app controls.')
    SettingsUI.resetAll('condition', resetAppearance,
      'Restore every Condition setting?')
  end)
end

function M.current(base)
  return {
    theme = base.theme,
    opacity = M.values.opacity,
    lifeTextSize = M.values.lifeTextSize,
    lifeTextWeight = M.values.lifeTextWeight,
    showTemperatureLegend = M.values.showTemperatureLegend
  }
end

return M
