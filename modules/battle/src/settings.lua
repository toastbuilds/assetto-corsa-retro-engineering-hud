local SettingsUI = require('src/settings_ui')
local M = {}
local DEFAULTS = { scale = 1, autoPlacement = true, locked = true, showGraphs = true }
local ok, stored = pcall(ac.storage, DEFAULTS, 'retro-ui.battle.')
M.values = ok and type(stored) == 'table' and stored or {}
for key, value in pairs(DEFAULTS) do if M.values[key] == nil then M.values[key] = value end end
function M.normalize()
  local scale = tonumber(M.values.scale)
  if not scale or scale ~= scale or math.abs(scale) == math.huge then scale = 1 end
  M.values.scale = math.max(0.65, math.min(1.5, scale))
  for key, value in pairs(DEFAULTS) do if type(value) == 'boolean' then M.values[key] = M.values[key] ~= false end end
end
local function checkbox(label, key)
  if ui.checkbox(label, M.values[key]) then M.values[key] = not M.values[key] end
end
function M.draw(state, preview)
  M.normalize()
  ui.header('Battle Panel')
  SettingsUI.section('battle', 'basics', 'Basics', true, function()
    local value, changed = ui.slider('HUD scale', M.values.scale, 0.65, 1.5, '%.2fx', 1)
    if changed then M.values.scale = value end
    checkbox('Show gap history', 'showGraphs')
    ui.textWrapped('The next drivers ahead and behind in your class, ordered by race position. The right number shows seconds gained or lost per lap: positive green means you gain, negative red means you lose. Rising graphs mean you gain; falling graphs mean you lose.')
  end)
  SettingsUI.section('battle', 'personalization', 'Personalization', false, function()
    checkbox('Auto-placement', 'autoPlacement')
    checkbox('Stay visible when mouse leaves', 'locked')
    if ui.button('Preview battle##battle.preview') then preview() end
  end)
  SettingsUI.section('battle', 'advanced', 'Advanced', false, function()
    ui.textWrapped('Trends compare gaps at the same point over up to three laps. A full lap of data is required; -- is shown while collecting data. ~ marks an estimated rate. History clears after rival changes, pit stops, restarts and replay seeks. Class detection follows Leaderboard settings.')
  end)
  ui.separator()
  SettingsUI.resetAppearance('battle', function() M.values.scale = 1 end)
  SettingsUI.resetAll('battle', function()
    for key, value in pairs(DEFAULTS) do M.values[key] = value end
    state:reset()
  end)
  M.normalize()
end
return M
