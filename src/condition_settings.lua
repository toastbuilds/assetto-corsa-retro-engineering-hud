local M = {}
local SettingsUI = require('src/settings_ui')
M.values = ac.storage({ opacity = 1 }, 'retro-ui.condition.')

function M.draw()
  ui.header('Condition')
  SettingsUI.section('condition', 'appearance', 'Appearance', true, function()
    local value, changed = ui.slider('Instrument opacity', M.values.opacity * 100, 45, 100, '%.0f%%', 1)
    if changed then M.values.opacity = value / 100 end
    SettingsUI.resetAppearance('condition', function() M.values.opacity = 1 end)
  end)
  SettingsUI.section('condition', 'advanced', 'Advanced', false, function()
    ui.textWrapped('Move and resize this window with the Assetto Corsa app controls.')
    SettingsUI.resetAll('condition', function() M.values.opacity = 1 end,
      'Restore every Condition setting?')
  end)
end

function M.current(base)
  return { theme = base.theme, opacity = M.values.opacity }
end

return M
