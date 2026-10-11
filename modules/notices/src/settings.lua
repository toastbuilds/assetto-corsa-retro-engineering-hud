local SettingsUI = require('src/settings_ui')
local M = {}
local DEFAULTS = {
  scale = 1, autoPlacement = true, locked = true,
  blueEnabled = true, repairEnabled = true, pitEnabled = true,
  autoPitForDamage = true, repairHold = 6,
  bodyDamageThreshold = 0.20, suspensionDamageThreshold = 0.05, engineDamageThreshold = 0.20
}
local ok, stored = pcall(ac.storage, DEFAULTS, 'retro-ui.notices.')
M.values = ok and type(stored) == 'table' and stored or {}
for key, value in pairs(DEFAULTS) do if M.values[key] == nil then M.values[key] = value end end

function M.normalize()
  for _, key in ipairs({ 'scale', 'repairHold', 'bodyDamageThreshold',
      'suspensionDamageThreshold', 'engineDamageThreshold' }) do
    local value = tonumber(M.values[key])
    if not value or value ~= value or math.abs(value) == math.huge then value = DEFAULTS[key] end
    local low, high = 0.01, 1
    if key == 'scale' then low, high = 0.65, 1.5
    elseif key == 'repairHold' then low, high = 2, 15 end
    M.values[key] = math.max(low, math.min(high, value))
  end
  for key, value in pairs(DEFAULTS) do
    if type(value) == 'boolean' then M.values[key] = M.values[key] ~= false end
  end
end

local function checkbox(label, key)
  if ui.checkbox(label, M.values[key]) then M.values[key] = not M.values[key] end
end

local function slider(label, key, low, high, format, percent)
  local factor = percent and 100 or 1
  local value, changed = ui.slider(label, M.values[key] * factor, low, high, format, 1)
  if changed then M.values[key] = value / factor end
end

function M.draw(state, requestPit, preview)
  M.normalize()
  ui.header('Race Notices')
  SettingsUI.section('notices', 'basics', 'Basics', true, function()
    slider('HUD scale', 'scale', 0.65, 1.5, '%.2fx')
    checkbox('Blue flag notices', 'blueEnabled')
    checkbox('Repair notices', 'repairEnabled')
    checkbox('Pit notices', 'pitEnabled')
    checkbox('Request a pit stop after damage', 'autoPitForDamage')
    if ui.button('Box next lap##notices.request') then requestPit() end
    ui.sameLine()
    if ui.button('Cancel pit request##notices.cancel') then state:cancelPit() end
    if state.pitLap then ui.text('Pit request: lap ' .. state.pitLap) end
    ui.textWrapped('Repair warnings appear first, then blue flags, then pit reminders. The panel is hidden when there is no notice.')
  end)
  SettingsUI.section('notices', 'personalization', 'Personalization', false, function()
    checkbox('Auto-placement', 'autoPlacement')
    checkbox('Stay visible when mouse leaves', 'locked')
    for _, item in ipairs({ { 'Blue flag', 'blue' }, { 'Repair', 'repair' }, { 'Pit', 'pit' } }) do
      if ui.button('Preview ' .. item[1] .. '##notices.' .. item[2]) then preview(item[2]) end
    end
  end)
  SettingsUI.section('notices', 'advanced', 'Advanced', false, function()
    slider('Bodywork warning', 'bodyDamageThreshold', 1, 100, '%.0f%%', true)
    slider('Suspension warning', 'suspensionDamageThreshold', 1, 100, '%.0f%%', true)
    slider('Engine / gearbox warning', 'engineDamageThreshold', 1, 100, '%.0f%%', true)
    slider('Repair notice duration', 'repairHold', 2, 15, '%.0f s')
    ui.textWrapped('Estimated repair time (~) assumes full bodywork, suspension and engine repairs using the car\'s pit rates and worst damaged zones. It excludes fuel, tyres and driving through pitlane. -- means the estimate is unavailable.')
  end)
  ui.separator()
  SettingsUI.resetAppearance('notices', function() M.values.scale = DEFAULTS.scale end)
  SettingsUI.resetAll('notices', function()
    for key, value in pairs(DEFAULTS) do M.values[key] = value end
    state:reset()
  end)
  M.normalize()
end

return M
