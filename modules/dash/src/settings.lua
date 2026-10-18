local SettingsUI = require('src/settings_ui')
local M = {}

M.values = ac.storage({
  version = 1,
  style = 'rpm-top',
  rpmTopShowPedals = true,
  rpmTopShowIndicators = true,
  sideShowSteering = true,
  sideShowPedals = true,
  sideShowIndicators = true,
}, 'retro-ui.dash.')

local function normalize()
  local values = M.values
  values.style = values.style == 'side-tach' and 'side-tach' or 'rpm-top'
  for _, key in ipairs({ 'rpmTopShowPedals', 'rpmTopShowIndicators',
      'sideShowSteering', 'sideShowPedals', 'sideShowIndicators' }) do
    values[key] = values[key] ~= false
  end
  values.version = 1
end

normalize()

local function checkbox(label, key)
  if ui.checkbox(label, M.values[key]) then M.values[key] = not M.values[key] end
end

function M.current()
  normalize()
  return M.values
end

function M.draw()
  normalize()
  ui.header('Dash')
  SettingsUI.section('dash', 'layout', 'Composition', true, function()
    SettingsUI.choice('dash', 'style', 'Style', M.values.style,
      { { label = 'RPM bar above', value = 'rpm-top' },
        { label = 'Side tachometer', value = 'side-tach' } },
      function(value) M.values.style = value end)
  end)
  SettingsUI.section('dash', 'visibility', 'Visible groups', true, function()
    if M.values.style == 'rpm-top' then
      checkbox('Pedal history graph', 'rpmTopShowPedals')
      checkbox('Status indicators', 'rpmTopShowIndicators')
    else
      checkbox('Steering indicator', 'sideShowSteering')
      checkbox('Pedal history graph', 'sideShowPedals')
      checkbox('Status indicators', 'sideShowIndicators')
    end
    ui.textWrapped('Speed, gear, RPM, fuel and boost remain visible. Visibility choices are saved separately for each composition.')
  end)
  ui.separator()
  SettingsUI.resetAll('dash', function()
    M.values.style = 'rpm-top'
    M.values.rpmTopShowPedals, M.values.rpmTopShowIndicators = true, true
    M.values.sideShowSteering, M.values.sideShowPedals, M.values.sideShowIndicators = true, true, true
  end, 'Restore the Dash composition and visibility settings? Shared appearance and units are managed in General.')
end

return M
